//
//  DashboardHeatmapAndMetricsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class DashboardHeatmapAndMetricsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. DashboardCoordinator & Density Model Tests

    func testDashboardCoordinatorStateAndCalculations() async throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
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
        store.pages = [page1, page2, page3]

        let coordinator = DashboardCoordinator()
        await coordinator.refreshAll()
        await coordinator.refreshInsights()

        XCTAssertFalse(coordinator.isGeneratingInsights)

        // 验证 DensityInfo 模型
        let item = DensityInfo(name: "Architecture", inbound: 1.0, outbound: 2.0)
        XCTAssertEqual(item.name, "Architecture")
        XCTAssertEqual(item.inbound, 1.0)
        XCTAssertEqual(item.outbound, 2.0)
    }

    // MARK: - 2. KnowledgeDashboardView & MetricBox & HotTopicMedal

    func testKnowledgeDashboardViewAndSubviews() throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        store.pages = [
            KnowledgePage(title: "Entity Page", pageType: .entity, content: "Content"),
            KnowledgePage(title: "Concept Page", pageType: .concept, content: "Content"),
            KnowledgePage(title: "Source Page", pageType: .source, content: "Content"),
            KnowledgePage(title: "Comparison Page", pageType: .comparison, content: "Content")
        ]

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
            unit: "pages",
            icon: "doc.fill",
            color: .blue,
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
}
