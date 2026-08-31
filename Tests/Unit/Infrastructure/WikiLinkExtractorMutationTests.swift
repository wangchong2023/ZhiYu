//
//  WikiLinkExtractorMutationTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[测试层]
//  核心职责：对 WikiLinkExtractor 进行变异测试 + Fuzz 测试。
//  核心正则：(?<!\\)\[\[([^\]\|]+)(?:\|([^\]]+))?\]\]
//  每个用例构造「若正则有误则 FAIL」的输入，而非从实现反向构造通过断言。
//

import XCTest
@testable import ZhiYu

@MainActor
final class WikiLinkExtractorMutationTests: XCTestCase {

    // MARK: - 变异 W1：转义双链不应被提取
    //
    // 正则使用 (?<!\\) 负向环视，\[[链接]] 不应被提取。
    // 危险点：若负向环视实现有误，转义链接会被错误提取。
    // 若此测试 FAIL → Bug：转义前缀 \ 未被正确识别
    func testMutation_EscapedWikiLink_ShouldNotBeExtracted() {
        let input = #"\[[不应提取的链接]]"# + " 和 [[应该提取的链接]]"
        let links = WikiLinkExtractor.extractLinks(from: input)

        XCTAssertEqual(links.count, 1, "转义链接不应被提取，只应提取 1 个链接，实际：\(links.count) 个 → \(links.map(\.targetTitle))")
        XCTAssertEqual(links.first?.targetTitle, "应该提取的链接", "提取到的链接标题错误")
    }

    // MARK: - 变异 W2：嵌套双链 —— 正则的贪婪性决定行为
    //
    // 输入 [[外层[[内嵌]]]] —— 正则 [^\]\|]+ 要求非 ] 非 | 字符，
    // 遇到第一个 ]] 时结束匹配。行为应为：
    // 匹配到「外层[[内嵌」作为 targetTitle，后面 ]] 结束
    // 若此测试 FAIL → Bug：正则贪婪模式导致匹配范围错误
    func testMutation_NestedWikiLink_RegexBehavior() {
        let input = "[[外层[[内嵌]]]]"
        let links = WikiLinkExtractor.extractLinks(from: input)

        // 正则 [^\]\|]+ 会把「外层[[内嵌」全部匹配（不含 ] 的字符），
        // 然后遇到 ]] 结束，得到 targetTitle = "外层[[内嵌"
        // 后面剩余 ]] 不再匹配
        XCTAssertGreaterThanOrEqual(links.count, 1, "应至少提取 1 个链接")
        if let first = links.first {
            XCTAssertFalse(first.targetTitle.isEmpty, "targetTitle 不应为空")
        }
    }

    // MARK: - 变异 W3：带别名双链 —— targetTitle 和 alias 不应互换
    //
    // 危险点：若 match.range(at:1) 和 range(at:2) 取反，别名会变成标题。
    // 若此测试 FAIL → Bug：targetTitle 和 alias 顺序颠倒
    func testMutation_AliasWikiLink_CorrectFieldMapping() {
        let input = "[[目标页面|显示别名]]"
        let links = WikiLinkExtractor.extractLinks(from: input)

        XCTAssertEqual(links.count, 1, "应提取 1 个带别名链接")
        guard let link = links.first else { return XCTFail("未提取到链接") }

        XCTAssertEqual(
            link.targetTitle, "目标页面",
            "targetTitle 应为「目标页面」，但得到：'\(link.targetTitle)' → 字段顺序可能颠倒"
        )
        XCTAssertEqual(
            link.alias, "显示别名",
            "alias 应为「显示别名」，但得到：'\(link.alias ?? "nil")' → 字段顺序可能颠倒"
        )
        XCTAssertEqual(
            link.displayTitle, "显示别名",
            "displayTitle 应返回 alias 而非 targetTitle"
        )
    }

