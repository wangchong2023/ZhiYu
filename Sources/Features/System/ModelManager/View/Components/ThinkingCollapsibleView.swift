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
    /// 从模型回复中分离思考过程与最终答案
    static func parse(rawText: String) -> ParsedThinkingResult {
        let openTag = FeatureConstants.ThinkingConstants.thinkTagOpen
        let closeTag = FeatureConstants.ThinkingConstants.thinkTagClose

        guard let openRange = rawText.range(of: openTag, options: .caseInsensitive) else {
            return ParsedThinkingResult(thinkingText: nil, answerText: rawText)
        }

        if let closeRange = rawText.range(of: closeTag, options: .caseInsensitive, range: openRange.upperBound..<rawText.endIndex) {
            let thought = String(rawText[openRange.upperBound..<closeRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let answer = String(rawText[closeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedThinkingResult(thinkingText: thought.isEmpty ? nil : thought, answerText: answer)
        } else {
            // 正在流式生成思考内容中（尚未闭合 </think>）
            let thought = String(rawText[openRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return ParsedThinkingResult(thinkingText: thought, answerText: "")
        }
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
            withAnimation(.easeInOut(duration: 0.2)) {
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
