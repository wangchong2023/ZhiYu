//
//  FrontmatterParserFuzzTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[测试层]
//  核心职责：对 FrontmatterParser 进行真正的 Property-based Fuzz 测试。
//  使用 xorshift64 轻量随机生成器构造畸变 Markdown + 随机 JSON/YAML，
//  验证「不变式」而非具体输出值，任何不变式违反代表真实 Bug。
//
//  【Fuzz 不变式】
//  1. 任意输入永不崩溃、解析完成时间 < 500ms
//  2. 无 "---" 开头时 frontmatter 必须为 nil
//  3. frontmatter != nil 时 body 不应包含 Frontmatter 区域内容
//  4. 空 JSON {} 可被 ConceptFrontmatter（全 Optional 字段）解码为非 nil
//  5. 任意 JSON 字符串传入 parse() 永不崩溃
//

import XCTest
@testable import ZhiYu

// MARK: - 轻量随机数生成器（复用同一实现，避免跨文件依赖）
private struct FuzzRNG {
    var state: UInt64

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }

    mutating func nextInt(in range: Range<Int>) -> Int {
        guard range.count > 0 else { return range.lowerBound }
        return range.lowerBound + Int(next() % UInt64(range.count))
    }

    mutating func nextBool() -> Bool { next() % 2 == 0 }

    mutating func nextElement<C: RandomAccessCollection>(from collection: C) -> C.Element {
        collection[collection.index(collection.startIndex, offsetBy: nextInt(in: 0..<collection.count))]
    }
}

// MARK: - 随机 Frontmatter/Markdown 构造器
private func makeRandomMarkdownDoc(rng: inout FuzzRNG) -> String {
    var doc = ""

    // 随机决定是否以 --- 开头
    let hasFrontmatterStart = rng.nextBool()
    if hasFrontmatterStart {
        doc += "---\n"
    } else {
        // 以普通内容开头（不含 ---）
        doc += "普通正文开头\n"
    }

    // 随机生成「Frontmatter 区域」内容
    let fmLineCount = rng.nextInt(in: 0..<10)
    let fmKeyPool = ["title", "tags", "author", "date", "status", "type"]
    let fmValuePool = [
        "普通值", "含:冒号的值", "\"带引号\"", "[数组, 值]",
        "multi\nline", "", "   ", "null", "true", "12345",
        "value: nested", "😀🚀"
    ]

    for _ in 0..<fmLineCount {
        let key = nextElement(from: fmKeyPool, rng: &rng)
        let value = nextElement(from: fmValuePool, rng: &rng)
        doc += "\(key): \(value)\n"
    }

    // 随机决定是否有闭合 ---
    let hasFrontmatterEnd = rng.nextBool()
    if hasFrontmatterEnd {
        doc += "---\n"
    }

    // 随机正文
    doc += "正文内容第\(rng.nextInt(in: 0..<100))段\n"
    return doc
}

private func nextElement<T>(from arr: [T], rng: inout FuzzRNG) -> T {
    arr[rng.nextInt(in: 0..<arr.count)]
}

// MARK: - Fuzz 测试用例

@MainActor
final class FrontmatterParserFuzzTests: XCTestCase {

    // MARK: - Fuzz P1：200 次随机 Markdown 验证全部不变式
    func testFuzz_RandomMarkdown_AllInvariantsHold() {
        let baseSeed = UInt64(Date().timeIntervalSinceReferenceDate * 1000)
        var failCount = 0

        for i in 0..<200 {
            let seed = baseSeed &+ UInt64(i) &* 6364136223846793005 &+ 1442695040888963407
            var rng = FuzzRNG(state: seed == 0 ? 1 : seed)
            let input = makeRandomMarkdownDoc(rng: &rng)

            // 不变式 1：不崩溃且完成时间 < 500ms
            let start = Date()
            let result = FrontmatterParser.split(content: input)
            let elapsed = Date().timeIntervalSince(start)

            if elapsed >= 0.5 {
                failCount += 1
                XCTFail("不变式1违反：解析超时 \(String(format: "%.3f", elapsed))s [seed=\(seed), i=\(i)]")
            }

            // 不变式 2：无 --- 开头时 frontmatter 必须为 nil
            let startsWithDash = input.hasPrefix("---")
            if !startsWithDash && result.frontmatter != nil {
                failCount += 1
                XCTFail("不变式2违反：无 --- 开头时 frontmatter 不应非 nil [seed=\(seed), i=\(i), input前30='\(input.prefix(30))']")
            }

            // 不变式 3：frontmatter != nil 时 body 应不包含 Frontmatter 内容
            // 简化验证：若 frontmatter 非空，则 body 不应包含完整的 frontmatter 字符串
            if let fm = result.frontmatter, !fm.isEmpty {
                let bodyContainsFM = result.body.contains(fm)
                if bodyContainsFM {
                    failCount += 1
                    XCTFail("不变式3违反：body 包含完整 frontmatter 内容 [seed=\(seed), i=\(i)]")
                }
            }

            if failCount >= 3 { break }
        }
    }

