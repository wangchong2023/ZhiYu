//
//  KnowledgeStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：数据模型与状态管理，定义数据结构与 @Observable 状态。
//
import Foundation
import UFPCore
import Combine
import Observation
import Dependencies

/// 知识页面状态存储中心 (L2-Feature Store)
/// 负责管理全量页面状态、搜索缓存及 UI 交互状态。
@Observable
@MainActor
public final class KnowledgeStore {

    @ObservationIgnored @Dependency(\.toastService) private var toastManager

    // MARK: - 状态属性
    
    /// 全量页面镜像
    public var pages: [KnowledgePage] = []
    
    /// 页面总数
    public var totalPages: Int = 0
    
    /// 全文总字数
    public var totalWords: Int = 0
    
    /// 是否正在执行 AI 扫描/处理
    public var isScanning: Bool = false
    
    /// 是否显示创建页面表单
    public var showCreateSheet: Bool = false
    
    // MARK: - 核心依赖 (DI)

    /// [L1.5] 知识库领域仓储 — 遵循 DIP，L2 不再直接依赖 L1 SQLiteStore
    @ObservationIgnored @Dependency(\.pageStoreCapabilities) private var pageStore: any AnyPageStoreCapabilities
    @ObservationIgnored @Dependency(\.pageManager) private var pageManager: KnowledgePageManager
    /// Factory 风格：可选依赖，测试环境或 DI 未就绪时为 nil。
    /// 注册点在 KnowledgeModuleRegistrar，但测试路径可能跳过注册链。
    @ObservationIgnored @Dependency(\.maintenanceService) private var maintenanceService: MaintenanceService
    @ObservationIgnored @Dependency(\.settingsStore) private var settingsStore: SettingsStore
    /// Factory 风格：属性类型标注为可选（T?）， 自动使用 resolveOptional
    @ObservationIgnored @Dependency(\.keyStore) private var keyStore: (any KeyStoreProtocol)?

    // MARK: - 私有属性
    
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    public init() {
        Logger.shared.info(" [KnowledgeStore] Initializing...")
        // 诊断：记录当前 DI 容器状态
        #if DEBUG
        let isProductionLocked = ServiceContainer.shared.isProductionChainLocked  // inject_exempt: DI 诊断
        Logger.shared.info(" [KnowledgeStore] DI container state: productionChainLocked=\(isProductionLocked), serviceCount=\(ServiceContainer.shared.diagnosticSnapshot.count)")  // inject_exempt: DI 诊断
        #endif
        setupSubscriptions()
    }

    deinit {
        Logger.shared.info(" [KnowledgeStore] Deinitializing and cancelling subscriptions...")
    }

