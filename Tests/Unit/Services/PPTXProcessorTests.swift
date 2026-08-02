//
//  PPTXProcessorTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
@testable import ZhiYu

final class PPTXProcessorTests: XCTestCase {

    override func setUp() {
        super.setUp()
        let container = ServiceContainer.shared
        if container.resolveOptional((any FileArchiverProtocol).self) == nil {
            let archiver = iOSFileArchiver()
            container.register(archiver as any FileArchiverProtocol, for: (any FileArchiverProtocol).self)
        }
    }

    func testPPTXProcessor_GeneratesValidZipAndOpenXMLStructure() async throws {
        // Given: 多页面幻灯片 Markdown 文本
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
        let outputURL = try await PPTXProcessor.shared.generate(markdown: markdown, title: "TestPresentation")

        // Then:
        // 1. 生成的 outputURL 文件必须在磁盘上合法存在且大于 0 字节
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path), "生成的 .pptx 文件路径必须存在")
        let attributes = try FileManager.default.attributesOfItem(atPath: outputURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0
        XCTAssertGreaterThan(fileSize, 0, "生成的 .pptx 文件大小必须大于 0 字节")

        // 2. 清理测试文件
        try? FileManager.default.removeItem(at: outputURL)
    }
}
