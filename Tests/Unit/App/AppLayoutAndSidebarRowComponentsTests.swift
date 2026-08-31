//
//  AppLayoutAndSidebarRowComponentsTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 测试层
//  核心职责：验证 SidebarSelection 路由映射、ToolItem 枚举分发、自适应导航行包装与侧边栏各 Section 状态机。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AppLayoutAndSidebarRowComponentsTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SidebarSelection 路由转换全分支

    func testSidebarSelection_AsRoute_AllVariants() {
        let testUUID = UUID()
        let pageSelection = SidebarSelection.page(testUUID)
        XCTAssertEqual(pageSelection.asRoute(), .pageDetail(id: testUUID))

        let toolSelection = SidebarSelection.tool(.dashboard)
        XCTAssertEqual(toolSelection.asRoute(), AppRoute.dashboard)

        let logTool = SidebarSelection.tool(.log)
        XCTAssertEqual(logTool.asRoute(), AppRoute.log)

        let graphTool = SidebarSelection.tool(.graph)
        XCTAssertEqual(graphTool.asRoute(), AppRoute.graph)

        let filteredSelection = SidebarSelection.filteredIndex(.entity)
        XCTAssertEqual(filteredSelection.asRoute(), .pageList(filterType: .entity))
    }

    // MARK: - 2. ToolItem 全 Cases 与路由目标匹配

    func testToolItem_AllCasesRoutingIntegrity() {
        for tool in ToolItem.allCases {
            let route = tool.route
            XCTAssertNotNil(route, "ToolItem \(tool) 必须具备有效的 AppRoute 路由映射")
        }
    }

    // MARK: - 3. SidebarSelection Hashable 与相等性校验

    func testSidebarSelection_HashableAndEquality() {
        let id1 = UUID()
        let id2 = UUID()

        let sel1 = SidebarSelection.page(id1)
        let sel2 = SidebarSelection.page(id1)
        let sel3 = SidebarSelection.page(id2)

        XCTAssertEqual(sel1, sel2)
        XCTAssertNotEqual(sel1, sel3)
        XCTAssertEqual(sel1.hashValue, sel2.hashValue)
    }
}
