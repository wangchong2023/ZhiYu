//
//  Vault.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：多笔记本管理：创建、切换、主题、iCloud 同步。
//
import Foundation
import UFPCore

/// 内置演示笔记本的英文标识常量
public enum BuiltinVaultEnglishName {
    /// 个人知识管理笔记本
    public static let personalKM = "Personal_KM"
    /// 项目调研笔记本
    public static let projectResearch = "Project_Research"
}

/// 笔记本/库基础协议
public protocol VaultProtocol: Sendable {
    var id: UUID { get }
    var name: String { get }
    var icon: String? { get }
    var pageCount: Int { get }
    var updatedAt: Date { get }
}

/// 笔记本/库数据模型
public struct Vault: Identifiable, Codable, Hashable, VaultProtocol {
    public let id: UUID
    public var name: String
    public var createdAt: Date
    public var updatedAt: Date
    public var pageCount: Int
    public var themePayload: String?
    public var icon: String?
    public var description: String?
    
    /// 笔记本对应的英文/安全目录名称
    public var englishName: String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. 内置演示笔记本全语言（简体、繁体、英文）映射，保证跨语言环境下的目录与唯一 ID 识别稳定性
        let defaultNames: Set<String> = [
            BuiltinVaultEnglishName.personalKM,
            L10n.Vault.defaultName,
            L10n.Vault.defaultNameZh,
            L10n.Vault.defaultNameEn
        ]
        let researchNames: Set<String> = [
            BuiltinVaultEnglishName.projectResearch,
            L10n.Vault.researchName,
            L10n.Vault.researchNameZh,
            L10n.Vault.researchNameEn,
            L10n.InitialNotebook.Log.projectResearch
        ]
        
        if defaultNames.contains(trimmedName) {
            return BuiltinVaultEnglishName.personalKM
        }
        if researchNames.contains(trimmedName) {
            return BuiltinVaultEnglishName.projectResearch
        }
        
        // 2. 自定义笔记本拼音转译与字符清洗
        let latin = trimmedName.applyingTransform(.toLatin, reverse: false)
        let strip = latin?.applyingTransform(.stripDiacritics, reverse: false) ?? trimmedName
        
        // 将所有非安全字符（非字母、非数字、非下划线）替换为下划线，支持多空格/连接符归并
        let spaced = strip.replacingOccurrences(of: FeatureConstants.RegexEscape.whitespaceOrDash, with: SystemConstants.Character.underscore, options: .regularExpression)
        let pattern = "[^a-zA-Z0-9_]"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: spaced.utf16.count)
            let cleaned = regex.stringByReplacingMatches(in: spaced, options: [], range: range, withTemplate: "")
            let cleanResult = cleaned.replacingOccurrences(of: FeatureConstants.RegexEscape.underscorePlus, with: SystemConstants.Character.underscore, options: .regularExpression)
            let trimmedResult = cleanResult.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            return trimmedResult.isEmpty ? "Vault_\(id.uuidString.prefix(AppConstants.Keys.ImportLimits.uuidPrefixLength))" : trimmedResult
        }
        return "Vault_\(id.uuidString.prefix(AppConstants.Keys.ImportLimits.uuidPrefixLength))"
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        pageCount: Int = 0,
        themePayload: String? = nil,
        icon: String? = nil,
        description: String? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pageCount = pageCount
        self.themePayload = themePayload
        self.icon = icon
        self.description = description
    }
}
