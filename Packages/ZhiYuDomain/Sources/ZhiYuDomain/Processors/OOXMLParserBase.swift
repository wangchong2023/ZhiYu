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
import UFPCore

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

    /// 启动 XML 解析（统一委托至带 XXE / DTD 防护的 XMLParserLauncher）
    /// - Returns: true 表示解析成功
    @discardableResult
    public func parse() -> Bool {
        XMLParserLauncher.parse(xmlData: xmlData, delegate: self)
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

/// XMLParser 启动辅助：封装安全检查与 `XMLParser(data:) + delegate + parse()` 样板。
/// 遵循 ECMA-376 OOXML 规范，强制禁止 DTD / `<!DOCTYPE` / `<!ENTITY` 与外部实体解析，防御 XXE 与 Billion Laughs 攻击。
public enum XMLParserLauncher {
    private enum SecurityLimits {
        /// 单个 OOXML XML 部件大小上限（32 MB）
        static let maxXMLDataMB: Int = 32
        static let maxXMLDataBytes: Int = maxXMLDataMB * Int(SystemConstants.bytesPerMB)
        /// 禁止出现在 OOXML XML 中的 DTD/实体声明特征（不区分大小写）
        static let forbiddenDeclarations: [String] = [
            "<!doctype",
            "<!entity"
        ]
    }

    /// 校验 XML 载荷是否安全（未超限且不含 DTD / 实体声明）
    public static func isSafeXMLPayload(_ xmlData: Data) -> Bool {
        guard xmlData.count <= SecurityLimits.maxXMLDataBytes else { return false }
        let rawText = String(data: xmlData, encoding: .utf8) ?? String(data: xmlData, encoding: .isoLatin1) ?? ""
        let inspectText = rawText.lowercased()
        return !SecurityLimits.forbiddenDeclarations.contains { inspectText.contains($0) }
    }

    /// 启动 XML 解析并返回是否成功
    /// - Parameters:
    ///   - xmlData: 待解析的 XML 数据
    ///   - delegate: XMLParser 代理
    /// - Returns: true 表示解析成功；若触发 XXE/DTD 或体积超限守卫则直接返回 false
    @discardableResult
    public static func parse(xmlData: Data, delegate: XMLParserDelegate) -> Bool {
        guard isSafeXMLPayload(xmlData) else { return false }
        let parser = XMLParser(data: xmlData)
        parser.shouldResolveExternalEntities = false
        parser.externalEntityResolvingPolicy = .never
        parser.delegate = delegate
        return parser.parse()
    }
}
