//
//  ThinkingProcessorTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
@testable import ZhiYu

final class ThinkingProcessorTests: XCTestCase {

    func testProcess_thinkTagExtraction() {
        let raw = """
        <think>
        思考如何总结知识库。
        这是推理步骤。
        </think>
        这是正式回答正文。
        """
        let result = ThinkingProcessor.process(raw)
        XCTAssertNotNil(result.thinkingContent)
        XCTAssertTrue(result.thinkingContent?.contains("思考如何总结知识库") == true)
        XCTAssertEqual(result.mainContent, "这是正式回答正文。")
    }

    func testProcess_uppercaseThinkingTagExtraction() {
        let raw = """
        <Thinking>
        通过分析用户输入的 Prompt。
        这是大写的思考过程。
        </Thinking>

        你好！这是正式回答。
        """
        let result = ThinkingProcessor.process(raw)
        XCTAssertNotNil(result.thinkingContent)
        XCTAssertTrue(result.thinkingContent?.contains("这是大写的思考过程") == true)
        XCTAssertEqual(result.mainContent, "你好！这是正式回答。")
    }

    func testProcess_implicitChainOfThoughtExtraction() {
        let raw = """
        我们被要求基于知识库规划学习路径。需要查看当前知识库概览和相关信息。
        用户需求：规划学习路径。建议先实践原子化笔记。根据你的知识库，建议下一步学习路径如下：

        1. 掌握原子化笔记
        2. 建立卡片盒系统
        """
        let result = ThinkingProcessor.process(raw)
        XCTAssertNotNil(result.thinkingContent)
        XCTAssertTrue(result.thinkingContent?.contains("我们被要求基于知识库规划学习路径") == true)
        XCTAssertTrue(result.mainContent.contains("1. 掌握原子化笔记"))
    }

    func testProcess_withoutThinking() {
        let raw = "这是没有思考过程的普通回答正文。"
        let result = ThinkingProcessor.process(raw)
        XCTAssertNil(result.thinkingContent)
        XCTAssertEqual(result.mainContent, raw)
    }

    func testProcess_emptyInput() {
        let result = ThinkingProcessor.process("   ")
        XCTAssertNil(result.thinkingContent)
        XCTAssertEqual(result.mainContent, "")
    }
}
