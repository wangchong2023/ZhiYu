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
    private let parser = MarkdownProcessor()

    private enum Layout {
        static let minColWidth: CGFloat = 80
        static let maxColWidth: CGFloat = 180
        static let cellHeight: CGFloat = 36
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
                VStack(alignment: .leading, spacing: DesignSystem.medium) {
                    let blocks = parser.parse(content)
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        renderBlock(block)
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .blur(radius: (store.isPrivacyModeEnabled && isPrivate && !tempUnlocked) ? DesignSystem.cardRadius : 0)
        .overlay {
            if store.isPrivacyModeEnabled && isPrivate && !tempUnlocked {
                VStack(spacing: DesignSystem.medium) {
                    Image(systemName: DesignSystem.Icons.privacyMode)
                        .font(.system(size: ComponentSpacing.iconCompact))
                    Text(L10n.Common.Security.privacyMasked)
                        .font(DesignSystem.titleFont)
                    Button(action: {
                        authenticate()
                    }) {
                        Label(L10n.Common.Security.unlockToView, systemImage: DesignSystem.Icons.lockOpen)
                            .padding(.horizontal, DesignSystem.standardPadding)
                            .padding(.vertical, DesignSystem.tightPadding)
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
        #if os(watchOS)
        VStack(alignment: .leading, spacing: DesignSystem.tiny) {
            Text(summary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.appAccent)
            MarkdownRendererView(content: content, isPrivate: isPrivate, onLinkTap: onLinkTap, isCompact: true)
                .padding(.top, DesignSystem.tiny)
        }
        .padding(DesignSystem.medium)
        .background(Color.appAccent.opacity(SystemOpacity.ghost))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
        .padding(.vertical, DesignSystem.tiny)
        #else
        DisclosureGroup {
            MarkdownRendererView(content: content, isPrivate: isPrivate, onLinkTap: onLinkTap, isCompact: true)
                .padding(.top, DesignSystem.tiny)
        } label: {
            Text(summary)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.appAccent)
        }
        .padding(DesignSystem.medium)
        .background(Color.appAccent.opacity(SystemOpacity.ghost))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
        .padding(.vertical, DesignSystem.tiny)
        #endif
    }

    // MARK: - Render Heading
    private func renderHeading(text: String, level: Int) -> some View {
        let headingLevel = DesignSystem.HeadingLevel(rawValue: level) ?? .h6
        let isMainTitle = level == 1
        
        return Text(text)
            .font(.system(size: headingLevel.size, design: .rounded).weight(headingLevel.weight))
            .font(.system(size: headingLevel.size + 2, design: .rounded).weight(headingLevel.weight))
            .foregroundStyle(.appText)
            .multilineTextAlignment(isMainTitle ? .center : .leading)
            .frame(maxWidth: .infinity, alignment: isMainTitle ? .center : .leading)
            .padding(.top, isMainTitle ? DesignSystem.widePadding : headingLevel.topPadding)
            .padding(.bottom, isMainTitle ? DesignSystem.standardPadding : DesignSystem.tiny)
    }

    @ViewBuilder
    private func renderParagraph(text: String) -> some View {
        renderInlineContent(text)
            .font(isCompact ? DesignSystem.secondaryFont : .system(.body, design: .serif))
            .lineSpacing(isCompact ? SystemSpacing.tiny : SystemSpacing.small)
            .foregroundStyle(.appText.opacity(SystemOpacity.active - SystemOpacity.glass))
    }

    // MARK: - Render Bullet List
    @ViewBuilder
    private func renderBulletList(items: [String], indent: Int, startNumber: Int = 1) -> some View {
        let isOrdered = indent == -1
        VStack(alignment: .leading, spacing: DesignSystem.tiny) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .top, spacing: DesignSystem.tightPadding) {
                    if isOrdered {
                        Text("\(startNumber + index).")
                            .font(.system(.body, design: .rounded).weight(.bold))
                            .foregroundStyle(.appAccent)
                            .frame(width: DesignSystem.IconSize.standard, alignment: .trailing)
                    } else {
                        Text("")
                            .foregroundStyle(.appAccent)
                            .frame(width: DesignSystem.iconSmall)
                    }
                    
                    renderInlineContent(item)
                        .foregroundStyle(.appText)
                    Spacer(minLength: 0)
                }
                .padding(.leading, isOrdered ? 0 : CGFloat(indent) * DesignSystem.standardPadding)
            }
        }
        .padding(.vertical, DesignSystem.atomic)
    }

    // MARK: - Render Blockquote
    @ViewBuilder
    private func renderBlockquote(text: String) -> some View {
        let isAISummary = text.contains("AI") || text.hasPrefix("> AI")
        
        HStack(spacing: 0) {
            RoundedRectangle(cornerRadius: DesignSystem.tiny)
                .fill(isAISummary ? Color.appAccent : Color.appAccent.opacity(SystemOpacity.disabled))
                .frame(width: DesignSystem.atomic + SystemStroke.border)
                .padding(.trailing, DesignSystem.mediumRadius)

            renderInlineContent(text)
                .font(isAISummary ? .system(.body, design: .serif).italic() : .body.italic())
                .foregroundStyle(isAISummary ? .appAccent : .appSecondary)
                .lineSpacing(isAISummary ? DesignSystem.small : SystemSpacing.small) // AI 总结采用更宽松的行间距提升阅读舒适度

            Spacer(minLength: 0)
        }
        .padding(isAISummary ? DesignSystem.medium : 0)
        .background(isAISummary ? Color.appAccent.opacity(SystemOpacity.ghost) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: isAISummary ? DesignSystem.smallRadius : 0))
        .padding(.vertical, DesignSystem.tiny)
    }

    // MARK: - Render Code Block
    @ViewBuilder
    private func renderCodeBlock(code: String, language: String) -> some View {
        if language.lowercased() == "mermaid" {
            MermaidWebView(mermaidCode: code)
                .padding(.vertical, DesignSystem.tightPadding)
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if !language.isEmpty {
                    Text(language)
                        .font(.system(.caption2, design: .monospaced).weight(.medium))
                        .foregroundStyle(.appSecondary)
                        .padding(.horizontal, DesignSystem.medium)
                        .padding(.top, DesignSystem.tightPadding)
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
                    .foregroundStyle(.appText.opacity(SystemOpacity.active - SystemOpacity.glass))
                    .padding(DesignSystem.medium)
                }
            }
            .background(Color.appCard.opacity(SystemOpacity.active - SystemOpacity.glass * 1.5))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                    .stroke(Color.appBorder.opacity(SystemOpacity.disabled), lineWidth: SystemStroke.border)
            )
            .padding(.vertical, DesignSystem.tiny)
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
                                .padding(.horizontal, DesignSystem.small)
                                .padding(.vertical, DesignSystem.tightPadding)
                                .frame(minWidth: Layout.minColWidth, maxWidth: Layout.maxColWidth, alignment: .leading)
                        }
                        .background(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                        // 列间分割线（最后一列不加）
                        if index < headers.count - 1 {
                            Divider()
                                .frame(maxHeight: Layout.cellHeight)
                                .background(Color.appBorder.opacity(DesignSystem.Opacity.shadow))
                        }
                    }
                }
                Divider().background(Color.appBorder.opacity(DesignSystem.Opacity.disabled))
                // 数据行
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                            Group {
                                renderInlineContent(cell)
                                    .font(.footnote)
                                    .foregroundStyle(.appText)
                                    .padding(.horizontal, DesignSystem.small)
                                    .padding(.vertical, DesignSystem.tightPadding)
                                    .frame(minWidth: Layout.minColWidth, maxWidth: Layout.maxColWidth, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .background(rowIndex % 2 != 0 ? Color.appCard.opacity(DesignSystem.Opacity.shadow) : Color.clear)
                            if colIndex < row.count - 1 {
                                Divider()
                                    .background(Color.appBorder.opacity(DesignSystem.Opacity.shadow))
                            }
                        }
                    }
                    if rowIndex < rows.count - 1 {
                        Divider().background(Color.appBorder.opacity(DesignSystem.Opacity.shadow))
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                    .stroke(Color.appBorder.opacity(DesignSystem.Opacity.shadow), lineWidth: 0.5)
            )
        }
        .padding(.vertical, DesignSystem.tiny)
    }

    // MARK: - Render Horizontal Rule
    @ViewBuilder
    private func renderHorizontalRule() -> some View {
        Divider()
            .background(Color.appBorder)
            .padding(.vertical, DesignSystem.tightPadding)
    }

    // MARK: - Render Task List
    @ViewBuilder
    private func renderTaskList(items: [(text: String, checked: Bool)]) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.tiny + DesignSystem.atomic) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: DesignSystem.tightPadding) {
                    Image(systemName: item.checked ? DesignSystem.Icons.checkSquareFill : DesignSystem.Icons.emptySquare)
                        .font(.body)
                        .foregroundStyle(item.checked ? .green : .appSecondary)
                    renderInlineContent(item.text)
                        .foregroundStyle(item.checked ? .appSecondary : .appText)
                        .strikethrough(item.checked)
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.vertical, DesignSystem.atomic)
    }

    // MARK: - Inline Content Renderer
    @ViewBuilder
    private func renderInlineContent(_ text: String) -> some View {
        let segments = parser.parseInlineSegments(text)
        
        Text(buildAttributedString(from: segments))
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .environment(\.openURL, OpenURLAction { url in
                if url.scheme == "applink" {
                    let title = url.absoluteString
                        .replacingOccurrences(of: "applink://", with: "")
                        .removingPercentEncoding ?? ""
                    
                    if !title.isEmpty {
                        if title.contains("|") {
                            let actualTitle = title.split(separator: "|").last.map(String.init) ?? title
                            onLinkTap(actualTitle)
                        } else {
                            onLinkTap(title)
                        }
                    }
                    return .handled
                }
                return .systemAction
            })
    }
    
    private func buildAttributedString(from segments: [MarkdownProcessor.InlineSegment]) -> AttributedString {
        var result = AttributedString()
        for segment in segments {
            result.append(attributedString(for: segment))
        }
        return result
    }

    private func attributedString(for segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        switch segment.type {
        case .text: return textSegment(segment)
        case .bold: return boldSegment(segment)
        case .italic: return italicSegment(segment)
        case .strikethrough: return strikethroughSegment(segment)
        case .code: return codeSegment(segment)
        case .applink: return applinkSegment(segment)
        case .link: return linkSegment(segment)
        case .emoji: return emojiSegment(segment)
        }
    }

    private func textSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        var container = AttributedString(segment.content)
        container.swiftUI.font = isCompact ? Font.footnote : Font.body
        return container
    }

    private func boldSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        var container = AttributedString(segment.content)
        container.swiftUI.font = (isCompact ? Font.footnote : Font.body).weight(.bold)
        return container
    }

    private func italicSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        var container = AttributedString(segment.content)
        container.swiftUI.font = (isCompact ? Font.footnote : Font.body).italic()
        return container
    }

    private func strikethroughSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        var container = AttributedString(segment.content)
        container.swiftUI.font = isCompact ? Font.footnote : Font.body
        container.swiftUI.strikethroughStyle = .single
        return container
    }

    private func codeSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        var container = AttributedString(segment.content)
        container.swiftUI.font = .system(.caption, design: .monospaced)
        container.swiftUI.backgroundColor = Color.appAccent.opacity(SystemOpacity.glass)
        container.swiftUI.foregroundColor = .appText
        return container
    }

    private func applinkSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        if segment.content.contains("|") {
            let parts = segment.content.split(separator: "|")
            let label = String(parts.first ?? "")
            let title = String(parts.last ?? "")
            var container = AttributedString(label)
            container.swiftUI.font = (isCompact ? Font.footnote : Font.body).weight(.medium)
            container.swiftUI.foregroundColor = Color.appAccent
            if let encoded = title.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                container.foundation.link = URL(string: "applink://\(encoded)")
            }
            return container
        } else {
            var container = AttributedString(segment.content)
            container.swiftUI.font = (isCompact ? Font.footnote : Font.body).weight(.medium)
            container.swiftUI.foregroundColor = Color.appAccent
            if let encoded = segment.content.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                container.foundation.link = URL(string: "applink://\(encoded)")
            }
            return container
        }
    }

    private func linkSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        let parts = segment.content.split(separator: "|")
        let label = String(parts.first ?? "")
        let urlString = String(parts.last ?? "")
        var container = AttributedString(label)
        container.swiftUI.font = isCompact ? Font.footnote : Font.body
        container.swiftUI.foregroundColor = Color.appAccent
        container.swiftUI.underlineStyle = .single
        if let url = URL(string: urlString) {
            container.foundation.link = url
        }
        return container
    }

    private func emojiSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        var container = AttributedString(segment.content)
        container.swiftUI.font = .body
        return container
    }
    
    // MARK: - Skeleton View
    @ViewBuilder
    private func renderSkeleton() -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
            RoundedRectangle(cornerRadius: DesignSystem.microRadius)
                .fill(Color.appCard)
                .frame(width: DesignSystem.Gallery.callToActionWidth + DesignSystem.huge, height: DesignSystem.Action.largeIconSize)
            
            VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: DesignSystem.microRadius)
                        .fill(Color.appCard.opacity(SystemOpacity.glassStrong))
                        .frame(height: DesignSystem.captionFontSize + DesignSystem.atomic)
                        .frame(maxWidth: .infinity)
                }
            }
            
            RoundedRectangle(cornerRadius: DesignSystem.microRadius)
                .fill(Color.appCard.opacity(SystemOpacity.disabled))
                .frame(width: DesignSystem.Gallery.callToActionWidth - DesignSystem.tightPadding, height: DesignSystem.subheadlineFontSize + SystemSpacing.tiny)
        }
        .padding(.vertical, DesignSystem.tightPadding)
        .opacity(SystemOpacity.glassStrong)
    }
}
