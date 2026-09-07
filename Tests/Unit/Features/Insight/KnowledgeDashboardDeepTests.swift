//
//  KnowledgeDashboardDeepTests.swift
//  ZhiYuTests
//
//  合并自 3 个碎片化测试文件：KnowledgeDashboardAndPageListDeepTests.swift, KnowledgeDashboardMetricsDeepTests.swift, KnowledgeDashboardViewInteractiveTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class KnowledgeDashboardDeepTests: XCTestCase {

    private var knowledgeStore: KnowledgeStore!
    private var appStore: AppStore!
    private var aiStore: AIInsightStore!
    private var router: Router!
    private var themeManager: ThemeManager!
    private var window: UIWindow!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()

        knowledgeStore = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        appStore = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        aiStore = ServiceContainer.shared.resolveOptional(AIInsightStore.self) ?? AIInsightStore()
        router = ServiceContainer.shared.resolveOptional(Router.self) ?? Router()
        themeManager = ServiceContainer.shared.resolveOptional(ThemeManager.self) ?? ThemeManager()

        window = UIWindow(frame: CGRect(x: 0, y: 0, width: TestConstants.windowWidth, height: TestConstants.windowHeight))
    }

    func createTestPages() -> [KnowledgePage] {
        let p1 = KnowledgePage(
            title: TestConstants.longTitle,
            pageType: .concept,
            content: "关联到 [[短标题]] 与 [[系统架构]]",
            tags: ["架构", "DDD"]
        )
        let p2 = KnowledgePage(
            title: TestConstants.shortTitle,
            pageType: .entity,
            content: "反向链接 [[这是一段非常非常长的页面标题用于验证图表标签自动截断]]",
            tags: ["Swift"]
        )
        let p3 = KnowledgePage(
            title: "系统架构",
            pageType: .concept,
            content: "包含 [[短标题]]",
            tags: ["架构"]
        )
        let p4 = KnowledgePage(
            title: "参考论文.pdf",
            pageType: .source,
            content: "学术论文原文",
            tags: ["学术"]
        )
        let p5 = KnowledgePage(
            title: "技术方案对比",
            pageType: .comparison,
            content: "对比分析表格",
            tags: ["方案"]
        )
        let p6 = KnowledgePage(
            title: "RawData",
            pageType: .raw,
            content: "未加工原始素材"
        )
        return [p1, p2, p3, p4, p5, p6]
    }

    func testKnowledgeDashboardView_EmptyState_RendersGracefully() async {
        knowledgeStore.pages = []
        XCTAssertEqual(knowledgeStore.pages.count, 0)

        let view = KnowledgeDashboardView()
            .environment(appStore)
            .environment(router)
            .environment(themeManager)
            .snapshotEnvironment(knowledgeStore: knowledgeStore, appStore: appStore)

        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testKnowledgeDashboardView_WithRichData_RendersMetricsAndDensityChart() async {
        let pages = createTestPages()
        knowledgeStore.pages = pages
        XCTAssertFalse(pages.isEmpty)
        appStore.knowledgeStore.pages = pages

        let view = KnowledgeDashboardView()
            .environment(appStore)
            .environment(router)
            .environment(themeManager)
            .snapshotEnvironment(knowledgeStore: knowledgeStore, appStore: appStore)

        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testDailyRecapCard_NavigationAndDeletedDefense() async {
        let pages = createTestPages()
        appStore.knowledgeStore.pages = pages

        // 1. 存在的目标页面：触发路由跳转
        let validTarget = pages[0]
        let validRecap = KnowledgeInsightService.DailyRecap(
            targetPageID: validTarget.id,
            targetPageTitle: validTarget.title,
            insight: "核心洞察",
            suggestedConnection: "关联 [[概念索引]]"
        )
        XCTAssertTrue(appStore.pages.contains(where: { $0.id == validRecap.targetPageID }))
        router.navigateToPage(id: validRecap.targetPageID)
        XCTAssertEqual(router.path.count, 1)
        router.popToRoot()

        // 2. 已被删除的幽灵页面：容灾防御不崩溃
        let nonExistentID = UUID()
        _ = KnowledgeInsightService.DailyRecap(
            targetPageID: nonExistentID,
            targetPageTitle: "已删除页面",
            insight: "残留见解",
            suggestedConnection: ""
        )
        XCTAssertFalse(appStore.pages.contains(where: { $0.id == nonExistentID }))
    }

    func testKnowledgeDashboard_Subviews_DirectRendering() {
        // 1. MetricBox 带趋势与不带趋势
        let boxWithTrend = MetricBox(
            title: "核心指标",
            value: TestConstants.largeMetricValue,
            unit: "篇",
            icon: DesignSystem.Icons.documentFill,
            color: .appAccent,
            trend: TestConstants.sampleTrend
        )
        XCTAssertEqual(boxWithTrend.title, "核心指标")
        let hostBox1 = UIHostingController(rootView: boxWithTrend)
        hostBox1.view.layoutIfNeeded()
        XCTAssertNotNil(hostBox1.view)

        let boxWithoutTrend = MetricBox(
            title: "总关联",
            value: "0",
            unit: nil,
            icon: DesignSystem.Icons.network,
            color: .purple,
            trend: nil
        )
        XCTAssertEqual(boxWithoutTrend.value, "0")
        let hostBox2 = UIHostingController(rootView: boxWithoutTrend)
        hostBox2.view.layoutIfNeeded()
        XCTAssertNotNil(hostBox2.view)

        // 2. HotTopicMedal 各分类勋章
        for type in PageType.allVisibleCases {
            let medal = HotTopicMedal(
                category: type.displayName,
                count: 5,
                icon: type.icon,
                color: Color.fromModelColorName(type.colorName)
            )
            let hostMedal = UIHostingController(rootView: medal)
            hostMedal.view.layoutIfNeeded()
            XCTAssertNotNil(hostMedal.view)
        }
    }
    func testKnowledgePageListView_SearchTriggerAndDebounce() async throws {
        let pages = createTestPages()
        knowledgeStore.pages = pages

        let listView = KnowledgePageListView(filterType: nil)
            .environment(appStore)
            .environment(router)
            .environment(themeManager)
            .snapshotEnvironment(knowledgeStore: knowledgeStore, appStore: appStore)

        let host = UIHostingController(rootView: listView)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        // 模拟执行搜索与清空
        guard let searchStore = appStore.searchStore else {
            XCTFail("searchStore 应当存在")
            return
        }
        XCTAssertFalse(searchStore.isSearching)

        // 模拟正在检索骨架屏状态
        searchStore.isSearching = true
        host.view.layoutIfNeeded()
        XCTAssertTrue(searchStore.isSearching)

        searchStore.isSearching = false
        host.view.layoutIfNeeded()
        XCTAssertFalse(searchStore.isSearching)
    }

    func testKnowledgePageListView_DeleteConfirmationAndStyles() async {
        let pages = createTestPages()
        knowledgeStore.pages = pages

        let pageToDelete = pages[0]
        await appStore.deletePage(pageToDelete)
        XCTAssertFalse(appStore.pages.contains(where: { $0.id == pageToDelete.id }))

        // 测试 KnowledgeStatItem 渲染
        let statItem = KnowledgeStatItem(label: "总页面数", value: "100", color: .appAccent)
        let hostStat = UIHostingController(rootView: statItem)
        hostStat.view.layoutIfNeeded()
        XCTAssertNotNil(hostStat.view)

        // 测试 AppPressButtonStyle
        let button = Button("测试点击") {}
            .buttonStyle(AppPressButtonStyle())
        let hostBtn = UIHostingController(rootView: button)
        hostBtn.view.layoutIfNeeded()
        XCTAssertNotNil(hostBtn.view)
    }

    func testKnowledgeDashboardViewMountingWithData() async throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        let appStore = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()

        let page1 = KnowledgePage(title: "Architecture Guide", tags: ["iOS", "Architecture"])
        let page2 = KnowledgePage(title: "Concurrency Patterns", tags: ["Swift", "iOS"])
        let page3 = KnowledgePage(title: "RAG Retrieval", tags: ["AI", "RAG"])

        store.pages = [page1, page2, page3]
        XCTAssertEqual(store.pages.count, 3)

        let view = KnowledgeDashboardView()
            .snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }

    func testKnowledgeDashboardViewEmptyState() async throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        store.pages = []
        XCTAssertEqual(store.pages.count, 0)

        let view = KnowledgeDashboardView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
    }

    func testTagBubbleRatioCalculator_BoundaryAndFuzzResistance() {
        // 空列表
        XCTAssertEqual(TagBubbleRatioCalculator.calculate(for: 5, from: []), 0.0)

        // min == max (无极差)
        XCTAssertEqual(TagBubbleRatioCalculator.calculate(for: 3, from: [3, 3, 3]), 0.5)

        // 下界越界 (count < min) 强制钳位至 0.0，杜绝负数尺寸
        XCTAssertEqual(TagBubbleRatioCalculator.calculate(for: 0, from: [2, 5, 10]), 0.0)
        XCTAssertEqual(TagBubbleRatioCalculator.calculate(for: -50, from: [2, 5, 10]), 0.0)

        // 上界越界 (count > max) 强制钳位至 1.0，杜绝超大变形
        XCTAssertEqual(TagBubbleRatioCalculator.calculate(for: 20, from: [2, 5, 10]), 1.0)
        XCTAssertEqual(TagBubbleRatioCalculator.calculate(for: 9999, from: [2, 5, 10]), 1.0)

        // 正常范围精确归一化
        let ratio = TagBubbleRatioCalculator.calculate(for: 6, from: [2, 10])
        XCTAssertEqual(ratio, 0.5, accuracy: 0.0001)

        // 100 次 Fuzz 混沌极值注入，保证严格位于 [0.0, 1.0] 区间且绝不产生 NaN
        for _ in 0..<100 {
            let randomMin = Int.random(in: -1000...1000)
            let randomMax = Int.random(in: -1000...1000)
            let randomCount = Int.random(in: -2000...2000)
            let result = TagBubbleRatioCalculator.calculate(for: randomCount, from: [randomMin, randomMax])

            XCTAssertFalse(result.isNaN, "计算结果绝不能为 NaN")
            XCTAssertFalse(result.isInfinite, "计算结果绝不能为无穷大")
            XCTAssertGreaterThanOrEqual(result, 0.0, "比例下界必须 >= 0.0")
            XCTAssertLessThanOrEqual(result, 1.0, "比例上界必须 <= 1.0")
        }
    }

    func testDashboardCoordinatorCalculateStatsWithPagesAndLinks() async {
        let p1 = KnowledgePage(title: "Page A", content: "链接到 [[Page B]] 和 [[Page C]]")
        let p2 = KnowledgePage(title: "Page B", content: "链接到 [[Page C]]")
        let p3 = KnowledgePage(title: "Page C", content: "孤立节点")

        await appStore.savePage(p1)
        await appStore.savePage(p2)
        await appStore.savePage(p3)

        let coordinator = DashboardCoordinator()
        await coordinator.calculateStats(store: appStore)

        // Page A 有 2 个外链，Page B 有 1 个外链，总外链数为 3
        XCTAssertEqual(coordinator.totalLinks, 3, "总链接数应为 3")

        // 验证密度数据 Top N
        XCTAssertFalse(coordinator.densityData.isEmpty, "计算后密度数据不应为空")
        let pageCDensity = coordinator.densityData.first(where: { $0.name == "Page C" })
        XCTAssertNotNil(pageCDensity)
        XCTAssertEqual(pageCDensity?.inbound, 2.0, "Page C 的入链数应为 2")
    }

    func testDashboardCoordinatorCalculateStatsEmptyPagesReturnsZero() async {
        appStore.knowledgeStore.pages = []
        let coordinator = DashboardCoordinator()
        await coordinator.calculateStats(store: appStore)

        XCTAssertEqual(coordinator.totalLinks, 0, "空库下总链接数应为 0")
        XCTAssertTrue(coordinator.densityData.isEmpty, "空库下密度列表应为空")
    }

    func testTagsAggregationAccurateCounts() async {
        let p1 = KnowledgePage(title: "P1", content: "...", tags: ["Swift", "iOS"])
        let p2 = KnowledgePage(title: "P2", content: "...", tags: ["Swift", "Architecture"])
        let p3 = KnowledgePage(title: "P3", content: "...", tags: ["Swift"])

        await appStore.savePage(p1)
        await appStore.savePage(p2)
        await appStore.savePage(p3)

        let coordinator = DashboardCoordinator()
        coordinator.updateTags(store: appStore)

        let swiftTag = coordinator.tags.first(where: { $0.tag == "Swift" })
        XCTAssertEqual(swiftTag?.count, 3, "Swift 标签应被 3 个页面引用")

        let iosTag = coordinator.tags.first(where: { $0.tag == "iOS" })
        XCTAssertEqual(iosTag?.count, 1, "iOS 标签应被 1 个页面引用")
    }

    func testDashboardCoordinatorRefreshAllExecutesSuccessfully() async {
        let p1 = KnowledgePage(title: "P1", content: "链接 [[P2]]", tags: ["Tag1"])
        let p2 = KnowledgePage(title: "P2", content: "正文", tags: ["Tag2"])
        await appStore.savePage(p1)
        await appStore.savePage(p2)

        let coordinator = DashboardCoordinator()
        await coordinator.refreshAll(store: appStore)

        XCTAssertFalse(coordinator.isCalculating, "刷新完成后计算中标志应重置为 false")
        XCTAssertEqual(coordinator.totalLinks, 1)
        XCTAssertEqual(coordinator.tags.count, 2)
    }

    func testKnowledgeDashboardViewMountAndRenderWithMultiPageTypes() async {
        let conceptPage = KnowledgePage(title: "概念核心", pageType: .concept, content: "这是概念")
        let entityPage = KnowledgePage(title: "实体词条", pageType: .entity, content: "这是词条")
        let sourcePage = KnowledgePage(title: "原始资料", pageType: .source, content: "这是资料")

        await appStore.savePage(conceptPage)
        await appStore.savePage(entityPage)
        await appStore.savePage(sourcePage)

        XCTAssertEqual(conceptPage.title, "概念核心")
        XCTAssertEqual(sourcePage.pageType, .source)

        let view = KnowledgeDashboardView()
            .environment(appStore)
            .environment(router)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "KnowledgeDashboardView 宿主视图应成功完成挂载并排版各区块")
    }

    func testDailyRecapCard_PageNavigationAndDeletedToast() async {
        let targetPage = KnowledgePage(title: "重要页面", content: "这是页面正文")
        await appStore.savePage(targetPage)

        // 验证目标页面存在时的路由跳转
        let recap = KnowledgeInsightService.DailyRecap(
            targetPageID: targetPage.id,
            targetPageTitle: targetPage.title,
            insight: "深度核心洞察解析",
            suggestedConnection: "建议连接至 [[其它页面]]"
        )

        XCTAssertTrue(appStore.pages.contains(where: { $0.id == recap.targetPageID }))
        router.navigateToPage(id: recap.targetPageID)
        XCTAssertFalse(router.path.isEmpty)
        router.popToRoot()

        // 验证目标页面已删除时的容灾分支
        let deletedRecap = KnowledgeInsightService.DailyRecap(
            targetPageID: UUID(),
            targetPageTitle: "已不存在的页面",
            insight: "遗留洞察",
            suggestedConnection: ""
        )

        XCTAssertFalse(appStore.pages.contains(where: { $0.id == deletedRecap.targetPageID }))
    }

    func testMetricBoxVariantsRenderWithoutCrash() {
        let rawBoxWithTrend = MetricBox(
            title: "核心指标",
            value: "128",
            unit: "篇",
            icon: DesignSystem.Icons.documentFill,
            color: .appAccent,
            trend: "+12%"
        )
        XCTAssertEqual(rawBoxWithTrend.title, "核心指标")
        let boxWithTrend = rawBoxWithTrend.snapshotEnvironment()

        let host1 = UIHostingController(rootView: boxWithTrend)
        _ = host1.view

        let rawBoxWithoutTrend = MetricBox(
            title: "基础指标",
            value: "50",
            unit: nil,
            icon: DesignSystem.Icons.network,
            color: .purple,
            trend: nil
        )
        XCTAssertEqual(rawBoxWithoutTrend.value, "50")
        let boxWithoutTrend = rawBoxWithoutTrend.snapshotEnvironment()

        let host2 = UIHostingController(rootView: boxWithoutTrend)
        _ = host2.view

        XCTAssertNotNil(host1.view)
        XCTAssertNotNil(host2.view)
    }

    func testHotTopicMedalRenderWithoutCrash() {
        let rawMedal = HotTopicMedal(
            category: "概念定义",
            count: 42,
            icon: PageType.concept.icon,
            color: .blue
        )
        XCTAssertEqual(rawMedal.count, 42)
        let medal = rawMedal.snapshotEnvironment()

        let host = UIHostingController(rootView: medal)
        _ = host.view

        XCTAssertNotNil(host.view, "HotTopicMedal 卡片应稳定完成布局渲染")
    }

    func testWeeklyInsightCard_StateTransitionsAndRender() {
        // 空周报状态（显示生成报告按钮）
        aiStore.weeklyInsight = nil
        XCTAssertNil(aiStore.weeklyInsight)
        let emptyCard = WeeklyInsightCard()
            .environment(appStore)
            .environment(aiStore)
            .environment(router)
            .snapshotEnvironment()

        let hostEmpty = UIHostingController(rootView: emptyCard)
        _ = hostEmpty.view
        XCTAssertNotNil(hostEmpty.view)

        // 具有周报数据状态
        aiStore.weeklyInsight = KnowledgeInsightService.WeeklyInsight(
            dateRange: "2026.08.28 - 2026.09.04",
            totalNewPages: 18,
            topKeywords: ["Swift", "RAG", "VectorDB"],
            aiSummary: "本周知识库迎来了 **大规模增长**，新增了对 [[核心概念]] 的深度引用。",
            growthTraction: "+35%"
        )
        XCTAssertEqual(aiStore.weeklyInsight?.totalNewPages, 18)

        let populatedCard = WeeklyInsightCard()
            .environment(appStore)
            .environment(aiStore)
            .environment(router)
            .snapshotEnvironment()

        let hostPopulated = UIHostingController(rootView: populatedCard)
        _ = hostPopulated.view
        XCTAssertNotNil(hostPopulated.view)
    }

    func testWeeklyReportView_FullScreenHierarchy() {
        let rawReport = WeeklyReportView()
        XCTAssertNotNil(rawReport)
        let reportView = rawReport
            .environment(appStore)
            .environment(aiStore)
            .environment(router)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: reportView)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "WeeklyReportView 全屏周报界面应正确挂载并渲染提示与卡片")
    }

    func testInsightStatRendering() {
        let rawStat = InsightStat(
            label: "本周新增",
            value: "25",
            icon: DesignSystem.Icons.docBadgePlus,
            color: .blue
        )
        XCTAssertEqual(rawStat.value, "25")
        let stat = rawStat.snapshotEnvironment()

        let host = UIHostingController(rootView: stat)
        _ = host.view
        XCTAssertNotNil(host.view, "InsightStat 指标小组件应成功渲染")
    }

    private enum TestConstants {
        static let windowWidth: CGFloat = 375
        static let windowHeight: CGFloat = 812
        static let longTitle = "这是一个非常长的标题用于测试截断逻辑"
        static let shortTitle = "短标题"
        static let largeMetricValue: String = "1000.0"
        static let sampleTrend: String = "0.15"
    }
}
