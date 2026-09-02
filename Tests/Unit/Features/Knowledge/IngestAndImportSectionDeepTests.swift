//
//  IngestAndImportSectionDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 IngestView 知识摄取大盘与 ImportRecordSection 导入历史记录卡片。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class IngestAndImportSectionDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. IngestView 顶层视图测试

    func testIngestView_Hierarchy() {
        let host = NavigationStack {
            IngestView(selectedTab: .constant(.ingest))
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. ImportRecordSection 导入分段卡片测试

    func testImportRecordSection_Hierarchy() {
        let host = ImportRecordSection()
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testImportCategory_Properties() {
        for category in ImportCategory.allCases {
            XCTAssertFalse(category.displayName.isEmpty)
            XCTAssertFalse(category.directoryName.isEmpty)
        }
    }
}
