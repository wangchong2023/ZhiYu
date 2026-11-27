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

    /// PII 脱敏正则规则集（使用数字负向边界替代 \b，修复中文紧贴场景下的脱敏绕过）
    private enum PIIPattern {
        /// 身份证号 (中国 18 位 / 15 位，兼容中文紧贴同时避免误伤 20+ 位数字流水号)
        static let chineseIDCard: String = #"(?<![\dA-Za-z])(?:\d{17}[\dXx]|\d{15})(?![\dA-Za-z])"#
        /// 信用卡号（连续 13-19 位或空格/连字符 4x4 分组格式）
        static let creditCard: String = #"(?<!\d)(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|3[47][0-9]{13}|6(?:011|5[0-9]{2})[0-9]{12}|(?:4\d{3}|5[1-5]\d{2})(?:[\s-]\d{4}){3})(?!\d)"#
        /// API Key / Secret Token / JWT（兼容 OpenAI sk-、Bearer、Gemini AIza、GitHub PAT 与 JWT）
        static let apiKeyAndSecret: String = #"(?i)(?:sk-[a-zA-Z0-9_-]{20,}|bearer\s+[a-zA-Z0-9._-]{20,}|AIza[0-9A-Za-z_-]{35}|gh[pousr]_[0-9A-Za-z]{36}|github_pat_[0-9A-Za-z_]{20,}|eyJ[A-Za-z0-9_-]{10,}\.eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,})"#
        /// 电子邮箱
        static let email: String = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        /// 手机号码 (中国 11 位 13x - 19x，兼容中文紧贴如「手机号13812345678请保存」)
        static let chineseMobile: String = #"(?<!\d)1[3-9]\d{9}(?!\d)"#

        static let all: [String] = [
            chineseIDCard,
            creditCard,
            apiKeyAndSecret,
            email,
            chineseMobile
        ]
    }

    /// 自动对文本中的隐私敏感数据实施掩码遮蔽
    /// - Parameter text: 原始输入文本
    /// - Returns: 脱敏处理后的安全文本
    public func mask(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        let rules = PIIPattern.all.map { (pattern: $0, template: CoreConstants.PIIMasking.redactedPII) }
        return RegexReplacementHelper.applyReplacements(text, rules: rules)
    }
}
