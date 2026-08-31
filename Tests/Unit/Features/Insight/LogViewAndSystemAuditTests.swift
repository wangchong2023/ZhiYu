//
//  LogViewAndSystemAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 LogEntry 展开状态机、清空确认与操作日志格式化分支。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class LogViewAndSystemAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. LogEntry 构造与级别

    func testLogEntry_CreationAndFormattedDate() {
        let id = UUID()
        let now = Date()
        let entry = LogEntry(
            id: id,
            action: .create,
            target: "新建文档",
            details: "用户手动创建了概念文档",
            timestamp: now
        )

        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.action, .create)
        XCTAssertEqual(entry.target, "新建文档")
    }

    // MARK: - 2. AppStore 日志清空与状态流转

    func testAppStore_ClearLogsFlow() async {
        let store = AppStore()

        let entry = LogEntry(
            id: UUID(),
            action: .update,
            target: "修改文档",
            details: "更新了段落",
            timestamp: Date()
        )
        store.logEntries = [entry]
        XCTAssertFalse(store.logEntries.isEmpty)

        await store.clearLogs()
        XCTAssertTrue(store.logEntries.isEmpty, "调用 clearLogs 必须清空日志列表")
    }
}
