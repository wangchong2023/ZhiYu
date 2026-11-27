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
import Dependencies

/// 全局大模型状态控制中枢，使用 Swift 17 @Observable 宏，全局唯一并以 Environment/DI 形式分发
@MainActor
@Observable
public final class GlobalModelManager: TestStateResettable {
    
    /// 全局共享实例
    public static let shared = runOnMainSync { GlobalModelManager() }
    
    // MARK: - 依赖注入
    
    @ObservationIgnored @Dependency(\.remoteConfig) private var remoteConfig: any RemoteConfigCapabilities
    @ObservationIgnored @Dependency(\.modelDownload) var downloadManager: any ModelDownloadCapabilities
    /// Factory 风格：属性类型标注为可选（T?）， 自动使用 resolveOptional
    @ObservationIgnored @Dependency(\.keyStore) var keyStore: (any KeyStoreProtocol)?
    
    // MARK: - 全局响应式属性
    
    /// 远程拉取的端侧模型白名单列表
    public internal(set) var remoteManifests: [LLMManifest] = []
    
    /// 模型 ID 到对应下载进度状态的映射映射表
    public internal(set) var downloadStates: [String: DownloadState] = [:]
    
    /// 是否正在加载白名单
    public private(set) var isLoading: Bool = false
    
    /// 物理设备总内存大小 (字节)
    public let physicalMemory: UInt64
    
    /// 已下载模型的存储占用（字节），按 modelId 索引
    public internal(set) var modelStorageUsage: [String: Int64] = [:]

    /// 当前是否已配置 HuggingFace 访问令牌（用于下载 gated 模型）
    public internal(set) var hasHuggingFaceToken: Bool = false

    /// 当前是否已配置魔搭社区（ModelScope）SDK 令牌
    public internal(set) var hasModelScopeToken: Bool = false

    /// 模型调用次数统计，按 modelId 索引
    public private(set) var modelCallCounts: [String: Int] = [:]

    /// 已订阅下载状态流的模型 ID 集合，防止重复订阅产生僵尸 Task
    var subscribedModelIds: Set<String> = []

    /// 待触发的备用镜像源映射表（当主下载源在异步 HTTP 响应阶段返回 4xx/5xx 时自动容灾切换）
    var pendingFallbackURLs: [String: URL] = [:]

    /// 物理硬件运存防爆评估拦截服务
    @ObservationIgnored private let hardwareGuard: DeviceHardwareGuard
    
    /// 单元测试专用：允许手动模拟国内/国外环境
    internal var isChinaRegionOverride: Bool?

    /// 判断当前是否处于中国大陆地区，用于决定大模型下载源路由（多维特征综合判定：地区代码 / 语言代码 / 首选语言 / 时区）
    internal var isChinaRegion: Bool {
        if let override = isChinaRegionOverride {
            return override
        }
        // 1. 地区标识检测 (iOS 16+ region code)
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
            if Locale.current.region?.identifier == FeatureConstants.LocaleIdentifier.cn {
                return true
            }
        }
        
        // 2. 语言与区域代码检测 (zh-Hans / zh_CN / zh-Hans-CN)
        let localeId = Locale.current.identifier
        if localeId.contains(FeatureConstants.LocaleIdentifier.cn) ||
           localeId.contains(FeatureConstants.LocaleIdentifier.zhHans) ||
           localeId.contains(FeatureConstants.LocaleIdentifier.zhHansCN) {
            return true
        }

        // 3. 用户首选语言列表检测 (zh / zh-Hans / zh-Hant)
        if let preferred = Locale.preferredLanguages.first, preferred.hasPrefix(FeatureConstants.LocaleIdentifier.zh) {
            return true
        }

        // 4. 时区特征检测 (中国标准时区 Asia/Shanghai, Asia/Chongqing 等)
        let timeZoneId = TimeZone.current.identifier
        if FeatureConstants.LocaleIdentifier.chinaTimeZones.contains(timeZoneId) {
            return true
        }

        return false
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

