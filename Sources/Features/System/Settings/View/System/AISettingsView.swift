//
//  AISettingsView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建统一的 AI 大模型设置面板（AISettingsView），聚合在线模型、本地模型、智能路由和提示词设置。
//

import SwiftUI

/// 统一的 AI 大模型配置面板视图
@MainActor
struct AISettingsView: View {
    @Environment(AppStore.self) var store
    @Environment(ThemeManager.self) var themeManager
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            // 在最外层统一渲染背景，并忽略安全区，确保子视图无需重复制做
            themeManager.pageBackground()
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 使用系统 Picker(.segmented) 保证 hit testing 稳定可靠
                // 引入 SF Symbols 选项卡图标，补充视觉引导
                Picker("", selection: $selectedTab) {
                    ForEach(0..<tabLabels.count, id: \.self) { index in
                        Label(tabLabels[index], systemImage: tabIcons[index])
                            .tag(index)
                    }
                }
                .segmentedPickerStyleIfAvailable()
                .padding(.horizontal)
                .padding(.vertical, Spacing.small)
 
                // 核心状态切换区域，根据 selectedTab 动态渲染对应子模块配置视图
                Group {
                    switch selectedTab {
                    case 0: SmartRoutingView()
                    case 1: LLMSettingsView()
                    case 2: LocalModelManagerView()
                    default: EmptyView()
                    }
                }
                .id(selectedTab)
            }
        }
        .navigationTitle(L10n.Settings.Section.ai)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.Common.done) {
                    dismiss()
                }
                .bold()
            }
        }
    }
    
    /// 获取当前设置界面的选项卡标签文本数组
    private var tabLabels: [String] {
        [L10n.Settings.smartRouting, L10n.Settings.llmSettings, L10n.Settings.localModelManager]
    }

    /// 获取当前设置选项卡的图标数组，与 tabLabels 按索引一一对齐
    private var tabIcons: [String] {
        ["arrow.triangle.merge", "cloud.fill", "cpu.fill"]
    }
}
