//
//  ThinkingCollapsibleView.swift
//  ZhiYu
//
//  系统层级：[L3] 表现层 / 视图组件
//  核心职责：大模型深度思考过程 (<think>) 折叠收起与展开呈现组件，提供思考耗时徽章与清晰的推导阶段展示。
//

import SwiftUI
import UFPCore
import UFPDesignSystem

/// 思考过程解析结果结构体
struct ParsedThinkingResult: Equatable, Sendable {
    let thinkingText: String?
    let answerText: String
}

/// 思考过程解析工具类
enum ThinkingContentParser {
    private enum TagPairs {
        static let thoughtOpen = "<thought>"
        static let thoughtClose = "</thought>"
        static let pairs: [(open: String, close: String)] = [
            (FeatureConstants.ThinkingConstants.thinkTagOpen, FeatureConstants.ThinkingConstants.thinkTagClose),
            (thoughtOpen, thoughtClose)
        ]
    }

    /// 从模型回复中分离思考过程与最终答案（支持 `<think>` 与 `<thought>`、多段思考块与流式半闭合）
    static func parse(rawText: String) -> ParsedThinkingResult {
        var thoughts: [String] = []
        var answerParts: [String] = []
        var foundTag = false
        var cursor = rawText.startIndex

        while cursor < rawText.endIndex {
            guard let nextOpen = findEarliestOpenTag(in: rawText, from: cursor) else {
                answerParts.append(String(rawText[cursor...]))
                break
            }

            foundTag = true
            if nextOpen.range.lowerBound > cursor {
                answerParts.append(String(rawText[cursor..<nextOpen.range.lowerBound]))
            }

            let contentStart = nextOpen.range.upperBound
            if let closeRange = rawText.range(of: nextOpen.closeTag, options: .caseInsensitive, range: contentStart..<rawText.endIndex) {
                let thought = String(rawText[contentStart..<closeRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !thought.isEmpty {
                    thoughts.append(thought)
                }
                cursor = closeRange.upperBound
            } else {
                // 流式生成思考内容中（尚未收到闭合标签）
                let thought = String(rawText[contentStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !thought.isEmpty {
                    thoughts.append(thought)
                }
                break
            }
        }

        guard foundTag else {
            return ParsedThinkingResult(thinkingText: nil, answerText: rawText)
        }
        let joinedThought = thoughts.isEmpty ? nil : thoughts.joined(separator: "\n\n")
        let joinedAnswer = answerParts.joined().trimmingCharacters(in: .whitespacesAndNewlines)
        return ParsedThinkingResult(thinkingText: joinedThought, answerText: joinedAnswer)
    }

    private static func findEarliestOpenTag(
        in text: String,
        from start: String.Index
    ) -> (range: Range<String.Index>, closeTag: String)? {
        var earliest: (range: Range<String.Index>, closeTag: String)?
        for pair in TagPairs.pairs {
            guard let range = text.range(of: pair.open, options: .caseInsensitive, range: start..<text.endIndex) else {
                continue
            }
            if let current = earliest {
                if range.lowerBound < current.range.lowerBound {
                    earliest = (range, pair.close)
                }
            } else {
                earliest = (range, pair.close)
            }
        }
        return earliest
    }
}

/// 思考过程可折叠交互视图
@MainActor
struct ThinkingCollapsibleView: View {
    let thinkingText: String
    let durationSeconds: Double
    let isStreaming: Bool

    @State private var isExpanded: Bool = false

    init(thinkingText: String, durationSeconds: Double = FeatureConstants.ThinkingConstants.defaultSimulatedThinkingSeconds, isStreaming: Bool = false) {
        self.thinkingText = thinkingText
        self.durationSeconds = durationSeconds
        self.isStreaming = isStreaming
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.atomic) {
            headerButton

            if isExpanded {
                contentBox
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, DesignTokens.SystemSpacing.atomic)
    }

    // MARK: - 子视图拆分

    private var headerButton: some View {
        Button {
            withAnimation(.easeInOut(duration: DesignTokens.Animations.fastDuration)) {
                HapticFeedback.shared.trigger(.selection)
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                Image(systemName: DesignTokens.Icons.brain)
                    .font(.caption2)
                    .foregroundStyle(Color.theme.purple)

                if isStreaming {
                    Text(L10n.ModelManager.Lab.Thinking.inProgress)
                        .font(.caption2.bold())
                        .foregroundStyle(Color.theme.purple)
                } else {
                    let formattedDuration = String(format: "%.1fs", durationSeconds)
                    Text(L10n.ModelManager.Lab.Thinking.completedFormat(formattedDuration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isExpanded ? DesignTokens.Icons.chevronDown : DesignTokens.Icons.chevronRight)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, DesignTokens.Spacing.standardPadding)
            .padding(.vertical, DesignTokens.SystemSpacing.tiny)
            .background(Color.theme.purple.opacity(DesignTokens.Opacity.ghost))
            .cornerRadius(DesignTokens.SystemRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small)
                    .stroke(Color.theme.purple.opacity(DesignTokens.Opacity.subtle), lineWidth: DesignTokens.SystemStroke.divider)
            )
        }
        .buttonStyle(.plain)
    }

    private var contentBox: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.tight) {
            Text(thinkingText)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineSpacing(DesignTokens.SystemSpacing.atomic)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.standardPadding)
        .background(Color.appCard.opacity(DesignTokens.Opacity.faint))
        .cornerRadius(DesignTokens.SystemRadius.small)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.small)
                .stroke(Color.appBorder.opacity(DesignTokens.Opacity.subtle), lineWidth: DesignTokens.SystemStroke.divider)
        )
    }
}
