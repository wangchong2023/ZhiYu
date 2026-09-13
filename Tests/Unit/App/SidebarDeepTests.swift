//
//  SidebarDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：SidebarAndAdaptiveLayoutDeepAuditTests.swift, SidebarAndGraphComponentsDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import UFPStorage
import XCTest
@testable import ZhiYu

@MainActor
final class SidebarDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func testSidebarSelection_MappingIntegrity() {
        let pageID = UUID()
        let pageSelection = SidebarSelection.page(pageID)
        XCTAssertEqual(pageSelection.asRoute(), .pageDetail(id: pageID))

        let toolSelection = SidebarSelection.tool(.dashboard)
        XCTAssertEqual(toolSelection.asRoute(), .dashboard)

        let filterSelection = SidebarSelection.filteredIndex(.concept)
        XCTAssertEqual(filterSelection.asRoute(), .pageList(filterType: .concept))
    }

    func testToolItem_RoutingMapping_AllNonNil() {
        for tool in ToolItem.allCases {
            let route = tool.route
            XCTAssertNotNil(route, "ToolItem \(tool) 的 route 属性不可为 nil")
        }
    }

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

}
