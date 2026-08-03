//
//  SynthesisProcessorTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 SynthesisProcessor 的 Mermaid 格式化、标题提取、Markdown 清理等功能开展单元测试。
//

import XCTest
@testable import ZhiYu

final class SynthesisProcessorTests: XCTestCase {

    // MARK: - formatMermaid

    func testFormatMermaid_mindmap() {
        let input = "mindmap\n  Root\n    A\n    B"
        let result = SynthesisProcessor.formatMermaid(input, fallbackPrefix: "graph TD")
        XCTAssertTrue(result.hasPrefix("mindmap"))
        XCTAssertTrue(result.contains("Root"))
        XCTAssertTrue(result.contains("A"))
        XCTAssertTrue(result.contains("B"))
    }

    func testFormatMermaid_mindmap_withFence() {
        let input = "```mermaid\nmindmap\n  Root\n    Child\n```"
        let result = SynthesisProcessor.formatMermaid(input, fallbackPrefix: "graph TD")
        XCTAssertTrue(result.hasPrefix("mindmap"))
        XCTAssertTrue(result.contains("Child"))
    }

    func testFormatMermaid_graphTD() {
        let input = "graph TD\n  A-->B\n  B-->C"
        let result = SynthesisProcessor.formatMermaid(input, fallbackPrefix: "graph TD")
        XCTAssertTrue(result.contains("graph TD"))
        XCTAssertTrue(result.contains("A-->B"))
    }

    func testFormatMermaid_noPattern_usesFallback() {
        let input = "some random text"
        let result = SynthesisProcessor.formatMermaid(input, fallbackPrefix: "graph TD")
        XCTAssertTrue(result.contains("graph TD"))
    }

    func testFormatMermaid_bareGraphKeyword_isBlockedAsEmpty() {
        let input = "graph"
        let result = SynthesisProcessor.formatMermaid(input, fallbackPrefix: "graph TD")
        XCTAssertEqual(result, "", "裸关键字 'graph' 无有效节点，必须被拦截返回空字符串")
    }

    func testFormatMermaid_preservesTitle() {
        let input = "# My Diagram\nmindmap\n  Root"
        let result = SynthesisProcessor.formatMermaid(input, fallbackPrefix: "graph TD")
        XCTAssertTrue(result.hasPrefix("# My Diagram"))
        XCTAssertTrue(result.contains("mindmap"))
    }

    func testFormatMermaid_timeline() {
        let input = "timeline\n  title History\n  2020: Event"
        let result = SynthesisProcessor.formatMermaid(input, fallbackPrefix: "graph TD")
        XCTAssertTrue(result.contains("timeline"))
        XCTAssertTrue(result.contains("Event"))
    }

    // MARK: - extractTitle

    func testExtractTitle_firstH1() {
        let content = "# Main Title\n\nSome content"
        let result = SynthesisProcessor.extractTitle(from: content)
        XCTAssertEqual(result, "Main Title")
    }

    func testExtractTitle_ignoresH2() {
        let content = "## Not H1\n\n# Real Title"
        let result = SynthesisProcessor.extractTitle(from: content)
        XCTAssertEqual(result, "Real Title")
    }

    func testExtractTitle_noHeader_returnsNil() {
        let content = "plain text without headers"
        let result = SynthesisProcessor.extractTitle(from: content)
        XCTAssertNil(result)
    }

    func testExtractTitle_emptyContent_returnsNil() {
        let result = SynthesisProcessor.extractTitle(from: "")
        XCTAssertNil(result)
    }

    func testExtractTitle_stripsCodeFence() {
        let content = "# Title ```\nmore content"
        let result = SynthesisProcessor.extractTitle(from: content)
        XCTAssertEqual(result, "Title")
    }

    func testExtractTitle_multipleH1_takesFirst() {
        let content = "# First\n\n# Second"
        let result = SynthesisProcessor.extractTitle(from: content)
        XCTAssertEqual(result, "First")
    }

