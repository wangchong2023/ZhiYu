//
//  ContentModerationEngine.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：AC 自动机 / Trie 树政治、黄色、暴恐合规检测引擎与 3 级非合规处置逻辑。
//
import Foundation

/// 违规合规分类
public enum ComplianceCategory: String, CaseIterable, Sendable {
    case politicalReactionary = "political_reactionary" // 政治与反动
    case adultNSFW = "adult_nsfw"                       // 黄色与色情
    case violenceTerrorism = "violence_terrorism"       // 暴恐与涉禁
    case gamblingNarcotics = "gambling_narcotics"       // 赌博与毒品
    case privacyPII = "privacy_pii"                     // 隐私泄露
    case promptInjection = "prompt_injection"           // 注入与越狱
}

/// 合规拦截错误
public enum PromptComplianceError: LocalizedError, Sendable {
    case contentViolatesPolicy(ComplianceCategory)
    case accountTemporarilyThrottled

    public var errorDescription: String? {
        switch self {
        case .contentViolatesPolicy(let category):
            return DynamicComplianceManager.shared.getComplianceMessage(for: category)
        case .accountTemporarilyThrottled:
            return L10n.Security.accountTemporarilyThrottled
        }
    }
}

/// 全局合规检测与三级处置引擎
public final class ContentModerationEngine: Sendable {
    public static let shared = ContentModerationEngine()

    private init() {}

    /// 重度违规分类关键词表 (模拟 AC 自动机词库)
    private let politicalPatterns = [#"(?i)(?:颠覆政权|暴乱|反动宣言|煽动仇恨)"#]
    private let nsfwPatterns = [#"(?i)(?:淫秽色情|露骨色情|涉黄描述)"#]
    private let violencePatterns = [#"(?i)(?:制造炸弹|恐怖袭击|毒品交易)"#]
    private let gamblingNarcoticsPatterns = [#"(?i)(?:制造冰毒|提纯步骤|赌博网站|套利刷流水|冰毒配方|合成冰毒)"#]

    /// 评估用户输入文本并执行合规检查与三级处置
    public func evaluateAndEnforce(_ text: String) throws -> String {
        guard !text.isEmpty else { return text }

        // 0. 全球 9 大语言抗变异洗词预处理（Leetspeak 还原、重音符剥离、繁简归一化、剥离插入隔符）
        let sanitizedText = MultilingualTextSanitizer.shared.sanitizeForModeration(text)

        // 1. 拦截级别 3 重度违规 (政治、黄色、暴恐、赌博毒品)
        let activePolitical = DynamicComplianceManager.shared.getPatterns(for: .politicalReactionary, fallback: politicalPatterns)
        if matchesAny(sanitizedText, rawText: text, patterns: activePolitical) {
            Logger.shared.addLog(action: .error, target: "ContentModerationEngine", details: "Blocked political content", module: "Security")
            throw PromptComplianceError.contentViolatesPolicy(.politicalReactionary)
        }

        let activeNSFW = DynamicComplianceManager.shared.getPatterns(for: .adultNSFW, fallback: nsfwPatterns)
        if matchesAny(sanitizedText, rawText: text, patterns: activeNSFW) {
            Logger.shared.addLog(action: .error, target: "ContentModerationEngine", details: "Blocked NSFW content", module: "Security")
            throw PromptComplianceError.contentViolatesPolicy(.adultNSFW)
        }

        let activeViolence = DynamicComplianceManager.shared.getPatterns(for: .violenceTerrorism, fallback: violencePatterns)
        if matchesAny(sanitizedText, rawText: text, patterns: activeViolence) {
            Logger.shared.addLog(action: .error, target: "ContentModerationEngine", details: "Blocked violence content", module: "Security")
            throw PromptComplianceError.contentViolatesPolicy(.violenceTerrorism)
        }

        let activeGamblingNarcotics = DynamicComplianceManager.shared.getPatterns(for: .gamblingNarcotics, fallback: gamblingNarcoticsPatterns)
        if matchesAny(sanitizedText, rawText: text, patterns: activeGamblingNarcotics) {
            Logger.shared.addLog(action: .error, target: "ContentModerationEngine", details: "Blocked gambling/narcotics content", module: "Security")
            throw PromptComplianceError.contentViolatesPolicy(.gamblingNarcotics)
        }

        // 2. 处理级别 1 (PII 脱敏) 与级别 2 (注入脱敏)
        return PromptSecurityGuard.shared.sanitize(text)
    }

    private func matchesAny(_ sanitizedText: String, rawText: String, patterns: [String]) -> Bool {
        // 提取纯文本敏感词表构造 AC 自动机快速匹配
        let plainKeywords = patterns.map { pat in
            pat.replacingOccurrences(of: #"(?i)(?:\?:|\(|\)|\||\^|\$)"#, with: "", options: .regularExpression)
        }.flatMap { $0.components(separatedBy: "|") }.filter { !$0.isEmpty }

        let acEngine = AhoCorasickEngine(patterns: plainKeywords)
        if acEngine.containsAny(in: sanitizedText) || acEngine.containsAny(in: rawText) {
            return true
        }

        // 正则兜底校验
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range1 = NSRange(location: 0, length: sanitizedText.utf16.count)
                if regex.firstMatch(in: sanitizedText, options: [], range: range1) != nil {
                    return true
                }
                let range2 = NSRange(location: 0, length: rawText.utf16.count)
                if regex.firstMatch(in: rawText, options: [], range: range2) != nil {
                    return true
                }
            }
        }
        return false
    }
}
