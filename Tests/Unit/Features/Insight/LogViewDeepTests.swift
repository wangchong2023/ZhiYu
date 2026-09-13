//
//  LogViewDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：LogViewAndDiagnosticsDeepTests.swift, LogViewFilterAndExportDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class LogViewDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func testLogView_Hierarchy_EmptyState() {
        let view = NavigationStack {
            LogView()
        }
        .snapshotEnvironment()

        XCTAssertNotNil(view)
    }

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

    func testLogViewMountingWithEntries() async throws {
        let appStore = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        
        let sampleLog1 = LogEntry(
            id: UUID(),
            action: .create,
            target: "Knowledge Note",
            details: "key: value",
            timestamp: Date(),
            startTime: Date().addingTimeInterval(-2.5),
            endTime: Date(),
            module: "Knowledge",
            status: .success
        )

        let sampleLog2 = LogEntry(
            id: UUID(),
            action: .delete,
            target: "Outdated Draft",
            details: "",
            timestamp: Date().addingTimeInterval(-3600),
            module: "Vault",
            status: .failure,
            failureReason: "Disk I/O Error"
        )

        appStore.logEntries = [sampleLog1, sampleLog2]
        XCTAssertEqual(sampleLog1.action, .create)
        XCTAssertEqual(sampleLog2.status, .failure)

        let view = LogView()
            .snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }

    func testLogViewEmptyStateAndClear() async throws {
        let appStore = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        appStore.logEntries = []

        let emptyView = LogView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: emptyView)
        XCTAssertNotNil(host.view)

        // 测试日志清空接口
        await appStore.clearLogs()
        XCTAssertTrue(appStore.logEntries.isEmpty)
    }

}
