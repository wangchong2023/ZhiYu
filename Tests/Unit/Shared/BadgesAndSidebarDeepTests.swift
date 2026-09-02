//
//  BadgesAndSidebarDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 AIRainbowGlowBadge 全局发光微标、SidebarRowComponents
//           侧边栏组件与自适应分栏渲染。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class BadgesAndSidebarDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. AIRainbowGlowBadge 呼吸发光指示微标测试

    func testAIRainbowGlowBadge_Hierarchy() {
        let host = AIRainbowGlowBadge()
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. SidebarSelection 路由转换测试

    func testSidebarSelection_AsRoute() {
        let pageID = UUID()
        let pageSel = SidebarSelection.page(pageID)
        XCTAssertEqual(pageSel.asRoute(), .pageDetail(id: pageID))

        for tool in ToolItem.allCases {
            let toolSel = SidebarSelection.tool(tool)
            XCTAssertEqual(toolSel.asRoute(), tool.route)
        }

        for type in PageType.allCases {
            let filterSel = SidebarSelection.filteredIndex(type)
            XCTAssertEqual(filterSel.asRoute(), .pageList(filterType: type))
        }
    }
}
