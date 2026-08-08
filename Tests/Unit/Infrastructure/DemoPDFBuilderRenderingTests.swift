//
//  DemoPDFBuilderRenderingTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 DemoPDFBuilder PDF 生成与 Markdown 渲染逻辑验证。
//

import XCTest
@testable import ZhiYu

#if canImport(UIKit) && canImport(PDFKit) && !os(watchOS)
final class DemoPDFBuilderRenderingTests: XCTestCase {

    private var tempDir: String!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = NSTemporaryDirectory() + "DemoPDFBuilderTests_\(UUID().uuidString)/"
        try FileManager.default.createDirectory(atPath: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        if let tempDir, FileManager.default.fileExists(atPath: tempDir) {
            try? FileManager.default.removeItem(atPath: tempDir)
        }
        tempDir = nil
        try await super.tearDown()
    }

    // MARK: - ensurePDFExists

    func testEnsurePDFExistsCreatesValidPDFFile() throws {
        let path = tempDir + "test_basic.pdf"
        let result = DemoPDFBuilder.ensurePDFExists(at: path, title: "测试标题", content: "这是正文内容")
        XCTAssertNotNil(result)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        // 验证生成的文件是有效 PDF（头部应包含 %PDF）
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        XCTAssertGreaterThan(data.count, 100)
        XCTAssertEqual(data.prefix(4), Data("%PDF".utf8))
    }

    func testEnsurePDFExistsReturnsNilForInvalidPath() {
        // 使用一个不可能创建的路径
        let invalidPath = "/dev/null/cannot_create_dir/test.pdf"
        let result = DemoPDFBuilder.ensurePDFExists(at: invalidPath, title: "标题", content: "内容")
        XCTAssertNil(result)
    }

    func testEnsurePDFExistsOverwritesExistingFile() throws {
        let path = tempDir + "test_overwrite.pdf"
        // 第一次生成
        _ = DemoPDFBuilder.ensurePDFExists(at: path, title: "第一版", content: "内容A")
        let firstSize = try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int ?? 0
        // 第二次生成（不同内容）
        _ = DemoPDFBuilder.ensurePDFExists(at: path, title: "第二版", content: "内容B更长的内容")
        let secondSize = try FileManager.default.attributesOfItem(atPath: path)[.size] as? Int ?? 0
        // 文件应被覆盖（大小可能不同）
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        XCTAssertGreaterThan(secondSize, 100)
    }

    // MARK: - Markdown 元素渲染

    func testEnsurePDFExistsRendersH1Heading() throws {
        let path = tempDir + "test_h1.pdf"
        let content = "# 一级标题\n这是正文"
        let result = DemoPDFBuilder.ensurePDFExists(at: path, title: "H1测试", content: content)
        XCTAssertNotNil(result)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    func testEnsurePDFExistsRendersH2Heading() throws {
        let path = tempDir + "test_h2.pdf"
        let content = "## 二级标题\n这是正文"
        let result = DemoPDFBuilder.ensurePDFExists(at: path, title: "H2测试", content: content)
        XCTAssertNotNil(result)
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
    }

    func testEnsurePDFExistsRendersQuoteBlock() throws {
        let path = tempDir + "test_quote.pdf"
        let content = "> 这是引用块\n正文"
        let result = DemoPDFBuilder.ensurePDFExists(at: path, title: "引用测试", content: content)
        XCTAssertNotNil(result)
    }

    func testEnsurePDFExistsRendersTableRow() throws {
        let path = tempDir + "test_table.pdf"
        let content = "| 列1 | 列2 | 列3 |\n|---|---|---|\n| A | B | C |"
        let result = DemoPDFBuilder.ensurePDFExists(at: path, title: "表格测试", content: content)
        XCTAssertNotNil(result)
    }

    func testEnsurePDFExistsRendersListItems() throws {
        let path = tempDir + "test_list.pdf"
        let content = "- 列表项1\n- 列表项2\n* 星号列表项"
        let result = DemoPDFBuilder.ensurePDFExists(at: path, title: "列表测试", content: content)
        XCTAssertNotNil(result)
    }

    func testEnsurePDFExistsRendersEmptyContent() throws {
        let path = tempDir + "test_empty.pdf"
        let result = DemoPDFBuilder.ensurePDFExists(at: path, title: "空内容", content: "")
        XCTAssertNotNil(result)
    }

    func testEnsurePDFExistsRendersContentWithEmptyLines() throws {
        let path = tempDir + "test_blank_lines.pdf"
        let content = "段落1\n\n\n段落2\n\n\n\n段落3"
        let result = DemoPDFBuilder.ensurePDFExists(at: path, title: "空行测试", content: content)
        XCTAssertNotNil(result)
    }

    func testEnsurePDFExistsRendersLongContentExceedingPage() throws {
        let path = tempDir + "test_long.pdf"
        // 生成超长内容，触发分页截断逻辑
        var lines: [String] = []
        for i in 0..<200 {
            lines.append("这是第 \(i) 行内容，用于测试分页截断逻辑")
        }
        let content = lines.joined(separator: "\n")
        let result = DemoPDFBuilder.ensurePDFExists(at: path, title: "长内容", content: content)
        XCTAssertNotNil(result)
    }

    func testEnsurePDFExistsRendersMixedMarkdownElements() throws {
        let path = tempDir + "test_mixed.pdf"
        let content = """
        # 主标题

        ## 子标题

        这是正文段落。

        > 引用块内容

        | 列A | 列B |
        |---|---|
        | 1 | 2 |

        - 列表项
        - 另一项

        **粗体文本** 和 `代码` 和 「双链」
        """
        let result = DemoPDFBuilder.ensurePDFExists(at: path, title: "混合元素", content: content)
        XCTAssertNotNil(result)
    }

    // MARK: - sanitizeMarkdownText

    func testSanitizeMarkdownTextStripsBoldMarkers() {
        let result = DemoPDFBuilder.sanitizeMarkdownText("**粗体**")
        XCTAssertEqual(result, "粗体")
    }

    func testSanitizeMarkdownTextConvertsWikilinks() {
        let result = DemoPDFBuilder.sanitizeMarkdownText("[[双链]]")
        XCTAssertTrue(result.contains("「"))
        XCTAssertTrue(result.contains("」"))
    }

    func testSanitizeMarkdownTextStripsBackticks() {
        let result = DemoPDFBuilder.sanitizeMarkdownText("`代码`")
        XCTAssertEqual(result, "代码")
    }

    func testSanitizeMarkdownTextTrimsWhitespace() {
        let result = DemoPDFBuilder.sanitizeMarkdownText("  文本  ")
        XCTAssertEqual(result, "文本")
    }

    // MARK: - isTableSeparator

    func testIsTableSeparatorDetectsPipeWithDashes() {
        XCTAssertTrue(DemoPDFBuilder.isTableSeparator("|---|---|"))
    }

    func testIsTableSeparatorDetectsDashesWithPipes() {
        XCTAssertTrue(DemoPDFBuilder.isTableSeparator("| --- | --- |"))
    }

    func testIsTableSeparatorRejectsNormalText() {
        XCTAssertFalse(DemoPDFBuilder.isTableSeparator("普通文本"))
    }

    func testIsTableSeparatorRejectsPlainDashes() {
        XCTAssertFalse(DemoPDFBuilder.isTableSeparator("---"))
    }
}
#endif
