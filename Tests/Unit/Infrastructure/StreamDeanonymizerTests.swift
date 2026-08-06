//
//  StreamDeanonymizerTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证流式端侧解密还原器 StreamDeanonymizer 的占位符分包还原、缓冲区边界与 finalize 逻辑。
//

import XCTest
@testable import ZhiYu

final class StreamDeanonymizerTests: XCTestCase {

    // MARK: - 基础还原

    func testProcess_noPlaceholder_passesThrough() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        let result = deanonymizer.process(chunk: "Hello World")
        XCTAssertEqual(result, "Hello World")
    }

    func testProcess_singlePlaceholder_replacesCorrectly() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        let result = deanonymizer.process(chunk: "你好，[ENTITY_1]！")
        XCTAssertEqual(result, "你好，张三！")
    }

    func testProcess_multiplePlaceholders_allReplaced() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三", "[ENTITY_2]": "李四"])
        let result = deanonymizer.process(chunk: "[ENTITY_1]和[ENTITY_2]在开会")
        XCTAssertEqual(result, "张三和李四在开会")
    }

    func testProcess_unknownPlaceholder_passesThrough() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        let result = deanonymizer.process(chunk: "参考[REF_001]文档")
        XCTAssertEqual(result, "参考[REF_001]文档")
    }

    func testProcess_emptyMapping_passesAllThrough() {
        var deanonymizer = StreamDeanonymizer(mapping: [:])
        let result = deanonymizer.process(chunk: "[ENTITY_1]和[ENTITY_2]")
        XCTAssertEqual(result, "[ENTITY_1]和[ENTITY_2]")
    }

    func testProcess_emptyChunk_returnsEmpty() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        let result = deanonymizer.process(chunk: "")
        XCTAssertEqual(result, "")
    }

    // MARK: - 分包切断

    func testProcess_placeholderSplitAcrossChunks_buffersAndRestores() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])

        let part1 = deanonymizer.process(chunk: "你好，[ENTI")
        let part2 = deanonymizer.process(chunk: "TY_1]！")

        XCTAssertEqual(part1, "你好，")
        XCTAssertEqual(part2, "张三！")
    }

    func testProcess_placeholderSplitAtBracket_buffersBracket() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])

        let part1 = deanonymizer.process(chunk: "文本[")
        let part2 = deanonymizer.process(chunk: "ENTITY_1]后续")

        XCTAssertEqual(part1, "文本")
        XCTAssertEqual(part2, "张三后续")
    }

    func testProcess_placeholderSplitBeforeBracket_buffersNothing() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])

        let part1 = deanonymizer.process(chunk: "文本")
        let part2 = deanonymizer.process(chunk: "[ENTITY_1]")

        XCTAssertEqual(part1, "文本")
        XCTAssertEqual(part2, "张三")
    }

    func testProcess_multipleSplits_reassembleCorrectly() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])

        let p1 = deanonymizer.process(chunk: "A[")
        let p2 = deanonymizer.process(chunk: "ENT")
        let p3 = deanonymizer.process(chunk: "ITY")
        let p4 = deanonymizer.process(chunk: "_1]B")

        XCTAssertEqual(p1, "A")
        XCTAssertEqual(p2, "")
        XCTAssertEqual(p3, "")
        XCTAssertEqual(p4, "张三B")
    }

    // MARK: - 缓冲区长度边界

    func testProcess_longTextWithoutCloseBracket_buffersAndOutputsPrefix() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])

        let longText = "[" + String(repeating: "x", count: 30)
        let result = deanonymizer.process(chunk: longText)

        // 超过 maxRawLength(25)，输出前段，保留后 bufferSuffixLength(10) 字符
        XCTAssertFalse(result.isEmpty)
        XCTAssertTrue(result.contains("x"))
    }

    func testProcess_textWithinMaxRawLength_buffersEntireRemaining() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])

        let shortText = "[ENT" + String(repeating: "x", count: 15)
        let result = deanonymizer.process(chunk: shortText)

        // 未超过 maxRawLength(25)，全部缓存，不输出
        XCTAssertEqual(result, "")
    }

    // MARK: - finalize

    func testFinalize_emptyBuffer_returnsEmpty() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        _ = deanonymizer.process(chunk: "完整文本")
        let remaining = deanonymizer.finalize()
        XCTAssertEqual(remaining, "")
    }

    func testFinalize_nonEmptyBuffer_returnsBufferContent() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        _ = deanonymizer.process(chunk: "文本[ENTI")
        let remaining = deanonymizer.finalize()
        XCTAssertEqual(remaining, "[ENTI")
    }

    func testFinalize_afterPartialPlaceholder_returnsUnresolvedBuffer() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        _ = deanonymizer.process(chunk: "前文[ENTITY_")
        let remaining = deanonymizer.finalize()
        XCTAssertEqual(remaining, "[ENTITY_")
    }

    // MARK: - 混合场景

    func testProcess_mixedKnownAndUnknownPlaceholders() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三", "[ENTITY_2]": "李四"])
        let result = deanonymizer.process(chunk: "[ENTITY_1]提到[REF_001]和[ENTITY_2]")
        XCTAssertEqual(result, "张三提到[REF_001]和李四")
    }

    func testProcess_bracketNotPartOfPlaceholder_passesThrough() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        let result = deanonymizer.process(chunk: "数组[0]和[ENTITY_1]")
        XCTAssertEqual(result, "数组[0]和张三")
    }

    func testProcess_consecutivePlaceholders() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三", "[ENTITY_2]": "李四"])
        let result = deanonymizer.process(chunk: "[ENTITY_1][ENTITY_2]")
        XCTAssertEqual(result, "张三李四")
    }

    func testProcess_placeholderAtStart() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        let result = deanonymizer.process(chunk: "[ENTITY_1]开始")
        XCTAssertEqual(result, "张三开始")
    }

    func testProcess_placeholderAtEnd() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        let result = deanonymizer.process(chunk: "结束[ENTITY_1]")
        XCTAssertEqual(result, "结束张三")
    }

    func testProcess_onlyPlaceholder() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        let result = deanonymizer.process(chunk: "[ENTITY_1]")
        XCTAssertEqual(result, "张三")
    }

    // MARK: - 多轮 process + finalize 集成

    func testProcessMultipleChunksThenFinalize_completeRestoration() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三", "[ENTITY_2]": "李四"])

        var output = ""
        output += deanonymizer.process(chunk: "今天[ENTITY_1]和")
        output += deanonymizer.process(chunk: "[ENTITY_2]讨论了")
        output += deanonymizer.process(chunk: "项目方案")
        output += deanonymizer.finalize()

        XCTAssertEqual(output, "今天张三和李四讨论了项目方案")
    }

    func testProcessChunkWithTrailingIncompleteThenFinalize() {
        var deanonymizer = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])

        var output = ""
        output += deanonymizer.process(chunk: "你好[ENTITY_1]，再见[ENT")
        output += deanonymizer.finalize()

        XCTAssertEqual(output, "你好张三，再见[ENT")
    }
}
