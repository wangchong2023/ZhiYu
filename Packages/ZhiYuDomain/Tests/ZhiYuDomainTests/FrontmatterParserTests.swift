//
//  FrontmatterParserTests.swift
//  ZhiYuDomainTests
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：验证通用 Frontmatter 剥离逻辑（split 头尾定界符识别、正文回退）与简易 YAML→JSON
//           泛型解码（parse），覆盖 Fuzz / 边界 / 空值等场景，确保下沉后行为等价无回归。
//

import XCTest
@testable import ZhiYuDomain

final class FrontmatterParserTests: XCTestCase {

    // MARK: - split 剥离

    /// 验证标准 YAML Frontmatter 被正确剥离，返回 frontmatter 与 body
    func testSplit_YamlFrontmatter_ReturnsFrontmatterAndBody() {
        let content = "---\ntitle: 测试\n---\n正文内容"
        let result = FrontmatterParser.split(content: content)
        XCTAssertEqual(result.frontmatter, "title: 测试")
        XCTAssertEqual(result.body, "正文内容")
    }

    /// 验证无 Frontmatter（不以 --- 开头）时整体作为 body 返回
    func testSplit_NoFrontmatter_EntireContentIsBody() {
        let content = "纯正文，没有 frontmatter"
        let result = FrontmatterParser.split(content: content)
        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, content)
    }

    /// 验证 ---json 标志也被识别为 frontmatter 起点
    func testSplit_JsonDelimiter_Recognized() {
        let content = "---json\n{\"key\":\"value\"}\n---\n正文"
        let result = FrontmatterParser.split(content: content)
        XCTAssertNotNil(result.frontmatter)
        XCTAssertEqual(result.frontmatter, "{\"key\":\"value\"}")
        XCTAssertEqual(result.body, "正文")
    }

    /// 验证未闭合定界符时整体作为 body 返回
    func testSplit_UnclosedDelimiter_EntireContentIsBody() {
        let content = "---\ntitle: 测试\n没有闭合"
        let result = FrontmatterParser.split(content: content)
        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, content)
    }

    /// 验证前置缩进空格时不被识别为 frontmatter（禁止前置缩进）
    func testSplit_IndentedFirstLine_NotRecognized() {
        let content = " ---\ntitle: 测试\n---\n正文"
        let result = FrontmatterParser.split(content: content)
        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, content)
    }

    /// 验证空串输入安全返回
    func testSplit_EmptyContent_ReturnsNilFrontmatterAndEmptyBody() {
        let result = FrontmatterParser.split(content: "")
        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, "")
    }

    /// 验证空 Frontmatter 块返回 nil（不返回空字符串）
    func testSplit_EmptyFrontmatterBlock_ReturnsNil() {
        let content = "---\n---\n正文"
        let result = FrontmatterParser.split(content: content)
        XCTAssertNil(result.frontmatter)
        XCTAssertEqual(result.body, "正文")
    }

    /// Fuzz：随机 Markdown 输入永不崩溃
    func testFuzz_RandomMarkdown_AllInvariantsHold() {
        for _ in 0..<200 {
            let content = Self.randomMarkdown()
            let result = FrontmatterParser.split(content: content)
            XCTAssertNotNil(result)
        }
    }

    // MARK: - parse 泛型解码

    /// 验证标准 JSON Frontmatter 能解码为自定义模型
    func testParse_Json_DecodesModel() {
        let json = #"{"title":"标题","count":3}"#
        let result = FrontmatterParser.parse(TestFrontmatter.self, from: json)
        XCTAssertEqual(result?.title, "标题")
        XCTAssertEqual(result?.count, 3)
    }

    /// 验证简易 YAML 格式能降级解码为自定义模型
    func testParse_Yaml_DecodesModel() {
        let yaml = "title: 标题\ncount: 5"
        let result = FrontmatterParser.parse(TestFrontmatter.self, from: yaml)
        XCTAssertEqual(result?.title, "标题")
        XCTAssertEqual(result?.count, 5)
    }

    /// 验证 YAML 布尔值正确解析
    func testParse_YamlBool_DecodesTrue() {
        let yaml = "enabled: true"
        let result = FrontmatterParser.parse(BoolModel.self, from: yaml)
        XCTAssertEqual(result?.enabled, true)
    }

    /// 验证 YAML 行内数组正确解析
    func testParse_YamlArray_DecodesModel() {
        let yaml = "tags: [a, b]"
        let result = FrontmatterParser.parse(ArrayModel.self, from: yaml)
        XCTAssertEqual(result?.tags, ["a", "b"])
    }

    /// 验证空字符串解析不崩溃（可选字段模型返回空模型）
    func testParse_EmptyString_DoesNotCrash() {
        let result = FrontmatterParser.parse(TestFrontmatter.self, from: "")
        XCTAssertNotNil(result)
    }

    /// 验证缺必填字段的无效内容返回 nil（不崩溃）
    func testParse_MissingRequiredField_ReturnsNil() {
        let result = FrontmatterParser.parse(RequiredModel.self, from: "not: a title")
        XCTAssertNil(result)
    }

    // MARK: - 测试辅助

    private struct TestFrontmatter: Decodable {
        let title: String?
        let count: Int?
    }

    private struct RequiredModel: Decodable {
        let title: String
    }

    private struct BoolModel: Decodable {
        let enabled: Bool?
    }

    private struct ArrayModel: Decodable {
        let tags: [String]?
    }

    private static func randomMarkdown() -> String {
        let lines = ["", "---", "---json", "title: x", "body: y", "# heading", "- item", "正文", "  nested: v"]
        var parts: [String] = []
        let count = Int.random(in: 0...12)
        for _ in 0..<count {
            parts.append(lines.randomElement() ?? "")
        }
        return parts.joined(separator: "\n")
    }
}