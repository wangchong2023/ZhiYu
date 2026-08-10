//
//  KnowledgeInsightServiceTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 KnowledgeInsightService 的每日召回、周报生成、缓存命中与 LLM 响应解析逻辑。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class KnowledgeInsightServiceTests: XCTestCase {

    /// 被测服务实例
    private var service: KnowledgeInsightService!

    /// Mock LLM 服务
    private var llm: MockLLMService!

    /// 测试用 KeyStore（UserDefaults 实例）
    private var keyStore: UserDefaultsKeyStore!

    /// 缓存 key 前缀清理集合
    private var injectedKeys: [String] = []

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        service = KnowledgeInsightService()
        llm = MockLLMService()
        keyStore = UserDefaultsKeyStore.shared
        // 清理可能残留的缓存
        clearInsightCaches()
    }

    override func tearDown() async throws {
        clearInsightCaches()
        service = nil
        llm = nil
        keyStore = nil
        try? await Task.sleep(nanoseconds: 50_000_000)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    /// 清理洞察缓存
    private func clearInsightCaches() {
        for key in keyStore.dictionaryRepresentation().keys {
            if key.hasPrefix(AppConstants.Keys.Storage.dailyRecapPrefix)
                || key.hasPrefix(AppConstants.Keys.Storage.weeklyInsightPrefix) {
                keyStore.removeObject(forKey: key)
            }
        }
    }

    // MARK: - generateDailyRecap

    /// 验证空页面列表抛出"请先添加页面"错误
    func testGenerateDailyRecapEmptyPagesThrows() async {
        do {
            _ = try await service.generateDailyRecap(pages: [], llmService: llm)
            XCTFail("空页面列表应抛出错误")
        } catch {
            let nsError = error as NSError
            XCTAssertTrue(nsError.localizedDescription.contains(L10n.Dashboard.insight.addPagesFirst)
                          || nsError.code == -2, "应抛出 insight 错误")
        }
    }

    /// 验证 forceRefresh=true 时跳过缓存直接调用 LLM
    func testGenerateDailyRecapForceRefreshBypassesCache() async throws {
        let page = KnowledgePage(title: "测试页面", pageType: .concept, content: "内容")
        let mockResponse = "{\"insight\":\"这是洞察\",\"suggestedConnection\":\"建议连接\"}"
        llm.generateHandler = { _, _ in mockResponse }

        let recap = try await service.generateDailyRecap(pages: [page], llmService: llm, forceRefresh: true)

        XCTAssertEqual(recap.targetPageID, page.id, "目标页面 ID 应匹配")
        XCTAssertEqual(recap.targetPageTitle, "测试页面", "目标页面标题应匹配")
        XCTAssertEqual(recap.insight, "这是洞察", "应从 JSON 提取 insight 字段")
        XCTAssertEqual(recap.suggestedConnection, "建议连接", "应从 JSON 提取 suggestedConnection 字段")
    }

    /// 验证 LLM 返回非 JSON 时回退到原始响应
    func testGenerateDailyRecapNonJSONResponseFallback() async throws {
        let page = KnowledgePage(title: "回退页面", pageType: .concept, content: "内容")
        llm.generateHandler = { _, _ in "这是纯文本洞察，不是 JSON" }

        let recap = try await service.generateDailyRecap(pages: [page], llmService: llm, forceRefresh: true)

        XCTAssertEqual(recap.insight, "这是纯文本洞察，不是 JSON", "非 JSON 响应应回退为原始文本")
        XCTAssertEqual(recap.suggestedConnection, L10n.Dashboard.insight.recap.tip, "非 JSON 时建议连接应为默认提示")
    }

    /// 验证缓存命中时不再调用 LLM
    func testGenerateDailyRecapCacheHitSkipsLLM() async throws {
        let page = KnowledgePage(title: "缓存页面", pageType: .concept, content: "内容")
        var llmCallCount = 0
        llm.generateHandler = { _, _ in
            llmCallCount += 1
            return "{\"insight\":\"首次生成\",\"suggestedConnection\":\"\"}"
        }

        // 第一次生成（forceRefresh=true 跳过缓存）
        let firstRecap = try await service.generateDailyRecap(pages: [page], llmService: llm, forceRefresh: true)
        XCTAssertEqual(llmCallCount, 1, "首次生成应调用 LLM 一次")
        XCTAssertEqual(firstRecap.insight, "首次生成")

        // 第二次生成（forceRefresh=false，应命中缓存）
        let cachedRecap = try await service.generateDailyRecap(pages: [page], llmService: llm, forceRefresh: false)
        XCTAssertEqual(llmCallCount, 1, "缓存命中时不应再次调用 LLM")
        XCTAssertEqual(cachedRecap.insight, "首次生成", "缓存返回应与首次一致")
    }

    /// 验证缓存中页面不存在时重新生成
    func testGenerateDailyRecapCacheMissWhenPageRemoved() async throws {
        let page1 = KnowledgePage(title: "页面1", pageType: .concept, content: "内容1")
        let page2 = KnowledgePage(title: "页面2", pageType: .concept, content: "内容2")

        var callCount = 0
        llm.generateHandler = { _, _ in
            callCount += 1
            return "{\"insight\":\"洞察\(callCount)\",\"suggestedConnection\":\"\"}"
        }

        // 用 page1 生成缓存
        _ = try await service.generateDailyRecap(pages: [page1], llmService: llm, forceRefresh: true)
        XCTAssertEqual(callCount, 1)

        // 用 page2（不含 page1）应重新生成
        let recap = try await service.generateDailyRecap(pages: [page2], llmService: llm, forceRefresh: false)
        XCTAssertEqual(callCount, 2, "缓存中页面不存在时应重新调用 LLM")
        XCTAssertEqual(recap.targetPageID, page2.id)
    }

    // MARK: - generateWeeklyInsight

    /// 验证周报生成包含新增页面数与关键词
    func testGenerateWeeklyInsightBasic() async throws {
        let now = Date()
        let recentPage = KnowledgePage(
            title: "新页面",
            pageType: .concept,
            content: "内容",
            tags: ["Swift", "iOS", "RAG"],
            createdAt: now.addingTimeInterval(3600)
        )

        llm.generateHandler = { _, _ in "本周知识增长稳定" }

        let insight = try await service.generateWeeklyInsight(pages: [recentPage], llmService: llm, forceRefresh: true)

        XCTAssertEqual(insight.totalNewPages, 1, "新增页面数应为 1")
        XCTAssertEqual(insight.aiSummary, "本周知识增长稳定", "AI 摘要应匹配 LLM 返回")
        XCTAssertFalse(insight.dateRange.isEmpty, "日期范围不应为空")
        XCTAssertLessThanOrEqual(insight.topKeywords.count, 5, "关键词数量应不超过 5")
    }

    /// 验证周报缓存命中
    func testGenerateWeeklyInsightCacheHit() async throws {
        let page = KnowledgePage(title: "周报页面", pageType: .concept, content: "内容")
        var callCount = 0
        llm.generateHandler = { _, _ in
            callCount += 1
            return "周报摘要\(callCount)"
        }

        _ = try await service.generateWeeklyInsight(pages: [page], llmService: llm, forceRefresh: true)
        XCTAssertEqual(callCount, 1)

        let cached = try await service.generateWeeklyInsight(pages: [page], llmService: llm, forceRefresh: false)
        XCTAssertEqual(callCount, 1, "缓存命中时不应调用 LLM")
        XCTAssertEqual(cached.aiSummary, "周报摘要1")
    }

    /// 验证新增页面超过爆发阈值时增长趋势为"爆发式"
    func testGenerateWeeklyInsightExplosiveGrowth() async throws {
        var pages: [KnowledgePage] = []
        for i in 1...6 {
            pages.append(KnowledgePage(
                title: "P\(i)",
                pageType: .concept,
                content: "c\(i)",
                createdAt: Date().addingTimeInterval(3600)
            ))
        }
        llm.generateHandler = { _, _ in "爆发式增长" }

        let insight = try await service.generateWeeklyInsight(pages: pages, llmService: llm, forceRefresh: true)

        XCTAssertEqual(insight.growthTraction, L10n.Dashboard.insight.growth.explosive, "6 个新页面应触发爆发式增长")
    }

    /// 验证新增页面低于阈值时增长趋势为"稳定"
    func testGenerateWeeklyInsightSteadyGrowth() async throws {
        let page = KnowledgePage(title: "P1", pageType: .concept, content: "c", createdAt: Date())
        llm.generateHandler = { _, _ in "稳定增长" }

        let insight = try await service.generateWeeklyInsight(pages: [page], llmService: llm, forceRefresh: true)

        XCTAssertEqual(insight.growthTraction, L10n.Dashboard.insight.growth.steady, "1 个新页面应为稳定增长")
    }

    /// 验证无新增页面时周报仍能生成
    func testGenerateWeeklyInsightNoNewPages() async throws {
        let oldPage = KnowledgePage(
            title: "旧页面",
            pageType: .concept,
            content: "内容",
            createdAt: Date().addingTimeInterval(-30 * 24 * 3600)
        )
        llm.generateHandler = { _, _ in "本周无新增" }

        let insight = try await service.generateWeeklyInsight(pages: [oldPage], llmService: llm, forceRefresh: true)

        XCTAssertEqual(insight.totalNewPages, 0, "无新增页面时计数应为 0")
        XCTAssertEqual(insight.growthTraction, L10n.Dashboard.insight.growth.steady, "无新增应为稳定增长")
    }
}
