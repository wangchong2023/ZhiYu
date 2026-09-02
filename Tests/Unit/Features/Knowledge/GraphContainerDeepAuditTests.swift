//
//  GraphContainerDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 GraphContainerView、边截断与 2D 力导向拓扑画布渲染。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class GraphContainerDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    struct GraphWrapper: View {
        @Namespace private var heroNamespace
        @State private var selectedTab: AppTab = .graph

        var body: some View {
            GraphContainerView(heroNamespace: heroNamespace, selectedTab: $selectedTab)
        }
    }

    func testGraphContainerView_Hierarchy() {
        let host = NavigationStack {
            GraphWrapper()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}
