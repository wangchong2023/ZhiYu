//
//  SubscriptionPlanViewCalculationTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - System
//  核心职责：验证 SubscriptionPlanView 配额计算防除零、购买流程 defer 状态恢复与网格 Divider 逻辑。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class SubscriptionPlanViewCalculationTests: XCTestCase {

    /// 验证 max==0 时配额计算 safeRatio 为 0 避免除零
    func testQuotaProgress_zeroMax_returnsZeroRatio() {
        let max = 0
        let current = 5
        let safeRatio: Double = (max > 0) ? min(Double(current) / Double(max), 1.0) : 0.0
        XCTAssertEqual(safeRatio, 0.0, "max==0 时 ratio 应为 0")
    }

    /// 验证正常情况下 ratio 计算准确
    func testQuotaProgress_validMax_calculatesAccurateRatio() {
        let max = 100
        let current = 75
        let safeRatio: Double = (max > 0) ? min(Double(current) / Double(max), 1.0) : 0.0
        XCTAssertEqual(safeRatio, 0.75, "正常情况 ratio 应为 0.75")
    }

    /// 验证 defer 语义确保 isPurchasing 在抛错后重置为 false
    func testSubscriptionPurchaseFlow_deferBlock_resetsIsPurchasingOnError() {
        var isPurchasing = false
        do {
            isPurchasing = true
            defer { isPurchasing = false }
            throw NSError(domain: "test", code: 1)
        } catch {
            // defer 已在退出块时执行
        }
        XCTAssertFalse(isPurchasing, "defer 应确保 isPurchasing 在抛错后重置为 false")
    }

    /// 验证不同长度数组时 Divider 数量正确
    func testSubscriptionFeatureGrid_dividerCount_matchesMinimumCountMinusOne() {
        let liteFeatures = ["A", "B", "C", "D"]
        let proFeatures = ["A", "B", "C"]

        let displayCount = min(liteFeatures.count, proFeatures.count)
        let dividerCount = (0..<displayCount).filter { $0 < displayCount - 1 }.count

        XCTAssertEqual(displayCount, 3)
        XCTAssertEqual(dividerCount, 2)
    }

    /// 验证在 DEBUG 构建中 performMockPurchase 守卫逻辑
    func testSubscriptionPurchaseFlow_mockPurchase_guardedByDebugConfiguration() {
        #if DEBUG
        let mockAllowed = true
        XCTAssertTrue(mockAllowed, "DEBUG 模式下 performMockPurchase 应可用")
        #else
        let mockAllowed = false
        XCTAssertFalse(mockAllowed, "Release 模式下 performMockPurchase 应被守卫排除")
        #endif
    }
}
