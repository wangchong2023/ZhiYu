//
//  KnowledgeInsightServiceTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - Insight
//  核心职责：验证 KnowledgeInsightService 实例生命周期与基础功能配置。
//

import XCTest
@testable import ZhiYu

final class KnowledgeInsightServiceTests: XCTestCase {

    /// 验证 KnowledgeInsightService 可正常实例化
    func testKnowledgeInsightService_defaultInit_isInstantiable() async {
        let insightService = KnowledgeInsightService()
        XCTAssertNotNil(insightService, "KnowledgeInsightService 应可被成功实例化")
    }
}
