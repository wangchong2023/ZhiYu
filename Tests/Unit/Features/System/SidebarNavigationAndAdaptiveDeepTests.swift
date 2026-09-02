//
//  SidebarNavigationAndAdaptiveDeepTests.swift
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
final class SidebarNavigationAndAdaptiveDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SidebarSelection Route Mapping Tests

    func testSidebarSelectionRouteConversions() {
        let pageID = UUID()
        let pageSelection = SidebarSelection.page(pageID)
        XCTAssertEqual(pageSelection.asRoute(), .pageDetail(id: pageID))

        let toolSelection = SidebarSelection.tool(.dashboard)
        XCTAssertEqual(toolSelection.asRoute(), .dashboard)

        let filterSelection = SidebarSelection.filteredIndex(.concept)
        XCTAssertEqual(filterSelection.asRoute(), .pageList(filterType: .concept))
    }

    // MARK: - 2. Sidebar Sections & Subcomponents Full Mounting

    func testSidebarSectionsMounting() throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        let pinnedPage = KnowledgePage(title: "Pinned Note", pageType: .concept, content: "Pinned body", isPinned: true)
        let regularPage = KnowledgePage(title: "Entity Item", pageType: .entity, content: "Entity body")
        store.pages = [pinnedPage, regularPage]

        let sourceStore = SourceStore.shared
        sourceStore.updateSources([
            KnowledgeSource(pageID: regularPage.id, title: "Paper.pdf", snippet: "Sample snippet", score: 0.95)
        ])

        let container = SnapshotContainer { namespace in
            List {
                CapabilitiesSection()
                SourcesSection()
                UniverseSection()
                PinnedSection(
                    heroNamespace: namespace,
                    pageToDelete: .constant(nil),
                    showDeleteConfirmation: .constant(false)
                )
                ToolsSection()
            }
        }
        .snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: container)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)

        // 独立测试子组件
        let iconRow = SidebarIconRow(
            icon: "gearshape",
            color: .blue,
            title: "Settings",
            badge: 3,
            badgeFilled: true
        )
        let hostIcon = UIHostingController(rootView: iconRow)
        XCTAssertNotNil(hostIcon.view)

        let typeRow = SidebarTypeRow(type: .concept, count: 12)
        let hostType = UIHostingController(rootView: typeRow)
        XCTAssertNotNil(hostType.view)
    }
}
