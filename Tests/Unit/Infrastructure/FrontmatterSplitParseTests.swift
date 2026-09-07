//
//  FrontmatterSplitParseTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Frontmatter 剥离（split）与 YAML/JSON 解析（parse）的基础路径、降级路径及失败路径。
//

import XCTest
@testable import ZhiYu

final class FrontmatterSplitParseTests: XCTestCase {

    // MARK: - split: 基础剥离

    func testSplit_yamlFrontmatter_returnsFrontmatterAndBody() {
        let content = "---\nkey: value\n---\n# Title\nBody text"
        let result = FrontmatterParser.split(content: content)

        XCTAssertEqual(result.frontmatter, "key: value")
        XCTAssertEqual(result.body, "# Title\nBody text")
    }

    func testSplit_jsonFrontmarker_returnsFrontmatterAndBody() {
        let content = "---json\n{\"key\": \"value\"}\n---\nBody"
        let result = FrontmatterParser.split(content: content)

        XCTAssertEqual(result.frontmatter, "{\"key\": \"value\"}")
        XCTAssertEqual(result.body, "Body")
    }

    func testSplit_noFrontmatter_returnsNilAndOriginalContent() {
        let content = "# Title\nNo frontmatter here"
        let result = FrontmatterParser.split(content: content)

        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, content)
    }

    func testSplit_emptyString_returnsNilAndEmptyBody() {
        let result = FrontmatterParser.split(content: "")

        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, "")
    }

    func testSplit_onlyOpeningDelimiter_returnsNilAndOriginalContent() {
        let content = "---\nkey: value\nno closing delimiter"
        let result = FrontmatterParser.split(content: content)

        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, content)
    }

    func testSplit_firstLineWithLeadingWhitespace_isNotRecognizedAsFrontmatter() {
        let content = "  ---\nkey: value\n---\nBody"
        let result = FrontmatterParser.split(content: content)

        XCTAssertNil(result.frontmatter, "包含前置缩进空格的分隔符不应被识别为 Frontmatter")
        XCTAssertEqual(result.body, content)
    }

    func testSplit_emptyFrontmatter_returnsNilFrontmatter() {
        let content = "---\n---\nBody only"
        let result = FrontmatterParser.split(content: content)

        XCTAssertNil(result.frontmatter, "空 frontmatter 应返回 nil")
        XCTAssertEqual(result.body, "Body only")
    }

    func testSplit_emptyBody_returnsEmptyBody() {
        let content = "---\nkey: value\n---\n"
        let result = FrontmatterParser.split(content: content)

        XCTAssertEqual(result.frontmatter, "key: value")
        XCTAssertEqual(result.body, "")
    }

    func testSplit_multipleDelimiters_takesFirstAsOpening() {
        let content = "---\nkey: value\n---\n---\nmore"
        let result = FrontmatterParser.split(content: content)

        XCTAssertEqual(result.frontmatter, "key: value")
        XCTAssertEqual(result.body, "---\nmore")
    }

    func testSplit_nonDelimiterFirstLine_returnsOriginal() {
        let content = "key: value\n---\nbody"
        let result = FrontmatterParser.split(content: content)

        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, content)
    }

    // MARK: - split: 边界

    func testSplit_singleDelimiterLine_returnsNilFrontmatterAndEmptyBody() {
        let content = "---\n---"
        let result = FrontmatterParser.split(content: content)

        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, "")
    }

    func testSplit_frontmatterWithTrailingNewline_isTrimmed() {
        let content = "---\nkey: value\n\n\n---\nBody"
        let result = FrontmatterParser.split(content: content)

        XCTAssertEqual(result.frontmatter, "key: value")
        XCTAssertEqual(result.body, "Body")
    }

    // MARK: - parse: JSON 路径

    func testParse_jsonObject_decodesSuccessfully() {
        let json = "{\"pronunciation\": \"test\", \"definition\": \"def\"}"
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pronunciation, "test")
        XCTAssertEqual(result?.definition, "def")
    }

    func testParse_jsonWithSnakeCase_decodesSuccessfully() {
        let json = "{\"file_name\": \"doc.pdf\", \"file_size\": 1024}"
        let result = FrontmatterParser.parse(SourceFrontmatter.self, from: json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.fileName, "doc.pdf")
        XCTAssertEqual(result?.fileSize, 1024)
    }

    /// 无效 JSON（不以 `}` 结尾）走 YAML 降级路径，`convertYamlToJson` 返回 `{}`，
    /// Codable 解码出全 nil 字段的默认对象。
    func testParse_invalidJson_degradesToDefaultObject() {
        let json = "{invalid json"
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: json)

        XCTAssertNotNil(result, "无效 JSON 降级为 YAML 后解码出默认对象")
        XCTAssertNil(result?.pronunciation)
        XCTAssertNil(result?.definition)
    }

    /// JSON 类型不匹配（fileSize 传字符串）JSON 解码失败，走 YAML 降级路径，
    /// `convertYamlToJson` 返回 `{}`，fileSize 解码为 nil。
    func testParse_jsonTypeMismatch_degradesToNilField() {
        let json = "{\"file_size\": \"not a number\"}"
        let result = FrontmatterParser.parse(SourceFrontmatter.self, from: json)

        XCTAssertNotNil(result, "类型不匹配降级后解码出默认对象")
        XCTAssertNil(result?.fileSize, "fileSize 字段解码失败为 nil")
    }

    /// 空字符串走 YAML 降级路径，`convertYamlToJson("")` 返回 `{}`，
    /// Codable 解码出全 nil 字段的默认对象。
    func testParse_emptyString_degradesToDefaultObject() {
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: "")

        XCTAssertNotNil(result, "空字符串降级为 YAML 后解码出默认对象")
        XCTAssertNil(result?.pronunciation)
        XCTAssertNil(result?.definition)
    }

    func testParse_jsonWithLeadingTrailingWhitespace_isTrimmed() {
        let json = "  \n{\"key\": \"value\"}\n  "
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: json)

        XCTAssertNotNil(result)
    }

    // MARK: - parse: YAML 降级路径

    func testParse_yamlSimpleKeyValue_decodesSuccessfully() {
        let yaml = "pronunciation: test\ndefinition: def"
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: yaml)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pronunciation, "test")
        XCTAssertEqual(result?.definition, "def")
    }

    func testParse_yamlWithQuotedValue_decodesSuccessfully() {
        let yaml = "pronunciation: \"quoted value\""
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: yaml)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pronunciation, "quoted value")
    }

    func testParse_yamlWithSingleQuotedValue_decodesSuccessfully() {
        let yaml = "pronunciation: 'single quoted'"
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: yaml)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pronunciation, "single quoted")
    }

    func testParse_yamlWithBooleanTrue_decodesSuccessfully() {
        struct BoolModel: Decodable { let enabled: Bool }
        let yaml = "enabled: true"
        let result = FrontmatterParser.parse(BoolModel.self, from: yaml)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.enabled, true)
    }

    func testParse_yamlWithBooleanFalse_decodesSuccessfully() {
        struct BoolModel: Decodable { let enabled: Bool }
        let yaml = "enabled: false"
        let result = FrontmatterParser.parse(BoolModel.self, from: yaml)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.enabled, false)
    }

    func testParse_yamlWithNumericValue_decodesSuccessfully() {
        struct NumModel: Decodable { let count: Double }
        let yaml = "count: 42"
        let result = FrontmatterParser.parse(NumModel.self, from: yaml)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.count, 42)
    }

    func testParse_yamlWithInlineArray_decodesSuccessfully() {
        struct ArrayModel: Decodable { let aliases: [String] }
        let yaml = "aliases: [a, b, c]"
        let result = FrontmatterParser.parse(ArrayModel.self, from: yaml)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.aliases, ["a", "b", "c"])
    }

    func testParse_yamlWithCommentLine_isSkipped() {
        let yaml = "# this is a comment\npronunciation: test"
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: yaml)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pronunciation, "test")
    }

    func testParse_yamlWithEmptyLine_isSkipped() {
        let yaml = "\n\npronunciation: test\n\n"
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: yaml)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pronunciation, "test")
    }

}
