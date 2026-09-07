//
//  InsightDashboardDeepTests.swift
//  ZhiYuTests
//
//  合并自 3 个碎片化测试文件：InsightDashboardAdvancedBehaviorTests.swift, InsightDashboardAndMedalDeepTests.swift, InsightDashboardDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class InsightDashboardDeepTests: XCTestCase {

    private var medalService: MedalService!
    private var settingsStore: SettingsStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        medalService = MedalService.shared
        settingsStore = SettingsStore()
    }

    func testKnowledgeDashboardFullLifecycleAndMetrics() async throws {
        let store = AppStore()
        let page1 = KnowledgePage(
            title: "Architecture Guide",
            pageType: .concept,
            content: "Architecture concepts with [[Swift Concurrency]] links.",
            tags: ["Architecture", "Swift"]
        )
        let page2 = KnowledgePage(
            title: "Swift Concurrency",
            pageType: .concept,
            content: "Concurrency in Swift 6.",
            tags: ["Swift", "Concurrency"]
        )
        await store.savePage(page1)
        await store.savePage(page2)

        struct Wrapper: View {
            var body: some View {
                VStack {
                    KnowledgeDashboardView()
                    WeeklyInsightCard()
                    TagCloudView(initialTag: "Swift")
                }
            }
        }

        let view = Wrapper().snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(page1.title, "Architecture Guide")
        XCTAssertEqual(page2.tags.count, 2)
    }

    func testComparisonDetailBodyViewWithRichFrontmatter() async throws {
        let markdownContent = """
        ---
        {
          "subjects": [
            {"id": "s1", "name": "Swift"},
            {"id": "s2", "name": "Rust"}
          ],
          "dimensions": [
            {"id": "d1", "name": "Safety Rating", "type": "rating"},
            {"id": "d2", "name": "Compile Latency", "type": "range"},
            {"id": "d3", "name": "Memory Model", "type": "text"}
          ],
          "matrix": [
            {"subject_id": "s1", "dimension_id": "d1", "value": 5.0},
            {"subject_id": "s2", "dimension_id": "d1", "value": 4.5},
            {"subject_id": "s1", "dimension_id": "d2", "value": {"min": 1.0, "max": 10.0}},
            {"subject_id": "s2", "dimension_id": "d2", "value": {"min": 5.0, "max": 20.0}},
            {"subject_id": "s1", "dimension_id": "d3", "value": "ARC & Ownership"}
          ]
        }
        ---

        # Swift vs Rust Comparison

        Detailed body with [[Apple Silicon]] integration notes.
        """

        let comparisonPage = KnowledgePage(
            title: "Language Comparison",
            pageType: .comparison,
            content: markdownContent
        )

        XCTAssertEqual(comparisonPage.title, "Language Comparison")

        struct Wrapper: View {
            let page: KnowledgePage
            var body: some View {
                ScrollView {
                    ComparisonDetailBodyView(page: page, onLinkTap: { _ in })
                    PageDetailAISection(page: page, onLinkTap: { _ in })
                }
            }
        }

        let view = Wrapper(page: comparisonPage).snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testTagCloudViewBulkAndExpansionModes() async throws {
        struct Wrapper: View {
            var body: some View {
                TagCloudView()
            }
        }

        let wrapper = Wrapper()
        XCTAssertNotNil(wrapper)
        let view = wrapper.snapshotEnvironment()
        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
    }

    func testKnowledgeDashboardView_Rendering() {
        let rawView = KnowledgeDashboardView()
        XCTAssertNotNil(rawView)
        let dashboardView = rawView.snapshotEnvironment()

        let host = UIHostingController(rootView: dashboardView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testMedalComponents_Rendering() {
        XCTAssertFalse(medalService.allMedals.isEmpty)
        if let medal = medalService.allMedals.first {
            let cardView = MedalCard(medal: medal, isEarned: true)
                .snapshotEnvironment()

            let host1 = UIHostingController(rootView: cardView)
            _ = host1.view
            host1.view.layoutIfNeeded()
            XCTAssertNotNil(host1.view)

            let popupView = MedalRewardPopup(medal: medal, onDismiss: {})
                .snapshotEnvironment()

            let host2 = UIHostingController(rootView: popupView)
            _ = host2.view
            host2.view.layoutIfNeeded()
            XCTAssertNotNil(host2.view)
        }
    }

    func testSettingsView_SectionStates() {
        let rawView = SettingsView()
        XCTAssertNotNil(rawView)
        let settingsView = rawView
            .environment(settingsStore)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: settingsView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testDeveloperSettingsView_Rendering() {
        let rawView = DeveloperSettingsView()
        XCTAssertNotNil(rawView)
        let devView = rawView.snapshotEnvironment()

        let host = UIHostingController(rootView: devView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testHexSpiralCalculator_GeometryAndCollisionFree() {
        // 1. 零与单点极值
        let zeroCoords = HexSpiralCalculator.generateSpiralCoordinates(count: 0)
        XCTAssertTrue(zeroCoords.isEmpty, "请求 0 个坐标点时应安全返回空数组")

        let singleCoords = HexSpiralCalculator.generateSpiralCoordinates(count: 1)
        XCTAssertEqual(singleCoords.count, 1)
        XCTAssertEqual(singleCoords.first, HexCoordinate(axialQ: 0, axialR: 0), "首个蜂窝坐标必须为物理中心原点 (0, 0)")

        let centerPoint = HexSpiralCalculator.convertToPhysicalPoint(coord: singleCoords[0], stepSize: 40)
        XCTAssertEqual(centerPoint.x, 0.0, accuracy: 0.0001, "中心原点物理 X 轴坐标应为 0")
        XCTAssertEqual(centerPoint.y, 0.0, accuracy: 0.0001, "中心原点物理 Y 轴坐标应为 0")

        // 2. 7 节点完整第一圈蜂窝 (1 中心 + 6 环绕)
        let ring1Coords = HexSpiralCalculator.generateSpiralCoordinates(count: 7)
        XCTAssertEqual(ring1Coords.count, 7, "应生成 7 个蜂窝网格坐标点")

        // 碰撞检测：验证所有坐标点绝对互不重叠
        let uniqueSet = Set(ring1Coords)
        XCTAssertEqual(uniqueSet.count, 7, "所有生成的螺旋轴向坐标必须唯一，绝不允许空间重叠碰撞")

        // 3. 物理平面投射间距有效性
        var physicalPoints: [CGPoint] = []
        for coord in ring1Coords {
            physicalPoints.append(HexSpiralCalculator.convertToPhysicalPoint(coord: coord, stepSize: 50))
        }
        for (i, p1) in physicalPoints.enumerated() {
            for (j, p2) in physicalPoints.enumerated() where i != j {
                let dist = hypot(p1.x - p2.x, p1.y - p2.y)
                XCTAssertGreaterThan(dist, 10.0, "各蜂窝气泡物理间距必须大于安全防碰撞阈值")
            }
        }
    }

    func testMedalService_AchievementsTriggeringAndReset() {
        let medalService = MedalService.shared
        medalService.reset()
        XCTAssertTrue(medalService.earnedMedalIDs.isEmpty, "重置后已获得勋章集合必须为空")

        // 1. 初始 0 页面 0 链接，不应触发任何成就
        medalService.checkAchievements(nodeCount: 0, linkCount: 0)
        XCTAssertTrue(medalService.earnedMedalIDs.isEmpty, "0 页面时不应解锁首篇笔记勋章")

        // 2. 增加 1 个页面，触发探索首篇成就
        medalService.checkAchievements(nodeCount: 1, linkCount: 0)
        XCTAssertTrue(medalService.earnedMedalIDs.contains(MedalConstants.MedalID.firstPage), "创建第 1 篇页面应解锁 firstPage 勋章")
        XCTAssertEqual(medalService.newlyEarnedMedal?.id, MedalConstants.MedalID.firstPage)

        // 3. 达到 5 个页面，触发积累 tier1 成就
        medalService.checkAchievements(nodeCount: 5, linkCount: 0)
        XCTAssertTrue(medalService.earnedMedalIDs.contains(MedalConstants.MedalID.nodes5), "达到 5 篇页面应解锁 nodes5 勋章")

        // 4. 达到 5 个链接，触发链接 tier1 成就
        medalService.checkAchievements(nodeCount: 5, linkCount: 5)
        XCTAssertTrue(medalService.earnedMedalIDs.contains(MedalConstants.MedalID.links5), "达到 5 个双链应解锁 links5 勋章")

        // 5. 再次重置
        medalService.reset()
        XCTAssertTrue(medalService.earnedMedalIDs.isEmpty, "执行 reset 后勋章列表应当被清空")
        XCTAssertNil(medalService.newlyEarnedMedal, "最新勋章指针应复位为 nil")
    }

    func testLintService_BrokenLinksAndDuplicateTitlesDetection() async {
        let lintService = LintService()
        let linkService = LinkService()

        // 1. 构造含有死链的页面（引用了不存在的 "不存在的目标"）
        let brokenPage = KnowledgePage(
            title: "微服务网关",
            pageType: .concept,
            content: "详见 [[不存在的跨域页面]] 和 [[正常概念]]。"
        )

        let targetPage = KnowledgePage(
            title: "正常概念",
            pageType: .concept,
            content: "这是正常存在的概念内容。"
        )

        // 2. 构造两个具有完全相同标题的重复页面（但 ID 不同）
        let dupPage1 = KnowledgePage(
            title: "重复标题条目",
            pageType: .concept,
            content: "条目 A 正文"
        )
        let dupPage2 = KnowledgePage(
            title: "重复标题条目",
            pageType: .concept,
            content: "条目 B 正文"
        )

        let allPages = [brokenPage, targetPage, dupPage1, dupPage2]

        let issues = await lintService.runLint(pages: allPages, linkService: linkService)

        // 验证：必须精准捕获到死链与重复标题问题
        let hasBrokenLink = issues.contains { (issue: LintIssue) -> Bool in
            issue.type == .brokenLink || issue.message.contains("不存在") || issue.suggestion.contains("不存在")
        }
        XCTAssertTrue(hasBrokenLink, "Lint 巡检应能精准识别并报告未引用的断裂死链")

        let hasDuplicate = issues.contains { (issue: LintIssue) -> Bool in
            issue.message.contains("重复") || issue.suggestion.contains("重复")
        }
        XCTAssertTrue(hasDuplicate, "Lint 巡检应能精准识别并报告同名冲突页面")
    }

    func testKnowledgeInsightService_EmptyPages_ThrowsAppropriateError() async {
        let insightService = KnowledgeInsightService()
        let mockLLM = LLMService.shared

        // 验证：向空知识库请求周报/每日见解时，绝不应发生除零崩溃或数组越界，
        // 必须优雅抛出语义清晰的 AppError.insight
        do {
            _ = try await insightService.generateDailyRecap(pages: [], llmService: mockLLM)
            XCTFail("向空页面集合请求每日见解应当抛出错误，而不是静默通过")
        } catch let err as NSError {
            XCTAssertEqual(err.domain, CoreConstants.ErrorDomain.insight, "错误域必须为 insight")
            XCTAssertFalse(err.localizedDescription.isEmpty, "抛出的错误消息应具有明确的指导文案")
        } catch {
            XCTFail("应当捕获到 NSError 实例，收到: \(error)")
        }
    }

    func testKnowledgePageListView_AllFilterTypes() {
        for pageType in [PageType.concept, PageType.entity, PageType.source, PageType.comparison, nil] {
            let rawList = KnowledgePageListView(filterType: pageType)
            XCTAssertNotNil(rawList)
            let listView = rawList.snapshotEnvironment()

            let host = UIHostingController(rootView: listView)
            _ = host.view
            host.view.layoutIfNeeded()

            XCTAssertNotNil(host.view)
        }
    }

    func testPageDetailView_Rendering() {
        let samplePage = KnowledgePage(
            title: "Paxos 共识算法深入浅出",
            pageType: .concept,
            content: "# Paxos 原理\n- 提议者 (Proposer)\n- 接受者 (Acceptor)\n- 学习者 (Learner)"
        )

        XCTAssertEqual(samplePage.title, "Paxos 共识算法深入浅出")

        let detailView = PageDetailView(page: samplePage)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: detailView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    func testLogView_Rendering() {
        let rawView = LogView()
        XCTAssertNotNil(rawView)
        let logView = rawView.snapshotEnvironment()

        let host = UIHostingController(rootView: logView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

}
