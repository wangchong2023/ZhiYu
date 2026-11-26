//
//  MarkdownAndThinkingRegressionTests.swift
//  ZhiYuDomainTests
//
//  Created by Antigravity on 2026/11/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：以发现缺陷为目的，覆盖 ThinkingProcessor（大小写未闭合、空前缀、隐式 CoT、分隔符拆分）、
//           MarkdownProcessor+BlockParsing（未闭合代码块越界、嵌套子列表吞行、表格负数单元格误滤、
//           details/taskList/table/heading/blockquote 边界）与核心领域模型 Codable 契约。
//

import XCTest
@testable import ZhiYuDomain

final class MarkdownAndThinkingRegressionTests: XCTestCase {

    // MARK: - 1. ThinkingProcessor 缺陷回归与边界对抗

    /// 回归测试：流式大写未闭合 `<THINK>` 标签必须被识别，禁止将思考过程泄露为正文
    func testThinkingProcessorRecognizesUppercaseUnclosedTag() {
        let result = ThinkingProcessor.process("<THINK>正在分析用户的深层意图...")
        XCTAssertEqual(result.thinkingContent, "正在分析用户的深层意图...")
        XCTAssertEqual(result.mainContent, "", "未闭合思考标签不应泄露到 mainContent")
    }

    /// 回归测试：仅有思考前缀无内容时，thinkingContent 必须返回 nil（与契约一致），不得返回空串
    func testThinkingProcessorEmptyPrefixReturnsNilThinking() {
        let result = ThinkingProcessor.process("Thinking:    \n   ")
        XCTAssertNil(result.thinkingContent, "空白思考内容应归一化为 nil")
        XCTAssertEqual(result.mainContent, "")
    }

    /// 验证前缀式思考配合双换行/关键词分隔符正确拆分 thinking 与 main
    func testThinkingProcessorPrefixWithDividerAndImplicitCoT() {
        let prefixWithAnswer = "Thinking: 先分析步骤一，再核对事实。\n\n最终结论是 42。"
        let res1 = ThinkingProcessor.process(prefixWithAnswer)
        XCTAssertEqual(res1.thinkingContent, "先分析步骤一，再核对事实。")
        XCTAssertEqual(res1.mainContent, "最终结论是 42。")

        // 含隐式思维链前缀 + 关键词分隔符
        let implicitPrefix = ProcessorConstants.Thinking.implicitCoTWeAreAsked
        let dividerKeyword = ProcessorConstants.Thinking.dividerSuggestion
        let implicitCoT = "\(implicitPrefix)分析这个架构问题。\(dividerKeyword)采用严格单向分层。"
        let res2 = ThinkingProcessor.process(implicitCoT)
        XCTAssertEqual(res2.thinkingContent, "\(implicitPrefix)分析这个架构问题。")
        XCTAssertEqual(res2.mainContent, "建议采用严格单向分层。")

        // 直接测试 splitAtDivider 与 makeResult 边界
        let sample = "   思考过程  \n\n  正式回答  "
        if let divider = sample.range(of: "\n\n") {
            let split = ThinkingProcessor.splitAtDivider(sample, dividerRange: divider)
            XCTAssertEqual(split.thinking, "思考过程")
            XCTAssertEqual(split.main, "正式回答")
        } else {
            XCTFail("应定位到双换行分隔符")
        }
        XCTAssertNil(ThinkingProcessor.makeResult(thinking: "", main: "Answer").thinkingContent)
        XCTAssertEqual(ThinkingProcessor.makeResult(thinking: "Plan", main: "Answer").thinkingContent, "Plan")
    }

    // MARK: - 2. MarkdownProcessor+BlockParsing 缺陷回归与对抗边界

