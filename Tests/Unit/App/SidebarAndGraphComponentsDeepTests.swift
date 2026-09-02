//
//  SidebarAndGraphComponentsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 SidebarRowComponents 侧边栏行与 GraphZoomControls 图谱控制栏。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class SidebarAndGraphComponentsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SidebarRowComponents 测试

    func testSidebarSelection_AsRoute() {
        let pageId = UUID()
        let pageSel = SidebarSelection.page(pageId)
        XCTAssertEqual(pageSel.asRoute(), .pageDetail(id: pageId))

        let toolItem = ToolItem.dashboard
        let toolSel = SidebarSelection.tool(toolItem)
        XCTAssertEqual(toolSel.asRoute(), toolItem.route)

        let filterSel = SidebarSelection.filteredIndex(.concept)
        XCTAssertEqual(filterSel.asRoute(), .pageList(filterType: .concept))
    }

    func testCapabilitiesSection_Hierarchy() {
        let host = List {
            CapabilitiesSection()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testSourcesSection_Hierarchy() {
        let host = List {
            SourcesSection()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. GraphComponents 测试

    func testGraphZoomControls_Hierarchy() {
        let host = GraphZoomControls(
            scale: .constant(1.0),
            lastScale: .constant(1.0),
            offset: .constant(.zero),
            lastOffset: .constant(.zero),
            show3D: .constant(false),
            onRelayout: {},
            onFitToScreen: {}
        )
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}
