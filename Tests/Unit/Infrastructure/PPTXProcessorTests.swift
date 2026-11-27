//
//  PPTXProcessorTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import UFPCore
@testable import ZhiYuUnitTestHost

final class PPTXProcessorTests: XCTestCase {

    func testPPTXProcessor_GeneratesValidZipAndOpenXMLStructure() async throws {
        // Given: 多页面幻灯片 Markdown 文本 + 专用 PPTXProcessor 实例（构造函数注入真实 archiver）
        // 不使用 shared 单例，避免全局 ServiceContainer 状态污染
        let processor = PPTXProcessor(archiver: ZIPFoundationArchiver())
        let markdown = """
        # 智宇 LLM Wiki 架构
        
        ## 核心特性
        - 语义分块与混合向量检索
        - AI 合成与双向链接缝合
        - 盘古排版与 AST 节点清洗
        
        ## 稳定性打点
        - synthesisTraceID 级联追踪
        - 自愈降级与 Audit 日志
        """

        // When: 生成 PPTX
        let outputURL = try await processor.generate(markdown: markdown, title: "TestPresentation")

        // Then:
        // 1. 生成的 outputURL 文件必须在磁盘上合法存在且大于 0 字节
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "生成的 .pptx 文件路径必须存在")
        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 0, "生成的 .pptx 文件大小必须大于 0 字节")

        // 2. 清理测试文件
        try? FileManager.default.removeItem(at: outputURL)
    }

    /// 缺陷 #109 回归：XML 保留字符必须转义，且含路径穿越符的标题不得逃逸 temporaryDirectory
    func testPPTXProcessor_EscapesXMLAndSanitizesTraversalTitle() async throws {
        let escaped = PPTXProcessor.escapeXML(#"A & B <tag> "quote" 'single'"#)
        XCTAssertEqual(escaped, "A &amp; B &lt;tag&gt; &quot;quote&quot; &apos;single&apos;")

        let sanitized = PPTXProcessor.sanitizeOutputFilename("../../Q1/Q2\\Report")
        XCTAssertFalse(sanitized.contains("/"))
        XCTAssertFalse(sanitized.contains("\\"))
        XCTAssertFalse(sanitized.contains(".."))
        XCTAssertEqual(PPTXProcessor.sanitizeOutputFilename("///..."), "Presentation")

        let processor = PPTXProcessor(archiver: ZIPFoundationArchiver())
        let outputURL = try await processor.generate(
            markdown: "# R&D <2026>\n\n## Budget & Goals\n- x < y && y > 0",
            title: "../Evil/Title"
        )
        defer { try? FileManager.default.removeItem(at: outputURL) }

        XCTAssertEqual(
            outputURL.deletingLastPathComponent().standardizedFileURL,
            FileManager.default.temporaryDirectory.standardizedFileURL,
            "输出文件必须严格限制在 temporaryDirectory 根目录内"
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
    }

    /// 缺陷 #185 回归：XML 1.0 非法控制字符（如 NUL/换页符）必须剥离，保留制表与换行
    func testPPTXProcessor_StripsInvalidXMLControlCharacters() {
        let dirty = "Hello\u{0000}\u{000C}World\tLine1\nLine2"
        let cleaned = PPTXProcessor.escapeXML(dirty)
        XCTAssertEqual(cleaned, "HelloWorld\tLine1\nLine2", "必须剥离 NUL 与 FormFeed 等 XML 1.0 非法控制字符并保留合法空白")
    }
}
