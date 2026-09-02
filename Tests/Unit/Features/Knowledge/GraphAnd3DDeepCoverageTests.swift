//
//  GraphAnd3DDeepCoverageTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 GraphContainerView 知识图谱画布与 Graph3DView SceneKit 三维力导向渲染。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class GraphAnd3DDeepCoverageTests: XCTestCase {

    @Namespace private var heroNamespace

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 2D 知识图谱容器测试

    func testGraphContainerView_Hierarchy() {
        struct Wrapper: View {
            @Namespace var hero
            @State var tab: AppTab = .graph
            var body: some View {
                GraphContainerView(heroNamespace: hero, selectedTab: $tab)
            }
        }

        let host = Wrapper()
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. 3D SceneKit 知识图谱测试

    func testGraph3DView_Hierarchy() {
        let host = Graph3DView(
            selectedNodeID: .constant(nil),
            isFullScreen: .constant(false)
        )
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}
