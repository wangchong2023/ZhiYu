//
//  XlsxStringsProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：文档处理器：Markdown 解析、文本分块、图谱布局、网页抓取。
//
import Foundation

public final class XlsxSharedStringsParser: OOXMLParserBase {
    public private(set) var strings: [String] = []

    public override var textElementName: String { "t" }

    public override func onTextElementClose(elementName _: String, currentText: String) {
        strings.append(currentText)
    }
}
