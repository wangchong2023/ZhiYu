//
//  IngestSanitationPipelineTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证多模态 IngestSanitationPipeline 针对 OCR、语音笔记、网页剪藏的清洗与规整逻辑。
//

import XCTest
@testable import ZhiYu

final class IngestSanitationPipelineTests: XCTestCase {

    func testOCRSanitation_MergesLineBreaksAndAppliesPanguSpacing() {
        let rawOCR = "<p>智宇AI知识管理</p>\n支持双向链接"
        let sanitized = IngestSanitationPipeline.shared.sanitize(rawOCR, mode: .ocr)

        XCTAssertFalse(sanitized.contains("<p>"), "应当剥离 HTML 标签")
        XCTAssertTrue(sanitized.contains("智宇 AI 知识管理"), "应当自动填充盘古中英文空格，got: \(sanitized)")
    }

    func testVoiceNoteSanitation_StripsLeadingChatterAndAppliesPangu() {
        let rawVoice = "Here is the summary:\n语音转写内容100%成功"
        let sanitized = IngestSanitationPipeline.shared.sanitize(rawVoice, mode: .voiceNote)

        XCTAssertFalse(sanitized.contains("Here is the summary"), "应当剥离前导对话引导文案")
        XCTAssertTrue(sanitized.contains("语音转写内容 100% 成功"), "应当应用盘古空格，got: \(sanitized)")
    }

    func testWebClipSanitation_StripsHTMLAndFixesMermaid() {
        let rawWeb = "<div>网页正文</div>\n```mermaid\ngraph TD\nA[节点:测试] --> B\n```"
        let sanitized = IngestSanitationPipeline.shared.sanitize(rawWeb, mode: .webClip)

        XCTAssertFalse(sanitized.contains("<div>"), "应当剥离 div 标签")
        XCTAssertTrue(sanitized.contains("A[\"节点:测试\"]"), "应当修复 Mermaid 带冒号节点的双引号包领，got: \(sanitized)")
    }
}
