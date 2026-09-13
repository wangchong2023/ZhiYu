//
//  NotebookSharedComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：笔记本中心共享组件，消除 NotebookCard 与 NotebookListRow 之间重复的 defaultIcon 与 notebookContextMenu。
//

import SwiftUI

/// 笔记本共享组件扩展，收拢 NotebookCard 与 NotebookListRow 的重复逻辑
extension Vault {
    /// 获取根据笔记本 ID 哈希值计算出来的兜底默认 Emoji 图标，收拢至强类型设计令牌
    var defaultEmojiIcon: String {
        let index = abs(id.hashValue) % DesignSystem.Icons.Notebook.options.count
        return DesignSystem.Icons.Notebook.options[index]
    }
}

/// 笔记本上下文菜单构建器，消除 NotebookCard 与 NotebookListRow 的重复菜单代码
struct NotebookContextMenu: View {
    let notebook: Vault
    let viewModel: NotebookHubViewModel

    var body: some View {
        Group {
            Button {
                viewModel.prepareEdit(notebook)
            } label: {
                Label(L10n.Vault.edit, systemImage: DesignSystem.Icons.edit)
            }
            Button(role: .destructive) {
                viewModel.deleteNotebook(id: notebook.id)
            } label: {
                Label(L10n.Vault.deleteNotebook, systemImage: DesignSystem.Icons.delete)
            }
        }
    }
}

/// 笔记本图标视图，消除 NotebookCard 与 NotebookListRow 的重复 ZStack + Emoji 布局
struct NotebookIconView<S: Shape>: View {
    let emoji: String
    let backgroundShape: S
    let backgroundColor: Color

    var body: some View {
        ZStack {
            backgroundShape
                .fill(backgroundColor)
                .frame(width: DesignSystem.IconSize.xlarge, height: DesignSystem.IconSize.xlarge)

            Text(emoji)
                .font(.title2)
        }
        .accessibilityHidden(true)
    }
}
