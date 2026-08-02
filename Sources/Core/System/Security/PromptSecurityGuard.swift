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

    /// 对输入文本进行转义、脱敏与防越狱拦截
    /// - Parameter prompt: 用户原始提问或输入
    /// - Returns: 经过安全中和后的 Prompt 文本
    public func sanitize(_ prompt: String) -> String {
        // 1. PII 隐性数据脱敏
        var clean = PIIMasker.shared.mask(prompt)

        // 2. 特殊定界符转义，中和逃逸攻击
        for token in delimiterTokens {
            clean = clean.replacingOccurrences(of: token, with: "\\[ESCAPED_\(token)\\]")
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
