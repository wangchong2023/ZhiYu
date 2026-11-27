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

public final class ExcelProcessor: NSObject, XMLParserDelegate {
    private let xmlData: Data
    public private(set) var values: [String] = []
    private var inValueElement = false
    private var currentText = ""
    private var currentCellType: String?

    public init(xmlData: Data) {
        self.xmlData = xmlData
    }

    /// 启动 XML 解析：解析 XLSX 工作表 sheetN.xml，提取单元格数据。
    /// - Returns: true 表示解析成功
    @discardableResult
    public func parse() -> Bool {
        XMLParserLauncher.parse(xmlData: xmlData, delegate: self)
    }

    /// XMLParserDelegate: 元素开始 — 检测单元格 <c>、值节点 <v> 与内联文本节点 <t>，记录单元格类型 t 属性。
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == ProcessorConstants.OOXML.cellElement {
            currentCellType = attributeDict[ProcessorConstants.OOXML.cellTypeAttribute]
            currentText = ""
        } else if elementName == ProcessorConstants.OOXML.valueElement || elementName == ProcessorConstants.OOXML.textElement {
            inValueElement = true
        }
    }

    /// XMLParserDelegate: 字符捕获 — 在 <v>/<t> 节点内累积文本。
    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inValueElement {
            currentText += string
        }
    }

    /// XMLParserDelegate: 元素结束 — <v>/<t> 关闭时停止累积；<c> 关闭时提取共享字符串合法非负索引或直接单元格文本/数值。
    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == ProcessorConstants.OOXML.valueElement || elementName == ProcessorConstants.OOXML.textElement {
            inValueElement = false
        } else if elementName == ProcessorConstants.OOXML.cellElement {
            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                if currentCellType == ProcessorConstants.OOXML.cellTypeShared {
                    if let value = Int(trimmed), value >= 0, value < ProcessorConstants.OOXML.sharedStringIndexMax {
                        values.append("\(ProcessorConstants.OOXML.sharedStringIndexOpen)\(value)\(ProcessorConstants.OOXML.sharedStringIndexClose)")
                    }
                } else if currentCellType == nil
                    || currentCellType == ProcessorConstants.OOXML.cellTypeInlineString
                    || currentCellType == ProcessorConstants.OOXML.cellTypeFormulaString
                    || currentCellType == ProcessorConstants.OOXML.cellTypeNumber {
                    values.append(trimmed)
                }
            }
            currentCellType = nil
            currentText = ""
        }
    }
}
