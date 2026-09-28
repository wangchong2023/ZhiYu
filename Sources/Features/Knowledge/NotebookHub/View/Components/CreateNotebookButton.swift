//
//  CreateNotebookButton.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：笔记本中心：入口页面、笔记本卡片、创建表单。
//
import SwiftUI
import UFPDesignSystem

@MainActor
struct CreateNotebookButton: View {
    // MARK: - 状态与环境
    
    @Bindable var viewModel: NotebookHubViewModel
    let displayMode: NotebookHubViewModel.DisplayMode
    
    // MARK: - 视图主体
    
    var body: some View {
        if displayMode == .grid {
            createNotebookCard
        } else {
            createNotebookListRow
        }
    }
    
    // MARK: - 子视图组件
    
    private var createNotebookListRow: some View {
        Button(action: { 
            HapticFeedback.shared.trigger(.selection)
            viewModel.isShowingCreateSheet = true 
        }) {
            HStack(spacing: DesignTokens.Spacing.medium) {
                Image(systemName: DesignTokens.Icons.plusCircle)
                    .font(.system(size: DesignTokens.Typography.titleFontSize))
                    .foregroundStyle(.appAccent)
                
                Text(L10n.Vault.new)
                    .font(.system(size: DesignTokens.Typography.headlineFontSize, weight: .bold))
                    .foregroundStyle(.appText)
                
                Spacer()
            }
            .padding(DesignTokens.Spacing.medium)
            .borderedCardStyle(
                horizontalPadding: DesignTokens.Spacing.medium,
                verticalPadding: DesignTokens.Spacing.medium,
                backgroundOpacity: DesignTokens.Opacity.dim,
                cornerRadius: DesignTokens.Spacing.cardRadius
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius)
                    .strokeBorder(style: StrokeStyle(lineWidth: DesignTokens.Spacing.borderWidth, dash: [4]))
                    .foregroundStyle(.appAccent.opacity(DesignTokens.Colors.Opacity.secondaryOpacity))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var createNotebookCard: some View {
        Button(action: { 
            HapticFeedback.shared.trigger(.selection)
            viewModel.isShowingCreateSheet = true 
        }) {
            VStack(spacing: DesignTokens.Spacing.medium) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(DesignTokens.Opacity.subtle))
                        .frame(width: DesignTokens.Metrics.notebookActionIconSize, height: DesignTokens.Metrics.notebookActionIconSize)
                    
                    Image(systemName: DesignTokens.Icons.plus)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.appAccent)
                }
                
                Text(L10n.Vault.new)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.appText)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignTokens.Metrics.notebookCardHeight)
            .cardStyle(
                horizontalPadding: DesignTokens.Spacing.standardPadding,
                verticalPadding: DesignTokens.Spacing.standardPadding,
                backgroundOpacity: DesignTokens.Colors.subtleFillOpacity,
                cornerRadius: DesignTokens.Spacing.cardRadius
            )
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: DesignTokens.SystemStroke.emphasis, dash: FeatureConstants.DashedBorder.pattern))
                    .foregroundStyle(.appAccent.opacity(DesignTokens.Opacity.medium))
            )
        }
        .buttonStyle(.plain)
    }
}
