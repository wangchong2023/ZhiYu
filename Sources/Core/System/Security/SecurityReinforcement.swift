//
//  SecurityReinforcement.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：日志脱敏：多提供商 API key、Authorization header 等 PII 信息脱敏。
//
import Foundation

/// 日志脱敏层 (Security Item)
struct LogMasker {
    /// 脱敏 PII 信息（如 API Key, 用户邮箱等）
    /// - Note: VULN-015 修复：覆盖多提供商 key 格式 + Authorization header
    static func mask(_ content: String) -> String {
        let rules: [(pattern: String, template: String)] = [
            ("sk-[a-zA-Z0-9]{32,}", "sk-****"),                          // OpenAI / DeepSeek / Qwen
            ("sk-ant-[a-zA-Z0-9_-]{20,}", "sk-ant-****"),                // Anthropic
            ("AIza[0-9A-Za-z_-]{35}", "AIza****"),                       // Google
            ("[a-f0-9]{32}\\.[a-zA-Z0-9]{16}", "****.****"),             // Zhipu (xxx.xxx)
            ("(?i)authorization:\\s*bearer\\s+[a-zA-Z0-9._-]+", "Authorization: Bearer ****") // Auth header
        ]
        return RegexReplacementHelper.applyReplacements(content, rules: rules)
    }
}
