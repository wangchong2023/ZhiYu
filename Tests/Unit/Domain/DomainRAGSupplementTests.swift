//
//  DomainRAGSupplementTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：补充验证 RAGEvaluationService 评估指标计算、AIContentEnricher
//           富化分支、SynthesisControlOptions 选项组合的未覆盖分支。
//

import XCTest
@testable import ZhiYu

@MainActor
final class DomainRAGSupplementTests: XCTestCase {

    // MARK: - SynthesisControlOptions.promptInstruction 全分支覆盖

    /// 验证 concise depth 的 promptInstruction 包含精简字数区间
    func testPromptInstructionConciseDepthContainsConciseWordRange() {
        let options = SynthesisControlOptions(depth: .concise)
        let instruction = options.promptInstruction
        XCTAssertFalse(instruction.isEmpty, "promptInstruction 不应为空")
        XCTAssertTrue(instruction.contains("\(PromptConstants.SynthesisWordCount.conciseMinWords)"), "应包含精简最小字数")
        XCTAssertTrue(instruction.contains("\(PromptConstants.SynthesisWordCount.conciseMaxWords)"), "应包含精简最大字数")
    }

    /// 验证 standard depth 的 promptInstruction 包含标准字数区间
    func testPromptInstructionStandardDepthContainsStandardWordRange() {
        let options = SynthesisControlOptions(depth: .standard)
        let instruction = options.promptInstruction
        XCTAssertFalse(instruction.isEmpty)
        XCTAssertTrue(instruction.contains("\(PromptConstants.SynthesisWordCount.standardMinWords)"))
        XCTAssertTrue(instruction.contains("\(PromptConstants.SynthesisWordCount.standardMaxWords)"))
    }

    /// 验证 detailed depth 的 promptInstruction 包含详尽字数区间
    func testPromptInstructionDetailedDepthContainsDetailedWordRange() {
        let options = SynthesisControlOptions(depth: .detailed)
        let instruction = options.promptInstruction
        XCTAssertFalse(instruction.isEmpty)
        XCTAssertTrue(instruction.contains("\(PromptConstants.SynthesisWordCount.detailedMinWords)"))
        XCTAssertTrue(instruction.contains("\(PromptConstants.SynthesisWordCount.detailedMaxWords)"))
    }

    /// 验证 beginner audience 的 promptInstruction 包含初学者指令
    func testPromptInstructionBeginnerAudienceContainsBeginnerInstruction() {
        let options = SynthesisControlOptions(audience: .beginner)
        let instruction = options.promptInstruction
        XCTAssertFalse(instruction.isEmpty)
    }

    /// 验证 professional audience 的 promptInstruction 包含专业用户指令
    func testPromptInstructionProfessionalAudienceContainsProfessionalInstruction() {
        let options = SynthesisControlOptions(audience: .professional)
        let instruction = options.promptInstruction
        XCTAssertFalse(instruction.isEmpty)
    }

    /// 验证 executive audience 的 promptInstruction 包含高管指令
    func testPromptInstructionExecutiveAudienceContainsExecutiveInstruction() {
        let options = SynthesisControlOptions(audience: .executive)
        let instruction = options.promptInstruction
        XCTAssertFalse(instruction.isEmpty)
    }

    /// 验证 academic tone 的 promptInstruction 包含学术风格指令
    func testPromptInstructionAcademicToneContainsAcademicStyleInstruction() {
        let options = SynthesisControlOptions(tone: .academic)
        let instruction = options.promptInstruction
        XCTAssertFalse(instruction.isEmpty)
    }

    /// 验证 professional tone 的 promptInstruction 包含专业风格指令
    func testPromptInstructionProfessionalToneContainsProfessionalStyleInstruction() {
        let options = SynthesisControlOptions(tone: .professional)
        let instruction = options.promptInstruction
        XCTAssertFalse(instruction.isEmpty)
    }

    /// 验证 casual tone 的 promptInstruction 包含休闲风格指令
    func testPromptInstructionCasualToneContainsCasualStyleInstruction() {
        let options = SynthesisControlOptions(tone: .casual)
        let instruction = options.promptInstruction
        XCTAssertFalse(instruction.isEmpty)
    }

