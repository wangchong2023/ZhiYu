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

private enum WidgetMetrics {
    static let darkBgTop = Color(red: 0.1, green: 0.11, blue: 0.18)
    static let darkBgBottom = Color(red: 0.06, green: 0.07, blue: 0.12)
    static let circleSize: CGFloat = 44
    static let opacityGhost: Double = 0.05
    static let opacityGlow: Double = 0.2
    static let buttonCornerRadius: CGFloat = 12
}

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
    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [WidgetMetrics.darkBgTop, WidgetMetrics.darkBgBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            switch family {
            case .systemMedium:
                mediumView
            case .accessoryRectangular:
                accessoryView
            default:
                mediumView
            }
        }
        .containerBackground(for: .widget) { Color.clear }
    }

    private var mediumView: some View {
        HStack(spacing: 3) {
            captureButton(title: WidgetL10n.voice, icon: "mic.fill", color: WidgetSharedConstants.Color.purple, url: WidgetSharedConstants.DeepLink.voice)
            captureButton(title: WidgetL10n.ocr, icon: "doc.text.viewfinder", color: WidgetSharedConstants.Color.blue, url: WidgetSharedConstants.DeepLink.ocr)
            captureButton(title: WidgetL10n.search, icon: "magnifyingglass", color: WidgetSharedConstants.Color.orange, url: WidgetSharedConstants.DeepLink.search)
            captureButton(title: WidgetL10n.qa, icon: "sparkles", color: WidgetSharedConstants.Color.teal, url: WidgetSharedConstants.DeepLink.chat)
        }
        .padding(12)
    }

    private var accessoryView: some View {
        HStack(spacing: 8) {
            Link(destination: URL(string: WidgetSharedConstants.DeepLink.voice) ?? URL(string: "about:blank")!) {
                Image(systemName: "mic.fill")
                    .font(.title3)
            }
            Link(destination: URL(string: WidgetSharedConstants.DeepLink.ocr) ?? URL(string: "about:blank")!) {
                Image(systemName: "doc.text.viewfinder")
                    .font(.title3)
            }
            Link(destination: URL(string: WidgetSharedConstants.DeepLink.chat) ?? URL(string: "about:blank")!) {
                Image(systemName: "sparkles")
                    .font(.title3)
            }
        }
    }

    private func captureButton(title: String, icon: String, color: Color, url: String) -> some View {
        Link(destination: URL(string: url) ?? URL(string: "about:blank")!) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(color.opacity(WidgetMetrics.opacityGlow))
                        .frame(width: WidgetMetrics.circleSize, height: WidgetMetrics.circleSize)
                    Image(systemName: icon)
                        .font(.headline)
                        .foregroundStyle(color)
                }

                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(WidgetMetrics.opacityGhost))
            .clipShape(RoundedRectangle(cornerRadius: WidgetMetrics.buttonCornerRadius))
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
