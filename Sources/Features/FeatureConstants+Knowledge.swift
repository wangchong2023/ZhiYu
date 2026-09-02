//
//  FeatureConstants+Knowledge.swift
//  ZhiYu
//
//  系统层级：[L2] 业务功能层
//  核心职责：Features 模块知识摄入、图谱、Lint、RAG 评估相关强类型常量。
//

import Foundation
import UFPCore

// MARK: - 知识管理相关常量
extension FeatureConstants {

    // MARK: - Lint 动作 (Lint Action)
    /// 知识 lint 修复动作字符串键
    enum LintAction {
        static let merge: String = "merge"
        static let split: String = "split"
        static let rename: String = "rename"
    }

    // MARK: - Graph 洞察类型 (Graph Insight Type)
    /// 图谱洞察类型字符串键，用于 switch case 匹配
    enum GraphInsightType {
        static let surprising: String = "surprising"
        static let orphans: String = "orphans"
        static let sparse: String = "sparse"
        static let bridges: String = "bridges"
    }

    // MARK: - 导入状态 (Import Status)
    /// 导入记录状态字符串键
    enum ImportStatus {
        static let done: String = "done"
    }

    // MARK: - 来源类型 (Source Type)
    /// 知识来源类型字符串常量，消除 type == "voice" 等魔鬼字符串
    enum SourceType {
        static let voice = "voice"
        static let ocr = "ocr"
        static let audio = "audio"
        static let file = "file"
        static let link = "link"
        static let concept = "concept"
        static let entity = "entity"
        static let source = "source"
        static let map = "map"
        static let notebook = "notebook"
        static let pen = "pen"
        static let manual = "manual"

        /// Widget 默认来源分布比例（source 40% / concept 30% / entity 20% / map 10%）
        static let defaultWidgetDistribution: [String: Double] = [
            source: 0.4, concept: 0.3, entity: 0.2, map: 0.1
        ]
    }

    // MARK: - 场景节点名 (Scene Node Name)
    /// SceneKit 3D 场景节点名常量
    enum SceneNode {
        static let mainCamera = "mainCamera"
    }

    // MARK: - 分类筛选 (Category Filter)
    /// 导入记录分类筛选标签
    enum CategoryFilter {
        static let all = "all"
    }

    // MARK: - 标签前缀 (Tag Prefix)
    /// 标签展示前缀
    enum TagPrefix {
        static let hash = "#"
    }

    // MARK: - 页面详情元数据 (Page Detail Metadata)
    /// 推荐页摘要截断长度
    enum PageDetailMetadata {
        static let summaryPrefixLength: Int = 60
    }

    // MARK: - Lint 健康评分阈值 (Lint Health Threshold)
    /// LintService 健康评分扣分权重与等级阈值
    enum LintHealthThreshold {
        static let errorDeduction: Int = 10
        static let warningDeduction: Int = 5
        static let infoDeduction: Int = 2
        static let baseScore: Int = 100
        static let excellentScore: Int = 90
        static let goodScore: Int = 75
        static let fairScore: Int = 50
        static let progressMax: Double = 100.0
    }

    // MARK: - 六角蜂窝网格 (Hex Spiral Grid)
    /// HexSpiralCalculator 蜂窝网格算法参数
    enum HexSpiral {
        static let directionCount: Int = 6
        static let physicalYScale: Double = 1.5
        static let physicalXRDivisor: Double = 2.0
    }

    // MARK: - 标签气泡云 (Tag Bubble Cloud)
    /// 标签气泡云视图缩放与透明度参数
    enum TagBubbleCloud {
        static let countBadgeFontScale: Double = 0.75
        static let canvasHalfDivisor: Double = 2.0
        static let cosineInterpolatorDivisor: Double = 2.0
        static let capsuleCountFontScale: Double = 0.8
        static let capsuleCountVerticalPadding: Double = 0.5
        static let capsuleBubbleRatioThreshold: Double = 0.5
        static let capsuleShadowOpacityFactor: Double = 0.08
        static let capsuleShadowRadius: CGFloat = 2
        static let capsuleShadowY: CGFloat = 1
    }

