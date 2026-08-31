//
//  MarkdownProcessorParsingBranchTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 测试层
//  核心职责：验证 MarkdownProcessor 复杂块解析、Frontmatter 自愈与双链提取全部边缘分支。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class MarkdownProcessorParsingBranchTests: XCTestCase {

    // MARK: - 1. YAML Frontmatter 容灾解析分支

    func testFrontmatterParser_MalformedAndNormal() {
        let normalContent = """
        ---
        title: 知识库设计
        tags: [架构, Swift]
        ---
        正文第一段
        """
        let parsed = FrontmatterParser.split(content: normalContent)
        XCTAssertNotNil(parsed.frontmatter)
        XCTAssertTrue(parsed.frontmatter?.contains("title: 知识库设计") ?? false)
        XCTAssertEqual(parsed.body.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines), "正文第一段")

        // 畸变 Frontmatter（未闭合 ---）
        let malformed = """
        ---
        title: 未闭合头部
        没有闭合分割线
        """
        let malformedResult = FrontmatterParser.split(content: malformed)
        XCTAssertNil(malformedResult.frontmatter)
        XCTAssertFalse(malformedResult.body.isEmpty)
    }

    // MARK: - 2. WikiLink 复杂双链提取分支

    func testWikiLinkExtractor_ExtractionEdgeCases() {
        let content = """
        这里引用了 [[核心概念]]，以及带别名的 [[核心概念|别名描述]]。
        还有空链 [[]] 和单边括号 [未闭合。
        """
        let links = WikiLinkExtractor.extractLinks(from: content)

        XCTAssertTrue(links.contains { $0.targetTitle == "核心概念" })
        XCTAssertFalse(links.contains { $0.targetTitle.isEmpty }, "空链接不应被提取为有效引用")
    }
}
