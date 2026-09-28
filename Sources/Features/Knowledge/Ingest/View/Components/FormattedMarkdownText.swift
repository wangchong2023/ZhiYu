//
//  FormattedMarkdownText.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：提供高精度的 Markdown 格式化解析与表格、引用块及标题的转义渲染组件。
//

import SwiftUI
import UFPCore
import UFPDesignSystem

/// 格式化 Markdown 行模型
private struct LineEntry: Identifiable {
    let id: Int
    let text: String
}

/// 格式化 Markdown 表格列模型
private struct ColumnEntry: Identifiable {
    let id: Int
    let text: String
}

/// Markdown 格式化排版渲染组件
public struct FormattedMarkdownText: View {
    public let text: String
    public var onWikiLinkTap: ((String) -> Void)?
    public var onCitationTap: ((String) -> Void)?
    public var onSectionPolish: ((String) -> Void)?
    public var onSectionRegenerate: ((String) -> Void)?

    public init(
        text: String,
        onWikiLinkTap: ((String) -> Void)? = nil,
        onCitationTap: ((String) -> Void)? = nil,
        onSectionPolish: ((String) -> Void)? = nil,
        onSectionRegenerate: ((String) -> Void)? = nil
    ) {
        self.text = text
        self.onWikiLinkTap = onWikiLinkTap
        self.onCitationTap = onCitationTap
        self.onSectionPolish = onSectionPolish
        self.onSectionRegenerate = onSectionRegenerate
    }

    public var body: some View {
        let lines: [LineEntry] = text.components(separatedBy: "\n").enumerated().map { LineEntry(id: $0.offset, text: $0.element) }
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            ForEach(lines) { (entry: LineEntry) in
                let trimmed = entry.text.trimmingCharacters(in: .whitespaces)
                
                // 1. 跳过 Markdown 表格对齐分隔行 (|:---|:---|)
                if isTableSeparator(trimmed) {
                    EmptyView()
                } else if trimmed.hasPrefix(SystemConstants.MarkdownSyntax.h1Prefix) {
                    Text(LocalizedStringKey(trimmed.replacingOccurrences(of: SystemConstants.MarkdownSyntax.h1Prefix, with: "")))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.appText)
                        .padding(.top, DesignTokens.Spacing.tiny)
                } else if trimmed.hasPrefix(SystemConstants.MarkdownSyntax.h2Prefix) {
                    let sectionTitle = trimmed.replacingOccurrences(of: SystemConstants.MarkdownSyntax.h2Prefix, with: "")
                    HStack {
                        Text(LocalizedStringKey(sectionTitle))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.appAccent)

                        Spacer()

                        if onSectionPolish != nil || onSectionRegenerate != nil {
                            HStack(spacing: DesignTokens.Spacing.tiny) {
                                if let onSectionPolish {
                                    Button {
                                        onSectionPolish(sectionTitle)
                                    } label: {
                                        Label(L10n.AI.Synthesis.Actions.polish, systemImage: DesignTokens.Icons.sparkles)
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(.appAccent)
                                }

                                if let onSectionRegenerate {
                                    Button {
                                        onSectionRegenerate(sectionTitle)
                                    } label: {
                                        Label(L10n.AI.Synthesis.Actions.regenerate, systemImage: DesignTokens.Icons.arrowClockwise)
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(Color.theme.orange)
                                }
                            }
                        }
                    }
                    .padding(.top, DesignTokens.Spacing.tiny)
                } else if trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.blockquotePrefix) {
                    HStack(spacing: DesignTokens.Spacing.small) {
                        Rectangle()
                            .fill(Color.appAccent)
                            .frame(width: DesignTokens.Spacing.tiny)
                        Text(LocalizedStringKey(trimmed.replacingOccurrences(of: ProcessorConstants.MarkdownSyntax.blockquotePrefix, with: "")))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(DesignTokens.Spacing.tightPadding)
                    .background(Color.appAccent.opacity(DesignTokens.Opacity.subtle))
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius))
                } else if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                    renderTableRow(trimmed)
                } else if !trimmed.isEmpty {
                    renderRichLine(trimmed)
                }
            }
        }
    }

    @ViewBuilder
    private func renderRichLine(_ line: String) -> some View {
        let wikiMatches = WikiLinkExtractor.extractLinks(from: line)
        if !wikiMatches.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                Text(LocalizedStringKey(line))
                    .font(.body)
                    .foregroundStyle(.appText)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignTokens.Spacing.tiny) {
                        ForEach(wikiMatches, id: \WikiLinkMatch.rawMatch) { (match: WikiLinkMatch) in
                            Button {
                                onWikiLinkTap?(match.targetTitle)
                            } label: {
                                HStack(spacing: DesignTokens.SystemSpacing.atomic) {
                                    Image(systemName: DesignTokens.Icons.link)
                                        .font(.caption2)
                                    Text("[[\(match.displayTitle)]]")
                                        .font(.caption.weight(.medium))
                                }
                                .padding(.horizontal, DesignTokens.Spacing.tightPadding)
                                .padding(.vertical, DesignTokens.Spacing.tiny)
                                .background(Color.appAccent.opacity(DesignTokens.Colors.Opacity.glassOpacity))
                                .foregroundStyle(Color.appAccent)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        } else {
            Text(LocalizedStringKey(line))
                .font(.body)
                .foregroundStyle(.appText)
        }
    }

    private func isTableSeparator(_ line: String) -> Bool {
        let cleaned = line.replacingOccurrences(of: " ", with: "")
        return cleaned.hasPrefix(SystemConstants.MarkdownSyntax.tableSeparatorColon) || cleaned.hasPrefix(SystemConstants.MarkdownSyntax.tableSeparatorDash) || (cleaned.contains(SystemConstants.MarkdownDelimiter.horizontalRule) && cleaned.contains(SystemConstants.Character.pipe))
    }

    @ViewBuilder
    private func renderTableRow(_ line: String) -> some View {
        let rawCols = line.split(separator: "|")
        let columns: [ColumnEntry] = rawCols.enumerated().map { ColumnEntry(id: $0.offset, text: String($0.element).trimmingCharacters(in: .whitespaces)) }
        HStack(spacing: DesignTokens.Spacing.tightPadding) {
            ForEach(columns) { (col: ColumnEntry) in
                Text(LocalizedStringKey(col.text))
                    .font(.caption.weight(col.id == 0 ? .semibold : .regular))
                    .foregroundStyle(.appText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignTokens.Spacing.tightPadding)
                    .padding(.vertical, DesignTokens.Spacing.tightPadding)
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.microRadius))
            }
        }
    }
}
