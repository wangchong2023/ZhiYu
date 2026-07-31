//
//  DesignSystem+Metrics.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：设计系统令牌：颜色、排版、间距、动画、图标等可视化常量。
//
import SwiftUI
import CoreGraphics

extension DesignSystem {

    // MARK: - 11. 指标与仪表盘 (Metrics)
    public enum Metrics {
        public static let heroValueSize: CGFloat = Spacing.Metrics.heroValueSize
        public static let subValueSize: CGFloat = Spacing.Metrics.subValueSize
        public static let chartHeight: CGFloat = Spacing.Metrics.chartHeight
        public static let boxHeight: CGFloat = Spacing.Metrics.boxHeight
        public static let indicatorSize: CGFloat = Spacing.Metrics.indicatorSize
        public static let progressHeight: CGFloat = Spacing.Metrics.progressHeight
        public static let ringSize: CGFloat = Spacing.Metrics.ringSize
        public static let boxAspectRatio: CGFloat = Spacing.Metrics.boxAspectRatio
        public static let dashboardValueSize: CGFloat = Spacing.Metrics.dashboardValueSize
        public static let dashboardLabelSize: CGFloat = Spacing.Metrics.dashboardLabelSize
        public static let dashboardRadius: CGFloat = Spacing.Metrics.dashboardRadius
        public static let iconBoxSize: CGFloat = Spacing.Metrics.iconBoxSize
        public static let smallIconBoxSize: CGFloat = Spacing.Metrics.smallIconBoxSize
        public static let largeIconBoxSize: CGFloat = Spacing.Metrics.largeIconBoxSize
        public static let titleFontSize: CGFloat = Spacing.Metrics.titleFontSize
        public static let sourceCardWidth: CGFloat = Spacing.Metrics.sourceCardWidth
        public static let sourceCardHeight: CGFloat = Spacing.Metrics.sourceCardHeight
        public static let titleSmallFontSize: CGFloat = Spacing.Metrics.titleSmallFontSize
        public static let maxBreadcrumbCount: Int = Spacing.Metrics.maxBreadcrumbCount
        public static let maxCollabEditHistory: Int = Spacing.Metrics.maxCollabEditHistory
        public static let maxCollabEditPreviewLength: Int = Spacing.Metrics.maxCollabEditPreviewLength
        public static let maxTagCloudHeight: CGFloat = Spacing.Metrics.maxTagCloudHeight
        public static let knowledgeGrowthDaysLimit: Int = Spacing.Metrics.knowledgeGrowthDaysLimit
        public static let graphCoachMarkThreshold: Int = Spacing.Metrics.graphCoachMarkThreshold
        public static let maxReportPageExportCount: Int = Spacing.Metrics.maxReportPageExportCount
        public static let reportContentPreviewLength: Int = Spacing.Metrics.reportContentPreviewLength
        public static let maxReportContentLineLimit: Int = Spacing.Metrics.maxReportContentLineLimit
        public static let maxDashboardItems: Int = Spacing.Metrics.maxDashboardItems
        public static let maxRecentItems: Int = Spacing.Metrics.maxRecentItems
        public static let A4Width: CGFloat = Spacing.Metrics.A4Width
        public static let A4Height: CGFloat = Spacing.Metrics.A4Height
        public static let emptyStateVerticalPadding: CGFloat = Spacing.Metrics.emptyStateVerticalPadding
        public static let emptyStateIconOpacity: CGFloat = Spacing.Metrics.emptyStateIconOpacity
        public static let sectionSpacing: CGFloat = Spacing.Metrics.sectionSpacing
        
        public static let lockOverlayScaleMultiplier: CGFloat = Spacing.Metrics.lockOverlayScaleMultiplier
        public static let coachMarkScaleMultiplier: CGFloat = Spacing.Metrics.coachMarkScaleMultiplier
        public static let splashQuoteShimmerOffset: CGFloat = Spacing.Metrics.splashQuoteShimmerOffset
        
