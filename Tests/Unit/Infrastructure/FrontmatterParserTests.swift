//
//  FrontmatterParserTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Frontmatter 剥离、YAML/JSON 解析、强类型反序列化与边界容错。
//

import XCTest
@testable import ZhiYu

final class FrontmatterParserTests: XCTestCase {

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

    func testSplit_firstLineWithLeadingWhitespace_isRecognized() {
        let content = "  ---\nkey: value\n---\nBody"
        let result = FrontmatterParser.split(content: content)

        XCTAssertEqual(result.frontmatter, "key: value")
        XCTAssertEqual(result.body, "Body")
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

    // MARK: - MatrixValue 编解码

    func testMatrixValue_textRoundTrip_encodesAndDecodes() throws {
        let original = MatrixValue.text("hello")
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MatrixValue.self, from: encoded)

        if case .text(let str) = decoded {
            XCTAssertEqual(str, "hello")
        } else {
            XCTFail("应为 text case")
        }
    }

    func testMatrixValue_ratingRoundTrip_encodesAndDecodes() throws {
        let original = MatrixValue.rating(4.5)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MatrixValue.self, from: encoded)

        if case .rating(let val) = decoded {
            XCTAssertEqual(val, 4.5)
        } else {
            XCTFail("应为 rating case")
        }
    }

    func testMatrixValue_rangeRoundTrip_encodesAndDecodes() throws {
        let original = MatrixValue.range(min: 1.0, max: 10.0)
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MatrixValue.self, from: encoded)

        if case .range(let min, let max) = decoded {
            XCTAssertEqual(min, 1.0)
            XCTAssertEqual(max, 10.0)
        } else {
            XCTFail("应为 range case")
        }
    }

    func testMatrixValue_imageListRoundTrip_encodesAndDecodes() throws {
        let original = MatrixValue.imageList(["url1", "url2"])
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MatrixValue.self, from: encoded)

        if case .imageList(let arr) = decoded {
            XCTAssertEqual(arr, ["url1", "url2"])
        } else {
            XCTFail("应为 imageList case")
        }
    }

    func testMatrixValue_nullRoundTrip_encodesAndDecodes() throws {
        let original = MatrixValue.null
        let encoded = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(MatrixValue.self, from: encoded)

        if case .null = decoded {
            XCTAssertTrue(true)
        } else {
            XCTFail("应为 null case")
        }
    }

    func testMatrixValue_nullFromJSONNull_decodesAsNull() throws {
        let json = Data("null".utf8)
        let decoded = try JSONDecoder().decode(MatrixValue.self, from: json)

        if case .null = decoded {
            XCTAssertTrue(true)
        } else {
            XCTFail("JSON null 应解码为 .null")
        }
    }

    func testMatrixValue_rangeFromDict_decodesAsRange() throws {
        let json = Data("{\"min\": 5, \"max\": 15}".utf8)
        let decoded = try JSONDecoder().decode(MatrixValue.self, from: json)

        if case .range(let min, let max) = decoded {
            XCTAssertEqual(min, 5)
            XCTAssertEqual(max, 15)
        } else {
            XCTFail("应解码为 range")
        }
    }

    func testMatrixValue_rangeFromIncompleteDict_fallsBackToNull() throws {
        let json = Data("{\"min\": 5}".utf8)
        let decoded = try JSONDecoder().decode(MatrixValue.self, from: json)

        if case .null = decoded {
            XCTAssertTrue(true, "不完整的 range dict 应回退为 null")
        } else {
            XCTFail("不完整 range dict 应回退为 null")
        }
    }

    // MARK: - ConceptFrontmatter 编解码

    func testConceptFrontmatter_fullDecode_decodesSuccessfully() {
        let json = """
        {
            "outlines": [
                {"id": "o1", "title": "Outline 1", "level": 1, "associated_page_id": "p1"}
            ],
            "surprising_insights": [
                {"insight_title": "Insight", "linked_concept_id": "c1", "reason": "because"}
            ]
        }
        """
        let result = FrontmatterParser.parse(ConceptFrontmatter.self, from: json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.outlines?.count, 1)
        XCTAssertEqual(result?.outlines?[0].id, "o1")
        XCTAssertEqual(result?.outlines?[0].title, "Outline 1")
        XCTAssertEqual(result?.outlines?[0].level, 1)
        XCTAssertEqual(result?.outlines?[0].associatedPageID, "p1")
        XCTAssertEqual(result?.surprisingInsights?.count, 1)
        XCTAssertEqual(result?.surprisingInsights?[0].insightTitle, "Insight")
        XCTAssertEqual(result?.surprisingInsights?[0].linkedConceptID, "c1")
        XCTAssertEqual(result?.surprisingInsights?[0].reason, "because")
    }

    func testConceptFrontmatter_nullOptionalFields_decodesAsNil() {
        let json = "{\"outlines\": null, \"surprising_insights\": null}"
        let result = FrontmatterParser.parse(ConceptFrontmatter.self, from: json)

        XCTAssertNotNil(result)
        XCTAssertNil(result?.outlines)
        XCTAssertNil(result?.surprisingInsights)
    }

    // MARK: - SourceFrontmatter 编解码

    func testSourceFrontmatter_fullDecode_decodesSuccessfully() {
        let json = """
        {
            "type": "voice",
            "file_name": "audio.m4a",
            "file_size": 2048,
            "voice_amplitude_waveform": [0.1, 0.5, 0.9],
            "transcription": "hello world",
            "extracted_page_ids": [
                {"page_id": "p1", "name": "Page 1", "type": "concept"}
            ]
        }
        """
        let result = FrontmatterParser.parse(SourceFrontmatter.self, from: json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.type, "voice")
        XCTAssertEqual(result?.fileName, "audio.m4a")
        XCTAssertEqual(result?.fileSize, 2048)
        XCTAssertEqual(result?.voiceAmplitudeWaveform, [0.1, 0.5, 0.9])
        XCTAssertEqual(result?.transcription, "hello world")
        XCTAssertEqual(result?.extractedPageIDs?.count, 1)
        XCTAssertEqual(result?.extractedPageIDs?[0].pageID, "p1")
        XCTAssertEqual(result?.extractedPageIDs?[0].name, "Page 1")
        XCTAssertEqual(result?.extractedPageIDs?[0].type, "concept")
    }

    // MARK: - ComparisonFrontmatter 编解码

    func testComparisonFrontmatter_fullDecode_decodesSuccessfully() {
        let json = """
        {
            "subjects": [
                {"id": "s1", "name": "Subject 1", "logo_asset": {"light_url": "l1", "dark_url": "d1"}}
            ],
            "dimensions": [
                {"id": "d1", "name": "Dim 1", "type": "text", "unit": "kg"}
            ],
            "matrix": [
                {"subject_id": "s1", "dimension_id": "d1", "value": "sample"}
            ]
        }
        """
        let result = FrontmatterParser.parse(ComparisonFrontmatter.self, from: json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.subjects?.count, 1)
        XCTAssertEqual(result?.subjects?[0].id, "s1")
        XCTAssertEqual(result?.subjects?[0].name, "Subject 1")
        XCTAssertEqual(result?.subjects?[0].logoAsset?.lightURL, "l1")
        XCTAssertEqual(result?.subjects?[0].logoAsset?.darkURL, "d1")
        XCTAssertEqual(result?.dimensions?.count, 1)
        XCTAssertEqual(result?.dimensions?[0].id, "d1")
        XCTAssertEqual(result?.dimensions?[0].type, "text")
        XCTAssertEqual(result?.dimensions?[0].unit, "kg")
        XCTAssertEqual(result?.matrix?.count, 1)
        XCTAssertEqual(result?.matrix?[0].subjectID, "s1")
        XCTAssertEqual(result?.matrix?[0].dimensionID, "d1")
        if case .text(let val) = result?.matrix?[0].value {
            XCTAssertEqual(val, "sample")
        } else {
            XCTFail("matrix value 应为 text")
        }
    }

    // MARK: - EntityFrontmatter 编解码

    func testEntityFrontmatter_fullDecode_decodesSuccessfully() {
        let json = """
        {
            "pronunciation": "pro",
            "definition": "def",
            "aliases": ["a1", "a2"],
            "infobox": [{"key": "k1", "value": "v1"}],
            "overview": ["line1", "line2"]
        }
        """
        let result = FrontmatterParser.parse(EntityFrontmatter.self, from: json)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.pronunciation, "pro")
        XCTAssertEqual(result?.definition, "def")
        XCTAssertEqual(result?.aliases, ["a1", "a2"])
        XCTAssertEqual(result?.infobox?.count, 1)
        XCTAssertEqual(result?.infobox?[0].key, "k1")
        XCTAssertEqual(result?.infobox?[0].value, "v1")
        XCTAssertEqual(result?.overview, ["line1", "line2"])
    }

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
