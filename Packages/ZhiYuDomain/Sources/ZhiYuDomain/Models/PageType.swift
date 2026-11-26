//
//  PageType.swift
//  ZhiYuDomain
//
//  系统层级：[L1.5] 领域层（ZhiYuDomain SPM 包）
//  核心职责：定义页面类型枚举（PageType）、状态枚举（PageStatus）和置信度枚举（Confidence），
//           约束知识页面的分类体系。纯 Foundation 模型，无 L10n / UI 依赖。
//

import Foundation

// MARK: - Page Type

/// 知识页面类型枚举
public enum PageType: String, Codable, CaseIterable, Identifiable, Sendable {
    // 调整顺序：使概念 (主题) 排在实体 (词条) 前面，符合知识层级上主题优先的规律
    case concept
    case entity
    case source
    case comparison
    case raw

    public var id: String { rawValue }

    /// 用户可见的页面类型列表（不含内部用的 raw 类型）
    public static var allVisibleCases: [PageType] {
        // 对调排列顺序，使主题 (.concept) 排在词条 (.entity) 之前
        return [.concept, .entity, .source]
    }

    /// 用于 UI 渲染的颜色名称（不含 L10n 显示名，显示名由 App 层 PageType+Display.swift 提供）
    public var colorName: String {
        switch self {
        case .entity: return "entity"
        case .concept: return "concept"
        case .source: return "source"
        case .comparison: return "comparison"
        case .raw: return "gray"
        }
    }
}

// MARK: - Page Status

/// 知识页面状态枚举
public enum PageStatus: String, Codable, CaseIterable, Sendable {
    case active
    case stub
    case needsUpdate = "needs-update"
    case deprecated = "deprecated"

    /// 用于 UI 渲染的颜色名称（不含 L10n 显示名）
    public var colorName: String {
        switch self {
        case .active: return "green"
        case .stub: return "yellow"
        case .needsUpdate: return "orange"
        case .deprecated: return "red"
        }
    }
}

// MARK: - Confidence Level

/// 知识置信度枚举
public enum Confidence: String, Codable, CaseIterable, Sendable {
    case high
    case medium
    case low

    /// 用于 UI 渲染的颜色名称（不含 L10n 显示名）
    public var colorName: String {
        switch self {
        case .high: return "green"
        case .medium: return "yellow"
        case .low: return "red"
        }
    }
}
