//
//  FeatureGateManagerTests.swift
//  ZhiYuTests
//
//  Created by Constantine on 2026/07/23.
//  Description: FeatureGateManager & PlanQuotasVo 单元测试
//

import XCTest
@testable import ZhiYu

final class FeatureGateManagerTests: XCTestCase {

    private var testUserDefaults: UserDefaults?
    private var sut: FeatureGateManager?

    override func setUp() {
        super.setUp()
        let suite = UserDefaults(suiteName: "FeatureGateManagerTestsDomain")
        suite?.removePersistentDomain(forName: "FeatureGateManagerTestsDomain")
        testUserDefaults = suite
        if let defaults = testUserDefaults {
            sut = FeatureGateManager(userDefaults: defaults)
        }
    }

    override func tearDown() {
        testUserDefaults?.removePersistentDomain(forName: "FeatureGateManagerTestsDomain")
        testUserDefaults = nil
        sut = nil
        super.tearDown()
    }

    func testPlanQuotasVoJSONDecoding() throws {
        let jsonString = """
        {
            "max_knowledge_pages": 1000,
            "max_vaults_count": 2,
            "max_file_size_mb": 10,
            "daily_ai_messages": 20,
            "cloud_llm_models_enabled": false,
            "vector_search_enabled": true,
            "graph_advanced_enabled": false,
            "audio_overview_enabled": false,
            "large_attachment_sync": false,
            "advanced_export_enabled": true,
            "spotlight_indexing_enabled": false,
            "pro_plugins_enabled": false,
            "custom_local_llm_enabled": true,
            "ad_free_enabled": true
        }
        """
        let jsonData = Data(jsonString.utf8)

        let decoder = JSONDecoder()
        let vo = try decoder.decode(PlanQuotasVo.self, from: jsonData)

        XCTAssertEqual(vo.maxKnowledgePages, 1000)
        XCTAssertEqual(vo.maxVaultsCount, 2)
        XCTAssertTrue(vo.vectorSearchEnabled)
        XCTAssertTrue(vo.advancedExportEnabled)
        XCTAssertTrue(vo.customLocalLlmEnabled)
    }

    func testOfflineFallbackToColdStartBaseline() throws {
        let gateManager = try XCTUnwrap(sut)
        gateManager.clearQuotasCache()
        
        // 无缓存时应当生效冷启动基线 (Lite)
        XCTAssertTrue(gateManager.isFeatureEnabled(\.customLocalLlmEnabled))
        XCTAssertTrue(gateManager.isFeatureEnabled(\.adFreeEnabled))
        XCTAssertFalse(gateManager.isFeatureEnabled(\.cloudLlmModelsEnabled))
        XCTAssertFalse(gateManager.isFeatureEnabled(\.vectorSearchEnabled))

        XCTAssertEqual(gateManager.getQuotaLimit(\.maxKnowledgePages), 1000)
        XCTAssertEqual(gateManager.getQuotaLimit(\.maxVaultsCount), 2)
    }

    func testCacheFirstPreservesProPlanOffline() throws {
        let gateManager = try XCTUnwrap(sut)
        let proVo = PlanQuotasVo.createProDefault
        gateManager.updateActiveQuotas(proVo)

        // 重新实例模拟冷启动
        let defaults = try XCTUnwrap(testUserDefaults)
        let sut2 = FeatureGateManager(userDefaults: defaults)

        XCTAssertTrue(sut2.isFeatureEnabled(\.vectorSearchEnabled))
        XCTAssertTrue(sut2.isFeatureEnabled(\.cloudLlmModelsEnabled))
        XCTAssertFalse(sut2.isFeatureEnabled(\.graphAdvancedEnabled))
        XCTAssertFalse(sut2.isFeatureEnabled(\.audioOverviewEnabled))
        XCTAssertEqual(sut2.getQuotaLimit(\.maxKnowledgePages), 50000)
        XCTAssertEqual(sut2.getQuotaLimit(\.dailyAiMessages), -1)
        XCTAssertFalse(sut2.isQuotaExceeded(\.maxKnowledgePages, currentUsage: 49999))
    }
}
