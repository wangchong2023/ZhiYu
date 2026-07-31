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

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        let lines: [LineEntry] = text.components(separatedBy: "\n").enumerated().map { LineEntry(id: $0.offset, text: $0.element) }
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            ForEach(lines) { (entry: LineEntry) in
                let trimmed = entry.text.trimmingCharacters(in: .whitespaces)
                
                // 1. 跳过 Markdown 表格对齐分隔行 (|:---|:---|)
                if isTableSeparator(trimmed) {
                    EmptyView()
                } else if trimmed.hasPrefix("# ") {
                    Text(LocalizedStringKey(trimmed.replacingOccurrences(of: "# ", with: "")))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.appText)
                        .padding(.top, DesignSystem.tiny)
                } else if trimmed.hasPrefix("## ") {
                    Text(LocalizedStringKey(trimmed.replacingOccurrences(of: "## ", with: "")))
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.appAccent)
                        .padding(.top, DesignSystem.tiny)
                } else if trimmed.hasPrefix("> ") {
                    HStack(spacing: DesignSystem.small) {
                        Rectangle()
                            .fill(Color.appAccent)
                            .frame(width: DesignSystem.tiny)
                        Text(LocalizedStringKey(trimmed.replacingOccurrences(of: "> ", with: "")))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(DesignSystem.tightPadding)
                    .background(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
                } else if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                    renderTableRow(trimmed)
                } else if !trimmed.isEmpty {
                    Text(LocalizedStringKey(trimmed))
                        .font(.body)
                        .foregroundStyle(.appText)
                }
            }
        }
    }

    private func isTableSeparator(_ line: String) -> Bool {
        let cleaned = line.replacingOccurrences(of: " ", with: "")
        return cleaned.hasPrefix("|:") || cleaned.hasPrefix("|-") || (cleaned.contains("---") && cleaned.contains("|"))
    }

    @ViewBuilder
    private func renderTableRow(_ line: String) -> some View {
        let rawCols = line.split(separator: "|")
        let columns: [ColumnEntry] = rawCols.enumerated().map { ColumnEntry(id: $0.offset, text: String($0.element).trimmingCharacters(in: .whitespaces)) }
        HStack(spacing: DesignSystem.tightPadding) {
            ForEach(columns) { (col: ColumnEntry) in
                Text(LocalizedStringKey(col.text))
                    .font(.caption.weight(col.id == 0 ? .semibold : .regular))
                    .foregroundStyle(.appText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, DesignSystem.tightPadding)
                    .padding(.vertical, DesignSystem.tightPadding)
                    .background(Color.appCard)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.microRadius))
            }
        }
    }
}
