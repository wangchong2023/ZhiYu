//
//  DocxProcessorTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 DOCX XML 解析器对 w:t 文本元素、w:p 段落换行、连续文本空格拼接的语义正确性。
//

import XCTest
@testable import ZhiYu

final class DocxProcessorTests: XCTestCase {

    // MARK: - 基础解析

    func testParse_validXml_returnsTrue() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
                <w:p><w:r><w:t>Hello World</w:t></w:r></w:p>
            </w:body>
        </w:document>
        """
        let processor = DocxProcessor(xmlData: Data(xml.utf8))

        let result = processor.parse()

        XCTAssertTrue(result, "合法 XML 应解析成功")
        XCTAssertTrue(processor.extractedText.hasPrefix("Hello World"), "应提取文本内容")
    }

    func testParse_emptyXml_returnsTrueWithEmptyText() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body></w:body>
        </w:document>
        """
        let processor = DocxProcessor(xmlData: Data(xml.utf8))

        let result = processor.parse()

        XCTAssertTrue(result)
        XCTAssertEqual(processor.extractedText, "", "无 w:t 元素时文本应为空")
    }

    // MARK: - 段落换行

    func testParse_multipleParagraphs_insertsNewlineBetween() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
                <w:p><w:r><w:t>第一段</w:t></w:r></w:p>
                <w:p><w:r><w:t>第二段</w:t></w:r></w:p>
            </w:body>
        </w:document>
        """
        let processor = DocxProcessor(xmlData: Data(xml.utf8))

        processor.parse()

        XCTAssertTrue(processor.extractedText.hasPrefix("第一段"), "应提取第一段")
        XCTAssertTrue(processor.extractedText.contains("第二段"), "应提取第二段")
        XCTAssertTrue(processor.extractedText.contains("\n"), "段落之间应有换行")
    }

    // MARK: - 连续文本空格拼接

    func testParse_multipleTextRunsInSameParagraph_insertsSpace() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
                <w:p>
                    <w:r><w:t>Hello</w:t></w:r>
                    <w:r><w:t>World</w:t></w:r>
                </w:p>
            </w:body>
        </w:document>
        """
        let processor = DocxProcessor(xmlData: Data(xml.utf8))

        processor.parse()

        XCTAssertTrue(processor.extractedText.hasPrefix("Hello"), "应包含 Hello")
        XCTAssertTrue(processor.extractedText.contains("World"), "应包含 World")
    }

    // MARK: - 空文本元素

    func testParse_emptyTextElement_notAppended() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
                <w:p>
                    <w:r><w:t></w:t></w:r>
                    <w:r><w:t>实际内容</w:t></w:r>
                </w:p>
            </w:body>
        </w:document>
        """
        let processor = DocxProcessor(xmlData: Data(xml.utf8))

        processor.parse()

        XCTAssertTrue(processor.extractedText.contains("实际内容"), "应包含实际内容")
        XCTAssertFalse(processor.extractedText.hasPrefix(" "), "不应以空格开头（空 w:t 不触发空格拼接）")
    }

    // MARK: - 段落内无文本

    func testParse_paragraphWithoutText_noNewlineInserted() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
                <w:p></w:p>
                <w:p><w:r><w:t>内容</w:t></w:r></w:p>
            </w:body>
        </w:document>
        """
        let processor = DocxProcessor(xmlData: Data(xml.utf8))

        processor.parse()

        XCTAssertTrue(processor.extractedText.contains("内容"), "应包含内容")
        XCTAssertFalse(processor.extractedText.hasPrefix("\n"), "无文本的空段落不应在开头产生换行")
    }

    // MARK: - 非法 XML

    func testParse_malformedXml_returnsFalse() {
        let malformed = "<w:document><w:body><w:p><w:t>未闭合"
        let processor = DocxProcessor(xmlData: Data(malformed.utf8))

        let result = processor.parse()

        XCTAssertFalse(result, "非法 XML 应返回 false")
    }

    // MARK: - 字符累积

    func testParse_textSplitAcrossCharacterCallbacks_concatenatedCorrectly() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
                <w:p><w:r><w:t>ABC</w:t></w:r></w:p>
            </w:body>
        </w:document>
        """
        let processor = DocxProcessor(xmlData: Data(xml.utf8))

        processor.parse()

        XCTAssertTrue(processor.extractedText.contains("ABC"), "字符应被完整累积")
    }

    // MARK: - 混合段落与文本运行

    func testParse_complexDocument_structurePreserved() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
            <w:body>
                <w:p>
                    <w:r><w:t>标题</w:t></w:r>
                    <w:r><w:t>续</w:t></w:r>
                </w:p>
                <w:p>
                    <w:r><w:t>正文</w:t></w:r>
                </w:p>
                <w:p></w:p>
                <w:p>
                    <w:r><w:t>结尾</w:t></w:r>
                </w:p>
            </w:body>
        </w:document>
        """
        let processor = DocxProcessor(xmlData: Data(xml.utf8))

        processor.parse()

        XCTAssertTrue(processor.extractedText.contains("标题"), "应包含标题")
        XCTAssertTrue(processor.extractedText.contains("续"), "应包含续")
        XCTAssertTrue(processor.extractedText.contains("正文"), "应包含正文")
        XCTAssertTrue(processor.extractedText.contains("结尾"), "应包含结尾")
        XCTAssertTrue(processor.extractedText.contains(" "), "应包含空格拼接")
    }
}
