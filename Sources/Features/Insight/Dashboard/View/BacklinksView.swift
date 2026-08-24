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
                            HStack(spacing: SystemSpacing.element) {
                                Image(systemName: DesignSystem.Icons.arrowRight)
                                    .font(.caption)
                                    .foregroundStyle(.appAccent)
                                
                                Image(systemName: linkedPage.displayIcon)
                                    .foregroundStyle(Color.fromModelColorName(linkedPage.pageType.colorName))
                                    .frame(width: DesignSystem.IconSize.medium, height: DesignSystem.IconSize.medium)
                                    .background(Color.fromModelColorName(linkedPage.pageType.colorName).opacity(DesignSystem.Opacity.glass))
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.microRadius))
                                
                                VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                                    Text(linkedPage.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.appText)
                                    Text(linkedPage.pageType.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(.appSecondary)
                                }
                            }
                            .padding(.vertical, DesignSystem.tiny)
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
                            HStack(spacing: SystemSpacing.element) {
                                Image(systemName: DesignSystem.Icons.arrowLeft)
                                    .font(.caption)
                                    .foregroundStyle(.appComparison)
                                
                                Image(systemName: linkingPage.displayIcon)
                                    .foregroundStyle(Color.fromModelColorName(linkingPage.pageType.colorName))
                                    .frame(width: DesignSystem.IconSize.medium, height: DesignSystem.IconSize.medium)
                                    .background(Color.fromModelColorName(linkingPage.pageType.colorName).opacity(DesignSystem.Opacity.glass))
                                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.microRadius))
                                
                                VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                                    Text(linkingPage.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.appText)
                                    Text(linkingPage.pageType.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(.appSecondary)
                                }
                            }
                            .padding(.vertical, DesignSystem.tiny)
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
}
