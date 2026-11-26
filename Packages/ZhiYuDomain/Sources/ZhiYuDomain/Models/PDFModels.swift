//
//  PDFModels.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：数据模型与状态管理，定义数据结构与 @Observable 状态。
//
import Foundation

// MARK: - PDF 文档模型

/// PDF 导入模式枚举
public enum PDFIngestMode: String, Codable, Sendable, CaseIterable {
    case fullText
    case pageRange
    case highlights
}

/// PDF 文档信息模型
///
/// 存储 PDF 文档的元数据，包括标题、页数、阅读进度、高亮内容和关联的知识库页面。
public struct PDFDocumentInfo: Identifiable, Codable, Sendable {
    public let id: UUID
    public var title: String
    public var fileName: String
    public var pageCount: Int
    public var addedDate: Date
    public var lastReadPage: Int
    public var highlights: [PDFHighlight]
    public var linkedPageTitles: [String]

    public init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        pageCount: Int,
        addedDate: Date = Date(),
        lastReadPage: Int = 0,
        highlights: [PDFHighlight] = [],
        linkedPageTitles: [String] = []
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.pageCount = pageCount
        self.addedDate = addedDate
        self.lastReadPage = lastReadPage
        self.highlights = highlights
        self.linkedPageTitles = linkedPageTitles
    }
}

// MARK: - PDF 高亮颜色

/// PDF 高亮颜色枚举
public enum PDFHighlightColor: String, Codable, Sendable, CaseIterable {
    case yellow
    case green
    case blue
    case pink
    case purple

    /// 所有颜色原始值，用于 UI 遍历
    public static var allRawValues: [String] { allCases.map(\.rawValue) }
}

// MARK: - PDF 高亮

/// PDF 高亮标记模型
public struct PDFHighlight: Identifiable, Codable, Sendable {
    public let id: UUID
    public var pageIndex: Int
    public var text: String
    public var color: String
    public var note: String
    public var creationDate: Date

    public init(
        id: UUID = UUID(),
        pageIndex: Int,
        text: String,
        color: String = PDFHighlightColor.yellow.rawValue,
        note: String = "",
        creationDate: Date = Date()
    ) {
        self.id = id
        self.pageIndex = pageIndex
        self.text = text
        self.color = color
        self.note = note
        self.creationDate = creationDate
    }
}