    // MARK: - Vault 图表占位 (Vault Chart Placeholder)
    /// VaultInsightsPanel 占位曲线控制点比例
    enum VaultChartPlaceholder {
        static let startHeightRatio: Double = 0.7
        static let endHeightRatio: Double = 0.3
        static let control1WidthRatio: Double = 0.4
        static let control1HeightRatio: Double = 0.9
        static let control2WidthRatio: Double = 0.6
        static let control2HeightRatio: Double = 0.1
    }

    // MARK: - RAG 评估 (RAG Evaluation)
    /// RAG 评估历史默认天数
    enum RAGEvaluation {
        static let defaultSelectedDays: Int = 30
    }

    // MARK: - RAG 评估时间范围 (RAG Eval Time Range)
    /// RAGTimeRangePicker 可选时间窗口（天）
    enum RAGEvalTimeRange {
        /// 短期：7 天
        static let shortDays: Int = 7
        /// 中期：30 天
        static let mediumDays: Int = 30
        /// 长期：90 天
        static let longDays: Int = 90
    }

    // MARK: - 图谱聚类 (Graph Clustering)
    /// GraphClusteringService K-Means 聚类参数
    enum GraphClustering {
        static let defaultK: Int = 5
        static let maxIterations: Int = 10
    }

    // MARK: - 图谱洞察检测 (Graph Insight Detection)
    /// GraphInsightDetection 桥接节点最小连接社区数
    enum GraphInsightDetection {
        static let minBridgeCommunityCount: Int = 3
    }

    // MARK: - 图谱组件缩放 (Graph Components Scale)
    /// GraphComponents 节点尺寸缩放因子
    enum GraphComponentsScale {
        static let linkCountSizeFactor: CGFloat = 1.5
        static let auraSizeMultiplier: CGFloat = 2.2
    }

    // MARK: - 摄入限制 (Ingest Limit)
    /// IngestService 原始片段截取长度
    enum IngestLimit {
        static let rawSnippetLength: Int = 500
        static let urlRawSnippetLength: Int = 1000
    }

    // MARK: - 摄入网格 (Ingest Grid)
    /// IngestEntryCardsSection 响应式网格列数与尺寸倍数
    enum IngestGrid {
        static let regularColumns: Int = 5
        static let flexibleMinMultiplier: CGFloat = 3
        static let flexibleMaxMultiplier: CGFloat = 7
    }

    // MARK: - OCR 扫描 (OCR Scan)
    /// OCRScanView 标题预填长度
    enum OCRScan {
        static let titlePrefixLength: Int = 20
    }

    // MARK: - 命令面板 (Command Palette)
    /// CommandPaletteView 最近访问展示数量
    enum CommandPalette {
        static let recentAccessCount: Int = 3
    }

    // MARK: - 搜索视图 (Search View)
    /// SearchView 骨架屏行数与空状态图标缩放
    enum SearchView {
        static let skeletonRowCount: Int = 6
        static let emptyIconSizeMultiplier: CGFloat = 1.5
    }

    // MARK: - 知识库引导 (Knowledge Coach Mark)
    /// KnowledgeStore 图谱引导触发最小页面数
    enum KnowledgeCoachMark {
        static let minPagesForGraphCoachMark: Int = 3
    }

    // MARK: - 笔记本洞察面板 (Vault Insights Panel)
    /// VaultInsightsPanel 分类分布柱状图相对高度比例
    /// Bug #104 修复：抽取硬编码 0.6/0.8/0.4/0.2/0.05 为强类型常量
    enum VaultInsightsBarRatio {
        static let entity: Double = 0.6
        static let concept: Double = 0.8
        static let source: Double = 0.4
        static let comparison: Double = 0.2
        static let raw: Double = 0.05
    }

    // MARK: - 插件描述 (Plugin Description)
    /// 插件详情描述折叠阈值
    enum PluginDescription {
        static let expandLineThreshold: Int = 5
        static let collapsedMaxHeight: CGFloat = 180
    }

    // MARK: - 笔记本创建按钮 (Create Notebook Button)
    /// 虚线边框 dash pattern（dash 4pt, gap 4pt）
    enum DashedBorder {
        static let dashLength: CGFloat = 4
        static let gapLength: CGFloat = 4
        static let pattern: [CGFloat] = [dashLength, gapLength]
    }
}
