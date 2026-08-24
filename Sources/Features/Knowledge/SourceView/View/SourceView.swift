//
//  SourceView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 Source 界面的 UI 视图层组件。
//
import SwiftUI

struct SourceView: View {
    @State private var sourceStore = SourceStore.shared
    @Environment(Router.self) var router
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            
            if sourceStore.activeSources.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: DesignSystem.medium) {
                        ForEach(sourceStore.activeSources) { source in
                            SourceRow(source: source) { pageID in
                                // 跳转到原文
                                router.navigate(to: .pageDetail(id: pageID))
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(PageBackgroundView(accentColor: .appAccent))
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                Text(L10n.Knowledge.Page.Source.title)
                    .font(.headline)
                    .foregroundStyle(.appText)
                Text(L10n.Knowledge.Page.Source.content)
                    .font(.caption2)
                    .foregroundStyle(.appSecondary)
            }
            Spacer()
            
            Button(action: { sourceStore.clear() }) {
                Image(systemName: DesignSystem.Icons.delete)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
            }
        }
        .padding()
        .background(Color.appCard.opacity(DesignSystem.glassOpacity))
    }
    
    private var emptyState: some View {
        VStack(spacing: DesignSystem.wide) {
            Spacer()
            Image(systemName: DesignSystem.Icons.quoteOpening)
                .font(.largeTitle)
                .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.shadow))
            
            Text(L10n.Knowledge.Page.Source.empty)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, ComponentSpacing.ultra)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
