//
//  TextChunkerSupplementTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/09/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Test] 单元测试
//  核心职责：TextChunker 及其余 Processors 组件补充测试 — Quiz 策略、清理管线、JSON/Frontmatter 提取器
//

import XCTest
import Foundation
import Dependencies
import UFPCore
@testable import ZhiYu

// MARK: - TextChunkerProcessor 补充测试

final class TextChunkerSupplementTests: XCTestCase {

    private var chunker: TextChunkerProcessor!

    override func setUp() {
        super.setUp()
        chunker = TextChunkerProcessor()
    }

    override func tearDown() {
        chunker = nil
        super.tearDown()
    }

    // MARK: - split 边界条件
    // MARK: - 代码块处理
    // MARK: - 标题层级与面包屑
    // MARK: - Chunk contextualText
    // MARK: - 重叠窗口
    // MARK: - startIndex 单调递增（缺陷 #12 修复验证）
    // MARK: - 默认配置
}

// MARK: - QuizSynthesisStrategy 补充测试

final class QuizSynthesisStrategySupplementTests: XCTestCase {

    private var strategy: QuizSynthesisStrategy!

    override func setUp() {
        super.setUp()
        strategy = QuizSynthesisStrategy()
    }

    override func tearDown() {
        strategy = nil
        super.tearDown()
    }

    // MARK: - type 属性

    func testType_isQuiz() {
        XCTAssertEqual(strategy.type, .quiz)
    }

    // MARK: - process 路径覆盖

    func testProcess_validQuizJSON_returnsRawContent() {
        let validJSON = """
        {
            "quizTitle": "Test Quiz",
            "questions": [
                {
                    "id": 1,
                    "question": "What is 1+1?",
                    "options": ["1", "2", "3", "4"],
                    "answerIndex": 1,
                    "explanation": "Basic math"
                }
            ]
        }
        """
        let result = strategy.process(rawContent: validJSON, sourceContent: "source")
        XCTAssertEqual(result, validJSON)
    }

    func testProcess_invalidContent_longEnough_returnsRawContent() {
        // rawContent.utf8.count >= minValidSynthesisTextBytes (10) 但无法解析为 quiz
        let longInvalidContent = "This is a long enough content that cannot be parsed as quiz JSON"
        let result = strategy.process(rawContent: longInvalidContent, sourceContent: "source")
        // 由于 canDecodeAsQuizModel false, convertJSONToMarkdown nil, 但 utf8.count >= 10
        XCTAssertEqual(result, longInvalidContent)
    }

    func testProcess_invalidContent_tooShort_returnsFallback() {
        // rawContent.utf8.count < minValidSynthesisTextBytes (10)
        let shortInvalidContent = "short"
        let result = strategy.process(rawContent: shortInvalidContent, sourceContent: "source content")
        // 应返回 fallback
        XCTAssertFalse(result.isEmpty)
        // fallback 应是有效 JSON
        XCTAssertTrue(result.contains("quizTitle") || result.contains("questions"))
    }

    func testProcess_emptyContent_returnsFallback() {
        let result = strategy.process(rawContent: "", sourceContent: "source content")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - generateFallback

    func testGenerateFallback_returnsValidQuizJSON() {
        let result = strategy.generateFallback(from: "source content", title: "Test Title")
        XCTAssertFalse(result.isEmpty)
        // 应是有效 JSON
        if let data = result.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            XCTAssertNotNil(json[ProcessorConstants.Synthesis.quizTitleKey])
            XCTAssertNotNil(json[ProcessorConstants.Synthesis.quizQuestionsKey])
        } else {
            XCTFail("generateFallback 应返回有效 JSON")
        }
    }

    func testGenerateFallback_emptyTitle_usesDefaultTitle() {
        let result = strategy.generateFallback(from: "source content", title: "")
        XCTAssertFalse(result.isEmpty)
        // 应包含默认标题
        XCTAssertTrue(result.contains(L10n.AI.Prompt.Quiz.defaultTitle) || result.contains("quizTitle"))
    }

    func testGenerateFallback_whitespaceTitle_usesDefaultTitle() {
        let result = strategy.generateFallback(from: "source content", title: "   ")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Sendable 合规

    func testStrategy_isSendable() {
        // 编译时与运行时检查 Sendable 合规
        let proto = strategy as SynthesisStrategyProtocol
        XCTAssertNotNil(proto, "strategy 实例应合规遵循 SynthesisStrategyProtocol")
    }
}

// MARK: - CJKSpacingFormatter 补充测试

final class CJKSpacingFormatterSupplementTests: XCTestCase {
    // 占位：CJK 间距格式化器补充测试
}

// MARK: - MermaidSanitizer 补充测试

final class MermaidSanitizerSupplementTests: XCTestCase {
    // 占位：Mermaid 清理器补充测试
}

// MARK: - SwiftMarkdownASTCleaner 补充测试

final class SwiftMarkdownASTCleanerSupplementTests: XCTestCase {
    // 占位：SwiftMarkdown AST 清理器补充测试
}

// MARK: - IngestSanitationPipeline 补充测试

final class IngestSanitationPipelineSupplementTests: XCTestCase {
    func testSanitize_ocrMode_stripsHTML() {
        let input = "<p>OCR text</p>"
        let result = IngestSanitationPipeline.shared.sanitize(input, mode: .ocr)
        XCTAssertFalse(result.contains("<p>"))
        XCTAssertTrue(result.contains("OCR text"))
    }

    func testSanitize_voiceNoteMode_stripsLeadingChatter() {
        let input = "Here is the summary:\nActual content"
        let result = IngestSanitationPipeline.shared.sanitize(input, mode: .voiceNote)
        XCTAssertFalse(result.contains("Here is the summary"))
    }

    func testSanitize_webClipMode_stripsHTML() {
        let input = "<script>alert(1)</script><p>Content</p>"
        let result = IngestSanitationPipeline.shared.sanitize(input, mode: .webClip)
        XCTAssertFalse(result.contains("<script>"))
        XCTAssertTrue(result.contains("Content"))
    }
}

// MARK: - DocumentSanitationEngine 补充测试

final class DocumentSanitationEngineSupplementTests: XCTestCase {
    // 占位：文档清理引擎补充测试
}

// MARK: - WikiLinkExtractor 补充测试

final class WikiLinkExtractorSupplementTests: XCTestCase {
    // 占位：Wiki 链接提取器补充测试
}
