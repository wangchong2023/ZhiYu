//
//  ThinkingProcessorEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 ThinkingProcessor 对 <think>/<thinking>/前缀思考/隐式 CoT 的提取与拆分语义正确性。
//

import XCTest
@testable import ZhiYu

final class ThinkingProcessorEdgeTests: XCTestCase {

    // MARK: - 空输入

    func testProcess_emptyString_returnsEmptyMain() {
        let result = ThinkingProcessor.process("")
        XCTAssertNil(result.thinkingContent)
        XCTAssertEqual(result.mainContent, "")
    }

    func testProcess_whitespaceOnly_returnsEmptyMain() {
        let result = ThinkingProcessor.process("   \n   ")
        XCTAssertNil(result.thinkingContent)
        XCTAssertEqual(result.mainContent, "")
    }

    // MARK: - <think> 标签

    func testProcess_thinkTag_extractsThinkingAndMain() {
        let raw = """
        <think>
        这是思考过程。
        </think>

        这是正式回答。
        """
        let result = ThinkingProcessor.process(raw)
        XCTAssertEqual(result.thinkingContent, "这是思考过程。")
        XCTAssertEqual(result.mainContent, "这是正式回答。")
    }

    func testProcess_thinkTag_caseInsensitive() {
        let raw = """
        <THINK>
        大写思考。
        </THINK>

        正文。
        """
        let result = ThinkingProcessor.process(raw)
        XCTAssertNotNil(result.thinkingContent)
        XCTAssertTrue(result.thinkingContent?.contains("大写思考") == true)
    }

    // MARK: - <thinking> 标签

    func testProcess_thinkingTag_extractsThinkingAndMain() {
        let raw = """
        <thinking>
        推理步骤。
        </thinking>

        回答正文。
        """
        let result = ThinkingProcessor.process(raw)
        XCTAssertEqual(result.thinkingContent, "推理步骤。")
        XCTAssertEqual(result.mainContent, "回答正文。")
    }

    // MARK: - <thought> 标签

    func testProcess_thoughtTag_extractsThinkingAndMain() {
        let raw = """
        <thought>
        思路。
        </thought>

        正文。
        """
        let result = ThinkingProcessor.process(raw)
        XCTAssertNotNil(result.thinkingContent)
    }

    // MARK: - [think] 方括号标签

    func testProcess_bracketThinkTag_extractsThinkingAndMain() {
        let raw = """
        [think]
        方括号思考。
        [/think]

        正文。
        """
        let result = ThinkingProcessor.process(raw)
        XCTAssertNotNil(result.thinkingContent)
        XCTAssertTrue(result.thinkingContent?.contains("方括号思考") == true)
    }

    // MARK: - [思考过程] 中文标签

    func testProcess_chineseThinkingTag_extractsThinkingAndMain() {
        let raw = """
        [思考过程]
        中文思考。
        [/思考过程]

        正文。
        """
        let result = ThinkingProcessor.process(raw)
        XCTAssertNotNil(result.thinkingContent)
        XCTAssertTrue(result.thinkingContent?.contains("中文思考") == true)
    }

    // MARK: - ```think 代码块

    func testProcess_thinkCodeBlock_extractsThinkingAndMain() {
        let raw = """
        ```think
        代码块思考。
        ```

        正文。
        """
        let result = ThinkingProcessor.process(raw)
        XCTAssertNotNil(result.thinkingContent)
        XCTAssertTrue(result.thinkingContent?.contains("代码块思考") == true)
    }

    // MARK: - 未闭合标签

    func testProcess_unclosedThinkTag_extractsThinkingOnly() {
        let raw = "<think>这是未闭合的思考过程"
        let result = ThinkingProcessor.process(raw)
        XCTAssertNotNil(result.thinkingContent)
        XCTAssertEqual(result.mainContent, "")
    }

    // MARK: - 前缀思考

    func testProcess_prefixThinkingChinese_extractsThinkingAndMain() {
        let raw = "思考过程：这是思考。\n\n这是正文。"
        let result = ThinkingProcessor.process(raw)
        XCTAssertNotNil(result.thinkingContent)
        XCTAssertTrue(result.thinkingContent?.contains("这是思考") == true)
        XCTAssertTrue(result.mainContent.contains("这是正文"))
    }

    func testProcess_prefixThinkingEnglish_extractsThinkingAndMain() {
        let raw = "Thinking: this is thinking.\n\nThis is main."
        let result = ThinkingProcessor.process(raw)
        XCTAssertNotNil(result.thinkingContent)
        XCTAssertTrue(result.mainContent.contains("This is main"))
    }

    // MARK: - 隐式 CoT

    func testProcess_implicitCoT_extractsThinkingAndMain() {
        let raw = """
        我们被要求分析问题。需要查看相关信息。

        1. 第一步
        2. 第二步
        """
        let result = ThinkingProcessor.process(raw)
        XCTAssertNotNil(result.thinkingContent)
        XCTAssertTrue(result.mainContent.contains("1. 第一步"))
    }

    // MARK: - 无思考过程

    func testProcess_plainText_noThinking() {
        let raw = "这是普通回答正文。"
        let result = ThinkingProcessor.process(raw)
        XCTAssertNil(result.thinkingContent)
        XCTAssertEqual(result.mainContent, raw)
    }

    // MARK: - Result Equatable

    func testResult_equatable() {
        let r1 = ThinkingProcessor.Result(thinkingContent: "a", mainContent: "b")
        let r2 = ThinkingProcessor.Result(thinkingContent: "a", mainContent: "b")
        XCTAssertEqual(r1, r2)
    }

    func testResult_thinkingContentNil_notEqual() {
        let r1 = ThinkingProcessor.Result(thinkingContent: nil, mainContent: "b")
        let r2 = ThinkingProcessor.Result(thinkingContent: "a", mainContent: "b")
        XCTAssertNotEqual(r1, r2)
    }
}
