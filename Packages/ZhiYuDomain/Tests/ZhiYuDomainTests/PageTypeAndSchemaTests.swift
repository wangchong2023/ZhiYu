//
//  PageTypeAndSchemaTests.swift
//  ZhiYuDomainTests
//
//  系统层级：[Tests] ZhiYuDomain SPM 单元测试
//  核心职责：对下沉至 ZhiYuDomain 的 PageType、PageStatus、Confidence 及 PageSchema 进行契约与 Codable 单测。
//

import XCTest
@testable import ZhiYuDomain

final class PageTypeAndSchemaTests: XCTestCase {

    // MARK: - PageType Tests

    func testPageTypeOrderAndVisibility() {
        let visible = PageType.allVisibleCases
        XCTAssertEqual(visible.count, 3)
        XCTAssertEqual(visible[0], .concept, "概念/主题需排在实体/词条前面")
        XCTAssertEqual(visible[1], .entity)
        XCTAssertEqual(visible[2], .source)
        XCTAssertFalse(visible.contains(.raw), "raw 类型不对用户可见")
        XCTAssertFalse(visible.contains(.comparison))
    }

    func testPageTypeIdentifiableAndColorName() {
        for type in PageType.allCases {
            XCTAssertEqual(type.id, type.rawValue)
            XCTAssertFalse(type.colorName.isEmpty)
        }
        XCTAssertEqual(PageType.concept.colorName, "concept")
        XCTAssertEqual(PageType.entity.colorName, "entity")
        XCTAssertEqual(PageType.source.colorName, "source")
        XCTAssertEqual(PageType.comparison.colorName, "comparison")
        XCTAssertEqual(PageType.raw.colorName, "gray")
    }

    func testPageTypeCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for original in PageType.allCases {
            let data = try encoder.encode(original)
            let decoded = try decoder.decode(PageType.self, from: data)
            XCTAssertEqual(decoded, original)
        }
    }

    // MARK: - PageStatus Tests

    func testPageStatusColorNameAndCodable() throws {
        XCTAssertEqual(PageStatus.active.colorName, "green")
        XCTAssertEqual(PageStatus.stub.colorName, "yellow")
        XCTAssertEqual(PageStatus.needsUpdate.colorName, "orange")
        XCTAssertEqual(PageStatus.deprecated.colorName, "red")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for status in PageStatus.allCases {
            let data = try encoder.encode(status)
            let decoded = try decoder.decode(PageStatus.self, from: data)
            XCTAssertEqual(decoded, status)
        }
    }

    // MARK: - Confidence Tests

    func testConfidenceColorNameAndCodable() throws {
        XCTAssertEqual(Confidence.high.colorName, "green")
        XCTAssertEqual(Confidence.medium.colorName, "yellow")
        XCTAssertEqual(Confidence.low.colorName, "red")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for confidence in Confidence.allCases {
            let data = try encoder.encode(confidence)
            let decoded = try decoder.decode(Confidence.self, from: data)
            XCTAssertEqual(decoded, confidence)
        }
    }

    // MARK: - PageSchema Tests

    func testPageSchemaInitAndCodableRoundTrip() throws {
        let schema = PageSchema(
            type: .concept,
            requiredFields: ["title", "definition", "examples"],
            template: "# {{title}}\n\n## 定义\n{{definition}}",
            promptInstruction: "请按概念 Schema 生成标准维基页面"
        )

        XCTAssertEqual(schema.type, .concept)
        XCTAssertEqual(schema.requiredFields.count, 3)
        XCTAssertEqual(schema.template, "# {{title}}\n\n## 定义\n{{definition}}")
        XCTAssertEqual(schema.promptInstruction, "请按概念 Schema 生成标准维基页面")

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let data = try encoder.encode(schema)
        let decoded = try decoder.decode(PageSchema.self, from: data)

        XCTAssertEqual(decoded.type, schema.type)
        XCTAssertEqual(decoded.requiredFields, schema.requiredFields)
        XCTAssertEqual(decoded.template, schema.template)
        XCTAssertEqual(decoded.promptInstruction, schema.promptInstruction)
    }
}