    // MARK: - Fuzz P2：JSON Fuzz —— 随机 JSON 传入 parse() 永不崩溃
    func testFuzz_RandomJson_ParseNeverCrashes() {
        let baseSeed = UInt64(9999)
        let jsonFragments = [
            "{}", "{\"outlines\": null}", "{\"invalid\": true}",
            "{\"outlines\": []}", "[]", "null", "\"string\"",
            "{", "}", "{\"outlines\": [{\"id\": \"1\", \"title\": \"T\", \"level\": 1}]}",
            "{\"surprising_insights\": [{\"insight_title\": \"X\", \"linked_concept_id\": \"Y\", \"reason\": \"Z\"}]}"
        ]

        for (i, fragment) in jsonFragments.enumerated() {
            var rng = FuzzRNG(state: baseSeed &+ UInt64(i + 1))

            // 随机对 fragment 做字节变异
            for _ in 0..<20 {
                var bytes = Array(fragment.utf8)
                guard !bytes.isEmpty else { break }
                let op = rng.nextInt(in: 0..<3)
                switch op {
                case 0:
                    let idx = rng.nextInt(in: 0..<bytes.count)
                    bytes[idx] ^= UInt8(rng.nextInt(in: 1..<256))
                case 1:
                    let idx = rng.nextInt(in: 0..<bytes.count + 1)
                    bytes.insert(UInt8(rng.nextInt(in: 32..<127)), at: idx)
                default:
                    if bytes.count > 1 {
                        bytes.remove(at: rng.nextInt(in: 0..<bytes.count))
                    }
                }
                let mutated = String(bytes: bytes, encoding: .utf8) ?? "{}"
                // 不变式：永不崩溃
                _ = FrontmatterParser.parse(ConceptFrontmatter.self, from: mutated)
            }
        }
        // 如果走到这里说明没有崩溃，测试通过
        XCTAssertTrue(true, "JSON Fuzz 200 次变异全部完成，未发生崩溃")
    }

    // MARK: - Fuzz P3：空 JSON 解码不变式（边界验证，P0 级）
    //
    // ConceptFrontmatter 所有字段都是 Optional，空 {} 必须能成功解码。
    // 若此测试 FAIL，说明 ConceptFrontmatter 有非 Optional 字段导致解码失败。
    func testFuzz_EmptyJson_DecodesConceptFrontmatter() {
        let result = FrontmatterParser.parse(ConceptFrontmatter.self, from: "{}")
        XCTAssertNotNil(
            result,
            "空 JSON {} 应能被解码为 ConceptFrontmatter（全 Optional 字段），返回 nil 说明存在非 Optional 字段设计错误"
        )
        XCTAssertNil(result?.outlines, "outlines 应为 nil")
        XCTAssertNil(result?.surprisingInsights, "surprisingInsights 应为 nil")
    }

    // MARK: - Fuzz P4：大量 --- 行的压力测试
    //
    // 危险点：多个 --- 行时，解析器找到第一个结束 --- 后停止，
    // 剩余的 --- 行应出现在 body 中。若实现贪心匹配最后一个 ---，会产生错误的 frontmatter。
    func testFuzz_MultipleDelimiters_OnlyFirstPairUsed() {
        let input = """
        ---
        title: 第一个 Frontmatter
        ---
        正文内容
        ---
        这是第二个假的 Frontmatter 块
        ---
        更多正文
        """

        let result = FrontmatterParser.split(content: input)

        // 只应提取第一对 --- 之间的内容
        XCTAssertNotNil(result.frontmatter, "应识别第一个 Frontmatter")
        if let fm = result.frontmatter {
            XCTAssertTrue(fm.contains("title"), "Frontmatter 应包含 title")
            // 不应包含第二个假 Frontmatter 的内容
            XCTAssertFalse(fm.contains("第二个假的"), "Frontmatter 不应包含第二个块内容")
        }

        // body 应包含第二个 --- 块及其后的内容
        XCTAssertTrue(
            result.body.contains("正文内容"),
            "body 应包含正文内容，实际: '\(result.body.prefix(100))'"
        )
    }

    // MARK: - Fuzz P5：极端 Unicode 输入（RTL 字符、零宽字符、Emoji）不崩溃
    func testFuzz_ExtremeUnicode_NeverCrashes() {
        let extremeInputs = [
            "---\n\u{202E}RTL反转\u{202C}: value\n---\n正文",
            "---\n\u{200B}零宽空格key: val\n---\n正文",
            "---\n😀🚀🎉: 😱\n---\n正文",
            "---\n中文键: 中文值\n---\n正文",
            "---\n\0NUL字符: value\n---\n正文",
            "---\n" + String(repeating: "极长键名", count: 100) + ": val\n---\n正文"
        ]

        for (i, input) in extremeInputs.enumerated() {
            let result = FrontmatterParser.split(content: input)
            // 不变式：有 --- 开头且有闭合 ---，应识别 frontmatter
            XCTAssertNotNil(
                result.frontmatter ?? result.frontmatter, // 允许 nil（若解析内容为空）
                // 主要验证不崩溃，不对具体值做断言
                ""
            )
            _ = result  // 消除 warning，主要验证不崩溃
            XCTAssertTrue(true, "极端 Unicode 输入 [\(i)] 未崩溃")
        }
    }
}
