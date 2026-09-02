//
//  AppStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：全局状态管理（AppStore），持有应用级 @Observable 状态树与子 Store 聚合。
//            本文件保留核心类型声明、DI 注入、初始化与事件订阅逻辑。
//
import SwiftUI
import UFPCore
import Combine
import Observation
import Dependencies
import UFPStorage

/// 智宇核心状态中心 (L3-Facade)
/// 负责全局状态同步、跨服务协调及业务流程封装。
@Observable
@MainActor
public final class AppStore {

    // MARK: - 辅助类型

    /// 引导层类型定义
    public enum CoachMarkType: String, Sendable {
        case graphDiscovery = "graph_discovery"
    }

    // ToolItem 已下移至 L1.5 Domain 层 (Sources/Domain/Models/ToolItem.swift)
    // 原 AppStore.ToolItem 引用可直接使用 ToolItem（同模块内顶级类型）

    /// 知识增长点数据模型
    public struct KnowledgeGrowthPoint: Identifiable {
        public let id = UUID()
        public let date: Date
        public let count: Int

        public init(date: Date, count: Int) {
            self.date = date
            self.count = count
        }
    }

    // ── UI 状态 ──
    public var pendingCoachMark: CoachMarkType?

    /// 日志条目缓存（Cache Proxy 模式）
    /// 订阅 Logger.logEntriesPublisher，作为 UI 层同步访问的 source of truth
    public var logEntries: [LogEntry] = []

    // ── 转发指标 (由 KnowledgeStore 持有，@Observable 自动追踪) ──
    public var pages: [KnowledgePage] { knowledgeStore.pages }
    public var totalPages: Int { knowledgeStore.totalPages }
    public var totalWords: Int { knowledgeStore.totalWords }
    public var isScanning: Bool { knowledgeStore.isScanning }
    public var isScanningAI: Bool { isScanning }
    public var showCreateSheet: Bool {
        get { knowledgeStore.showCreateSheet }
        set { knowledgeStore.showCreateSheet = newValue }
    }

    public var brokenLinkCount: Int { aiInsightStore.brokenLinkCount }
    public var orphanPageCount: Int { aiInsightStore.orphanPageCount }
    public var totalConnectionCount: Int { aiInsightStore.totalConnectionCount }
    public var tags: [String] { Array(tagStore.getAllTags(from: pages).keys).sorted() }
    public var sourceCount: Int { aiInsightStore.sourceCount }
    public var entityCount: Int { aiInsightStore.entityCount }
    public var conceptCount: Int { aiInsightStore.conceptCount }
    public var growthSeries: [KnowledgeGrowthPoint] { aiInsightStore.growthSeries }
    public var lintIssues: [LintIssue] { aiWorkflowStore.lintIssues }
    public var isPrivacyModeEnabled: Bool { settingsStore.isPrivacyModeEnabled }
    public var showPerfDashboard: Bool {
        get { settingsStore.showPerfDashboard }
        set { settingsStore.showPerfDashboard = newValue }
    }

    // ── 核心依赖 (DI) ──
    @ObservationIgnored @Dependency(\.pageStoreCapabilities) var pageStore: any AnyPageStoreCapabilities
    /// Factory 风格：可选依赖，测试环境或 DI 未就绪时为 nil
    @ObservationIgnored @Dependency(\.maintenanceServiceOptional) var maintenanceService: MaintenanceService?
    @ObservationIgnored @Dependency(\.performanceService) var performanceService: PerformanceService
    @ObservationIgnored @Dependency(\.llmService) var llmService: any LLMServiceProtocol
    @ObservationIgnored @Dependency(\.settingsStore) var settingsStore: SettingsStore
    @ObservationIgnored @Dependency(\.linkService) var linkService: LinkService
    @ObservationIgnored @Dependency(\.ingestServiceConcrete) var ingestService: IngestService
    @ObservationIgnored @Dependency(\.vaultStorageSecurityService) var securityService: VaultStorageSecurityService
    @ObservationIgnored @Dependency(\.snapshotService) var snapshotService: SnapshotService

    // ── 职责解耦：子 Store 聚合 ──
    @ObservationIgnored public var searchStore: SearchStore!
    @ObservationIgnored public var aiWorkflowStore: AIWorkflowStore!
    @ObservationIgnored public var tagStore: TagStore!
    @ObservationIgnored public var knowledgeStore: KnowledgeStore!

    public var aiInsightStore: AIInsightStore { aiWorkflowStore.insightStore }

    // ── 私有属性 ──
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    // MARK: - 初始化

    public init() {
        Logger.shared.info(" [AppStore] Initializing core engine...")

        // 1. 初始化子 Store
        self.searchStore = SearchStore()
        self.aiWorkflowStore = AIWorkflowStore()
        self.tagStore = TagStore()
        self.knowledgeStore = KnowledgeStore()

        // 2. 将核心 Store 及子 Store 自动注册到全局 DI 容器中 (@DIP)
        let container = ServiceContainer.shared // inject_exempt: DI 核心初始化代码
        container.register(self, for: AppStore.self)
        container.register(self.searchStore, for: SearchStore.self)
        container.register(self.aiWorkflowStore, for: AIWorkflowStore.self)
        container.register(self.aiWorkflowStore as any AIWorkflowCapabilities, for: (any AIWorkflowCapabilities).self)
        container.register(self.aiWorkflowStore.insightStore, for: AIInsightStore.self)
        container.register(self.tagStore, for: TagStore.self)
        container.register(self.knowledgeStore, for: KnowledgeStore.self)

        // 3. 注册系统事件订阅
        setupSubscriptions()
    }

