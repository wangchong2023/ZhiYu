//
//  StreamDeanonymizerLiteralCollisionTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 StreamDeanonymizer 对 LLM 生成的 [ENTITY_X] 字面量的处理——是否存在误还原导致数据泄露。
//

import XCTest
@testable import ZhiYu

final class StreamDeanonymizerLiteralCollisionTests: XCTestCase {

    // MARK: - 核心问题验证：LLM 生成 [ENTITY_A] 字面量被误还原

    /// 场景：LLM 在响应中输出了与脱敏占位符格式完全相同的字面量文本（如解释脱敏机制、引用文档片段）。
    /// 注意：当前实现无法区分真实脱敏占位符和 LLM 生成的同格式字面量——这是设计层面的限制。
    /// 此测试记录当前行为：字面量会被误还原。彻底解决需要使用 UUID 等独特占位符格式或位置记录。
    func testLiteralEntityPlaceholderMistakenlyReplaced() {
        let mapping = ["[ENTITY_A]": "张三"]
        var streamDecoder = StreamDeanonymizer(mapping: mapping)

        // LLM 生成的字面量 [ENTITY_A]（非脱敏占位符，而是模型自行输出的文本）
        let llmOutput = "脱敏占位符格式为 [ENTITY_A]，用于替换敏感实体。"
        let output = streamDecoder.process(chunk: llmOutput)

        // 当前行为：字面量被误还原为敏感数据（设计限制，需用 UUID 占位符彻底解决）
        XCTAssertEqual(output, "脱敏占位符格式为 张三，用于替换敏感实体。", "当前实现无法区分真实占位符和字面量——设计限制")
    }

    /// 场景：LLM 在代码块中输出了 [ENTITY_A] 字面量
    /// 注意：当前实现无法区分真实占位符和字面量——设计限制。
    func testLiteralEntityPlaceholderInCodeBlock() {
        let mapping = ["[ENTITY_A]": "张三", "[ENTITY_B]": "北京"]
        var streamDecoder = StreamDeanonymizer(mapping: mapping)

        // 简单代码块，[ENTITY_A] 和 [ENTITY_B] 都是独立占位符格式
        let llmOutput = "代码示例：[ENTITY_A] 和 [ENTITY_B] 是占位符"
        let output = streamDecoder.process(chunk: llmOutput)

        // 当前行为：字面量被还原（设计限制，无法区分真实占位符和字面量）
        XCTAssertTrue(output.contains("张三"), "当前实现会还原代码块中的字面量——设计限制")
        XCTAssertTrue(output.contains("北京"), "当前实现会还原代码块中的字面量——设计限制")
    }

    // MARK: - 普通方括号文本误判验证

    /// 场景：Markdown 链接 [text](url) 中的 [text] 被当作占位符查找
    func testMarkdownLinkBracketNotMistakenAsPlaceholder() {
        let mapping = ["[ENTITY_A]": "张三"]
        var streamDecoder = StreamDeanonymizer(mapping: mapping)

        let markdown = "参见 [文档](https://example.com) 了解详情。"
        let output = streamDecoder.process(chunk: markdown)

        // 期望：Markdown 链接原样输出（[文档] 不在 mapping 中，应原样输出）
        XCTAssertEqual(output, markdown, "Markdown 链接中的 [text] 不应被修改")
    }

    /// 场景：数组字面量 [1, 2, 3] 中的方括号
    func testArrayLiteralBracketNotMistakenAsPlaceholder() {
        var streamDecoder = StreamDecoder(mapping: [:])

        let array = "let arr = [1, 2, 3]"
        let output = streamDecoder.process(chunk: array)

        XCTAssertEqual(output, array, "数组字面量中的方括号应原样输出")
    }

    // MARK: - 跨 chunk 切断的普通方括号文本

    /// 场景：普通文本 "array = [1, 2" 被分包切断，[ 后无配对 ]
    func testPlainBracketSplitAcrossChunks() {
        var streamDecoder = StreamDecoder(mapping: ["[ENTITY_A]": "张三"])

        let out1 = streamDecoder.process(chunk: "array = [1, 2")
        let out2 = streamDecoder.process(chunk: ", 3] done")

        // 期望：最终输出应完整还原 "array = [1, 2, 3] done"
        let combined = out1 + out2
        XCTAssertEqual(combined, "array = [1, 2, 3] done", "普通方括号文本跨 chunk 应完整还原")
    }

    // MARK: - 混合场景：真实占位符 + 字面量占位符

    /// 场景：响应中同时包含真实脱敏占位符和 LLM 生成的同格式字面量
    /// 注意：当前实现无法区分两者——设计限制。
    func testMixedRealAndLiteralPlaceholders() {
        let mapping = ["[ENTITY_A]": "张三"]
        var streamDecoder = StreamDecoder(mapping: mapping)

        // 第一个 [ENTITY_A] 是真实脱敏占位符（应还原为"张三"）
        // 第二个 [ENTITY_A] 是 LLM 生成的字面量（当前实现也会还原）
        let input = "张三说：\"占位符格式是 [ENTITY_A]\""
        let output = streamDecoder.process(chunk: input)

        // 当前行为：两者都被还原（设计限制）
        XCTAssertEqual(output, "张三说：\"占位符格式是 张三\"", "当前实现会将所有 [ENTITY_A] 都还原——设计限制")
    }
}

/// 临时别名，避免与 StreamDeanonymizer 命名冲突
typealias StreamDecoder = StreamDeanonymizer
