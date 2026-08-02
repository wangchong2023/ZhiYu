//
//  LiveActivityView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / 平台适配
//  核心职责：iOS 灵动岛 (Dynamic Island) 与锁屏 Live Activity Widget 视图组装
//

import SwiftUI
#if os(iOS) && !targetEnvironment(macCatalyst)
import ActivityKit
import WidgetKit

public struct LiveActivityView: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: AIProcessingAttributes.self) { context in
            // 锁屏界面 (Lock Screen Banner)
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color.appCard.opacity(DesignSystem.Opacity.soft))
                .activitySystemActionForegroundColor(Color.appAccent)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开状态 (Expanded Layout)
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: DesignSystem.small) {
                        Image(systemName: iconName(for: context.state.kind))
                            .foregroundStyle(Color.appAccent)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                            Text(context.attributes.taskName)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.primary)
                            Text(context.state.status)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: DesignSystem.atomic) {
                        Text("\(Int(context.state.progress * 100))%")
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                            .foregroundStyle(Color.appAccent)
                        
                        if context.state.estimatedSecondsRemaining > 0 {
                            Text("\(context.state.estimatedSecondsRemaining)s")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: DesignSystem.tiny) {
                        ProgressView(value: context.state.progress)
                            .tint(Color.appAccent)
                        
                        if context.state.kind == .synthesis && context.state.sourceCount > 0 {
                            HStack {
                                Label("\(context.state.sourceCount) Sources", systemImage: DesignSystem.Icons.quote)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                        } else if !context.state.currentFileName.isEmpty {
                            HStack {
                                Text(context.state.currentFileName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    }
                    .padding(.top, DesignSystem.tiny)
                }
            } compactLeading: {
                Image(systemName: iconName(for: context.state.kind))
                    .foregroundStyle(Color.appAccent)
                    .font(.caption.weight(.bold))
            } compactTrailing: {
                Text("\(Int(context.state.progress * 100))%")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(Color.appAccent)
            } minimal: {
                Image(systemName: iconName(for: context.state.kind))
                    .foregroundStyle(Color.appAccent)
                    .font(.caption2)
            }
        }
    }

    private func iconName(for kind: ActivityKind) -> String {
        switch kind {
        case .synthesis: return DesignSystem.Icons.mindmap
        case .ingestOCR: return DesignSystem.Icons.scan
        case .voiceNote: return DesignSystem.Icons.voiceNote
        }
    }
}

// MARK: - 锁屏实时卡片 View
private struct LockScreenLiveActivityView: View {
    let context: ActivityViewContext<AIProcessingAttributes>

    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(DesignSystem.Opacity.soft))
                    .frame(width: Spacing.Sidebar.backButtonWidth, height: Spacing.Sidebar.backButtonWidth)
                
                Image(systemName: iconName(for: context.state.kind))
                    .foregroundStyle(Color.appAccent)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                HStack {
                    Text(context.attributes.taskName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.system(.subheadline, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color.appAccent)
                }

                ProgressView(value: context.state.progress)
                    .tint(Color.appAccent)

                Text(context.state.status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(DesignSystem.standardPadding)
    }

    private func iconName(for kind: ActivityKind) -> String {
        switch kind {
        case .synthesis: return DesignSystem.Icons.mindmap
        case .ingestOCR: return DesignSystem.Icons.scan
        case .voiceNote: return DesignSystem.Icons.voiceNote
        }
    }
}
#endif
