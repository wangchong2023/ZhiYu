//
//  StreamingDownloadManager.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage] 通用存储引擎包
//  核心职责：通用后台静默下载、断点续传、SHA256 流式完整性校验与速率采样的下载器。
//           与业务完全无关——任务标识、路径、错误消息均由调用方注入。
//

import Foundation
import CommonCrypto
import UFPCore

/// 通用流式下载器配置常量（避免魔数）。
private enum StreamingDownloadConstants {
    /// 下载速度采样最小间隔（秒），避免高频采样抖动
    static let speedSampleIntervalSeconds: Double = 0.5
    /// 默认断点续传数据子目录名
    static let resumeDirectoryName = "ufp.download.resume"
    /// 沙盒存储分配失败错误消息前缀
    static let sandboxAllocationFailedPrefix = "Sandbox storage allocation failed:"
}

/// 通用流式下载管理器。
///
/// 提供基于 URLSession 的后台静默下载、断点续传、SHA256 流式完整性校验与速率采样。
/// 与业务完全无关：
/// - 任务标识为通用 `taskID: String`（非业务 modelId）
/// - 断点续传目录、目标文件路径、错误消息均由闭包注入
/// - 使用自身通用状态类型 `StreamingDownloadState`，不依赖任何上层领域模型
public actor StreamingDownloadManager {

    /// 当前活跃下载任务的状态映射表
    private var states: [String: StreamingDownloadState] = [:]
    /// 任务 ID 到物理后台 Session Task 的映射表
    private var activeTasks: [String: URLSessionDownloadTask] = [:]
    /// 任务 ID 到期望 SHA256 校验指纹的映射表
    private var sha256Checksums: [String: String] = [:]
    /// 任务 ID 到实时下载速率计算器的追踪映射表
    private var speedTrackers: [String: SpeedTrackerState] = [:]
    /// 任务 ID 到其异步流事件通道 (Continuation) 的订阅分发映射表
    private var continuations: [String: AsyncStream<StreamingDownloadState>.Continuation] = [:]

    private struct SpeedTrackerState {
        let lastBytes: Int64
        let lastTime: Date
        let currentSpeed: Double
    }

    /// Session 工厂闭包 — 生产环境创建 background URLSession，测试环境可注入 ephemeral session
    private let sessionFactory: @Sendable (StreamingDownloadManager) -> URLSession
    /// 断点续传数据的存储目录（由调用方注入，保持路径通用）
    private let resumeDataDirectory: @Sendable () -> URL
    /// 目标文件路径解析（由调用方注入，保持业务路径通用）
    private let destinationResolver: @Sendable (String) -> URL

    /// 懒加载 Session 实例，由 sessionFactory 创建
    private lazy var session: URLSession = {
        sessionFactory(self)
    }()

    /// 生产环境默认 Session 工厂 — 创建 background URLSession
    @Sendable
    private static func defaultSessionFactory(manager: StreamingDownloadManager) -> URLSession {
        let config = URLSessionConfiguration.background(withIdentifier: "com.ufp.streaming.download")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        let delegateHelper = StreamingDownloadDelegateHelper(manager: manager)
        return URLSession(configuration: config, delegate: delegateHelper, delegateQueue: nil)
    }

    /// 生产环境默认断点续传目录（Caches 下通用子目录）
    @Sendable
    private static func defaultResumeDirectory() -> URL {
        let cachesDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let resumeFolder = cachesDirectory.appendingPathComponent(StreamingDownloadConstants.resumeDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: resumeFolder, withIntermediateDirectories: true)
        return resumeFolder
    }

    /// 生产环境初始化器 — 使用默认 Session 工厂与默认断点续传目录
    public init() {
        self.init(
            sessionFactory: Self.defaultSessionFactory,
            resumeDataDirectory: Self.defaultResumeDirectory,
            destinationURL: { taskID in
                let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                return documentDirectory.appendingPathComponent("\(taskID).bin")
            }
        )
    }

    /// 便捷初始化器 — 使用自定义 URLSessionConfiguration（可注入 protocolClasses 等），
    /// 内部以通用 Delegate 桥接器创建 session，保持回调链路完整。
    /// - Parameters:
    ///   - configuration: URLSession 配置（测试可注入 `MockDownloadURLProtocol`）
    ///   - resumeDataDirectory: 断点续传数据存储目录闭包
    ///   - destinationURL: 目标文件路径解析闭包
    public init(
        configuration: URLSessionConfiguration,
        resumeDataDirectory: @escaping @Sendable () -> URL,
        destinationURL: @escaping @Sendable (String) -> URL
    ) {
        self.sessionFactory = { manager in
            let delegateHelper = StreamingDownloadDelegateHelper(manager: manager)
            return URLSession(configuration: configuration, delegate: delegateHelper, delegateQueue: nil)
        }
        self.resumeDataDirectory = resumeDataDirectory
        self.destinationResolver = destinationURL
    }

    /// 测试/定制初始化器 — 允许注入自定义 Session 工厂、断点续传目录与目标路径解析
    /// - Parameters:
    ///   - sessionFactory: 自定义 Session 工厂闭包
    ///   - resumeDataDirectory: 断点续传数据存储目录闭包
    ///   - destinationURL: 目标文件路径解析闭包
    public init(
        sessionFactory: @escaping @Sendable (StreamingDownloadManager) -> URLSession,
        resumeDataDirectory: @escaping @Sendable () -> URL,
        destinationURL: @escaping @Sendable (String) -> URL
    ) {
        self.sessionFactory = sessionFactory
        self.resumeDataDirectory = resumeDataDirectory
        self.destinationResolver = destinationURL
    }

    /// 获取断点恢复数据（resumeData）在断点续传目录下的物理存储 URL
    private func resumeDataURL(for taskID: String) -> URL {
        resumeDataDirectory().appendingPathComponent("\(taskID).resume")
    }

    /// 获取任务文件的目标存储 URL（由注入的 destinationResolver 解析）
    private func destinationURL(for taskID: String) -> URL {
        destinationResolver(taskID)
    }

    /// 原子性持久化 resumeData 并更新状态；失败时更新为 failed 状态
    /// - Parameters:
    ///   - data: 断点续传二进制数据
    ///   - taskID: 任务 ID
    ///   - errorPrefix: 失败日志前缀（区分 pause / network error 场景）
    private func persistResumeData(_ data: Data, for taskID: String, errorPrefix: String) {
        do {
            try data.write(to: resumeDataURL(for: taskID), options: .atomic)
            updateState(for: taskID, to: .paused)
        } catch {
            updateState(for: taskID, to: .failed(error: errorPrefix + error.localizedDescription))
        }
    }

    // MARK: - 下载生命周期

    /// 开始下载任务。
    /// - Parameters:
    ///   - taskID: 通用任务标识
    ///   - remoteURL: 远程文件 URL
    public func startDownload(taskID: String, remoteURL: URL) async throws {
        // 1. 如果已经存在下载任务，直接拦截
        if let state = states[taskID] {
            switch state {
            case .downloading, .verifying, .completed:
                return
            default:
                break
            }
        }

        // 2. 清理历史残余
        cleanPreviousFiles(for: taskID)

        // 3. 构建后台 Task
        let task = session.downloadTask(with: remoteURL)
        task.taskDescription = taskID
        activeTasks[taskID] = task

        // 4. 更新并分发状态为 pending
        updateState(for: taskID, to: .pending)

        // 5. 激活 Task 开始下载
        task.resume()
    }

    /// 暂停正在下载的任务，捕获断点续传数据 (resumeData)
    public func pauseDownload(taskID: String) async throws {
        guard let task = activeTasks[taskID] else { return }

        // 优雅捕获 resumeData 并暂停物理下载
        let resumeData = await withCheckedContinuation { (continuation: CheckedContinuation<Data?, Never>) in
            task.cancel(byProducingResumeData: { data in
                continuation.resume(returning: data)
            })
        }

        if let data = resumeData {
            persistResumeData(data, for: taskID, errorPrefix: StreamingDownloadConstants.sandboxAllocationFailedPrefix)
        } else {
            updateState(for: taskID, to: .failed(error: "resume data generation failed"))
        }

        activeTasks[taskID] = nil
    }

    /// 恢复已经暂停的任务 (利用之前捕获的 resumeData)
    public func resumeDownload(taskID: String) async throws {
        // 1. 检索物理断点恢复文件数据
        let fileURL = resumeDataURL(for: taskID)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else {
            updateState(for: taskID, to: .failed(error: "no resume data"))
            return
        }

        // 2. 基于 resumeData 重新拉起 Task 并关联
        let task = session.downloadTask(withResumeData: data)
        task.taskDescription = taskID
        activeTasks[taskID] = task

        // 3. 激活 Task 继续静默续传
        task.resume()

        // 4. 清理已消费的物理断点恢复文件 — 在 task.resume() 之后执行
        try? FileManager.default.removeItem(at: fileURL)
    }

    /// 取消下载任务，彻底清除临时下载数据
    public func cancelDownload(taskID: String) async throws {
        if let task = activeTasks[taskID] {
            task.cancel()
        }

        // 清理可能存在的断点恢复文件
        let fileURL = resumeDataURL(for: taskID)
        try? FileManager.default.removeItem(at: fileURL)

        activeTasks[taskID] = nil
        cleanPreviousFiles(for: taskID)

        updateState(for: taskID, to: .cancelled)
    }

    /// 监听特定任务的实时状态与进度变化流
    public func observeDownloadState(for taskID: String) async -> AsyncStream<StreamingDownloadState> {
        return AsyncStream { continuation in
            // 保存当前事件通道
            continuations[taskID] = continuation

            // 首次订阅时推送当前已有状态
            let currentState = states[taskID] ?? .failed(error: "Idle")
            continuation.yield(currentState)

            // 订阅断开时自动清理
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?.removeContinuation(for: taskID)
                }
            }
        }
    }

    // MARK: - 注册 SHA256 指纹

    /// 外部在发起下载前，向管理器注册期望的哈希值用于完好性判定
    /// - Parameters:
    ///   - taskID: 任务 ID
    ///   - checksum: SHA256 校验和串
    public func registerChecksum(for taskID: String, checksum: String) {
        sha256Checksums[taskID] = checksum
    }

    // MARK: - 供 Delegate 调用的内部并发更新方法

    /// 更新下载进度百分比与实时下载速率
    public func updateProgress(for taskID: String, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        let now = Date()

        var calculatedSpeed: Double = 0
        if let tracker = speedTrackers[taskID] {
            let timeDiff = now.timeIntervalSince(tracker.lastTime)
            if timeDiff >= StreamingDownloadConstants.speedSampleIntervalSeconds {
                let bytesDiff = Double(totalBytesWritten - tracker.lastBytes)
                calculatedSpeed = max(0, bytesDiff / timeDiff)
                speedTrackers[taskID] = SpeedTrackerState(lastBytes: totalBytesWritten, lastTime: now, currentSpeed: calculatedSpeed)
            } else {
                calculatedSpeed = tracker.currentSpeed
            }
        } else {
            speedTrackers[taskID] = SpeedTrackerState(lastBytes: totalBytesWritten, lastTime: now, currentSpeed: 0)
        }

        updateState(
            for: taskID,
            to: .downloading(
                progress: progress,
                bytesPerSecond: calculatedSpeed,
                downloadedBytes: totalBytesWritten,
                totalBytes: totalBytesExpectedToWrite
            )
        )
    }

    /// 完成下载，在临时路径触发指纹完整性验证并移入目标目录
    public func completeDownload(for taskID: String, tempFileURL: URL, verificationFailedMessage: String) {
        updateState(for: taskID, to: .verifying)

        // 在 actor 上下文中预先读取 Sendable 值，避免 detached 任务访问 actor 隔离状态
        let checksum = sha256Checksums[taskID] ?? ""
        let destURL = destinationURL(for: taskID)
        let sandboxFailurePrefix = StreamingDownloadConstants.sandboxAllocationFailedPrefix

        // 利用后台并发 Task 异步进行 CPU 密集的哈希判定与文件移动，解耦主 Actor
        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            // 1. 进行完好性校验 (SHA256) — verifySHA256 是 nonisolated，可在 detached 直接调用
            if !self.verifySHA256(of: tempFileURL, expectedHash: checksum) {
                await self.updateState(for: taskID, to: .failed(error: verificationFailedMessage))
                try? FileManager.default.removeItem(at: tempFileURL)
                await self.clearActiveTask(for: taskID)
                return
            }

            // 2. 校验成功，安全移入目标目录
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.moveItem(at: tempFileURL, to: destURL)

                // 3. 标记完结
                await self.updateState(for: taskID, to: .completed(localURL: destURL))
                await self.clearActiveTask(for: taskID)
            } catch {
                await self.updateState(for: taskID, to: .failed(error: "\(sandboxFailurePrefix) \(error.localizedDescription)"))
            }
        }
    }

    /// 网络传输异常时的错误拦截处理
    public func handleDownloadError(for taskID: String, error: Error) {
        let nsError = error as NSError

        // 如果是断网等原因引起的异常中断，错误包里可能附带 resumeData
        if let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            persistResumeData(resumeData, for: taskID, errorPrefix: StreamingDownloadConstants.sandboxAllocationFailedPrefix)
        } else {
            updateState(for: taskID, to: .failed(error: error.localizedDescription))
        }

        activeTasks[taskID] = nil
    }

    // MARK: - 内部并发辅助工具方法

    /// 获取指定任务的 SHA256 校验和
    public func getChecksum(for taskID: String) -> String? {
        return sha256Checksums[taskID]
    }

    /// 清除指定任务的活动下载任务
    public func clearActiveTask(for taskID: String) {
        activeTasks[taskID] = nil
    }

    /// 核心状态更新与发布分发引擎
    public func updateState(for taskID: String, to state: StreamingDownloadState) {
        states[taskID] = state

        // 瞬间向所有订阅的 AsyncStream 分发最新状态事件
        if let continuation = continuations[taskID] {
            continuation.yield(state)
        }
    }

    private func removeContinuation(for taskID: String) {
        continuations[taskID] = nil
    }

    private func cleanPreviousFiles(for taskID: String) {
        let destURL = destinationURL(for: taskID)
        try? FileManager.default.removeItem(at: destURL)
    }

    /// 校验文件的 SHA256 哈希是否与期望值一致（纯算法，非isolated，转发自通用工具）。
    /// - Returns: 校验是否通过（空哈希容灾放行；非 64 字符拒绝）
    nonisolated public func verifySHA256(of fileURL: URL, expectedHash: String) -> Bool {
        SHA256Verifier.verify(of: fileURL, expectedHash: expectedHash)
    }
}