    /// 验证 customPrompt 为空时不追加自定义指令
    func testPromptInstructionEmptyCustomPromptDoesNotAppendCustomInstruction() {
        let options = SynthesisControlOptions(customPrompt: "")
        let instruction = options.promptInstruction
        XCTAssertFalse(instruction.isEmpty)
    }

    /// 验证 customPrompt 非空时追加自定义指令
    func testPromptInstructionNonEmptyCustomPromptAppendsCustomInstruction() {
        let customText = "请特别关注量子计算部分"
        let options = SynthesisControlOptions(customPrompt: customText)
        let instruction = options.promptInstruction
        XCTAssertTrue(instruction.contains(customText), "应包含自定义指令文本")
    }

    /// 验证全组合（concise + beginner + academic + customPrompt）
    func testPromptInstructionFullCombinationConciseBeginnerAcademicWithCustom() {
        let options = SynthesisControlOptions(
            depth: .concise,
            audience: .beginner,
            tone: .academic,
            customPrompt: "附加要求"
        )
        let instruction = options.promptInstruction
        XCTAssertFalse(instruction.isEmpty)
        XCTAssertTrue(instruction.contains("附加要求"))
    }

    /// 验证全组合（detailed + executive + casual）
    func testPromptInstructionFullCombinationDetailedExecutiveCasual() {
        let options = SynthesisControlOptions(
            depth: .detailed,
            audience: .executive,
            tone: .casual
        )
        let instruction = options.promptInstruction
        XCTAssertFalse(instruction.isEmpty)
    }

    /// 验证默认选项的 promptInstruction 非空
    func testPromptInstructionDefaultOptionNonEmpty() {
        let options = SynthesisControlOptions()
        let instruction = options.promptInstruction
        XCTAssertFalse(instruction.isEmpty, "默认选项的 promptInstruction 不应为空")
    }

    // MARK: - AIContentEnricher 未覆盖分支

    /// 验证空内容富化直接返回空字符串
    func testAIContentEnricherEmptyContentDirectlyReturns() async {
        let mockLLM = MockLLMService()
        let enriched = await AIContentEnricher.shared.enrich("", llm: mockLLM)
        XCTAssertEqual(enriched, "", "空内容应直接返回空字符串")
    }

    /// 验证纯文本（无表格/图片标记）直接返回原内容
    func testAIContentEnricherPlainTextDirectlyReturns() async {
        let content = "这是一段纯文本，没有任何 Markdown 特殊语法。"
        let mockLLM = MockLLMService()
        let enriched = await AIContentEnricher.shared.enrich(content, llm: mockLLM)
        XCTAssertEqual(enriched, content, "纯文本应直接返回原内容")
    }

    /// 验证图片 alt 为空时不触发 LLM，直接返回图片 Markdown
    func testAIContentEnricherImageEmptyAltDoesNotTriggerLLM() async {
        let content = "![](https://example.com/image.png)"
        let mockLLM = MockLLMService()
        let llmCalled = MutableBox(false)
        mockLLM.generateHandler = { _, _ in
            llmCalled.value = true
            return "不应该被调用"
        }
        let enriched = await AIContentEnricher.shared.enrich(content, llm: mockLLM)
        XCTAssertTrue(enriched.contains("![](https://example.com/image.png)"), "应保留原图片 Markdown")
        XCTAssertFalse(llmCalled.value, "alt 为空时不应触发 LLM")
    }

