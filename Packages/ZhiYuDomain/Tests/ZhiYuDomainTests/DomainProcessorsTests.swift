//
//  DomainProcessorsTests.swift
//  ZhiYuDomainTests
//
//  系统层级：[ZhiYuDomainTests]
//  核心职责：验证下沉至 ZhiYuDomain 的 WikiLinkExtractor、MermaidSanitizer、ThinkingProcessor 与 FrontmatterDocumentModels。
//

import XCTest
@testable import ZhiYuDomain

final class DomainProcessorsTests: XCTestCase {

    func testWikiLinkExtractorParsesPlainAndAliasedLinks() {
        let links = WikiLinkExtractor.extractLinks(from: "参见 [[知识图谱]] 与 [[RAG架构|检索增强]]，忽略 \\[[转义]]")
        XCTAssertEqual(links.count, 2)
        XCTAssertEqual(links[0].targetTitle, "知识图谱")
        XCTAssertNil(links[0].alias)
        XCTAssertEqual(links[0].displayTitle, "知识图谱")
        XCTAssertEqual(links[1].targetTitle, "RAG架构")
        XCTAssertEqual(links[1].alias, "检索增强")
        XCTAssertEqual(links[1].displayTitle, "检索增强")
    }

    func testMermaidSanitizerQuotesSpecialCharactersInLabels() {
        let raw = """
        flowchart TD
        A[Node (With Paren)] --> B[CleanNode]
        """
        let sanitized = MermaidSanitizer.sanitize(raw)
        XCTAssertTrue(sanitized.contains(#"A["Node (With Paren)"]"#))
        XCTAssertTrue(sanitized.contains("B[CleanNode]"))
    }

    func testThinkingProcessorExtractsThinkTagAndMainAnswer() {
        let raw = "<think>先分析上下文再归纳结论</think>\n最终回答内容"
        let result = ThinkingProcessor.process(raw)
        XCTAssertEqual(result.thinkingContent, "先分析上下文再归纳结论")
        XCTAssertEqual(result.mainContent, "最终回答内容")
    }

    func testThinkingProcessorHandlesPlainAnswerWithoutThinking() {
        let result = ThinkingProcessor.process("直接回答无思考标签")
        XCTAssertNil(result.thinkingContent)
        XCTAssertEqual(result.mainContent, "直接回答无思考标签")
    }

    func testMatrixValueCodableRoundTrip() throws {
        let cells: [MatrixValue] = [.text("高"), .rating(4.8), .range(min: 1.0, max: 5.0), .imageList(["a.png"]), .null]
        let data = try JSONEncoder().encode(cells)
        let decoded = try JSONDecoder().decode([MatrixValue].self, from: data)
        XCTAssertEqual(decoded, cells)
    }

    func testDocxProcessorExtractsParagraphs() {
        let xml = "<w:document><w:p><w:t>Hello</w:t><w:t>World</w:t></w:p><w:p><w:t>Line2</w:t></w:p></w:document>"
        let processor = DocxProcessor(xmlData: Data(xml.utf8))
        XCTAssertTrue(processor.parse())
        XCTAssertEqual(processor.extractedText, "Hello World\nLine2\n")
    }

    func testExcelAndSharedStringsProcessorsExtractValues() {
        let sst = "<sst><si><t>CellA</t></si><si><t>CellB</t></si></sst>"
        let sstParser = XlsxSharedStringsParser(xmlData: Data(sst.utf8))
        XCTAssertTrue(sstParser.parse())
        XCTAssertEqual(sstParser.strings, ["CellA", "CellB"])

        let sheet = #"<worksheet><c t="s"><v>0</v></c><c t="s"><v>1</v></c></worksheet>"#
        let sheetParser = ExcelProcessor(xmlData: Data(sheet.utf8))
        XCTAssertTrue(sheetParser.parse())
        XCTAssertEqual(sheetParser.values.count, 2)
    }

    /// 缺陷 #193 回归：ExcelProcessor 拦截负数共享字符串索引，并完整提取内联字符串、公式字符串与数值单元格
    func testExcelProcessorHandlesInlineStrFormulaNumberAndRejectsNegativeSharedIndex() {
        let sheet = """
        <worksheet>
            <c t="s"><v>-1</v></c>
            <c t="s"><v>0</v></c>
            <c t="inlineStr"><is><t>内联标题</t></is></c>
            <c t="str"><v>公式结果</v></c>
            <c><v>1234.56</v></c>
            <c t="n"><v>99</v></c>
        </worksheet>
        """
        let parser = ExcelProcessor(xmlData: Data(sheet.utf8))
        XCTAssertTrue(parser.parse())
        XCTAssertEqual(parser.values, ["[0]", "内联标题", "公式结果", "1234.56", "99"])
    }

    func testSwiftMarkdownASTCleanerClosesUnclosedFenceAndBold() {
        let brokenFence = "```swift\nlet x = 1\n\n\n\nlet y = 2"
        let cleanedFence = SwiftMarkdownASTCleaner.cleanAST(brokenFence)
        XCTAssertFalse(cleanedFence.contains("\n\n\n"))
        XCTAssertEqual(cleanedFence.components(separatedBy: "```").count - 1, 2, "未闭合代码块应自动补齐闭合围栏")

        let brokenBold = "正文包含 **未闭合粗体"
        let cleanedBold = SwiftMarkdownASTCleaner.cleanAST(brokenBold)
        XCTAssertTrue(cleanedBold.hasSuffix("**"), "围栏外未闭合粗体应自动补齐 **")
    }

    /// 缺陷 #196 回归：围栏代码块内的 `**`（如 Python 幂运算或 C 二级指针）不得触发末尾误追加孤立 `**`
    func testSwiftMarkdownASTCleanerIgnoresBoldMarkersInsideCodeFences() {
        let pythonDoc = """
        正文说明

        ```python
        power = 2 ** 8
        ```
        """
        let cleaned = SwiftMarkdownASTCleaner.cleanAST(pythonDoc)
        XCTAssertFalse(cleaned.hasSuffix("**"), "代码块内的幂运算符 ** 不得被误判为未闭合粗体")
        XCTAssertTrue(cleaned.contains("power = 2 ** 8"))
    }

    func testMarkdownProcessorParsesBlocksAndInlineAppLinks() {
        let md = """
        # 标题一
        - 列表项 A
        - 列表项 B

        正文包含 **加粗** 与 [[目标页面|显示名]]。
        """
        let processor = MarkdownProcessor()
        let blocks = processor.parse(md)
        XCTAssertEqual(blocks.count, 3)

        let segments = processor.parseInlineSegments("前文 **重点** 与 [[知识图谱|图谱]] 后文")
        XCTAssertTrue(segments.contains { $0.type == .bold && $0.content == "重点" })
        XCTAssertTrue(segments.contains { $0.type == .applink && $0.content == "知识图谱|图谱" })
    }

    func testVoiceRecordingAndPDFModelsCodableRoundTrip() throws {
        let rec = VoiceRecording(title: "会议录音", text: "纪要内容", language: "zh-CN", duration: 42.5)
        let recData = try JSONEncoder().encode(rec)
        let decodedRec = try JSONDecoder().decode(VoiceRecording.self, from: recData)
        XCTAssertEqual(decodedRec.title, "会议录音")
        XCTAssertEqual(decodedRec.duration, 42.5)

        let highlight = PDFHighlight(pageIndex: 2, text: "核心定理", color: PDFHighlightColor.green.rawValue, note: "重点")
        let pdfInfo = PDFDocumentInfo(title: "论文", fileName: "paper.pdf", pageCount: 12, highlights: [highlight])
        let pdfData = try JSONEncoder().encode(pdfInfo)
        let decodedPDF = try JSONDecoder().decode(PDFDocumentInfo.self, from: pdfData)
        XCTAssertEqual(decodedPDF.pageCount, 12)
        XCTAssertEqual(decodedPDF.highlights.first?.text, "核心定理")
        XCTAssertEqual(PDFHighlightColor.allRawValues.count, 5)
        XCTAssertEqual(PDFIngestMode.allCases.count, 3)
    }

    func testDemoMediaConstantsAndAudioBuilder() {
        XCTAssertEqual(DemoMediaConstants.audioSampleRate, 44100.0)
        XCTAssertEqual(DemoMediaConstants.chordFrequencies.count, 4)
        #if canImport(AVFoundation)
        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_demo_\(UUID().uuidString).wav").path
        defer { try? FileManager.default.removeItem(atPath: tempPath) }
        let url = DemoAudioBuilder.ensureAudioExists(at: tempPath, duration: 0.2)
        XCTAssertNotNil(url)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempPath))
        #endif
    }
}