// MARK: - 桥接 Delegate 协调助手类 (NSObject Bridge Pattern)

/// URLSession 代理协助类。负责无声桥接后台系统通知至 Actor。
internal final class StreamingDownloadDelegateHelper: NSObject, URLSessionDownloadDelegate, Sendable {

    /// 持有弱引用的 Actor 控制器
    private let manager: StreamingDownloadManager

    init(manager: StreamingDownloadManager) {
        self.manager = manager
        super.init()
    }

    /// URLSession 下载进度回调，更新下载进度
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let taskID = downloadTask.taskDescription, totalBytesExpectedToWrite > 0 else { return }

        Task {
            await manager.updateProgress(for: taskID, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
        }
    }

    /// URLSession 下载完成回调，将临时文件移交至管理器处理
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let taskID = downloadTask.taskDescription else { return }

        // 严格校验 HTTP 状态码，拦截 404/500 等异常请求，防止将错误页面保存
        if let httpResponse = downloadTask.response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
            Task {
                await manager.updateState(for: taskID, to: .failed(error: "Network error: HTTP \(httpResponse.statusCode)"))
                await manager.clearActiveTask(for: taskID)
            }
            return
        }

        // 创建临时安全副本，防止系统委托在退出 didFinishDownloading 瞬间删除文件
        let tempDirectory = FileManager.default.temporaryDirectory
        let safeTempURL = tempDirectory.appendingPathComponent(UUID().uuidString + ".bin")

        do {
            try FileManager.default.moveItem(at: location, to: safeTempURL)
            Task {
                await manager.completeDownload(for: taskID, tempFileURL: safeTempURL, verificationFailedMessage: "verification failed")
            }
        } catch {
            Task {
                await manager.updateState(for: taskID, to: .failed(error: "temporary copy failed: \(error.localizedDescription)"))
                await manager.clearActiveTask(for: taskID)
            }
        }
    }

    /// URLSession 任务完成回调，处理下载错误（自动忽略用户主动取消）
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let taskDescription = task.taskDescription else { return }

        if let error = error {
            let nsError = error as NSError
            // 如果是用户主动取消任务，忽略报错
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }

            Task {
                await manager.handleDownloadError(for: taskDescription, error: error)
            }
        }
    }
}