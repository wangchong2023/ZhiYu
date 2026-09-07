//
//  DocumentSanitizerTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
@testable import ZhiYu

final class DocumentSanitizerTests: XCTestCase {

    func testDocumentSanitizer_IngestMultimodalText_AppliesPanguSpacingAndASTFixes() throws {
        // Given: 模拟 OCR 或音视频转写产出的无空格中英文、且未闭合代码块的粗糙 Markdown 文本
        let chatter = L10n.AI.Synthesis.Fallback.chatterPrefixes.first ?? "Here is"
        let unformattedRawText = "\(chatter): summary:\niOS开发和Swift6并发模型示例:\n```swift\nlet x = 10"

        // When: 执行全局清洗引擎规范化
        let sanitized = DocumentSanitationEngine.shared.sanitize(unformattedRawText)

        // Then:
        // 1. 杂质引导语 必须被干净剥离
        XCTAssertFalse(sanitized.contains(chatter), "前导杂质对话引导语必须被干净剥离")

        // 2. 盘古中英文混排自动注入空格（如 "iOS 开发"、"Swift 6"）
        XCTAssertTrue(sanitized.contains("iOS 开发") || sanitized.contains("Swift 6"), "英文与数字/中文混排必须由 Pangu 格式化美化空格")

        // 3. 未闭合的代码块必须由 AST 清洗器自动补齐结尾 ```
        XCTAssertTrue(sanitized.hasSuffix("```") || sanitized.hasSuffix("```\n"), "缺失末尾闭合标记的代码块必须被 AST 清洗器自动修复闭合")
    }

    func testWikiLinkExtractor_ExtractsValidTitleAndAliases() throws {
        // Given: 包含单标准 WikiLink 与别名 WikiLink 的 Markdown 文本
        let sampleMarkdown = "参考 [[架构设计]] 以及 [[数据模型|Database Schema]] 规范"

        // When: 调用公共提取器
        let matches = WikiLinkExtractor.extractLinks(from: sampleMarkdown)

        // Then: 成功提取出 2 个合规的双向链接对象
        XCTAssertEqual(matches.count, 2, "应该精准提取出 2 个 [[页面标题]] 双向链接")
        XCTAssertEqual(matches[0].targetTitle, "架构设计", "第一个链接的目标标题应为 '架构设计'")
        XCTAssertNil(matches[0].alias, "第一个链接不应带别名")

        XCTAssertEqual(matches[1].targetTitle, "数据模型", "第二个链接的目标标题应为 '数据模型'")
        XCTAssertEqual(matches[1].alias, "Database Schema", "第二个链接的别名应为 'Database Schema'")
    }
}
