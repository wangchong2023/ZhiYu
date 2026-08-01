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
