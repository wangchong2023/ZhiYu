//
//  ExcelProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：文档处理器：Markdown 解析、文本分块、图谱布局、网页抓取。
//
import Foundation

final class ExcelProcessor: NSObject, XMLParserDelegate {
    private let xmlData: Data
    private(set) var values: [String] = []
    private var inCellElement = false
    private var inValueElement = false
    private var currentText = ""
    private var currentCellType: String?

    init(xmlData: Data) {
        self.xmlData = xmlData
    }

    /// 启动 XML 解析：解析 XLSX 工作表 sheetN.xml，提取单元格数据。
    /// - Returns: true 表示解析成功
    func parse() -> Bool {
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        return parser.parse()
    }

    /// XMLParserDelegate: 元素开始 — 检测单元格 <c> 和值节点 <v>，记录单元格类型 t 属性。
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == ProcessorConstants.OOXML.cellElement {
            currentCellType = attributeDict[ProcessorConstants.OOXML.cellTypeAttribute]
            inCellElement = true
            currentText = ""
        } else if elementName == ProcessorConstants.OOXML.valueElement {
            inValueElement = true
            currentText = ""
        }
    }

    /// XMLParserDelegate: 字符捕获 — 在 <v> 值节点内累积文本。
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inValueElement {
            currentText += string
        }
    }

    /// XMLParserDelegate: 元素结束 — <v> 关闭时停止累积；<c> 关闭时将共享字符串索引 (t="s") 记录为待映射值。
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == ProcessorConstants.OOXML.valueElement {
            inValueElement = false
        } else if elementName == ProcessorConstants.OOXML.cellElement {
            if !currentText.isEmpty && (currentCellType == ProcessorConstants.OOXML.cellTypeShared || currentCellType == ProcessorConstants.OOXML.cellTypeInlineString) {
                if let value = Int(currentText), value < ProcessorConstants.OOXML.sharedStringIndexMax {
                    values.append("\(ProcessorConstants.OOXML.sharedStringIndexOpen)\(value)\(ProcessorConstants.OOXML.sharedStringIndexClose)")
                }
            }
            inCellElement = false
            currentCellType = nil
            currentText = ""
        }
    }
}