        public static let commandPaletteHeight: CGFloat = Spacing.Metrics.commandPaletteHeight
        public static let coachMarkIconScale: CGFloat = Spacing.Metrics.coachMarkIconScale
        public static let coachMarkActionHorizontalPadding: CGFloat = Spacing.Metrics.coachMarkActionHorizontalPadding
        public static let coachMarkRadiusOffset: CGFloat = Spacing.Metrics.coachMarkRadiusOffset
        public static let coachMarkShadowRadius: CGFloat = Spacing.Metrics.coachMarkShadowRadius
        public static let coachMarkShadowY: CGFloat = Spacing.Metrics.coachMarkShadowY
        
        public static let welcomeHeroDotWidth: CGFloat = Spacing.Metrics.welcomeHeroDotWidth
        public static let welcomeHeroDotHeight: CGFloat = Spacing.Metrics.welcomeHeroDotHeight
        public static let welcomeHeroCircleSize: CGFloat = Spacing.Metrics.welcomeHeroCircleSize
        public static let welcomeHeroIconSize: CGFloat = Spacing.Metrics.welcomeHeroIconSize
        public static let statCardMinWidth: CGFloat = Spacing.Metrics.statCardMinWidth
        /// macOS/Catalyst 最小窗口宽度 (800px)
        public static let minWindowWidth: CGFloat = Spacing.Metrics.minWindowWidth
        /// macOS/Catalyst 最小窗口高度 (600px)
        public static let minWindowHeight: CGFloat = Spacing.Metrics.minWindowHeight
        /// 笔记本名称最大长度限制 (24字符)
        public static let maxNotebookNameLength: Int = 24
        /// 耗时分析标签宽度 (60px)
        public static let timingLabelWidth: CGFloat = 60
    
        // MARK: - 语义化 UI 组件与布局 Token
        /// 分割线厚度 (1px)
        public static let dividerThickness: CGFloat = 1
        /// 按钮与图标操作框尺寸 (56px)
        public static let notebookActionIconSize: CGFloat = 56
        /// 笔记本卡片宽度 (140px)
        public static let notebookCardWidth: CGFloat = 140
        /// 笔记本卡片高度 (180px)
        public static let notebookCardHeight: CGFloat = 180
        /// 笔记本标记条宽度 (40px)
        public static let notebookBadgeWidth: CGFloat = 40
        /// 头像选择框尺寸 (96px)
        public static let avatarPickerSize: CGFloat = 96
        /// 颜色选项圈尺寸 (54px)
        public static let colorOptionSize: CGFloat = 54
        /// 图谱控制浮框宽度 (140px)
        public static let graphControlWidth: CGFloat = 140
        /// 搜索命令面板宽度 (500px)
        public static let commandPaletteWidth: CGFloat = 500
        /// 锁屏/安全校验弹窗宽度 (500px)
        public static let lockDialogWidth: CGFloat = 500
        /// 锁屏/安全校验弹窗高度 (400px)
        public static let lockDialogHeight: CGFloat = 400
        /// 骨架屏头像尺寸 (40px)
        public static let avatarSkeletonSize: CGFloat = 40
        /// 骨架屏文本高度 (14px)
        public static let textSkeletonHeight: CGFloat = 14
        /// 空状态插画高度 (100px)
        public static let emptyStateGraphicHeight: CGFloat = 100
        /// 背景装饰光晕尺寸 (300px / 500px)
        public static let backgroundDecorativeSize: CGFloat = 300
        public static let backgroundLargeDecorativeSize: CGFloat = 500
        /// 彩虹徽章小/大图标 (14px / 22px)
        public static let glowBadgeSmallIcon: CGFloat = 14
        public static let glowBadgeLargeIcon: CGFloat = 22
        public static let glowBadgeSize: CGFloat = 14
        public static let glowBadgeRingSize: CGFloat = 22
        
        /// 动画光晕与解密动效圈尺寸 (500px / 400px / 180px / 220px)
        public static let largeGlowSize: CGFloat = 500
        public static let mediumGlowSize: CGFloat = 400
        public static let ringSmallSize: CGFloat = 180
        public static let ringLargeSize: CGFloat = 220
        
        public static let settingsSidebarWidth: CGFloat = Spacing.Metrics.settingsSidebarWidth
        public static let settingsIconFrameSize: CGFloat = Spacing.Metrics.settingsIconFrameSize
    }
}
