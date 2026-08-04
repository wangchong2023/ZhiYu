//
//  FeatureModuleIsolationTests.swift
//  ZhiYuFeaturesTests
//
//  系统层级：[ZhiYuFeaturesTests]
//  核心职责：验证 3 个 FeatureModule 的状态字符串互不相同（模块隔离契约）。
//

import XCTest
@testable import ZhiYuFeaturesAI
@testable import ZhiYuFeaturesKnowledge
@testable import ZhiYuFeaturesInsight

final class FeatureModuleIsolationTests: XCTestCase {

    /// 3 个模块的 status 必须互不相同
    func testModuleStatusesDistinct() {
        let ai = AIFeatureModule.shared.getModuleStatus()
        let knowledge = KnowledgeFeatureModule.shared.getModuleStatus()
        let insight = InsightFeatureModule.shared.getModuleStatus()

        XCTAssertNotEqual(ai, knowledge, "AI 与 Knowledge 状态必须不同")
        XCTAssertNotEqual(ai, insight, "AI 与 Insight 状态必须不同")
        XCTAssertNotEqual(knowledge, insight, "Knowledge 与 Insight 状态必须不同")
    }

    /// 3 个模块的 shared 必须是不同实例（类型不同）
    func testModuleSingletonsDifferentTypes() {
        let ai = AIFeatureModule.shared
        let knowledge = KnowledgeFeatureModule.shared
        let insight = InsightFeatureModule.shared

        XCTAssertTrue(type(of: ai) != type(of: knowledge))
        XCTAssertTrue(type(of: ai) != type(of: insight))
        XCTAssertTrue(type(of: knowledge) != type(of: insight))
    }

    /// 所有模块状态都必须包含 "Ready"
    func testAllModulesReady() {
        XCTAssertTrue(AIFeatureModule.shared.getModuleStatus().contains("Ready"))
        XCTAssertTrue(KnowledgeFeatureModule.shared.getModuleStatus().contains("Ready"))
        XCTAssertTrue(InsightFeatureModule.shared.getModuleStatus().contains("Ready"))
    }

    /// 所有模块状态都必须包含 "ZhiYuFeatures" 前缀
    func testAllModulesContainZhiYuFeaturesPrefix() {
        XCTAssertTrue(AIFeatureModule.shared.getModuleStatus().contains("ZhiYuFeatures"))
        XCTAssertTrue(KnowledgeFeatureModule.shared.getModuleStatus().contains("ZhiYuFeatures"))
        XCTAssertTrue(InsightFeatureModule.shared.getModuleStatus().contains("ZhiYuFeatures"))
    }
}
