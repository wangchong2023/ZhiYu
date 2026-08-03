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

/// OWASP Prompt 注入与越狱防范沙箱 Guard
public final class PromptSecurityGuard: Sendable {
    public static let shared = PromptSecurityGuard()

    private init() {}

    /// 核心系统定界符，须严防用户文本中的逃逸注入
    private let delimiterTokens = [
        "<|im_start|>", "<|im_end|>", "### System:", "### Assistant:", ["\\[", "SYS", "TEM", "_", "INS", "TRU", "CTI", "ON", "\\]"].joined()
    ]

    /// 将定界符 token 中性化，使其不再被 LLM 识别为系统定界符
    /// 策略：
    /// 1. 对 < > | 等 ASCII 特殊字符替换为全角字符（破坏 ChatML 定界符语义）
    /// 2. 对 ### 等 Markdown 定界符替换为全角字符（破坏角色标记语义）
    /// 3. 对 \\[ \\] 替换为全角字符（破坏指令注入标记语义）
    /// 4. 整体用 [ESCAPED_...] 包裹保留可读标记
    private func neutralizeToken(_ token: String) -> String {
        let neutralized = token
            .replacingOccurrences(of: "<", with: "〈")
            .replacingOccurrences(of: ">", with: "〉")
            .replacingOccurrences(of: "|", with: "｜")
            .replacingOccurrences(of: "#", with: "＃")
            .replacingOccurrences(of: "\\[", with: "【")
            .replacingOccurrences(of: "\\]", with: "】")
        return "[ESCAPED_\(neutralized)]"
    }

    /// 对输入文本进行转义、脱敏与防越狱拦截
    /// - Parameter prompt: 用户原始提问或输入
    /// - Returns: 经过安全中和后的 Prompt 文本
    public func sanitize(_ prompt: String) -> String {
        // 1. PII 隐性数据脱敏
        var clean = PIIMasker.shared.mask(prompt)

        // 2. 特殊定界符转义，中和逃逸攻击
        // 中性化策略：破坏 token 的 ASCII 特殊字符（< > |），使其不再被 LLM 识别为定界符
        // 同时用 [ESCAPED_...] 包裹保留可读标记
        for token in delimiterTokens {
            clean = clean.replacingOccurrences(of: token, with: neutralizeToken(token))
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
