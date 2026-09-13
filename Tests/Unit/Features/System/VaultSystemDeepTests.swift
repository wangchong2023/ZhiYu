//
//  VaultDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：VaultInsightsAndSubFlowDeepTests.swift, VaultSecurityKeyRotationDeepTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import XCTest

@testable import ZhiYu

@MainActor
final class VaultSystemDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func testVaultInsightsPanel_Hierarchy() {
        let rawPanel = VaultInsightsPanel()
        XCTAssertNotNil(rawPanel)
        let host = rawPanel
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }

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

    func testVaultStorageSecurityServiceUnlock() async throws {
        let service = VaultStorageSecurityService()
        service.lock()
        XCTAssertTrue(service.isLocked)

        let unlocked = await service.unlock()
        XCTAssertTrue(unlocked)
        XCTAssertFalse(service.isLocked)
    }

    func testAuthenticateWithBiometrics() async throws {
        let service = VaultStorageSecurityService()
        let result = await service.authenticateWithBiometrics()
        XCTAssertTrue(result)
    }

}
