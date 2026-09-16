//
//  LocalModelManagerView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/05.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：本地大模型管理统一入口，集成模型市场、参数调优、服务器配置、智能路由四大核心功能模块。
//

import SwiftUI

/// 本地大模型管理统一入口视图
/// 采用 Tab 切换架构，整合模型市场和参数调优两大核心功能模块
@MainActor
public struct LocalModelManagerView: View {

    // MARK: - 环境注入

    @Environment(AppStore.self) private var store
    @Environment(Router.self) private var router
    @Environment(ThemeManager.self) private var themeManager

    // MARK: - 状态管理

    public init() {}

    public var body: some View {
        ScrollView {
            ScrollViewReader { proxy in
                VStack(spacing: DesignSystem.giant) {
                    // Section 1: 模型市场
                    VStack(alignment: .leading, spacing: 0) {
                        modelSectionHeader(icon: DesignSystem.Icons.stackFill, iconColor: Color.theme.cyan, title: L10n.ModelManager.storeTitle)
                        
                        ModelStoreView(embedInScrollView: false) {
                            withAnimation(.easeInOut) {
                                proxy.scrollTo("lab_section", anchor: .top)
                            }
                        }
                        .environment(store)
                        .environment(router)
                    }
                    .modifier(ModelSectionCardModifier())
                    .id("store_section")
                    
                    // Section 2: 测试实验室
                    VStack(alignment: .leading, spacing: 0) {
                        modelSectionHeader(icon: DesignSystem.Icons.flaskFill, iconColor: Color.theme.purple, title: L10n.ModelManager.laboratoryTitle)
                        
                        ModelLabView(embedInScrollView: false) {
                            withAnimation(.easeInOut) {
                                proxy.scrollTo("store_section", anchor: .top)
                            }
                        }
                        .environment(store)
                        .environment(router)
                    }
                    .modifier(ModelSectionCardModifier())
                    .id("lab_section")
                }
                .padding(.vertical)
            }
        }
    }
}

private struct ModelSectionCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
            .cornerRadius(DesignSystem.mediumRadius)
            .padding(.horizontal)
    }
}

/// 模型区块标题，消除 Store/Lab 区块的 HStack+padding 重复
private func modelSectionHeader(icon: String, iconColor: Color, title: String) -> some View {
    HStack(spacing: DesignSystem.small) {
        Image(systemName: icon)
            .foregroundStyle(iconColor)
            .font(.title3)
        Text(title)
            .font(.title3.bold())
            .foregroundStyle(Color.theme.text)
    }
    .padding(.horizontal, DesignSystem.medium)
    .padding(.top, DesignSystem.medium)
}

// MARK: - 预览

#if DEBUG
#Preview {
    NavigationStack {
        ZStack {
            // 在预览模式下在最外层包裹背景，确保预览效果与真机运行时一致
            ThemeManager().pageBackground()
                .ignoresSafeArea()
            LocalModelManagerView()
        }
        .environment(AppStore())
        .environment(Router())
        .environment(ThemeManager())
    }
}
#endif
