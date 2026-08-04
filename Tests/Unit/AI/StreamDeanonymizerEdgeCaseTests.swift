//
//  StreamDeanonymizerEdgeCaseTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 StreamDeanonymizer 的边界条件：25 字符阈值、无映射占位符、finalize 非空 buffer、连续左括号。
//

import XCTest
@testable import ZhiYu

final class StreamDeanonymizerEdgeCaseTests: XCTestCase {

    // MARK: - 25 字符阈值分支

    func testLongUnmatchedBracketOutputsPrefixAndBuffersSuffix() {
        var streamDecoder = StreamDeanonymizer(mapping: [:])
        // 构造一个超过 25 字符且无匹配 ']' 的文本
        let longText = "[这是一个非常非常非常非常非常非常长的未闭合占位符文本内容"
        let output = streamDecoder.process(chunk: longText)

        // remaining.count > 25 时：输出前段（count - 10），缓存后 10 字符
        XCTAssertFalse(output.isEmpty, "超过 25 字符的未匹配 '[' 应输出前段而非全部缓冲")
        let finalRemaining = streamDecoder.finalize()
        XCTAssertFalse(finalRemaining.isEmpty, "finalize 应返回缓冲的后 10 字符")
        XCTAssertEqual(finalRemaining.count, 10, "应恰好缓冲后 10 字符")
    }

    func testShortUnmatchedBracketFullyBuffered() {
        var streamDecoder = StreamDeanonymizer(mapping: [:])
        // 短于 25 字符的未匹配 '[' 应全部缓冲
        let output = streamDecoder.process(chunk: "[ENT")
        XCTAssertEqual(output, "", "短文本未匹配 '[' 应全部缓冲，不输出")
        let finalRemaining = streamDecoder.finalize()
        XCTAssertEqual(finalRemaining, "[ENT", "finalize 应返回缓冲的完整文本")
    }

    // MARK: - 无映射占位符直接输出

    func testUnmappedPlaceholderOutputAsIs() {
        var streamDecoder = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])
        // [ENTITY_B] 不在映射中，应原样输出
        let output = streamDecoder.process(chunk: "你好[ENTITY_B]再见")
        XCTAssertEqual(output, "你好[ENTITY_B]再见", "未在映射中的占位符应原样输出")
    }

    func testMappedPlaceholderReplaced() {
        var streamDecoder = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])
        let output = streamDecoder.process(chunk: "你好[ENTITY_A]再见")
        XCTAssertEqual(output, "你好张三再见", "映射中的占位符应被还原")
    }

    // MARK: - finalize 返回非空 buffer

    func testFinalizeReturnsNonEmptyBuffer() {
        var streamDecoder = StreamDeanonymizer(mapping: [:])
        let output = streamDecoder.process(chunk: "文本[ENT")
        XCTAssertTrue(output.contains("文本"), "前段文本应已输出")
        let final = streamDecoder.finalize()
        XCTAssertEqual(final, "[ENT", "finalize 应返回缓冲区剩余的未匹配占位符")
    }

    func testFinalizeReturnsEmptyWhenBufferEmpty() {
        var streamDecoder = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])
        _ = streamDecoder.process(chunk: "完整[ENTITY_A]文本")
        let final = streamDecoder.finalize()
        XCTAssertEqual(final, "", "buffer 为空时 finalize 应返回空字符串")
    }

    // MARK: - 连续左括号

    func testConsecutiveOpenBrackets() {
        var streamDecoder = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])
        // 第一个 '[' 无匹配 ']'，第二个 '[ENTITY_A]' 有匹配
        let output = streamDecoder.process(chunk: "[未闭合[ENTITY_A]后续")
        XCTAssertTrue(output.contains("张三") || output.contains("[ENTITY_A]"), "应正确处理连续左括号")
    }

    // MARK: - 空输入

    func testEmptyChunkReturnsEmpty() {
        var streamDecoder = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])
        let output = streamDecoder.process(chunk: "")
        XCTAssertEqual(output, "", "空 chunk 应返回空字符串")
    }

    func testNoBracketsOutputAsIs() {
        var streamDecoder = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])
        let output = streamDecoder.process(chunk: "普通文本无占位符")
        XCTAssertEqual(output, "普通文本无占位符", "无 '[' 的文本应原样输出")
    }

    // MARK: - 占位符跨多 chunk 切断

    func testPlaceholderSplitAcrossMultipleChunks() {
        var streamDecoder = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])

        let out1 = streamDecoder.process(chunk: "前缀[")
        let out2 = streamDecoder.process(chunk: "ENTITY")
        let out3 = streamDecoder.process(chunk: "_A]后缀")

        XCTAssertEqual(out1, "前缀", "第一个 chunk 应输出 '[' 之前的文本")
        XCTAssertEqual(out2, "", "中间 chunk 应被缓冲")
        XCTAssertEqual(out3, "张三后缀", "最后 chunk 应拼装完整占位符并还原")
    }

    // MARK: - 多个占位符混合

    func testMultiplePlaceholdersMixed() {
        let mapping = ["[ENTITY_A]": "张三", "[ENTITY_B]": "北京"]
        var streamDecoder = StreamDeanonymizer(mapping: mapping)

        let output = streamDecoder.process(chunk: "[ENTITY_A]住在[ENTITY_B]城市")
        XCTAssertEqual(output, "张三住在北京城市", "多个占位符应全部还原")
    }
}
