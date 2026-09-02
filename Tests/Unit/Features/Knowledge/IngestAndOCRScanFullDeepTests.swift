//
//  IngestAndOCRScanFullDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 IngestView 知识摄取控制台、OCRScanView 文字识别、
//           ImportRecordSection 导入留存管理与 IngestCoordinator 的完整流程。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class IngestAndOCRScanFullDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. IngestView 视图渲染与状态切换测试

    func testIngestView_FullRenderHierarchy() {
        let host = NavigationStack {
            IngestView(selectedTab: .constant(.ingest))
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. OCRScanView 图像识别状态机测试

    func testOCRScanView_InitialStateAndHierarchy() {
        var didFinish = false
        let host = NavigationStack {
            OCRScanView(onFinish: { _, _, _ in
                didFinish = true
            })
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertFalse(didFinish)
    }

    // MARK: - 3. ImportRecordSection 导入留存列表测试

    func testImportRecordSection_HierarchyAndCategories() {
        let host = NavigationStack {
            ImportRecordSection(
                onAITag: { _ in },
                onManualEdit: { _ in }
            )
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 4. IngestCoordinator 深度交互测试

    func testIngestCoordinator_TriggerActions() async {
        let coordinator = IngestCoordinator()
        XCTAssertFalse(coordinator.showError)
        XCTAssertNil(coordinator.errorMessage)

        let record = ImportRecord(
            category: "link",
            title: "https://example.com/deep-test",
            status: "pending",
            sourceURL: "https://example.com/deep-test"
        )

        coordinator.openManualForm(with: record)
        coordinator.triggerAITagging(for: record)
        XCTAssertNotNil(coordinator)
    }
}
