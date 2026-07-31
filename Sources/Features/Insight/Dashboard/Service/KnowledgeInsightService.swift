//
//  KnowledgeInsightService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：实现 KnowledgeInsight 模块的核心业务逻辑服务。
//
import Foundation
/// 知识见解服务 (PM 视角：价值闭环)
/// 负责生成知识周报与核心趋势分析。
actor KnowledgeInsightService {
    static let shared = KnowledgeInsightService()
    public struct WeeklyInsight: Codable, Equatable {
        public let dateRange: String
        public let totalNewPages: Int
        public let topKeywords: [String]
        public let aiSummary: String
        public let growthTraction: String // 增长趋势描述
    }

    public struct DailyRecap: Codable, Equatable {
        public let targetPageID: UUID
        public let targetPageTitle: String
        public let insight: String
        public let suggestedConnection: String
    }

    /// 生成每日主动召回见解 (Smart Recall)
    /// 每天仅生成一次，结果缓存至 UserDefaults。用户手动刷新时跳过缓存。
    func generateDailyRecap(pages: [KnowledgePage], llmService: any LLMServiceProtocol, forceRefresh: Bool = false) async throws -> DailyRecap {
        guard !pages.isEmpty else { throw AppError.insight(L10n.Dashboard.insight.addPagesFirst) }

        // 是否处于自动化 UI 测试模式
        let isTesting = ProcessInfo.processInfo.arguments.contains("--uitesting") || ProcessInfo.processInfo.environment["UITesting"] == "true"

        // 1. 尝试从本地加载有效缓存
        if let cached = await loadValidCache(pages: pages, forceRefresh: forceRefresh, isTesting: isTesting) {
            return cached
        }

        // 2. 测试靶场下的智能自愈
        if isTesting {
            guard let target = pages.first else {
                throw AppError.insight(L10n.Dashboard.insight.addPagesFirst)
            }
            let recap = DailyRecap(
                targetPageID: target.id,
                targetPageTitle: target.title,
                insight: L10n.Dashboard.insight.mock.insight,
                suggestedConnection: L10n.Dashboard.insight.mock.suggestedConnection
            )
            await saveCachedDailyRecap(recap)
            return recap
        }

        updateStatus(L10n.AI.Status.extracting)

        // 3. 挑选目标页面以供 RAG 分析
        let target = try selectTargetPage(pages: pages)
        
        let now = Date()
        let calendar = Calendar.current
        guard let recentThreshold = calendar.date(byAdding: .day, value: -3, to: now) else {
            throw AppError.insight(L10n.Insight.dateCalculationFailed, code: -2)
        }
        let recentPages = pages.filter { $0.updatedAt >= recentThreshold }
        let recentFocus = recentPages.isEmpty ? L10n.Insight.InsightSection.Daily.noUpdate : recentPages.map { $0.title }.joined(separator: " ")

        let prompt = L10n.Dashboard.insight.daily.promptRecent(recentFocus, target.title, String(target.content.prefix(500)))

        do {
            let response = try await llmService.generate(prompt: prompt, systemPrompt: L10n.Dashboard.insight.daily.systemPrompt)
            updateStatus(L10n.AI.Status.generating)

            // 4. 提取并解析 LLM 的回复
            let recap = parseDailyRecapResponse(response, target: target)
            await saveCachedDailyRecap(recap)
            return recap
        } catch {
            throw error
        }
    }

    /// 载入满足测试用例状态或数据完整度的今日见解缓存
    private func loadValidCache(pages: [KnowledgePage], forceRefresh: Bool, isTesting: Bool) async -> DailyRecap? {
        guard !forceRefresh, let cached = await loadCachedDailyRecap() else { return nil }
        if !isTesting || pages.contains(where: { $0.id == cached.targetPageID }) {
            return cached
        }
        return nil
    }

    /// 筛选当前知识页面，找到 30~90 天内最近修改的页面或冷页面作为主动召回靶标
    private func selectTargetPage(pages: [KnowledgePage]) throws -> KnowledgePage {
        let now = Date()
        let calendar = Calendar.current
        guard let longTermMin = calendar.date(byAdding: .day, value: -90, to: now),
              let longTermMax = calendar.date(byAdding: .day, value: -30, to: now) else {
            throw AppError.insight(L10n.Insight.dateCalculationFailed, code: -2)
        }

        let candidates = pages.filter { $0.updatedAt >= longTermMin && $0.updatedAt <= longTermMax }
        let fallback = pages.sorted { $0.updatedAt < $1.updatedAt }.first
        guard let target = candidates.randomElement() ?? fallback else {
            throw AppError.insight(L10n.Dashboard.insight.addPagesFirst)
        }
        return target
    }

    /// 解析大语言模型返回的召回结果 JSON
    private func parseDailyRecapResponse(_ response: String, target: KnowledgePage) -> DailyRecap {
        var jsonString: String?
        if let firstBrace = response.firstIndex(of: "{"),
           let lastBrace = response.lastIndex(of: "}") {
            jsonString = String(response[firstBrace...lastBrace])
        }

        if let jsonData = jsonString?.data(using: .utf8),
           let json = try? JSONDecoder().decode([String: String].self, from: jsonData) {
            return DailyRecap(
                targetPageID: target.id,
                targetPageTitle: target.title,
                insight: json["insight"] ?? response,
                suggestedConnection: json["suggestedConnection"] ?? ""
            )
        } else {
            return DailyRecap(
                targetPageID: target.id,
                targetPageTitle: target.title,
                insight: response,
                suggestedConnection: L10n.Dashboard.insight.recap.tip
            )
        }
    }

    private func cacheKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        let lang = Localized.currentLanguage
        return "\(AppConstants.Keys.Storage.dailyRecapPrefix)\(formatter.string(from: Date()))_\(lang)"
    }

    private func loadCachedDailyRecap() async -> DailyRecap? {
        let key = cacheKey()
        guard let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) else {
            return nil
        }
        let data = await MainActor.run { keyStore.data(forKey: key) }
        guard let data, let recap = try? JSONDecoder().decode(DailyRecap.self, from: data) else {
            return nil
        }
        return recap
    }

    private func saveCachedDailyRecap(_ recap: DailyRecap) async {
        let key = cacheKey()
        guard let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) else { return }
        if let data = try? JSONEncoder().encode(recap) {
            await MainActor.run { keyStore.set(data, forKey: key) }
        }
    }

    private func weeklyCacheKey() -> String {
        let calendar = Calendar.current
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        let year = comps.yearForWeekOfYear ?? 2026
        let week = comps.weekOfYear ?? 1
        let lang = Localized.currentLanguage
        return "weekly_insight_cache_\(year)_\(week)_\(lang)"
    }

    private func loadCachedWeeklyInsight() async -> WeeklyInsight? {
        let key = weeklyCacheKey()
        guard let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) else { return nil }
        let data = await MainActor.run { keyStore.data(forKey: key) }
        guard let data, let insight = try? JSONDecoder().decode(WeeklyInsight.self, from: data) else {
            return nil
        }
        return insight
    }

    private func saveCachedWeeklyInsight(_ insight: WeeklyInsight) async {
        let key = weeklyCacheKey()
        guard let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self) else { return }
        if let data = try? JSONEncoder().encode(insight) {
            await MainActor.run { keyStore.set(data, forKey: key) }
        }
    }

    /// 生成最近一周的知识洞察 (仅在 forceRefresh 为 true 或无本地缓存时才向 AI 请求新周报)
    func generateWeeklyInsight(pages: [KnowledgePage], llmService: any LLMServiceProtocol, forceRefresh: Bool = false) async throws -> WeeklyInsight {
        if !forceRefresh, let cached = await loadCachedWeeklyInsight() {
            return cached
        }

        updateStatus(L10n.AI.Status.synthesizing)
        let calendar = Calendar.current
        let lastWeek = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        let newPages = pages.filter { $0.createdAt >= lastWeek }
        let newTitles = newPages.map { $0.title }.joined(separator: ", ")

        let prompt = L10n.Dashboard.insight.weekly.prompt(newTitles)

        let summary = try await llmService.generate(prompt: prompt, systemPrompt: L10n.Dashboard.insight.weekly.systemPrompt)
        let allTags = newPages.flatMap { $0.tags }
        let keywords = Array(Set(allTags)).sorted().prefix(5).map { String($0) }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: Localized.currentLanguage)
        let dateRange = "\(formatter.string(from: lastWeek)) - \(formatter.string(from: Date()))"

        let insight = WeeklyInsight(
            dateRange: dateRange,
            totalNewPages: newPages.count,
            topKeywords: keywords,
            aiSummary: summary,
            growthTraction: newPages.count > 5 ? L10n.Dashboard.insight.growth.explosive : L10n.Dashboard.insight.growth.steady
        )

        await saveCachedWeeklyInsight(insight)
        return insight
    }

    private func updateStatus(_ text: String) {
        Task { @MainActor in
            TaskCenter.shared.updateLatestStatus(text)
        }
    }
}
