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

    private static let zeroWidthScalarSet: Set<UInt32> = [
        0x200B, // Zero-width space
        0x200C, // Zero-width non-joiner
        0x200D, // Zero-width joiner
        0xFEFF, // Zero-width no-break space (BOM)
        0x200E, // Left-to-right mark
        0x200F, // Right-to-left mark
        0x2060  // Word joiner
    ]

    /// 扫描输入文本是否包含越狱/提权攻击模式
    public static func scanJailbreakAttempt(_ input: String) -> Bool {
        // 预处理：基于 Unicode Scalar 严格移除零宽字符，防止字形簇合并绕过
        let cleanedScalars = input.unicodeScalars.filter { !zeroWidthScalarSet.contains($0.value) }
        let lowercaseInput = String(cleanedScalars).lowercased()
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
