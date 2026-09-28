//
//  SourceRow.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：Features/Knowledge/SourceView/View/Components 模块的 SourceRow 实现。
//
import SwiftUI
import UFPDesignSystem

struct SourceRow: View {
    let source: KnowledgeSource
    var onSelect: (UUID) -> Void
    
    var body: some View {
        Button(action: { onSelect(source.pageID) }) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.tightPadding) {
                HStack {
                    Image(systemName: DesignTokens.Icons.documentFill)
                        .font(.caption)
                        .foregroundStyle(.appAccent)
                    
                    VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.divider) {
                        Text(source.title)
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.appText)
                            .lineLimit(1)
                        
                        if let path = source.anchorPath, !path.isEmpty {
                            Text(path)
                                .font(.caption2)
                                .foregroundStyle(.appSecondary)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(Int(source.score * 100))%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.appSecondary)
                        .accentSubtleCapsule(
                            horizontalPadding: DesignTokens.Spacing.tightPadding,
                            verticalPadding: DesignTokens.Spacing.atomic
                        )
                }
                
                Text(source.snippet)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(DesignTokens.Spacing.small)
            .background(Color.appCard.opacity(DesignTokens.Colors.Opacity.softOpacity))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius)
                    .stroke(Color.appBorder.opacity(DesignTokens.Opacity.shadow), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
