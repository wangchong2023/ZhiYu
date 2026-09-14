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

final class DocxProcessor: OOXMLParserBase {
    private(set) var extractedText: String = ""
    private var lastWasText = false

    override var textElementName: String { ProcessorConstants.OOXML.wordText }
    override var paragraphElementName: String { ProcessorConstants.OOXML.wordParagraph }

    override func onTextElementClose(elementName: String, currentText: String) {
        if !currentText.isEmpty {
            if lastWasText {
                extractedText += ProcessorConstants.Whitespace.space
            }
            extractedText += currentText
            lastWasText = true
        }
    }

    override func onParagraphClose(elementName: String) {
        if lastWasText {
            extractedText += ProcessorConstants.Whitespace.newline
            lastWasText = false
        }
    }
}
