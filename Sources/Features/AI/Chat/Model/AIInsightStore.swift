//
//  AIInsightStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：AI 对话功能：多轮对话、流式响应、聊天历史管理。
//
import Foundation
import UFPCore
import Observation
import Combine
import Dependencies

/// AI 洞察存储，管理全库级别的统计与分析结论。
@MainActor
@Observable
public final class AIInsightStore {
    
    public struct InsightMetric: Identifiable, Sendable {
        public let id = UUID()
        public let label: String
        public let value: String
        public let icon: String
        public let trend: Double?
        
        public init(label: String, value: String, icon: String, trend: Double? = nil) {
            self.label = label
            self.value = value
            self.icon = icon
            self.trend = trend
        }
    }

    // ── 洞察与报告 ──
    var weeklyInsight: KnowledgeInsightService.WeeklyInsight?
    var dailyRecap: KnowledgeInsightService.DailyRecap?
    var isGeneratingDailyRecap = false

    // ── 统计指标 (从 AppStore 下沉) ──
    public var brokenLinkCount: Int = 0
    public var orphanPageCount: Int = 0
    public var totalConnectionCount: Int = 0
    public var sourceCount: Int = 0
    public var entityCount: Int = 0
    public var conceptCount: Int = 0
    public var growthSeries: [AppStore.KnowledgeGrowthPoint] = []

    @ObservationIgnored @Dependency(\.knowledgeInsightService) private var insightService: KnowledgeInsightService
    @ObservationIgnored @Dependency(\.llmService) private var llmService: any LLMServiceProtocol
    @ObservationIgnored @Dependency(\.pageStoreCapabilities) private var pageStore: any AnyPageStoreCapabilities
    @ObservationIgnored @Dependency(\.logger) private var logger: any LoggerProtocol

    public init() {}

    /// 更新全局统计指标
    public func updateStatistics() async {
        let pages = await pageStore.pages
        
        self.sourceCount = pages.filter { $0.pageType == .source }.count
        self.entityCount = pages.filter { $0.pageType == .entity }.count
        self.conceptCount = pages.filter { $0.pageType == .concept }.count
        self.totalConnectionCount = pages.reduce(0) { $0 + $1.outgoingLinks.count }
        
        // 模拟增长曲线 (基于创建时间)
        calculateGrowthSeries(pages: pages)
    }

    private func calculateGrowthSeries(pages: [KnowledgePage]) {
        let calendar = Calendar.current
        let now = Date()
        var dailyCounts: [Date: Int] = [:]
        
        for page in pages {
            let day = calendar.startOfDay(for: page.createdAt)
            dailyCounts[day, default: 0] += 1
        }
        
        // 转换为连续的增长点 (最近 7 天)
        var series: [AppStore.KnowledgeGrowthPoint] = []
        var runningTotal = 0
        
        // 先按日期排序
        let sortedDays = dailyCounts.keys.sorted()
        for day in sortedDays {
            runningTotal += dailyCounts[day] ?? 0
            guard let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) else { continue }
            if day > weekAgo {
                series.append(AppStore.KnowledgeGrowthPoint(date: day, count: runningTotal))
            }
        }
        
        self.growthSeries = series
    }

    // MARK: - 周报业务

    /// 生成WeeklyInsight
    /// - Parameter forceRefresh: force刷新
    func generateWeeklyInsight(forceRefresh: Bool = false) async {
        let pages = await pageStore.pages
        do {
            let insight = try await insightService.generateWeeklyInsight(pages: pages, llmService: llmService, forceRefresh: forceRefresh)
            self.weeklyInsight = insight
        } catch {
            logger.addLog(action: .aiscanFailed, target: FeatureConstants.LogTarget.weeklyInsight, details: error.localizedDescription)
        }
    }

    /// 生成DailyRecap
    /// - Parameter forceRefresh: force刷新
    func generateDailyRecap(forceRefresh: Bool = false) async {
        isGeneratingDailyRecap = true
        defer { isGeneratingDailyRecap = false }
        
        let pages = await pageStore.pages
        do {
            let recap = try await insightService.generateDailyRecap(pages: pages, llmService: llmService, forceRefresh: forceRefresh)
            self.dailyRecap = recap
        } catch {
            logger.addLog(action: .aiscanFailed, target: FeatureConstants.LogTarget.dailyRecap, details: error.localizedDescription)
        }
    }
}

// MARK: - DependencyKey

@MainActor
public enum AIInsightStoreKey: DependencyKey {
    @MainActor
    public static var liveValue: AIInsightStore { ServiceContainer.shared.resolve(AIInsightStore.self) }

    @MainActor
    public static var testValue: AIInsightStore {
        ServiceContainer.shared.resolveOptional(AIInsightStore.self) ?? AIInsightStore()
    }
}

extension DependencyValues {
    @MainActor
    public var aiInsightStore: AIInsightStore {
        get { self[AIInsightStoreKey.self] }
        set { self[AIInsightStoreKey.self] = newValue }
    }
}
