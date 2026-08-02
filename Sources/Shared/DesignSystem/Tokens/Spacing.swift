//
//  Spacing.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：设计系统令牌：颜色、排版、间距、动画、图标等可视化常量。
//
import Foundation
import CoreGraphics

/// 智宇原子间距令牌 (Spacing Tokens)
/// 包含基础步进间距、圆角规范及各组件的布局指标。
public enum Spacing {
    
    // MARK: - 1. 原子间距 (Atomic Spacing)
    // MARK: @PR-03: 布局常数直接影响渲染管线的布局计算与滚动性能
    
    /// 最小步进常数 (2px)
    public static let atomic: CGFloat = 2
    /// 极小间距 (4px)
    public static let tiny: CGFloat = 4
    /// 小型间距 (8px)
    public static let small: CGFloat = 8
    /// 中型间距 (12px)
    public static let medium: CGFloat = 12
    /// 标准页面内边距 (16px)
    public static let standardPadding: CGFloat = 16
    /// 大型间距 (16px)
    public static let large: CGFloat = 16
    /// 宽型间距 (20px)
    public static let wide: CGFloat = 20
    /// 巨型间距 (24px)
    public static let giant: CGFloat = 24
    /// 极大型间距 (32px)
    public static let huge: CGFloat = 32
    
    /// 底部输入栏基准高度 (54px)
    public static let inputBarHeight: CGFloat = 54
    /// 宽松内边距 (24px)
    public static let loosePadding: CGFloat = 24
    /// 宽幅内边距 (20px)
    public static let widePadding: CGFloat = 20
    /// 紧凑内边距 (8px)
    public static let tightPadding: CGFloat = 8
    
    // MARK: - 2. 原子圆角 (Atomic Radius)
    // MARK: @PR-03: 圆角半径需遵循 GPU 优化准则以维持 60 FPS
    
    /// 微型圆角 (4px)
    public static let microRadius: CGFloat = 4
    /// 小型圆角 (8px)
    public static let smallRadius: CGFloat = 8
    /// 中型圆角 (10px)
    public static let mediumRadius: CGFloat = 10
    /// 卡片通用圆角 (12px)
    public static let cardRadius: CGFloat = 12
    /// 标准圆角 (12px)
    public static let standardRadius: CGFloat = 12
    /// 大型圆角 (16px)
    public static let largeRadius: CGFloat = 16
    /// 胶囊型圆角 (20px)
    public static let chipRadius: CGFloat = 20
    
    // MARK: - 3. 图标尺寸 (Icon Sizes)
    
    /// 极小图标尺寸 (12px)
    public static let iconTiny: CGFloat = 12
    /// 小型图标尺寸 (16px)
    public static let iconSmall: CGFloat = 16
    /// 中型图标尺寸 (20px)
    public static let iconMedium: CGFloat = 20
    /// 大型图标尺寸 (24px)
    public static let iconLarge: CGFloat = 24
    /// 巨大图标尺寸 (32px)
    public static let iconHuge: CGFloat = 32
    /// 展示型图标尺寸 (48px)
    public static let iconDisplay: CGFloat = 48
    
    /// 小型图标尺寸别名 (16px)
    public static let smallIconSize: CGFloat = 16
    /// 标题图标尺寸 (24px)
    public static let titleIconSize: CGFloat = 24
    /// 大型图标尺寸别名 (28px)
    public static let largeIconSize: CGFloat = 28
    /// 微型图标尺寸 (14px)
    public static let microIconSize: CGFloat = 14
    /// 说明文字图标尺寸 (12px)
    public static let captionIconSize: CGFloat = 12
    
    // MARK: - 4. 布局模式 (Layout Patterns)
    
    /// 全局布局规范
    public struct Layout {
        /// 内容最大阅读宽度 (针对阅读体验优化的 800px)
        public static let maxReadWidth: CGFloat = 800
        /// 卡 cardContentPadding (16px)
        public static let cardContentPadding: CGFloat = 16
        /// 紧凑型边距 (8px)
        public static let tightPadding: CGFloat = 8
        /// 页面顶部标题栏纵向边距 (12px)
        public static let headerVerticalPadding: CGFloat = 12
        /// 欢迎页顶部内边距 (huge + small)
        public static let welcomeHeaderTopPadding: CGFloat = huge + small
        /// 移动端侧边栏覆盖层纵向内边距 (medium)
        public static let sidebarOverlayVerticalPadding: CGFloat = medium
        /// 栏目间距 (16px)
        public static let columnSpacing: CGFloat = 16
        /// 列表行间距 (8px)
        public static let listRowSpacing: CGFloat = 8
    }
    
