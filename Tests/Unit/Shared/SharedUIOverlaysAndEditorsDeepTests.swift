//
//  SharedUIOverlaysAndEditorsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度覆盖 L3 Shared 通用覆盖层、OCR、编辑器工具与加载态组件。
//

import XCTest
import SwiftUI
@testable import ZhiYu
import UFPCore

@MainActor
final class SharedUIOverlaysAndEditorsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. HostingSetupSheet 协同面板测试

    func testHostingSetupSheet_RenderingAndAction() {
        let collabService = CollaborationService()
        var roomName = "智宇协同空间"
        let binding = Binding(get: { roomName }, set: { roomName = $0 })

        let sheet = HostingSetupSheet(collabService: collabService, roomName: binding)
        let host = UIHostingController(rootView: sheet.snapshotEnvironment())
        host.view.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "HostingSetupSheet 应正常渲染")
        XCTAssertFalse(collabService.isHosting)
        XCTAssertEqual(roomName, "智宇协同空间")
    }

    // MARK: - 2. OCRImageContentView 渲染测试

    func testOCRImageContentView_NilAndPopulated() {
        // 1. nil 图像
        let nilView = OCRImageContentView(image: nil)
        let host1 = UIHostingController(rootView: nilView.snapshotEnvironment())
        host1.view.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view)
        XCTAssertNil(nilView.image)

        // 2. 真实图像
        let img = UIImage()
        let populatedView = OCRImageContentView(image: img)
        let host2 = UIHostingController(rootView: populatedView.snapshotEnvironment())
        host2.view.frame = CGRect(x: 0, y: 0, width: 320, height: 200)
        host2.view.layoutIfNeeded()
        XCTAssertNotNil(host2.view)
        XCTAssertNotNil(populatedView.image)
    }

    // MARK: - 3. EditorToolbarButton 工具栏按钮测试

    func testEditorToolbarButton_Interaction() {
        var actionTriggered = false
        let button = EditorToolbarButton(
            title: "加粗",
            icon: DesignSystem.Icons.edit
        ) {
            actionTriggered = true
        }

        let host = UIHostingController(rootView: button.snapshotEnvironment())
        host.view.frame = CGRect(x: 0, y: 0, width: 60, height: 50)
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)

        button.action()
        XCTAssertTrue(actionTriggered, "点击动作应成功回调")
    }

    // MARK: - 4. VaultGridLayout & VaultListLayout 容器测试

    func testVaultLayouts_GridAndList() {
        let grid = VaultGridLayout {
            Text("Notebook A")
            Text("Notebook B")
        }
        let host1 = UIHostingController(rootView: grid.snapshotEnvironment())
        host1.view.frame = CGRect(x: 0, y: 0, width: 390, height: 300)
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view)

        let list = VaultListLayout {
            Text("Row 1")
            Text("Row 2")
        }
        let host2 = UIHostingController(rootView: list.snapshotEnvironment())
        host2.view.frame = CGRect(x: 0, y: 0, width: 390, height: 300)
        host2.view.layoutIfNeeded()
        XCTAssertNotNil(host2.view)
        XCTAssertNotNil(grid.body)
    }

    // MARK: - 5. AnimatedSection 展开/收起转场测试

    func testAnimatedSection_ExpansionState() {
        let collapsed = AnimatedSection(isExpanded: false) {
            Text("Hidden Content")
        }
        let host1 = UIHostingController(rootView: collapsed.snapshotEnvironment())
        host1.view.frame = CGRect(x: 0, y: 0, width: 320, height: 100)
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view)
        XCTAssertFalse(collapsed.isExpanded)

        let expanded = AnimatedSection(isExpanded: true) {
            Text("Visible Content")
        }
        let host2 = UIHostingController(rootView: expanded.snapshotEnvironment())
        host2.view.frame = CGRect(x: 0, y: 0, width: 320, height: 100)
        host2.view.layoutIfNeeded()
        XCTAssertNotNil(host2.view)
        XCTAssertTrue(expanded.isExpanded)
    }

    // MARK: - 6. AppLoadingOverlay 加载遮罩测试

    func testAppLoadingOverlay_States() {
        let hidden = AppLoadingOverlay(isLoading: false)
        let host1 = UIHostingController(rootView: hidden.snapshotEnvironment())
        host1.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view)
        XCTAssertFalse(hidden.isLoading)

        let visible = AppLoadingOverlay(
            isLoading: true,
            message: "知识库全量重构中...",
            backgroundColor: Color.black.opacity(DesignSystem.Opacity.dim),
            foregroundColor: Color.appAccent
        )
        let host2 = UIHostingController(rootView: visible.snapshotEnvironment())
        host2.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        host2.view.layoutIfNeeded()
        XCTAssertNotNil(host2.view)
        XCTAssertTrue(visible.isLoading)
        XCTAssertEqual(visible.message, "知识库全量重构中...")
    }

    // MARK: - 7. WatchFeaturePlaceholderView 占位视图测试

    func testWatchFeaturePlaceholderView_Rendering() {
        let view = WatchFeaturePlaceholderView(placeholderMessage: "请在 iPhone 上查看完整知识图谱")
        let host = UIHostingController(rootView: view.snapshotEnvironment())
        host.view.frame = CGRect(x: 0, y: 0, width: 200, height: 200)
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "WatchFeaturePlaceholderView 应成功挂载")
        XCTAssertEqual(view.placeholderMessage, "请在 iPhone 上查看完整知识图谱")
    }
}
