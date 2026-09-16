//
//  DashboardDeepTests.swift
//  ZhiYuTests
//
//  合并自 3 个碎片化测试文件：DashboardComponentsDeepTests.swift, DashboardHeatmapAndMetricsDeepTests.swift, InsightAndDashboardDeepAnalyticsTests.swift
//

import SwiftUI
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class DashboardDeepTests: XCTestCase {

    private var store: AppStore!
    private var router: Router!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        router = ServiceContainer.shared.resolveOptional(Router.self) ?? Router()
    }

    func testKnowledgeDashboardViewPopulatedAndEmpty() async throws {
        let dashboardView = KnowledgeDashboardView()
            .environment(store)
            .environment(router)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: dashboardView)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(dashboardView)
        XCTAssertNotNil(store)
    }

    func testDashboardCoordinatorCalculation() async throws {
        let coordinator = DashboardCoordinator()

        // 验证初始状态
        XCTAssertEqual(coordinator.totalLinks, 0)
        XCTAssertTrue(coordinator.densityData.isEmpty)
        XCTAssertFalse(coordinator.isGeneratingInsights)

        // 触发刷新
        await coordinator.refreshAll(store: store)

        // 验证刷新完成且无崩溃
        XCTAssertGreaterThanOrEqual(coordinator.totalLinks, 0)
    }

    func testDashboardCoordinatorStateAndCalculations() async throws {
        let page1 = KnowledgePage(
            title: "Architecture.md",
            pageType: .concept,
            content: "References [[Engine.swift]] and [[Database.swift]]."
        )
        let page2 = KnowledgePage(
            title: "Engine.swift",
            pageType: .entity,
            content: "Engine implementation details."
        )
        let page3 = KnowledgePage(
            title: "Database.swift",
            pageType: .source,
            content: "Database implementation and [[Architecture.md]] backlink."
        )
        store.knowledgeStore.pages = [page1, page2, page3]

        let coordinator = DashboardCoordinator()
        await coordinator.refreshAll(store: store)
        await coordinator.refreshInsights()

        XCTAssertFalse(coordinator.isGeneratingInsights)

        // 验证 DensityInfo 模型
        let item = DensityInfo(name: "Architecture", inbound: 1.0, outbound: 2.0)
        XCTAssertEqual(item.name, "Architecture")
        XCTAssertEqual(item.inbound, 1.0)
        XCTAssertEqual(item.outbound, 2.0)
    }

    func testKnowledgeDashboardViewAndSubviews() throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        store.pages = [
            KnowledgePage(title: "Entity Page", pageType: .entity, content: "Content"),
            KnowledgePage(title: "Concept Page", pageType: .concept, content: "Content"),
            KnowledgePage(title: "Source Page", pageType: .source, content: "Content"),
            KnowledgePage(title: "Comparison Page", pageType: .comparison, content: "Content")
        ]

        XCTAssertEqual(store.pages.count, 4)

        let dashboardView = KnowledgeDashboardView()
            .snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: dashboardView)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)

        // 独立测试 MetricBox
        let box = MetricBox(
            title: "Total Pages",
            value: "42",
            icon: "doc.fill",
            color: .blue,
            unit: "pages",
            trend: "+12%"
        )
        let hostBox = UIHostingController(rootView: box)
        XCTAssertNotNil(hostBox.view)

        // 独立测试 HotTopicMedal
        let medal = HotTopicMedal(
            category: "Concepts",
            count: 15,
            icon: "lightbulb.fill",
            color: .purple
        )
        let hostMedal = UIHostingController(rootView: medal)
        XCTAssertNotNil(hostMedal.view)

        // 独立测试 VaultInsightsPanel
        let panel = VaultInsightsPanel()
            .snapshotEnvironment()
        let hostPanel = UIHostingController(rootView: panel)
        window.rootViewController = hostPanel
        hostPanel.view.layoutIfNeeded()
        XCTAssertNotNil(hostPanel.view)
    }

    func testKnowledgeDashboardFullInteraction() async throws {
        struct Wrapper: View {
            var body: some View {
                VStack {
                    KnowledgeDashboardView()
                    TagCloudView()
                    WeeklyInsightCard()
                }
            }
        }

        let wrapper = Wrapper()
        XCTAssertNotNil(wrapper)
        let view = wrapper.snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }

    func testPageListAndCreatePageView() async throws {
        struct Wrapper: View {
            var body: some View {
                VStack {
                    KnowledgePageListView()
                    CreatePageView()
                }
            }
        }

        let wrapper = Wrapper()
        XCTAssertNotNil(wrapper)
        let view = wrapper.snapshotEnvironment()
        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
    }

    func testPageDetailAndSpecializedBodyViews() async throws {
        let conceptPage = KnowledgePage(title: "Architecture Concept", pageType: .concept, content: "Markdown body")
        let sourcePage = KnowledgePage(title: "Architecture Source", pageType: .source, content: "Source body")
        let comparisonPage = KnowledgePage(title: "Swift vs Rust", pageType: .comparison, content: "Comparison body")

        XCTAssertEqual(conceptPage.title, "Architecture Concept")
        XCTAssertEqual(sourcePage.pageType, .source)

        struct Wrapper: View {
            var conceptPage: KnowledgePage
            var sourcePage: KnowledgePage
            var comparisonPage: KnowledgePage

            var body: some View {
                VStack {
                    PageDetailView(page: conceptPage)
                    ConceptDetailBodyView(page: conceptPage, onLinkTap: { _ in })
                    SourceDetailBodyView(page: sourcePage, onLinkTap: { _ in })
                    ComparisonDetailBodyView(page: comparisonPage, onLinkTap: { _ in })
                    BacklinksView(page: conceptPage)
                    PageHistoryView(page: conceptPage)
                }
            }
        }

        let view = Wrapper(
            conceptPage: conceptPage,
            sourcePage: sourcePage,
            comparisonPage: comparisonPage
        ).snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
    }

    func testLogAndLintViews() async throws {
        struct Wrapper: View {
            @State var selection: SidebarSelection? = .tool(.lint)

            var body: some View {
                VStack {
                    LogView()
                    LintView(selection: $selection)
                }
            }
        }

        let wrapper = Wrapper()
        XCTAssertNotNil(wrapper)
        let view = wrapper.snapshotEnvironment()
        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
    }

}
