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
            HStack(spacing: DesignSystem.medium) {
                Image(systemName: DesignSystem.Icons.plusCircle)
                    .font(.system(size: DesignSystem.titleFontSize))
                    .foregroundStyle(.appAccent)
                
                Text(L10n.Vault.new)
                    .font(.system(size: DesignSystem.headlineFontSize, weight: .bold))
                    .foregroundStyle(.appText)
                
                Spacer()
            }
            .padding(DesignSystem.medium)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                    .strokeBorder(style: StrokeStyle(lineWidth: DesignSystem.borderWidth, dash: [4]))
                    .foregroundStyle(.appAccent.opacity(DesignSystem.secondaryOpacity))
            )
        }
        .buttonStyle(.plain)
    }
    
    private var createNotebookCard: some View {
        Button(action: { 
            HapticFeedback.shared.trigger(.selection)
            viewModel.isShowingCreateSheet = true 
        }) {
            VStack(spacing: DesignSystem.medium) {
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                        .frame(width: DesignSystem.Metrics.notebookActionIconSize, height: DesignSystem.Metrics.notebookActionIconSize)
                    
                    Image(systemName: DesignSystem.Icons.plus)
                        .font(.title.weight(.bold))
                        .foregroundStyle(.appAccent)
                }
                
                Text(L10n.Vault.new)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(.appText)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .frame(height: DesignSystem.Metrics.notebookCardHeight)
            .background(Color.appCard.opacity(DesignSystem.subtleFillOpacity))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cardRadius, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    .foregroundStyle(.appAccent.opacity(DesignSystem.Opacity.medium))
            )
        }
        .buttonStyle(.plain)
    }
}
