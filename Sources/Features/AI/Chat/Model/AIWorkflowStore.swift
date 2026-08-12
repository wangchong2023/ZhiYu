//
//  AIWorkflowStore.swift
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

/// AI 工作流存储，管理 AI 扫描状态、洞察及建议。
@MainActor
@Observable
public final class AIWorkflowStore: AIWorkflowCapabilities {
    @ObservationIgnored @Dependency(\.taskCenter) private var taskCenter

    // ── 子 Store 聚合 ──
    public var insightStore: AIInsightStore = AIInsightStore()

    // ── 扫描与分析状态 ──
    public var isScanningAI = false
    public var refactorSuggestions: [RefactorSuggestionDTO] = []
    public var potentialLinks: [PotentialLinkSuggestion] = []

    // ── 页面级 AI 状态 ──
    public var activePageAIResult: String?
    public var isProcessingPageAI = false
    public var activeQuiz: QuizModel?

    // ── 健康度状态 ──
    public var lastLintScore: Int = 0
    public var lastLintDate: Date?

    // ── 健康度代理 (由 LintService 实时计算) ──
    public var healthMetrics: (score: Int, level: LintService.HealthLevel) {
        lintService.calculateHealthMetrics(issues: lintIssues)
    }
    public var lintScore: Int { healthMetrics.score }
    public var healthLevel: LintService.HealthLevel { healthMetrics.level }
    
    /// LLM 服务是否已启用
    public var isLLMEnabled: Bool { llmService.isEnabled }

