//
//  iPadRouterTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 iPadRouter 开展自动化单元测试验证。
//
import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class iPadRouterTests: XCTestCase {
    
    private var router: Router {
        Router.shared
    }
    
    override func setUp() async throws {
        try await super.setUp()
        // 注册 KeyStoreProtocol Mock 以支持 Router selectedTab 持久化验证
        setupFullMockEnvironment()
        // 每个测试用例开始前，强行初始化/复位 Router 状态，实现严格的状态隔离
        router.popToRoot()
        router.sidebarSelection = nil
        router.clearHistory()
        router.isShowingSettingsSheet = false
    }
    
    override func tearDown() async throws {
        // 测试结束后，将 Router 状态进行复原归零，消灭环境污染
        router.popToRoot()
        router.sidebarSelection = nil
        router.clearHistory()
        router.isShowingSettingsSheet = false
        try await super.tearDown()
    }
    
    func testRouterSyncTabForSidebarSelection() async {
        // 函数头说明: 验证 iPad 侧边栏选中项切换时，主 Tab (selectedTab) 的自动联动同步算法
        // - 验证点: 1. 选中 AI 工具（.chat, .synthesis）时，自动同步主 Tab；
        //          2. 选中多金库过滤索引 (.filteredIndex) 或笔记详情 (.page) 时，主 Tab 同步为 .knowledge；
        //          3. 验证 selectedTab 的联动是否精确对齐。
        
        // 1. 验证 AI 会话工具联动
        router.sidebarSelection = .tool(.chat)
        XCTAssertEqual(router.selectedTab, .chat, "iPad 侧边栏选中 AI 会话时，selectedTab 应同步联动为 .chat")
        
        // 2. 验证图谱工具联动
        router.sidebarSelection = .tool(.graph)
        XCTAssertEqual(router.selectedTab, .graph, "iPad 侧边栏选中知识图谱时，selectedTab 应同步联动为 .graph")
        
        // 3. 验证摄取工具联动
        router.sidebarSelection = .tool(.ingest)
        XCTAssertEqual(router.selectedTab, .ingest, "iPad 侧边栏选中知识摄取时，selectedTab 应同步联动为 .ingest")
        
        // 4. 验证合成实验室工具联动
        router.sidebarSelection = .tool(.synthesis)
        XCTAssertEqual(router.selectedTab, .synthesis, "iPad 侧边栏选中合成实验室时，selectedTab 应同步联动为 .synthesis")
        
        // 5. 验证仪表盘合并至知识库 Tab 展现的逻辑
        router.sidebarSelection = .tool(.dashboard)
        XCTAssertEqual(router.selectedTab, .knowledge, "仪表盘属于知识宇宙的一环，应合并在 .knowledge Tab")
        
        // 6. 验证侧边栏按分类索引过滤时联动知识库 Tab
        router.sidebarSelection = .filteredIndex(.concept)
        XCTAssertEqual(router.selectedTab, .knowledge, "按分类过滤时，selectedTab 应保持在知识库 .knowledge")
        
        // 7. 验证选择具体笔记时联动知识库 Tab
        let mockPageId = UUID()
        router.sidebarSelection = .page(mockPageId)
        XCTAssertEqual(router.selectedTab, .knowledge, "在侧边栏点击具体笔记后，主 Tab 应保持在 .knowledge 且侧边栏显示选中态")
        
        // 8. 验证搜索工具联动
        router.sidebarSelection = .tool(.search)
        XCTAssertEqual(router.selectedTab, .knowledge, "搜索功能应合并在 .knowledge Tab 中显示")
        
        // 9. 验证其他工具分支的 syncTab 行为
        let otherTools: [ToolItem] = [
            .pageList, .lint, .tagCloud, .taskCenter, .weeklyReport, .log, .collab, .pluginMarket
        ]
        for tool in otherTools {
            router.sidebarSelection = .tool(tool)
            XCTAssertEqual(router.selectedTab, .knowledge, "工具 \(tool.rawValue) 联动后 selectedTab 应该被判定为 .knowledge")
        }
    }
    
    func testRouterNavigationHistoryLimit() async {
        /// 函数头说明: 测试在大屏连续多级浏览时面包屑导航历史（navigationHistory）的去重与容量上限机制
        /// - 验证点: 1. 历史长度上限被严格限制在 maxBreadcrumbCount (5个) 以内，防止内存暴涨与大屏渲染断层；
        ///          2. 重复访问最新页面自动触发去重；
        ///          3. 超限后，最老的历史页面应被安全丢弃。
        
        let maxCount = DesignSystem.Metrics.maxBreadcrumbCount

        // 1. 连续创建并浏览超出上限的 Mock 笔记
        var mockPages: [KnowledgePage] = []
        for i in 1...(maxCount + 1) {
            let page = KnowledgePage(
                id: UUID(),
                title: "Mock笔记-\(i)",
                content: "笔记内容测试"
            )
            mockPages.append(page)
        }
        
        // 依次加入历史
        for page in mockPages {
            router.addToHistory(page)
        }
        
        // 2. 验证大屏面包屑上限拦截
        XCTAssertEqual(router.navigationHistory.count, maxCount, "大屏面包屑导航历史数量必须被拦截在上限 \(maxCount) 个以内")
        XCTAssertEqual(router.navigationHistory.first?.title, "Mock笔记-2", "超限后，最先被添加的『Mock笔记-1』应该已经被剔除")
        XCTAssertEqual(router.navigationHistory.last?.title, "Mock笔记-\(maxCount + 1)", "大屏面包屑末尾应该精确呈现最新浏览的『Mock笔记-\(maxCount + 1)』")
        
        // 3. 验证大屏浏览相同笔记时的重复去重机制
        router.addToHistory(mockPages[maxCount]) // 再次加入最新的笔记
        XCTAssertEqual(router.navigationHistory.count, maxCount, "浏览当前已处于栈顶的笔记时不应产生历史冗余")
    }
    
    func testRouterDeepLinkNavigateAndStackPop() async {
        // 函数头说明: 测试外部深链接 (Deep Link) 调度解析与 NavigationPath 大屏导航压栈生命周期
        // - 验证点: 1. 进入子路由详情页 (如 pageDetail) 时，路由正常 append 并压入 path 导航栈；
        //          2. 切换回根目录页面 (如 dashboard) 时，导航栈被安全清空以防状态混乱；
        //          3. 验证 pop 操作在导航栈出栈时的准确响应。
        
        // 1. 模拟深链接分流，直接推送子笔记详情页进入 NavigationStack
        let mockPageId = UUID()
        router.navigate(to: .pageDetail(id: mockPageId))
        
        XCTAssertEqual(router.path.count, 1, "跳转详情页面时，应将路由压入 NavigationPath 栈")
        
        // 2. 模拟点击顶层导航，切换至根仪表盘
        router.navigate(to: .dashboard)
        XCTAssertEqual(router.path.count, 0, "切回顶层主路由时，NavigationPath 应该清空重置，避免堆栈残留")
        XCTAssertEqual(router.sidebarSelection, .tool(.dashboard), "侧边栏选中状态应自动对齐为 .dashboard")
        
        // 3. 多级堆栈压栈与出栈测试
        router.navigate(to: .pageDetail(id: UUID()))
        router.navigate(to: .about) // 关于页面也属于 detailRoute 子路由
        XCTAssertEqual(router.path.count, 2, "两层详情页跳转后，导航堆栈深度应为 2")
        
        // 验证出栈 (pop)
        router.pop()
        XCTAssertEqual(router.path.count, 1, "执行一次 pop操作后，最顶层子路由出栈，堆栈深度降为 1")
        
        // 验证回根 (popToRoot)
        router.popToRoot()
        XCTAssertEqual(router.path.count, 0, "执行 popToRoot 后，所有子路由清空，重置回大屏主视图")
    }
    
    func testAppRoutePropertiesAllCases() async {
        /// 函数头说明: 遍历测试所有 AppRoute 枚举值的 id、sidebarSelection、domain，确保分支覆盖率达 100%
        /// - 验证点: 1. 验证所有 22 个路由 case 拥有非空的唯一标识符 id；
        ///          2. 验证所有 case 的 sidebarSelection 对应侧边栏联动策略；
        ///          3. 验证所有 case 的 domain 归属是否合理。
        let testUUID = UUID()
        
        let allRoutes: [AppRoute] = [
            .notebookHub,
            .dashboard,
            .pageList(filterType: nil),
            .pageList(filterType: .concept),
            .pageDetail(id: testUUID),
            .tagCloud,
            .taskCenter,
            .chat,
            .synthesis,
            .sources,
            .settings,
            .help,
            .about,
            .log,
            .collab,
            .weeklyReport,
            .lint,
            .pluginMarket,
            .search(query: nil, filterType: nil),
            .search(query: "test", filterType: .concept),
            .ingest,
            .graph,
            .quiz,
            .medalWall
        ]
        
        for route in allRoutes {
            // 1. 验证 id
            let id = route.id
            XCTAssertFalse(id.isEmpty, "路由 \(route) 的 id 标识不应为空")
            
            // 2. 验证 sidebarSelection 正常返回，不会产生运行时崩溃
            let selection = route.sidebarSelection
            if route.id == "settings" || route.id == "help" || route.id == "about" {
                XCTAssertNil(selection, "对于 settings、help、about 页面，侧边栏应该返回 nil")
            } else {
                XCTAssertNotNil(selection, "普通业务页面 \(route) 在大屏上应该有其对应的侧边栏选中项")
            }
            
            // 3. 验证 domain 归属
            let domain = route.domain
            switch route {
            case .notebookHub, .pageList, .pageDetail, .tagCloud, .ingest, .graph, .search, .sources:
                XCTAssertEqual(domain, .knowledge, "大屏知识宇宙相关的路由 \(route) 应该归属于 .knowledge 领域")
            case .chat, .synthesis, .taskCenter, .weeklyReport, .quiz:
                XCTAssertEqual(domain, .ai, "AI 合成与会话相关的路由 \(route) 应该归属于 .ai 领域")
            case .dashboard, .log, .lint, .medalWall:
                XCTAssertEqual(domain, .insight, "度量度盘相关的路由 \(route) 应该归属于 .insight 领域")
            case .settings, .help, .about, .collab, .pluginMarket:
                XCTAssertEqual(domain, .system, "系统能力相关的路由 \(route) 应该归属于 .system 领域")
            }
        }
    }
    
    func testRouterAdditionalAPIs() async {
        // 函数头说明: 针对 Router 类中其余的高频交互辅助方法进行 100% 物理加固
        // - 验证点: 1. triggerLanguageRefresh() 确实能够切换状态标识；
        //          2. dismissSheet() 确实能安全隐藏 sheet 控制器；
        //          3. navigateToPage(id:) 确实压入详情导航；
        //          4. navigateToTool(_:) 确实能够选中特定的侧边栏并清空导航栈；
        //          5. 检验 selectedTab 底层 UserDefaults 的写入和读取一致性。
        
        // 1. 测试多语言强制刷新状态转换
        let initialRefreshState = router.languageForceUpdate
        router.triggerLanguageRefresh()
        XCTAssertNotEqual(router.languageForceUpdate, initialRefreshState, "调用 triggerLanguageRefresh 应该能够将刷新标识取反")
        
        // 2. 测试隐藏弹窗面板
        router.isShowingSettingsSheet = true
        router.dismissSheet()
        XCTAssertFalse(router.isShowingSettingsSheet, "调用 dismissSheet 应该强行将 isShowingSettingsSheet 重置为 false")
        
        // 3. 测试便捷详情页跳转
        let testId = UUID()
        router.navigateToPage(id: testId)
        XCTAssertEqual(router.path.count, 1, "navigateToPage 后 path 中应有 1 个元素")
        
        // 4. 测试便捷工具项跳转
        for tool in ToolItem.allCases {
            router.navigateToTool(tool)
            XCTAssertEqual(router.sidebarSelection, .tool(tool), "navigateToTool 后 sidebarSelection 应被置为对应的 .tool(\(tool.rawValue))")
            XCTAssertEqual(router.path.count, 0, "navigateToTool 属于顶层切换，应清空 NavigationPath 导航栈")
        }
        
        // 5. 校验 selectedTab 读写 UserDefaults 落地
        router.selectedTab = .chat
        // P2-1 迁移：Router 通过 ServiceContainer 解析 KeyStoreProtocol 持久化，
        //           setupFullMockEnvironment() 注册的是独立 UserDefaults 实例，
        //           因此从同一 KeyStore 读取，而非 UserDefaults.standard。
        let storedTab = ServiceContainer.shared
            .resolveOptional((any KeyStoreProtocol).self)?
            .string(forKey: AppConstants.Keys.Storage.selectedTab)
        XCTAssertEqual(storedTab, "chat", "selectedTab 在被 didSet 时应该写入到 UserDefaults")
    }
    
    func testRouterPathClearingOnSelectionChange() async {
        // 函数头说明: 验证在切换 selectedTab 或 sidebarSelection 时，能够自动将 path 导航栈清空，以解决右侧视图无联动的 Bug
        // - 验证点: 1. 当 path 中存在推栈页面时，修改 selectedTab 会重置 path；
        //          2. 当 path 中存在推栈页面时，修改 sidebarSelection 会重置 path。
        
        // 1. 验证切换 selectedTab 触发 path 重置
        router.path.append(AppRoute.settings)
        XCTAssertEqual(router.path.count, 1)
        router.selectedTab = .chat
        XCTAssertEqual(router.path.count, 0, "当切换 selectedTab 时，应自动重置并清空 path")
        
        // 2. 验证切换 sidebarSelection 触发 path 重置
        router.path.append(AppRoute.settings)
        XCTAssertEqual(router.path.count, 1)
        router.sidebarSelection = .tool(.weeklyReport)
        XCTAssertEqual(router.path.count, 0, "当切换 sidebarSelection 时，应自动重置并清空 path")
    }
}
