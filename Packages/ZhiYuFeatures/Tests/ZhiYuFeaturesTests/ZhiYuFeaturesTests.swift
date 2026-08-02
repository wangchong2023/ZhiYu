//
//  ZhiYuFeaturesTests.swift
//  ZhiYuFeaturesTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuFeaturesTests]
//  核心职责：智宇垂直业务功能切片包 (ZhiYuFeatures) 单元测试套件。
//

import XCTest
@testable import ZhiYuFeaturesAI
@testable import ZhiYuFeaturesKnowledge
@testable import ZhiYuFeaturesInsight

final class ZhiYuFeaturesTests: XCTestCase {

    func testFeaturesModuleStatus() {
        XCTAssertEqual(AIFeatureModule.shared.getModuleStatus(), "ZhiYuFeaturesAI Ready")
        XCTAssertEqual(KnowledgeFeatureModule.shared.getModuleStatus(), "ZhiYuFeaturesKnowledge Ready")
        XCTAssertEqual(InsightFeatureModule.shared.getModuleStatus(), "ZhiYuFeaturesInsight Ready")
    }
}
