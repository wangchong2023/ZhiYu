//
//  KnowledgePage.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义知识页面 (KnowledgePage) 的核心领域模型，包含页面内容、标签、置信度及关联来源。
//
import Foundation

// MARK: - Knowledge Page
/// 知识管理系统核心数据模型
public struct KnowledgePage: Identifiable, Codable, Hashable, Sendable, KnowledgePageRepresentable {
    public static let databaseTableName: String = AppConstants.Storage.Tables.pages
    
    public enum CodingKeys: String, CodingKey {
        case id, title, content, aliases, tags, status, confidence, sources
        case pageType = "page_type"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case customIcon = "custom_icon"
        case relatedPageIDs = "related_page_ids"
        case isPinned = "is_pinned"
        case contentHash = "content_hash"
        case sourceURL = "source_url"
        case rawTextSnippet = "raw_snippet"
        case fileSize = "file_size"
        case sourceType = "source_type"
        case lamportTimestamp = "lamport_timestamp"
    }
    
    /// 唯一标识符
    public var id: UUID
    
    /// 页面标题
    public var title: String
    
    /// 页面类型 (concept, entity, source, etc.)
    public var pageType: PageType
    
    /// 用户自定义图标 (SF Symbol 名称)，若为 nil 则使用类型默认图标
    public var customIcon: String?
    
    /// Markdown 原始内容
    public var content: String
    
    /// 别名列表
    public var aliases: [String]
    
    /// 标签列表
    public var tags: [String]
    
    /// 页面处理状态
    public var status: PageStatus
    
    /// AI 提取内容的置信度
    public var confidence: Confidence
    
    /// 原始资料来源 ID 引用列表
    public var sources: [String]
    
    /// 关联页面 ID 列表
    public var relatedPageIDs: [UUID]
    
    /// 是否已置顶
    public var isPinned: Bool
    
    /// 内容哈希，用于检测变更
    public var contentHash: String?
    
    /// 创建时间
    public var createdAt: Date
    
    /// 更新时间
    public var updatedAt: Date
    
    // MARK: - 分布式冲突解决 (LWW 策略)
    /// 逻辑时钟，用于解决多端同步冲突
    public var lamportTimestamp: Int64
    
    // MARK: - 溯源字段 (Karpathy 模式)
    /// 原始资料链接 (网页或 YouTube)
    public var sourceURL: String?
    /// 原始资料片段，用于校验
    public var rawTextSnippet: String?
    /// 文件大小 (字节)
    public var fileSize: Int64?
    /// 来源类型 (pdf, text, doc, etc.)
    public var sourceType: String?
    
    /// 显示图标：优先使用自定义图标，否则使用页面类型默认图标
    public var displayIcon: String {
        customIcon ?? pageType.icon
    }

