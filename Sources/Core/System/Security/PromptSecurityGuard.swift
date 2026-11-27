//
//  PromptSecurityGuard.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：Prompt OWASP 越狱注入拦截、定界符转义与物理金沙箱隔离包裹。
//
import Foundation
import UFPCore

/// OWASP Prompt 注入与越狱防范沙箱 Guard
public final class PromptSecurityGuard: Sendable {
    public static let shared = PromptSecurityGuard()

    private init() {}

    private enum GuardConstants {
        static let fullWidthSlash = "／"
        /// 零宽与不可见格式控制字符集合，防止攻击者插入零宽字符绕过定界符与 OWASP 注入检测
        static let invisibleBypassScalars: Set<Unicode.Scalar> = [
            "\u{200B}", // Zero Width Space
            "\u{200C}", // Zero Width Non-Joiner
            "\u{200D}", // Zero Width Joiner
            "\u{2060}", // Word Joiner
            "\u{FEFF}", // Zero Width No-Break Space / BOM
            "\u{00AD}"  // Soft Hyphen
        ]
        /// XML 沙箱标签与主流开源模型定界符（Llama-3 / Mistral / ChatML 扩展）
        static let extraDelimiterTokens: [String] = [
            "<context_sandbox>",
            "</context_sandbox>",
            "<|begin_of_text|>",
            "<|end_of_text|>",
            "<|start_header_id|>",
            "<|end_header_id|>",
            "<|eot_id|>",
            "[INST]",
            "[/INST]",
            "<<SYS>>",
            "<</SYS>>"
        ]
    }

    /// 核心系统定界符，须严防用户文本中的逃逸注入
    private var delimiterTokens: [String] {
        [
            CoreConstants.PromptInjection.imStart,
            CoreConstants.PromptInjection.imEnd,
            CoreConstants.PromptInjection.systemMarker,
            CoreConstants.PromptInjection.assistantMarker,
            [
                CoreConstants.PromptInjection.escapedBracketOpen,
                CoreConstants.PromptInjection.instructionFragmentSys,
                CoreConstants.PromptInjection.instructionFragmentTem,
                CoreConstants.PromptInjection.instructionFragmentUnderscore,
                CoreConstants.PromptInjection.instructionFragmentIns,
                CoreConstants.PromptInjection.instructionFragmentTru,
                CoreConstants.PromptInjection.instructionFragmentCti,
                CoreConstants.PromptInjection.instructionFragmentOn,
                CoreConstants.PromptInjection.escapedBracketClose
            ].joined()
        ] + GuardConstants.extraDelimiterTokens
    }

    /// 将定界符 token 中性化，使其不再被 LLM 识别为系统定界符
    /// 策略：
    /// 1. 对 < > | / 等 ASCII 特殊字符替换为全角字符（破坏 ChatML 与 XML 沙箱定界符语义）
    /// 2. 对 ### 等 Markdown 定界符替换为全角字符（破坏角色标记语义）
    /// 3. 对 [ ] 及 \\[ \\] 替换为全角字符（破坏指令注入标记语义）
    /// 4. 整体用 [ESCAPED_...] 包裹保留可读标记
    private func neutralizeToken(_ token: String) -> String {
        let neutralized = token
            .replacingOccurrences(of: SystemConstants.Character.lessThan, with: CoreConstants.PromptInjection.fullWidthLessThan)
            .replacingOccurrences(of: SystemConstants.Character.greaterThan, with: CoreConstants.PromptInjection.fullWidthGreaterThan)
            .replacingOccurrences(of: SystemConstants.Character.pipe, with: CoreConstants.PromptInjection.fullWidthPipe)
            .replacingOccurrences(of: SystemConstants.Character.hash, with: CoreConstants.PromptInjection.fullWidthHash)
            .replacingOccurrences(of: SystemConstants.Character.slash, with: GuardConstants.fullWidthSlash)
            .replacingOccurrences(of: CoreConstants.PromptInjection.escapedBracketOpen, with: CoreConstants.PromptInjection.fullWidthOpenBracket)
            .replacingOccurrences(of: CoreConstants.PromptInjection.escapedBracketClose, with: CoreConstants.PromptInjection.fullWidthCloseBracket)
            .replacingOccurrences(of: SystemConstants.Character.openBracket, with: CoreConstants.PromptInjection.fullWidthOpenBracket)
            .replacingOccurrences(of: SystemConstants.Character.closeBracket, with: CoreConstants.PromptInjection.fullWidthCloseBracket)
        return "\(CoreConstants.PromptInjection.escapedPrefix)\(neutralized)\(CoreConstants.PromptInjection.escapedSuffix)"
    }

    /// 对输入文本进行转义、脱敏与防越狱拦截
    /// - Parameter prompt: 用户原始提问或输入
    /// - Returns: 经过安全中和后的 Prompt 文本
    public func sanitize(_ prompt: String) -> String {
        // 0. 剥离零宽与不可见混淆字符，阻断 `<\u{200B}|im_start|>` / `ig\u{200B}nore` 绕过
        var clean = String(prompt.unicodeScalars.filter { !GuardConstants.invisibleBypassScalars.contains($0) })

        // 1. PII 隐性数据脱敏
        clean = PIIMasker.shared.mask(clean)

        // 2. 特殊定界符转义，中和逃逸攻击
        // 中性化策略：破坏 token 的 ASCII 特殊字符（< > | / [ ]），使其不再被 LLM 识别为定界符
        // 同时用 [ESCAPED_...] 包裹保留可读标记
        for token in delimiterTokens {
            clean = clean.replacingOccurrences(of: token, with: neutralizeToken(token), options: .caseInsensitive)
        }

        // 3. 基础 PromptSanitizer OWASP 拦截
        return PromptSanitizer.shared.sanitize(clean)
    }

    /// 上下文安全沙箱包裹
    public func wrapInSandbox(_ content: String) -> String {
        let safeContent = sanitize(content)
        return PromptSanitizer.shared.wrapInSandbox(safeContent)
    }
}
