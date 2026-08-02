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

    private init() {}

    /// 获取特定领域及场景Key的系统提示词
    /// - Parameters:
    ///   - domain: 业务领域 (Chat, Synthesis, Ingest, RAG, Refactor, VoiceNote)
    ///   - key: 场景主键
    /// - Returns: 本地化及版本管理后的 System Prompt 字符串
    public func getPrompt(domain: PromptDomain, key: String) -> String {
        switch domain {
        case .chat:
            return PromptService.shared.expansionSystemPrompt
        case .synthesis:
            return PromptService.shared.mindmapPrompt
        case .ingest:
            return "You are a professional knowledge curator. Structure, summarize, and extract key entities from incoming content."
        case .ragRetrieval:
            return PromptService.shared.queryExpansionPrompt
        case .knowledgeRefactor:
            return PromptService.shared.refactorPrompt
        case .voiceNote:
            return "You are a voice note summarizer. Organize transcriptions into concise bullet points and action items."
        }
    }

    /// 动态渲染安全的 Prompt 字符串，自动转义与套用安全沙箱
    public func buildPrompt(domain: PromptDomain, key: String = "default", variables: [String: String] = [:]) -> String {
        var base = getPrompt(domain: domain, key: key)
        for (varKey, varVal) in variables {
            // 转义并安全插值
            let safeVal = PromptSecurityGuard.shared.sanitize(varVal)
            base = base.replacingOccurrences(of: "{{\(varKey)}}", with: safeVal)
        }
        return base
    }
}
