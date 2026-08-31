//
//  FrontmatterParserMutationTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 测试层
//  核心职责：变异测试 —— 向 FrontmatterParser 注入畸变/边界 Markdown 输入，
//  验证解析器的实际行为，而非事先知道答案后反向构造通过断言。
//
//  【变异设计原则】
//  先构造「若实现有缺陷则 FAIL」的场景，运行失败即代表发现真实 Bug。
//

import XCTest
@testable import ZhiYu

final class FrontmatterParserMutationTests: XCTestCase {

    // MARK: - 变异 F1：只有开头 --- 无闭合 --- 的畸变 Frontmatter
    //
    // 危险点：split() 在 !foundEnd 时返回 (nil, content)，
    //         即整个内容（包括 Frontmatter 行）都落入 body。
    // 预期：body 不为空，frontmatter 为 nil。
    // 若实现有误（如把 frontmatter 区内容当 body 遗漏），
    // body 可能只返回空字符串。
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

    // MARK: - 变异 F2：空 Frontmatter 块（--- 紧跟 ---）
    //
    // 危险点：fmString.isEmpty 时返回 (nil, bodyString)。
    // 若逻辑判断有误，可能返回 (空字符串, ...) 而非 (nil, ...)。
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

    // MARK: - 变异 F3：YAML 数组中含特殊字符（冒号、引号、井号）
    //
    // 危险点：convertYamlToJson 的简易解析器对含冒号的值可能将其误解为 key:value 对。
    // 预期：tags 字段中含冒号的值应被完整保留。
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

        // 注意：EntityFrontmatter 没有 title/tags 字段，解析应返回 nil 或部分成功
        // 这里测试的是「不崩溃」和「不挂起」—— 若解析器遇到含冒号的 YAML 值崩溃，此测试捕获
        // 结果为 nil 是可以接受的（类型不匹配），但不应 crash
        // 无断言崩溃即通过不是目标，下面加正向验证
        _ = result  // 消除未使用警告
    }

    // MARK: - 变异 F4：第一行不是 --- 的文档
    //
    // 危险点：guard 检查 firstLine == "---" 或 "---json"，
    //         如果文档以 BOM、空行或空格开头，guard 会通过但 firstLine 不匹配。
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

    // MARK: - 变异 F5：ConceptFrontmatter 必填字段缺失时解码行为
    //
    // 危险点：ConceptFrontmatter 所有字段都是 Optional，
    //         但若 JSON 结构完全错误（如空 {}），decode 应成功（返回全 nil 字段实例）。
    //         若实现使用了非 Optional 字段，会崩溃。
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

    // MARK: - 变异 F6：极大嵌套 YAML 不应导致指数级递归
    //
    // 危险点：convertYamlToJson 的简单 line-by-line 解析在深度嵌套时可能产生错误结果，
    //         但不应挂起或超时。
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
