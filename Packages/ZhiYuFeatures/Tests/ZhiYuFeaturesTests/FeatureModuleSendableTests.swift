//
//  FeatureModuleSendableTests.swift
//  ZhiYuFeaturesTests
//
//  系统层级：[ZhiYuFeaturesTests]
//  核心职责：验证 3 个 FeatureModule 的 Sendable 遵循（可跨 actor 传递）。
//

import XCTest
@testable import ZhiYuFeaturesAI
@testable import ZhiYuFeaturesKnowledge
@testable import ZhiYuFeaturesInsight

final class FeatureModuleSendableTests: XCTestCase {

    /// AIFeatureModule 必须可跨 actor 传递
    func testAIFeatureModuleSendable() async {
        let module = AIFeatureModule.shared
        await Task {
            XCTAssertEqual(module.getModuleStatus(), "ZhiYuFeaturesAI Ready")
        }.value
    }

    /// KnowledgeFeatureModule 必须可跨 actor 传递
    func testKnowledgeFeatureModuleSendable() async {
        let module = KnowledgeFeatureModule.shared
        await Task {
            XCTAssertEqual(module.getModuleStatus(), "ZhiYuFeaturesKnowledge Ready")
        }.value
    }

    /// InsightFeatureModule 必须可跨 actor 传递
    func testInsightFeatureModuleSendable() async {
        let module = InsightFeatureModule.shared
        await Task {
            XCTAssertEqual(module.getModuleStatus(), "ZhiYuFeaturesInsight Ready")
        }.value
    }

    /// 并发访问 3 个模块不崩溃
    func testConcurrentAccessAllModules() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = AIFeatureModule.shared.getModuleStatus()
            }
            group.addTask {
                _ = KnowledgeFeatureModule.shared.getModuleStatus()
            }
            group.addTask {
                _ = InsightFeatureModule.shared.getModuleStatus()
            }
        }
        XCTAssertTrue(true, "并发访问 3 个模块不崩溃")
    }
}
