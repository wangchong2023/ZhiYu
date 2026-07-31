//
//  L10n+Dashboard.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Dashboard 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public struct Dashboard: L10nTableEntry {
        public static let tableName = "Insight"
        public static var t: String { tableName }
        /// 本地化翻译
        /// - Parameter key: key
        /// - Returns: 返回值
        /// 本地化格式化翻译
        /// - Parameter key: key
        /// - Parameter args: args
        /// - Returns: 返回值
        public static func trf(_ key: String, _ args: CVarArg...) -> String {
            let localized = Localized.trf(key, table: t, arguments: args)
            if localized == key {
                return Localized.trf(key, table: t, arguments: args)
            }
            return localized
        }

        public static var pageListPages: String { Localized.tr("dashboard.pageList.pages", table: t) }
        public static var pageListLinks: String { Localized.tr("dashboard.pageList.links", table: t) }
        public static var density: String { Localized.tr("dashboard.density", table: t) }
        public static var dailyInsights: String { Localized.tr("dashboard.dailyInsights", table: t) }
        public static var hotTopics: String { Localized.tr("dashboard.hotTopics", table: t) }

        public static var insightsLoading: String { Localized.tr("dashboard.insights.loading", table: t) }
        public static var insightsPageDeleted: String { Localized.tr("insights.pageDeleted", table: t) }
        public static var insightsEmpty: String { Localized.tr("dashboard.insights.empty", table: t) }
        public static var graphShortcut: String { Localized.tr("graphShortcut", table: t) }

        // swiftlint:disable:next type_name
        public struct insight {
            public static var weeklyTitle: String { L10n.Common.tr("sidebar.weeklyInsight") }
            public static var generateReport: String { Localized.tr("dashboard.insight.generateReport", table: t) }
            public static var addPagesFirst: String { Localized.tr("dashboard.insight.addPagesFirst", table: t) }

            // swiftlint:disable:next type_name
            public struct daily {
                public static var systemPrompt: String { Localized.tr("dashboard.insight.daily.systemPrompt", table: t) }

                /// 获取每日洞察针对最近内容的 Prompt
                /// - Parameters:
                ///   - focus: 关注点/热点话题
                ///   - title: 页面标题
                ///   - snippet: 页面片段
                /// - Returns: 本地化 Prompt
                public static func promptRecent(_ focus: String, _ title: String, _ snippet: String) -> String { Dashboard.trf("insight.daily.prompt.recent", focus, title, snippet) }
            }

            // swiftlint:disable:next type_name
            public struct mock {
                public static var insight: String { Localized.tr("dashboard.insight.mock.insight", table: t) }
                public static var suggestedConnection: String { Localized.tr("dashboard.insight.mock.suggestedConnection", table: t) }
            }

            // swiftlint:disable:next type_name
            public struct recap {
                public static var tip: String { Localized.tr("dashboard.insight.recap.tip", table: t) }
            }

            // swiftlint:disable:next type_name
            public struct weekly {
                public static var systemPrompt: String { Localized.tr("dashboard.insight.weekly.systemPrompt", table: t) }

                /// 获取每周洞察针对精选页面的 Prompt
                /// - Parameter titles: 精选条目标题连接串
                /// - Returns: 本地化 Prompt
                public static func prompt(_ titles: String) -> String { Dashboard.trf("insight.weekly.prompt", titles) }
            }

            // swiftlint:disable:next type_name
            public struct growth {
                public static var explosive: String { Localized.tr("dashboard.insight.growth.explosive", table: t) }
                public static var steady: String { Localized.tr("dashboard.insight.growth.steady", table: t) }
            }

            // swiftlint:disable:next type_name
            public struct tips {
                public static var title: String { tr("title") }
                public static var content: String { Localized.tr("dashboard.insight.tips.content", table: t) }
            }
        }

        // swiftlint:disable:next type_name
        public struct pageList {
            public static var tags: String { Localized.tr("dashboard.pageList.tags", table: t) }
            public static var sources: String { L10n.Common.Tab.ingest }
            public static var overview: String { Localized.tr("dashboard.stats.overview", table: t) }
            public static var concepts: String { Localized.tr("dashboard.pageList.concepts", table: t) }
            public static var entities: String { Localized.tr("dashboard.pageList.entities", table: t) }
            public static var wordCount: String { Localized.tr("dashboard.pageList.wordCount", table: t) }
            public static var entityCount: String { Localized.tr("dashboard.pageList.entityCount", table: t) }
            public static var conceptCount: String { Localized.tr("dashboard.pageList.conceptCount", table: t) }
            public static var sourceCount: String { Localized.tr("dashboard.pageList.sourceCount", table: t) }
            public static var comparisonCount: String { Localized.tr("dashboard.pageList.comparisonCount", table: t) }
            public static var rawCount: String { Localized.tr("dashboard.pageList.rawCount", table: t) }

            /// 获取格式化字数文案
            /// - Parameter count: 字数
            /// - Returns: 本地化格式化文案
            public static func wordCount(_ count: Int) -> String { Localized.trf("dashboard.pageList.wordCount", table: t, count) }

            /// 获取格式化实体个数文案
            /// - Parameter count: 实体个数
            /// - Returns: 本地化格式化文案
            public static func entityCount(_ count: Int) -> String { Localized.trf("dashboard.pageList.entityCount", table: t, count) }

            /// 获取格式化概念个数文案
            /// - Parameter count: 概念个数
            /// - Returns: 本地化格式化文案
            public static func conceptCount(_ count: Int) -> String { Localized.trf("dashboard.pageList.conceptCount", table: t, count) }

            /// 获取格式化信源个数文案
            /// - Parameter count: 信源个数
            /// - Returns: 本地化格式化文案
            public static func sourceCount(_ count: Int) -> String { Localized.trf("dashboard.pageList.sourceCount", table: t, count) }

            /// 获取格式化对比个数文案
            /// - Parameter count: 对比个数
            /// - Returns: 本地化格式化文案
            public static func comparisonCount(_ count: Int) -> String { Localized.trf("dashboard.pageList.comparisonCount", table: t, count) }

            /// 获取格式化原始个数文案
            /// - Parameter count: 原始个数
            /// - Returns: 本地化格式化文案
            public static func rawCount(_ count: Int) -> String { Localized.trf("dashboard.pageList.rawCount", table: t, count) }
        }

        public static var title: String { L10n.Common.Sidebar.tags }
        public static var unitMs: String { Localized.tr("dashboard.stats.unitMs", table: t) }
        public static var densityDesc: String { Localized.tr("dashboard.density.desc", table: t) }
        public static var densityDetails: String { Localized.tr("dashboard.density.details", table: t) }
        public static var densityOutbound: String { Localized.tr("dashboard.density.outbound", table: t) }
        public static var densityInbound: String { Localized.tr("dashboard.density.inbound", table: t) }
        public static var axisPages: String { Localized.tr("dashboard.axis.pages", table: t) }
        public static var axisRelations: String { Localized.tr("dashboard.axis.relations", table: t) }
        public static var benchmarkDescription: String { Localized.tr("dashboard.stats.benchmark.description", table: t) }
        public static var cleanupAction: String { Dashboard.tr("cleanupAction") }
        public static var updateSuccess: String { Localized.tr("dashboard.updateSuccess", table: t) }
        public static var totalPages: String { Dashboard.tr("totalPages") }
        public static var totalLinks: String { Dashboard.tr("totalLinks") }
        public static var apiRequests: String { Dashboard.tr("apiRequests") }
        public static var totalStorage: String { Dashboard.tr("totalStorage") }
        public static var tokens: String { Dashboard.tr("tokens") }
        public static var chartDate: String { Localized.tr("dashboard.stats.chartDate", table: t) }
        public static var chartSelected: String { Localized.tr("dashboard.stats.chartSelected", table: t) }
        public static var chartValue: String { Localized.tr("dashboard.stats.chartValue", table: t) }
        /// 数据维护与清理段标题
        public static var maintenance: String { Localized.tr("dashboard.stats.maintenance", table: t) }
        /// 已清理条数的前缀文案
        public static var cleanedPrefix: String { Localized.tr("dashboard.stats.cleanedPrefix", table: t) }
        /// 已清理条数的后缀文案
        public static var cleanedSuffix: String { Localized.tr("dashboard.stats.cleanedSuffix", table: t) }

        // swiftlint:disable:next type_name
        public struct stats {
            public static var title: String { Localized.tr("dashboard.stats.title", table: t) }
            public static var audioFormat: String { Localized.tr("dashboard.stats.audioFormat", table: t) }
            public static var imageFormat: String { Localized.tr("dashboard.stats.imageFormat", table: t) }
            public static var documentFormat: String { Localized.tr("dashboard.stats.documentFormat", table: t) }
            public static func itemsCount(_ count: Int) -> String { Localized.trf("dashboard.stats.itemsCount", table: t, count) }

            public static var faithfulness: String { Dashboard.tr("stats.faithfulness") }
            public static var relevance: String { Dashboard.tr("stats.relevance") }
            public static var precision: String { Dashboard.tr("stats.precision") }
            public static var hallucinationRate: String { Localized.tr("dashboard.stats.hallucinationRate", table: t) }
            public static var citationAccuracy: String { Localized.tr("dashboard.stats.citationAccuracy", table: t) }
            public static var generationQuality: String { Localized.tr("dashboard.stats.generationQuality", table: t) }
            public static var retrievalFidelity: String { Localized.tr("dashboard.stats.retrievalFidelity", table: t) }
            public static var retrievalQuality: String { Localized.tr("dashboard.stats.retrievalQuality", table: t) }
            public static var rankingQuality: String { Localized.tr("dashboard.stats.ndcgDesc", table: t) }
            public static var coverage: String { Localized.tr("dashboard.stats.coverage", table: t) }
            public static var contextFidelity: String { Localized.tr("dashboard.stats.contextFidelity", table: t) }
            public static var responseLatency: String { Localized.tr("dashboard.stats.responseLatency", table: t) }
            public static var hitRateDesc: String { Localized.tr("dashboard.stats.hitRateDesc", table: t) }
            public static var mrrTitle: String { Localized.tr("dashboard.stats.mrrTitle", table: t) }
            public static var mrrDesc: String { Localized.tr("dashboard.stats.mrrDesc", table: t) }
            public static var ndcgTitle: String { Localized.tr("dashboard.stats.ndcgTitle", table: t) }
            public static var ndcgDesc: String { Localized.tr("dashboard.stats.ndcgDesc", table: t) }
            public static var hitRateTitle: String { Localized.tr("dashboard.stats.hitRateTitle", table: t) }
            public static var recallAtK: String { Localized.tr("dashboard.stats.recallAtK", table: t) }
            public static var recallDesc: String { Localized.tr("dashboard.stats.recallDesc", table: t) }
            public static var f1AtK: String { Localized.tr("dashboard.stats.f1AtK", table: t) }
            public static var f1Desc: String { Localized.tr("dashboard.stats.f1Desc", table: t) }
            public static var mapTitle: String { Localized.tr("dashboard.stats.mapTitle", table: t) }
            public static var mapDesc: String { Localized.tr("dashboard.stats.mapDesc", table: t) }
            public static var answerCorrectness: String { Localized.tr("dashboard.stats.answerCorrectness", table: t) }
            public static var answerCorrectnessDesc: String { Localized.tr("dashboard.stats.answerCorrectnessDesc", table: t) }
            public static var retrievalLatency: String { Localized.tr("dashboard.stats.retrievalLatency", table: t) }
            public static var latencyP50: String { Localized.tr("dashboard.stats.latencyP50", table: t) }
            public static var latencyP95: String { Localized.tr("dashboard.stats.latencyP95", table: t) }
            public static var latencyP99: String { Localized.tr("dashboard.stats.latencyP99", table: t) }
            public static var latencyUnitMS: String { Localized.tr("dashboard.stats.latencyUnitMS", table: t) }
            public static var latencySampleCount: String { Localized.tr("dashboard.stats.latencySampleCount", table: t) }
            public static var tokenEfficiency: String { Localized.tr("dashboard.stats.tokenEfficiency", table: t) }
            public static var totalTokens: String { Localized.tr("dashboard.stats.totalTokens", table: t) }
            public static var avgTokensPerQuery: String { Localized.tr("dashboard.stats.avgTokensPerQuery", table: t) }
            public static var estimatedCost: String { Localized.tr("dashboard.stats.estimatedCost", table: t) }
            public static var queryCount: String { Localized.tr("dashboard.stats.queryCount", table: t) }
            public static var tabRetrieval: String { Localized.tr("dashboard.stats.tab.retrieval", table: t) }
            public static var tabGeneration: String { Localized.tr("dashboard.stats.tab.generation", table: t) }
            public static var tabSatisfaction: String { Localized.tr("dashboard.stats.tab.satisfaction", table: t) }
            public static var tabHistory: String { Localized.tr("dashboard.stats.tab.history", table: t) }
            public static var tabSatisfactionAndEval: String { Localized.tr("dashboard.stats.tab.satisfactionAndEval", table: t) }
            public static var tabPlugins: String { Localized.tr("dashboard.stats.tab.plugins", table: t) }

            // MARK: - Tooltip 说明文案

            /// 检索阶段说明
            public static var tipRetrievalPhase: String { Localized.tr("dashboard.stats.tipRetrievalPhase", table: t) }
            /// 生成阶段说明
            public static var tipGenerationPhase: String { Localized.tr("dashboard.stats.tipGenerationPhase", table: t) }
            /// 资源消耗说明
            public static var tipCostPhase: String { Localized.tr("dashboard.stats.tipCostPhase", table: t) }
            /// Hit@5 说明
            public static var tipHitRate: String { Localized.tr("dashboard.stats.tipHitRate", table: t) }
            /// MRR 说明
            public static var tipMRR: String { Localized.tr("dashboard.stats.tipMRR", table: t) }
            /// NDCG 说明
            public static var tipNDCG: String { Localized.tr("dashboard.stats.tipNDCG", table: t) }
            /// Recall 说明
            public static var tipRecall: String { Localized.tr("dashboard.stats.tipRecall", table: t) }
            /// F1 说明
            public static var tipF1: String { Localized.tr("dashboard.stats.tipF1", table: t) }
            /// MAP 说明
            public static var tipMAP: String { Localized.tr("dashboard.stats.tipMAP", table: t) }
            /// Faithfulness 说明
            public static var tipFaithfulness: String { Localized.tr("dashboard.stats.tipFaithfulness", table: t) }
            /// Relevance 说明
            public static var tipRelevance: String { Localized.tr("dashboard.stats.tipRelevance", table: t) }
            /// Hallucination 说明
            public static var tipHallucination: String { Localized.tr("dashboard.stats.tipHallucination", table: t) }
            /// Precision 说明
            public static var tipPrecision: String { Localized.tr("dashboard.stats.tipPrecision", table: t) }
            /// Citation Accuracy 说明
            public static var tipCitation: String { Localized.tr("dashboard.stats.tipCitation", table: t) }
            /// Correctness 说明
            public static var tipCorrectness: String { Localized.tr("dashboard.stats.tipCorrectness", table: t) }
            /// 检索延迟说明
            public static var tipLatency: String { Localized.tr("dashboard.stats.tipLatency", table: t) }
            /// Token 效率说明
            public static var tipTokenEfficiency: String { Localized.tr("dashboard.stats.tipTokenEfficiency", table: t) }
            public static var tipContextSufficiency: String { Localized.tr("dashboard.stats.tipContextSufficiency", table: t) }
            public static var tipUserSatisfaction: String { Localized.tr("dashboard.stats.tipUserSatisfaction", table: t) }

            public static var contextSufficiency: String { Localized.tr("dashboard.stats.contextSufficiency", table: t) }
            public static var contextSufficiencyDesc: String { Localized.tr("dashboard.stats.contextSufficiencyDesc", table: t) }
            public static var userSatisfaction: String { Localized.tr("dashboard.stats.userSatisfaction", table: t) }
            public static var noRatings: String { Localized.tr("dashboard.stats.noRatings", table: t) }
            public static var ratingTotal: String { Localized.tr("dashboard.stats.ratingTotal", table: t) }

            public static var evaluation: String { Localized.tr("dashboard.stats.evaluation", table: t) }
            public static var overview: String { Localized.tr("dashboard.index.overview", table: t) }
            public static var recentEvaluations: String { Localized.tr("dashboard.stats.recentEvaluations", table: t) }
            public static var noEvaluations: String { Localized.tr("dashboard.stats.noEvaluations", table: t) }
            public static var unitDays: String { Localized.tr("dashboard.stats.unitDays", table: t) }
            public static var benchmark: String { Localized.tr("dashboard.stats.benchmark", table: t) }
            public static var categoryDistribution: String { Localized.tr("dashboard.stats.categoryDistribution", table: t) }
            public static var knowledgeGrowth: String { Localized.tr("dashboard.stats.knowledgeGrowth", table: t) }
            public static var navigationTitleMonitor: String { Localized.tr("dashboard.stats.navigationTitleMonitor", table: t) }
            public static var storageImport: String { Localized.tr("dashboard.stats.storageImport", table: t) }
            public static var storageExport: String { Localized.tr("dashboard.stats.storageExport", table: t) }
            public static var tabPerf: String { Localized.tr("dashboard.stats.tabPerf", table: t) }
            public static var tabStorage: String { Localized.tr("dashboard.stats.tabStorage", table: t) }
            public static var rangeThirtyDays: String { Localized.tr("dashboard.stats.rangeThirtyDays", table: t) }
            public static var requestsUsage: String { Localized.tr("dashboard.stats.requestsUsage", table: t) }
            public static var tokenUsage: String { Localized.tr("common.tokenUsage", table: t) }
            public static var requestCount: String { Localized.tr("common.requests", table: t) }
            public static var storageDistribution: String { Localized.tr("dashboard.stats.storageDistribution", table: t) }
            public static var chartDate: String { Localized.tr("dashboard.stats.chartDate", table: t) }
            public static var chartSelected: String { Localized.tr("dashboard.stats.chartSelected", table: t) }
            /// Token 使用消耗量卡片标题
            public static var tokensUsage: String { Localized.tr("dashboard.stats.tokensUsage", table: t) }
            /// 响应时延统计卡片标题
            public static var latencyTitle: String { Localized.tr("dashboard.stats.latencyTitle", table: t) }
            /// 平均响应时延简写标签
            public static var avgLatencyShort: String { Localized.tr("dashboard.stats.avgLatencyShort", table: t) }
            /// 最大时延标签
            public static var maxLatency: String { Localized.tr("dashboard.stats.maxLatency", table: t) }
            /// 最小时延标签
            public static var minLatency: String { Localized.tr("dashboard.stats.minLatency", table: t) }
            /// 时延测量次数/样本数标签
            public static var measureCount: String { Localized.tr("dashboard.stats.measureCount", table: t) }
            /// 存储空间分布详情卡片标题
            public static var storageDetails: String { Localized.tr("dashboard.stats.storageDetails", table: t) }
            public static var chartValue: String { Localized.tr("dashboard.stats.chartValue", table: t) }
            /// 存储空间多分库笔记本的详情描述
            public static func multiVaultDesc(_ count: Int) -> String { Localized.trf("dashboard.stats.multiVaultDesc", table: t, count) }
            
            /// 各笔记本占用标题
            public static var vaultStorageTitle: String { Localized.tr("dashboard.stats.vaultStorageTitle", table: t) }
            /// 当前激活笔记本的状态文本
            public static var activeVaultStatus: String { Localized.tr("dashboard.stats.activeVaultStatus", table: t) }
            /// 未激活笔记本的状态文本
            public static var inactiveVaultStatus: String { Localized.tr("dashboard.stats.inactiveVaultStatus", table: t) }
            
            /// 原始数据存储监控标题
            public static var rawStorageTitle: String { Localized.tr("dashboard.stats.rawStorageTitle", table: t) }
            
            /// 原始来源文件总数标签
            public static var rawTotalPages: String { Localized.tr("dashboard.stats.rawTotalPages", table: t) }
            
            /// 原始文件存储大小标签
            public static var rawTotalSize: String { Localized.tr("dashboard.stats.rawTotalSize", table: t) }
            
            /// 原始文件列表查看入口标签
            public static var viewRawPages: String { Localized.tr("dashboard.stats.viewRawPages", table: t) }
            
            /// 原始页面详情标题
            public static var rawPageDetailTitle: String { Localized.tr("dashboard.stats.rawPageDetailTitle", table: t) }
            
            /// 原始页面元数据大小和字数的格式化文案
            /// - Parameters:
            ///   - count: 字符字数
            ///   - size: 友好格式化的文件大小
            /// - Returns: 格式化后的本地化文案
            public static func rawPageCountFormat(_ count: Int, _ size: String) -> String { Dashboard.trf("dashboard.stats.rawPageCountFormat", count, size) }

            // swiftlint:disable:next type_name
            public struct short {
                public static var entity: String { Dashboard.tr("stats.short.entity") }
                public static var concept: String { Dashboard.tr("stats.short.concept") }
                public static var source: String { Dashboard.tr("stats.short.source") }
                public static var comparison: String { Dashboard.tr("stats.short.comparison") }
                public static var raw: String { Dashboard.tr("stats.short.raw") }
                public static var pages: String { Dashboard.tr("stats.short.pages") }
                public static var new: String { Dashboard.tr("stats.short.new") }
                public static var ref: String { Dashboard.tr("stats.short.ref") }
            }
        }

        // swiftlint:disable:next type_name
        public struct index {
            public static var title: String { Localized.tr("dashboard.index.title", table: t) }
            public static var overview: String { Localized.tr("dashboard.index.overview", table: t) }
        }

        public struct System {
            public static var status: String { Localized.tr("dashboard.system.status", table: t) }
            public static var database: String { Dashboard.tr("stats.database") }
            public static var logs: String { Dashboard.tr("stats.logs") }
            public static var models: String { Dashboard.tr("stats.models") }
            public static var plugins: String { Dashboard.tr("stats.plugins") }
            public static var caches: String { Dashboard.tr("stats.caches") }
        }
    }
}
