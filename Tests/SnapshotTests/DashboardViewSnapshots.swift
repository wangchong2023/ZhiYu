//
//  DashboardViewSnapshots.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：仪表盘 Dashboard View 子组件的快照测试，覆盖 PageDetailHeader、PageDetailContentSection、
//           4 种 PageType 差异化 BodyView（Entity/Concept/Comparison/Source）、PageDetailMetadataSection。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class DashboardViewSnapshots: XCTestCase {

    /// 依据环境变量判断快照录制策略
    private static var recordMode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
    }

    override func invokeTest() {
        withSnapshotTesting(record: Self.recordMode) {
            super.invokeTest()
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 测试数据工厂

    /// 构造 Entity 类型测试页面（含 frontmatter）
    private func makeEntityPage() -> KnowledgePage {
        let frontmatter = """
        ---
        pronunciation: "ˈiːn.tɪ.ti"
        definition: "实体是知识图谱中可标识、可区分的独立对象或概念单元"
        aliases: ["条目", "词条", "Entry"]
        infobox:
          - key: "类别"
            value: "知识本体"
          - key: "粒度"
            value: "原子级"
          - key: "示例"
            value: "人物、地点、事件"
        overview:
          - "实体是知识管理的基本单元"
          - "每个实体具有唯一标识符和属性集合"
        ---
        """
        let body = "# 实体详情\n\n这是实体的**详细内容**，用于验证排版。\n\n## 属性\n\n- 唯一性\n- 可标识性\n- 可区分性"
        return KnowledgePage(
            title: "测试实体",
            pageType: .entity,
            content: frontmatter + "\n" + body,
            aliases: ["条目", "Entry"],
            tags: ["知识管理", "本体"],
            confidence: .high
        )
    }

    /// 构造 Concept 类型测试页面（含 frontmatter）
    private func makeConceptPage() -> KnowledgePage {
        let frontmatter = """
        ---
        outlines:
          - id: "1"
            title: "核心定义"
            level: 1
            associated_page_id: null
          - id: "2"
            title: "应用场景"
            level: 2
            associated_page_id: null
        surprising_insights:
          - insight_title: "概念间的涌现性"
            linked_concept_id: "concept-002"
            reason: "多个简单概念组合后产生不可预测的新特性"
        ---
        """
        let body = "# 主题详情\n\n这是主题的**详细内容**，包含知识脉络树和认知碰撞卡。"
        return KnowledgePage(
            title: "测试主题",
            pageType: .concept,
            content: frontmatter + "\n" + body,
            tags: ["主题", "脑图"],
            confidence: .medium
        )
    }

    /// 构造 Comparison 类型测试页面（含 frontmatter）
    private func makeComparisonPage() -> KnowledgePage {
        let frontmatter = """
        ---
        subjects:
          - id: "a"
            name: "方案 A"
            logo_asset: null
          - id: "b"
            name: "方案 B"
            logo_asset: null
        dimensions:
          - id: "perf"
            name: "性能"
            type: "rating"
            unit: "星"
          - id: "cost"
            name: "成本"
            type: "range"
            unit: "元"
          - id: "desc"
            name: "描述"
            type: "text"
            unit: null
        matrix:
          - subject_id: "a"
            dimension_id: "perf"
            value:
              text: null
              rating: 4.5
              range: null
              image_list: null
          - subject_id: "b"
            dimension_id: "perf"
            value:
              text: null
              rating: 3.0
              range: null
              image_list: null
          - subject_id: "a"
            dimension_id: "cost"
            value:
              text: null
              rating: null
              range:
                min: 100
                max: 500
              image_list: null
          - subject_id: "b"
            dimension_id: "cost"
            value:
              text: null
              rating: null
              range:
                min: 200
                max: 800
              image_list: null
          - subject_id: "a"
            dimension_id: "desc"
            value:
              text: "高性能方案"
              rating: null
              range: null
              image_list: null
          - subject_id: "b"
            dimension_id: "desc"
            value:
              text: "经济型方案"
              rating: null
              range: null
              image_list: null
        ---
        """
        let body = "# 对比分析\n\n这是**多方案对比**的详细分析内容。"
        return KnowledgePage(
            title: "测试对比",
            pageType: .comparison,
            content: frontmatter + "\n" + body,
            tags: ["对比", "决策"],
            confidence: .high
        )
    }

    /// 构造 Source 类型测试页面（含 frontmatter，音频类型）
    private func makeSourcePage() -> KnowledgePage {
        let frontmatter = """
        ---
        type: "voice"
        file_name: "录音_001.m4a"
        file_size: 102400
        voice_amplitude_waveform: [0.15, 0.45, 0.72, 0.88, 0.52, 0.22, 0.65, 0.81, 0.35, 0.12]
        transcription: "这是语音转文字的转录内容"
        extracted_page_ids:
          - page_id: "page-001"
            name: "提取概念 1"
            type: "concept"
        ---
        """
        let body = "# 来源详情\n\n这是**语音来源**的转录内容，用于验证音频载体排版。"
        return KnowledgePage(
            title: "测试来源",
            pageType: .source,
            content: frontmatter + "\n" + body,
            tags: ["语音", "转录"],
            confidence: .low,
            sourceURL: "file://localhost/test.m4a",
            sourceType: "voice"
        )
    }

    /// 构造 Raw 类型测试页面（无 frontmatter）
    private func makeRawPage() -> KnowledgePage {
        KnowledgePage(
            title: "测试原始页面",
            pageType: .raw,
            content: "# 原始 Markdown\n\n这是**纯 Markdown** 内容，不经过类型化排版。\n\n- 列表项 1\n- 列表项 2",
            tags: ["原始"]
        )
    }

    // MARK: - PageDetailHeader

    /// 测试页面详情头部 — Entity 类型，高置信度，含标签和别名
    func testPageDetailHeader_EntityType_HighConfidence() {
        let page = makeEntityPage()
        let view = PageDetailHeader(page: page)
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试页面详情头部 — Concept 类型，中置信度
    func testPageDetailHeader_ConceptType_MediumConfidence() {
        let page = makeConceptPage()
        let view = PageDetailHeader(page: page)
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试页面详情头部 — 置顶页面
    func testPageDetailHeader_PinnedPage() {
        let page = KnowledgePage(
            title: "置顶测试页面",
            pageType: .concept,
            content: "# 置顶内容",
            tags: ["重要"],
            isPinned: true
        )
        let view = PageDetailHeader(page: page)
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - PageDetailContentSection

    /// 测试内容区 — 编辑模式
    /// 注意：编辑模式使用 MarkdownEditorView，后者通过 OCRPickerModifier 间接依赖
    /// @Environment(IngestStore.self)，需注入 IngestStore 实例。
    func testPageDetailContentSection_EditingMode() {
        var page = makeRawPage()
        let view = PageDetailContentSection(
            page: .constant(page),
            isEditing: .constant(true),
            onLinkTap: { _ in }
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
        _ = page
    }

    /// 测试内容区 — 编辑模式（IngestStore 缺失降级路径）
    /// 验证 S9-19 根治：IngestStore 未注入时 MarkdownEditorView 不崩溃，OCR 按钮禁用。
    func testPageDetailContentSection_EditingMode_NoIngestStoreFallback() {
        let page = makeRawPage()
        let view = PageDetailContentSection(
            page: .constant(page),
            isEditing: .constant(true),
            onLinkTap: { _ in }
        )
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试内容区 — 空状态
    func testPageDetailContentSection_EmptyState() {
        let page = KnowledgePage(title: "空页面", pageType: .concept, content: "")
        let view = PageDetailContentSection(
            page: .constant(page),
            isEditing: .constant(false),
            onLinkTap: { _ in }
        )
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试内容区 — Raw 类型（直接 MarkdownRendererView）
    /// 注意：MarkdownRendererView 依赖 @Environment(AppStore.self)，需注入 AppStore
    func testPageDetailContentSection_RawType() {
        let page = makeRawPage()
        let view = PageDetailContentSection(
            page: .constant(page),
            isEditing: .constant(false),
            onLinkTap: { _ in }
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - EntityDetailBodyView

    /// 测试词条详情 — 含 frontmatter（释义板 + InfoBox + 概述）
    /// 注意：EntityDetailBodyView 内部使用 MarkdownRendererView，需注入 AppStore
    func testEntityDetailBodyView_WithFrontmatter() {
        let page = makeEntityPage()
        let view = EntityDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试词条详情 — 无 frontmatter（纯 Markdown 回退）
    func testEntityDetailBodyView_NoFrontmatter() {
        let page = KnowledgePage(
            title: "纯文本词条",
            pageType: .entity,
            content: "# 纯文本词条\n\n这是不含 frontmatter 的词条内容。"
        )
        let view = EntityDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - ConceptDetailBodyView

    /// 测试主题详情 — 含 frontmatter（脑图 + 认知碰撞卡 + 脉络树）
    /// 注意：ConceptDetailBodyView 内部使用 MarkdownRendererView，需注入 AppStore
    func testConceptDetailBodyView_WithFrontmatter() {
        let page = makeConceptPage()
        let view = ConceptDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - ComparisonDetailBodyView

    /// 测试对比详情 — 含 frontmatter（矩阵网格 + 评分 + 区间）
    /// 注意：ComparisonDetailBodyView 内部使用 MarkdownRendererView，需注入 AppStore
    func testComparisonDetailBodyView_WithFrontmatter() {
        let page = makeComparisonPage()
        let view = ComparisonDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - SourceDetailBodyView

    /// 测试来源详情 — 语音类型（波形图 + 转录）
    /// 注意：SourceDetailBodyView 内部使用 MarkdownRendererView，需注入 AppStore
    func testSourceDetailBodyView_VoiceType() {
        let page = makeSourcePage()
        let view = SourceDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - PageDetailMetadataSection

    /// 测试元数据区 — 含来源 URL、回链和推荐
    func testPageDetailMetadataSection_WithBacklinksAndRecommendations() {
        let page = KnowledgePage(
            title: "元数据测试页面",
            pageType: .concept,
            content: "# 内容",
            sourceURL: "https://example.com/source-article"
        )
        let backlinks = [
            KnowledgePage(title: "回链页面 1", pageType: .entity, content: "引用了测试页面"),
            KnowledgePage(title: "回链页面 2", pageType: .concept, content: "关联讨论")
        ]
        let recommendations = [
            KnowledgePage(title: "推荐页面 1", pageType: .entity, content: "语义相关"),
            KnowledgePage(title: "推荐页面 2", pageType: .source, content: "延伸阅读")
        ]

        let view = PageDetailMetadataSection(
            page: page,
            backlinks: backlinks,
            recommendations: recommendations
        )
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试元数据区 — 无来源 URL、无回链、无推荐
    func testPageDetailMetadataSection_EmptyState() {
        let page = KnowledgePage(title: "无元数据页面", pageType: .concept, content: "# 内容")

        let view = PageDetailMetadataSection(
            page: page,
            backlinks: [],
            recommendations: []
        )
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}
