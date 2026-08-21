//
//  GlobalPromptRegistry.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：应用级 Prompt 统一集中注册中心，覆盖 Chat、Synthesis、Ingest、RAG、Refactor、VoiceNote。
//
import Foundation
import Dependencies

/// Prompt 变量插值标记常量
private enum PromptVariableSyntax {
    /// 变量占位符左定界符 `{{`
    static let openDelimiter = "{{"
    /// 变量占位符右定界符 `}}`
    static let closeDelimiter = "}}"
}

/// 业务 Prompt 模块领域划分
public enum PromptDomain: String, Sendable, CaseIterable {
    case chat
    case synthesis
    case ingest
    case ragRetrieval
    case knowledgeRefactor
    case voiceNote
}

/// 应用级 Prompt 统一集中注册中心
public final class GlobalPromptRegistry: Sendable {
    public static let shared = GlobalPromptRegistry()

    @ObservationIgnored private let promptService: PromptService

    private init() {
        self.promptService = PromptService(defaults: .standard)
    }

    /// 测试/自定义注入构造器
    public init(promptService: PromptService) {
        self.promptService = promptService
    }

    /// 获取特定领域及场景Key的系统提示词
    /// - Parameters:
    ///   - domain: 业务领域 (Chat, Synthesis, Ingest, RAG, Refactor, VoiceNote)
    ///   - key: 场景主键（当前实现按领域返回统一 Prompt，key 保留用于未来按场景细分扩展）
    /// - Returns: 本地化及版本管理后的 System Prompt 字符串
    public func getPrompt(domain: PromptDomain, key _: String) -> String {
        switch domain {
        case .chat:
            return promptService.expansionSystemPrompt
        case .synthesis:
            return promptService.mindmapPrompt
        case .ingest:
            return L10n.AI.Prompt.System.ingest
        case .ragRetrieval:
            return promptService.queryExpansionPrompt
        case .knowledgeRefactor:
            return promptService.refactorPrompt
        case .voiceNote:
            return L10n.AI.Prompt.System.voiceNote
        }
    }

    /// 动态渲染安全的 Prompt 字符串，自动转义与套用安全沙箱
    public func buildPrompt(domain: PromptDomain, key: String = "default", variables: [String: String] = [:]) -> String {
        var base = getPrompt(domain: domain, key: key)
        for (varKey, varVal) in variables {
            // 转义并安全插值
            let safeVal = PromptSecurityGuard.shared.sanitize(varVal)
            base = base.replacingOccurrences(of: PromptVariableSyntax.openDelimiter + varKey + PromptVariableSyntax.closeDelimiter, with: safeVal)
        }
        return base
    }
}
