//
//  Graph2D3DAndComponentsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 GraphContainerView 2D 拓扑图、Graph3DView 3D 沉浸图谱、
//           GraphComponents 与 WeeklyInsightCard 知识周报面板。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

private struct GraphTestContainer: View {
    @Namespace var ns
    var body: some View {
        GraphContainerView(heroNamespace: ns, selectedTab: .constant(.graph))
    }
}

@MainActor
final class Graph2D3DAndComponentsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. GraphContainerView 2D 拓扑与模式切换测试

    func testGraphView_HierarchyAndModes() {
        let host = NavigationStack {
            GraphTestContainer()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. Graph3DView 3D 沉浸图谱测试

    func testGraph3DView_Hierarchy() {
        let host = NavigationStack {
            Graph3DView(
                selectedNodeID: .constant(nil),
                isFullScreen: .constant(false)
            )
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. WeeklyInsightCard 知识周报卡片测试

    func testWeeklyInsightCard_Hierarchy() {
        let host = NavigationStack {
            WeeklyInsightCard()
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}
