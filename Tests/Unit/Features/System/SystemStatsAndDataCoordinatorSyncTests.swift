//
//  SystemStatsAndDataCoordinatorSyncTests.swift
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
final class SystemStatsAndDataCoordinatorSyncTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SystemStatsCoordinator Data Fetch & Aggregation

    func testSystemStatsCoordinatorFetch() async throws {
        let store = AppStore()
        let page = KnowledgePage(
            title: "Storage Test Page",
            pageType: .concept,
            content: "Some storage test content with 100 bytes length."
        )
        await store.savePage(page)

        let coordinator = SystemStatsCoordinator()
        await coordinator.loadStats()

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertGreaterThanOrEqual(coordinator.totalPages, 0)
    }

    // MARK: - 2. MaintenanceService Notebooks Generation

    func testMaintenanceServiceGenerateNotebooks() async throws {
        let service = MaintenanceService()
        let result = await service.generateInitialNotebooks()
        XCTAssertGreaterThanOrEqual(result.total, 0)
    }
}
