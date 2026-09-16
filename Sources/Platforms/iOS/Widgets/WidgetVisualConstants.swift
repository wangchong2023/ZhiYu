//
//  WidgetVisualConstants.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Platforms] Widget Extension
//  核心职责：Widget Extension 共享视觉常量与基础视图组件，消除 4 个 Widget 文件中
//           重复的 WidgetMetrics 定义、LinearGradient 背景、containerBackground 修饰
//           与 Timeline 构造模式。
//

import SwiftUI
import WidgetKit

// MARK: - Widget 共享视觉常量

/// Widget Extension 共享视觉常量集（消除 4 个 Widget 文件中重复的 WidgetMetrics 定义）
enum WidgetVisualConstants {

    // MARK: - 背景渐变
    /// 暗色背景渐变顶部色值
    static let darkBgTop: Color = Color(red: 0.1, green: 0.11, blue: 0.18)
    /// 暗色背景渐变底部色值
    static let darkBgBottom: Color = Color(red: 0.06, green: 0.07, blue: 0.12)

    // MARK: - 透明度
    /// 柔和高亮透明度（标题/引文）
    static let opacitySoft: Double = 0.9
    /// 轻量分隔透明度（Divider）
    static let opacityLight: Double = 0.1
    /// 微妙卡片透明度（背景填充）
    static let opacitySubtle: Double = 0.05
    /// 幽灵按钮透明度（按钮背景）
    static let opacityGhost: Double = 0.05
    /// 光晕透明度（圆形按钮光晕）
    static let opacityGlow: Double = 0.2

    // MARK: - 圆角
    /// 卡片圆角
    static let cardCornerRadius: CGFloat = 8
    /// Widget 圆角
    static let widgetCornerRadius: CGFloat = 6
    /// 微型圆角
    static let microCornerRadius: CGFloat = 4
    /// 按钮圆角
    static let buttonCornerRadius: CGFloat = 12

    // MARK: - 刷新间隔
    /// 小组件刷新间隔（秒，30 分钟）
    static let refreshIntervalSeconds: TimeInterval = 1800

    // MARK: - 尺寸
    /// 圆形按钮尺寸
    static let circleSize: CGFloat = 44
    /// 最小分段宽度
    static let minSegmentWidth: CGFloat = 8
    /// 条形图高度
    static let barHeight: CGFloat = 10
    /// 图例圆点尺寸
    static let legendDotSize: CGFloat = 6
    /// 热力图方格高度
    static let heatSquareHeight: CGFloat = 30
    /// 分段圆角
    static let cornerRadius: CGFloat = 3
    /// 热力图圆角
    static let heatCornerRadius: CGFloat = 4
    /// 行图标尺寸
    static let rowIconSize: CGFloat = 20
    /// 箭头图标尺寸
    static let chevronFontSize: CGFloat = 8

    // MARK: - 透明度（补充）
    /// 半透明（箭头/次要元素）
    static let opacityHalf: Double = 0.5
    /// 极淡背景（行卡片背景）
    static let opacityFaint: Double = 0.03
    /// 中等透明度（渐变光晕）
    static let opacityMedium: Double = 0.15

    // MARK: - 间距
    /// 紧凑间距
    static let spacingCompact: CGFloat = 4
    /// 标准间距
    static let spacingStandard: CGFloat = 8
    /// 宽松间距
    static let spacingWide: CGFloat = 12
    /// 大间距
    static let spacingLarge: CGFloat = 16

    // MARK: - 内边距
    /// 水平内边距
    static let horizontalPadding: CGFloat = 8
    /// 垂直内边距
    static let verticalPadding: CGFloat = 6
    /// 边缘内边距
    static let edgePadding: CGFloat = 12

    // MARK: - 字号
    /// 微型字号
    static let microFontSize: CGFloat = 9
    /// 小字号
    static let smallFontSize: CGFloat = 10
    /// 说明字号
    static let captionFontSize: CGFloat = 11

    // MARK: - 渐变背景视图

    /// Widget 标准暗色渐变背景
    static var gradientBackground: some View {
        LinearGradient(
            colors: [darkBgTop, darkBgBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Widget Timeline 构造器

/// Widget Timeline 通用构造工具，消除各 Provider 中重复的
/// `Task.detached { await MainActor.run { Timeline(...) } }` 模式。
enum WidgetTimelineBuilder {

    /// 构造单条目的 Timeline，使用标准刷新间隔
    /// - Parameters:
    ///   - entry: Timeline 条目
    ///   - completion: Timeline 回调
    static func buildSingleTimeline<Entry: TimelineEntry>(
        entry: Entry,
        completion: @escaping @Sendable (Timeline<Entry>) -> Void
    ) {
        Task.detached {
            await MainActor.run {
                let nextUpdate = Date().addingTimeInterval(WidgetVisualConstants.refreshIntervalSeconds)
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            }
        }
    }
}