    private func setupSubscriptions() {
        // 订阅全局事件总线
        AppEventBus.shared.subscribe()
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .pagesCleared:
                    self.pages = []
                    self.totalPages = 0
                    self.totalWords = 0
                case .pageCreated, .pageUpdated, .pageDeleted:
                    Task { [weak self] in
                        await self?.refresh()
                    }
                case .clearAllDataRequested:
                    self.clearAllData()
                default: break
                }
            }
            .store(in: &cancellables)
            
        // 监听物理库热切换
        NotificationCenter.default.publisher(for: .databaseDidSwitch)
            .receive(on: RunLoop.main)
            .sink { [weak self] notification in
                guard let self = self else { return }
                Logger.shared.info(" [KnowledgeStore] Database switched, clearing cache...")
                self.pages = []
                self.totalPages = 0
                self.totalWords = 0
                Task { [weak self] in
                    guard let self = self else { return }
                    await self.refresh()
                    
                    // 🎬 RAG 冷启动魔法时刻 (Aha Moment)：
                    // 在新建笔记本首次切换进入时，如果数据库为空且未播种过，则自动注入欢迎与引导数据
                    // 防御性校验：在应用冷启动尚未完成 DI 注册前，避开早期的数据库卡片准备通知引发的竞态注入
                    guard ServiceContainer.shared.isReady || ProcessInfo.processInfo.arguments.contains(FeatureConstants.UITestingArg.uiTesting) else {  // inject_exempt: DI 就绪性检查
                        return
                    }

                    if let vaultID = notification.userInfo?["vaultID"] as? UUID {
                        let isTesting = TestModeDetector.isUITesting
                        let seedKey = "seeded_vault_\(vaultID.uuidString)"
                        if !(keyStore?.bool(forKey: seedKey) ?? false) || isTesting {
                            Logger.shared.info(" [KnowledgeStore] Seeding guide data for vault \(vaultID.uuidString)...")
                            let vaultName = VaultService.shared.vaults.first(where: { $0.id == vaultID })?.name
                            await self.seedDefaultContent(vaultName: vaultName)
                            keyStore?.set(true, forKey: seedKey)
                            
                            // 🎬 播种完毕后，重新从物理库同步加载内存镜像，同时会自动同步刷新活跃笔记本的页面计数
                            await self.refresh()
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - 基础管理

    /// 注册页面处理器 (Phase 3)
    public func registerProcessor(_ processor: any KnowledgePageProcessor, pluginID: String? = nil) {
        pageManager.registerProcessor(processor, pluginID: pluginID)
    }

    /// 注销页面处理器 (Phase 3)
    public func unregisterProcessor(id: String) {
        pageManager.unregisterProcessor(id: id)
    }

    /// 注销指定插件的所有处理器 (Phase 3)
    public func unregisterProcessors(for pluginID: String) {
        pageManager.unregisterProcessors(for: pluginID)
    }

    /// 刷新内存镜像
    public func refresh() async {
        let startTime = Date()

        // 🛡️ 防御性检查：在全量测试并发场景下，DI 容器可能被前置测试破坏
        // 使用 optionalResolve 避免因服务未注册导致 fatalError
        // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
        guard let pageStore = ServiceContainer.shared.resolveOptional((any AnyPageStoreCapabilities).self),
              let knowledgeRepo = ServiceContainer.shared.resolveOptional((any KnowledgeRepository).self) else {
            Logger.shared.warning("[KnowledgeStore] refresh() skipped: required services missing from DI container (likely due to test interference)")
            return
        }

        // 🚨 强制同步底层物理缓存：确保 pageStore (SQLiteStore) 内部内存镜像与磁盘完成重载
        // 这对于直接通过 DB 裸物理连接写入数据（如 Demo 演示数据播种写入）后的数据一致性至关重要
        await pageStore.reloadFromDisk()

        self.pages = (try? await knowledgeRepo.fetchAll()) ?? []
        self.totalPages = pages.count
        self.totalWords = pages.reduce(0) { $0 + $1.content.count }

        // 同步刷新当前活跃笔记本的页面计数并落库以保证 UI 数据一致性
        if let selectedVaultID = VaultService.shared.selectedVaultID {
            await VaultService.shared.refreshPageCount(for: selectedVaultID)
        }

        let duration = Date().timeIntervalSince(startTime)
        if let perf = ServiceContainer.shared.resolveOptional(PerformanceService.self) {  // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
            perf.record(.databaseLoad, duration: duration)
        }
    }

    /// 填充默认内容
    public func seedDefaultContent(vaultName: String? = nil) async {
        await maintenanceService.seedDefaultContent(pages: pages, vaultName: vaultName)
        await refresh()
    }

    // MARK: - 核心业务逻辑

    /// 根据标题查找页面
    public func pageByTitle(_ title: String) async -> KnowledgePage? {
        await pageManager.pageByTitle(title, in: pages)
    }

    /// 创建页面
    @discardableResult

    /// 创建Page
    public func createPage(
        title: String,
        pageType: PageType,
        customIcon: String? = nil,
        content: String = "",
        tags: [String] = [],
        sourceURL: String? = nil,
        rawSnippet: String? = nil,
        fileSize: Int64? = nil,
        sourceType: String? = nil
    ) async -> KnowledgePage {
        let page = (try? await pageManager.createPage(
            title: title,
            pageType: pageType,
            customIcon: customIcon,
            content: content,
            tags: tags,
            sourceURL: sourceURL,
            rawSnippet: rawSnippet,
            fileSize: fileSize,
            sourceType: sourceType,
            currentPages: pages
        )) ?? KnowledgePage(title: title)

        // 检查是否需要显示图谱引导 (@SRS-UI-01)
        if totalPages >= FeatureConstants.KnowledgeCoachMark.minPagesForGraphCoachMark && !settingsStore.hasShownGraphCoachMark {
            // 此处逻辑暂留，AppStore 可能会处理全局引导弹窗
            // 我们只负责触发事件或状态更新
            NotificationCenter.default.post(name: NSNotification.Name("ShowGraphCoachMark"), object: nil)
        }

        await refresh()

        // 里程碑检查
        if let milestone = OnboardingMilestone.checkPageCountMilestone(totalPages) {
            if !milestone.hasBeenShown {
                toastManager.show(type: .success, message: milestone.toastMessage)
                milestone.markAsShown()
            }
        }

        return page
    }

    /// 更新页面
    public func updatePage(_ page: KnowledgePage) async {
        try? await pageManager.updatePage(page, currentPages: pages)
        await refresh()
    }

    /// 保存页面
    public func savePage(_ page: KnowledgePage) async {
        try? await pageManager.savePage(page, currentPages: pages)
        await refresh()
    }

    /// 删除页面
    public func deletePage(_ page: KnowledgePage) async {
        try? await pageManager.deletePage(page, currentPages: pages)
        await refresh()
    }

    /// 重命名页面
    public func renamePage(_ page: KnowledgePage, to newTitle: String) async {
        try? await pageManager.renamePage(page, to: newTitle, currentPages: pages)
        await refresh()
    }

    // MARK: - 事务与同步

    /// 撤销
    public func undo() async {
        if let newPages = try? await pageManager.undo(currentPages: pages) {
            self.pages = newPages
            await refresh()
        }
    }

    /// 重做
    public func redo() async {
        if let newPages = try? await pageManager.redo(currentPages: pages) {
            self.pages = newPages
            await refresh()
        }
    }

    /// 保存ToDisk
    public func saveToDisk() async {
        await maintenanceService.saveToDisk(pages: pages)
    }

    /// 加载FromDisk
    public func loadFromDisk() async { 
        await maintenanceService.loadFromDisk()
        await refresh()
    }

    // MARK: - 业务协同

    /// 应用Potential链接
    /// - Parameter suggestion: suggestion
    public func applyPotentialLink(_ suggestion: PotentialLinkSuggestion) async {
        try? await pageManager.applyPotentialLink(suggestion, currentPages: pages)
        await refresh()
    }

    /// 应用重构Suggestion
    /// - Parameter suggestion: suggestion
    public func applyRefactorSuggestion(_ suggestion: RefactorSuggestion) async {
        try? await pageManager.applyRefactorSuggestion(suggestion, currentPages: pages)
        await refresh()
    }

    /// 导入摄取Folder
    public func ingestFolder(at url: URL) async {
        // 转发至领域层 KnowledgePageManager 执行物理和向量导入流程
        // 注意：此处仍需传递 pageStore (通常是 AppStore 或 self) 以满足协议
        // 为保持解耦，我们传递 ServiceContainer 中的 AnyPageStore 实例
        if let store = ServiceContainer.shared.resolveOptional(AppStore.self) {  // inject_exempt: DI 就绪性检查（Key 返回非可选，测试时未注册会崩溃，故保留 resolveOptional）
            await pageManager.ingestFolder(at: url, pageStore: store)
        }
        await refresh()
    }

    private func clearAllData() {
        Task {
            await maintenanceService.clearAllDeveloperData()
            await refresh()
        }
    }
}

// MARK: - DependencyKey 注册

/// KnowledgeStore 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析）
public enum KnowledgeStoreKey: DependencyKey {
    @MainActor
    public static var liveValue: KnowledgeStore {
        ServiceContainer.shared.resolve(KnowledgeStore.self)
    }

    @MainActor
    public static var testValue: KnowledgeStore {
        ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
    }
}

extension DependencyValues {
    /// 知识存储依赖
    public var knowledgeStore: KnowledgeStore {
        get { self[KnowledgeStoreKey.self] }
        set { self[KnowledgeStoreKey.self] = newValue }
    }
}
