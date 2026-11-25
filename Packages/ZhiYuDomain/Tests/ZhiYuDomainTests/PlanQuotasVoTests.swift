//
//  PlanQuotasVoTests.swift
//  ZhiYuDomainTests
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：验证 PlanQuotasVo 与 SubscriptionQuotaConstants 的配额基线及 JSON 编解码契约。
//

import XCTest
@testable import ZhiYuDomain

final class PlanQuotasVoTests: XCTestCase {

    func testFreeAndProDefaultsAlignWithConstants() {
        let free = PlanQuotasVo.createFreeDefault
        XCTAssertEqual(free.maxKnowledgePages, SubscriptionQuotaConstants.Free.maxKnowledgePages)
        XCTAssertEqual(free.maxVaultsCount, SubscriptionQuotaConstants.Free.maxVaultsCount)
        XCTAssertEqual(free.maxFileSizeMb, SubscriptionQuotaConstants.Free.maxFileSizeMb)
        XCTAssertFalse(free.cloudLlmModelsEnabled)

        let pro = PlanQuotasVo.createProDefault
        XCTAssertEqual(pro.maxKnowledgePages, SubscriptionQuotaConstants.Pro.maxKnowledgePages)
        XCTAssertEqual(pro.maxVaultsCount, SubscriptionQuotaConstants.Pro.maxVaultsCount)
        XCTAssertEqual(pro.maxFileSizeMb, SubscriptionQuotaConstants.Pro.maxFileSizeMb)
        XCTAssertTrue(pro.cloudLlmModelsEnabled)
        XCTAssertTrue(pro.vectorSearchEnabled)
    }

    func testSnakeCaseJSONRoundTrip() throws {
        let original = PlanQuotasVo.createProDefault
        let data = try JSONEncoder().encode(original)
        let jsonString = try XCTUnwrap(String(data: data, encoding: .utf8))
        XCTAssertTrue(jsonString.contains("max_knowledge_pages"))
        let decoded = try JSONDecoder().decode(PlanQuotasVo.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
