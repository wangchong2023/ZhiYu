//
//  DynamicComplianceManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：支持合规告示文案的多语言强类型管理与云端/本地 RemoteConfig 动态覆盖与更新。
//
import Foundation
import os

/// 动态合规告示与敏感词库管理中心
public final class DynamicComplianceManager: @unchecked Sendable {
    public static let shared = DynamicComplianceManager()

    private let lock = OSAllocatedUnfairLock()
    private var remoteTextOverrides: [String: [String: String]] = [:]
    private var remotePatternOverrides: [ComplianceCategory: [String]] = [:]

    private init() {}

    /// 注册来自 RemoteConfig 或云端配置的动态覆盖文案与正则词库
    /// - Parameters:
    ///   - textOverrides: [LanguageCode: [Key: CustomMessage]]
    ///   - patternOverrides: [Category: [CustomRegexPatterns]]
    public func updateRemoteComplianceConfig(
        textOverrides: [String: [String: String]] = [:],
        patternOverrides: [ComplianceCategory: [String]] = [:]
    ) {
        lock.withLock {
            if !textOverrides.isEmpty {
                self.remoteTextOverrides = textOverrides
            }
            if !patternOverrides.isEmpty {
                self.remotePatternOverrides = patternOverrides
            }
        }
        Logger.shared.info("[DynamicComplianceManager] 动态合规文案与正则表达式已更新")
    }

    /// 获取自适应当前语言的合规拒绝告知文案 (优先支持 RemoteConfig 动态覆盖，离线回退至 L10n)
    /// - Parameter category: 违规分类
    /// - Returns: 本地化/动态更新后的合规告示
    public func getComplianceMessage(for category: ComplianceCategory) -> String {
        let custom = lock.withLock { () -> String? in
            let lang = Locale.preferredLanguages.first?.lowercased() ?? "en"
            let langKey = lang.hasPrefix(CoreConstants.LanguageCode.zh) ? "zh-Hans" : "en"
            if let langDict = remoteTextOverrides[langKey], let customMsg = langDict[category.rawValue], !customMsg.isEmpty {
                return customMsg
            }
            return nil
        }
        // 回退至强类型 String Catalog (.xcstrings) 多语言
        return custom ?? L10n.Security.compliancePolicyViolation
    }

    /// 获取动态生效的重度违规正则表达式
    /// - Parameter category: 违规分类
    /// - Returns: 合并了云端动态覆盖与本地离线预设的正则表达式列表
    public func getPatterns(for category: ComplianceCategory, fallback: [String]) -> [String] {
        let custom = lock.withLock { () -> [String]? in
            if let customPatterns = remotePatternOverrides[category], !customPatterns.isEmpty {
                return customPatterns
            }
            return nil
        }
        return custom ?? fallback
    }
}
