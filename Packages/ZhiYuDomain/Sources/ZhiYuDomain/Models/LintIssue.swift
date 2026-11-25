//
//  LintIssue.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义代码/内容质量检查 (Lint) 的问题报告领域模型，含潜在链接建议、严重级别与修正指引。
//
import Foundation

// MARK: - Potential Link Suggestion
public struct PotentialLinkSuggestion: Identifiable, Codable, Sendable {
    public var id = UUID()
    public let sourcePageID: UUID
    public let sourceTitle: String
    public let targetTitle: String
    
    public init(id: UUID = UUID(), sourcePageID: UUID, sourceTitle: String, targetTitle: String) {
        self.id = id
        self.sourcePageID = sourcePageID
        self.sourceTitle = sourceTitle
        self.targetTitle = targetTitle
    }
}

// MARK: - Lint Issue
public struct LintIssue: Identifiable, Codable, Sendable {
    public var id = UUID()
    public var severity: LintSeverity
    public var type: IssueType = .generic
    public var pageID: UUID?
    public var message: String
    public var suggestion: String
    
    public enum IssueType: String, Codable, Sendable {
        case generic
        case brokenLink
        case orphan
        case island
        case cycle
        case stub
        case stale
        
        public var icon: String {
            switch self {
            case .brokenLink: return "link"
            case .orphan: return "person.crop.circle.badge.questionmark"
            case .island: return "leaf.fill"
            case .cycle: return "arrow.2.squarepath"
            case .stub: return "doc.append"
            case .stale: return "clock.arrow.circlepath"
            default: return "sparkles"
            }
        }
    }

    public enum LintSeverity: String, Codable, Sendable {
        case error
        case warning
        case info

        public var icon: String {
            switch self {
            case .error: return "xmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .info: return "info.circle.fill"
            }
        }

        public var colorName: String {
            switch self {
            case .error: return "red"
            case .warning: return "orange"
            case .info: return "blue"
            }
        }
    }

    public init(id: UUID = UUID(), severity: LintSeverity, type: IssueType = .generic, pageID: UUID? = nil, message: String, suggestion: String) {
        self.id = id
        self.severity = severity
        self.type = type
        self.pageID = pageID
        self.message = message
        self.suggestion = suggestion
    }
}