    func testExtractTitle_h1WithExtraHashSigns() {
        let content = "## H2\n#  H1 with space"
        let result = SynthesisProcessor.extractTitle(from: content)
        XCTAssertEqual(result, "H1 with space")
    }

    // MARK: - cleanMarkdown

    func testCleanMarkdown_escapedPlus() {
        let result = SynthesisProcessor.cleanMarkdown("list\\+item")
        XCTAssertEqual(result, "list+item")
    }

    func testCleanMarkdown_escapedMinus() {
        let result = SynthesisProcessor.cleanMarkdown("\\- item")
        XCTAssertEqual(result, "- item")
    }

    func testCleanMarkdown_escapedAsterisk() {
        let result = SynthesisProcessor.cleanMarkdown("\\*bold\\*")
        XCTAssertEqual(result, "*bold*")
    }

    func testCleanMarkdown_escapedBrackets() {
        let result = SynthesisProcessor.cleanMarkdown("\\[\\[link\\]\\]")
        XCTAssertEqual(result, "[[link]]")
    }

    func testCleanMarkdown_noEscapes_unmodified() {
        let input = "plain text"
        let result = SynthesisProcessor.cleanMarkdown(input)
        XCTAssertEqual(result, input)
    }

    func testCleanMarkdown_trimWhitespace() {
        let result = SynthesisProcessor.cleanMarkdown("  hello  ")
        XCTAssertEqual(result, "hello")
    }

    func testCleanMarkdown_combinedEscapes() {
        let result = SynthesisProcessor.cleanMarkdown("\\+ \\- \\* \\. ")
        XCTAssertEqual(result, "+ - * .")
    }

    func testCleanMarkdown_emptyString() {
        let result = SynthesisProcessor.cleanMarkdown("")
        XCTAssertEqual(result, "")
    }

    // MARK: - QuizProcessor Parse Tests

