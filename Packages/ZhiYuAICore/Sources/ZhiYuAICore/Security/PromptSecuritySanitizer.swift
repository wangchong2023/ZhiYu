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

public struct PromptSecuritySanitizer: Sendable {

    public init() {}

    private enum EscapeTokens {
        static let lt = "&lt;"
        static let gt = "&gt;"
        static let singleSpace = " "
    }

    /// 使用指定 XML 标签安全包裹输入文本（转义同类开闭标签、带属性标签及带空白闭合标签，防止沙箱逃逸）
    public static func sanitizeAndWrap(_ input: String, tag: String) -> String {
        let openTag = "<\(tag)>"
        let closeTag = "</\(tag)>"
        let escapedTagName = NSRegularExpression.escapedPattern(for: tag)
        let pattern = "<(\\/?)\(escapedTagName)((?:\\s[^>]*)?\\/?)>"

        var escapedInput = input
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let fullRange = NSRange(escapedInput.startIndex..., in: escapedInput)
            let matches = regex.matches(in: escapedInput, range: fullRange)
            for match in matches.reversed() {
                guard let fullMatchRange = Range(match.range, in: escapedInput) else { continue }
                let slash = Range(match.range(at: 1), in: escapedInput).map { String(escapedInput[$0]) } ?? ""
                let suffix = Range(match.range(at: 2), in: escapedInput).map { String(escapedInput[$0]) } ?? ""
                escapedInput.replaceSubrange(fullMatchRange, with: "\(EscapeTokens.lt)\(slash)\(tag)\(suffix)\(EscapeTokens.gt)")
            }
        } else {
            escapedInput = input
                .replacingOccurrences(of: openTag, with: "\(EscapeTokens.lt)\(tag)\(EscapeTokens.gt)", options: .caseInsensitive)
                .replacingOccurrences(of: closeTag, with: "\(EscapeTokens.lt)/\(tag)\(EscapeTokens.gt)", options: .caseInsensitive)
        }

        return "\(openTag)\n\(escapedInput)\n\(closeTag)"
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
        // 兼容归一化（全角 ASCII 转半角等）+ 多空白/换行折叠为单空格
        let normalized = String(cleanedScalars)
            .precomposedStringWithCompatibilityMapping
            .replacingOccurrences(of: #"\s+"#, with: EscapeTokens.singleSpace, options: .regularExpression)
            .lowercased()
        let maliciousPatterns = [
            "ignore previous instructions",
            "ignore all instructions",
            "you are now in developer mode",
            "dan mode",
            "system prompt override",
            "bypass security checks"
        ]

        return maliciousPatterns.contains { pattern in
            normalized.contains(pattern)
        }
    }
}
