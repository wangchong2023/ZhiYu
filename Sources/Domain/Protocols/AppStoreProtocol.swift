//
//  AppStoreProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：Protocols。定义智宇核心状态中心的抽象契约。
//

import Foundation
import UFPCore
import Observation

/// 智宇核心状态中心协议 (L3-Facade 抽象接口)
/// 用于解耦 Features 层对 AppStore 的直接依赖。
@MainActor
protocol AppStoreProtocol: AnyObject, Observable {
    // ── 指标与数据 ──
    var pages: [KnowledgePage] { get }
    var totalPages: Int { get }
    var totalWords: Int { get }
    var isScanning: Bool { get }
    var showCreateSheet: Bool { get set }

    var brokenLinkCount: Int { get }
    var orphanPageCount: Int { get }
    var totalConnectionCount: Int { get }
    var tags: [String] { get }
    var sourceCount: Int { get }
    var entityCount: Int { get }
    var conceptCount: Int { get }
    var lintIssues: [LintIssue] { get }

    // ── UI 状态 ──
    var pendingCoachMark: CoachMarkType? { get set }

    var growthSeries: [KnowledgeGrowthPoint] { get }

    var isPrivacyModeEnabled: Bool { get }
    var showPerfDashboard: Bool { get set }
    
    var llmService: any LLMServiceProtocol { get }
    
    // ── 核心逻辑 ──
    /// 刷新全部知识页面数据
    func refresh() async
    /// 按标题查找知识页面
    func pageByTitle(_ title: String) async -> KnowledgePage?
    /// 删除指定知识页面
    func deletePage(_ page: KnowledgePage) async
    /// 清除全部开发者调试数据
    func clearAllDeveloperData()
    /// 播种默认示例内容
    func seedDefaultContent(vaultName: String?) async

    // ── 建议应用 ──
    /// 应用重构建议
    func applyRefactorSuggestion(_ suggestion: RefactorSuggestion) async
    /// 应用潜在链接建议
    func applyPotentialLink(_ link: PotentialLinkSuggestion) async
}

// MARK: - SwiftUI Support

#if canImport(SwiftUI)
import SwiftUI

extension EnvironmentValues {
    @Entry var appStore: any AppStoreProtocol = ServiceContainer.shared.resolve((any AppStoreProtocol).self)  // inject_exempt: EnvironmentValues 默认值，DI 就绪后访问
}
#endif
