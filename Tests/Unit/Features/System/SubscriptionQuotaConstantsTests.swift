//
//  SubscriptionQuotaConstantsTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - System
//  核心职责：验证 SubscriptionQuota 各项配额限制、无限符号与告警阈值配置。
//

import XCTest
@testable import ZhiYu

final class SubscriptionQuotaConstantsTests: XCTestCase {

    /// 验证 SubscriptionQuota 默认限制常量配置为正值且符号正确
    func testSubscriptionQuota_defaultMaxLimits_arePositive() {
        XCTAssertGreaterThan(FeatureConstants.SubscriptionQuota.defaultMaxVaults, 0)
        XCTAssertGreaterThan(FeatureConstants.SubscriptionQuota.defaultMaxPages, 0)
        XCTAssertGreaterThan(FeatureConstants.SubscriptionQuota.defaultMaxPlugins, 0)
        XCTAssertEqual(FeatureConstants.SubscriptionQuota.unlimitedSymbol, "∞")
    }

    /// 验证 dangerRatioThreshold 在合法区间 (0, 1] 内
    func testSubscriptionQuota_dangerRatioThreshold_withinNormalizedRange() {
        let threshold = FeatureConstants.SubscriptionQuota.dangerRatioThreshold
        XCTAssertGreaterThan(threshold, 0)
        XCTAssertLessThanOrEqual(threshold, 1)
    }
}
