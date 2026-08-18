//
//  Router.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：App 模块的 Router 实现。
//
import SwiftUI
import UFPCore
import Observation
import Dependencies

/// 业务领域定义
public enum FeatureDomain: String, CaseIterable, Sendable {
    case knowledge
    case ai
    case insight
    case system
}

/// 应用程序路由目标定义
/// 每个 Case 对应系统中的一个物理视图或逻辑页面。
public enum AppRoute: Hashable, Identifiable {
    /// 笔记本工作台 (切换与管理不同笔记本的入口) -> `NotebookHubView`
    case notebookHub

    /// 知识仪表盘 (展示统计图表、活跃度等总览信息) -> `KnowledgeDashboardView`
    case dashboard
    
    /// 知识库页面列表 (展示所有知识条目，支持类型过滤) -> `KnowledgePageListView`
    case pageList(filterType: PageType? = nil)
    
    /// 知识条目详情页 (查看与编辑具体笔记内容) -> `PageDetailView`
    case pageDetail(id: UUID)
    
    /// 标签云视图 (可视化展示知识标签分布) -> `TagCloudView`
    case tagCloud
    
    /// 任务中心 (管理与知识条目关联的待办事项) -> `TaskCenterView`
    case taskCenter
    
    /// AI 智能对话 (基于 RAG 架构的知识问答) -> `ChatView`
    case chat
    
    /// AI 合成实验室 (深度引用、知识重组与合成) -> `SynthesisView`
    case synthesis
    
    /// 当前 AI 会话信源 (对标 NotebookLM) -> `SourceView`
    case sources
    
    /// 应用设置页面 (个性化、存储与 AI 模型配置) -> `SettingsView`
    case settings
    
    /// 帮助与反馈 -> 系统 Web 视图
    case help
    
    /// 关于应用 (版本、团队及版权信息) -> `AboutView`
    case about
    
    /// 系统运行日志 (用于排查 RAG 管道错误) -> `LogView`
    case log
    
    /// 协作中心 (多人同步与知识共享状态) -> `CollaborationView`
    case collab
    
    /// 知识周报 (AI 自动生成的学习与知识产出总结) -> `WeeklyReportView`
    case weeklyReport
    
    /// 知识巡检 (Lint 检查、无效链接与冲突检测) -> `LintView`
    case lint
    
    /// 插件市场 (扩展 AI 处理器与导入插件) -> `PluginCenterView`
    case pluginMarket
    
    /// 全局搜索中心 (混合搜索与语义过滤) -> `SearchView`
    case search(query: String? = nil, filterType: PageType? = nil)
    
    /// 知识摄取中心 (OCR、PDF 导入、网页裁剪) -> `IngestView`
    case ingest
    
    /// 知识图谱 (可视化展示页面间的关联网络) -> `GraphContainerView`
    case graph
    
    /// 知识测试 (基于页面的 AI 测验)
    case quiz
    
    /// 勋章墙 (展示用户的知识管理成就)
    case medalWall
    public var id: String {
        switch self {
        case .notebookHub: return "notebookHub"
        case .dashboard: return "dashboard"
        case .pageList(let type): return "pageList-\(type?.rawValue ?? "all")"
        case .pageDetail(let id): return "page-\(id.uuidString)"
        case .tagCloud: return "tagCloud"
        case .taskCenter: return "taskCenter"
        case .chat: return "chat"
        case .synthesis: return "synthesis"
        case .settings: return "settings"
        case .help: return "help"
        case .about: return "about"
        case .log: return "log"
        case .collab: return "collab"
        case .weeklyReport: return "weeklyReport"
        case .lint: return "lint"
        case .pluginMarket: return "pluginMarket"
        case .search(let query, let type): return "search-\(query ?? "")-\(type?.rawValue ?? "all")"
        case .ingest: return "ingest"
        case .graph: return "graph"
        case .quiz: return "quiz"
        case .medalWall: return "medalWall"
        case .sources: return "sources"
        }
    }
    