    public init(
        id: UUID = UUID(),
        title: String,
        pageType: PageType = .concept,
        customIcon: String? = nil,
        content: String = "",
        aliases: [String] = [],
        tags: [String] = [],
        status: PageStatus = .active,
        confidence: Confidence = .medium,
        sources: [String] = [],
        relatedPageIDs: [UUID] = [],
        isPinned: Bool = false,
        contentHash: String? = nil,
        sourceURL: String? = nil,
        rawTextSnippet: String? = nil,
        fileSize: Int64? = nil,
        sourceType: String? = nil,
        lamportTimestamp: Int64? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.pageType = pageType
        self.customIcon = customIcon
        self.content = content
        self.aliases = aliases
        self.tags = tags
        self.status = status
        self.confidence = confidence
        self.sources = sources
        self.relatedPageIDs = relatedPageIDs
        self.isPinned = isPinned
        self.contentHash = contentHash
        self.sourceURL = sourceURL
        self.rawTextSnippet = rawTextSnippet
        self.fileSize = fileSize ?? Int64(content.utf8.count)
        self.sourceType = sourceType
        self.lamportTimestamp = lamportTimestamp ?? Int64(createdAt.timeIntervalSince1970 * SystemConstants.millisecondsPerSecond)
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// 执行 LWW (Last Write Wins) 冲突合并
    /// - Parameter remote: 远程或同步过来的版本
    /// - Returns: 合并后的最终版本
    public func merge(with remote: KnowledgePage) -> KnowledgePage {
        // 核心规则：时间戳大的胜出
        if remote.lamportTimestamp > self.lamportTimestamp {
            return remote
        } else if remote.lamportTimestamp < self.lamportTimestamp {
            return self
        } else {
            // 时间戳一致时，以更新时间为准
            return remote.updatedAt > self.updatedAt ? remote : self
        }
    }
    
    /// 执行 [[知识链接]] 提取
    public var outgoingLinks: [String] {
        AppLinkProcessor.extractOutgoingLinks(from: content)
    }
    
    /// 计算页面物理总字数
    public var wordCount: Int {
        PageContentUtility.calculateWordCount(content)
    }
    
    /// 是否为存根页面 (内容过少)
    public var isStub: Bool {
        content.count < SystemConstants.KnowledgePageThresholds.stubPageWordCount
    }
    
    /// 获取存储文件夹名称
    public var folderName: String {
        switch pageType {
        case .entity: return "entities"
        case .concept: return "concepts"
        case .source: return "sources"
        case .comparison: return "comparisons"
        case .raw: return "raw"
        }
    }

    /// 隐私敏感判定
    public var isPrivate: Bool {
        getAllTags().contains("private")
    }

    /// 获取所有标签（包括元数据标签和内容中的 #标签）
    public func getAllTags() -> [String] {
        PageContentUtility.extractAllTags(content: content, existingTags: tags)
    }
}

// MARK: - 页面来源展示美化扩展
extension KnowledgePage {
    /// 是否为本地文件来源
    public var isLocalFileSource: Bool {
        guard let urlStr = sourceURL else { return false }
        return urlStr.lowercased().hasPrefix("file://")
    }
    
    /// 来源在 UI 上的友好展示名称
    public var displaySourceName: String {
        guard let urlStr = sourceURL else { return "" }
        if isLocalFileSource {
            // 尝试将字符串解析为标准 URL，并提取最后的文件名组件
            if let url = URL(string: urlStr) {
                let lastComp = url.lastPathComponent
                // 当提取的组件非空且非根路径时直接返回
                if !lastComp.isEmpty && lastComp != "/" {
                    return lastComp
                }
            }
            // 兜底：若 URL 解析出的组件为空，通过 '/' 字符切片提取文件名组件
            // 必须排除 file:// 协议头中的斜杠（限制索引大于协议前缀末尾位置 6）
            if let lastSlash = urlStr.lastIndex(of: "/") {
                let prefixLimit = urlStr.index(urlStr.startIndex, offsetBy: 6, limitedBy: urlStr.endIndex) ?? urlStr.endIndex
                if lastSlash > prefixLimit {
                    let index = urlStr.index(after: lastSlash)
                    let sliceStr = String(urlStr[index...])
                    if !sliceStr.isEmpty {
                        return sliceStr
                    }
                }
            }
            // 最终兜底：返回原始 URL 字符串
            return urlStr
        } else {
            // 如果是网页，尝试获取其主机域名(Host)
            if let url = URL(string: urlStr), let host = url.host {
                return host
            }
            return urlStr
        }
    }
    
    /// 来源的显示图标 (SF Symbol 名称)
    public var displaySourceIcon: String {
        guard let type = sourceType?.lowercased() else {
            return isLocalFileSource ? "doc.fill" : "safari"
        }
        if type == "pdf" {
            return "doc.text.fill"
        } else if type == "markdown" || type == "md" || type == "txt" {
            return "doc.text"
        } else {
            return isLocalFileSource ? "doc.fill" : "safari"
        }
    }
}
