//
//  GlobalModelManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层 / 状态中台
//  核心职责：作为全局响应式大模型控制中枢。负责拉取并映射端侧模型市场白名单、监听后台下载进度流、处理本地运存护栏判定、以及执行端云混合路由决策（2.4 契约）。
//

import Foundation
import UFPCore
import Observation
import Combine

/// 全局大模型状态控制中枢，使用 Swift 17 @Observable 宏，全局唯一并以 Environment/DI 形式分发
@MainActor
@Observable
public final class GlobalModelManager {
    
    /// 全局共享实例
    public static let shared = GlobalModelManager()
    
    // MARK: - 依赖注入
    
    @ObservationIgnored @Inject private var remoteConfig: any RemoteConfigCapabilities
    @ObservationIgnored @Inject private var downloadManager: any ModelDownloadCapabilities
    /// Factory 风格：属性类型标注为可选（T?）， 自动使用 resolveOptional
    @ObservationIgnored @Inject private var keyStore: (any KeyStoreProtocol)?
    
    // MARK: - 全局响应式属性
    
    /// 远程拉取的端侧模型白名单列表
    public private(set) var remoteManifests: [LLMManifest] = []
    
    /// 模型 ID 到对应下载进度状态的映射映射表
    public private(set) var downloadStates: [String: DownloadState] = [:]
    
    /// 是否正在加载白名单
    public private(set) var isLoading: Bool = false
    
    /// 物理设备总内存大小 (字节)
    public let physicalMemory: UInt64
    
    /// 已下载模型的存储占用（字节），按 modelId 索引
    public private(set) var modelStorageUsage: [String: Int64] = [:]

    /// 模型调用次数统计，按 modelId 索引
    public private(set) var modelCallCounts: [String: Int] = [:]

    /// 物理硬件运存防爆评估拦截服务
    @ObservationIgnored private let hardwareGuard: DeviceHardwareGuard
    
    /// 单元测试专用：允许手动模拟国内/国外环境
    internal var isChinaRegionOverride: Bool?

