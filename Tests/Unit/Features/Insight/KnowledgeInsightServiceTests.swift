//
//  KnowledgeInsightServiceTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - Insight
//  核心职责：验证 KnowledgeInsightService 实例生命周期与基础功能配置。
//

import XCTest
@testable import ZhiYuUnitTestHost

final class KnowledgeInsightServiceTests: XCTestCase {

    /// 验证 KnowledgeInsightService 可正常实例化
    func testKnowledgeInsightService_defaultInit_isInstantiable() async {
        let insightService = KnowledgeInsightService()
        XCTAssertNotNil(insightService, "KnowledgeInsightService 应可被成功实例化")
    }

    // MARK: - 缺陷 #203 回归：洞察缓存按 Vault 隔离

    func testCacheKeys_isolatedAcrossDifferentVaultScopes() {
        let dailyA = KnowledgeInsightService.buildDailyCacheKey(dateString: "20261127", language: "zh-Hans", vaultScope: "vault-A")
        let dailyB = KnowledgeInsightService.buildDailyCacheKey(dateString: "20261127", language: "zh-Hans", vaultScope: "vault-B")
        XCTAssertNotEqual(dailyA, dailyB, "不同 Vault 的每日见解缓存键必须物理隔离")

        let weeklyA = KnowledgeInsightService.buildWeeklyCacheKey(year: 2026, week: 48, language: "zh-Hans", vaultScope: "vault-A")
        let weeklyB = KnowledgeInsightService.buildWeeklyCacheKey(year: 2026, week: 48, language: "zh-Hans", vaultScope: "vault-B")
        XCTAssertNotEqual(weeklyA, weeklyB, "不同 Vault 的每周洞察缓存键必须物理隔离")
    }
}
