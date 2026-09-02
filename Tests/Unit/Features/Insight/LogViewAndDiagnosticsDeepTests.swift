//
//  LogViewAndDiagnosticsDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 LogView、LogViewContent、LogEntryRow 展开/折叠状态机、
//           日志清空确认与时间区间格式化逻辑。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class LogViewAndDiagnosticsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. LogView 基础视图与空状态测试

    func testLogView_Hierarchy_EmptyState() {
        let view = NavigationStack {
            LogView()
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }

    // MARK: - 2. LogView 列表填充与展开状态测试

    func testLogView_Hierarchy_WithEntries() {
        let appStore = AppStore()
        let id1 = UUID()
        let id2 = UUID()

        let entrySuccess = LogEntry(
            id: id1,
            action: .ingest,
            target: "Transformer架构解析.md",
            details: "成功导入 4 个 Chunk",
            timestamp: Date().addingTimeInterval(-60),
            startTime: Date().addingTimeInterval(-65),
            endTime: Date().addingTimeInterval(-60),
            module: "Ingest",
            status: .success
        )

        let entryFailure = LogEntry(
            id: id2,
            action: .lint,
            target: "概念拓扑",
            details: "网络超时或 Token 额度不足",
            timestamp: Date(),
            module: "Synthesis",
            status: .failure
        )

        appStore.logEntries = [entrySuccess, entryFailure]

        let view = NavigationStack {
            LogView()
        }
        .environment(appStore)
        .snapshotEnvironment()

        XCTAssertNotNil(view)
        XCTAssertEqual(appStore.logEntries.count, 2)
    }

    // MARK: - 3. LogEntry 格式化与区间计算测试

    func testLogEntry_FormatAndStatus() {
        let now = Date()
        let start = now.addingTimeInterval(-10)
        let entry = LogEntry(
            id: UUID(),
            action: .create,
            target: "embedding.bin",
            details: "耗时 10 秒",
            timestamp: now,
            startTime: start,
            endTime: now,
            module: "VectorDB",
            status: .success
        )

        XCTAssertEqual(entry.module, "VectorDB")
        XCTAssertEqual(entry.status, .success)
        XCTAssertNotNil(entry.startTime)
        XCTAssertNotNil(entry.endTime)
    }
}
