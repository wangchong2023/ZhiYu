//
//  BacklinksView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 Backlinks 界面的 UI 视图层组件。
//
import SwiftUI

struct BacklinksView: View {
    let page: KnowledgePage
    @Environment(AppStore.self) var store
    @Environment(\.dismiss) private var dismiss
    
    @State private var backlinks: [KnowledgePage] = []
    @State private var outgoingPages: [KnowledgePage] = []
    @State private var isLoading = true
    
    private func fetchData() async {
        isLoading = true
        let bl = await store.getBacklinks(for: page.id)
        
        var op: [KnowledgePage] = []
        for title in page.outgoingLinks {
            if let p = await store.pageByTitle(title) {
                op.append(p)
            }
        }
        
        await MainActor.run {
            self.backlinks = bl
            self.outgoingPages = op
            self.isLoading = false
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Outgoing links
                Section {
                    if outgoingPages.isEmpty {
                        Text(L10n.Components.noOutgoing)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                    } else {
                        ForEach(outgoingPages) { linkedPage in
                            linkRow(page: linkedPage, arrowIcon: DesignSystem.Icons.arrowRight, arrowColor: .appAccent)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: DesignSystem.Icons.arrowRight)
                        Text(L10n.Vault.Backlinks.outgoing( outgoingPages.count))
                    }
                }
                
                // Backlinks
                Section {
                    if backlinks.isEmpty {
                        Text(L10n.Components.noBackLinks)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                    } else {
                        ForEach(backlinks) { linkingPage in
                            linkRow(page: linkingPage, arrowIcon: DesignSystem.Icons.arrowLeft, arrowColor: .appComparison)
                        }
                    }
                } header: {
                    HStack {
                        Image(systemName: DesignSystem.Icons.arrowLeft)
                        Text(L10n.Vault.Backlinks.count( backlinks.count))
                    }
                }
            }
            .adaptiveListStyle()
            .scrollContentBackground(.hidden)
            .background(PageBackgroundView(accentColor: .appAccent))
            .navigationTitle(page.title)
.appNavigationBarTitleDisplayMode(.inline)
            .task {
                await fetchData()
            }
        }
    }

    /// 链接行视图：箭头 + 页面图标 + 标题 + 类型
    @ViewBuilder
    private func linkRow(page: KnowledgePage, arrowIcon: String, arrowColor: Color) -> some View {
        HStack(spacing: SystemSpacing.element) {
            Image(systemName: arrowIcon)
                .font(.caption)
                .foregroundStyle(arrowColor)

            InsightPageTypeIcon(page: page, size: DesignSystem.IconSize.medium)

            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                Text(page.title)
                    .font(.subheadline)
                    .foregroundStyle(.appText)
                Text(page.pageType.displayName)
                    .font(.caption2)
                    .foregroundStyle(.appSecondary)
            }
        }
        .padding(.vertical, DesignSystem.tiny)
    }
}
