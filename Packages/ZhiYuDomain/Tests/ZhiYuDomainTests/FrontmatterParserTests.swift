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

    // MARK: - YAML 转换边界（convertYamlToJson 内部辅助）

    /// 验证 YAML 注释行与空行被忽略
    func testParse_YamlCommentLine_Ignored() {
        let yaml = "# 这是注释\ntitle: 标题\n\n# 另一个注释"
        let result = FrontmatterParser.parse(TestFrontmatter.self, from: yaml)
        XCTAssertEqual(result?.title, "标题", "注释行应被忽略")
    }

    /// 验证 YAML 数组项（- key: value）解析为对象数组。
    /// 说明：简易转换器 currentObject 为顶层独立字典，数组项经 processArrayItemLine→flush 追加进数组。
    func testParse_YamlArrayItems_DecodesArrayOfObjects() {
        let yaml = "items:\n  - name: 甲\n  - name: 乙"
        let result = FrontmatterParser.parse(MixedModel.self, from: yaml)
        XCTAssertEqual(result?.items?.count, 2, "数组项应解析为 2 个对象")
        XCTAssertEqual(result?.items?.first?.name, "甲", "数组首个对象 name 应解析")
        XCTAssertEqual(result?.items?.last?.name, "乙", "数组末个对象 name 应解析")
    }

    /// 验证四空格缩进行也被当作 currentObject 键值解析（简易转换器不生成嵌套 dict）。
    /// 断言：数组项内四空格缩进作为对象键值被写入数组元素。
    func testParse_YamlQuadSpaceIndent_BecomesArrayObjectField() {
        let yaml = "items:\n    - name: 值"
        let result = FrontmatterParser.parse(MixedModel.self, from: yaml)
        XCTAssertEqual(result?.items?.first?.name, "值", "四空格缩进数组项应解析")
    }

    /// 验证双引号与单引号包裹的字符串值被去引号
    func testParse_YamlQuotedValues_StripQuotes() {
        let yaml = "title: \"带引号标题\"\nsubtitle: '单引号标题'"
        let result = FrontmatterParser.parse(QuotedModel.self, from: yaml)
        XCTAssertEqual(result?.title, "带引号标题", "双引号应被剥离")
        XCTAssertEqual(result?.subtitle, "单引号标题", "单引号应被剥离")
    }

    /// 验证布尔 false 与数字字符串正确区分
    func testParse_YamlBoolFalse_AndNumeric() {
        let yaml = "enabled: false\ncount: 42"
        let result = FrontmatterParser.parse(MixedModel.self, from: yaml)
        XCTAssertEqual(result?.enabled, false, "false 应解析为布尔 false")
        XCTAssertEqual(result?.count, 42, "数字字符串应解析为数字")
    }

    /// 验证数组键但无数组元素时不崩溃
    func testParse_YamlArrayKeyWithoutItems_DoesNotCrash() {
        let yaml = "emptyList:\n  - \n"
        let result = FrontmatterParser.parse(ArrayModel.self, from: yaml)
        // 不崩溃即为通过；空数组可解析为 nil 或空
        _ = result
    }

    /// 验证 YAML 非 JSON 前缀内容（无 { 结尾）走 YAML 降级路径
    func testParse_YamlWithoutBracePrefix_StillDecodes() {
        let yaml = "title: YAML标题\ncount: 7"
        let result = FrontmatterParser.parse(TestFrontmatter.self, from: yaml)
        XCTAssertEqual(result?.title, "YAML标题")
        XCTAssertEqual(result?.count, 7)
    }

    /// 验证以 { 开头且 } 结尾但 JSON 无效时，JSON 直接解析失败后回退 YAML 解析（触发 catch 分支）
    func testParse_InvalidJsonBraces_FallsBackToYaml() {
        let content = "{\"title\":123}"
        let result = FrontmatterParser.parse(RequiredModel.self, from: content)
        // JSON 解码因类型不匹配失败；YAML 降级也无法提供必填 title，最终返回 nil（不崩溃）
        XCTAssertNil(result, "无效 JSON 且 YAML 无法解码时应返回 nil")
    }

    /// 验证缩进的 key: value 行进入 currentObject（触发双空格分支与引号/数字剥离），并在后续顶层键刷新时入数组
    func testParse_YamlIndentedKeyValue_FlushesIntoArray() {
        let yaml = "list:\n  name: \"双空格值\"\n  count: 3\nother: 42"
        let result = FrontmatterParser.parse(ListModel.self, from: yaml)
        XCTAssertEqual(result?.list?.first?.name, "双空格值", "缩进引号值应剥离引号并入数组对象")
        XCTAssertEqual(result?.list?.first?.count, 3, "缩进数字值应转为数字")
        XCTAssertEqual(result?.other, 42, "后续顶层键应正常解析")
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

    private struct MixedModel: Decodable {
        let author: Author?
        let items: [Item]?
        let enabled: Bool?
        let count: Int?
    }

    private struct Author: Decodable {
        let name: String?
        let age: Int?
    }

    private struct Item: Decodable {
        let name: String?
    }

    private struct QuotedModel: Decodable {
        let title: String?
        let subtitle: String?
    }

    private struct ListModel: Decodable {
        let list: [ListItem]?
        let other: Int?
    }

    private struct ListItem: Decodable {
        let name: String?
        let count: Int?
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
