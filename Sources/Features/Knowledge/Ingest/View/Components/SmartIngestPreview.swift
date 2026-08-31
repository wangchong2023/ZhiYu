//
//  IngestViewComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：知识摄入：文档导入、URL 抓取、OCR 扫描、PDF 解析。
//
import SwiftUI

// MARK: - Smart Ingest Preview
/// 智能导入预览卡片组件
/// 负责展示 LLM 预处理后的建议结果（标题、摘要、自动标签等），供用户确认或修正
struct SmartIngestPreview: View {
    let result: SmartIngestResult
    let onConfirm: () -> Void
    let onDiscard: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// iPad 大屏幕下从 12pt 升到 15pt
    private var previewFont: Font {
        horizontalSizeClass == .regular ? .subheadline : .caption
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            AppSectionHeader(
                title: L10n.Ingest.preview,
                icon: DesignSystem.Icons.sparkles,
                iconColor: .appAccent,
                trailing: AnyView(
                    HStack {
                        Button(action: onConfirm) {
                            AppCapsuleButton(title: L10n.Ingest.previewConfirm, icon: DesignSystem.Icons.check, isPrimary: true, color: .appAccent)
                        }
                        .buttonStyle(.plain)
                        Button(action: onDiscard) {
                            AppCapsuleButton(title: L10n.Ingest.previewDiscard, icon: nil, isPrimary: false)
                        }
                        .buttonStyle(.plain)
                    }
                )
            )
            .padding(.horizontal, DesignSystem.tiny)

            VStack(alignment: .leading, spacing: DesignSystem.medium) { // 12
                // Type + Tags chips
                HStack(spacing: DesignSystem.small) { // 8
                    if let type = PageType(rawValue: result.suggestedType) {
                        AppChip(text: type.displayName, color: Color.fromModelColorName(type.colorName))
                    }
                    ForEach(result.suggestedTags.prefix(DesignSystem.Metrics.maxRecentItems), id: \.self) { tag in // 5
                        AppChip(text: FeatureConstants.TagPrefix.hash + tag, color: .appAccent, backgroundOpacity: DesignSystem.glassOpacity) // 0.1
                    }
                }

                if !result.summary.isEmpty {
                    Text(result.summary)
                        .font(previewFont)
                        .foregroundStyle(.appSecondary)
                        .italic()
                }

                // Compiled content preview
                ScrollView {
                    Text(result.compiledContent)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.appText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxHeight: ComponentSpacing.chartHeight) // 220 最近档舍入
                .padding(DesignSystem.small) // 8
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))

                // Related titles
                if !result.relatedTitles.isEmpty {
                    VStack(alignment: .leading, spacing: DesignSystem.atomic) { // 4
                        Text(L10n.Ingest.suggestLinks)
                            .font(previewFont.weight(.medium))
                            .foregroundStyle(.appSecondary)

                        ForEach(result.relatedTitles, id: \.self) { title in
                            HStack(spacing: DesignSystem.atomic) { // 4
                                Image(systemName: DesignSystem.Icons.link)
                                    .font(.caption2)
                                Text("[[\(title)]]")
                                    .font(previewFont)
                            }
                            .foregroundStyle(.appAccent)
                        }
                    }
                }
            }
            .appContainer(padding: true)
        }
    }
}