        // 单例自注册到测试状态重置注册表（仅 shared 实例触发）
        TestStateResetRegistry.shared.register(self)

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
            let list = keyStore?.object(forKey: Self.downloadedModelIdsKey) as? [String] ?? []
            return Set(list)
        }
        set {
            keyStore?.set(Array(newValue), forKey: Self.downloadedModelIdsKey)
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
        // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
        let remoteConfig = ServiceContainer.shared.resolveOptional((any RemoteConfigCapabilities).self) ?? RemoteConfigService.shared

        do {
            // 1. 静默拉取白名单（支持极致的离线兜底 fallback），并合并本地持久化的 BYOM 自定义模型
            let fetched = try await remoteConfig.fetchLLMManifests()
            let customManifests = loadPersistedCustomManifests()
            let customIds = Set(customManifests.map(\.modelId))
            self.remoteManifests = customManifests + fetched.filter { !customIds.contains($0.modelId) }
            
            // 2. 扫描本地沙盒文件，对齐下载状态
            refreshLocalModelFiles()
        } catch {
            Logger.shared.error(" [GlobalModelManager] : \(error.localizedDescription)")
        }
    }
    
    /// 强制重新加载市场配置及沙盒状态
    public func reload() async {
        if remoteManifests.isEmpty {
            await initializeManager()
        } else {
            refreshLocalModelFiles()
        }
    }
    
    /// 物理扫描本地沙盒中大模型的权重文件，结合 UserDefaults 持久化 Flag 执双重对齐
    public func refreshLocalModelFiles() {
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let currentFlags = downloadedModelIds
        
        for manifest in remoteManifests {
            syncLocalModelState(for: manifest, directory: documentDirectory, currentFlags: currentFlags)
        }
    }

    /// 校验并对齐单个大模型在本地沙盒中的物理状态（兼容 .litertlm / .task / .gguf / .bin）
    private func syncLocalModelState(for manifest: LLMManifest, directory: URL, currentFlags: Set<String>) {
        let modelId = manifest.modelId
        let fileURL = Self.resolveLocalModelURL(for: modelId, in: directory)
            ?? directory.appendingPathComponent(modelId + FeatureConstants.ModelSpecConstants.modelBinExtension)

        let isFileValid = validateAndAlignDiskFile(manifest: manifest, fileURL: fileURL, currentFlags: currentFlags)

        if isFileValid {
            downloadStates[modelId] = .completed(localURL: fileURL)
        } else {
            alignIncompleteDownloadState(for: modelId)
        }
    }

    /// 按优先级定位本地模型文件，保留原始扩展名并兼容存量 `.bin` 文件
    public static func resolveLocalModelURL(for modelId: String, in directory: URL) -> URL? {
        let fm = FileManager.default
        for ext in BYOMConstants.supportedExtensions {
            let candidate = directory.appendingPathComponent(modelId + ext)
            if fm.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
        return nil
    }

    /// 校验沙盒物理权重文件合法性并执行自愈与坏包清理（基于魔数探针与权威收据，绝不静默删除用户文件）
    private func validateAndAlignDiskFile(manifest: LLMManifest, fileURL: URL, currentFlags: Set<String>) -> Bool {
        let modelId = manifest.modelId
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            if currentFlags.contains(modelId) {
                markModelAsRemoved(modelId)
            }
            ModelReceiptStore.shared.removeReceipt(for: modelId)
            return false
        }

        // 1. 魔数格式探针校验：读取头部魔数与结构有效性（O(1) 防残卷与空壳）
        let probeResult = ModelFormatProbe.shared.inspect(fileURL: fileURL)
        switch probeResult {
        case .notFound:
            return false
        case .corrupted(let reason):
            // 异常透明标记：绝不静默删除用户文件！保留现场并标记失败状态
            Logger.shared.warning("[GlobalModelManager] 模型 \(modelId) 探针检测损坏 (\(reason))，透明标记为异常，不执行静默删除")
            downloadStates[modelId] = .failed(error: L10n.ModelManager.Status.fileCorrupted)
            return false
        case .valid(let format):
            // 2. 权威完成凭证比对 (Receipt Matching)
            let actualFileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
            if let receipt = ModelReceiptStore.shared.getReceipt(for: modelId) {
                if actualFileSize == receipt.exactFileSize {
                    modelStorageUsage[modelId] = actualFileSize
                    markModelAsDownloaded(modelId)
                    return true
                } else {
                    Logger.shared.warning("[GlobalModelManager] 模型 \(modelId) 物理大小 (\(actualFileSize) B) 与权威收据 (\(receipt.exactFileSize) B) 不匹配，判定为截断损坏")
                    downloadStates[modelId] = .failed(error: L10n.ModelManager.Status.fileCorrupted)
                    return false
                }
            } else {
                // 3. 针对存量或预置模型：魔数探针有效，自动补发收据凭证并盖戳
                let receipt = ModelDownloadReceipt(
                    modelId: modelId,
                    exactFileSize: actualFileSize,
                    completedAt: Date(),
                    sha256Checksum: nil,
                    format: format
                )
                ModelReceiptStore.shared.saveReceipt(receipt)
                modelStorageUsage[modelId] = actualFileSize
                markModelAsDownloaded(modelId)
                return true
            }
        }
    }

    /// 对齐未完成或无效模型的下载状态
    private func alignIncompleteDownloadState(for modelId: String) {
        let currentState = downloadStates[modelId]
        switch currentState {
        case .downloading, .paused, .pending, .verifying, .failed:
            // 保持现有进行中或具体错误状态（如损坏异常），不执行破坏性重置
            return
        default:
            downloadStates[modelId] = .failed(error: FeatureConstants.DefaultValue.notDownloaded)
        }
    }
    
    // MARK: - 兼容度与就绪状态查询
    
    /// 重置响应式内部状态
    /// - Note: 清空远程清单、下载状态、存储占用与调用计数
    func reset() {
        remoteManifests = []
        downloadStates = [:]
        modelStorageUsage = [:]
        modelCallCounts = [:]
        isLoading = false
        subscribedModelIds = []
        pendingFallbackURLs = [:]
    }

    // MARK: - TestStateResettable

    /// 重置单例状态用于测试隔离
    nonisolated public func resetStateForTesting() {
        runOnMainSync {
            reset()
        }
    }
    
    /// 判定目标模型对当前物理硬件的运存支持度 (.supported / .warning / .restricted)
    public func evaluateEligibility(for manifest: LLMManifest) -> DeviceEligibility {
        return hardwareGuard.evaluateEligibility(for: manifest)
    }
    
    /// 判断特定模型是否已下载并在端侧完全就绪（基于内存状态、魔数探针与权威收据多重核验）
    public func isModelLocalReady(for modelId: String) -> Bool {
        if case .completed = downloadStates[modelId] {
            return true
        }
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        guard let fileURL = Self.resolveLocalModelURL(for: modelId, in: docDir) else { return false }

        // 1. 使用魔数格式探针核验证明，杜绝半截残卷或伪造空壳误判为就绪
        let probe = ModelFormatProbe.shared.inspect(fileURL: fileURL)
        guard case .valid = probe else { return false }

        // 2. 若存在权威收据，物理文件字节数必须精准对齐凭据
        let actualFileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int64) ?? 0
        if let receipt = ModelReceiptStore.shared.getReceipt(for: modelId) {
            guard actualFileSize == receipt.exactFileSize else {
                return false
            }
        }

        downloadStates[modelId] = .completed(localURL: fileURL)
        return true
    }
    
    /// 获取已在沙盒就绪的本地大模型物理路径 URL
    public func getLocalModelURL(for modelId: String) -> URL? {
        if case let .completed(url) = downloadStates[modelId] {
            return url
        }
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return Self.resolveLocalModelURL(for: modelId, in: docDir)
    }

    /// 清理指定模型的本地沙盒权重与缓存（用户显式请求时执行物理清理与凭据移除）
    public func clearModelCache(for modelId: String) {
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        for ext in BYOMConstants.supportedExtensions {
            let fileURL = docDir.appendingPathComponent(modelId + ext)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
            }
        }
        ModelReceiptStore.shared.removeReceipt(for: modelId)
        modelStorageUsage.removeValue(forKey: modelId)
        markModelAsRemoved(modelId)
        downloadStates[modelId] = .failed(error: FeatureConstants.DefaultValue.notDownloaded)
        if modelId.hasPrefix(BYOMConstants.customModelPrefix) {
            removePersistedCustomManifest(modelId: modelId)
            remoteManifests.removeAll { $0.modelId == modelId }
        }
    }
    
    // MARK: - 智能端云路由决策 (2.4 契约)
    
    /// 端云混合混合智能路由决策
    /// - Parameter taskTag: 推理任务标签 (如: "Tagging", "Synthesis", "Chat")
    /// - Returns: 是否应该分流路由到云端 (true 代表云端 API，false 代表端侧本地运行)
    public func shouldRouteToCloud(for taskTag: String) -> Bool {
        // 1. 语义分块 (Chunking) 与 反链发现 (LinkDiscovery) 强锁定本地端侧，绝对不下发云端，保证最高隐私安全与免资后台运行
        if taskTag == FeatureConstants.TaskTag.chunking || taskTag == FeatureConstants.TaskTag.linkDiscovery {
            return false
        }
        
        // 2. 合成实验室 (Synthesis) 属于端云混合中枢
        if taskTag == FeatureConstants.TaskTag.synthesis {
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
