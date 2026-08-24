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

struct SourceRow: View {
    let source: KnowledgeSource
    var onSelect: (UUID) -> Void
    
    var body: some View {
        Button(action: { onSelect(source.pageID) }) {
            VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
                HStack {
                    Image(systemName: DesignSystem.Icons.documentFill)
                        .font(.caption)
                        .foregroundStyle(.appAccent)
                    
                    VStack(alignment: .leading, spacing: SystemSpacing.divider) {
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
                        .padding(.horizontal, DesignSystem.tightPadding)
                        .padding(.vertical, DesignSystem.atomic)
                        .background(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                        .clipShape(Capsule())
                }
                
                Text(source.snippet)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(DesignSystem.small)
            .background(Color.appCard.opacity(DesignSystem.softOpacity))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                    .stroke(Color.appBorder.opacity(DesignSystem.Opacity.shadow), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}
