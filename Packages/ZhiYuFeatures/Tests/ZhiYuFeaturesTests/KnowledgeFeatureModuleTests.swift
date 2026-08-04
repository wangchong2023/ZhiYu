//
//  KnowledgeFeatureModuleTests.swift
//  ZhiYuFeaturesTests
//
//  系统层级：[ZhiYuFeaturesTests]
//  核心职责：验证 KnowledgeFeatureModule 的单例契约与模块状态语义。
//

import XCTest
@testable import ZhiYuFeaturesKnowledge

final class KnowledgeFeatureModuleTests: XCTestCase {

    /// shared 必须是单例
    func testSharedIsSingleton() {
        XCTAssertTrue(KnowledgeFeatureModule.shared === KnowledgeFeatureModule.shared)
    }

    /// getModuleStatus 必须非空
    func testGetModuleStatusNonEmpty() {
        XCTAssertFalse(KnowledgeFeatureModule.shared.getModuleStatus().isEmpty)
    }

    /// getModuleStatus 必须包含 Knowledge 标识
    func testGetModuleStatusContainsModuleName() {
        let status = KnowledgeFeatureModule.shared.getModuleStatus()
        XCTAssertTrue(status.contains("Knowledge") || status.contains("ZhiYuFeaturesKnowledge"))
    }

    /// getModuleStatus 必须包含 Ready
    func testGetModuleStatusContainsReady() {
        XCTAssertTrue(KnowledgeFeatureModule.shared.getModuleStatus().contains("Ready"))
    }

    /// 必须可独立实例化
    func testIndependentInstance() {
        let instance = KnowledgeFeatureModule()
        XCTAssertEqual(instance.getModuleStatus(), KnowledgeFeatureModule.shared.getModuleStatus())
    }

    /// 幂等性
    func testGetModuleStatusIdempotent() {
        XCTAssertEqual(KnowledgeFeatureModule.shared.getModuleStatus(),
                       KnowledgeFeatureModule.shared.getModuleStatus())
    }
}