    /// 验证表格 LLM 抛错时返回原表格
    func testAIContentEnricherTableLLMThrowsReturnsOriginalTable() async {
        let content = """
        | 列1 | 列2 |
        | --- | --- |
        | A | B |
        """
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in
            throw NSError(domain: "test", code: 1)
        }
        let enriched = await AIContentEnricher.shared.enrich(content, llm: mockLLM)
        XCTAssertTrue(enriched.contains("| 列1 | 列2 |"), "LLM 抛错时应返回原表格")
        XCTAssertTrue(enriched.contains("| A | B |"))
    }

    /// 验证图片 LLM 抛错时返回原图片 Markdown
    func testAIContentEnricherImageLLMThrowsReturnsOriginalImage() async {
        let content = "![描述](https://example.com/img.png)"
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in
            throw NSError(domain: "test", code: 1)
        }
        let enriched = await AIContentEnricher.shared.enrich(content, llm: mockLLM)
        XCTAssertTrue(enriched.contains("![描述](https://example.com/img.png)"), "LLM 抛错时应返回原图片 Markdown")
    }

    /// 验证表格后紧跟文本的块解析
    func testAIContentEnricherTableFollowedByTextCorrectChunking() async {
        let content = """
        | 表头 | 值 |
        | --- | --- |
        | A | 1 |

        表格后的正文内容。
        """
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in "增强洞察" }
        let enriched = await AIContentEnricher.shared.enrich(content, llm: mockLLM)
        XCTAssertTrue(enriched.contains("| 表头 | 值 |"), "应保留表格")
        XCTAssertTrue(enriched.contains("表格后的正文内容。"), "应保留表格后文本")
        XCTAssertTrue(enriched.contains("增强洞察"), "应包含 LLM 增强内容")
    }

    /// 验证多个图片的并行增强
    func testAIContentEnricherMultipleImagesParallelEnrichment() async {
        let content = """
        ![图片1](https://example.com/1.png)

        ![图片2](https://example.com/2.png)
        """
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in "图片描述" }
        let enriched = await AIContentEnricher.shared.enrich(content, llm: mockLLM)
        XCTAssertTrue(enriched.contains("![图片1](https://example.com/1.png)"))
        XCTAssertTrue(enriched.contains("![图片2](https://example.com/2.png)"))
    }

    /// 验证空图片占位符 `![]` 触发增强
    func testAIContentEnricherEmptyImagePlaceholderTriggersEnrichment() async {
        let content = "文本包含 ![] 占位符"
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in "增强内容" }
        let enriched = await AIContentEnricher.shared.enrich(content, llm: mockLLM)
        XCTAssertFalse(enriched.isEmpty)
    }

    // MARK: - RAGEvaluationService 未覆盖分支

    /// 验证 evaluate 无 sources 时走无源 Prompt 路径
    func testRAGEvaluationNoSourcesGoesNoSourcePromptPath() async {
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in
            """
            {"faithfulness": 0.9, "relevance": 0.8, "context_precision": 0.7, "hallucination_rate": 0.1, "citation_accuracy": 0.85}
            """
        }
        let governanceStore = NoOpRAGGovernanceRepository()
        let service = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceStore)
        let report = await service.evaluate(query: "测试问题", answer: "测试回答", context: "测试上下文", sources: nil)
        XCTAssertEqual(report.query, "测试问题")
        XCTAssertEqual(report.answer, "测试回答")
        XCTAssertEqual(report.faithfulness, 0.9, accuracy: 0.01)
        XCTAssertEqual(report.relevance, 0.8, accuracy: 0.01)
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.pass)
    }

    /// 验证 evaluate 有 sources 时走含源 Prompt 路径
    func testRAGEvaluationWithSourcesGoesWithSourcePromptPath() async {
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in
            """
            {"faithfulness": 0.6, "relevance": 0.5, "context_precision": 0.4, "hallucination_rate": 0.3, "citation_accuracy": 0.5, "relevance_scores": [2, 1, 0]}
            """
        }
        let governanceStore = NoOpRAGGovernanceRepository()
        let service = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceStore)
        let sources = [
            KnowledgeSource(pageID: UUID(), title: "源1", snippet: "片段1", score: 0.9),
            KnowledgeSource(pageID: UUID(), title: "源2", snippet: "片段2", score: 0.6),
            KnowledgeSource(pageID: UUID(), title: "源3", snippet: "片段3", score: 0.3)
        ]
        let report = await service.evaluate(query: "问题", answer: "回答", context: "上下文", sources: sources)
        XCTAssertEqual(report.faithfulness, 0.6, accuracy: 0.01)
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.warning)
    }

    /// 验证 evaluate LLM 抛错时返回零指标 error 报告
    func testRAGEvaluationLLMThrowsReturnsZeroMetricsErrorReport() async {
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in
            throw NSError(domain: "test", code: 1)
        }
        let governanceStore = NoOpRAGGovernanceRepository()
        let service = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceStore)
        let report = await service.evaluate(query: "问题", answer: "回答", context: "上下文")
        XCTAssertEqual(report.faithfulness, 0)
        XCTAssertEqual(report.relevance, 0)
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.error)
    }

    /// 验证 evaluate LLM 返回无效 JSON 时返回零指标 error 报告
    func testRAGEvaluationInvalidJSONReturnsZeroMetricsErrorReport() async {
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in "这不是 JSON" }
        let governanceStore = NoOpRAGGovernanceRepository()
        let service = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceStore)
        let report = await service.evaluate(query: "问题", answer: "回答", context: "上下文")
        XCTAssertEqual(report.faithfulness, 0)
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.error)
    }

    /// 验证 evaluate LLM 返回缺失字段 JSON 时默认 0.0
    func testRAGEvaluationMissingFieldJSONDefaultsToZero() async {
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in
            "{\"faithfulness\": 0.85}"
        }
        let governanceStore = NoOpRAGGovernanceRepository()
        let service = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceStore)
        let report = await service.evaluate(query: "问题", answer: "回答", context: "上下文")
        XCTAssertEqual(report.faithfulness, 0.85, accuracy: 0.01)
        XCTAssertEqual(report.relevance, 0, "缺失字段应默认 0")
        XCTAssertEqual(report.precision, 0)
        XCTAssertEqual(report.hallucinationRate, 0)
        XCTAssertEqual(report.citationAccuracy, 0)
    }

    /// 验证 evaluate 忠实度 < 0.5 时状态为 fail
    func testRAGEvaluationFaithfulnessBelow0_5StatusIsFail() async {
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in
            "{\"faithfulness\": 0.3, \"relevance\": 0.8, \"context_precision\": 0.7, \"hallucination_rate\": 0.1, \"citation_accuracy\": 0.85}"
        }
        let governanceStore = NoOpRAGGovernanceRepository()
        let service = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceStore)
        let report = await service.evaluate(query: "问题", answer: "回答", context: "上下文")
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.fail)
    }

    /// 验证 evaluate 忠实度 0.5-0.7 时状态为 warning
    func testRAGEvaluationFaithfulness0_5To0_7StatusIsWarning() async {
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in
            "{\"faithfulness\": 0.6, \"relevance\": 0.8, \"context_precision\": 0.7, \"hallucination_rate\": 0.1, \"citation_accuracy\": 0.85}"
        }
        let governanceStore = NoOpRAGGovernanceRepository()
        let service = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceStore)
        let report = await service.evaluate(query: "问题", answer: "回答", context: "上下文")
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.warning)
    }

    /// 验证 evaluate 忠实度 >= 0.7 时状态为 pass
    func testRAGEvaluationFaithfulnessAbove0_7StatusIsPass() async {
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in
            "{\"faithfulness\": 0.85, \"relevance\": 0.8, \"context_precision\": 0.7, \"hallucination_rate\": 0.1, \"citation_accuracy\": 0.85}"
        }
        let governanceStore = NoOpRAGGovernanceRepository()
        let service = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceStore)
        let report = await service.evaluate(query: "问题", answer: "回答", context: "上下文")
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.pass)
    }

    /// 验证 evaluate 空 sources 数组走无源路径
    func testRAGEvaluationEmptySourcesArrayGoesNoSourcePath() async {
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in
            "{\"faithfulness\": 0.9, \"relevance\": 0.8, \"context_precision\": 0.7, \"hallucination_rate\": 0.1, \"citation_accuracy\": 0.85}"
        }
        let governanceStore = NoOpRAGGovernanceRepository()
        let service = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceStore)
        let report = await service.evaluate(query: "问题", answer: "回答", context: "上下文", sources: [])
        XCTAssertEqual(report.faithfulness, 0.9, accuracy: 0.01)
        XCTAssertEqual(report.status, L10n.AI.Eval.Status.pass)
    }

    /// 验证 evaluate 有 sources 但无 relevance_scores 时走启发式标注
    func testRAGEvaluationWithSourcesNoRelevanceScoresGoesHeuristicAnnotation() async {
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in
            "{\"faithfulness\": 0.85, \"relevance\": 0.8, \"context_precision\": 0.7, \"hallucination_rate\": 0.1, \"citation_accuracy\": 0.85}"
        }
        let governanceStore = NoOpRAGGovernanceRepository()
        let service = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceStore)
        let sources = [
            KnowledgeSource(pageID: UUID(), title: "高相关", snippet: "片段", score: 0.9),
            KnowledgeSource(pageID: UUID(), title: "中相关", snippet: "片段", score: 0.6),
            KnowledgeSource(pageID: UUID(), title: "低相关", snippet: "片段", score: 0.2)
        ]
        let report = await service.evaluate(query: "问题", answer: "回答", context: "上下文", sources: sources)
        XCTAssertEqual(report.faithfulness, 0.85, accuracy: 0.01)
    }

    /// 验证 evaluate 有 sources 且有 relevance_scores 时走 LLM 标注
    func testRAGEvaluationWithSourcesWithRelevanceScoresGoesLLMAnnotation() async {
        let mockLLM = MockLLMService()
        mockLLM.generateHandler = { _, _ in
            "{\"faithfulness\": 0.85, \"relevance\": 0.8, \"context_precision\": 0.7, \"hallucination_rate\": 0.1, \"citation_accuracy\": 0.85, \"relevance_scores\": [2, 1, 0]}"
        }
        let governanceStore = NoOpRAGGovernanceRepository()
        let service = RAGEvaluationService(llmService: mockLLM, governanceStore: governanceStore)
        let sources = [
            KnowledgeSource(pageID: UUID(), title: "源1", snippet: "片段1", score: 0.9),
            KnowledgeSource(pageID: UUID(), title: "源2", snippet: "片段2", score: 0.5),
            KnowledgeSource(pageID: UUID(), title: "源3", snippet: "片段3", score: 0.1)
        ]
        let report = await service.evaluate(query: "问题", answer: "回答", context: "上下文", sources: sources)
        XCTAssertEqual(report.faithfulness, 0.85, accuracy: 0.01)
    }

    /// 验证 EvaluationReport 的 Identifiable
    func testEvaluationReportIdentifiableHasUniqueID() {
        let report1 = EvaluationReport(
            query: "q1", answer: "a1",
            faithfulness: 0.9, relevance: 0.8, precision: 0.7,
            hallucinationRate: 0.1, citationAccuracy: 0.85,
            status: "Pass"
        )
        let report2 = EvaluationReport(
            query: "q2", answer: "a2",
            faithfulness: 0.5, relevance: 0.4, precision: 0.3,
            hallucinationRate: 0.5, citationAccuracy: 0.5,
            status: "Warning"
        )
        XCTAssertNotEqual(report1.id, report2.id, "两个 EvaluationReport 的 ID 应不同")
    }

    // MARK: - RAGEvalConstants 常量验证

    /// 验证 RAGEvalConstants 启发式相关性阈值
    func testRAGEvalConstantsHeuristicRelevanceThreshold() {
        XCTAssertEqual(RAGEvalConstants.HeuristicRelevance.highThreshold, 0.8)
        XCTAssertEqual(RAGEvalConstants.HeuristicRelevance.mediumThreshold, 0.5)
    }

    /// 验证 RAGEvalConstants 忠实度状态阈值
    func testRAGEvalConstantsFaithfulnessStatusThreshold() {
        XCTAssertEqual(RAGEvalConstants.FaithfulnessStatus.failThreshold, 0.5)
        XCTAssertEqual(RAGEvalConstants.FaithfulnessStatus.warningThreshold, 0.7)
    }

    /// 验证 RAGEvalConstants 评判 Prompt 截断长度
    func testRAGEvalConstantsJudgePromptTruncationLength() {
        XCTAssertEqual(RAGEvalConstants.JudgePrompt.maxSources, 20)
        XCTAssertEqual(RAGEvalConstants.JudgePrompt.sourceSnippetPrefix, 150)
        XCTAssertEqual(RAGEvalConstants.JudgePrompt.contextPrefix, 3000)
    }

    /// 验证 RAGEvalConstants 快照 snippet 前缀长度
    func testRAGEvalConstantsSnapshotSnippetPrefixLength() {
        XCTAssertEqual(RAGEvalConstants.snapshotSnippetPrefix, 200)
    }
}
