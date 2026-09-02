//
//  DetailBodyMarkdownSection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：知识页面详情通用 Markdown 正文渲染组件，复用标题与渲染器消除重复代码 (DRY)。
//

import SwiftUI

/// [L3] 表现层：知识详情页通用 Markdown 正文渲染切片
struct DetailBodyMarkdownSection: View {
    let title: String
    let content: String
    let isPrivate: Bool
    let onLinkTap: (String) -> Void

    init(
        title: String = L10n.Editor.placeholder,
        content: String,
        isPrivate: Bool,
        onLinkTap: @escaping (String) -> Void
    ) {
        self.title = title
        self.content = content
        self.isPrivate = isPrivate
        self.onLinkTap = onLinkTap
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(.appSecondary)

            MarkdownRendererView(
                content: content,
                isPrivate: isPrivate,
                onLinkTap: onLinkTap
            )
        }
    }
}
