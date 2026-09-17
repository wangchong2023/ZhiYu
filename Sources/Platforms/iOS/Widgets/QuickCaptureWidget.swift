//
//  QuickCaptureWidget.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：iOS 桌面与锁屏【极速捕获与 AI 助手入口】Widget 渲染与 Deep Link 唤醒。
//

import SwiftUI
@preconcurrency import WidgetKit

// MARK: - Timeline Entry
struct QuickCaptureEntry: TimelineEntry {
    let date: Date
}

// MARK: - Provider
struct QuickCaptureProvider: TimelineProvider {
    typealias Entry = QuickCaptureEntry

    func placeholder(in context: Context) -> QuickCaptureEntry {
        QuickCaptureEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (QuickCaptureEntry) -> Void) {
        completion(QuickCaptureEntry(date: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping @Sendable (Timeline<QuickCaptureEntry>) -> Void) {
        let timeline = Timeline(entries: [QuickCaptureEntry(date: Date())], policy: .never)
        completion(timeline)
    }
}

// MARK: - Widget View
struct QuickCaptureWidgetEntryView: View {
    var entry: QuickCaptureProvider.Entry

    var body: some View {
        WidgetContainerBackground { family in
            switch family {
            case .systemMedium:
                mediumView
            case .accessoryRectangular:
                accessoryView
            default:
                mediumView
            }
        }
    }

    private var mediumView: some View {
        HStack(spacing: 3) {
            WidgetCaptureButton(title: WidgetL10n.voice, icon: WidgetSharedConstants.Icon.micFill, color: WidgetSharedConstants.Color.purple, url: WidgetSharedConstants.DeepLink.voice)
            WidgetCaptureButton(title: WidgetL10n.ocr, icon: WidgetSharedConstants.Icon.docTextViewfinder, color: WidgetSharedConstants.Color.blue, url: WidgetSharedConstants.DeepLink.ocr)
            WidgetCaptureButton(title: WidgetL10n.search, icon: WidgetSharedConstants.Icon.magnifyingglass, color: WidgetSharedConstants.Color.orange, url: WidgetSharedConstants.DeepLink.search)
            WidgetCaptureButton(title: WidgetL10n.qa, icon: WidgetSharedConstants.Icon.sparkles, color: WidgetSharedConstants.Color.teal, url: WidgetSharedConstants.DeepLink.chat)
        }
        .padding(WidgetVisualConstants.spacingWide)
    }

    private var accessoryView: some View {
        HStack(spacing: WidgetVisualConstants.spacingStandard) {
            WidgetAccessoryIconLink(icon: WidgetSharedConstants.Icon.micFill, url: WidgetSharedConstants.DeepLink.voice)
            WidgetAccessoryIconLink(icon: WidgetSharedConstants.Icon.docTextViewfinder, url: WidgetSharedConstants.DeepLink.ocr)
            WidgetAccessoryIconLink(icon: WidgetSharedConstants.Icon.sparkles, url: WidgetSharedConstants.DeepLink.chat)
        }
    }
}

// MARK: - 捕获按钮（中尺寸）

/// Widget 中尺寸捕获按钮：圆形光晕 + 图标 + 标签，消除 QuickCaptureWidget 中
/// 4 次重复的 `captureButton` 构造模式。
struct WidgetCaptureButton: View {
    let title: String
    let icon: String
    let color: Color
    let url: String

    var body: some View {
        Link(destination: WidgetDeepLinkURL.resolve(url)) {
            VStack(spacing: WidgetVisualConstants.spacingStandard) {
                ZStack {
                    Circle()
                        .fill(color.opacity(WidgetVisualConstants.opacityGlow))
                        .frame(width: WidgetVisualConstants.circleSize, height: WidgetVisualConstants.circleSize)
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(WidgetVisualConstants.opacityGhost))
            .clipShape(RoundedRectangle(cornerRadius: WidgetVisualConstants.buttonCornerRadius))
        }
    }
}

// MARK: - 辅助尺寸图标链接

/// Widget 辅助尺寸（accessoryRectangular）图标链接，消除 QuickCaptureWidget
/// accessoryView 中 3 次重复的 `Link + Image + font(.title3)` 模式。
struct WidgetAccessoryIconLink: View {
    let icon: String
    let url: String

    var body: some View {
        Link(destination: WidgetDeepLinkURL.resolve(url)) {
            Image(systemName: icon)
                .font(.title3)
        }
    }
}

// MARK: - Widget Definition
struct QuickCaptureWidget: Widget {
    let kind: String = "QuickCaptureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickCaptureProvider()) { entry in
            QuickCaptureWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetL10n.quickCaptureTitle)
        .supportedFamilies([.systemMedium, .accessoryRectangular])
        .contentMarginsDisabled()
    }
}
