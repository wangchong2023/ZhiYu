//
//  FrontmatterModelsCodableTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 Frontmatter 强类型模型（MatrixValue/Concept/Source/Comparison/Entity）的 Codable 编解码往返与字段映射。
//

import XCTest
@testable import ZhiYu

final class FrontmatterModelsCodableTests: XCTestCase {

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
        XCTAssertEqual(decoded, .null, "应解码为 null case")
    }

    func testMatrixValue_nullFromJSONNull_decodesAsNull() throws {
        let json = Data("null".utf8)
        let decoded = try JSONDecoder().decode(MatrixValue.self, from: json)
        XCTAssertEqual(decoded, .null, "JSON null 应解码为 .null")
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
        XCTAssertEqual(decoded, .null, "不完整的 range dict 应回退为 null")
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
}
