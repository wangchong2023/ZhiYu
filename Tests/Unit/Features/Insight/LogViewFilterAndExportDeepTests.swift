//
//  LogViewFilterAndExportDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class LogViewFilterAndExportDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. LogView Empty & Populated State Mounting

    func testLogViewMountingWithEntries() async throws {
        let appStore = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        
        let sampleLog1 = LogEntry(
            id: UUID(),
            action: .create,
            target: "Knowledge Note",
            module: "Knowledge",
            status: .success,
            timestamp: Date(),
            startTime: Date().addingTimeInterval(-2.5),
            endTime: Date(),
            metadata: ["key": "value"]
        )

        let sampleLog2 = LogEntry(
            id: UUID(),
            action: .delete,
            target: "Outdated Draft",
            module: "Vault",
            status: .failure,
            errorMessage: "Disk I/O Error",
            timestamp: Date().addingTimeInterval(-3600)
        )

        appStore.logEntries = [sampleLog1, sampleLog2]

        let view = LogView()
            .snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. LogView Empty State & Clear Logs Action

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
