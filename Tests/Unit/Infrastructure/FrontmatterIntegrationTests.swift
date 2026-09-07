//
//  FrontmatterIntegrationTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 split + parse 端到端集成、YAML 数组项解析、parse 失败降级路径、YAML 边界场景（嵌套缩进/无冒号/值含冒号）及重复 key 覆盖行为。
//

import XCTest
@testable import ZhiYu

final class FrontmatterIntegrationTests: XCTestCase {

    // MARK: - 集成：split + parse

    func testSplitAndParse_yamlFrontmatter_endToEnd() {
        let content = "---\npronunciation: test\ndefinition: def\n---\n# Body"
        let split = FrontmatterParser.split(content: content)
        let parsed = FrontmatterParser.parse(EntityFrontmatter.self, from: split.frontmatter ?? "")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.pronunciation, "test")
        XCTAssertEqual(parsed?.definition, "def")
        XCTAssertEqual(split.body, "# Body")
    }

    func testSplitAndParse_jsonFrontmatter_endToEnd() {
        let content = "---json\n{\"pronunciation\": \"test\"}\n---\nBody"
        let split = FrontmatterParser.split(content: content)
        let parsed = FrontmatterParser.parse(EntityFrontmatter.self, from: split.frontmatter ?? "")

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.pronunciation, "test")
    }

    // MARK: - parse: YAML 数组项

    /// YAML 数组对象解析：`subjects:` 后跟 `- id: s1` / `- id: s2` 缩进项。
    /// 修复 `omittingEmptySubsequences: false` 后 `currentArrayKey` 正确设置。
    func testParse_yamlWithArrayOfObjects_decodesSuccessfully() {
        let yaml = """
        subjects:
          - id: s1
            name: Subject 1
          - id: s2
            name: Subject 2
        """
        let result = FrontmatterParser.parse(ComparisonFrontmatter.self, from: yaml)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.subjects?.count, 2)
        XCTAssertEqual(result?.subjects?[0].id, "s1")
        XCTAssertEqual(result?.subjects?[0].name, "Subject 1")
        XCTAssertEqual(result?.subjects?[1].id, "s2")
    }

    func testParse_yamlArrayItemWithOnlyDash_noContent() {
        let yaml = """
        subjects:
          -
        """
        let result = FrontmatterParser.parse(ComparisonFrontmatter.self, from: yaml)

        XCTAssertNotNil(result, "空数组项应能解析")
    }

    // MARK: - parse: 失败路径

    /// 格式错误的 YAML 走 `convertYamlToJson`，无法解析的行被跳过，
    /// 返回 `{}`，Codable 解码出全 nil 默认对象。
    func testParse_yamlMalformed_degradesToDefaultObject() {
        let yaml = "this is not yaml: : :"
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: yaml)

        XCTAssertNotNil(result, "格式错误的 YAML 降级为默认对象")
        XCTAssertNil(result?.pronunciation)
    }

    func testParse_jsonNotMatchingModel_returnsNil() {
        let json = "{\"unknown_field\": \"value\"}"
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: json)

        XCTAssertNotNil(result, "可选字段缺失应能解析为 nil")
        XCTAssertNil(result?.pronunciation)
    }

    // MARK: - YAML 边界

    func testParse_yamlWithNestedObject_twoSpaceIndent() {
        let yaml = """
        subjects:
          id: s1
          name: Subject 1
        """
        let result = FrontmatterParser.parse(ComparisonFrontmatter.self, from: yaml)

        XCTAssertNotNil(result, "两空格缩进嵌套对象应能解析")
    }

    func testParse_yamlWithNestedObject_fourSpaceIndent() {
        let yaml = """
        subjects:
            id: s1
            name: Subject 1
        """
        let result = FrontmatterParser.parse(ComparisonFrontmatter.self, from: yaml)

        XCTAssertNotNil(result, "四空格缩进嵌套对象应能解析")
    }

    func testParse_yamlLineWithoutColon_isSkipped() {
        let yaml = "pronunciation: test\nthis line has no colon"
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: yaml)

        XCTAssertNotNil(result, "无冒号行应被跳过")
        XCTAssertEqual(result?.pronunciation, "test")
    }

    func testParse_yamlValueWithColonInValue_keepsColon() {
        let yaml = "pronunciation: http://example.com"
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: yaml)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pronunciation, "http://example.com")
    }

    // MARK: - 重复 key 覆盖

    func testParse_yamlDuplicateKeys_lastValueWins() {
        let yaml = "pronunciation: first\npronunciation: second"
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: yaml)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pronunciation, "second", "重复 key 后值覆盖前值")
    }
}
