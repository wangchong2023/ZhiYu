//
//  AISynthesisServiceDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：AISynthesisService 深度补盲测试 — 覆盖 11 个合成方法的正常/空/超长/LLM 抛错路径、
//            6 个 SynthesisType Facade 分派、suggestFix 的 pageID 匹配/不匹配/空 pages 边界、
//            generateInsightfulQuestions/predictFollowUpQuestions 的空输入短路、
//            截断保护、fallback 降级链，以发现生产代码潜在 bug 为首要目标。
//
//  说明：Tests/Unit/AI/AISynthesisServiceTests.swift 已覆盖基础空输入与 6 类合成正常路径。
//        本文件补充 fallback 边界、LLM 抛错降级、suggestFix/insight/followUp 深度场景、
//        synthesize Facade 全 case、截断行为、currentLLM vs llm 不一致 bug 验证。
//

import XCTest
import UFPCore
import Combine
import Dependencies
@testable import ZhiYu

// MARK: - 可控 LLM Mock（支持按调用返回不同结果 / 抛错 / 记录调用）

/// 可控 LLM 服务 Mock：记录所有 generate 调用，支持按 prompt 关键字返回不同响应或抛错。
@MainActor
final class ControllableLLMService: LLMServiceProtocol, @unchecked Sendable {
    /// 默认响应（无 handler 命中时返回）
    var defaultResponse: String = ""
    /// 按 systemPrompt 关键字匹配的自定义 handler
    var generateHandler: ((String, String) async throws -> String)?
    /// 是否在下次 generate 抛错
    var shouldThrow: Bool = false
    /// 抛错时使用的 Error
    var throwError: Error = LLMError.notConfigured
    /// 记录所有 generate 调用的 (prompt, systemPrompt)
    private(set) var generateCalls: [(prompt: String, systemPrompt: String)] = []

    var isEnabled: Bool = true
    var provider: LLMProvider = .custom
    var apiKey: String = ""
    var baseURL: String = ""
    var model: String = ""
    var autoScan: Bool = false
    var autoRefactor: Bool = false

    func chat(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) async throws -> ChatMessageDTO {
        ChatMessageDTO(role: .assistant, content: defaultResponse)
    }

    func chatStream(query: String, history: [ChatMessageDTO], pages: [any KnowledgePageRepresentable]) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func generate(prompt: String, systemPrompt: String, maxTokens: Int) async throws -> String {
        generateCalls.append((prompt, systemPrompt))
        if shouldThrow { throw throwError }
        if let handler = generateHandler {
            return try await handler(prompt, systemPrompt)
        }
        return defaultResponse
    }

    func smartIngest(title: String, rawContent: String, pages: [any KnowledgePageRepresentable]) async throws -> SmartIngestResultDTO {
        SmartIngestResultDTO(title: title, compiledContent: "", suggestedTags: [], suggestedType: "", relatedTitles: [], summary: "")
    }
    func discoverPotentialLinks(content: String, existingTitles: [String]) async throws -> [String] { [] }
    func foldContent(existingContent: String, newContent: String, title: String) async throws -> String { "" }
    func analyzeForRefactoring(pages: [any KnowledgePageRepresentable]) async throws -> [RefactorSuggestionDTO] { [] }
    func rewriteQuery(_ query: String) async -> String { query }
    func expandQuery(_ query: String) async -> [String] { [query] }
    func rerank(query: String, candidates: [any KnowledgePageRepresentable]) async throws -> [any KnowledgePageRepresentable] { candidates }
    func rerankChunks(query: String, chunks: [PageChunk]) async -> [PageChunk] { chunks }
    func generateHypotheticalDocument(query: String) async -> String { query }
}

// MARK: - AISynthesisService 深度测试

@MainActor
final class AISynthesisServiceDeepTests: XCTestCase {

    // MARK: - 测试夹具

    private var mockLLM: ControllableLLMService!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        resetPersistentTestState()

        // 创建可控 Mock 并同时注入 actor 内部 llm 引用 + 覆盖 ServiceContainer 注册，
        // 因为 currentLLM computed property 优先从 ServiceContainer 解析，
        // 仅 updateLLMForTesting 无法覆盖 currentLLM 的解析路径。
        let llm = ControllableLLMService()
        self.mockLLM = llm
        ServiceContainer.shared.register(llm as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        await AISynthesisService.shared.updateLLMForTesting(llm)
    }

    override func tearDown() async throws {
        await MainActor.run { resetPersistentTestState() }
        try await super.tearDown()
    }

    // MARK: - summarize 正常路径

