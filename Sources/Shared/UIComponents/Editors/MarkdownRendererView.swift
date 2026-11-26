//
//  MarkdownRendererView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：构建 MarkdownRenderer 界面的 UI 视图层组件。
//
import SwiftUI
import Dependencies
import UFPDesignSystem

// MARK: - Markdown Renderer View
/// Renders structured Markdown blocks using MarkdownProcessor.
/// Parsing logic is extracted to MarkdownProcessor service for reuse.
@MainActor
struct MarkdownRendererView: View {
    @Environment(AppStore.self) var store
    @Dependency(\.taskCenter) private var taskCenter
    let content: String
    let isPrivate: Bool
    let onLinkTap: (String) -> Void
    var isCompact: Bool = false

    @State private var tempUnlocked = false
    let parser = MarkdownProcessor()

    private enum Layout {
        static let minColWidth: CGFloat = DesignTokens.ComponentSpacing.metricChipWidth
        static let maxColWidth: CGFloat = DesignTokens.Metrics.markdownTableMaxColWidth
        static let cellHeight: CGFloat = DesignTokens.Metrics.markdownTableCellHeight
    }

    var body: some View {
        Group {
            if content.isEmpty && taskCenter.tasks.contains(where: { task in
                if case .running = task.status {
                    return task.type == .ai || task.type == .synthesis
                }
                return false
            }) {
                renderSkeleton()
            } else {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                    let blocks = parser.parse(content)
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        renderBlock(block)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .blur(radius: (store.isPrivacyModeEnabled && isPrivate && !tempUnlocked) ? DesignTokens.Spacing.cardRadius : 0)
        .overlay {
            if store.isPrivacyModeEnabled && isPrivate && !tempUnlocked {
                VStack(spacing: DesignTokens.Spacing.medium) {
                    Image(systemName: DesignTokens.Icons.privacyMode)
                        .font(.system(size: DesignTokens.ComponentSpacing.iconCompact))
                    Text(L10n.Common.Security.privacyMasked)
                        .font(DesignTokens.Typography.titleFont)
                    Button(action: {
                        authenticate()
                    }) {
                        Label(L10n.Common.Security.unlockToView, systemImage: DesignTokens.Icons.lockOpen)
                            .padding(.horizontal, DesignTokens.Spacing.standardPadding)
                            .padding(.vertical, DesignTokens.Spacing.tightPadding)
                            .background(Color.appAccent)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
                .foregroundStyle(.appText)
            }
        }
    }

    private func authenticate() {
        Task {
            if await store.securityService.authenticateWithBiometrics() {
                await MainActor.run {
                    withAnimation { tempUnlocked = true }
                    HapticFeedback.shared.trigger(.unlock)
                }
            }
        }
    }

    // MARK: - Block Renderer
    @ViewBuilder
    private func renderBlock(_ block: MarkdownProcessor.BlockType) -> some View {
        switch block {
        case .heading(let text, let level):
            renderHeading(text: text, level: level)
        case .paragraph(let text):
            renderParagraph(text: text)
        case .bulletList(let items, let indent, let startNumber):
            renderBulletList(items: items, indent: indent, startNumber: startNumber)
        case .blockquote(let text):
            renderBlockquote(text: text)
        case .codeBlock(let code, let language):
            renderCodeBlock(code: code, language: language)
        case .table(let headers, let rows):
            renderTable(headers: headers, rows: rows)
        case .horizontalRule:
            renderHorizontalRule()
        case .taskList(let items):
            renderTaskList(items: items)
        case .details(let summary, let content):
            renderDetailsBlock(summary: summary, content: content)
        }
    }

    @ViewBuilder
    private func renderDetailsBlock(summary: String, content: String) -> some View {
        DisclosureGroup {
            MarkdownRendererView(content: content, isPrivate: isPrivate, onLinkTap: onLinkTap, isCompact: true)
                .padding(.top, DesignTokens.Spacing.tiny)
        } label: {
            Text(summary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.appAccent)
        }
        .detailsBlockStyle()
    }

    // MARK: - Render Heading
    private func renderHeading(text: String, level: Int) -> some View {
        let headingLevel = DesignTokens.Typography.HeadingLevel(rawValue: level) ?? .h6
        let isMainTitle = level == 1
        
        return Text(text)
            .font(.system(size: headingLevel.size, design: .rounded).weight(headingLevel.weight))
            .font(.system(size: headingLevel.size + 2, design: .rounded).weight(headingLevel.weight))
            .foregroundStyle(.appText)
            .multilineTextAlignment(isMainTitle ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: isMainTitle ? .center : .leading)
            .padding(.top, isMainTitle ? DesignTokens.Spacing.widePadding : headingLevel.topPadding)
            .padding(.bottom, isMainTitle ? DesignTokens.Spacing.standardPadding : DesignTokens.Spacing.tiny)
    }

    @ViewBuilder
    private func renderParagraph(text: String) -> some View {
        renderInlineContent(text)
            .font(isCompact ? DesignTokens.Typography.secondaryFont : .system(.body, design: .serif))
            .lineSpacing(isCompact ? DesignTokens.SystemSpacing.tiny : DesignTokens.SystemSpacing.small)
            .foregroundStyle(.appText.opacity(DesignTokens.SystemOpacity.active - DesignTokens.SystemOpacity.glass))
    }

    // MARK: - Render Bullet List
    @ViewBuilder
    private func renderBulletList(items: [String], indent: Int, startNumber: Int = 1) -> some View {
        let isOrdered = indent == -1
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: DesignTokens.Spacing.tightPadding) {
                    if isOrdered {
                        Text("\(startNumber + index).")
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .foregroundStyle(.appAccent)
                            .frame(width: DesignTokens.IconSize.standard, alignment: .trailing)
                    } else {
                        Text("")
                            .foregroundStyle(.appAccent)
                            .frame(width: DesignTokens.Spacing.iconSmall)
                    }
                    
                    renderInlineContent(item)
                        .foregroundStyle(.appText)
                    Spacer(minLength: 0)
                }
                .padding(.leading, isOrdered ? 0 : CGFloat(indent) * DesignTokens.Spacing.standardPadding)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.atomic)
    }

    // MARK: - Render Blockquote
    @ViewBuilder
    private func renderBlockquote(text: String) -> some View {
        let isAISummary = text.contains("AI") || text.hasPrefix("> AI")
        
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: DesignTokens.Spacing.tiny)
                .fill(isAISummary ? Color.appAccent : Color.appAccent.opacity(DesignTokens.SystemOpacity.disabled))
                .frame(width: DesignTokens.Spacing.atomic + DesignTokens.SystemStroke.border)
                .padding(.trailing, DesignTokens.Spacing.mediumRadius)

            renderInlineContent(text)
                .font(isAISummary ? .system(.body, design: .serif).italic() : .body.italic())
                .foregroundStyle(isAISummary ? .appAccent : .appSecondary)
                .lineSpacing(isAISummary ? DesignTokens.Spacing.small : DesignTokens.SystemSpacing.small) // AI 总结采用更宽松的行间距提升阅读舒适度

            Spacer(minLength: 0)
        }
        .padding(isAISummary ? DesignTokens.Spacing.medium : 0)
        .background(isAISummary ? Color.appAccent.opacity(DesignTokens.SystemOpacity.ghost) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: isAISummary ? DesignTokens.Spacing.smallRadius : 0))
        .padding(.vertical, DesignTokens.Spacing.tiny)
    }

    // MARK: - Render Code Block
    @ViewBuilder
    private func renderCodeBlock(code: String, language: String) -> some View {
        if language.lowercased() == "mermaid" {
            MermaidWebView(mermaidCode: code)
                .padding(.vertical, DesignTokens.Spacing.tightPadding)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if !language.isEmpty {
                    Text(language)
                        .font(.system(.caption2, design: .monospaced).weight(.medium))
                        .foregroundStyle(.appSecondary)
                        .padding(.horizontal, DesignTokens.Spacing.medium)
                        .padding(.top, DesignTokens.Spacing.tightPadding)
                }

                ScrollView(.horizontal, showsIndicators: true) {
                    Group {
                        if language.isEmpty || language == "text" || language == "wiki" {
                            renderInlineContent(code)
                        } else {
                            Text(code)
                        }
                    }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.appText.opacity(DesignTokens.SystemOpacity.active - DesignTokens.SystemOpacity.glass))
                    .padding(DesignTokens.Spacing.medium)
                }
            }
            .background(Color.appCard.opacity(DesignTokens.SystemOpacity.textSecondary))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius)
                    .stroke(Color.appBorder.opacity(DesignTokens.SystemOpacity.disabled), lineWidth: DesignTokens.SystemStroke.border)
            )
            .padding(.vertical, DesignTokens.Spacing.tiny)
        }
    }

    /// 渲染表格，使用 Grid 实现列宽自动同步
    @ViewBuilder
    private func renderTable(headers: [String], rows: [[String]]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            Grid(alignment: .topLeading, horizontalSpacing: 0, verticalSpacing: 0) {
                // 表头行
                GridRow {
                    ForEach(Array(headers.enumerated()), id: \.offset) { index, cell in
                        Group {
                            renderInlineContent(cell)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.appAccent)
                                .tableCellFrame(minColWidth: Layout.minColWidth, maxColWidth: Layout.maxColWidth)
                        }
                        .background(Color.appAccent.opacity(DesignTokens.Opacity.subtle))
                        // 列间分割线（最后一列不加）
                        if index < headers.count - 1 {
                            tableDivider(opacity: DesignTokens.Opacity.shadow)
                        }
                    }
                }
                Divider().background(Color.appBorder.opacity(DesignTokens.Opacity.disabled))
                // 数据行
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                            Group {
                                renderInlineContent(cell)
                                    .font(.footnote)
                                    .foregroundStyle(.appText)
                                    .tableCellFrame(minColWidth: Layout.minColWidth, maxColWidth: Layout.maxColWidth)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .background(rowIndex % 2 != 0 ? Color.appCard.opacity(DesignTokens.Opacity.shadow) : Color.clear)
                            if colIndex < row.count - 1 {
                                tableDivider(opacity: DesignTokens.Opacity.shadow)
                            }
                        }
                    }
                    if rowIndex < rows.count - 1 {
                        tableDivider(opacity: DesignTokens.Opacity.shadow)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius)
                    .stroke(Color.appBorder.opacity(DesignTokens.Opacity.shadow), lineWidth: 0.5)
            )
        }
        .padding(.vertical, DesignTokens.Spacing.tiny)
    }

    /// 表格分割线（消除重复的 Divider + background 链）
    @ViewBuilder
    private func tableDivider(opacity: Double) -> some View {
        Divider()
            .frame(maxHeight: Layout.cellHeight)
            .background(Color.appBorder.opacity(opacity))
    }

    // MARK: - Render Horizontal Rule
    @ViewBuilder
    private func renderHorizontalRule() -> some View {
        Divider()
            .background(Color.appBorder)
            .padding(.vertical, DesignTokens.Spacing.tightPadding)
    }

    // MARK: - Render Task List
    @ViewBuilder
    private func renderTaskList(items: [(text: String, checked: Bool)]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.small) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: DesignTokens.Spacing.tightPadding) {
                    Image(systemName: item.checked ? DesignTokens.Icons.checkSquareFill : DesignTokens.Icons.emptySquare)
                        .font(.body)
                        .foregroundStyle(item.checked ? .green : .appSecondary)
                    renderInlineContent(item.text)
                        .foregroundStyle(item.checked ? .appSecondary : .appText)
                        .strikethrough(item.checked)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, DesignTokens.Spacing.atomic)
    }
}

// MARK: - Details Block 共享样式
private extension View {
    /// 折叠块统一样式：padding + accent 背景 + cardRadius 圆角 + 垂直间距，消除 watchOS / iOS 两处重复。
    func detailsBlockStyle() -> some View {
        self
            .padding(DesignTokens.Spacing.medium)
            .background(Color.appAccent.opacity(DesignTokens.SystemOpacity.ghost))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius))
            .padding(.vertical, DesignTokens.Spacing.tiny)
    }

    /// 表格单元格统一 frame + padding，消除表头与数据行两处重复。
    func tableCellFrame(minColWidth: CGFloat, maxColWidth: CGFloat) -> some View {
        self
            .padding(.horizontal, DesignTokens.Spacing.small)
            .padding(.vertical, DesignTokens.Spacing.tightPadding)
            .frame(minWidth: minColWidth, maxWidth: maxColWidth, alignment: .leading)
    }
}
