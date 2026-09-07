//
//  PluginLoaderDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：ChatRunnerAndPluginLoaderDeepTests.swift, PluginLoaderSecurityInteractiveTests.swift
//

import CryptoKit
import Dependencies
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class PluginLoaderDeepTests: XCTestCase {

    func testLongBracketContentWithClosingBracketIsStillReplaced() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_VERY_LONG_NAME_EXCEEDING_LIMIT]": "张三"])
        // 构造一个超过 25 字符的方括号内容，但有闭合 ']'
        let longContent = "[ENTITY_VERY_LONG_NAME_EXCEEDING_LIMIT]"
        let result = deanon.process(chunk: longContent)
        // 找到 ']' 时，即使超过 maxRawLength 也会尝试还原
        XCTAssertEqual(result, "张三", "完整方括号内容即使超过 maxRawLength 也应被还原")
    }

    func testLongBracketContentWithoutClosingBracketOutputsImmediately() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_VERY_LONG_NAME_EXCEEDING_LIMIT]": "张三"])
        // 构造一个超过 25 字符的方括号内容，但无闭合 ']'
        let longUnclosed = "[ENTITY_VERY_LONG_NAME_EXCEEDING_LIMIT_WITHOUT_CLOSING"
        let result = deanon.process(chunk: longUnclosed)
        // 无闭合 ']' 且超过 maxRawLength 时直接输出，不缓存
        XCTAssertEqual(result, longUnclosed, "超过 maxRawLength 且无闭合 ']' 的内容应直接输出")
    }

    func testFinalizeReturnsUnresolvedBufferWithPartialPlaceholder() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])
        _ = deanon.process(chunk: "text [ENTITY_")
        let remaining = deanon.finalize()
        // finalize 返回 "[ENTITY_"，这是未完成的占位符
        XCTAssertEqual(remaining, "[ENTITY_", "finalize 应返回未完成的 buffer")
    }

    func testEmptyMappingPassesEntityPlaceholdersThrough() {
        var deanon = StreamDeanonymizer(mapping: [:])
        let result = deanon.process(chunk: "Hello [ENTITY_A] world")
        XCTAssertEqual(result, "Hello [ENTITY_A] world", "空 mapping 时占位符应直接输出")
    }

    func testPlaceholderSplitBeforeBracketBuffersNothing() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])
        let chunk1 = "Hello "
        let chunk2 = "[ENTITY_A]"

        let result1 = deanon.process(chunk: chunk1)
        let result2 = deanon.process(chunk: chunk2)

        XCTAssertEqual(result1, "Hello ")
        XCTAssertEqual(result2, "张三")
    }

    func testConsecutivePlaceholdersSecondSplit() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三", "[ENTITY_B]": "李四"])
        let result1 = deanon.process(chunk: "[ENTITY_A][ENTITY_")
        let result2 = deanon.process(chunk: "B]")

        XCTAssertEqual(result1, "张三")
        XCTAssertEqual(result2, "李四")
    }

    func testMarkdownLinkNotTreatedAsPlaceholder() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])
        let result = deanon.process(chunk: "See [link](url) and [ENTITY_A]")
        XCTAssertEqual(result, "See [link](url) and 张三")
    }

    func testBufferAccumulatesAcrossMultipleProcessCalls() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])
        let r1 = deanon.process(chunk: "text [")
        let r2 = deanon.process(chunk: "ENT")
        let r3 = deanon.process(chunk: "ITY_")
        let r4 = deanon.process(chunk: "A]")

        XCTAssertEqual(r1, "text ")
        XCTAssertEqual(r2, "")
        XCTAssertEqual(r3, "")
        XCTAssertEqual(r4, "张三")
    }

    func testConstantTimeCompare_withIdenticalData_returnsTrue() {
        let dataA = Data([0x01, 0x02, 0x03, 0x04, 0xFF])
        let dataB = Data([0x01, 0x02, 0x03, 0x04, 0xFF])
        XCTAssertTrue(PluginLoader.constantTimeCompare(dataA, b: dataB))
    }

    func testConstantTimeCompare_withDifferentDataSameLength_returnsFalse() {
        let dataA = Data([0x01, 0x02, 0x03, 0x04, 0xFF])
        let dataB = Data([0x01, 0x02, 0x03, 0x04, 0xFE])
        XCTAssertFalse(PluginLoader.constantTimeCompare(dataA, b: dataB))
    }

    func testConstantTimeCompare_withDifferentLengths_returnsFalse() {
        let dataA = Data([0x01, 0x02, 0x03])
        let dataB = Data([0x01, 0x02, 0x03, 0x04])
        XCTAssertFalse(PluginLoader.constantTimeCompare(dataA, b: dataB))
        XCTAssertFalse(PluginLoader.constantTimeCompare(dataB, b: dataA))
    }

    func testConstantTimeCompare_withEmptyData_returnsTrueForBothEmpty() {
        let emptyA = Data()
        let emptyB = Data()
        let nonEmpty = Data([0xAA])
        XCTAssertTrue(PluginLoader.constantTimeCompare(emptyA, b: emptyB))
        XCTAssertFalse(PluginLoader.constantTimeCompare(emptyA, b: nonEmpty))
    }

    func testVerifyPluginSignature_withMissingOrEmptySignature_isRejected() {
        let script = "console.log('hello world');"
        
        // 缺少 codeSignature 字段
        let manifestWithoutSig = PluginManifest(
            id: "com.test.nosig",
            version: "1.0.0",
            author: "Test",
            permissions: [],
            names: ["en": "NoSigPlugin"],
            descriptions: ["en": "No Signature"],
            codeSignature: nil
        )
        XCTAssertFalse(PluginLoader.verifyPluginSignature(script: script, manifest: manifestWithoutSig))

        // codeSignature 为空字符串
        let manifestWithEmptySig = PluginManifest(
            id: "com.test.emptysig",
            version: "1.0.0",
            author: "Test",
            permissions: [],
            names: ["en": "EmptySigPlugin"],
            descriptions: ["en": "Empty Signature"],
            codeSignature: ""
        )
        XCTAssertFalse(PluginLoader.verifyPluginSignature(script: script, manifest: manifestWithEmptySig))
    }

    func testVerifyPluginSignature_withExternalManifestUsingLocalPrefix_isRejected() {
        let script = "console.log('malicious');"
        let spoofedManifest = PluginManifest(
            id: "local.spoofed.plugin",
            version: "1.0.0",
            author: "Attacker",
            permissions: [],
            names: ["en": "Spoofed"],
            descriptions: ["en": "Attempting to bypass signature using local prefix"],
            codeSignature: "1234567890abcdef"
        )
        // 外部 manifest 即使带 local. 前缀也必须被拦截
        XCTAssertFalse(PluginLoader.verifyPluginSignature(script: script, manifest: spoofedManifest, isTrustedLocal: false))
    }

    func testVerifyPluginSignature_withTrustedLocal_isAllowed() {
        let script = "console.log('trusted internal');"
        let trustedManifest = PluginManifest(
            id: "local.user.script",
            version: "1.0.0",
            author: "User",
            permissions: [],
            names: ["en": "Trusted Local"],
            descriptions: ["en": "User script"],
            codeSignature: nil
        )
        // 内部 loadPluginFromRawJS 生成的标记为 isTrustedLocal 的允许跳过签名
        XCTAssertTrue(PluginLoader.verifyPluginSignature(script: script, manifest: trustedManifest, isTrustedLocal: true))
    }

    func testVerifyPluginSignature_withInvalidHexSignature_isRejected() {
        let script = "console.log('test');"
        let manifestWithInvalidHex = PluginManifest(
            id: "com.test.invalidhex",
            version: "1.0.0",
            author: "Test",
            permissions: [],
            names: ["en": "InvalidHex"],
            descriptions: ["en": "Invalid hex signature"],
            codeSignature: "ZZZZZZZZ_NOT_HEX"
        )
        XCTAssertFalse(PluginLoader.verifyPluginSignature(script: script, manifest: manifestWithInvalidHex))
    }

}