    func testQuizProcessor_parseRawJSON() {
        let json = """
        {"title":"测试测验","questions":[{"id":1,"text":"1+1=?","options":["1","2","3","4"],"answer":1,"explanation":"基础数学"}]}
        """
        let model = QuizProcessor.parseToQuizModel(json)
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.title, "测试测验")
        XCTAssertEqual(model?.questions.count, 1)
        XCTAssertEqual(model?.questions.first?.text, "1+1=?")
    }

    func testQuizProcessor_parseFlexibleJSONWithStringsAndFences() {
        // 变异情况：answer 为字符串 "0"、id 为字符串 "q1" 且带有 Markdown 代码围栏
        let mutatedJSON = """
        ```json
        {
          "title": "知识测验",
          "questions": [
            {
              "id": "q1",
              "text": "在知识图谱中，词条“神经元”通常与哪个主题相关联？",
              "options": ["脑科学", "信息茧房", "双脑协同", "卡片盒笔记法"],
              "answer": "0",
              "explanation": "根据词条：什么是神经元..."
            }
          ]
        }
        ```
        """
        let model = QuizProcessor.parseToQuizModel(mutatedJSON)
        XCTAssertNotNil(model, "包含字符串类型 answer/id 的变异 JSON 必须被 100% 成功解码")
        XCTAssertEqual(model?.title, "知识测验")
        XCTAssertEqual(model?.questions.count, 1)
        // randomizeQuizAnswers 会洗牌选项导致 answer 索引变化，
        // 验证 answer 在合法范围内且指向正确答案文本（"脑科学"），而非固定索引
        guard let question = model?.questions.first else {
            XCTFail("题目不应为空"); return
        }
        XCTAssertGreaterThanOrEqual(question.answer, 0, "answer 索引应 ≥ 0")
        XCTAssertLessThan(question.answer, question.options.count, "answer 索引应 < options 数量")
        XCTAssertEqual(question.options[question.answer], "脑科学", "字符串 '0' 必须被柔性自愈解码，洗牌后仍指向正确答案文本")
    }

    func testQuizProcessor_parseMarkdownQuiz() {
        let markdown = """
        # 知识评估

        ## 1. 深度学习的基础单元是什么？
        * A. 神经元
        * B. 过滤器
        * C. 卷积层
        * D. 激活函数
        **正确答案:** A
        **解析:** 神经元是人工神经网络的核心构建单元。
        """
        let model = QuizProcessor.parseToQuizModel(markdown)
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.title, "知识评估")
        XCTAssertEqual(model?.questions.count, 1)
        XCTAssertEqual(model?.questions.first?.options.count, 4)
    }

    func testQuizProcessor_parseInvalidInputReturnsNil() {
        let invalidText = "这是一段普通随笔，没有任何题目"
        let model = QuizProcessor.parseToQuizModel(invalidText)
        XCTAssertNil(model)
    }

    func testQuizProcessor_emptyAndCorruptedInput() {
        XCTAssertNil(QuizProcessor.parseToQuizModel(""))
        XCTAssertNil(QuizProcessor.parseToQuizModel("{}"))
        XCTAssertNil(QuizProcessor.parseToQuizModel("```json\n{}\n```"))
    }

    func testQuizProcessor_markdownMissingAnswerIndex_fallbackToFirstOption() {
        let markdown = """
        # 补全测试
        1. 没有显示正确答案标记的题目
        - 选项一
        - 选项二
        """
        let model = QuizProcessor.parseToQuizModel(markdown)
        XCTAssertNotNil(model)
        // randomizeQuizAnswers 会洗牌选项，fallback 答案（"选项一"）的索引会变化，
        // 验证 answer 在合法范围内且指向 fallback 答案文本，而非固定索引 0
        guard let question = model?.questions.first else {
            XCTFail("题目不应为空"); return
        }
        XCTAssertGreaterThanOrEqual(question.answer, 0, "answer 索引应 ≥ 0")
        XCTAssertLessThan(question.answer, question.options.count, "answer 索引应 < options 数量")
        XCTAssertEqual(question.options[question.answer], "选项一", "缺失答案标记时应 fallback 到第一个选项，洗牌后仍指向该选项文本")
    }

    // MARK: - Slides Splitting Tests

    func testSlidesSplitting_multipleSections() {
        let content = """
        # 第一页
        正文一
        ---
        # 第二页
        正文二
        ---
        # 第三页
        正文三
        """
        let slides = content.components(separatedBy: "\n---")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        XCTAssertEqual(slides.count, 3)
        XCTAssertTrue(slides[0].contains("第一页"))
        XCTAssertTrue(slides[1].contains("第二页"))
        XCTAssertTrue(slides[2].contains("第三页"))
    }

    // MARK: - 观测点断言 (Metrics & Inspection Assertions)

    func testFormatMermaid_preventsSkeleton7BAnd8BOutputs() {
        // 观测点 1: 验证空文本输出被拦截为 ""，绝对不能返回纯 7B 的 "mindmap" 或 8B 的 "graph TD"
        let emptyResultMindmap = SynthesisProcessor.formatMermaid("", fallbackPrefix: "mindmap")
        XCTAssertEqual(emptyResultMindmap, "", "空文本生成时 formatMermaid 必须返回空字符串拦截，防止出现 7B 'mindmap' 假存盘")

        let emptyResultGraph = SynthesisProcessor.formatMermaid("", fallbackPrefix: "graph TD")
        XCTAssertEqual(emptyResultGraph, "", "空文本生成时 formatMermaid 必须返回空字符串拦截，防止出现 8B 'graph TD' 假存盘")

        // 观测点 2: 验证仅包含关键字的文本也被拦截
        let bareMindmap = SynthesisProcessor.formatMermaid("mindmap", fallbackPrefix: "mindmap")
        XCTAssertEqual(bareMindmap, "")

        let bareGraph = SynthesisProcessor.formatMermaid("graph TD", fallbackPrefix: "graph TD")
        XCTAssertEqual(bareGraph, "")
    }

    func testSynthesisContentMinimumByteSizeObservationPoint() {
        // 观测点 3: 验证有效的生成内容必须具有最小正文长度
        let validMindmapCode = "mindmap\n  root((主题))\n    节点A"
        let formatted = SynthesisProcessor.formatMermaid(validMindmapCode, fallbackPrefix: "mindmap")
        XCTAssertGreaterThanOrEqual(formatted.utf8.count, AppConstants.ExportLimits.minValidSynthesisTextBytes, "有效思维导图输出字节数必须满足 AppConstants.ExportLimits 限制")
    }

    // MARK: - 内容正确性观测点断言 (Semantic Correctness Observation Points)

    func testMindmapSemanticCorrectnessObservationPoint() {
        let sampleOutput = """
        # 知识涌现架构图
        mindmap
          root((知识库核心))
            原子笔记
            深度合成
        """
        let formatted = SynthesisProcessor.formatMermaid(sampleOutput, fallbackPrefix: "mindmap")
        XCTAssertTrue(formatted.contains("mindmap"), "思维导图必须包含 mindmap 声明")
        XCTAssertTrue(formatted.contains("root((") || formatted.contains("知识库核心"), "思维导图必须包含根节点定义")
        XCTAssertTrue(formatted.contains("原子笔记"), "思维导图必须包含有效的具体节点内容")
    }

    func testInfographicSemanticCorrectnessObservationPoint() {
        let sampleOutput = """
        # RAG 管道流程
        graph TD
          A[文档输入] --> B[语义分块]
          B --> C[向量存储]
        """
        let formatted = SynthesisProcessor.formatMermaid(sampleOutput, fallbackPrefix: "graph TD")
        XCTAssertTrue(formatted.contains("graph TD"), "信息图表必须包含 graph TD 架构图头")
        XCTAssertTrue(formatted.contains("-->"), "信息图表必须包含节点间的连接箭头关系")
        XCTAssertTrue(formatted.contains("文档输入") && formatted.contains("向量存储"), "信息图表必须包含完整的内容节点")
    }

    func testQuizSemanticCorrectnessObservationPoint() {
        let sampleQuizJSON = """
        {
          "title": "RAG 系统架构测试",
          "questions": [
            {
              "id": 1,
              "text": "以下哪个属于向量数据库检索技术？",
              "options": ["HNSW 索引", "B-Tree 索引", "Hash 索引", "顺序扫描"],
              "answer": 0,
              "explanation": "HNSW 是常用的高维向量近似最近邻搜索算法。"
            }
          ]
        }
        """
        let model = QuizProcessor.parseToQuizModel(sampleQuizJSON)
        XCTAssertNotNil(model, "测验文档必须成功解析为 QuizModel")
        XCTAssertEqual(model?.questions.count, 1, "测验题数目必须满足预期的数量 (>=1)")
        
        if let question = model?.questions.first {
            XCTAssertGreaterThanOrEqual(question.options.count, 2, "题目备选项必须 >= 2 个")
            XCTAssertTrue(question.answer >= 0 && question.answer < question.options.count, "正确答案索引必须在有效选项数组范围内")
            XCTAssertFalse(question.text.isEmpty, "题目正文不能为空")
        }
    }

    func testSlidesSemanticCorrectnessObservationPoint() {
        let sampleSlidesMarkdown = """
        # 智宇 RAG 闭环设计
        面向 iOS/macOS 的 AI 原生知识管理
        ---
        ## 核心架构
        * 向量与 FTS5 混合检索
        * AI 深度合成实验室
        ---
        ## 总结
        闭环自动化研发
        """
        let slides = sampleSlidesMarkdown.components(separatedBy: "\n---")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        XCTAssertEqual(slides.count, 3, "演示文稿必须按 --- 规范精准分隔为 3 页 Slide")
        for (idx, slide) in slides.enumerated() {
            XCTAssertFalse(slide.isEmpty, "第 \(idx + 1) 页幻灯片内容不能为空")
            XCTAssertTrue(slide.contains("#"), "每一页幻灯片必须包含标示主题的标题指令")
        }
    }

    func testPerformSynthesis_WhenLLMOutputIsEmpty_SelfHealsToValidMarkdown() {
        // Given: LLM 输出为空或仅包含 Chat 杂质
        let emptyLLMOutput = "Here is the result:"
        let sourceContent = "智宇是一款 AI 原生知识管理应用，基于 LLM Wiki 方法论构建。"

        // When: 通过 SynthesisStrategyFactory 选取 Report 策略处理
        let strategy = SynthesisStrategyFactory.strategy(for: .report)
        let healedResult = strategy.process(rawContent: emptyLLMOutput, sourceContent: sourceContent)

        // Then: 必须自愈为符合结构的合法 Markdown，且字节数达到安全底线
        XCTAssertGreaterThanOrEqual(healedResult.utf8.count, AppConstants.ExportLimits.minValidSynthesisTextBytes, "空输出必须柔性降级自愈为达到有效字节数的 Markdown")
        XCTAssertTrue(healedResult.contains("# "), "自愈产物必须包含一级标题")
    }

    // MARK: - NotebookLM Custom Prompt & Multi-Language Tests

    func testSynthesisControlOptions_CustomPromptAndDefaultValues() {
        let options = SynthesisControlOptions()
        XCTAssertEqual(options.depth, .standard, "默认深度应为 standard")
        XCTAssertEqual(options.audience, .professional, "默认受众应为 professional")
        XCTAssertEqual(options.tone, .professional, "默认语气应为 professional")
        XCTAssertEqual(options.customPrompt, "", "默认自定义提示语应为空")

        let customized = SynthesisControlOptions(depth: .detailed, audience: .executive, tone: .academic, customPrompt: "包含分布式与多终端同步场景")
        XCTAssertEqual(customized.depth, .detailed)
        XCTAssertEqual(customized.audience, .executive)
        XCTAssertEqual(customized.tone, .academic)
        XCTAssertEqual(customized.customPrompt, "包含分布式与多终端同步场景")
    }

    func testSynthesisType_CustomPromptPlaceholders_DifferentiatedAndNonEmpty() {
        let allTypes = SynthesisStore.SynthesisType.allCases
        var placeholders = Set<String>()

        for type in allTypes {
            let placeholder = type.customPromptPlaceholder
            XCTAssertFalse(placeholder.isEmpty, "\(type) 的定制提示语占位符不能为空")
            placeholders.insert(placeholder)
        }

        XCTAssertEqual(placeholders.count, allTypes.count, "6 大合成卡片必须拥有各自独立的差异化 Prompt 占位引导文案")
    }

    // MARK: - Mermaid 语法解析与非 Mermaid 纯文本打拦截断言

    func testIsValidMermaidSyntax_validMindmap_returnsTrue() {
        let validCode = """
        mindmap
          root((思维导图))
            节点1
            节点2
        """
        XCTAssertTrue(SynthesisProcessor.isValidMermaidSyntax(validCode), "合法的 Mermaid mindmap 代码必须通过语法校验")
    }

    func testIsValidMermaidSyntax_invalidRawMockText_returnsFalse() {
        let rawMockText = "这是针对 UI 测试的非流式 Mock 大模型回复内容。"
        XCTAssertFalse(SynthesisProcessor.isValidMermaidSyntax(rawMockText), "非 Mermaid 结构的普通 Mock 文本必须判定为语法无效，防止引发解析崩溃")
    }

    func testFormatMermaid_invalidBareKeywords_failsValidation() {
        let bareKeywords = ["mindmap", "graph TD", "graph"]
        for kw in bareKeywords {
            let formatted = SynthesisProcessor.formatMermaid(kw, fallbackPrefix: "graph TD")
            XCTAssertFalse(SynthesisProcessor.isValidMermaidSyntax(formatted), "仅含裸关键字 '\(kw)' 的格式化结果必须被判定为无效图表")
        }
    }
}