    /// 按钮与输入控件的交互规范
    public struct Action {
        /// 标准按钮高度
        public static let buttonHeight: CGFloat = 44
        /// 紧凑型按钮高度
        public static let compactButtonHeight: CGFloat = 32
        /// 胶囊标签高度
        public static let capsuleHeight: CGFloat = 28
        /// 标准输入框高度
        public static let inputFieldHeight: CGFloat = 50
        /// 最小可点击目标尺寸 (Apple 建议 44pt)
        public static let minTouchTarget: CGFloat = 44
        /// 输入栏标准高度
        public static let inputBarHeight: CGFloat = 44
        /// 按钮组间距
        public static let buttonSpacing: CGFloat = 12
        /// 按钮内部图标尺寸
        public static let iconSize: CGFloat = 16
        /// 小型按钮图标尺寸
        public static let smallIconSize: CGFloat = 14
        /// 大型操作图标尺寸
        public static let largeIconSize: CGFloat = 24
        /// 返回按钮点击区域宽度
        public static let backButtonWidth: CGFloat = 40
        /// 按压缩放比例
        public static let pressScale: CGFloat = 0.96
        /// 标准动画时长
        public static let animationDuration: Double = 0.2
    }
    
    /// 展示模式规范
    public struct Gallery {
        public static let itemSize: CGFloat = 100
        public static let iconSize: CGFloat = 40
        public static let badgeOffset: CGFloat = 28
        public static let itemRadius: CGFloat = 16
        public static let displayIconSize: CGFloat = 120
        public static let splashIconSize: CGFloat = 80
        public static let blurRadius: CGFloat = 40
        public static let mainIconSize: CGFloat = 64
        public static let callToActionWidth: CGFloat = 160
        public static let callToActionHeight: CGFloat = 50
        public static let containerRadius: CGFloat = 24
        public static let containerPadding: CGFloat = 32
        public static let showcaseRadius: CGFloat = 20
        /// 悬停缩放比例
        public static let hoverScale: CGFloat = 1.05
        
        /// 启动页 Logo 底部间距
        public static let splashLogoBottomPadding: CGFloat = huge * 2
        /// 启动页按钮底部间距
        public static let splashButtonBottomPadding: CGFloat = huge * 1.5
        
        public static let cardMinWidth: CGFloat = 120
        public static let emptyStateImageSize: CGFloat = 160
        public static let modalMaxWidth: CGFloat = 480
    }
    
    /// 时间轴展示规范
    public struct Timeline {
        public static let emptyIconSize: CGFloat = 64
        public static let indicatorSize: CGFloat = 36
        public static let detailHorizontalPadding: CGFloat = 12
        public static let detailVerticalPadding: CGFloat = 8
        public static let indentPadding: CGFloat = 48
        public static let rowVerticalPadding: CGFloat = 12
        public static let iconCircleSize: CGFloat = 36
    }
    
    /// 通用网格布局规范
    public struct Grid {
        public static let standardSpacing: CGFloat = 16
        public static let largeSpacing: CGFloat = 50
        public static let tightSpacing: CGFloat = 8
        public static let flowSpacing: CGFloat = 10
        public static let emptyStateHeight: CGFloat = 220
    }
    
    /// 知识图谱布局规范
    public struct Graph {
        public static let nodeSize: CGFloat = 40
        public static let selectedNodeSize: CGFloat = 48
        public static let nodeSizeReference: CGFloat = 20
        public static let centralNodeSize: CGFloat = 60
        public static let linkWidth: CGFloat = 1.5
        public static let forceStrength: CGFloat = -200
        public static let minScale: CGFloat = 0.5
        public static let maxScale: CGFloat = 2.0
        public static let tightPadding: CGFloat = 8
        public static let toolbarPaddingTrailing: CGFloat = 20
        public static let toolbarPaddingBottomExpanded: CGFloat = 150
        public static let toolbarPaddingBottomDefault: CGFloat = 20
        public static let layoutPadding: CGFloat = 40
        public static let minLayoutDimension: CGFloat = 100
        public static let highlightedLineWidth: CGFloat = 3.0
        public static let emptyIconSize: CGFloat = 60
        
        public struct ThreeD {
            public static let baseNodeSize: CGFloat = 3.5
            public static let minNodeSize: CGFloat = 3.0
            public static let maxNodeSize: CGFloat = 10.0
            /// 节点连接权重
            public static let nodeLinkWeight: Double = 0.5
            /// 标签偏移量
            public static let labelOffset: Float = 2.0
            /// 标签缩放比例
            public static let labelScale: Float = 1.0
            public static let edgeRadius: CGFloat = 0.1
            public static let edgeRadiusHighlighted: CGFloat = 0.3
            public static let starRadius: CGFloat = 0.1
            public static let starFieldRadius: Float = 150.0
        }
    }
    
