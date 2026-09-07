//
//  SearchResultSkeletonRow.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：检索与页面列表加载时的骨架屏单行占位视图，消除重复代码与硬编码尺寸 (DRY)。
//

import SwiftUI
import UFPCore

/// 知识搜索与页面列表检索时的单行骨架屏占位卡片 (DRY)
struct SearchResultSkeletonRow: View {
    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            AppSkeleton(width: DesignSystem.Sidebar.iconBoxSize, height: DesignSystem.Sidebar.iconBoxSize)
            VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                AppSkeleton(width: FeatureConstants.SearchView.skeletonTitleWidth, height: DesignSystem.standardFontSize)
                AppSkeleton(width: FeatureConstants.SearchView.skeletonSubtitleWidth, height: DesignSystem.microFontSize)
            }
            Spacer()
        }
    }
}
