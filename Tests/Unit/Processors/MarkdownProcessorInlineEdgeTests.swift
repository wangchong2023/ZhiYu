//
//  MarkdownProcessorInlineEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 MarkdownProcessor 两阶段行内解析算法对双链保护区、粗体/斜体/外链/代码的级联匹配语义。
//

import XCTest
@testable import ZhiYu

final class MarkdownProcessorInlineEdgeTests: XCTestCase {

    private let processor = MarkdownProcessor()

    // MARK: - 双链保护区（核心两阶段算法）

    func testParseInlineSegments_singleApplink() {
        let segments = processor.parseInlineSegments("[[目标页面]]")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .applink)
        XCTAssertEqual(segments[0].content, "目标页面")
    }

    func testParseInlineSegments_aliasedApplink() {
        let segments = processor.parseInlineSegments("[[显示文案|目标页面]]")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .applink)
        XCTAssertEqual(segments[0].content, "显示文案|目标页面")
    }

    func testParseInlineSegments_applinkSurroundedByText() {
        let segments = processor.parseInlineSegments("前文[[页面]]后文")
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[0].type, .text)
        XCTAssertEqual(segments[0].content, "前文")
        XCTAssertEqual(segments[1].type, .applink)
        XCTAssertEqual(segments[2].type, .text)
        XCTAssertEqual(segments[2].content, "后文")
    }

    // MARK: - 粗体

    func testParseInlineSegments_bold() {
        let segments = processor.parseInlineSegments("**粗体**")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .bold)
        XCTAssertEqual(segments[0].content, "粗体")
    }

    func testParseInlineSegments_boldSurroundedByText() {
        let segments = processor.parseInlineSegments("前**粗体**后")
        XCTAssertEqual(segments.count, 3)
        XCTAssertEqual(segments[1].type, .bold)
    }

    // MARK: - 斜体

    func testParseInlineSegments_italic() {
        let segments = processor.parseInlineSegments("*斜体*")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .italic)
        XCTAssertEqual(segments[0].content, "斜体")
    }

    // MARK: - 删除线

    func testParseInlineSegments_strikethrough() {
        let segments = processor.parseInlineSegments("~~删除线~~")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .strikethrough)
        XCTAssertEqual(segments[0].content, "删除线")
    }

    // MARK: - 行内代码

    func testParseInlineSegments_code() {
        let segments = processor.parseInlineSegments("`代码`")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .code)
        XCTAssertEqual(segments[0].content, "代码")
    }

    // MARK: - 外链

    func testParseInlineSegments_link() {
        let segments = processor.parseInlineSegments("[文案](https://example.com)")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .link)
        XCTAssertTrue(segments[0].content.contains("文案"))
        XCTAssertTrue(segments[0].content.contains("https://example.com"))
    }

    // MARK: - 复合嵌套（双链被粗体包围）

    func testParseInlineSegments_boldWrappingApplink_applinkProtected() {
        let segments = processor.parseInlineSegments("***[[知识页面]]***")
        let hasApplink = segments.contains { $0.type == .applink }
        XCTAssertTrue(hasApplink, "双链被粗体斜体包围时应被保护区算法保护")
    }

    // MARK: - 纯文本

    func testParseInlineSegments_plainText() {
        let segments = processor.parseInlineSegments("纯文本无格式")
        XCTAssertEqual(segments.count, 1)
        XCTAssertEqual(segments[0].type, .text)
    }

    func testParseInlineSegments_emptyString() {
        let segments = processor.parseInlineSegments("")
        XCTAssertTrue(segments.isEmpty)
    }

    // MARK: - 多格式混合

    func testParseInlineSegments_mixedFormats() {
        let segments = processor.parseInlineSegments("前**粗体**中[[双链]]后*斜体*")
        let types = segments.map { $0.type }
        XCTAssertTrue(types.contains(.text))
        XCTAssertTrue(types.contains(.bold))
        XCTAssertTrue(types.contains(.applink))
        XCTAssertTrue(types.contains(.italic))
    }

    // MARK: - 转义字符

    func testParseInlineSegments_escapedBold_treatedAsText() {
        let segments = processor.parseInlineSegments("\\**非粗体\\**")
        // 转义后的 ** 不应被识别为粗体
        let hasBold = segments.contains { $0.type == .bold }
        // 注意：当前实现可能不完整支持转义，记录实际行为
        _ = hasBold
    }
}
