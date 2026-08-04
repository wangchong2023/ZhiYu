//
//  AIFeatureModuleTests.swift
//  ZhiYuFeaturesTests
//
//  系统层级：[ZhiYuFeaturesTests]
//  核心职责：验证 AIFeatureModule 的单例契约与模块状态语义。
//

import XCTest
@testable import ZhiYuFeaturesAI

final class AIFeatureModuleTests: XCTestCase {

    /// shared 必须是单例（同一引用）
    func testSharedIsSingleton() {
        XCTAssertTrue(AIFeatureModule.shared === AIFeatureModule.shared)
    }

    /// getModuleStatus 必须返回非空字符串
    func testGetModuleStatusNonEmpty() {
        let status = AIFeatureModule.shared.getModuleStatus()
        XCTAssertFalse(status.isEmpty, "模块状态必须非空")
    }

    /// getModuleStatus 必须包含模块名标识
    func testGetModuleStatusContainsModuleName() {
        let status = AIFeatureModule.shared.getModuleStatus()
        XCTAssertTrue(status.contains("AI") || status.contains("ZhiYuFeaturesAI"),
                      "模块状态必须包含 AI 标识")
    }

    /// getModuleStatus 必须包含 "Ready" 状态
    func testGetModuleStatusContainsReady() {
        let status = AIFeatureModule.shared.getModuleStatus()
        XCTAssertTrue(status.contains("Ready"), "模块状态必须包含 Ready")
    }

    /// 必须可独立实例化（非仅 shared）
    func testIndependentInstance() {
        let instance = AIFeatureModule()
        XCTAssertNotNil(instance)
        XCTAssertEqual(instance.getModuleStatus(), AIFeatureModule.shared.getModuleStatus())
    }

    /// 多次调用 getModuleStatus 必须返回一致结果（幂等）
    func testGetModuleStatusIdempotent() {
        let s1 = AIFeatureModule.shared.getModuleStatus()
        let s2 = AIFeatureModule.shared.getModuleStatus()
        XCTAssertEqual(s1, s2)
    }
}
