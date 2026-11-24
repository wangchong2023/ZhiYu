//
//  LocalModelManagerView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/05.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：本地大模型管理统一入口 — 采用顶层 Segmented 分栏架构，解耦模型库 (Models) 与任务实验室 (Tasks)。
//

import SwiftUI
import UFPDesignSystem

/// 本地大模型管理顶层分栏定义
public enum ModelManagerTab: String, CaseIterable, Identifiable {
    case store
    case lab

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .store: return L10n.ModelManager.tabModels
        case .lab: return L10n.ModelManager.tabTasks
        }
    }

    public var icon: String {
        switch self {
        case .store: return DesignTokens.Icons.stackFill
        case .lab: return DesignTokens.Icons.flaskFill
        }
    }

    public var themeColor: Color {
        switch self {
        case .store: return Color.theme.cyan
        case .lab: return Color.theme.purple
        }
    }
}

/// 本地大模型管理统一入口视图
@MainActor
public struct LocalModelManagerView: View {

    // MARK: - 环境注入

    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(ThemeManager.self) private var themeManager

    // MARK: - 状态管理

    @State private var selectedTab: ModelManagerTab = .store

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 顶层 Segmented 分栏控制器
            topSegmentedControl
                .padding(.horizontal, DesignTokens.Spacing.medium)
                .padding(.top, DesignTokens.SystemSpacing.small)
                .padding(.bottom, DesignTokens.SystemSpacing.tiny)

            // 分栏内容切换（避免使用 TabView page 样式造成与父级 Picker 的底层触摸与手势劫持）
            Group {
                switch selectedTab {
                case .store:
                    ModelStoreView(embedInScrollView: true) {
                        withAnimation(.appStandard) {
                            selectedTab = .lab
                        }
                    }
                    .environment(store)
                    .environment(router)
                case .lab:
                    ModelLabView(embedInScrollView: true) {
                        withAnimation(.appStandard) {
                            selectedTab = .store
                        }
                    }
                    .environment(store)
                    .environment(router)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(themeManager.pageBackground())
    }

    // MARK: - 顶层分栏控制器

    @ViewBuilder
    private var topSegmentedControl: some View {
        HStack(spacing: DesignTokens.SystemSpacing.tiny) {
            ForEach(ModelManagerTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button(action: {
                    withAnimation(.appStandard) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                        Image(systemName: tab.icon)
                            .font(.subheadline)
                        Text(tab.title)
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DesignTokens.SystemSpacing.small)
                    .background(
                        isSelected ?
                            tab.themeColor.opacity(DesignTokens.Opacity.prominent) :
                            Color.clear
                    )
                    .foregroundStyle(isSelected ? Color.theme.white : .secondary)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignTokens.SystemSpacing.atomic)
        .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius)
                .stroke(Color.appBorder.opacity(DesignTokens.Opacity.prominent), lineWidth: DesignTokens.SystemStroke.divider)
        )
    }
}

// MARK: - 预览

#if DEBUG
#Preview {
    NavigationStack {
        ZStack {
            ThemeManager().pageBackground()
            LocalModelManagerView()
        }
    }
}
#endif