    /// 回归测试：未闭合代码块必须安全收尾且 nextIndex == lines.count，不得越界
    func testUnclosedCodeBlockDoesNotOverflowNextIndex() {
        let processor = MarkdownProcessor()
        let lines = ["```swift", "let x = 1", "let y = 2"]
        let parsed = processor.parseCodeBlock(lines: lines, startIndex: 0)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.nextIndex, lines.count, "未闭合代码块 nextIndex 不得超出 lines.count")
        if case .codeBlock(let code, let language) = parsed?.block {
            XCTAssertEqual(language, "swift")
            XCTAssertEqual(code, "let x = 1\nlet y = 2")
        } else {
            XCTFail("应解析为 codeBlock")
        }
    }

    /// 回归测试：嵌套缩进子列表不得被父列表循环静默吞掉
    func testNestedBulletListPreservesChildItemsInsteadOfSwallowing() {
        let processor = MarkdownProcessor()
        let lines = [
            "- 父级项 A",
            "  - 子级项 A1",
            "  - 子级项 A2",
            "- 父级项 B"
        ]
        guard let first = processor.parseBulletList(lines: lines, startIndex: 0) else {
            return XCTFail("应解析出顶层父级项")
        }
        XCTAssertEqual(first.nextIndex, 1, "遇到更深缩进子列表时必须终止当前块，不得吞掉子项")

        guard let nested = processor.parseBulletList(lines: lines, startIndex: first.nextIndex) else {
            return XCTFail("外层循环继续扫描时应能完整解析子列表")
        }
        XCTAssertEqual(nested.nextIndex, 3)
        if case .bulletList(let items, let indent, _) = nested.block {
            XCTAssertEqual(indent, 2)
            XCTAssertEqual(items, ["子级项 A1", "子级项 A2"])
        } else {
            XCTFail("子级块应为 bulletList")
        }
    }

    /// 回归测试：Markdown 表格中的负数单元格（如 "-15%"、"-3.2"）不得被误判为对齐分隔符吞掉
    func testMarkdownTablePreservesNegativeNumberCells() {
        let processor = MarkdownProcessor()
        let lines = [
            "| 指标 | 变化率 | 差值 |",
            "| --- | :---: | ---: |",
            "| 延迟 | -15% | -3.2 |"
        ]
        guard let parsed = processor.parseTable(lines: lines, startIndex: 0) else {
            return XCTFail("应解析为标准表格")
        }
        XCTAssertEqual(parsed.nextIndex, 3)
        if case .table(let headers, let rows) = parsed.block {
            XCTAssertEqual(headers, ["指标", "变化率", "差值"])
            XCTAssertEqual(rows.count, 1)
            XCTAssertEqual(rows[0], ["延迟", "-15%", "-3.2"], "负数单元格不得被误过滤导致列错位")
        } else {
            XCTFail("应解析为 table")
        }
    }

    /// 覆盖 details 折叠块（单行 summary / 多行 summary / 无 summary 兜底）、taskList、heading、HR、blockquote、有序列表与缩进
    func testMarkdownBlockParsingComprehensiveEdgeCases() {
        let processor = MarkdownProcessor()

        // 1) details 块：单行 summary + 默认兜底
        let detailsLines = [
            "<details>",
            "<summary>点击展开</summary>",
            "第一行正文",
            "第二行正文",
            "</details>"
        ]
        if let res = processor.parseDetailsBlock(lines: detailsLines, startIndex: 0),
           case .details(let summary, let content) = res.block {
            XCTAssertEqual(summary, "点击展开")
            XCTAssertEqual(content, "第一行正文\n第二行正文")
            XCTAssertEqual(res.nextIndex, 5)
        } else {
            XCTFail("应解析 details 块")
        }

        let multiLineSummary = ["<details>", "<summary>头部", "尾部</summary>", "内容", "</details>"]
        if let res = processor.parseDetailsBlock(lines: multiLineSummary, startIndex: 0),
           case .details(let summary, _) = res.block {
            XCTAssertEqual(summary, "头部尾部")
        } else {
            XCTFail("应支持多行 summary")
        }

        let noSummary = ["<details>", "仅内容", "</details>"]
        if let res = processor.parseDetailsBlock(lines: noSummary, startIndex: 0),
           case .details(let summary, _) = res.block {
            XCTAssertEqual(summary, "Details")
        } else {
            XCTFail("缺失 summary 应兜底为 Details")
        }

        // 2) taskList 全语法（- [ ] / - [x] / - [X] / * [ ] / * [x] / * [X]）
        let tasks = ["- [ ] 待办1", "- [x] 完成1", "- [X] 完成2", "* [ ] 待办2", "* [x] 完成3", "* [X] 完成4", "普通行"]
        if let res = processor.parseTaskList(lines: tasks, startIndex: 0),
           case .taskList(let items) = res.block {
            XCTAssertEqual(items.count, 6)
            XCTAssertEqual(items.map(\.checked), [false, true, true, false, true, true])
            XCTAssertEqual(res.nextIndex, 6)
        } else {
            XCTFail("应解析 6 条任务列表项")
        }

        // 3) heading 合法 H1-H6 与非法 H7/无空格拦截
        XCTAssertNotNil(processor.parseHeading("### 三级标题"))
        XCTAssertNil(processor.parseHeading("####### 七级非法"))
        XCTAssertNil(processor.parseHeading("#无空格"))

        // 4) HR、blockquote、tab 缩进、有序列表
        XCTAssertNotNil(processor.parseHorizontalRule("---"))
        XCTAssertNotNil(processor.parseHorizontalRule("***"))
        XCTAssertNotNil(processor.parseHorizontalRule("___"))
        XCTAssertNil(processor.parseHorizontalRule("abc"))
        XCTAssertNotNil(processor.parseBlockquote("> 引用内容"))
        XCTAssertNil(processor.parseBlockquote("非引用"))
        XCTAssertEqual(processor.getIndentLevel("\t  item"), 6)

        let ordered = ["3. 第三条", "4. 第四条", ""]
        if let res = processor.parseBulletList(lines: ordered, startIndex: 0),
           case .bulletList(let items, let indent, let startNum) = res.block {
            XCTAssertEqual(indent, -1)
            XCTAssertEqual(startNum, 3)
            XCTAssertEqual(items, ["第三条", "第四条"])
        } else {
            XCTFail("应解析有序列表起始编号与内容")
        }
    }

    // MARK: - 3. 核心领域模型 Codable 契约与完整性

    func testDomainModelsCodableAndMetadataContracts() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        // LintIssue 全枚举 icon / colorName 与编解码
        let allTypes: [LintIssue.IssueType] = [.generic, .brokenLink, .orphan, .island, .cycle, .stub, .stale]
        for type in allTypes {
            XCTAssertFalse(type.icon.isEmpty)
        }
        let allSeverities: [LintIssue.LintSeverity] = [.error, .warning, .info]
        for sev in allSeverities {
            XCTAssertFalse(sev.icon.isEmpty)
            XCTAssertFalse(sev.colorName.isEmpty)
        }
        let issue = LintIssue(severity: .warning, type: .brokenLink, pageID: UUID(), message: "断链", suggestion: "修复链接")
        let decodedIssue = try decoder.decode(LintIssue.self, from: encoder.encode(issue))
        XCTAssertEqual(decodedIssue.id, issue.id)
        XCTAssertEqual(decodedIssue.type, .brokenLink)

        let suggestion = PotentialLinkSuggestion(sourcePageID: UUID(), sourceTitle: "A", targetTitle: "B")
        let decodedSug = try decoder.decode(PotentialLinkSuggestion.self, from: encoder.encode(suggestion))
        XCTAssertEqual(decodedSug.targetTitle, "B")

        // SearchDiagnosticInfo / AITaskProgress / AgentTool / PluginRecord / PageLink / FTS 模型
        let score = SearchDiagnosticInfo.ResultScore(id: UUID(), title: "RAG", ftsRank: 1, vectorRank: 2, finalScore: 0.92)
        let diag = SearchDiagnosticInfo(query: "q", rewrittenQuery: "rq", ftsCount: 5, vectorCount: 8, rrfTopResults: [score])
        XCTAssertEqual(diag.rrfTopResults.first?.finalScore, 0.92)

        let meta = AITaskMetadata(taskName: "Index", startTime: Date(timeIntervalSince1970: 1000))
        let state = AITaskProgressState(progress: 0.75, status: "Running")
        XCTAssertEqual(try decoder.decode(AITaskMetadata.self, from: encoder.encode(meta)), meta)
        XCTAssertEqual(try decoder.decode(AITaskProgressState.self, from: encoder.encode(state)), state)

        let tool = AgentTool(toolName: "queryVectorDB", description: "检索向量库", parametersSchema: "{}")
        XCTAssertEqual(tool.id, "queryVectorDB")
        XCTAssertEqual(try decoder.decode(AgentTool.self, from: encoder.encode(tool)), tool)

        let record = PluginRecord(id: "p1", name: "P1", version: "1.0", author: "A", source: "local", status: "active", permissionsJSON: "[]")
        let decodedRecord = try decoder.decode(PluginRecord.self, from: encoder.encode(record))
        XCTAssertEqual(decodedRecord.id, "p1")

        let link = PageLink(sourceID: UUID(), targetID: UUID(), context: "引用上下文")
        let decodedLink = try decoder.decode(PageLink.self, from: encoder.encode(link))
        XCTAssertEqual(decodedLink.sourceID, link.sourceID)
        XCTAssertEqual(decodedLink.context, "引用上下文")

        let pageFTS = KnowledgePageFTS(id: "id1", title: "T", content: "C", tags: "tag", aliases: "alias")
        XCTAssertEqual(pageFTS.title, "T")

        let pluginFTS = PluginRecordFTS(id: "p1", name: "N", author: "A", description: "D")
        XCTAssertEqual(pluginFTS.name, "N")

        let src = KnowledgeSource(pageID: UUID(), title: "doc.pdf", snippet: "核心摘要", anchorPath: "A > B", score: 0.88)
        let decodedSrc = try decoder.decode(KnowledgeSource.self, from: encoder.encode(src))
        XCTAssertEqual(decodedSrc, src)
    }
}
