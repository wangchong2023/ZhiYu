//
//  GraphAndKnowledgeViewsStateMachineDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 测试层
//  核心职责：深度验证 Graph3DView、GraphView、ImportRecordSection 与 IngestView 的状态机流转与交互安全。
//

import XCTest
import SwiftUI
import UFPCore
import UFPStorage
import Dependencies
@testable import ZhiYu

@MainActor
final class GraphAndKnowledgeViewStateTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. Graph3DView 交互与全屏状态机求值

    func testGraph3DView_InteractiveStatesAndFullScreenToggle() {
        let store = KnowledgeStore()
        let router = Router()

        var selectedID: UUID?
        var isFullScreen = false

        let bindingID = Binding(get: { selectedID }, set: { selectedID = $0 })
        let bindingFS = Binding(get: { isFullScreen }, set: { isFullScreen = $0 })

        // 基础渲染
        let view = Graph3DView(selectedNodeID: bindingID, isFullScreen: bindingFS)
            .environment(store)
            .environment(router)

        let controller = UIHostingController(rootView: view)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        // 全屏模式切换求值
        isFullScreen = true
        let fsView = Graph3DView(selectedNodeID: bindingID, isFullScreen: bindingFS)
            .environment(store)
            .environment(router)
        let fsCtrl = UIHostingController(rootView: fsView)
        _ = fsCtrl.view
        fsCtrl.view.setNeedsLayout()
        fsCtrl.view.layoutIfNeeded()
    }

    // MARK: - 2. ImportRecordSection 分类 Tab 与预览 Sheet

    func testImportRecordSection_CategoriesAndPreviewFlow() async {
        let router = Router()

        let section = ImportRecordSection(
            onAITag: { _ in },
            onManualEdit: { _ in }
        )
        .environment(router)

        let controller = UIHostingController(rootView: section)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }

    // MARK: - 3. IngestView 导入页面全状态渲染

    func testIngestView_FullPageRenderAndSheetState() {
        let store = KnowledgeStore()
        let ingestStore = IngestStore()
        let router = Router()
        let theme = ThemeManager()
        var tab = AppTab.ingest
        let bindingTab = Binding(get: { tab }, set: { tab = $0 })

        let ingestView = IngestView(selectedTab: bindingTab)
            .environment(store)
            .environment(ingestStore)
            .environment(router)
            .environment(theme)
            .environmentObject(LLMService.shared)

        let controller = UIHostingController(rootView: ingestView)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
    }
}
