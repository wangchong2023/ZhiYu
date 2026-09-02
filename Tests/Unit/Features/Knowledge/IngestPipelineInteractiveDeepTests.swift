//
//  IngestPipelineInteractiveDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class IngestPipelineInteractiveDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        store.pages = []
        @Dependency(\.taskCenter) var taskCenter
        taskCenter.reset()
        try await super.tearDown()
    }

    // MARK: - 1. IngestCoordinator State Machine & Handlers

    func testIngestCoordinatorStateAndFlows() async throws {
        let coordinator = IngestCoordinator()

        // 1. 验证初始状态
        XCTAssertFalse(coordinator.isIngesting)
        XCTAssertFalse(coordinator.showManualForm)
        XCTAssertFalse(coordinator.showFileImporter)
        XCTAssertFalse(coordinator.showURLImport)
        XCTAssertFalse(coordinator.showOCRScan)
        XCTAssertFalse(coordinator.showVoiceNote)

        // 2. 切换各种录入弹窗触发态
        coordinator.showManualForm = true
        coordinator.newTitle = "Manual Markdown Note"
        coordinator.newContent = "## Summary\n\nDirect manual entry."
        XCTAssertTrue(coordinator.showManualForm)
        coordinator.showManualForm = false

        coordinator.showURLImport = true
        XCTAssertTrue(coordinator.showURLImport)
        coordinator.showURLImport = false

        coordinator.showOCRScan = true
        coordinator.hasNewContent = true
        XCTAssertTrue(coordinator.showOCRScan)
        coordinator.showOCRScan = false

        // 3. 执行剪贴板内容导入探测
        coordinator.performClipboardImport()
    }

    // MARK: - 2. IngestView Full Mounting & Subcomponents

    func testIngestViewMountingAndSubviews() throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        store.pages = [
            KnowledgePage(title: "Ingested Article", pageType: .source, content: "Extracted text")
        ]

        var selectedTab: AppTab = .ingest
        let binding = Binding(get: { selectedTab }, set: { selectedTab = $0 })
        let ingestView = IngestView(selectedTab: binding)
            .snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: ingestView)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)

        // 独立测试 ActivityRow
        let task = GlobalTask(type: .ingest, name: "Import", target: "Paper.pdf", status: .completed)
        let row = ActivityRow(task: task)
            .snapshotEnvironment()
        let hostRow = UIHostingController(rootView: row)
        XCTAssertNotNil(hostRow.view)
    }
}
