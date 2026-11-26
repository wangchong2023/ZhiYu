//
//  OOXMLParserBase.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：OOXML (DOCX/XLSX) XMLParserDelegate 公共基类，消除文本元素累积重复代码。
//
import Foundation

// MARK: - OOXML XMLParserDelegate 公共基类

/// OOXML 文档解析器的公共基类，封装"进入文本元素 → 累积字符 → 闭合元素追加"的通用模式。
/// 子类只需重写 `textElementName` 与 `onTextElementClose(_:currentText:)` 即可。
open class OOXMLParserBase: NSObject, XMLParserDelegate {
    public let xmlData: Data
    public var inTextElement = false
    public var currentText = ""

    public init(xmlData: Data) {
        self.xmlData = xmlData
    }

    /// 子类指定文本元素标签名（如 "w:t" 或 "t"）
    open var textElementName: String { "" }

    /// 子类指定段落元素标签名（如 "w:p"），默认空字符串表示不处理段落换行
    open var paragraphElementName: String { "" }

    /// 启动 XML 解析
    /// - Returns: true 表示解析成功
    @discardableResult
    public func parse() -> Bool {
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        return parser.parse()
    }

    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        if elementName == textElementName {
            inTextElement = true
            currentText = ""
        }
        onDidStartElement(elementName: elementName, attributes: attributeDict)
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inTextElement {
            currentText += string
        }
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == textElementName {
            onTextElementClose(elementName: elementName, currentText: currentText)
            inTextElement = false
            currentText = ""
        } else if !paragraphElementName.isEmpty && elementName == paragraphElementName {
            onParagraphClose(elementName: elementName)
        }
    }

    /// 子类钩子：元素开始时额外处理（如记录属性）
    open func onDidStartElement(elementName _: String, attributes _: [String: String]) {}

    /// 子类钩子：文本元素闭合时处理累积文本
    open func onTextElementClose(elementName _: String, currentText: String) {}

    /// 子类钩子：段落元素闭合时处理（如插入换行）
    open func onParagraphClose(elementName _: String) {}
}

// MARK: - XMLParser 启动辅助

/// XMLParser 启动辅助：封装 `XMLParser(data:) + delegate + parse()` 样板，消除各 XMLParserDelegate 实现间的 parse() 重复。
public enum XMLParserLauncher {
    /// 启动 XML 解析并返回是否成功
    /// - Parameters:
    ///   - xmlData: 待解析的 XML 数据
    ///   - delegate: XMLParser 代理
    /// - Returns: true 表示解析成功
    @discardableResult
    public static func parse(xmlData: Data, delegate: XMLParserDelegate) -> Bool {
        let parser = XMLParser(data: xmlData)
        parser.delegate = delegate
        return parser.parse()
    }
}
