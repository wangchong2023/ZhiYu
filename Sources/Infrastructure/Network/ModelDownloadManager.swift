//
//  ModelDownloadManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：大模型权重文件后台静默下载、断点续传、沙盒 SHA256 指纹完整性校验。
//           实现自 Domain 层 ModelDownloadCapabilities 协议，内部组合 UFPStorage 通用下载器
//           StreamingDownloadManager，并在入口桥接领域状态 DownloadState。
//

import Foundation
import UFPStorage
import UFPCore

/// 下载状态错误消息常量（通过 L10n 强类型访问实现多语言本地化）
private enum DownloadErrorMessage {
    /// 无续传数据文件
    static var noResumeData: String { L10n.ModelManager.Status.DownloadError.noResumeData }
    /// 空闲状态占位
    static var idle: String { L10n.ModelManager.Status.DownloadError.idle }
    /// 临时副本生成失败前缀
    static var temporaryCopyFailedPrefix: String { L10n.ModelManager.Status.DownloadError.temporaryCopyFailedPrefix }
    /// 生成失败连接符
    static var generationFailedConnector: String { L10n.ModelManager.Status.DownloadError.generationFailedConnector }
    /// resumeData 持久化失败前缀
    static var persistResumeDataFailedPrefix: String { L10n.ModelManager.Status.DownloadError.persistResumeDataFailedPrefix }
    /// 网络错误 resumeData 持久化失败前缀
    static var networkErrorResumeDataFailedPrefix: String { L10n.ModelManager.Status.DownloadError.networkErrorResumeDataFailedPrefix }
}