    private func setupSubscriptions() {
        AppEventBus.shared.subscribe()
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .pagesCleared:
                    break
                case .pageCreated, .pageUpdated, .pageDeleted:
                    Task { [weak self] in
                        await self?.aiInsightStore.updateStatistics()
                    }
                default: break
                }
            }
            .store(in: &cancellables)

        // 动态绑定物理专属数据库热切换监听
        NotificationCenter.default.publisher(for: .databaseDidSwitch)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                Logger.shared.info(" [AppStore] Detected exclusive physical database hot swap success...")
                Task { [weak self] in
                    await self?.aiInsightStore.updateStatistics()
                }
            }
            .store(in: &cancellables)

        // 订阅 Logger 日志流，缓存到本地存储属性供 UI 同步访问（Cache Proxy 模式）
        Logger.shared.logEntriesPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] entries in
                self?.logEntries = entries
            }
            .store(in: &cancellables)
    }

    // MARK: - 基础管理

    /// 刷新
    public func refresh() async {
        await knowledgeStore.refresh()
        await aiInsightStore.updateStatistics()
    }

    /// seedDefaultContent
    func seedDefaultContent(vaultName: String? = nil) async {
        await knowledgeStore.seedDefaultContent(vaultName: vaultName)
    }

    // ── 核心业务逻辑 ──

    /// pageByTitle
    public func pageByTitle(_ title: String) async -> KnowledgePage? {
        await knowledgeStore.pageByTitle(title)
    }

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
        sourceType: String? = nil,
        forceDeepScan _: Bool = false
    ) async -> KnowledgePage {
        await knowledgeStore.createPage(
            title: title,
            pageType: pageType,
            customIcon: customIcon,
            content: content,
            tags: tags,
            sourceURL: sourceURL,
            rawSnippet: rawSnippet,
            fileSize: fileSize,
            sourceType: sourceType
        )
    }

    /// 获取Backlinks
    public func getBacklinks(for id: UUID) async -> [KnowledgePage] { await pageStore.fetchBacklinksByID(for: id) }

    /// 更新Page
    public func updatePage(_ page: KnowledgePage, forceDeepScan _: Bool) async {
        await knowledgeStore.updatePage(page)
    }

    /// 保存Page
    public func savePage(_ page: KnowledgePage) async {
        await knowledgeStore.savePage(page)
    }

    /// 删除Page
    public func deletePage(_ page: KnowledgePage) async {
        await knowledgeStore.deletePage(page)
    }

    /// 撤销
    func undo() async {
        await knowledgeStore.undo()
    }

    /// 重做
    func redo() async {
        await knowledgeStore.redo()
    }

    /// 保存ToDisk
    func saveToDisk() async {
        await knowledgeStore.saveToDisk()
    }

    /// 请求Relayout
    public func requestRelayout() {
        AppEventBus.shared.publish(.graphRelayoutRequested)
    }

    /// 添加记录日志
    public nonisolated func addLog(action: LogAction, target: String, details: String, duration: TimeInterval? = nil, startTime: Date? = nil, endTime: Date? = nil, module: String? = "AppStore") {
        Logger.shared.addLog(action: action, target: target, details: details, duration: duration, startTime: startTime, endTime: endTime, module: module)
    }

    /// 清除Logs
    func clearLogs() async {
        await maintenanceService?.clearLogs()
        logEntries = []
    }
}

// MARK: - ToolItem + AppRoute (L3 路由映射扩展)

extension ToolItem {
    /// 将工具项映射为对应的路由目标，集中管理路由映射逻辑以降低圈复杂度
    var route: AppRoute {
        switch self {
        case .dashboard: return .dashboard
        case .pageList: return .pageList()
        case .lint, .healthCheck: return .lint
        case .taskCenter: return .taskCenter
        case .tagCloud: return .tagCloud
        case .chat: return .chat
        case .synthesis: return .synthesis
        case .weeklyReport: return .weeklyReport
        case .log: return .log
        case .collab: return .collab
        case .pluginMarket: return .pluginMarket
        case .search: return .search()
        case .ingest: return .ingest
        case .graph: return .graph
        case .sources: return .sources
        }
    }
}

// MARK: - DependencyKey

@MainActor
public enum AppStoreKey: DependencyKey {
    @MainActor
    public static var liveValue: AppStore {
        ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
    }

    @MainActor
    public static var testValue: AppStore {
        ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
    }
    @MainActor
    public static var previewValue: AppStore { testValue }
}

extension DependencyValues {
    @MainActor
    public var appStore: AppStore {
        get { self[AppStoreKey.self] }
        set { self[AppStoreKey.self] = newValue }
    }
}
