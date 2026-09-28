//
//  GraphEmptyStateView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 GraphEmptyState 界面的 UI 视图层组件。
//
import SwiftUI
import UFPDesignSystem

/// 知识图谱空状态占位视图
@MainActor
struct GraphEmptyStateView: View {
    @Binding var selectedTab: AppTab
    
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.loosePadding) {
            Image(systemName: DesignTokens.Icons.circleGrid3x3Fill)
                .font(.system(size: DesignSystem.Graph.emptyIconSize))
                .foregroundStyle(.appAccent.gradient)
            
            VStack(spacing: DesignTokens.Spacing.tightPadding) {
                Text(L10n.Graph.emptyTitle).font(.title2.bold())
                Text(L10n.Graph.emptyDesc)
                    .font(.subheadline)
                    .foregroundStyle(.appSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DesignTokens.Spacing.huge)
            }
            
            Button(action: { selectedTab = .ingest }) {
                Text(L10n.Graph.startBuilding)
                    .font(.headline)
                    .padding(.horizontal, DesignTokens.ComponentSpacing.huge)
                    .padding(.vertical, DesignTokens.SystemSpacing.contentMedium)
                    .background(Capsule().fill(Color.appAccent))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
    }
}
