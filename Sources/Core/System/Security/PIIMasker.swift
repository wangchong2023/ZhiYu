//
//  PIIMasker.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：个人隐私数据 (PII) 自动脱敏引擎，屏蔽身份证、信用卡、API Key、电话号码与邮箱。
//
import Foundation

/// 个人隐私与敏感数据脱敏引擎
public final class PIIMasker: Sendable {
    public static let shared = PIIMasker()

    private init() {}

    private let piiPatterns: [String] = [
        // 身份证号 (中国 18 位 / 15 位)
        #"\b\d{17}[\dXx]|\b\d{15}\b"#,
        // 信用卡号 (13 - 19 位数字)
        #"\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12})\b"#,
        // API Key / Secret Token (如 sk-xxx, bearer xxx)
        #"(?i)(?:sk-[a-zA-Z0-9]{20,}|bearer\s+[a-zA-Z0-9._-]{20,})"#,
        // 电子邮箱
        #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#,
        // 手机号码 (中国 11 位 13x - 19x)
        #"\b1[3-9]\d{9}\b"#
    ]

    /// 自动对文本中的隐私敏感数据实施掩码遮蔽
    /// - Parameter text: 原始输入文本
    /// - Returns: 脱敏处理后的安全文本
    public func mask(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        var masked = text

        for pattern in piiPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(location: 0, length: masked.utf16.count)
                masked = regex.stringByReplacingMatches(in: masked, options: [], range: range, withTemplate: "[REDACTED_PII]")
            }
        }

        return masked
    }
}