    // ── 健康度问题存储 (Lint Issues) ──
    @ObservationIgnored private var _lintIssues: [LintIssue] = {
        if let keyStore = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self),
           let data = keyStore.data(forKey: AppConstants.Keys.Storage.lastLintIssues),
           let decoded = try? JSONDecoder().decode([LintIssue].self, from: data) {
            return decoded
        }
        return []
    }()

    public var lintIssues: [LintIssue] {
        get { access(keyPath: \.lintIssues); return _lintIssues }
        set {
            withMutation(keyPath: \.lintIssues) {
                _lintIssues = newValue
                if let data = try? JSONEncoder().encode(newValue) {
                    keyStore?.set(data, forKey: AppConstants.Keys.Storage.lastLintIssues)
                }
            }
        }
    }

    @ObservationIgnored @Inject private var llmService: any LLMServiceProtocol  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    /// [L1.5] 知识库领域仓储 — 遵循 DIP，L2 不再直接依赖 L1 SQLiteStore
    @ObservationIgnored @Inject private var knowledgeRepository: any KnowledgeRepository  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    /// [L0] 向量检索能力 — 通过 L0 协议注入，避免直接耦合 L1 EmbeddingManager
    @ObservationIgnored @Inject private var vectorStore: any VectorIndexableStore  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    @ObservationIgnored @Inject private var lintService: LintService  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    @ObservationIgnored @Inject private var logger: any LoggerProtocol  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    @ObservationIgnored @Inject private var linkService: LinkService  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    /// Factory 风格：属性类型标注为可选（T?）， 自动使用 resolveOptional
    @ObservationIgnored @Inject private var keyStore: (any KeyStoreProtocol)?

    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    /// AI 扫描配置常量
    private enum AIScanConfig {
        /// 单页扫描时最近更新页面前缀数量
        static let recentScanPrefix: Int = 5
        /// 全局扫描时采样页面前缀数量
        static let globalScanPrefix: Int = 10
        /// 扫描任务名称
        static let scanTaskName: String = "Scan_Task"
        /// 系统级目标标识
        static let systemTarget: String = "System"
    }

    public init() {
        AppEventBus.shared.subscribe()
            .sink { [weak self] in if case .clearAllDataRequested = $0 { self?.clearAll() } }
            .store(in: &cancellables)
    }

    // ── 扫描与健康检查逻辑 ──

    /// 运行Lint
    public func runLint() async {
        let taskID = taskCenter.addTask(type: .healthCheck, name: L10n.Common.Sidebar.healthCheck, target: AIScanConfig.systemTarget)
        let pages = (try? await knowledgeRepository.fetchAll()) ?? []
        let issues = await lintService.runLint(pages: pages, linkService: linkService)
        lintIssues = issues
        lastLintDate = Date()
        taskCenter.updateTask(taskID, status: .completed)
    }

    /// 运行AI扫描
    public func runAIScan(forPage specificPage: KnowledgePage? = nil) async {
        guard llmService.isEnabled else {
            logger.addLog(action: .aiscanSkipped, target: specificPage?.title ?? AIScanConfig.systemTarget, details: "LLM service disabled")
            return
        }

        isScanningAI = true
        let taskTarget = specificPage?.title ?? AIScanConfig.systemTarget
        let taskID = taskCenter.addTask(type: .ai, name: AIScanConfig.scanTaskName, target: taskTarget)

        do {
            let allPages = (try? await knowledgeRepository.fetchAll()) ?? []
            let existingTitles = allPages.map { $0.title }

            let pagesToScan: [KnowledgePage]
            if let spec = specificPage {
                pagesToScan = [spec]
            } else {
                pagesToScan = Array(allPages.sorted(by: { $0.updatedAt > $1.updatedAt }).prefix(AIScanConfig.recentScanPrefix))
            }

            var tempLinks: [PotentialLinkSuggestion] = []
            var seenLinks = Set<String>()
            for page in pagesToScan {
                let found = try await llmService.discoverPotentialLinks(content: page.content, existingTitles: existingTitles)
                for title in Set(found) {
                    // 用 null 字符作分隔符避免 title 含 "-" 时碰撞
                    let linkKey = "\(page.id.uuidString)\u{0}\(title)"
                    if !seenLinks.contains(linkKey) && !page.content.contains("[[\(title)]]") {
                        seenLinks.insert(linkKey)
                        tempLinks.append(PotentialLinkSuggestion(sourcePageID: page.id, sourceTitle: page.title, targetTitle: title))
                    }
                }
            }

            if let spec = specificPage {
                // 如果是针对特定单页的扫描，只增量合并
                var currentLinks = potentialLinks
                currentLinks.removeAll { $0.sourcePageID == spec.id }
                potentialLinks = currentLinks + tempLinks
            } else {
                // 全局扫描
                let samplePages = Array(allPages.prefix(AIScanConfig.globalScanPrefix))
                let suggestions = try await llmService.analyzeForRefactoring(pages: samplePages)
                refactorSuggestions = suggestions
                potentialLinks = tempLinks
            }

            isScanningAI = false
            taskCenter.updateTask(taskID, status: .completed)
        } catch {
            logger.addLog(action: .aiscanFailed, target: taskTarget, details: error.localizedDescription)
            isScanningAI = false
            taskCenter.updateTask(taskID, status: .failed(error: error.localizedDescription))
        }
    }

    /// 拉取FixSuggestion
    /// - Returns: 字符串
    public func fetchFixSuggestion(for issue: LintIssue) async throws -> String {
        HapticFeedback.shared.trigger(.selection)
        let pages = (try? await knowledgeRepository.fetchAll()) ?? []
        return try await AISynthesisService.shared.suggestFix(issue: issue, pages: pages)
    }

    /// 查找与当前页面语义相似的页面（基于向量嵌入）
    public func findSimilarPages(for page: KnowledgePage, limit: Int = 3) async -> [KnowledgePage] {
        let results = await vectorStore.embeddingProvider.search(query: page.title, topK: limit + 1)
        
        var similarPages: [KnowledgePage] = []
        let allPages = (try? await knowledgeRepository.fetchAll()) ?? []
        for res in results {
            if res.id == page.id { continue }
            if let p = allPages.first(where: { $0.id == res.id }) {
                similarPages.append(p)
            }
            if similarPages.count >= limit { break }
        }
        return similarPages
    }

    // ── 页面级 AI 行为 (Async 接口版) ──

    /// 生成页面 AI 摘要
    public func runPageAISummary(content: String) async throws -> String {
        isProcessingPageAI = true
        defer { isProcessingPageAI = false }
        
        let summary = try await AISynthesisService.shared.summarize(content: content)
        activePageAIResult = summary
        return summary
    }

    /// 提取页面行动项
    public func runPageAIExtractActions(content: String) async throws -> String {
        isProcessingPageAI = true
        defer { isProcessingPageAI = false }
        
        let actions = try await AISynthesisService.shared.extractActions(content: content)
        activePageAIResult = actions
        return actions
    }

    /// 扩展页面存根内容
    public func runPageAIExpansion(content: String) async throws -> String {
        isProcessingPageAI = true
        defer { isProcessingPageAI = false }
        
        let expanded = try await AISynthesisService.shared.expandKnowledge(content: content)
        activePageAIResult = expanded
        return expanded
    }

    @ObservationIgnored @Inject private var synthesisStore: SynthesisStore  // inject_exempt: DI 就绪后由 AppEnvironment 实例化

    /// 执行通用页面综合任务（MindMap, Quiz, etc.）
    public func performPageSynthesis(type: SynthesisStore.SynthesisType, title: String, content: String) async throws -> String {
        isProcessingPageAI = true
        defer { isProcessingPageAI = false }
        
        let taskID = taskCenter.addTask(type: .ai, name: type.title, target: title)
        do {
            let result = try await AISynthesisService.shared.synthesize(type: type, content: content)
            taskCenter.completeTask(id: taskID)
            
            // 🛡️ 持久化落盘存入 SynthesisDocument 数组，确保在合成列表中可查
            synthesisStore.saveSynthesisResult(type: type, content: result)

            // 针对不同类型处理结果
            if type == .quiz {
                if let quiz = QuizProcessor.parseToQuizModel(result) {
                    activeQuiz = quiz
                } else {
                    activePageAIResult = result
                }
            } else {
                activePageAIResult = result
            }
            return result
        } catch {
            taskCenter.failTask(id: taskID, error: error.localizedDescription)
            throw error
        }
    }

    /// 清除All
    public func clearAll() {
        refactorSuggestions = []
        potentialLinks = []
        activePageAIResult = nil
        activeQuiz = nil
        lintIssues = []
        lastLintScore = 0
        lastLintDate = nil

        keyStore?.removeObject(forKey: AppConstants.Keys.Storage.lastLintIssues)

        logger.addLog(action: .systemInit, target: "AIWorkflowStore", details: "AI Workflow data cleared.", module: "AIWorkflowStore")
    }

    // ── 建议清理方法 ──
    /// 移除Potential链接
    /// - Parameter id: id
    public func removePotentialLink(id: UUID) {
        potentialLinks.removeAll { $0.id == id }
    }

    /// 移除重构Suggestion
    /// - Parameter id: id
    public func removeRefactorSuggestion(id: String) {
        refactorSuggestions.removeAll { $0.id == id }
    }
}
