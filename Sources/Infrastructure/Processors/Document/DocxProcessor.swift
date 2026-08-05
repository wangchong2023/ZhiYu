//
//  DocxProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：文档处理器：Markdown 解析、文本分块、图谱布局、网页抓取。
//
import Foundation

final class DocxProcessor: NSObject, XMLParserDelegate {
    private let xmlData: Data
    private(set) var extractedText: String = ""
    private var inTextElement = false
    private var currentText = ""
    private var lastWasText = false

    init(xmlData: Data) {
        self.xmlData = xmlData
    }

    /// 启动 XML 解析：解析 DOCX 的 word/document.xml 中 w:t 元素提取纯文本。
    /// - Returns: true 表示解析成功
    func parse() -> Bool {
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        return parser.parse()
    }

    /// XMLParserDelegate: 元素开始 — 检测到 w:t（文本运行）时标记进入文本元素。
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == ProcessorConstants.OOXML.wordText {
            inTextElement = true
            currentText = ""
        }
    }

    /// XMLParserDelegate: 字符捕获 — 在 w:t 内部时累积文本字符。
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inTextElement {
            currentText += string
        }
    }

    /// XMLParserDelegate: 元素结束 — w:t 闭合时追加文本（前加空格）；w:p 闭合时插入换行符。
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == ProcessorConstants.OOXML.wordText {
            if !currentText.isEmpty {
                if lastWasText {
                    extractedText += ProcessorConstants.Whitespace.space
                }
                extractedText += currentText
                lastWasText = true
            }
            inTextElement = false
            currentText = ""
        } else if elementName == ProcessorConstants.OOXML.wordParagraph {
            if lastWasText {
                extractedText += ProcessorConstants.Whitespace.newline
                lastWasText = false
            }
        }
    }
}
