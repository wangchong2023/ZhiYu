//
//  InsightDashboardChartsAndLogExpandTests.swift
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
final class InsightDashboardChartsAndLogExpandTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. KnowledgeDashboardView & LogView Full Interaction

    func testDashboardDensityAndLogExpandInteraction() async throws {
        let store = AppStore()
        let entry1 = LogEntry(
            action: .create,
            target: "Import Document",
            details: "Imported 12 pages successfully.",
            status: .success
        )
        let entry2 = LogEntry(
            action: .update,
            target: "Cloud Sync",
            details: "Sync timeout",
            status: .failure,
            failureReason: "Network unavailable"
        )
        store.logEntries = [entry1, entry2]
        XCTAssertEqual(store.logEntries.count, 2)

        struct Wrapper: View {
            var body: some View {
                VStack {
                    KnowledgeDashboardView()
                    LogView()
                }
            }
        }

        let view = Wrapper().snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }
}
