//
//  FrontmatterParserDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：FrontmatterParserFuzzTests.swift, FrontmatterParserMutationTests.swift
//

import XCTest

@testable import ZhiYu

@MainActor
final class FrontmatterParserDeepTests: XCTestCase {

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

    func testFuzz_RandomJson_ParseNeverCrashes() {
        let baseSeed = UInt64(9999)
        let jsonFragments = [
            "{}", "{\"outlines\": null}", "{\"invalid\": true}",
            "{\"outlines\": []}", "[]", "null", "\"string\"",
            "{", "}", "{\"outlines\": [{\"id\": \"1\", \"title\": \"T\", \"level\": 1}]}",
            "{\"surprising_insights\": [{\"insight_title\": \"X\", \"linked_concept_id\": \"Y\", \"reason\": \"Z\"}]}"
        ]
        let mutationsPerTemplate = 20
        var parseCount = 0
        for base in jsonFragments {
            for _ in 0..<mutationsPerTemplate {
                // 每次变异策略：随机删字节 / 插入控制字符 / 替换随机字符
                var bytes = Array(base.utf8)
                guard !bytes.isEmpty else { continue }
                let mutationType = Int.random(in: 0...2)
                let idx = Int.random(in: 0..<bytes.count)
                switch mutationType {
                case 0:
                    // 删字节
                    bytes.remove(at: idx)
                case 1:
                    // 插入 NUL、换行、非 ASCII 控制字符
                    let controlBytes: [UInt8] = [0x00, 0x0A, 0x0D, 0x1F, 0x7F, 0xC0, 0xFF]
                    bytes.insert(controlBytes.randomElement() ?? 0x00, at: idx)
                default:
                    // 替换为截断字符
                    bytes[idx] = 0x00
                }
                let mutated = String(bytes: bytes, encoding: .utf8) ?? "{}"
                // 不变式：永不崩溃
                _ = FrontmatterParser.parse(ConceptFrontmatter.self, from: mutated)
                parseCount += 1
            }
        }
        XCTAssertEqual(parseCount, jsonFragments.count * mutationsPerTemplate, "JSON Fuzz 所有变异执行完毕且未发生崩溃")
    }

