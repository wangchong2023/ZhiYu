//
//  DocumentFormat.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：应用级编译时常量定义（存储 key、超时、默认值等）。
//
import Foundation
import UFPCore

/// 智宇系统支持的外部导入文件格式定义 (DocumentFormat)
/// 本枚举代表待摄入资料的排版文件类型。
public enum DocumentFormat: Sendable {
    /// 标准 Markdown 文本格式 (.md, .markdown)
    case markdown
    /// 纯文本格式 (.txt, .text)
    case plainText
    /// Word 文档格式 (.docx)
    case docx
    /// Excel 表格格式 (.xlsx)
    case xlsx
    /// 便携式 PDF 格式 (.pdf)
    case pdf
    /// 暂不支持的未知格式
    case unknown

    /// 基于文件物理后缀名智能判定对应的文档格式
    /// - Parameter url: 文件的物理路径 URL
    /// - Returns: 返回解析出的对应 `DocumentFormat` 枚举值
    public static func detectFormat(from url: URL) -> DocumentFormat {
        let pathExtension = url.pathExtension.lowercased()
        switch pathExtension {
        case SystemConstants.FileExtension.markdown, SystemConstants.FileExtension.markdownLong:
            return .markdown
        case SystemConstants.FileExtension.text, SystemConstants.FileExtension.textLong:
            return .plainText
        case SystemConstants.FileExtension.docx:
            return .docx
        case SystemConstants.FileExtension.xlsx:
            return .xlsx
        case SystemConstants.FileExtension.pdf:
            return .pdf
        default:
            return .unknown
        }
    }
}
