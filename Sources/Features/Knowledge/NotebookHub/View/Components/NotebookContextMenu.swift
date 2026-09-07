//
//  NotebookContextMenu.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/05.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：笔记本卡片与行通用上下文菜单与默认图标生成器 (DRY)。
//

import SwiftUI

/// 笔记本通用上下文菜单组件 (DRY)
struct NotebookContextMenu: View {
    let notebook: Vault
    let viewModel: NotebookHubViewModel

    var body: some View {
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

extension Vault {
    /// 获取根据笔记本 ID 哈希值计算出来的兜底默认 Emoji 图标，收拢至强类型设计令牌
    var defaultDisplayIcon: String {
        let index = abs(id.hashValue) % DesignSystem.Icons.Notebook.options.count
        return DesignSystem.Icons.Notebook.options[index]
    }
}
