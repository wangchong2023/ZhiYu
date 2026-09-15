//
//  SkeletonListRow.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：列表骨架行组件，消除 KnowledgePageListView 与 SearchView 中重复的 HStack(AppSkeleton + VStack(AppSkeleton×2) + Spacer) 链。
//

import SwiftUI

/// 列表骨架行组件
///
/// 消除 `KnowledgePageListView` 与 `SearchView` 中重复的
/// `HStack(spacing: DesignSystem.medium) { AppSkeleton(iconBoxSize); VStack { AppSkeleton(titleWidth); AppSkeleton(subtitleWidth) }; Spacer() }` 模式。
struct SkeletonListRow: View {
    var iconBoxSize: CGFloat
    var titleWidth: CGFloat
    var subtitleWidth: CGFloat
    var titleHeight: CGFloat
    var subtitleHeight: CGFloat
    var spacing: CGFloat

    init(
        iconBoxSize: CGFloat = DesignSystem.Sidebar.iconBoxSize,
        titleWidth: CGFloat = FeatureConstants.SkeletonRow.titleWidth,
        subtitleWidth: CGFloat = FeatureConstants.SkeletonRow.subtitleWidth,
        titleHeight: CGFloat = DesignSystem.standardFontSize,
        subtitleHeight: CGFloat = DesignSystem.microFontSize,
        spacing: CGFloat = DesignSystem.medium
    ) {
        self.iconBoxSize = iconBoxSize
        self.titleWidth = titleWidth
        self.subtitleWidth = subtitleWidth
        self.titleHeight = titleHeight
        self.subtitleHeight = subtitleHeight
        self.spacing = spacing
    }

    var body: some View {
        HStack(spacing: spacing) {
            AppSkeleton(width: iconBoxSize, height: iconBoxSize)
            VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                AppSkeleton(width: titleWidth, height: titleHeight)
                AppSkeleton(width: subtitleWidth, height: subtitleHeight)
            }
            Spacer()
        }
    }
}