/// 大模型权重文件后台静默下载与状态管理器。
///
/// 保持 `ModelDownloadCapabilities` 契约不变，内部组合 UFPStorage 通用下载器 `StreamingDownloadManager`：
/// - 通用下载核心（URLSession 生命周期/断点续传/SHA256 流式校验/速率采样/状态流）委托给通用下载器
/// - 领域状态 `DownloadState` 与通用状态 `StreamingDownloadState` 在入口桥接
/// - 业务路径（Documents/{modelId}.bin）与本地化错误消息保留在本层
public actor ModelDownloadManager: ModelDownloadCapabilities {

    /// 测试用访问器：暴露 SHA256 缓冲区大小常量（供单元测试验证常量抽取）
    internal static var sha256BufferSizeForTesting: Int {
        Int(SystemConstants.bytesPerKB) * Int(SystemConstants.bytesPerKB)
    }

    /// 测试用访问器：暴露沙盒分配失败前缀常量
    internal static var sandboxAllocationFailedPrefixForTesting: String {
        "Sandbox storage allocation failed:"
    }

    /// 全局单例注入，便于在 App 顶层会话绑定
    public static let shared = ModelDownloadManager()

    /// 内部组合的通用流式下载器
    private let streaming: StreamingDownloadManager

    /// 生产环境初始化器（仅 `shared` 单例使用）。
    /// 注入业务路径：Documents/{modelId}.bin、Caches 下业务断点续传子目录。
    private init() {
        let resumeDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.zhiyu.app.download.resume", isDirectory: true)
        streaming = StreamingDownloadManager(
            sessionFactory: { _ in
                let config = URLSessionConfiguration.background(withIdentifier: "com.zhiyu.app.model.download")
                config.isDiscretionary = false
                config.sessionSendsLaunchEvents = true
                return URLSession(configuration: config, delegate: nil, delegateQueue: nil)
            },
            resumeDataDirectory: {
                try? FileManager.default.createDirectory(at: resumeDirectory, withIntermediateDirectories: true)
                return resumeDirectory
            },
            destinationURL: { modelId in
                let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                return documentDirectory.appendingPathComponent("\(modelId).bin")
            }
        )
    }

    /// 测试环境初始化器 — 允许注入自定义 Session 工厂
    /// - Parameter sessionFactory: 自定义 Session 工厂闭包
    internal init(sessionFactory: @escaping @Sendable (StreamingDownloadManager) -> URLSession) {
        let resumeDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.zhiyu.app.download.resume", isDirectory: true)
        streaming = StreamingDownloadManager(
            sessionFactory: sessionFactory,
            resumeDataDirectory: {
                try? FileManager.default.createDirectory(at: resumeDirectory, withIntermediateDirectories: true)
                return resumeDirectory
            },
            destinationURL: { modelId in
                let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                return documentDirectory.appendingPathComponent("\(modelId).bin")
            }
        )
    }

    /// 测试环境初始化器 — 允许注入自定义 URLSessionConfiguration（含 protocolClasses），
    /// 内部以通用 Delegate 桥接器创建 session。
    /// - Parameter configuration: URLSession 配置
    internal init(configuration: URLSessionConfiguration) {
        let resumeDirectory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("com.zhiyu.app.download.resume", isDirectory: true)
        streaming = StreamingDownloadManager(
            configuration: configuration,
            resumeDataDirectory: {
                try? FileManager.default.createDirectory(at: resumeDirectory, withIntermediateDirectories: true)
                return resumeDirectory
            },
            destinationURL: { modelId in
                let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                return documentDirectory.appendingPathComponent("\(modelId).bin")
            }
        )
    }

    // MARK: - 领域状态桥接

    /// 将通用下载状态桥接为领域 DownloadState。
    private func bridge(_ state: StreamingDownloadState) -> DownloadState {
        switch state {
        case .pending: return .pending
        case .downloading(let progress, let bytesPerSecond, let downloadedBytes, let totalBytes):
            return .downloading(
                progress: progress,
                bytesPerSecond: bytesPerSecond,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes
            )
        case .paused: return .paused
        case .verifying: return .verifying
        case .completed(let localURL): return .completed(localURL: localURL)
        case .cancelled: return .cancelled
        case .failed(let error): return .failed(error: error)
        }
    }

    // MARK: - Capabilities 契约接口实现

    /// 开始下载大模型权重文件
    public func startDownload(modelId: String, remoteURL: URL) async throws {
        try await streaming.startDownload(taskID: modelId, remoteURL: remoteURL)
    }

    /// 暂停正在下载的权重任务，捕获断点续传数据 (resumeData)
    public func pauseDownload(modelId: String) async throws {
        try await streaming.pauseDownload(taskID: modelId)
    }

    /// 恢复下载已经暂停的权重任务 (利用之前捕获的 resumeData)
    public func resumeDownload(modelId: String) async throws {
        try await streaming.resumeDownload(taskID: modelId)
    }

    /// 取消下载任务，彻底清除临时下载数据
    public func cancelDownload(modelId: String) async throws {
        try await streaming.cancelDownload(taskID: modelId)
    }

    /// 监听特定大模型任务的实时状态与进度变化流
    public func observeDownloadState(for modelId: String) async -> AsyncStream<DownloadState> {
        let stream = await streaming.observeDownloadState(for: modelId)
        return AsyncStream { continuation in
            Task {
                for await state in stream {
                    continuation.yield(bridge(state))
                }
                continuation.finish()
            }
        }
    }

    // MARK: - 注册 SHA256 指纹

    /// 外部在发起下载前，向 Manager 注册期望的哈希值用于完好性判定
    /// - Parameters:
    ///   - modelId: 模型 ID
    ///   - checksum: SHA256 校验和串
    public func registerChecksum(for modelId: String, checksum: String) async {
        await streaming.registerChecksum(for: modelId, checksum: checksum)
    }

    // MARK: - 供 Delegate 调用的内部并发更新方法

    /// 更新下载进度百分比与实时下载速率
    public func updateProgress(for modelId: String, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) async {
        await streaming.updateProgress(for: modelId, totalBytesWritten: totalBytesWritten, totalBytesExpectedToWrite: totalBytesExpectedToWrite)
    }

    /// 更新下载进度百分比 (兼容旧模式)
    public func updateProgress(for modelId: String, progress: Double) async {
        await streaming.updateState(for: modelId, to: .downloading(progress: progress))
    }

    /// 完成下载，在沙盒临时路径触发指纹完整性验证
    public func completeDownload(for modelId: String, tempFileURL: URL) async {
        let verificationFailedMessage = L10n.ModelManager.Status.verificationFailed
        await streaming.completeDownload(for: modelId, tempFileURL: tempFileURL, verificationFailedMessage: verificationFailedMessage)
    }

    /// 网络传输异常时的错误拦截处理
    public func handleDownloadError(for modelId: String, error: Error) async {
        await streaming.handleDownloadError(for: modelId, error: error)
    }

    /// 校验文件的 SHA256 哈希是否与期望值一致（纯算法，非isolated，转发自 UFPStorage 通用工具）。
    /// - Returns: 校验是否通过（空哈希容灾放行；非 64 字符拒绝）
    nonisolated func verifySHA256(of fileURL: URL, expectedHash: String) -> Bool {
        SHA256Verifier.verify(of: fileURL, expectedHash: expectedHash)
    }

    // MARK: - 内部并发辅助工具方法

    /// 获取指定模型的 SHA256 校验和
    public func getChecksum(for modelId: String) async -> String? {
        await streaming.getChecksum(for: modelId)
    }

    /// 清除指定模型的活动下载任务
    public func clearActiveTask(for modelId: String) async {
        await streaming.clearActiveTask(for: modelId)
    }

    /// 核心状态更新与发布分发引擎
    public func updateState(for modelId: String, to state: DownloadState) async {
        let generic: StreamingDownloadState
        switch state {
        case .pending: generic = .pending
        case .downloading(let progress, let bytesPerSecond, let downloadedBytes, let totalBytes):
            generic = .downloading(
                progress: progress,
                bytesPerSecond: bytesPerSecond,
                downloadedBytes: downloadedBytes,
                totalBytes: totalBytes
            )
        case .paused: generic = .paused
        case .verifying: generic = .verifying
        case .completed(let localURL): generic = .completed(localURL: localURL)
        case .cancelled: generic = .cancelled
        case .failed(let error): generic = .failed(error: error)
        }
        await streaming.updateState(for: modelId, to: generic)
    }
}