    /// 获取该路由对应的侧边栏选中项
    public var sidebarSelection: SidebarSelection? {
        switch self {
        case .notebookHub, .dashboard, .medalWall: return .tool(.dashboard)
        case .pageList(let type): return type.map { .filteredIndex($0) } ?? .tool(.pageList)
        case .tagCloud: return .tool(.tagCloud)
        case .taskCenter: return .tool(.taskCenter)
        case .chat: return .tool(.chat)
        case .synthesis, .quiz: return .tool(.synthesis)
        case .log: return .tool(.log)
        case .collab: return .tool(.collab)
        case .weeklyReport: return .tool(.weeklyReport)
        case .lint: return .tool(.lint)
        case .pluginMarket: return .tool(.pluginMarket)
        case .search: return .tool(.search)
        case .ingest: return .tool(.ingest)
        case .graph: return .tool(.graph)
        case .sources: return .tool(.sources)
        case .pageDetail(let id): return .page(id)
        case .settings, .help, .about: return nil
        }
    }
    
    /// 获取该路由所属的业务领域
    public var domain: FeatureDomain {
        switch self {
        case .notebookHub, .pageList, .pageDetail, .tagCloud, .ingest, .graph, .search, .sources:
            return .knowledge
        case .chat, .synthesis, .taskCenter, .weeklyReport, .quiz:
            return .ai
        case .dashboard, .log, .lint, .medalWall:
            return .insight
        case .settings, .help, .about, .collab, .pluginMarket:
            return .system
        }
    }
}

/// 应用程序路由管理器
/// 集中管理导航状态，支持解耦跳转与状态持久化
@Observable
@MainActor
final class Router {
    /// 全局单例，方便非视图层级调用（如 DeepLink 处理）
    static let shared = Router()

    // keyStore 已全部通过 resolveOptional() 手动解析，不再使用 @Inject 声明
    @ObservationIgnored @Dependency(\.pluginRegistry) private var pluginRegistry

    /// 核心导航路径
    var path = NavigationPath()
    
    /// 当前侧边栏选中项
    var sidebarSelection: SidebarSelection? {
        didSet {
            // 每次侧边栏选中项发生变动（无论切换还是置空），均需将导航路径清空。
            // 这是为了防止在 iPadOS/Mac Catalyst 上，因详情页导航栈（NavigationPath）历史残留
            // 导致详情页面被之前的 push 页面盖住，从而表现为"点击菜单右侧无变化"的经典 Bug。
            path = NavigationPath()
            
            if let selection = sidebarSelection {
                syncTab(for: selection)
                
                // 触发插件事件：页面打开
                if case .page(let id) = selection {
                    pluginRegistry.emitEvent("onFileOpen", data: id.uuidString)
                }
            }
        }
    }
    
    private func syncTab(for selection: SidebarSelection) {
        switch selection {
        case .tool(let tool):
            switch tool {
            case .chat: selectedTab = .chat
            case .graph: selectedTab = .graph
            case .ingest: selectedTab = .ingest
            case .synthesis: selectedTab = .synthesis
            case .search:
                // 搜索现在被合并到知识库 Tab
                selectedTab = .knowledge
            case .pageList, .dashboard, .lint, .tagCloud, .taskCenter, .weeklyReport, .log, .collab, .pluginMarket:
                selectedTab = .knowledge
            default: break
            }
        case .filteredIndex:
            selectedTab = .knowledge
        case .page:
            selectedTab = .knowledge
        }
    }
    
