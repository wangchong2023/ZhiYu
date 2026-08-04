//
//  InsightFeatureModuleTests.swift
//  ZhiYuFeaturesTests
//
//  系统层级：[ZhiYuFeaturesTests]
//  核心职责：验证 InsightFeatureModule 的单例契约与模块状态语义。
//

import XCTest
@testable import ZhiYuFeaturesInsight

final class InsightFeatureModuleTests: XCTestCase {

    /// shared 必须是单例
    func testSharedIsSingleton() {
        XCTAssertTrue(InsightFeatureModule.shared === InsightFeatureModule.shared)
    }

    /// getModuleStatus 必须非空
    func testGetModuleStatusNonEmpty() {
        XCTAssertFalse(InsightFeatureModule.shared.getModuleStatus().isEmpty)
    }

    /// getModuleStatus 必须包含 Insight 标识
    func testGetModuleStatusContainsModuleName() {
        let status = InsightFeatureModule.shared.getModuleStatus()
        XCTAssertTrue(status.contains("Insight") || status.contains("ZhiYuFeaturesInsight"))
    }

    /// getModuleStatus 必须包含 Ready
    func testGetModuleStatusContainsReady() {
        XCTAssertTrue(InsightFeatureModule.shared.getModuleStatus().contains("Ready"))
    }

    /// 必须可独立实例化
    func testIndependentInstance() {
        let instance = InsightFeatureModule()
        XCTAssertEqual(instance.getModuleStatus(), InsightFeatureModule.shared.getModuleStatus())
    }

    /// 幂等性
    func testGetModuleStatusIdempotent() {
        XCTAssertEqual(InsightFeatureModule.shared.getModuleStatus(),
                       InsightFeatureModule.shared.getModuleStatus())
    }
}
