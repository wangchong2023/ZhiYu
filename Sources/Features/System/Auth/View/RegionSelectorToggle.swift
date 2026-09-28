//
//  RegionSelectorToggle.swift
//  ZhiYu
//
//  Created by Constantine on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 业务功能层 - 表现视图
//  核心职责：提供高雅的胶囊式国内外登录区域手动选择切换组件，带有触觉选择反馈。
//

import SwiftUI
import UFPDesignSystem

/// 胶囊式登录区域选择切换组件
struct RegionSelectorToggle: View {
    /// 绑定的当前已选择的认证分区
    @Binding var currentRegion: AuthRegion
    /// 发生切换时的动作回调
    var onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(AuthRegion.allCases, id: \.self) { region in
                Text(region == .china ? L10n.Auth.regionChina : L10n.Auth.regionInternational)
                    .font(.caption2.bold())
                    .foregroundStyle(currentRegion == region ? .white : .appSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, DesignTokens.Spacing.medium)
                    .padding(.vertical, DesignTokens.Spacing.tiny)
                    .background(
                        Capsule()
                            .fill(currentRegion == region ? Color.appAccent : Color.clear)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if currentRegion != region {
                            // 触发轻快触觉选择反馈
                            HapticFeedback.shared.trigger(.selection)
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                currentRegion = region
                            }
                            onToggle()
                        }
                    }
            }
        }
        .padding(DesignTokens.Spacing.atomic)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}
