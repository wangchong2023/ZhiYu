//
//  PageType+Display.swift
//  ZhiYu
//
//  系统层级：[L2] 功能层（表现层适配）
//  核心职责：为 ZhiYuDomain.PageType / PageStatus / Confidence 枚举提供本地化显示名称（L10n 映射）。
//           纯显示适配，无业务逻辑。真相源已移入 Packages/ZhiYuDomain/Sources/ZhiYuDomain/Models/PageType.swift。
//

import Foundation
import ZhiYuDomain

// MARK: - PageType 显示适配（L10n）

extension PageType {
    public var displayName: String {
        switch self {
        case .entity: return L10n.CoreModels.type.entity
        case .concept: return L10n.CoreModels.type.concept
        case .source: return L10n.CoreModels.type.source
        case .comparison: return L10n.CoreModels.type.comparison
        case .raw: return L10n.CoreModels.type.raw
        }
    }
}

// MARK: - PageStatus 显示适配（L10n）

extension PageStatus {
    public var displayName: String {
        switch self {
        case .active: return L10n.CoreModels.Status.active
        case .stub: return L10n.CoreModels.Status.stub
        case .needsUpdate: return L10n.CoreModels.Status.needsUpdate
        case .deprecated: return L10n.CoreModels.Status.deprecated
        }
    }
}

// MARK: - Confidence 显示适配（L10n）

extension Confidence {
    public var displayName: String {
        switch self {
        case .high: return L10n.CoreModels.confidence.high
        case .medium: return L10n.CoreModels.confidence.medium
        case .low: return L10n.CoreModels.confidence.low
        }
    }
}
