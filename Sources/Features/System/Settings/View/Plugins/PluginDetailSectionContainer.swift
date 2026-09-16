//
//  PluginDetailSectionContainer.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：插件详情页 Section 容器统一组件，消除 metadataSection/permissionsSection/descriptionSection
//  及 LocalPluginDetailView 中重复的 VStack+Text(.headline) 标题头模式。
//

import SwiftUI

/// 插件详情页 Section 容器：统一标题头 + 内容区的 VStack 布局
struct PluginDetailSectionContainer<Content: View>: View {
    let title: String
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content

    init(title: String, spacing: CGFloat = DesignSystem.medium, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.appText)
            content()
        }
    }
}
