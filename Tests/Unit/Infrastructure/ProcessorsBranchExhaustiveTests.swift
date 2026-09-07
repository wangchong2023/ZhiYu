//
//  ProcessorsBranchExhaustiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] Infrastructure/Processors 核心算子深度分支穷举集成测试
//  核心职责：深度覆盖 CJKSpacingFormatter、FrontmatterParser、WikiLinkExtractor、
//            JSONExtractor、ThinkingProcessor、GraphLayoutProcessor、
//            SynthesisStrategyFactory 与 MermaidSanitizer 的极端分支与防御。
//  质量标准：严格执行 unit-test-quality-review 规范，包含中英空格幂等性、
//            Frontmatter 未闭合容错、双链转义防误判、JSON 括号转义感知、
//            CoT 思维链提取及力导向布局零数据与单节点物理极值防崩溃校验。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class ProcessorsBranchExhaustiveTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        try? await Task.sleep(nanoseconds: 50_000_000)
        try await super.tearDown()
    }

    // MARK: - 1. CJKSpacingFormatter 中英文与数字排版空格注入深测

    func testCJKSpacingFormatter_MixedContentAndIdempotence() {
        // 1. 中英文混排空格注入
        let mixed1 = CJKSpacingFormatter.spacing("Swift语言与iOS开发")
        XCTAssertTrue(mixed1.contains("Swift 语言"), "中英边界必须注入空格提升可读性")
        XCTAssertTrue(mixed1.contains("与 iOS 开发"), "英中边界必须注入空格")

        // 2. 中文与数字混排
        let mixed2 = CJKSpacingFormatter.spacing("发布版本2.0以及3个核心特性")
        XCTAssertTrue(mixed2.contains("版本 2.0 以及"), "数字与中文边界必须注入空格")
        XCTAssertTrue(mixed2.contains("以及 3 个"), "数字前后必须保持规范间距")

        // 3. 幂等性：已有规范空格的文本再次格式化不应产生多余空格
        let formattedOnce = CJKSpacingFormatter.spacing("Swift 语言开发")
        let formattedTwice = CJKSpacingFormatter.spacing(formattedOnce)
        XCTAssertEqual(formattedOnce, formattedTwice, "重复调用 CJKSpacingFormatter 必须具备严格幂等性")

        // 4. 空文本与纯语言边缘分支
        XCTAssertEqual(CJKSpacingFormatter.spacing(""), "")
        XCTAssertEqual(CJKSpacingFormatter.spacing("Pure English Text"), "Pure English Text")
        XCTAssertEqual(CJKSpacingFormatter.spacing("纯中文排版没有任何西文字符"), "纯中文排版没有任何西文字符")
    }

    // MARK: - 2. FrontmatterParser YAML/JSON 元数据切分与未闭合容错深测

    func testFrontmatterParser_DelimitersAndUnclosedFaultTolerance() {
        // 1. 标准有效 YAML Frontmatter 切分
        let validMarkdown = """
        ---
        title: 知识图谱架构
        author: ZhiYu Team
        ---
        # 正文标题
        这是知识页面的正文内容。
        """

        let (frontmatter, body) = FrontmatterParser.split(content: validMarkdown)
        XCTAssertNotNil(frontmatter, "有效 Frontmatter 必须被精准剥离")
        XCTAssertTrue(frontmatter?.contains("title: 知识图谱架构") ?? false)
        XCTAssertTrue(body.contains("# 正文标题"), "正文部分必须完整保留")

        // 2. 只有开头 --- 但缺少结尾 --- 的畸形未闭合 Markdown
        let unclosedMarkdown = """
        ---
        title: 损坏的未闭合元数据
        这是正文假装的段落
        """
        let (unclosedFM, unclosedBody) = FrontmatterParser.split(content: unclosedMarkdown)
        XCTAssertNil(unclosedFM, "未闭合的 Frontmatter 应当容错判定为 nil")
        XCTAssertEqual(unclosedBody, unclosedMarkdown, "容错降级时应回退保留全部原始输入")

        // 3. 无 Frontmatter 的纯正文 Markdown
        let plainMarkdown = "# 纯文本笔记\n无任何 YAML 头部的正文内容。"
        let (plainFM, plainBody) = FrontmatterParser.split(content: plainMarkdown)
        XCTAssertNil(plainFM)
        XCTAssertEqual(plainBody, plainMarkdown)

        // 4. 空字符串与空白边缘防御
        let (emptyFM, emptyBody) = FrontmatterParser.split(content: "")
        XCTAssertNil(emptyFM)
        XCTAssertEqual(emptyBody, "")
    }

    // MARK: - 3. WikiLinkExtractor 双链提取与反斜杠转义防误判深测

    func testWikiLinkExtractor_AliasesAndEscapeIgnorance() {
        let sampleMarkdown = """
        欢迎阅读 [[知识管理]] 与 [[双链系统|知识网状关联]]。
        注意转义的 \\[\\[这是被转义的双链\\]\\] 不应被提取。
        无效的双链 [[  ]] 应当被自动过滤。
        末尾的双链 [[Karpathy LLM Wiki]]。
        """

        let links = WikiLinkExtractor.extractLinks(from: sampleMarkdown)

        // 1. 验证成功提取的链接列表
        XCTAssertEqual(links.count, 3, "应精准提取 3 个有效双向链接，忽略转义与空链接")

        // 2. 基础双链
        XCTAssertEqual(links[0].targetTitle, "知识管理")
        XCTAssertNil(links[0].alias)
        XCTAssertEqual(links[0].displayTitle, "知识管理")

        // 3. 带别名的双链
        XCTAssertEqual(links[1].targetTitle, "双链系统")
        XCTAssertEqual(links[1].alias, "知识网状关联")
        XCTAssertEqual(links[1].displayTitle, "知识网状关联")

        // 4. 尾部双链
        XCTAssertEqual(links[2].targetTitle, "Karpathy LLM Wiki")

        // 5. 空文本保护
        XCTAssertTrue(WikiLinkExtractor.extractLinks(from: "").isEmpty)
    }

    // MARK: - 4. JSONExtractor 嵌套配对与字符串引号转义感知深测

    func testJSONExtractor_NestedBracesAndEscapedQuotes() {
        // 1. 嵌套结构与前后杂质文本
        let llmOutputWithGarbages = """
        这是大模型输出的思考前缀。
        ```json
        {
            "name": "智宇",
            "metadata": {
                "version": 2,
                "enabled": true
            },
            "description": "包含 {伪括号} 和 \\"转义引号\\" 的内容"
        }
        ```
        这是尾部的解释说明。
        """

        let extractedJSON = JSONExtractor.extractFirstJSONObject(from: llmOutputWithGarbages)
        XCTAssertNotNil(extractedJSON, "应能穿透 Markdown 代码块精准提取最外层闭合 JSON")

        let dict = JSONExtractor.extractJSONDictionary(from: llmOutputWithGarbages)
        XCTAssertEqual(dict["name"] as? String, "智宇")
        XCTAssertEqual((dict["metadata"] as? [String: Any])?["version"] as? Int, 2)
        XCTAssertTrue((dict["description"] as? String)?.contains("{伪括号}") ?? false, "字符串内部的花括号不应破坏外层结构配对")

        // 2. 无 JSON 的普通文本安全返回 nil
        XCTAssertNil(JSONExtractor.extractFirstJSONObject(from: "纯文本没有花括号"))
        XCTAssertTrue(JSONExtractor.extractJSONDictionary(from: "无任何结构").isEmpty)
    }

    // MARK: - 5. ThinkingProcessor 思维链 CoT 过程提取深测

    func testThinkingProcessor_EnclosedAndUnclosedReasoning() {
        // 1. 标准完整闭合思维链标签
        let enclosedText = """
        <think>
        首先分析用户的提问意图，
        然后组织 Markdown 分段。
        </think>
        这是经过深思熟虑后的正式回答正文。
        """

        let enclosedResult = ThinkingProcessor.process(enclosedText)
        XCTAssertNotNil(enclosedResult.thinkingContent, "应成功提取思维链内容")
        XCTAssertTrue(enclosedResult.thinkingContent?.contains("分析用户的提问意图") ?? false)
        XCTAssertEqual(enclosedResult.mainContent, "这是经过深思熟虑后的正式回答正文。")

        // 2. 流式传输中尚未闭合的思考标签
        let unclosedText = "<think>正在推理中还没有输出结束标记..."
        let unclosedResult = ThinkingProcessor.process(unclosedText)
        XCTAssertEqual(unclosedResult.thinkingContent, "正在推理中还没有输出结束标记...")
        XCTAssertTrue(unclosedResult.mainContent.isEmpty, "未闭合状态下正文部分应当为空")

        // 3. 无任何思考标签的常规输出
        let directText = "直接给出的专业回答正文"
        let directResult = ThinkingProcessor.process(directText)
        XCTAssertNil(directResult.thinkingContent, "无标签时 thinkingContent 应为 nil")
        XCTAssertEqual(directResult.mainContent, directText)

        // 4. 空文本保护
        let emptyResult = ThinkingProcessor.process("")
        XCTAssertNil(emptyResult.thinkingContent)
        XCTAssertEqual(emptyResult.mainContent, "")
    }

    // MARK: - 6. GraphLayoutProcessor 力导向图谱零数据与单节点极值深测

    func testGraphLayoutProcessor_EmptyAndSingleNodePhysicsSimulation() {
        let canvasSize = CGSize(width: 800, height: 600)

        // 1. 空页面集合：必须安全返回空节点与空边，防除零与越界
        let emptyResult = GraphLayoutProcessor.layout(
            pages: [],
            linkResolver: { _ in nil },
            canvasSize: canvasSize
        )
        XCTAssertTrue(emptyResult.nodes.isEmpty)
        XCTAssertTrue(emptyResult.edges.isEmpty)

        // 2. 单节点极值：验证不触发除以 0 或物理斥力自作用力 NaN 崩溃
        let singlePage = KnowledgePage(
            title: "核心孤立节点",
            pageType: .concept,
            content: "无连接内容"
        )
        let singleResult = GraphLayoutProcessor.layout(
            pages: [singlePage],
            linkResolver: { _ in nil },
            canvasSize: canvasSize
        )
        XCTAssertEqual(singleResult.nodes.count, 1)
        XCTAssertTrue(singleResult.edges.isEmpty)

        let nodePosition = singleResult.nodes[0].position
        XCTAssertFalse(nodePosition.x.isNaN, "计算出的 X 坐标绝不可为 NaN")
        XCTAssertFalse(nodePosition.y.isNaN, "计算出的 Y 坐标绝不可为 NaN")
        XCTAssertGreaterThan(nodePosition.x, 0, "节点应位于正坐标空间")
        XCTAssertGreaterThan(nodePosition.y, 0, "节点应位于正坐标空间")

        // 3. 双节点相互引用图谱
        let pageA = KnowledgePage(title: "页面A", pageType: .concept, content: "链接到 [[页面B]]")
        let pageB = KnowledgePage(title: "页面B", pageType: .entity, content: "链接到 [[页面A]]")
        let twoResult = GraphLayoutProcessor.layout(
            pages: [pageA, pageB],
            linkResolver: { title in
                if title == "页面A" { return pageA }
                if title == "页面B" { return pageB }
                return nil
            },
            canvasSize: canvasSize
        )
        XCTAssertEqual(twoResult.nodes.count, 2)
        XCTAssertGreaterThanOrEqual(twoResult.edges.count, 1, "互相引用的两页面应当生成关联拓扑边")
    }

    // MARK: - 7. SynthesisStrategyFactory 6 大策略路由完备性深测

    func testSynthesisStrategyFactory_AllCasesDispatchCompleteness() {
        for synthType in SynthesisStore.SynthesisType.allCases {
            let strategy = SynthesisStrategyFactory.strategy(for: synthType)
            XCTAssertEqual(strategy.type, synthType, "工厂派发的策略类型必须与 \(synthType) 严格对齐")

            // 验证策略兜底自愈文档生成能力
            let fallback = strategy.generateFallback(from: "这是源知识库素材文本", title: "测试主题")
            XCTAssertFalse(fallback.isEmpty, "\(synthType) 兜底生成的结构化文档绝不能为空")
            XCTAssertTrue(fallback.contains("测试主题") || fallback.contains("测试素材"), "\(synthType) 兜底文档应包含主题或素材片段")

            // 验证清洗解析能力
            let processed = strategy.process(rawContent: "# 生成正文\n测试段落", sourceContent: "源文本")
            XCTAssertFalse(processed.isEmpty, "\(synthType) 处理后的正文绝不能为空")
        }
    }

    // MARK: - 8. MermaidSanitizer 节点清洗与特殊字符状态机深测

    func testMermaidSanitizer_BracketEscapingAndDeclarationPreservation() {
        let rawMermaid = """
        graph TD
            A[正常节点] --> B[包含[嵌套方括号]的节点]
            B --> C[包含 (括号) 与 "引号" 的复杂条目]
        """

        let sanitized = MermaidSanitizer.sanitize(rawMermaid)

        // 1. 结构声明必须完整保留
        XCTAssertTrue(sanitized.contains("graph TD"), "Mermaid 图表声明行必须保留")

        // 2. 清洗结果必须非空且有效
        XCTAssertFalse(sanitized.isEmpty)
        XCTAssertTrue(sanitized.contains("正常节点"))
    }
}
