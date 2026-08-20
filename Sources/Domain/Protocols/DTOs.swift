//
//  DTOs.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：跨层协议定义，建立 L0-L3 各层间的抽象契约。
//
import Foundation
import UFPCore

// MARK: - 协议定义

/// [Infra] 知识页面表征协议
/// 定义了知识页面在参与 LLM 交互时所需的核心属性，用于跨模块类型抹除。
public protocol KnowledgePageRepresentable: Sendable {
    var id: UUID { get }
    var title: String { get }
    var content: String { get }
    var tags: [String] { get }
    var pageType: PageType { get }
}

// MARK: - 基础 DTO

/// 统一的对话消息传输对象
public struct ChatMessageDTO: Codable, Identifiable, Sendable {
    public let id: UUID
    public let role: ChatRole
    public let content: String
    public var timestamp = Date()
    public var relatedPageIDs: [UUID] = []
    
    public enum ChatRole: String, Codable, Sendable {
        case user
        case assistant
        case system
    }
    
    public init(id: UUID = UUID(), role: ChatRole, content: String, timestamp: Date = Date(), relatedPageIDs: [UUID] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.relatedPageIDs = relatedPageIDs
    }
}

// MARK: - Chat Message Alias
public typealias ChatMessage = ChatMessageDTO

// MARK: - 业务 DTO

/// 智能解析/摄入任务的结果传输对象
public struct SmartIngestResultDTO: Codable, Sendable {
    public let title: String?
    public let compiledContent: String
    public let suggestedTags: [String]
    public let suggestedType: String
    public let relatedTitles: [String]
    public let summary: String

    public enum CodingKeys: String, CodingKey {
        case title
        case compiledContent = "compiled_content"
        case suggestedTags = "suggested_tags"
        case suggestedType = "suggested_type"
        case relatedTitles = "related_titles"
        case summary
    }
    
    public init(
        title: String?,
        compiledContent: String,
        suggestedTags: [String],
        suggestedType: String,
        relatedTitles: [String],
        summary: String
    ) {
        self.title = title
        self.compiledContent = compiledContent
        self.suggestedTags = suggestedTags
        self.suggestedType = suggestedType
        self.relatedTitles = relatedTitles
        self.summary = summary
    }
}

// MARK: - 重构建议 DTO

/// 知识重构建议的传输对象
public struct RefactorSuggestionDTO: Codable, Identifiable, Sendable {
    public var id: String { target + CoreConstants.TextSeparator.colon + type }
    public let type: String     // merge, split, rename
    public let target: String
    public let reason: String
    public let suggestion: String
    
    public init(type: String, target: String, reason: String, suggestion: String) {
        self.type = type
        self.target = target
        self.reason = reason
        self.suggestion = suggestion
    }
}

// MARK: - 日志审计 DTO
// LogStatus / LogEntry 已下移至 L0 Core/Base/Constants，供 Logger 与日志审计共享。
// LogStatus.localizedName 扩展见 Sources/Localization/Extensions/L10n+Common.swift。
