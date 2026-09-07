//
//  BaseXMLTextParserDelegate.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：OOXML XMLParserDelegate 基类 — 封装 XML 数据持有、文本缓冲区与字符捕获，消除子类重复代码。
//

import Foundation

/// OOXML 文本解析代理基类
class BaseXMLTextParserDelegate: NSObject, XMLParserDelegate {
    let xmlData: Data
    var inTextElement: Bool = false
    var currentText: String = ""

    init(xmlData: Data) {
        self.xmlData = xmlData
        super.init()
    }

    /// 启动 XML 解析
    /// - Returns: true 表示解析成功
    func parse() -> Bool {
        let parser = XMLParser(data: xmlData)
        parser.delegate = self
        return parser.parse()
    }

    /// XMLParserDelegate: 字符捕获 — 在目标文本元素内部时累积字符。
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inTextElement {
            currentText += string
        }
    }
}
