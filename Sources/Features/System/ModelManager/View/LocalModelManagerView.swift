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
                        HStack(spacing: DesignSystem.small) {
                            Image(systemName: "square.stack.3d.up.fill")
                                .foregroundStyle(.cyan)
                                .font(.title3)
                            Text(L10n.ModelManager.storeTitle)
                                .font(.title3.bold())
                                .foregroundStyle(Color.theme.text)
                        }
                        .padding(.horizontal, DesignSystem.medium)
                        .padding(.top, DesignSystem.medium)
                        
                        ModelStoreView(embedInScrollView: false) {
                            withAnimation(.easeInOut) {
                                proxy.scrollTo("lab_section", anchor: .top)
                            }
                        }
                        .environment(store)
                        .environment(router)
                    }
                    .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
                    .cornerRadius(DesignSystem.mediumRadius)
                    .padding(.horizontal)
                    .id("store_section")
                    
                    // Section 2: 测试实验室
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: DesignSystem.small) {
                            Image(systemName: "flask.fill")
                                .foregroundStyle(.purple)
                                .font(.title3)
                            Text(L10n.ModelManager.laboratoryTitle)
                                .font(.title3.bold())
                                .foregroundStyle(Color.theme.text)
                        }
                        .padding(.horizontal, DesignSystem.medium)
                        .padding(.top, DesignSystem.medium)
                        
                        ModelLabView(embedInScrollView: false) {
                            withAnimation(.easeInOut) {
                                proxy.scrollTo("store_section", anchor: .top)
                            }
                        }
                        .environment(store)
                        .environment(router)
                    }
                    .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
                    .cornerRadius(DesignSystem.mediumRadius)
                    .padding(.horizontal)
                    .id("lab_section")
                }
                .padding(.vertical)
            }
        }
    }
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
