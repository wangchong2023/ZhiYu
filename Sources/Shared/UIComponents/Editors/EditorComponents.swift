//
//  EditorComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

// MARK: - Editor Toolbar Button
/// 编辑器工具栏按钮组件
struct EditorToolbarButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.atomic) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.caption2)
            }
            .foregroundStyle(Color.appSecondary)
            .frame(width: DesignSystem.IconSize.xlarge, height: 36)
            .background(Color.appBorder.opacity(DesignSystem.Opacity.glass))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.microRadius))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(title)
    }
}
