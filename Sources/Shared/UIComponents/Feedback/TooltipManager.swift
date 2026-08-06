//
//  TooltipManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

/// 管理引导提示的显示状态，支持首次使用检测。
@MainActor
class TooltipManager: ObservableObject {
    static let shared = TooltipManager()

    @Published var activeTooltip: TooltipType?
    @Published var shownTooltips: Set<String> = []

    private let defaults: UserDefaults
    private let shownKey = "app_shown_tooltips"

    enum TooltipType: String, CaseIterable {
        case createPage = "create_page"
        case appLink = "page_link"
        case graphFilter = "graph_filter"
        case ingest = "ingest"
        case chat = "chat"
        case tag = "tag"

        var titleKey: String {
            switch self {
            case .createPage: return "tooltip.createPage.title"
            case .appLink: return "tooltip.appLink.title"
            case .graphFilter: return "tooltip.graphFilter.title"
            case .ingest: return "tooltip.ingest.title"
            case .chat: return "tooltip.chat.title"
            case .tag: return "tooltip.tag.title"
            }
        }

        var descriptionKey: String {
            switch self {
            case .createPage: return "tooltip.createPage.desc"
            case .appLink: return "tooltip.appLink.desc"
            case .graphFilter: return "tooltip.graphFilter.desc"
            case .ingest: return "tooltip.ingest.desc"
            case .chat: return "tooltip.chat.desc"
            case .tag: return "tooltip.tag.desc"
            }
        }

        var icon: String {
            switch self {
            case .createPage: return "plus.circle.fill"
            case .appLink: return "link"
            case .graphFilter: return "line.3.horizontal.decrease.circle"
            case .ingest: return "tray.and.arrow.down.fill"
            case .chat: return "brain.head.profile"
            case .tag: return "tag.fill"
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        shownTooltips = Set(defaults.stringArray(forKey: shownKey) ?? [])
    }

    /// markShown
    /// - Parameter tooltip: tooltip
    func markShown(_ tooltip: TooltipType) {
        shownTooltips.insert(tooltip.rawValue)
        defaults.set(Array(shownTooltips), forKey: shownKey)
    }

    /// isShown
    /// - Parameter tooltip: tooltip
    /// - Returns: 是否成功
    func isShown(_ tooltip: TooltipType) -> Bool {
        shownTooltips.contains(tooltip.rawValue)
    }

    /// 重置All
    func resetAll() {
        shownTooltips.removeAll()
        defaults.removeObject(forKey: shownKey)
    }

    var pendingTooltips: [TooltipType] {
        TooltipType.allCases.filter { !isShown($0) }
    }
}
