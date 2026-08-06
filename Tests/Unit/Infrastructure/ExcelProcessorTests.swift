//
//  ExcelProcessorTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 XLSX 工作表 XML 解析器对单元格类型 (s/inlineStr)、共享字符串索引、值累积的语义正确性。
//

import XCTest
@testable import ZhiYu

final class ExcelProcessorTests: XCTestCase {

    // MARK: - 基础解析

    func testParse_validXml_returnsTrue() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
                <row>
                    <c t="s"><v>0</v></c>
                </row>
            </sheetData>
        </worksheet>
        """
        let processor = ExcelProcessor(xmlData: Data(xml.utf8))

        let result = processor.parse()

        XCTAssertTrue(result, "合法 XML 应解析成功")
    }

    func testParse_emptySheet_returnsTrueWithEmptyValues() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData></sheetData>
        </worksheet>
        """
        let processor = ExcelProcessor(xmlData: Data(xml.utf8))

        let result = processor.parse()

        XCTAssertTrue(result)
        XCTAssertTrue(processor.values.isEmpty, "无单元格时 values 应为空")
    }

    // MARK: - 共享字符串索引 (t="s")

    func testParse_sharedStringType_recordsIndexFormat() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
                <row>
                    <c t="s"><v>5</v></c>
                </row>
            </sheetData>
        </worksheet>
        """
        let processor = ExcelProcessor(xmlData: Data(xml.utf8))

        processor.parse()

        XCTAssertEqual(processor.values, ["[5]"], "t=\"s\" 类型应记录为 [索引] 格式")
    }

    func testParse_multipleSharedStringCells_allRecorded() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
                <row>
                    <c t="s"><v>0</v></c>
                    <c t="s"><v>1</v></c>
                    <c t="s"><v>2</v></c>
                </row>
            </sheetData>
        </worksheet>
        """
        let processor = ExcelProcessor(xmlData: Data(xml.utf8))

        processor.parse()

        XCTAssertEqual(processor.values, ["[0]", "[1]", "[2]"], "多个共享字符串单元格应全部记录")
    }

    // MARK: - inlineStr 类型

    func testParse_inlineStringType_recordsIndexFormat() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
                <row>
                    <c t="inlineStr"><v>3</v></c>
                </row>
            </sheetData>
        </worksheet>
        """
        let processor = ExcelProcessor(xmlData: Data(xml.utf8))

        processor.parse()

        XCTAssertEqual(processor.values, ["[3]"], "t=\"inlineStr\" 类型也应记录为 [索引] 格式")
    }

    // MARK: - 非字符串类型（数字单元格）

    func testParse_numericCell_notRecorded() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
                <row>
                    <c><v>42</v></c>
                </row>
            </sheetData>
        </worksheet>
        """
        let processor = ExcelProcessor(xmlData: Data(xml.utf8))

        processor.parse()

        XCTAssertTrue(processor.values.isEmpty, "无 t 属性的数字单元格不应被记录")
    }

    // MARK: - 空值单元格

    func testParse_emptyValueCell_notRecorded() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
                <row>
                    <c t="s"><v></v></c>
                </row>
            </sheetData>
        </worksheet>
        """
        let processor = ExcelProcessor(xmlData: Data(xml.utf8))

        processor.parse()

        XCTAssertTrue(processor.values.isEmpty, "空值的单元格不应被记录")
    }

    // MARK: - 索引上限保护

    func testParse_indexExceedingMax_notRecorded() {
        let hugeIndex = "20000"
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
                <row>
                    <c t="s"><v>\(hugeIndex)</v></c>
                </row>
            </sheetData>
        </worksheet>
        """
        let processor = ExcelProcessor(xmlData: Data(xml.utf8))

        processor.parse()

        XCTAssertTrue(processor.values.isEmpty, "超过 sharedStringIndexMax 的索引不应被记录")
    }

    // MARK: - 非数字值

    func testParse_nonNumericValueInSharedCell_notRecorded() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
                <row>
                    <c t="s"><v>abc</v></c>
                </row>
            </sheetData>
        </worksheet>
        """
        let processor = ExcelProcessor(xmlData: Data(xml.utf8))

        processor.parse()

        XCTAssertTrue(processor.values.isEmpty, "非数字值不应被记录为索引")
    }

    // MARK: - 非法 XML

    func testParse_malformedXml_returnsFalse() {
        let malformed = "<worksheet><sheetData><row><c t=\"s\"><v>0"
        let processor = ExcelProcessor(xmlData: Data(malformed.utf8))

        let result = processor.parse()

        XCTAssertFalse(result, "非法 XML 应返回 false")
    }

    // MARK: - 字符累积

    func testParse_valueSplitAcrossCallbacks_concatenatedCorrectly() {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
            <sheetData>
                <row>
                    <c t="s"><v>10</v></c>
                </row>
            </sheetData>
        </worksheet>
        """
        let processor = ExcelProcessor(xmlData: Data(xml.utf8))

        processor.parse()

        XCTAssertEqual(processor.values, ["[10]"], "值字符应被完整累积")
    }
}
