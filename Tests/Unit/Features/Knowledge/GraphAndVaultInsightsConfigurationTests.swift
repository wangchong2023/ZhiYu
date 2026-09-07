//
//  GraphAndVaultInsightsConfigurationTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - Knowledge
//  核心职责：验证 GraphViewModel 边截断缓存初始状态与 VaultInsightsBarRatio 占比常量。
//

import XCTest
@testable import ZhiYu

@MainActor
final class GraphAndVaultInsightsConfigurationTests: XCTestCase {

    /// 验证 GraphViewModel 边缓存字段初始状态
    func testGraphViewModel_cachedFilteredEdges_initiallyEmpty() {
        let vm = GraphViewModel()
        XCTAssertTrue(vm.cachedFilteredEdges.isEmpty, "初始缓存应为空")
        XCTAssertFalse(vm.cachedIsTruncatingEdges, "初始截断标志应为 false")
    }

    /// 验证 FeatureConstants.VaultInsightsBarRatio 各类型占比常量
    func testVaultInsightsBarRatio_constantsMatch() {
        XCTAssertEqual(FeatureConstants.VaultInsightsBarRatio.entity, 0.6)
        XCTAssertEqual(FeatureConstants.VaultInsightsBarRatio.concept, 0.8)
        XCTAssertEqual(FeatureConstants.VaultInsightsBarRatio.source, 0.4)
        XCTAssertEqual(FeatureConstants.VaultInsightsBarRatio.comparison, 0.2)
        XCTAssertEqual(FeatureConstants.VaultInsightsBarRatio.raw, 0.05)
    }
}
