//
//  MarkdownRendererView+Inline.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / Markdown 行内样式与骨架屏扩展
//  核心职责：承载 MarkdownRendererView 的行内富文本渲染（粗体/斜体/删除线/行内代码/双链/链接/表情）
//           与 AI 生成期间的骨架屏占位视图，按单一职责与块级渲染解耦。
//

import SwiftUI
import UFPDesignSystem

extension MarkdownRendererView {

    // MARK: - Inline Content Renderer

    @ViewBuilder
    func renderInlineContent(_ text: String) -> some View {
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
        makeBaseSegment(segment)
    }

    private func boldSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        var container = makeBaseSegment(segment)
        container.swiftUI.font = baseFont.weight(.bold)
        return container
    }

    private func italicSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        var container = makeBaseSegment(segment)
        container.swiftUI.font = baseFont.italic()
        return container
    }

    private func strikethroughSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        var container = makeBaseSegment(segment)
        container.swiftUI.strikethroughStyle = .single
        return container
    }

    /// 构建基础段落（消除重复的 AttributedString 初始化 + baseFont 赋值链）
    private func makeBaseSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        var container = AttributedString(segment.content)
        container.swiftUI.font = baseFont
        return container
    }

    /// 紧凑/正文基础字体（消除重复的 isCompact ? Font.footnote : Font.body 表达式）
    private var baseFont: Font {
        isCompact ? Font.footnote : Font.body
    }

    private func codeSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        var container = AttributedString(segment.content)
        container.swiftUI.font = .system(.caption, design: .monospaced)
        container.swiftUI.backgroundColor = Color.appAccent.opacity(DesignTokens.SystemOpacity.glass)
        container.swiftUI.foregroundColor = .appText
        return container
    }

    private func applinkSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        let label: String
        let linkTarget: String
        if segment.content.contains("|") {
            let parts = segment.content.split(separator: "|")
            label = String(parts.first ?? "")
            linkTarget = String(parts.last ?? "")
        } else {
            label = segment.content
            linkTarget = segment.content
        }
        var container = AttributedString(label)
        container.swiftUI.font = baseFont.weight(.medium)
        container.swiftUI.foregroundColor = Color.appAccent
        if let encoded = linkTarget.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
            container.foundation.link = URL(string: "applink://\(encoded)")
        }
        return container
    }

    private func linkSegment(_ segment: MarkdownProcessor.InlineSegment) -> AttributedString {
        let parts = segment.content.split(separator: "|")
        let label = String(parts.first ?? "")
        let urlString = String(parts.last ?? "")
        var container = AttributedString(label)
        container.swiftUI.font = baseFont
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
    func renderSkeleton() -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.standardPadding) {
            RoundedRectangle(cornerRadius: DesignTokens.Spacing.microRadius)
                .fill(Color.appCard)
                .frame(width: DesignSystem.Gallery.callToActionWidth + DesignTokens.Spacing.huge, height: DesignSystem.Action.largeIconSize)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.tightPadding) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: DesignTokens.Spacing.microRadius)
                        .fill(Color.appCard.opacity(DesignTokens.SystemOpacity.glassStrong))
                        .frame(height: DesignTokens.SystemSpacing.contentMedium)
                        .frame(maxWidth: .infinity)
                }
            }

            RoundedRectangle(cornerRadius: DesignTokens.Spacing.microRadius)
                .fill(Color.appCard.opacity(DesignTokens.SystemOpacity.disabled))
                .frame(width: DesignSystem.Gallery.callToActionWidth - DesignTokens.Spacing.tightPadding, height: DesignTokens.Typography.subheadlineFontSize + DesignTokens.SystemSpacing.tiny)
        }
        .padding(.vertical, DesignTokens.Spacing.tightPadding)
        .opacity(DesignTokens.SystemOpacity.glassStrong)
    }
}