    /// 复合行模式规范
    public struct CompositeRow {
        public static let spacing: CGFloat = 10
        public static let cornerRadius: CGFloat = 12
        public static let iconBoxSize: CGFloat = 32
        public static let actionAreaWidth: CGFloat = 60
        public static let indicatorWidth: CGFloat = 30
    }
    
    /// 仪表盘与指标规范
    public struct Metrics {
        public static let heroValueSize: CGFloat = 32
        public static let subValueSize: CGFloat = 14
        public static let chartHeight: CGFloat = 220
        public static let boxHeight: CGFloat = 100
        public static let indicatorSize: CGFloat = 12
        public static let progressHeight: CGFloat = 6
        /// 下载进度环尺寸 (36pt)
        public static let ringSize: CGFloat = 36
        public static let boxAspectRatio: CGFloat = 1.0
        public static let dashboardValueSize: CGFloat = 32
        public static let dashboardLabelSize: CGFloat = 13
        public static let dashboardRadius: CGFloat = 20
        public static let iconBoxSize: CGFloat = 40
        public static let smallIconBoxSize: CGFloat = 28
        public static let largeIconBoxSize: CGFloat = 44
        public static let sourceCardWidth: CGFloat = 135
        public static let sourceCardHeight: CGFloat = 115
        public static let A4Width: CGFloat = 595
        public static let A4Height: CGFloat = 842
        public static let emptyStateVerticalPadding: CGFloat = 24
        public static let sectionSpacing: CGFloat = 24
        public static let maxTagCloudHeight: CGFloat = 300
        
        /// 安全锁定层缩放倍率 (0.95)
        public static let lockOverlayScaleMultiplier: CGFloat = 0.95
        /// 功能引导卡片进入缩放倍率 (0.9)
        public static let coachMarkScaleMultiplier: CGFloat = 0.9
        /// 启动页名言闪烁偏移量 (-200)
        public static let splashQuoteShimmerOffset: CGFloat = -200
        
        /// 指令面板标准高度 (488pt)
        public static let commandPaletteHeight: CGFloat = 488
        /// 功能引导图标缩放比例 (1.3)
        public static let coachMarkIconScale: CGFloat = 1.3
        /// 功能引导主要操作水平内边距 (40pt)
        public static let coachMarkActionHorizontalPadding: CGFloat = 40
        /// 功能引导卡片圆角偏移 (12pt)
        public static let coachMarkRadiusOffset: CGFloat = 12
        /// 功能引导阴影半径 (36pt)
        public static let coachMarkShadowRadius: CGFloat = 36
        /// 功能引导阴影 Y 轴偏移 (18pt)
        public static let coachMarkShadowY: CGFloat = 18
        
        /// 欢迎页装饰点阵宽度 (248pt)
        public static let welcomeHeroDotWidth: CGFloat = 248
        /// 欢迎页装饰点阵高度 (124pt)
        public static let welcomeHeroDotHeight: CGFloat = 124
        /// 欢迎页装饰圆环大小 (172pt)
        public static let welcomeHeroCircleSize: CGFloat = 172
        /// 欢迎页英雄图标大小 (88pt)
        public static let welcomeHeroIconSize: CGFloat = 88
        /// 统计卡片最小宽度 (196pt)
        public static let statCardMinWidth: CGFloat = 196

        /// 标题字体大小 (20px)
        public static let titleFontSize: CGFloat = 20
        /// 小型标题字体大小 (17px)
        public static let titleSmallFontSize: CGFloat = 17
        /// 最大面包屑层级
        public static let maxBreadcrumbCount: Int = 5
        /// 最大协作编辑历史记录
        public static let maxCollabEditHistory: Int = 50
        /// 协作编辑预览长度
        public static let maxCollabEditPreviewLength: Int = 100
        /// 知识增长天数限制
        public static let knowledgeGrowthDaysLimit: Int = 30
        /// 图谱引导触发阈值
        public static let graphCoachMarkThreshold: Int = 5
        /// 最大报告导出页面数
        public static let maxReportPageExportCount: Int = 20
        /// 报告内容预览长度
        public static let reportContentPreviewLength: Int = 200
        /// 报告内容行数限制
        public static let maxReportContentLineLimit: Int = 3
        /// 仪表盘最大项数
        public static let maxDashboardItems: Int = 8
        /// 最近记录最大项数
        public static let maxRecentItems: Int = 10
        /// 缺省页图标不透明度
        public static let emptyStateIconOpacity: CGFloat = 0.3
        
