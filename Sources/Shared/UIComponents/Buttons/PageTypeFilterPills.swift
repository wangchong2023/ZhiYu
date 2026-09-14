//
//  PageTypeFilterPills.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 共享层
//  核心职责：页面类型过滤胶囊列表组件，消除 GraphFilterPillsView / SearchView 中重复的 FilterPill(all) + ForEach(PageType.allVisibleCases) 模式。
//

import SwiftUI

/// 页面类型过滤胶囊列表
///
/// 消除 `GraphFilterPillsView` 与 `SearchView` 中重复的
/// `ScrollView(.horizontal) { HStack { FilterPill(all) + ForEach(PageType.allVisibleCases) { FilterPill(...) } } }` 模式。
/// 可选触发触觉反馈、可选附加 accessibilityIdentifier。
struct PageTypeFilterPills: View {
    @Binding var filterType: PageType?
    var triggersHaptic: Bool = false
    var includesAccessibilityID: Bool = false

    var body: some View {
        HStack(spacing: DesignSystem.small) {
            FilterPill(
                title: L10n.Search.all,
                accessibilityIdentifier: includesAccessibilityID ? FeatureConstants.AccessibilityID.filterAll : nil,
                isSelected: filterType == nil
            ) {
                selectFilter(nil)
            }

            ForEach(PageType.allVisibleCases) { type in
                FilterPill(
                    title: type.displayName,
                    icon: type.icon,
                    color: Color.fromModelColorName(type.colorName),
                    accessibilityIdentifier: includesAccessibilityID ? "filter-\(type.rawValue)" : nil,
                    isSelected: filterType == type
                ) {
                    selectFilter(type)
                }
            }
        }
    }

    private func selectFilter(_ type: PageType?) {
        if triggersHaptic {
            HapticFeedback.shared.trigger(.selection)
        }
        filterType = type
    }
}