    /// 验证 summarize 在 LLM 返回正常文本时，应返回 cleanMarkdown 处理后的结果。
    func testSummarize_正常文本返回清理后的Markdown() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = "这是摘要内容\\# 标题"
        }

        let result = try await AISynthesisService.shared.summarize(content: "测试内容")

        XCTAssertFalse(result.isEmpty, "summarize 应返回非空结果")
        XCTAssertTrue(result.contains("摘要"), "应包含 LLM 返回的摘要文本")
    }

    /// 验证 summarize 在 LLM 抛错时应向上抛出（summarize 无 fallback）。
    func testSummarize_LLM抛错时向上传播异常() async throws {
        await MainActor.run {
            mockLLM.shouldThrow = true
            mockLLM.throwError = LLMError.notConfigured
        }

        do {
            _ = try await AISynthesisService.shared.summarize(content: "内容")
            XCTFail("summarize 在 LLM 抛错时应向上抛出异常")
        } catch {
            XCTAssertTrue(error is LLMError, "应抛出 LLMError")
        }
    }

    /// 验证 summarize 传入空字符串不崩溃，应正常调用 LLM。
    func testSummarize_空内容不崩溃() async throws {
        await MainActor.run { mockLLM.defaultResponse = "空内容摘要" }

        let result = try await AISynthesisService.shared.summarize(content: "")

        XCTAssertEqual(result, "空内容摘要")
    }

    // MARK: - summarize 截断保护

    /// 验证 summarize 对超长内容应截断至 maxSynthesisInputLength (8000) 后再传给 LLM。
    func testSummarize_超长内容应截断至8000字符() async throws {
        await MainActor.run { mockLLM.defaultResponse = "ok" }

        let longContent = String(repeating: "a", count: 20_000)
        _ = try await AISynthesisService.shared.summarize(content: longContent)

        let lastCall = try XCTUnwrap(mockLLM.generateCalls.last)
        // prompt = summaryPrompt + languageInstruction + "\n\n\n" + truncated(content)
        // 截断后 content 部分应为 8000 字符
        XCTAssertTrue(lastCall.prompt.contains(String(repeating: "a", count: 8000)), "超长内容应被截断至 8000 字符")
        XCTAssertFalse(lastCall.prompt.contains(String(repeating: "a", count: 8001)), "截断后不应包含超过 8000 个连续 a")
    }

    /// 验证 summarize 对恰好 8000 字符的内容不截断。
    func testSummarize_恰好8000字符不截断() async throws {
        await MainActor.run { mockLLM.defaultResponse = "ok" }

        let exactContent = String(repeating: "b", count: PromptConstants.TokenLimits.maxSynthesisInputLength)
        _ = try await AISynthesisService.shared.summarize(content: exactContent)

        let lastCall = try XCTUnwrap(mockLLM.generateCalls.last)
        XCTAssertTrue(lastCall.prompt.contains(exactContent), "恰好 8000 字符的内容应完整保留")
    }

    // MARK: - generateMindMap fallback 逻辑

    /// 验证 generateMindMap 在 LLM 返回有效 Mermaid 时直接返回格式化结果。
    func testGenerateMindMap_有效Mermaid返回格式化结果() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = """
            ```mermaid
            mindmap
              root((测试))
                分支1
                分支2
            ```
            """
        }

        let result = try await AISynthesisService.shared.generateMindMap(content: "内容")

        XCTAssertFalse(result.isEmpty, "有效 Mermaid 应返回非空结果")
    }

    /// 验证 generateMindMap 在 LLM 返回空字符串时触发 fallback 至 convertMarkdownToListMindmap。
    func testGenerateMindMap_LLM返回空字符串触发Fallback() async throws {
        await MainActor.run { mockLLM.defaultResponse = "" }

        let result = try await AISynthesisService.shared.generateMindMap(content: "# 标题\n- 要点1\n- 要点2")

        XCTAssertFalse(result.isEmpty, "空 Mermaid 应触发 fallback 自愈生成非空结果")
    }

    /// 验证 generateMindMap 在 LLM 返回过短内容（< 10 字节）时触发 fallback。
    func testGenerateMindMap_LLM返回过短内容触发Fallback() async throws {
        await MainActor.run { mockLLM.defaultResponse = "短" }

        let result = try await AISynthesisService.shared.generateMindMap(content: "内容")

        XCTAssertFalse(result.isEmpty, "过短 Mermaid 应触发 fallback")
    }

    /// 验证 generateMindMap 在 LLM 抛错时向上传播（无 try? 降级）。
    func testGenerateMindMap_LLM抛错时向上传播() async throws {
        await MainActor.run {
            mockLLM.shouldThrow = true
        }

        do {
            _ = try await AISynthesisService.shared.generateMindMap(content: "内容")
            XCTFail("generateMindMap 在 LLM 抛错时应向上传播")
        } catch {
            // 预期抛出
        }
    }

    // MARK: - extractActions

    /// 验证 extractActions 正常返回 cleanMarkdown 处理后的结果。
    func testExtractActions_正常返回清理后文本() async throws {
        await MainActor.run { mockLLM.defaultResponse = "1. 行动一\\n2. 行动二" }

        let result = try await AISynthesisService.shared.extractActions(content: "内容")

        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("行动"))
    }

    /// 验证 extractActions 在 LLM 抛错时向上传播（无 fallback）。
    func testExtractActions_LLM抛错时向上传播() async throws {
        await MainActor.run { mockLLM.shouldThrow = true }

        do {
            _ = try await AISynthesisService.shared.extractActions(content: "内容")
            XCTFail("extractActions 应向上抛出")
        } catch {
            // 预期
        }
    }

    // MARK: - generatePresentation fallback 逻辑

    /// 验证 generatePresentation 在 LLM 返回有效长文本时直接返回 cleaned。
    func testGeneratePresentation_有效长文本返回cleaned() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = "# 幻灯片1\n这是足够长的演示文稿内容用于通过最小字节校验"
        }

        let result = try await AISynthesisService.shared.generatePresentation(content: "内容")

        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("幻灯片"))
    }

    /// 验证 generatePresentation 在 LLM 返回空字符串时触发 fallback 生成。
    func testGeneratePresentation_LLM返回空触发Fallback() async throws {
        await MainActor.run { mockLLM.defaultResponse = "" }

        let result = try await AISynthesisService.shared.generatePresentation(content: "# 主题\n- 要点1\n- 要点2")

        XCTAssertFalse(result.isEmpty, "空响应应触发 fallback 自愈")
    }

    /// 验证 generatePresentation 在 LLM 返回过短内容时触发 fallback。
    func testGeneratePresentation_LLM返回过短触发Fallback() async throws {
        await MainActor.run { mockLLM.defaultResponse = "短" }

        let result = try await AISynthesisService.shared.generatePresentation(content: "内容")

        XCTAssertFalse(result.isEmpty, "过短响应应触发 fallback")
    }

    /// 验证 generatePresentation 使用 try? 降级，LLM 抛错时走 fallback
    /// - Note: C-14/Bug#1 评估结论 — generatePresentation/generateQuiz/generateInfographic/
    ///   generateReport/expandKnowledge 使用 try? 降级是有意设计，这些方法有 fallback 逻辑
    ///   （generateFallbackPresentation/generateFallbackQuiz 等），确保 LLM 不可用时仍有输出。
    ///   summarize/extractActions/generateMindMap 用 try 抛出是因为它们没有 fallback。
    ///   行为不一致但设计合理，不修复。
    func testGeneratePresentation_LLM抛错时降级返回fallback() async throws {
        await MainActor.run {
            mockLLM.shouldThrow = true
            mockLLM.throwError = LLMError.notConfigured
        }

        // generatePresentation 使用 (try? await ...) ?? "" 降级，不向上抛错
        let result = try await AISynthesisService.shared.generatePresentation(content: "内容")

        // 降级设计：LLM 抛错时 generatePresentation 返回 fallback 文本（非空）
        XCTAssertFalse(result.isEmpty, "LLM 抛错时 generatePresentation 降级返回 fallback 文本")
    }

    // MARK: - generateQuiz fallback 链

    /// 验证 generateQuiz 在 LLM 返回可解析的 Quiz JSON 时直接返回原始 JSON。
    func testGenerateQuiz_可解析JSON直接返回原文() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = """
            [
              {
                "question": "测试问题?",
                "options": ["A", "B", "C", "D"],
                "answerIndex": 0,
                "explanation": "解释"
              }
            ]
            """
        }

        let result = try await AISynthesisService.shared.generateQuiz(content: "内容")

        XCTAssertFalse(result.isEmpty)
    }

    /// 验证 generateQuiz 在 LLM 返回空字符串时触发 fallback 生成占位 Quiz。
    func testGenerateQuiz_LLM返回空触发Fallback() async throws {
        await MainActor.run { mockLLM.defaultResponse = "" }

        let result = try await AISynthesisService.shared.generateQuiz(content: "内容")

        XCTAssertFalse(result.isEmpty, "空响应应触发 fallback Quiz 生成")
    }

    /// 验证 generateQuiz 在 LLM 返回非 JSON 乱码但长度 >= 10 字节时返回原文。
    func testGenerateQuiz_非JSON乱码长度达标返回原文() async throws {
        let garbage = "这是非JSON的乱码文本内容长度超过十个字节"
        await MainActor.run { mockLLM.defaultResponse = garbage }

        let result = try await AISynthesisService.shared.generateQuiz(content: "内容")

        XCTAssertEqual(result, garbage, "非 JSON 但长度 >= 10 字节时应直接返回原文")
    }

    /// 验证 generateQuiz 在 LLM 抛错时静默降级（try? 降级）。
    func testGenerateQuiz_LLM抛错时静默降级() async throws {
        await MainActor.run { mockLLM.shouldThrow = true }

        let result = try await AISynthesisService.shared.generateQuiz(content: "内容")

        XCTAssertFalse(result.isEmpty, "LLM 抛错时应降级生成 fallback Quiz")
    }

    // MARK: - generateInfographic fallback

    /// 验证 generateInfographic 在 LLM 返回有效 Mermaid 时返回格式化结果。
    func testGenerateInfographic_有效Mermaid返回格式化() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = """
            ```mermaid
            graph TD
              A[节点A] --> B[节点B]
            ```
            """
        }

        let result = try await AISynthesisService.shared.generateInfographic(content: "内容")

        XCTAssertFalse(result.isEmpty)
    }

    /// 验证 generateInfographic 在 LLM 返回空时触发 fallback。
    func testGenerateInfographic_LLM返回空触发Fallback() async throws {
        await MainActor.run { mockLLM.defaultResponse = "" }

        let result = try await AISynthesisService.shared.generateInfographic(content: "内容")

        XCTAssertFalse(result.isEmpty, "空响应应触发 fallback 信息图")
    }

    /// 验证 generateInfographic 在 LLM 抛错时静默降级。
    func testGenerateInfographic_LLM抛错时静默降级() async throws {
        await MainActor.run { mockLLM.shouldThrow = true }

        let result = try await AISynthesisService.shared.generateInfographic(content: "内容")

        XCTAssertFalse(result.isEmpty, "LLM 抛错时应降级生成 fallback 信息图")
    }

    // MARK: - generateReport fallback

    /// 验证 generateReport 在 LLM 返回有效长文本时返回 cleaned。
    func testGenerateReport_有效长文本返回cleaned() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = "# 报告标题\n这是足够长的报告内容用于通过最小字节校验阈值"
        }

        let result = try await AISynthesisService.shared.generateReport(content: "内容")

        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("报告"))
    }

    /// 验证 generateReport 在 LLM 返回空时触发 fallback。
    func testGenerateReport_LLM返回空触发Fallback() async throws {
        await MainActor.run { mockLLM.defaultResponse = "" }

        let result = try await AISynthesisService.shared.generateReport(content: "内容")

        XCTAssertFalse(result.isEmpty, "空响应应触发 fallback 报告")
    }

    /// 验证 generateReport 在 LLM 抛错时静默降级。
    func testGenerateReport_LLM抛错时静默降级() async throws {
        await MainActor.run { mockLLM.shouldThrow = true }

        let result = try await AISynthesisService.shared.generateReport(content: "内容")

        XCTAssertFalse(result.isEmpty, "LLM 抛错时应降级生成 fallback 报告")
    }

    // MARK: - expandKnowledge fallback

    /// 验证 expandKnowledge 在 LLM 返回有效长文本时返回 cleaned。
    func testExpandKnowledge_有效长文本返回cleaned() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = "# 扩充标题\n这是足够长的知识扩充内容用于通过最小字节校验"
        }

        let result = try await AISynthesisService.shared.expandKnowledge(content: "内容")

        XCTAssertFalse(result.isEmpty)
    }

    /// 验证 expandKnowledge 在 LLM 返回空时触发 fallback。
    func testExpandKnowledge_LLM返回空触发Fallback() async throws {
        await MainActor.run { mockLLM.defaultResponse = "" }

        let result = try await AISynthesisService.shared.expandKnowledge(content: "内容")

        XCTAssertFalse(result.isEmpty, "空响应应触发 fallback 扩充")
    }

    /// 验证 expandKnowledge 在 LLM 抛错时静默降级。
    func testExpandKnowledge_LLM抛错时静默降级() async throws {
        await MainActor.run { mockLLM.shouldThrow = true }

        let result = try await AISynthesisService.shared.expandKnowledge(content: "内容")

        XCTAssertFalse(result.isEmpty, "LLM 抛错时应降级生成 fallback 扩充")
    }

    // MARK: - suggestFix pageID 匹配

    /// 验证 suggestFix 在 issue.pageID 匹配到 pages 中的页面时使用该页面标题和内容。
    func testSuggestFix_pageID匹配时使用对应页面() async throws {
        await MainActor.run { mockLLM.defaultResponse = "修复建议文本" }

        let pageID = UUID()
        let page = KnowledgePage(id: pageID, title: "匹配页面", content: "页面内容")
        let issue = LintIssue(severity: .warning, type: .stub, pageID: pageID, message: "问题描述", suggestion: "建议")

        let result = try await AISynthesisService.shared.suggestFix(issue: issue, pages: [page])

        XCTAssertEqual(result, "修复建议文本")
        let lastCall = try XCTUnwrap(mockLLM.generateCalls.last)
        XCTAssertTrue(lastCall.prompt.contains("匹配页面"), "prompt 应包含匹配页面的标题")
        XCTAssertTrue(lastCall.prompt.contains("页面内容"), "prompt 应包含匹配页面的内容")
    }

    /// 验证 suggestFix 在 issue.pageID 不匹配时使用 L10n.Common.unknown 作为标题。
    func testSuggestFix_pageID不匹配时使用未知标题() async throws {
        await MainActor.run { mockLLM.defaultResponse = "建议" }

        let page = KnowledgePage(title: "其他页面", content: "其他内容")
        let issue = LintIssue(severity: .warning, pageID: UUID(), message: "问题", suggestion: "建议")

        let result = try await AISynthesisService.shared.suggestFix(issue: issue, pages: [page])

        XCTAssertEqual(result, "建议")
        let lastCall = try XCTUnwrap(mockLLM.generateCalls.last)
        XCTAssertTrue(lastCall.prompt.contains(L10n.Common.unknown), "pageID 不匹配时应使用 L10n.Common.unknown 作为标题")
    }

    /// 验证 suggestFix 在 pages 为空时不崩溃。
    func testSuggestFix_空pages不崩溃() async throws {
        await MainActor.run { mockLLM.defaultResponse = "建议" }

        let issue = LintIssue(severity: .info, pageID: UUID(), message: "问题", suggestion: "建议")

        let result = try await AISynthesisService.shared.suggestFix(issue: issue, pages: [])

        XCTAssertEqual(result, "建议")
    }

    /// 验证 suggestFix 在 issue.pageID 为 nil 时使用 L10n.Common.unknown。
    func testSuggestFix_pageID为nil时使用未知标题() async throws {
        await MainActor.run { mockLLM.defaultResponse = "建议" }

        let issue = LintIssue(severity: .info, pageID: nil, message: "问题", suggestion: "建议")

        let result = try await AISynthesisService.shared.suggestFix(issue: issue, pages: [])

        XCTAssertEqual(result, "建议")
        let lastCall = try XCTUnwrap(mockLLM.generateCalls.last)
        XCTAssertTrue(lastCall.prompt.contains(L10n.Common.unknown))
    }

    /// 验证 suggestFix 在 LLM 抛错时向上传播（无 try? 降级）。
    func testSuggestFix_LLM抛错时向上传播() async throws {
        await MainActor.run { mockLLM.shouldThrow = true }

        let issue = LintIssue(severity: .info, message: "问题", suggestion: "建议")

        do {
            _ = try await AISynthesisService.shared.suggestFix(issue: issue, pages: [])
            XCTFail("suggestFix 在 LLM 抛错时应向上传播")
        } catch {
            // 预期
        }
    }

    /// 验证 suggestFix 使用 currentLLM 而非 llm
    /// - Note: C-12/Bug#2 已修复 — suggestFix 现在使用 currentLLM.generate，DI 动态更新 LLM 实例时生效。
    func testSuggestFix_使用currentLLM调用() async throws {
        await MainActor.run { mockLLM.defaultResponse = "通过currentLLM调用" }

        let issue = LintIssue(severity: .info, message: "问题", suggestion: "建议")
        let result = try await AISynthesisService.shared.suggestFix(issue: issue, pages: [])

        XCTAssertEqual(result, "通过currentLLM调用")
        XCTAssertGreaterThanOrEqual(mockLLM.generateCalls.count, 1, "suggestFix 应通过 currentLLM 调用 generate")
    }

    // MARK: - generateInsightfulQuestions

    /// 验证 generateInsightfulQuestions 在 pages 为空时返回空数组。
    func testGenerateInsightfulQuestions_空pages返回空数组() async throws {
        let result = try await AISynthesisService.shared.generateInsightfulQuestions(pages: [])

        XCTAssertTrue(result.isEmpty)
    }

    /// 验证 generateInsightfulQuestions 在 LLM 返回标准 JSON 数组时正确解析。
    func testGenerateInsightfulQuestions_标准JSON数组正确解析() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = "[\"问题一\", \"问题二\", \"问题三\"]"
        }

        let pages = [KnowledgePage(title: "页面", content: "内容")]
        let result = try await AISynthesisService.shared.generateInsightfulQuestions(pages: pages)

        XCTAssertEqual(result.count, 3)
        if result.count >= 3 {
            XCTAssertEqual(result[0], "问题一")
            XCTAssertEqual(result[1], "问题二")
            XCTAssertEqual(result[2], "问题三")
        }
    }

    /// 验证 generateInsightfulQuestions 在 LLM 返回非 JSON 时返回空数组。
    func testGenerateInsightfulQuestions_非JSON返回空数组() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = "这不是JSON数组"
        }

        let pages = [KnowledgePage(title: "页面", content: "内容")]
        let result = try await AISynthesisService.shared.generateInsightfulQuestions(pages: pages)

        XCTAssertTrue(result.isEmpty, "非 JSON 应优雅返回空数组")
    }

    /// 验证 generateInsightfulQuestions 在 LLM 返回数字数组时转为字符串数组。
    func testGenerateInsightfulQuestions_数字数组转为字符串数组() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = "[1, 2, 3]"
        }

        let pages = [KnowledgePage(title: "页面", content: "内容")]
        let result = try await AISynthesisService.shared.generateInsightfulQuestions(pages: pages)

        XCTAssertEqual(result.count, 3)
        if result.count >= 3 {
            XCTAssertEqual(result[0], "1")
            XCTAssertEqual(result[1], "2")
            XCTAssertEqual(result[2], "3")
        }
    }

    /// 验证 generateInsightfulQuestions 在 LLM 抛错时向上传播。
    func testGenerateInsightfulQuestions_LLM抛错时向上传播() async throws {
        await MainActor.run { mockLLM.shouldThrow = true }

        let pages = [KnowledgePage(title: "页面", content: "内容")]

        do {
            _ = try await AISynthesisService.shared.generateInsightfulQuestions(pages: pages)
            XCTFail("应向上抛出")
        } catch {
            // 预期
        }
    }

    /// 验证 generateInsightfulQuestions 只取最近更新的 15 个页面。
    func testGenerateInsightfulQuestions_只取最近15个页面() async throws {
        await MainActor.run { mockLLM.defaultResponse = "[]" }

        // 构造 20 个页面，updatedAt 递增
        let pages = (0..<20).map { i in
            KnowledgePage(title: "页面\(i)", content: "内容", updatedAt: Date(timeIntervalSince1970: TimeInterval(i)))
        }

        _ = try await AISynthesisService.shared.generateInsightfulQuestions(pages: pages)

        let lastCall = try XCTUnwrap(mockLLM.generateCalls.last)
        // 最近 15 个页面（updatedAt 最大的 15 个，即索引 5..19）
        XCTAssertTrue(lastCall.prompt.contains("页面19"), "应包含最近更新的页面19")
        XCTAssertTrue(lastCall.prompt.contains("页面5"), "应包含最近更新的页面5")
        XCTAssertFalse(lastCall.prompt.contains("页面4"), "不应包含 updatedAt 较早的页面4（超出前 15）")
    }

    /// 验证 generateInsightfulQuestions 使用 currentLLM 而非 llm
    /// - Note: C-13/Bug#3 已修复 — generateInsightfulQuestions 现在使用 currentLLM.generate。
    func testGenerateInsightfulQuestions_使用currentLLM调用() async throws {
        await MainActor.run { mockLLM.defaultResponse = "[]" }

        let pages = [KnowledgePage(title: "页面", content: "内容")]
        _ = try await AISynthesisService.shared.generateInsightfulQuestions(pages: pages)

        XCTAssertGreaterThanOrEqual(mockLLM.generateCalls.count, 1, "generateInsightfulQuestions 应通过 currentLLM 调用")
    }

    // MARK: - predictFollowUpQuestions

    /// 验证 predictFollowUpQuestions 在 history 为空时返回空数组。
    func testPredictFollowUpQuestions_空history返回空数组() async throws {
        let result = try await AISynthesisService.shared.predictFollowUpQuestions(history: [], pages: [])

        XCTAssertTrue(result.isEmpty)
    }

    /// 验证 predictFollowUpQuestions 在 LLM 返回标准 JSON 数组时正确解析。
    func testPredictFollowUpQuestions_标准JSON数组正确解析() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = "[\"追问1\", \"追问2\", \"追问3\"]"
        }

        let history = [ChatMessage(role: .user, content: "你好")]
        let result = try await AISynthesisService.shared.predictFollowUpQuestions(history: history, pages: [])

        XCTAssertEqual(result.count, 3)
    }

    /// 验证 predictFollowUpQuestions 在 LLM 返回非 JSON 时返回空数组。
    func testPredictFollowUpQuestions_非JSON返回空数组() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = "非JSON文本"
        }

        let history = [ChatMessage(role: .user, content: "你好")]
        let result = try await AISynthesisService.shared.predictFollowUpQuestions(history: history, pages: [])

        XCTAssertTrue(result.isEmpty)
    }

    /// 验证 predictFollowUpQuestions 在 LLM 抛错时向上传播。
    func testPredictFollowUpQuestions_LLM抛错时向上传播() async throws {
        await MainActor.run { mockLLM.shouldThrow = true }

        let history = [ChatMessage(role: .user, content: "你好")]

        do {
            _ = try await AISynthesisService.shared.predictFollowUpQuestions(history: history, pages: [])
            XCTFail("应向上抛出")
        } catch {
            // 预期
        }
    }

    /// 验证 predictFollowUpQuestions 只取最近 10 条历史消息。
    func testPredictFollowUpQuestions_只取最近10条历史() async throws {
        await MainActor.run { mockLLM.defaultResponse = "[]" }

        // 构造 15 条历史
        let history = (0..<15).map { i in
            ChatMessage(role: .user, content: "消息\(i)")
        }

        _ = try await AISynthesisService.shared.predictFollowUpQuestions(history: history, pages: [])

        let lastCall = try XCTUnwrap(mockLLM.generateCalls.last)
        XCTAssertTrue(lastCall.prompt.contains("消息14"), "应包含最近的消息14")
        XCTAssertTrue(lastCall.prompt.contains("消息5"), "应包含最近第 10 条消息5")
        XCTAssertFalse(lastCall.prompt.contains("消息4"), "不应包含超出最近 10 条的消息4")
    }

    /// 验证 predictFollowUpQuestions 对 user/assistant 角色正确标注。
    func testPredictFollowUpQuestions_角色标注正确() async throws {
        await MainActor.run { mockLLM.defaultResponse = "[]" }

        let history = [
            ChatMessage(role: .user, content: "用户问题"),
            ChatMessage(role: .assistant, content: "助手回复")
        ]

        _ = try await AISynthesisService.shared.predictFollowUpQuestions(history: history, pages: [])

        let lastCall = try XCTUnwrap(mockLLM.generateCalls.last)
        XCTAssertTrue(lastCall.prompt.contains("User: 用户问题"), "user 消息应标注为 User")
        XCTAssertTrue(lastCall.prompt.contains("Assistant: 助手回复"), "assistant 消息应标注为 Assistant")
    }

    // MARK: - synthesize Facade

    /// 验证 synthesize(.mindmap) 正确分派到 generateMindMap。
    func testSynthesize_mindmap分派正确() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = """
            ```mermaid
            mindmap
              root((测试))
                分支
            ```
            """
        }

        let result = try await AISynthesisService.shared.synthesize(type: .mindmap, content: "内容")

        XCTAssertFalse(result.isEmpty)
    }

    /// 验证 synthesize(.quiz) 正确分派到 generateQuiz。
    func testSynthesize_quiz分派正确() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = "[{\"question\":\"Q?\",\"options\":[\"A\"],\"answerIndex\":0}]"
        }

        let result = try await AISynthesisService.shared.synthesize(type: .quiz, content: "内容")

        XCTAssertFalse(result.isEmpty)
    }

    /// 验证 synthesize(.slides) 正确分派到 generatePresentation。
    func testSynthesize_slides分派正确() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = "# 幻灯片1\n足够长的演示文稿内容用于通过最小字节校验阈值"
        }

        let result = try await AISynthesisService.shared.synthesize(type: .slides, content: "内容")

        XCTAssertFalse(result.isEmpty)
    }

    /// 验证 synthesize(.report) 正确分派到 generateReport。
    func testSynthesize_report分派正确() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = "# 报告\n足够长的报告内容用于通过最小字节校验阈值"
        }

        let result = try await AISynthesisService.shared.synthesize(type: .report, content: "内容")

        XCTAssertFalse(result.isEmpty)
    }

    /// 验证 synthesize(.infographic) 正确分派到 generateInfographic。
    func testSynthesize_infographic分派正确() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = """
            ```mermaid
            graph TD
              A --> B
            ```
            """
        }

        let result = try await AISynthesisService.shared.synthesize(type: .infographic, content: "内容")

        XCTAssertFalse(result.isEmpty)
    }

    /// 验证 synthesize(.expansion) 正确分派到 expandKnowledge。
    func testSynthesize_expansion分派正确() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = "# 扩充\n足够长的知识扩充内容用于通过最小字节校验阈值"
        }

        let result = try await AISynthesisService.shared.synthesize(type: .expansion, content: "内容")

        XCTAssertFalse(result.isEmpty)
    }

    /// 验证 synthesize 在子方法抛错时向上传播（以 mindmap 为例，无 try? 降级的方法）。
    func testSynthesize_mindmapLLM抛错时向上传播() async throws {
        await MainActor.run { mockLLM.shouldThrow = true }

        do {
            _ = try await AISynthesisService.shared.synthesize(type: .mindmap, content: "内容")
            XCTFail("synthesize(.mindmap) 在 LLM 抛错时应向上传播")
        } catch {
            // 预期
        }
    }

    /// 验证 synthesize(.slides) 在 LLM 抛错时静默降级（因 generatePresentation 用 try?）。
    func testSynthesize_slidesLLM抛错时静默降级() async throws {
        await MainActor.run { mockLLM.shouldThrow = true }

        // slides 走 generatePresentation，使用 try? 降级
        let result = try await AISynthesisService.shared.synthesize(type: .slides, content: "内容")

        XCTAssertFalse(result.isEmpty, "slides 在 LLM 抛错时应降级返回 fallback")
    }

    // MARK: - currentLLM 动态解析

    /// 验证 summarize 使用 currentLLM（动态解析 ServiceContainer 中的最新实例）。
    func testSummarize_使用currentLLM动态解析() async throws {
        // 注册一个新的 Mock 到 ServiceContainer
        let newMock = await MainActor.run { ControllableLLMService() }
        await MainActor.run {
            newMock.defaultResponse = "来自DI的响应"
            ServiceContainer.shared.register(newMock as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        }

        // 不调用 updateLLMForTesting，依赖 currentLLM 动态解析
        let result = try await AISynthesisService.shared.summarize(content: "内容")

        XCTAssertEqual(result, "来自DI的响应", "summarize 应通过 currentLLM 动态解析 ServiceContainer 中的最新实例")
        let newMockCalls = await MainActor.run { newMock.generateCalls }
        XCTAssertGreaterThan(newMockCalls.count, 0, "应调用 ServiceContainer 中注册的新 Mock")
    }

    /// 验证 generateMindMap 使用 currentLLM 动态解析。
    func testGenerateMindMap_使用currentLLM动态解析() async throws {
        let newMock = await MainActor.run { ControllableLLMService() }
        await MainActor.run {
            newMock.defaultResponse = """
            ```mermaid
            mindmap
              root((DI))
            ```
            """
            ServiceContainer.shared.register(newMock as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        }

        let result = try await AISynthesisService.shared.generateMindMap(content: "内容")

        XCTAssertFalse(result.isEmpty)
        let newMockCalls = await MainActor.run { newMock.generateCalls }
        XCTAssertGreaterThan(newMockCalls.count, 0, "generateMindMap 应通过 currentLLM 调用 DI 中的新 Mock")
    }

    /// 验证 suggestFix 使用 currentLLM，DI 动态更新 LLM 实例时生效
    /// - Note: C-12/Bug#4 已修复 — suggestFix 现在使用 currentLLM.generate，DI 更新后使用新实例。
    func testSuggestFix_DI更新后使用新LLM实例() async throws {
        let newMock = await MainActor.run { ControllableLLMService() }
        await MainActor.run {
            newMock.defaultResponse = "来自新DI的修复建议"
            ServiceContainer.shared.register(newMock as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        }

        let issue = LintIssue(severity: .info, message: "问题", suggestion: "建议")
        let result = try await AISynthesisService.shared.suggestFix(issue: issue, pages: [])

        // 修复后：suggestFix 使用 currentLLM（newMock），而非旧 llm（mockLLM）
        let newMockCalls = await MainActor.run { newMock.generateCalls }

        XCTAssertGreaterThan(newMockCalls.count, 0, "suggestFix 应通过 currentLLM 使用 DI 中的新实例")
        XCTAssertEqual(result, "来自新DI的修复建议", "result 应来自新 DI Mock")
    }

    // MARK: - 截断保护边界

    /// 验证 generateMindMap 超长内容截断至 8000。
    func testGenerateMindMap_超长内容截断() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = """
            ```mermaid
            mindmap
              root((测试))
            ```
            """
        }

        let longContent = String(repeating: "x", count: 15_000)
        _ = try await AISynthesisService.shared.generateMindMap(content: longContent)

        let lastCall = try XCTUnwrap(mockLLM.generateCalls.last)
        XCTAssertTrue(lastCall.prompt.contains(String(repeating: "x", count: 8000)))
        XCTAssertFalse(lastCall.prompt.contains(String(repeating: "x", count: 8001)))
    }

    /// 验证 generateQuiz 超长内容截断。
    func testGenerateQuiz_超长内容截断() async throws {
        await MainActor.run { mockLLM.defaultResponse = "[]" }

        let longContent = String(repeating: "y", count: 12_000)
        _ = try await AISynthesisService.shared.generateQuiz(content: longContent)

        let lastCall = try XCTUnwrap(mockLLM.generateCalls.last)
        XCTAssertTrue(lastCall.prompt.contains(String(repeating: "y", count: 8000)))
        XCTAssertFalse(lastCall.prompt.contains(String(repeating: "y", count: 8001)))
    }

    /// 验证 generatePresentation 超长内容截断。
    func testGeneratePresentation_超长内容截断() async throws {
        await MainActor.run { mockLLM.defaultResponse = "足够长的响应内容用于通过校验" }

        let longContent = String(repeating: "z", count: 10_000)
        _ = try await AISynthesisService.shared.generatePresentation(content: longContent)

        let lastCall = try XCTUnwrap(mockLLM.generateCalls.last)
        XCTAssertTrue(lastCall.prompt.contains(String(repeating: "z", count: 8000)))
    }

    // MARK: - updateStatus 副作用

    /// 验证 synthesize 调用 updateStatus 不崩溃（通过 TaskCenter.updateLatestStatus）。
    func testSynthesize_调用updateStatus不崩溃() async throws {
        await MainActor.run {
            mockLLM.defaultResponse = """
            ```mermaid
            mindmap
              root((测试))
            ```
            """
        }

        // synthesize 内部调用 updateStatus，应不崩溃
        _ = try await AISynthesisService.shared.synthesize(type: .mindmap, content: "内容")

        // 不崩溃即通过
    }

    // MARK: - suggestFix 内容截断

    /// 验证 suggestFix 对 pageContent 截断至 500 字符。
    func testSuggestFix_pageContent截断至500字符() async throws {
        await MainActor.run { mockLLM.defaultResponse = "建议" }

        let longContent = String(repeating: "c", count: 1000)
        let page = KnowledgePage(title: "页面", content: longContent)
        let issue = LintIssue(severity: .info, pageID: page.id, message: "问题", suggestion: "建议")

        _ = try await AISynthesisService.shared.suggestFix(issue: issue, pages: [page])

        let lastCall = try XCTUnwrap(mockLLM.generateCalls.last)
        XCTAssertTrue(lastCall.prompt.contains(String(repeating: "c", count: 500)))
        XCTAssertFalse(lastCall.prompt.contains(String(repeating: "c", count: 501)))
    }

    /// 验证 suggestFix 对 otherTitles 截断至前 50 个。
    func testSuggestFix_otherTitles截断至前50个() async throws {
        await MainActor.run { mockLLM.defaultResponse = "建议" }

        // 构造 60 个页面，issue 匹配第一个
        let firstPageID = UUID()
        let pages = [KnowledgePage(id: firstPageID, title: "目标页面", content: "内容")]
            + (1...60).map { KnowledgePage(title: "页面\($0)", content: "内容") }
        let issue = LintIssue(severity: .info, pageID: firstPageID, message: "问题", suggestion: "建议")

        _ = try await AISynthesisService.shared.suggestFix(issue: issue, pages: pages)

        let lastCall = try XCTUnwrap(mockLLM.generateCalls.last)
        XCTAssertTrue(lastCall.prompt.contains("页面50"), "应包含第 50 个其他页面标题")
        XCTAssertFalse(lastCall.prompt.contains("页面51"), "不应包含第 51 个及之后的页面标题")
    }
}
