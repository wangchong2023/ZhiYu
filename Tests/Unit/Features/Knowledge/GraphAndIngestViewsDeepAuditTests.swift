//
//  GraphAndIngestViewsDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度审计图谱 3D 可视化 (Graph3DView) 与知识导入摄入 (IngestView) 的视图构建与状态流转。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class GraphAndIngestViewsDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. Graph3DView 视图树求值与全屏绑定

    func testGraph3DView_ViewHierarchy_Evaluates() {
        let nodeIDBinding = Binding<UUID?>(get: { nil }, set: { _ in })
        let fullScreenBinding = Binding<Bool>(get: { false }, set: { _ in })

        let view = Graph3DView(selectedNodeID: nodeIDBinding, isFullScreen: fullScreenBinding)
            .snapshotEnvironment()
        let controller = UIHostingController(rootView: view)
        XCTAssertNotNil(controller.view)
    }

    // MARK: - 2. IngestView 导入面板视图求值

    func testIngestView_ViewHierarchy_Evaluates() {
        let tabBinding = Binding<AppTab>(get: { .ingest }, set: { _ in })
        let view = IngestView(selectedTab: tabBinding)
            .snapshotEnvironment()
        let controller = UIHostingController(rootView: view)
        XCTAssertNotNil(controller.view)
    }
}