        /// macOS/Catalyst 最小窗口宽度 (800px)
        public static let minWindowWidth: CGFloat = 800
        /// macOS/Catalyst 最小窗口高度 (600px)
        public static let minWindowHeight: CGFloat = 600
        /// macOS/Catalyst 设置侧栏宽度 (240px)
        public static let settingsSidebarWidth: CGFloat = 240
        /// 设置图标背景框尺寸 (30px)
        public static let settingsIconFrameSize: CGFloat = 30
    }
    
    /// 任务管理中心规范
    public struct Task {
        public static let rowSpacing: CGFloat = 16
        public static let rowVerticalPadding: CGFloat = 4
        public static let iconBoxSize: CGFloat = 44
        public static let statusIndicatorSize: CGFloat = 10
        public static let badgeSize: CGFloat = 32
        public static let progressWidth: CGFloat = 40
        public static let dashboardSpacing: CGFloat = 12
        public static let dashboardPadding: CGFloat = 20
        public static let dashboardRadius: CGFloat = 20
    }
    
    /// 传统垂直列表规范
    public struct List {
        public static let rowVerticalPadding: CGFloat = 8
        public static let rowHorizontalPadding: CGFloat = 16
        public static let rowSpacing: CGFloat = 12
        public static let rowRadius: CGFloat = 12
    }
    
    /// 小型徽章规范
    public struct Chip {
        public static let horizontalPadding: CGFloat = 6
        public static let verticalPadding: CGFloat = 3
        public static let spacing: CGFloat = 8
        public static let iconSpacing: CGFloat = 4
        public static let cornerRadius: CGFloat = 6
    }
    
    /// 侧边菜单规范
    public struct Sidebar {
        public static let rowSpacing: CGFloat = 12
        public static let rowRadius: CGFloat = 8
        public static let rowVerticalPadding: CGFloat = 4
        public static let iconBoxSize: CGFloat = 28
        public static let iconFrameWidth: CGFloat = 24
        public static let badgePadding: CGFloat = 6
        
        /// 笔记本切换区域阴影半径
        public static let vaultShadowRadius: CGFloat = 5
        /// 笔记本切换区域阴影 Y 轴偏移
        public static let vaultShadowY: CGFloat = 3
        
        /// 侧边栏标准宽度
        public static let width: CGFloat = 280
        /// 返回按钮点击区域宽度
        public static let backButtonWidth: CGFloat = Action.backButtonWidth
    }
    
    /// 笔记本枢纽规范
    public struct Vault {
        public static let gridCardMin: CGFloat = 160
        public static let gridCardMax: CGFloat = 200
        public static let gridSpacing: CGFloat = 20
        public static let listSpacing: CGFloat = 12
        public static let cardHeight: CGFloat = 180
        public static let coverHeight: CGFloat = 100
        public static let listCoverSize: CGFloat = 44
        public static let homePadding: CGFloat = 16
        public static let homeVerticalPadding: CGFloat = 40
    }
    
    /// 视觉装饰模式规范 (Decorator)
    public struct Decorator {
        public static let shadowRadiusSmall: CGFloat = 8
        public static let shadowRadiusLarge: CGFloat = 12
        public static let shadowOffsetYSmall: CGFloat = 4
        public static let shadowOffsetYLarge: CGFloat = 6
        public static let accentLineWidth: CGFloat = 3
        public static let badgeMinSize: CGFloat = 20
        public static let desktopSheetMinWidth: CGFloat = 500
        public static let desktopSheetMinHeight: CGFloat = 600
        public static let glowBlurSmall: CGFloat = 4
        public static let glowBlurMedium: CGFloat = 8
        /// 中型发光缩放
        public static let glowScaleMedium: CGFloat = 1.2
        /// 大型发光缩放
        public static let glowScaleLarge: CGFloat = 1.5
        /// 呼吸缩放
        public static let pulseScale: CGFloat = 1.1
    }
    
    // MARK: - 5. 视觉风格常数 (Styling)
    
    /// 标准边框宽度
    public static let borderWidth: CGFloat = 0.8
    /// 标准阴影半径
    public static let shadowRadius: CGFloat = 10
    /// 标准阴影 Y 轴偏移
    public static let shadowY: CGFloat = 4
    /// 标准阴影不透明度
    public static let shadowOpacity: Double = 0.12
}