    /// 判断当前是否处于中国大陆地区，用于决定大模型下载源路由
    private var isChinaRegion: Bool {
        if let override = isChinaRegionOverride {
            return override
        }
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
            return Locale.current.region?.identifier == "CN"
        } else {
            return Locale.current.identifier.contains("zh-Hans") || Locale.current.identifier.contains("_CN")
        }
    }
    
    // MARK: - 持久化设置属性
    
    /// 用户当前选中的本地活跃大模型 ID (例如: "gemma-4-e2b-it")
    public var activeModelId: String {
        get {
            access(keyPath: \.activeModelId)
            return keyStore?.string(forKey: AppConstants.Keys.Storage.activeModelId) ?? "gemma-4-e2b-it"
        }
        set {
            withMutation(keyPath: \.activeModelId) {
                keyStore?.set(newValue, forKey: AppConstants.Keys.Storage.activeModelId)
            }
        }
    }
    
    /// 云端深度考据提权开关：开启时强网络优先路由到云端，关闭或离线自动回滚本地端侧 (2.4 契约)
    public var isCloudEscalationEnabled: Bool {
        get {
            access(keyPath: \.isCloudEscalationEnabled)
            return keyStore?.bool(forKey: AppConstants.Keys.Storage.isCloudEscalationEnabled) ?? false
        }
        set {
            withMutation(keyPath: \.isCloudEscalationEnabled) {
                keyStore?.set(newValue, forKey: AppConstants.Keys.Storage.isCloudEscalationEnabled)
            }
        }
    }
    
    /// 默认云端提权路由的大模型代号
    public var activeCloudModelId: String {
        get {
            access(keyPath: \.activeCloudModelId)
            return keyStore?.string(forKey: AppConstants.Keys.Storage.activeCloudModelId) ?? "gpt-4o"
        }
        set {
            withMutation(keyPath: \.activeCloudModelId) {
                keyStore?.set(newValue, forKey: AppConstants.Keys.Storage.activeCloudModelId)
            }
        }
    }
    
    // MARK: - 初始化
    
    /// 初始化大模型市场中台管理器
    public init() {
        self.physicalMemory = ProcessInfo.processInfo.physicalMemory
        self.hardwareGuard = DeviceHardwareGuard(physicalMemory: self.physicalMemory)
        
        // 异步加载模型列表并建立初始状态
        Task {
            await initializeManager()
        }
    }
    
    // MARK: - 持久化已完成模型 Flag 管理 (UserDefaults 容灾)
    
    private static let downloadedModelIdsKey = "zhiyu_downloaded_model_ids"
    
    /// 获取/更新本地记录的已完成模型 ID 集合
    public private(set) var downloadedModelIds: Set<String> {
        get {
            let list = UserDefaults.standard.stringArray(forKey: Self.downloadedModelIdsKey) ?? []
            return Set(list)
        }
        set {
            UserDefaults.standard.set(Array(newValue), forKey: Self.downloadedModelIdsKey)
        }
    }
    
    /// 标记某个模型 ID 为已完成下载并持久化 Flag
    public func markModelAsDownloaded(_ modelId: String) {
        var current = downloadedModelIds
        current.insert(modelId)
        downloadedModelIds = current
    }

    /// 标记某个模型 ID 为未下载/移除持久化 Flag
    public func markModelAsRemoved(_ modelId: String) {
        var current = downloadedModelIds
        current.remove(modelId)
        downloadedModelIds = current
    }
    
    // MARK: - 核心管理方法
    
    /// 初始化加载白名单及检测本地沙盒已就绪的权重
    private func initializeManager() async {
        self.isLoading = true
        defer { self.isLoading = false }

        // 在测试环境中 DI 容器可能尚未完全就绪，使用可选解析兜底
        guard let remoteConfig = ServiceContainer.shared.resolveOptional((any RemoteConfigCapabilities).self) else {
            Logger.shared.warning("[GlobalModelManager] RemoteConfigCapabilities 未注册，跳过远程清单拉取")
            return
        }

        do {
            // 1. 静默拉取白名单（支持极致的离线兜底 fallback）
            self.remoteManifests = try await remoteConfig.fetchLLMManifests()
            
            // 2. 扫描本地沙盒文件，对齐下载状态
            refreshLocalModelFiles()
        } catch {
            Logger.shared.error(" [GlobalModelManager] : \(error.localizedDescription)")
        }
    }
    
    /// 强制重新加载市场配置及沙盒状态
    public func reload() async {
        await initializeManager()
    }
    
    /// 物理扫描本地沙盒中大模型的权重文件，结合 UserDefaults 持久化 Flag 执双重对齐
    public func refreshLocalModelFiles() {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let currentFlags = downloadedModelIds
        
        for manifest in remoteManifests {
            let modelId = manifest.modelId
            let fileURL = documentDirectory.appendingPathComponent("\(modelId).bin")
            
            var isFileValid = false
            let hasFile = FileManager.default.fileExists(atPath: fileURL.path)
            
            if hasFile {
                do {
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    let fileSize = (attributes[.size] as? Int64) ?? 0
                    let expectedSize = manifest.fileSizeInBytes
                    
                    if fileSize > 0 && (expectedSize <= 0 || fileSize == expectedSize) {
                        isFileValid = true
                        modelStorageUsage[modelId] = fileSize
                        // 物理文件合法非空，自动自愈补齐持久化 Flag
                        markModelAsDownloaded(modelId)
                    } else {
                        // 物理文件为 0 字节或大小不匹配：强力删除物理残留坏包并移除标志
                        try? FileManager.default.removeItem(at: fileURL)
                        modelStorageUsage.removeValue(forKey: modelId)
                        markModelAsRemoved(modelId)
                        Logger.shared.warning("[GlobalModelManager] 物理清理损坏/大小不匹配的大模型文件: \(modelId) (实际: \(fileSize) B, 期望: \(expectedSize) B)")
                    }
                } catch {
                    Logger.shared.error("[GlobalModelManager] 校验模型权重文件属性失败: \(modelId)，错误: \(error.localizedDescription)")
                }
            } else if currentFlags.contains(modelId) {
                // 若磁盘文件已被物理清理，同步移除已失效的持久化 Flag
                markModelAsRemoved(modelId)
            }
            
            // 物理文件校验合法才认定为完成
            if isFileValid {
                downloadStates[modelId] = .completed(localURL: fileURL)
            } else {
                // 文件不存在或无效，降级为未下载状态（若处于下载中则保持）
                let currentState = downloadStates[modelId]
                let isDownloadingOrActive: Bool
                if let state = currentState {
                    switch state {
                    case .downloading, .paused, .pending:
                        isDownloadingOrActive = true
                    default:
                        isDownloadingOrActive = false
                    }
                } else {
                    isDownloadingOrActive = false
                }
                
                if !isDownloadingOrActive {
                    downloadStates[modelId] = .failed(error: "Not Downloaded")
                }
            }
        }
    }
    
    // MARK: - 后台静默下载管理
    
    /// 发起大模型权重文件后台静默下载
    /// - Parameter manifest: 期望下载的白名单大模型规格元数据
    public func startDownload(for manifest: LLMManifest) {
        let downloadURLString: String
        if isChinaRegion {
            downloadURLString = manifest.modelscopeURLString ?? manifest.remoteURLString
            Logger.shared.info("[GlobalModelManager] China region detected, routing download to ModelScope: \(downloadURLString)")
        } else {
            downloadURLString = manifest.huggingfaceURLString ?? manifest.remoteURLString
            Logger.shared.info("[GlobalModelManager] Non-China region detected, routing download to HuggingFace: \(downloadURLString)")
        }
        
        guard let url = URL(string: downloadURLString) else { return }
        let modelId = manifest.modelId
        
        // 1. 如果该模型不支持该硬件物理内存 (restricted)，强力拦截，杜绝 OOM 爆内存
        if evaluateEligibility(for: manifest) == .restricted {
            Logger.shared.warning(" [GlobalModelManager]  \(modelId) ")
            return
        }
        
        // 2. 启动后台物理下载与指纹注册（在异步任务中执行，以支持 actor 隔离调用）
        Task {
            // registerChecksum 是 actor-isolated，必须 await
            if let manager = downloadManager as? ModelDownloadManager {
                await manager.registerChecksum(for: modelId, checksum: manifest.sha256Checksum)
            }
            do {
                try await downloadManager.startDownload(modelId: modelId, remoteURL: url)
                // 3. 实时观察进度流
                observeDownloadState(for: modelId)
            } catch {
                downloadStates[modelId] = .failed(error: error.localizedDescription)
            }
        }
    }
    
    /// 暂停下载
    public func pauseDownload(for modelId: String) {
        Task {
            try? await downloadManager.pauseDownload(modelId: modelId)
        }
    }
    
    /// 恢复续传下载
    public func resumeDownload(for modelId: String) {
        Task {
            try? await downloadManager.resumeDownload(modelId: modelId)
            observeDownloadState(for: modelId)
        }
    }
    
    /// 取消下载并清理沙盒碎片
    public func cancelDownload(for modelId: String) {
        Task {
            try? await downloadManager.cancelDownload(modelId: modelId)
            downloadStates[modelId] = .failed(error: "Cancelled")
        }
    }
    
    /// 对指定模型启动异步下载状态流的消费订阅
    private func observeDownloadState(for modelId: String) {
        Task {
            let stream = await downloadManager.observeDownloadState(for: modelId)
            for await state in stream {
                // 确保在主线程更新 `@Observable` 响应式状态以驱动 UI 安全重绘
                await MainActor.run {
                    self.downloadStates[modelId] = state
                    if case .completed = state {
                        self.markModelAsDownloaded(modelId)
                    }
                }
            }
        }
    }
    
    // MARK: - 兼容度与就绪状态查询
    
    /// 判定目标模型对当前物理硬件的运存支持度 (.supported / .warning / .restricted)
    public func evaluateEligibility(for manifest: LLMManifest) -> DeviceEligibility {
        return hardwareGuard.evaluateEligibility(for: manifest)
    }
    
    /// 判断特定模型是否已下载并在端侧完全就绪
    /// - Parameter modelId: 模型唯一代号
    public func isModelLocalReady(for modelId: String) -> Bool {
        if case .completed = downloadStates[modelId] {
            return true
        }
        return false
    }
    
    /// 获取已在沙盒就绪的本地大模型物理路径 URL
    /// - Parameter modelId: 模型唯一代号
    public func getLocalModelURL(for modelId: String) -> URL? {
        if case let .completed(url) = downloadStates[modelId] {
            return url
        }
        return nil
    }
    
    // MARK: - 智能端云路由决策 (2.4 契约)
    
    /// 端云混合混合智能路由决策
    /// - Parameter taskTag: 推理任务标签 (如: "Tagging", "Synthesis", "Chat")
    /// - Returns: 是否应该分流路由到云端 (true 代表云端 API，false 代表端侧本地运行)
    public func shouldRouteToCloud(for taskTag: String) -> Bool {
        // 1. 语义分块 (Chunking) 与 反链发现 (LinkDiscovery) 强锁定本地端侧，绝对不下发云端，保证最高隐私安全与免资后台运行
        if taskTag == "Chunking" || taskTag == "LinkDiscovery" {
            return false
        }
        
        // 2. 合成实验室 (Synthesis) 属于端云混合中枢
        if taskTag == "Synthesis" {
            // 若用户开启了 ""，且本地活跃大模型未就绪或者强网络状态下，路由至云端以确保高质量考据
            return isCloudEscalationEnabled
        }
        
        // 3. 通用 Chat 或其它场景：如果本地活跃大模型未在端侧就绪，则自动溢出路由到云端，保证对话流畅度
        if !isModelLocalReady(for: activeModelId) {
            return true
        }
        
        return false
    }
}
