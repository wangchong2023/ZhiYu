//
//  VaultInsightsAndSubFlowDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 VaultInsightsPanel 笔记本数据洞察面板与 SubscriptionPurchaseFlow 订阅流程。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
@testable import ZhiYu

@MainActor
final class VaultInsightsAndSubFlowDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. VaultInsightsPanel 渲染测试

    func testVaultInsightsPanel_Hierarchy() {
        let host = VaultInsightsPanel()
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. SubscriptionPurchaseFlow 渲染测试

    func testSubscriptionPurchaseFlow_YearlyAndMonthly() {
        let yearlyHost = SubscriptionPurchaseFlow(
            isPurchasing: .constant(false),
            isUpgradeSuccess: .constant(false),
            errorMessage: .constant(nil),
            selectedCycle: .yearly
        )
        .snapshotEnvironment()
        .renderInWindow()
        XCTAssertNotNil(yearlyHost.view)

        let monthlyHost = SubscriptionPurchaseFlow(
            isPurchasing: .constant(false),
            isUpgradeSuccess: .constant(false),
            errorMessage: .constant(nil),
            selectedCycle: .monthly
        )
        .snapshotEnvironment()
        .renderInWindow()
        XCTAssertNotNil(monthlyHost.view)
    }
}