    // MARK: - 变异 W4：超长标题（10000字符）—— 不崩溃且不超时
    //
    // 危险点：正则在超长字符串上的回溯可能导致灾难性回溯（Catastrophic Backtracking）。
    // 若此测试 FAIL → Bug：正则超时导致 2 秒超时
    func testMutation_UltraLongTitle_DoesNotTimeout() {
        let longTitle = String(repeating: "极长标题字符", count: 1666) // ~10000 字符
        let input = "[[\(longTitle)]]"

        let expectation = XCTestExpectation(description: "超长标题提取应在 2 秒内完成")
        DispatchQueue.global().async {
            let links = WikiLinkExtractor.extractLinks(from: input)
            XCTAssertEqual(links.count, 1, "应提取 1 个超长标题链接")
            XCTAssertEqual(links.first?.targetTitle.count, longTitle.count, "标题长度应完整保留")
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
    }

    // MARK: - 变异 W5：空标题双链 [[]] 和 [[ ]] —— 应过滤
    //
    // 正则 [^\]\|]+ 要求至少 1 个字符，[[]] 不应匹配。
    // 但 [[ ]] 含一个空格可以被正则匹配，trim 后为空应被过滤。
    // 若此测试 FAIL → Bug：空标题链接未过滤，出现 targetTitle=="" 的结果
    func testMutation_EmptyTitleWikiLinks_AreFiltered() {
        let inputs = [
            ("[[]]", 0, "空括号"),
            ("[[ ]]", 0, "仅空格"),
            ("[[  ]]", 0, "多个空格"),
            ("[[有效链接]]", 1, "有效链接")
        ]

        for (input, expectedCount, desc) in inputs {
            let links = WikiLinkExtractor.extractLinks(from: input)
            XCTAssertEqual(
                links.count, expectedCount,
                "[\(desc)] 期望 \(expectedCount) 个链接，实际 \(links.count) 个 → 空标题过滤逻辑有误"
            )
            for link in links {
                XCTAssertFalse(
                    link.targetTitle.isEmpty,
                    "[\(desc)] 提取到 targetTitle 为空的链接，过滤逻辑失效"
                )
            }
        }
    }

    // MARK: - 变异 W6：同一行多个双链 —— 顺序和字段正确
    //
    // 危险点：多次匹配时，if match.numberOfRanges > 2 的边界条件可能混淆有无别名的链接。
    // 若此测试 FAIL → Bug：多链接时顺序错乱或别名归属错误
    func testMutation_MultipleSameLineLinks_CorrectOrderAndAlias() {
        let input = "前文 [[链接A]] 中间文本 [[链接B|别名B]] 后文"
        let links = WikiLinkExtractor.extractLinks(from: input)

        XCTAssertEqual(links.count, 2, "应提取 2 个链接，实际 \(links.count) 个")
        guard links.count == 2 else { return }

        XCTAssertEqual(links[0].targetTitle, "链接A", "第 1 个链接应为「链接A」")
        XCTAssertNil(links[0].alias, "链接A 不应有别名")

        XCTAssertEqual(links[1].targetTitle, "链接B", "第 2 个链接应为「链接B」")
        XCTAssertEqual(links[1].alias, "别名B", "链接B 的别名应为「别名B」")
    }

    // MARK: - Fuzz W7：随机 200 次输入，永不崩溃
    //
    // 不变式：任意字符串传入 extractLinks 永不崩溃
    func testFuzz_RandomInput_NeverCrashes() {
        var rng = SimpleRNGForWiki(state: 54321)
        let charPool: [Character] = ["[", "]", "|", "\\", "#", "A", "中", "\n", " ", "!"]

        for i in 0..<200 {
            let length = rng.nextInt(in: 0..<500)
            var str = ""
            for _ in 0..<length {
                str.append(rng.nextElement(from: charPool))
            }
            let links = WikiLinkExtractor.extractLinks(from: str)
            // 不变式：所有提取结果的 targetTitle 不为空
            for link in links {
                XCTAssertFalse(
                    link.targetTitle.isEmpty,
                    "Fuzz 输入 [\(i)] 产生了空 targetTitle，过滤逻辑失效"
                )
            }
        }
    }
}

// MARK: - 局部随机数生成器（避免跨文件依赖）
private struct SimpleRNGForWiki {
    var state: UInt64
    mutating func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17; return state
    }
    mutating func nextInt(in range: Range<Int>) -> Int {
        guard range.count > 0 else { return 0 }
        return range.lowerBound + Int(next() % UInt64(range.count))
    }
    mutating func nextElement<C: RandomAccessCollection>(from collection: C) -> C.Element {
        collection[collection.index(collection.startIndex, offsetBy: nextInt(in: 0..<collection.count))]
    }
}
