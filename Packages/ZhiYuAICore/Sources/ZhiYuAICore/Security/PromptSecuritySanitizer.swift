//
//  PromptSecuritySanitizer.swift
//  ZhiYuAICore
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[ZhiYuAICore]
//  核心职责：通用 XML 提示词沙箱隔离与越狱攻击拦截器 (Prompt Security Sanitizer)。
//

import Foundation
import UFPCore
import ZhiYuDomain

public enum PromptSecuritySanitizer {

    /// 使用指定 XML 标签安全包裹输入文本
    public static func sanitizeAndWrap(_ input: String, tag: String) -> String {
        let escapedInput = input
            .replacingOccurrences(of: "<\(tag)>", with: "&lt;\(tag)&gt;")
            .replacingOccurrences(of: "</\(tag)>", with: "&lt;/\(tag)&gt;")

        return "<\(tag)>\n\(escapedInput)\n</\(tag)>"
    }

    /// 扫描输入文本是否包含越狱/提权攻击模式
    public static func scanJailbreakAttempt(_ input: String) -> Bool {
        let lowercaseInput = input.lowercased()
        let maliciousPatterns = [
            "ignore previous instructions",
            "ignore all instructions",
            "you are now in developer mode",
            "dan mode",
            "system prompt override",
            "bypass security checks"
        ]

        return maliciousPatterns.contains { pattern in
            lowercaseInput.contains(pattern)
        }
    }
}
