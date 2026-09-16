//
//  CreatePageInput.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：封装 createPage / anyCreatePage 的参数列表，消除跨层参数转发重复。
//
import Foundation

/// 创建知识页面的输入参数封装。
///
/// 用途：消除 `AppStore` / `KnowledgeStore` / `KnowledgePageManager` / `SQLiteStore` /
/// `NoOpPageStoreCapabilities` 中 `createPage` 与 `anyCreatePage` 的重复参数列表转发，
/// 各层只需传递此结构体即可构造 `KnowledgePage`。
public struct CreatePageInput: Sendable {
    /// 页面标题
    public let title: String
    /// 页面类型
    public let pageType: PageType
    /// 自定义图标
    public let customIcon: String?
    /// 页面正文
    public let content: String
    /// 标签集合
    public let tags: [String]
    /// 数据源路径
    public let sourceURL: String?
    /// 原始文本片段
    public let rawSnippet: String?
    /// 文件物理大小
    public let fileSize: Int64?
    /// 源文件格式
    public let sourceType: String?

    public init(
        title: String,
        pageType: PageType,
        customIcon: String? = nil,
        content: String = "",
        tags: [String] = [],
        sourceURL: String? = nil,
        rawSnippet: String? = nil,
        fileSize: Int64? = nil,
        sourceType: String? = nil
    ) {
        self.title = title
        self.pageType = pageType
        self.customIcon = customIcon
        self.content = content
        self.tags = tags
        self.sourceURL = sourceURL
        self.rawSnippet = rawSnippet
        self.fileSize = fileSize
        self.sourceType = sourceType
    }
}

// MARK: - KnowledgePage 便捷构造

public extension KnowledgePage {
    /// 基于 `CreatePageInput` 构造 `KnowledgePage`，统一消除各层重复的构造调用。
    init(input: CreatePageInput) {
        self.init(
            title: input.title,
            pageType: input.pageType,
            customIcon: input.customIcon,
            content: input.content,
            tags: input.tags,
            sourceURL: input.sourceURL,
            rawTextSnippet: input.rawSnippet,
            fileSize: input.fileSize,
            sourceType: input.sourceType
        )
    }
}