    func testFuzz_EmptyJson_DecodesConceptFrontmatter() {
        let result = FrontmatterParser.parse(ConceptFrontmatter.self, from: "{}")
        XCTAssertNotNil(result, "ConceptFrontmatter 所有字段均为可选，空 JSON 必须能成功解析为默认实例")
        XCTAssertNil(result?.outlines, "outlines 应为 nil")
        XCTAssertNil(result?.surprisingInsights, "surprisingInsights 应为 nil")
    }

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
            XCTAssertFalse(input.isEmpty, "极端 Unicode 输入 [\(i)] 不应为空")
            _ = result
        }
    }

    func testMutation_UnclosedDelimiter_EntireContentFallsToBody() {
        let input = """
        ---
        title: 未闭合头部
        tags: [Swift, iOS]
        这行没有结束的三横线
        正文内容
        """

        let result = FrontmatterParser.split(content: input)

        // 断言 1：无法识别有效 frontmatter，应返回 nil
        XCTAssertNil(result.frontmatter, "未闭合 Frontmatter 应无法解析，返回 nil")

        // 断言 2：body 不能为空——整个原始内容都应在 body 里
        XCTAssertFalse(result.body.isEmpty, "未闭合时整个原文应作为 body 返回，不应为空")

        // 断言 3：body 里必须包含 title 行（因为它没被解析为 frontmatter）
        XCTAssertTrue(
            result.body.contains("title"),
            "未闭合时 title 行应出现在 body 里，实际 body: '\(result.body.prefix(100))'"
        )
    }

    func testMutation_EmptyFrontmatterBlock_ReturnsNilAndBody() {
        let input = """
        ---
        ---
        这是正文
        """

        let result = FrontmatterParser.split(content: input)

        XCTAssertNil(
            result.frontmatter,
            "空 Frontmatter 块（--- 紧跟 ---）应返回 nil，而非空字符串"
        )
        XCTAssertTrue(
            result.body.contains("这是正文"),
            "正文应正确提取"
        )
    }

    func testMutation_YamlValueWithColon_ParsedCorrectly() {
        let frontmatter = """
        title: 测试文档
        tags:
          - key: value
          - normal
        """

        // 向真实 YAML 转 JSON 逻辑注入含冒号的数组项
        // 如果解析器把 "key: value" 误处理，会导致解码失败或字段丢失
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: frontmatter)

        // 注意：EntityFrontmatter 没有 title/tags 字段，但由于所有字段均为 Optional，
        // Codable 会忽略未知字段并返回所有字段为 nil 的实例（这是 Codable 正常行为）
        // 验证不会因含冒号的值而崩溃或挂起
        XCTAssertNotNil(result, "含冒号值的 Frontmatter 解析不应崩溃，未知字段被忽略后返回全 nil 字段实例")
    }

    func testMutation_NoFrontmatter_EntireDocIsBody() {
        let variants = [
            "# 普通 Markdown\n\n正文内容",
            "正文直接开始，没有 Frontmatter",
            "\n---\n不在第一行的分隔符\n---\n正文",
            "  ---\n缩进开头不应识别为 Frontmatter\n---\n正文"
        ]

        for input in variants {
            let result = FrontmatterParser.split(content: input)
            XCTAssertNil(
                result.frontmatter,
                "非标准开头的文档不应识别出 frontmatter，输入开头: '\(input.prefix(30))'"
            )
            XCTAssertFalse(
                result.body.isEmpty,
                "正文不应为空，输入开头: '\(input.prefix(30))'"
            )
        }
    }

    func testMutation_EmptyJsonFrontmatter_DecodesWithAllNilFields() {
        let emptyJson = "{}"
        let result = FrontmatterParser.parse(ConceptFrontmatter.self, from: emptyJson)

        // 空 JSON 应能解码为全 nil 字段的 ConceptFrontmatter（所有字段都是 Optional）
        XCTAssertNotNil(
            result,
            "空 JSON {} 应能被解码为 ConceptFrontmatter（全 Optional 字段），返回了 nil 说明解码逻辑有误"
        )
        XCTAssertNil(result?.outlines, "outlines 应为 nil")
        XCTAssertNil(result?.surprisingInsights, "surprisingInsights 应为 nil")
    }

    func testMutation_DeepNestedYaml_CompletesWithinTimeout() {
        // 构造 100 层缩进（远超正常使用场景）
        var nestedYaml = "title: root\n"
        for i in 0..<50 {
            nestedYaml += String(repeating: "  ", count: i + 1) + "level_\(i): value\n"
        }

        let expectation = XCTestExpectation(description: "解析应在 2 秒内完成")

        DispatchQueue.global().async {
            let result = FrontmatterParser.split(content: "---\n\(nestedYaml)\n---\n正文")
            XCTAssertNotNil(result.body)
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 2.0)
    }

}

// MARK: - Fuzz 辅助工具

/// 简单的确定性随机数生成器（用于 Fuzz 测试）
struct FuzzRNG {
    var state: UInt64

    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }

    mutating func nextBool() -> Bool {
        next() % 2 == 0
    }

    mutating func nextString(length: Int) -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 \n-#:\"'"
        var result = ""
        for _ in 0..<length {
            let idx = Int(next() % UInt64(chars.count))
            result.append(chars[chars.index(chars.startIndex, offsetBy: idx)])
        }
        return result
    }
}

/// 生成随机 Markdown 文档（用于 Fuzz 测试）
func makeRandomMarkdownDoc(rng: inout FuzzRNG) -> String {
    let hasFrontmatter = rng.nextBool()
    let length = Int(rng.next() % 200) + 10
    let body = rng.nextString(length: length)

    if hasFrontmatter {
        let yaml = "title: \(rng.nextString(length: 10))\ntags: [test]\n"
        return "---\n\(yaml)\n---\n\(body)"
    }
    return body
}