    /// 当前主 Tab (通过 KeyStore 持久化，防止后台切换后状态丢失)
    /// didSet 使用 resolveOptional：DI 容器未就绪时静默跳过持久化，避免启动崩溃。
    var selectedTab: AppTab = .knowledge {
        didSet {
            if let ks = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) {
                ks.set(selectedTab.rawValue, forKey: AppConstants.Keys.Storage.selectedTab)
            }
            // 切换主 Tab 时自动清空全局的导航路径。
            // 以避免在 iPad 侧边栏/分栏布局下，多个 Tab 共享全局 router.path 导致的导航页重叠干扰问题。
            path = NavigationPath()
        }
    }
    
    /// 空间导航历史 (面包屑)
    var navigationHistory: [KnowledgePage] = []
    
    /// 用于在跳转至 AI 对话时自动发送的预设提示词 (冷启动 Aha Moment)
    var pendingInitialChatPrompt: String?

    /// 强制 UI 刷新标识（主要用于多语言切换）
    var languageForceUpdate: Bool = false
    
    /// 获取当前生效的 Locale，绑定语言刷新以实现响应式更新
    var currentLocale: Locale {
        _ = languageForceUpdate
        return Localized.currentLocale
    }
    
    /// 是否正在显示设置面板
    var isShowingSettingsSheet: Bool = false
    
    /// 是否正在显示用户个人中心菜单
    var isShowingProfileMenu: Bool = false
    
    /// 是否正在显示个人资料面板
    var isShowingProfileSheet: Bool = false
    
    /// 是否正在显示订阅计划面板
    var isShowingPlanSheet: Bool = false
    
    /// 是否正在显示插件中心面板
    var isShowingPluginsSheet: Bool = false
    
    /// 是否正在显示关于我们面板
    var isShowingAboutSheet: Bool = false
    
    /// 是否正在显示人工智能参数设置面板
    var isShowingAISettingsSheet: Bool = false
    
    /// 触发全局语言刷新
    func triggerLanguageRefresh() {
        languageForceUpdate.toggle()
    }
    
    /// 关闭当前显示的 sheet (通过单例路由协调)
    func dismissSheet() {
        isShowingSettingsSheet = false
        isShowingAISettingsSheet = false
    }

    /// 仅用于预览和测试的公开初始化器
    /// 使用 resolveOptional 优雅降级：DI 容器未就绪时（如 AppEnvironment 初始化早期）回退到默认 .knowledge。
    public init() {
        // 从 KeyStore 恢复上次选中的 Tab
        let storedRaw = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)?
            .string(forKey: AppConstants.Keys.Storage.selectedTab)
        self.selectedTab = AppTab(rawValue: storedRaw ?? "") ?? .knowledge
    }
    
    // MARK: - 导航指令
    
    /// 添加到导航历史 (去重并限制长度)
    func addToHistory(_ page: KnowledgePage) {
        // 如果当前已经在历史末尾，则不重复添加
        if navigationHistory.last?.id == page.id { return }
        
        // 限制历史长度 (UX 建议：过多会导致认知负担)
        if navigationHistory.count >= DesignSystem.Metrics.maxBreadcrumbCount { // 5
            navigationHistory.removeFirst()
        }
        navigationHistory.append(page)
    }
    
    /// 清空导航历史
    func clearHistory() {
        navigationHistory.removeAll()
    }
    
    /// 跳转到指定目标
    func navigate(to route: AppRoute) {
        // 如果是详情跳转，则推入路径堆栈；否则作为顶层导航
        if isDetailRoute(route) {
            path.append(route)
        } else {
            // 顶层导航切换
            updateSelection(for: route)
            // 切换顶层时通常清空路径
            path = NavigationPath()
        }
    }
    
    /// 便捷跳转：指定页面
    func navigateToPage(id: UUID) {
        navigate(to: .pageDetail(id: id))
    }
    
    /// 便捷跳转：指定工具
    func navigateToTool(_ tool: ToolItem) {
        sidebarSelection = .tool(tool)
        path = NavigationPath()
    }
    
    /// 返回上一级
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    /// 返回到根路径
    func popToRoot() {
        path = NavigationPath()
    }
    
    // MARK: - 辅助逻辑
    
    private func isDetailRoute(_ route: AppRoute) -> Bool {
        switch route {
        case .pageDetail, .settings, .help, .about: return true
        default: return false
        }
    }
    
    private func updateSelection(for route: AppRoute) {
        if let selection = route.sidebarSelection {
            sidebarSelection = selection
        }
    }
}

// MARK: - DependencyKey

@MainActor
enum RouterKey: DependencyKey {
    @MainActor
    static var liveValue: Router { ServiceContainer.shared.resolve(Router.self) }
}

extension DependencyValues {
    @MainActor
    var router: Router {
        get { self[RouterKey.self] }
        set { self[RouterKey.self] = newValue }
    }
}
