//
//  PanelCloseButton.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 共享层
//  核心职责：面板关闭按钮组件，消除 VaultInsightsPanel / GraphInfoPanel / 其他 sheet 中重复的 Button { dismiss() } label: { Image(errorCircle).font(.title2).foregroundStyle(.secondary) } 模式。
//

import SwiftUI

/// 面板关闭按钮
///
/// 消除 `VaultInsightsPanel`、`GraphInfoPanel` 等面板中重复的
/// `Button { dismiss() } label: { Image(systemName: errorCircle).font(.title2).foregroundStyle(.secondary) }` 模式。
struct PanelCloseButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: DesignSystem.Icons.errorCircle)
                .font(.title2)
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }
}
