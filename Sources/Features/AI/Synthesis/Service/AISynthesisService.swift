//
//  AISynthesisService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：实现 AISynthesis 模块的核心业务逻辑服务。
//
import Foundation
import UFPCore
import Dependencies

/// AI 知识综合服务 (L1 领域层)
/// 负责具体的业务 Prompt 编排与结果解析，解耦 LLMService。
actor AISynthesisService: AISynthesisServiceProtocol {
    nonisolated static let shared = AISynthesisService()

    @Inject private var logger: any LoggerProtocol
    private var llm: any LLMServiceProtocol
    @ObservationIgnored private let promptService: PromptService

    /// 动态解析最新的 LLMService 实例，防止持有失效句柄
    private var currentLLM: any LLMServiceProtocol {
        if let liveLLM = ServiceContainer.shared.resolveOptional((any LLMServiceProtocol).self) {
            return liveLLM
        }
        return llm
    }

    private init() {
        // 使用 resolveOptional 防护 DI 未就绪阶段，降级至 LLMService.shared 避免单例初始化崩溃
        if let resolved = ServiceContainer.shared.resolveOptional((any LLMServiceProtocol).self) {
            self.llm = resolved
        } else {
            // LLMService.shared 是 @MainActor 隔离，actor init 可能从后台线程调用，
            // 使用 runOnMainSync 安全桥接至主线程，避免 MainActor.assumeIsolated 在非主线程崩溃
            self.llm = runOnMainSync { LLMService.shared }
        }
        self.promptService = PromptService(defaults: .standard)
    }

    #if DEBUG
    /// [仅测试] 替换 actor 内部的 LLM 实现，解决单例持旧 Mock 引用导致测试失效的问题
    func updateLLMForTesting(_ newLLM: any LLMServiceProtocol) {
        self.llm = newLLM
    }
    #endif

    /// 输入截断保护：超长内容统一截断至 PromptConstants.TokenLimits.maxSynthesisInputLength
    private func truncated(_ content: String) -> String {
        String(content.prefix(PromptConstants.TokenLimits.maxSynthesisInputLength))
    }

    /// 摘要
    /// - Parameter content: content
    /// - Returns: 字符串
    func summarize(content: String) async throws -> String {
        let prompt = promptService.summaryPrompt + promptService.languageInstruction + "\n\n\n\(truncated(content))"
        let systemPrompt = L10n.AI.Prompt.System.summarize
        let result = try await currentLLM.generate(prompt: prompt, systemPrompt: systemPrompt)
        return SynthesisProcessor.cleanMarkdown(result)
    }

    /// 生成思维导图 (Mermaid)
    func generateMindMap(content: String) async throws -> String {
        let prompt = promptService.mindmapPrompt + promptService.languageInstruction + "\n\n\n\(truncated(content))"
        let systemPrompt = L10n.AI.Prompt.System.mindmap
        let result = try await currentLLM.generate(prompt: prompt, systemPrompt: systemPrompt)
        let formatted = SynthesisProcessor.formatMermaid(result, fallbackPrefix: "mindmap")
        if formatted.isEmpty || formatted.utf8.count < AppConstants.ExportLimits.minValidSynthesisTextBytes {
            return SynthesisProcessor.convertMarkdownToListMindmap(result, title: L10n.AI.Synthesis.Mindmap.title)
        }
        return formatted
    }

    /// 提取Actions
    /// - Parameter content: content
    /// - Returns: 字符串
    func extractActions(content: String) async throws -> String {
        let prompt = promptService.actionPrompt + promptService.languageInstruction + "\n\n\n\(truncated(content))"
        let systemPrompt = L10n.AI.Prompt.System.actions
        let result = try await currentLLM.generate(prompt: prompt, systemPrompt: systemPrompt)
        return SynthesisProcessor.cleanMarkdown(result)
    }

    /// 生成Presentation
    /// - Parameter content: content
    /// - Returns: 字符串
    func generatePresentation(content: String) async throws -> String {
        let prompt = promptService.slidesPrompt + promptService.languageInstruction + "\n\n\n\(truncated(content))"
        let systemPrompt = L10n.AI.Prompt.System.slides
        let rawResult = (try? await currentLLM.generate(prompt: prompt, systemPrompt: systemPrompt)) ?? ""
        let cleaned = SynthesisProcessor.cleanMarkdown(rawResult)
        if cleaned.utf8.count >= AppConstants.ExportLimits.minValidSynthesisTextBytes {
            return cleaned
        }
        return SynthesisProcessor.generateFallbackPresentation(from: content, title: L10n.AI.Prompt.Expert.Slides.title)
    }

    /// 生成测验题
    func generateQuiz(content: String) async throws -> String {
        let schemaInstruction = "\n\nPlease output valid raw JSON adhering to the JSON Schema below (no markdown block tags):\n" + PromptConstants.Schemas.quizJSONSchema
        let prompt = promptService.quizPrompt + promptService.languageInstruction + schemaInstruction + "\n\n\n\(truncated(content))"
        let quizTitle = L10n.AI.Prompt.Quiz.defaultTitle

        let systemPrompt = L10n.AI.Prompt.System.quiz(quizTitle)
        let rawResult = (try? await currentLLM.generate(prompt: prompt, systemPrompt: systemPrompt)) ?? ""

        // 使用专用的 QuizProcessor 进行解析与格式转换
        if QuizProcessor.canDecodeAsQuizModel(rawResult) {
            return rawResult
        }

        if let formatted = QuizProcessor.convertJSONToMarkdown(rawResult) {
            return formatted
        }

        if rawResult.utf8.count >= AppConstants.ExportLimits.minValidSynthesisTextBytes {
            return rawResult
        }

        return SynthesisProcessor.generateFallbackQuiz(from: content, title: L10n.AI.Prompt.Quiz.defaultTitle)
    }

    /// 生成信息图表 (Mermaid)
    func generateInfographic(content: String) async throws -> String {
        let prompt = promptService.infographicPrompt + promptService.languageInstruction + "\n\n\n\(truncated(content))"
        let systemPrompt = L10n.AI.Prompt.System.infographic
        let rawResult = (try? await currentLLM.generate(prompt: prompt, systemPrompt: systemPrompt)) ?? ""
        let formatted = SynthesisProcessor.formatMermaid(rawResult, fallbackPrefix: "graph TD")
        if formatted.isEmpty || formatted.utf8.count < AppConstants.ExportLimits.minValidSynthesisTextBytes {
            return SynthesisProcessor.generateFallbackInfographic(from: content, title: L10n.Knowledge.Page.AI.infographic)
        }
        return formatted
    }

    /// 生成Report
    /// - Parameter content: content
    /// - Returns: 字符串
    func generateReport(content: String) async throws -> String {
        let prompt = promptService.reportPrompt + promptService.languageInstruction + "\n\n\n\(truncated(content))"
        let systemPrompt = L10n.AI.Prompt.System.report
        let rawResult = (try? await currentLLM.generate(prompt: prompt, systemPrompt: systemPrompt)) ?? ""
        let cleaned = SynthesisProcessor.cleanMarkdown(rawResult)
        if cleaned.utf8.count >= AppConstants.ExportLimits.minValidSynthesisTextBytes {
            return cleaned
        }
        return SynthesisProcessor.generateFallbackReport(from: content, title: L10n.AI.Prompt.Expert.Report.title)
    }

    /// 知识深度扩充：对现有内容进行多维度深挖与背景补充
    func expandKnowledge(content: String) async throws -> String {
        let prompt = promptService.expansionPrompt + promptService.languageInstruction + "\n\n\n\(truncated(content))"
        let systemPrompt = L10n.AI.Prompt.System.expansion
        let rawResult = (try? await currentLLM.generate(prompt: prompt, systemPrompt: systemPrompt)) ?? ""
        let cleaned = SynthesisProcessor.cleanMarkdown(rawResult)
        if cleaned.utf8.count >= AppConstants.ExportLimits.minValidSynthesisTextBytes {
            return cleaned
        }
        return SynthesisProcessor.generateFallbackExpansion(from: content, title: L10n.Knowledge.Page.AI.expansion)
    }

    /// 针对具体的 Lint 问题提供 AI 修复建议
    func suggestFix(issue: LintIssue, pages: [KnowledgePage]) async throws -> String {
        let pageTitle = pages.first(where: { $0.id == issue.pageID })?.title ?? L10n.Common.unknown
        let pageContent = pages.first(where: { $0.title == pageTitle })?.content ?? ""
        let otherTitles = pages.map { $0.title }.filter { $0 != pageTitle }

        let prompt = """
        \(promptService.fixSuggestionPrompt)
        \(promptService.languageInstruction)

        \(L10n.AI.LLM.Prompt.pageTitle)\(pageTitle)
        \(L10n.AI.LLM.Prompt.issueDesc)\(issue.message)
        \(L10n.AI.LLM.Prompt.issueType)\(issue.type.icon)

        \(L10n.AI.LLM.Prompt.pageContentSnippet)
        \"\"\"
        \(pageContent.prefix(500))
        \"\"\"

        \(L10n.AI.LLM.Prompt.otherPageTitles)
        \(otherTitles.prefix(50).joined(separator: ", "))
        """

        let systemPrompt = L10n.AI.Prompt.System.suggestFix
        return try await llm.generate(prompt: prompt, systemPrompt: systemPrompt)
    }

    /// 自动生成启发式问题：分析知识库并推荐 3 个最值得深挖的问题
    func generateInsightfulQuestions(pages: [KnowledgePage]) async throws -> [String] {
        guard !pages.isEmpty else { return [] }

        let pageSummaries = pages.sorted(by: { $0.updatedAt > $1.updatedAt })
            .prefix(15)
            .map { "\($0.title): \($0.content.prefix(100))..." }
            .joined(separator: "\n")

        let prompt = """
        \(promptService.insightQuestionsPrompt)
        \(promptService.languageInstruction)


        \(pageSummaries)
        """

        // 诊断日志（logger 通过 @Inject 注入）
        logger.debug("[InsightQuestions] Prompt(前500): \(String(prompt.prefix(500)))")

        let systemPrompt = L10n.AI.Prompt.System.insightQuestions
        let result = try await llm.generate(prompt: prompt, systemPrompt: systemPrompt)
        logger.debug("[InsightQuestions] 原始响应(前300): \(String(result.prefix(300)))")
        return LLMUtils.parseJSONArray(result)
    }

    /// 根据对话上下文，预测用户可能还会问的 3 个问题
    /// - Parameters:
    ///   - history: 当前对话的历史记录
    ///   - pages: 相关知识库页面列表
    /// - Returns: 预测的 3 个问题字符串列表
    func predictFollowUpQuestions(history: [ChatMessage], pages: [KnowledgePage]) async throws -> [String] {
        guard !history.isEmpty else { return [] }

        // 提取最近最多 10 条消息（5 轮对话）以作为大模型预测的基础上下文
        let recentMessages = history.suffix(10)
            .map { "\($0.role == .user ? "User" : "Assistant"): \($0.content)" }
            .joined(separator: "\n")

        let prompt = L10n.AI.Prompt.predictQuestions(recentMessages)

        logger.debug("[PredictQuestions] Prompt: \(String(prompt.prefix(500)))")
        let result = try await currentLLM.generate(
            prompt: prompt,
            systemPrompt: L10n.AI.Prompt.predictQuestionsSystem
        )
        logger.debug("[PredictQuestions] LLM Response: \(result)")
        
        return LLMUtils.parseJSONArray(result)
    }

    /// 统一合成入口 (Facade)
    func synthesize(type: SynthesisStore.SynthesisType, content: String) async throws -> String {
        switch type {
        case .mindmap:
            updateStatus(L10n.AI.Status.structuring)
            return try await generateMindMap(content: content)
        case .quiz:
            updateStatus(L10n.AI.Status.extracting)
            return try await generateQuiz(content: content)
        case .slides:
            updateStatus(L10n.AI.Status.organizing)
            return try await generatePresentation(content: content)
        case .report:
            updateStatus(L10n.AI.Status.synthesizing)
            return try await generateReport(content: content)
        case .infographic:
            updateStatus(L10n.AI.Status.visualizing)
            return try await generateInfographic(content: content)
        case .expansion:
            updateStatus(L10n.AI.Status.digging)
            return try await expandKnowledge(content: content)
        }
    }

    private func updateStatus(_ text: String) {
        Task { @MainActor in
            TaskCenter.shared.updateLatestStatus(text)
        }
    }
}
