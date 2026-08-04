//
//  OnboardingPath.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：引导路径选择 + 里程碑触发系统

import Foundation
import UFPCore
import SwiftUI

// MARK: - 引导路径

public enum OnboardingPath: String, CaseIterable, Sendable {
    case quickStart
    case importData
    case explore

    public var icon: String {
        switch self {
        case .quickStart: return "rocket.fill"
        case .importData: return "tray.and.arrow.down.fill"
        case .explore: return "safari.fill"
        }
    }

    public var color: Color {
        switch self {
        case .quickStart: return .blue
        case .importData: return .green
        case .explore: return .orange
        }
    }
}

// MARK: - 引导里程碑

public enum OnboardingMilestone: String, CaseIterable, Sendable {
    case firstPageCreated
    case firstAIChat
    case firstGraphView
    case firstSynthesis
    case pageCount10
    case pageCount50
    case pageCount100

    // MARK: - KeyStore

    private static let prefix = "onboarding.milestone"
    // 注: 不再使用 @Inject 静态注入,因为 static var 在 Swift 6 严格并发下属于
    // "nonisolated global shared mutable state"。改在每个 @MainActor 方法内
    // 通过 ServiceContainer.shared.resolveOptional 按需解析,与 Localized.swift 保持一致。

    var key: String { "\(Self.prefix).\(rawValue)" }

    @MainActor
    public var hasBeenShown: Bool {
        let store = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
        return store?.bool(forKey: key) ?? false
    }

    @MainActor
    public func markAsShown() {
        let store = ServiceContainer.shared.resolveOptional((any KeyStoreProtocol).self)
        store?.set(true, forKey: key)
    }

    // MARK: - Toast

    public var toastMessage: String {
        switch self {
        case .firstPageCreated: return L10n.Onboarding.Milestone.firstPage
        case .firstAIChat: return L10n.Onboarding.Milestone.firstChat
        case .firstGraphView: return L10n.Onboarding.Milestone.firstGraph
        case .firstSynthesis: return L10n.Onboarding.Milestone.firstSynthesis
        case .pageCount10: return L10n.Onboarding.Milestone.page10
        case .pageCount50: return L10n.Onboarding.Milestone.page50
        case .pageCount100: return L10n.Onboarding.Milestone.page100
        }
    }

    // MARK: - 触发阈值

    public static func checkPageCountMilestone(_ count: Int) -> OnboardingMilestone? {
        switch count {
        case 1: return .firstPageCreated
        case 10: return .pageCount10
        case 50: return .pageCount50
        case 100: return .pageCount100
        default: return nil
        }
    }
}
