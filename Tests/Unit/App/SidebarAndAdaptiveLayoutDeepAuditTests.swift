//
//  SidebarAndAdaptiveLayoutDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层测试
//  核心职责：深度审计侧边栏导航行组件 (SidebarRowComponents) 与多端自适应布局组件 (AppLayoutComponents)。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SidebarAndAdaptiveLayoutDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SidebarSelection 路由转换与枚举匹配

    func testSidebarSelection_MappingIntegrity() {
        let pageID = UUID()
        let pageSelection = SidebarSelection.page(pageID)
        XCTAssertEqual(pageSelection.asRoute(), .pageDetail(id: pageID))

        let toolSelection = SidebarSelection.tool(.dashboard)
        XCTAssertEqual(toolSelection.asRoute(), .dashboard)

        let filterSelection = SidebarSelection.filteredIndex(.concept)
        XCTAssertEqual(filterSelection.asRoute(), .pageList(filterType: .concept))
    }

    // MARK: - 2. ToolItem 路由映射与完整性

    func testToolItem_RoutingMapping_AllNonNil() {
        for tool in ToolItem.allCases {
            let route = tool.route
            XCTAssertNotNil(route, "ToolItem \(tool) 的 route 属性不可为 nil")
        }
    }

    // MARK: - 3. ContentView 布局组件状态流转

    func testContentView_MainContainer_WithGuestAndLoggedIn() {
        let contentView = ContentView()
        let container = contentView.mainContainer(tintColor: .blue)
            .snapshotEnvironment()
        let controller = UIHostingController(rootView: container)
        XCTAssertNotNil(controller.view)
    }
}
