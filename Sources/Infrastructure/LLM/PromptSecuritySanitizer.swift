//
//  PromptSecuritySanitizer.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：通用提示词安全与沙箱转换器 (Universal Prompt Security & Sandboxing)。
//           防护 AI Chat、合成实验室 (Synthesis Lab) 与知识导入 (Ingestion) 免受 Prompt 越狱注入攻击。
//

import Foundation

/// 提示词安全防护错误枚举
public enum PromptSecurityError: LocalizedError, Equatable {
    case jailbreakAttemptDetected(pattern: String)

    public var errorDescription: String? {
        switch self {
        case .jailbreakAttemptDetected(let pattern):
            return L10n.AI.Prompt.jailbreakError(pattern)
        }
    }
}

/// 通用提示词安全沙箱与越狱注入拦截器
public struct PromptSecuritySanitizer: Sendable {

    /// 常见的越狱注入攻击特征词集
    private static let jailbreakPatterns: [String] = LLMConstants.PromptSecurity.jailbreakPatterns

    public init() {}

    private static let zeroWidthScalarSet: Set<UInt32> = [
        0x200B, // Zero-width space
        0x200C, // Zero-width non-joiner
        0x200D, // Zero-width joiner
        0xFEFF, // Zero-width no-break space (BOM)
        0x200E, // Left-to-right mark
        0x200F, // Right-to-left mark
        0x2060  // Word joiner
    ]

    /// 扫描输入文本中是否存在提示词注入越狱攻击
    /// - Parameter text: 待校验的原始文本
    /// - Throws: 发现注入模式时抛出 PromptSecurityError.jailbreakAttemptDetected
    public func scanJailbreakAttempt(in text: String) throws {
        // 预处理：基于 Unicode Scalar 严格移除零宽字符，防止字形簇合并绕过
        let cleanedScalars = text.unicodeScalars.filter { !Self.zeroWidthScalarSet.contains($0.value) }
        let lowered = String(cleanedScalars).lowercased()
        for pattern in Self.jailbreakPatterns where lowered.contains(pattern) {
            Logger.shared.warning("[PromptSecurity] 拦截越狱攻击特征: \(pattern)")
            throw PromptSecurityError.jailbreakAttemptDetected(pattern: pattern)
        }
    }

    /// 使用 XML 标签对 RAG 召回的知识库上下文进行沙箱包装，隔离外部非信任内容
    /// - Parameter context: 原始召回上下文
    /// - Returns: 经过 XML 沙箱包装后的上下文字符串
    public func sanitizeContext(_ context: String) -> String {
        let escaped = context
            .replacingOccurrences(of: LLMConstants.PromptTag.contextClose, with: LLMConstants.PromptTag.contextCloseEscaped)
            .replacingOccurrences(of: LLMConstants.PromptTag.contextOpen, with: LLMConstants.PromptTag.contextOpenEscaped)
        return "\(LLMConstants.PromptTag.contextOpen)\n\(escaped)\n\(LLMConstants.PromptTag.contextClose)"
    }

    /// 使用 XML 标签对用户输入的 Query 进行沙箱包装，防止其伪造 System Prompt
    /// - Parameter query: 原始用户输入
    /// - Returns: 经过 XML 沙箱包装后的用户 Query
    public func sanitizeUserQuery(_ query: String) -> String {
        let escaped = query
            .replacingOccurrences(of: LLMConstants.PromptTag.userQueryClose, with: LLMConstants.PromptTag.userQueryCloseEscaped)
            .replacingOccurrences(of: LLMConstants.PromptTag.userQueryOpen, with: LLMConstants.PromptTag.userQueryOpenEscaped)
        return "\(LLMConstants.PromptTag.userQueryOpen)\n\(escaped)\n\(LLMConstants.PromptTag.userQueryClose)"
    }
}
