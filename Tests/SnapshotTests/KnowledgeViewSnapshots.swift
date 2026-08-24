//
//  KnowledgeViewSnapshots.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：Features/Knowledge View 快照测试，覆盖 SearchSheets/GraphInfoPanel/Graph3DComponents/
//           NotebookFormSheet/VoiceAudioPlayerView/PDFComponents/FormattedMarkdownText/
//           ZoomableOCRImageView/PDFReaderView 等 0% 大文件，验证视觉一致性
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class KnowledgeViewSnapshots: XCTestCase {

    /// 保存原始语言模式，在 tearDown 中恢复
    private var originalLanguageMode: LanguageMode?

    /// 依据环境变量判断快照录制策略，用于支持 CI/CD 脚本自动更新基准图片
    private static var recordMode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
    }

    override func invokeTest() {
        withSnapshotTesting(record: Self.recordMode) {
            super.invokeTest()
        }
    }

    override func tearDown() async throws {
        if let original = originalLanguageMode {
            Localized.languageMode = original
        }
        try await super.tearDown()
    }

    /// 统一配置 Mock 测试环境并控制快照录制模式
    private func setupMockEnvironment() {
        setupFullMockEnvironment()

        // 强制中文环境，确保快照文本一致性，避免语言环境漂移导致快照不匹配
        if originalLanguageMode == nil {
            originalLanguageMode = Localized.languageMode
        }
        Localized.languageMode = .chinese

        // 清理聊天历史，防止其他测试的残留数据污染快照测试
        ChatService.shared.clearHistory()
    }

    // MARK: - 1. PagePreviewSheet（SearchSheets.swift）

    /// 测试 PagePreviewSheet 完整数据状态的视觉一致性
    func testPagePreviewSheetFullData() {
        setupMockEnvironment()

        let page = KnowledgePage(
            title: "量子纠缠现象详解",
            pageType: .concept,
            content: "量子纠缠是量子力学中的一种现象，两个或多个粒子之间存在关联...",
            tags: ["物理", "量子力学", "前沿科学"],
            status: .active,
            confidence: .high
        )

        let view = NavigationStack {
            PagePreviewSheet(page: page)
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 PagePreviewSheet 极简数据（无标签、无内容）状态
    func testPagePreviewSheetMinimalData() {
        setupMockEnvironment()

        let page = KnowledgePage(
            title: "空白笔记",
            pageType: .raw,
            content: "",
            tags: [],
            status: .stub,
            confidence: .low
        )

        let view = NavigationStack {
            PagePreviewSheet(page: page)
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. SearchDiagnosticSheet（SearchSheets.swift）

    /// 测试 SearchDiagnosticSheet 默认数据状态的视觉一致性
    func testSearchDiagnosticSheetDefault() {
        setupMockEnvironment()

        let info = SearchDiagnosticInfo(
            query: "量子计算基础",
            rewrittenQuery: "量子计算 基础原理 入门",
            ftsCount: 12,
            vectorCount: 8,
            rrfTopResults: [
                SearchDiagnosticInfo.ResultScore(id: UUID(), title: "量子计算入门指南", ftsRank: 1, vectorRank: 2, finalScore: 0.92),
                SearchDiagnosticInfo.ResultScore(id: UUID(), title: "量子比特原理", ftsRank: 2, vectorRank: 1, finalScore: 0.88),
                SearchDiagnosticInfo.ResultScore(id: UUID(), title: "量子门操作", ftsRank: 3, vectorRank: 4, finalScore: 0.75)
            ]
        )

        let view = NavigationStack {
            SearchDiagnosticSheet(info: info)
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 SearchDiagnosticSheet 空结果状态
    func testSearchDiagnosticSheetEmptyResults() {
        setupMockEnvironment()

        let info = SearchDiagnosticInfo(
            query: "无匹配内容",
            rewrittenQuery: "无匹配内容",
            ftsCount: 0,
            vectorCount: 0,
            rrfTopResults: []
        )

        let view = NavigationStack {
            SearchDiagnosticSheet(info: info)
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 3. GraphSelectedNodeCard（GraphInfoPanel.swift）

    /// 测试 GraphSelectedNodeCard 默认状态的视觉一致性
    func testGraphSelectedNodeCardDefault() {
        setupMockEnvironment()

        let page = KnowledgePage(
            title: "机器学习基础概念",
            pageType: .concept,
            content: "机器学习是人工智能的一个分支...",
            tags: ["AI", "ML"]
        )

        let view = GraphSelectedNodeCard(page: page)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 120)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 120)))
    }

    // MARK: - 4. GraphInsightsPanel（GraphInfoPanel.swift）

    /// 测试 GraphInsightsPanel 有数据状态的视觉一致性
    func testGraphInsightsPanelWithData() {
        setupMockEnvironment()

        let nodes: [GraphNode] = [
            GraphNode(id: UUID(), title: "概念A", pageType: .concept, position: CGPoint(x: 100, y: 100)),
            GraphNode(id: UUID(), title: "实体B", pageType: .entity, position: CGPoint(x: 200, y: 200)),
            GraphNode(id: UUID(), title: "来源C", pageType: .source, position: CGPoint(x: 300, y: 300))
        ]
        let surprising = [nodes[0].id, nodes[1].id]
        let orphans: [UUID] = [nodes[2].id]
        let sparse: [UUID] = []
        let bridges: [UUID] = [nodes[0].id]

        let view = GraphInsightsPanel(
            surprising: surprising,
            orphans: orphans,
            sparse: sparse,
            bridges: bridges,
            nodes: nodes,
            onSelectNode: { _ in }
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 GraphInsightsPanel 空状态（无任何洞察数据）
    func testGraphInsightsPanelEmpty() {
        setupMockEnvironment()

        let view = GraphInsightsPanel(
            surprising: [],
            orphans: [],
            sparse: [],
            bridges: [],
            nodes: [],
            onSelectNode: { _ in }
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 5. GraphConceptGuideSheet（GraphInfoPanel.swift）

    /// 测试 GraphConceptGuideSheet 概念指南弹窗的视觉一致性
    func testGraphConceptGuideSheetDefault() {
        setupMockEnvironment()

        let view = NavigationStack {
            GraphConceptGuideSheet()
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    // MARK: - 6. Graph3DControlsOverlay（Graph3DComponents.swift）

    /// 测试 Graph3DControlsOverlay 非全屏状态的视觉一致性
    func testGraph3DControlsOverlayNotFullScreen() {
        setupMockEnvironment()

        var autoRotate = false
        var filterType: PageType?
        var isFullScreen = false
        var hideControls = false

        let view = Graph3DControlsOverlay(
            autoRotate: Binding(get: { autoRotate }, set: { autoRotate = $0 }),
            filterType: Binding(get: { filterType }, set: { filterType = $0 }),
            isFullScreen: Binding(get: { isFullScreen }, set: { isFullScreen = $0 }),
            hideControls: Binding(get: { hideControls }, set: { hideControls = $0 }),
            onAutoRotateToggle: {},
            onResetCamera: {},
            onZoomIn: {},
            onZoomOut: {}
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight, alignment: .topTrailing)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试 Graph3DControlsOverlay 全屏状态的视觉一致性
    func testGraph3DControlsOverlayFullScreen() {
        setupMockEnvironment()

        var autoRotate = true
        var filterType: PageType? = .concept
        var isFullScreen = true
        var hideControls = false

        let view = Graph3DControlsOverlay(
            autoRotate: Binding(get: { autoRotate }, set: { autoRotate = $0 }),
            filterType: Binding(get: { filterType }, set: { filterType = $0 }),
            isFullScreen: Binding(get: { isFullScreen }, set: { isFullScreen = $0 }),
            hideControls: Binding(get: { hideControls }, set: { hideControls = $0 }),
            onAutoRotateToggle: {},
            onResetCamera: {},
            onZoomIn: {},
            onZoomOut: {}
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight, alignment: .topTrailing)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 7. Graph3DNodeInfoBar（Graph3DComponents.swift）

    /// 测试 Graph3DNodeInfoBar 默认状态的视觉一致性
    func testGraph3DNodeInfoBarDefault() {
        setupMockEnvironment()

        let page = KnowledgePage(
            title: "深度学习神经网络",
            pageType: .concept,
            content: "深度学习是机器学习的一个分支..."
        )

        let view = Graph3DNodeInfoBar(page: page, onViewPage: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)))
    }

    // MARK: - 8. NotebookFormSheet（NotebookFormSheet.swift）

    /// 测试 NotebookFormSheet 创建模式（空表单）的视觉一致性
    func testNotebookFormSheetCreateMode() {
        setupMockEnvironment()

        var name = ""
        var icon = "📓"
        var description = ""

        let view = NavigationStack {
            NotebookFormSheet(
                title: L10n.Vault.new,
                submitLabel: L10n.Common.create,
                name: Binding(get: { name }, set: { name = $0 }),
                icon: Binding(get: { icon }, set: { icon = $0 }),
                description: Binding(get: { description }, set: { description = $0 }),
                onSubmit: {}
            )
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 NotebookFormSheet 编辑模式（有数据）的视觉一致性
    func testNotebookFormSheetEditMode() {
        setupMockEnvironment()

        var name = "研究笔记"
        var icon = "🔬"
        var description = "存放研究相关的知识卡片"

        let view = NavigationStack {
            NotebookFormSheet(
                title: L10n.Vault.edit,
                submitLabel: L10n.Common.save,
                name: Binding(get: { name }, set: { name = $0 }),
                icon: Binding(get: { icon }, set: { icon = $0 }),
                description: Binding(get: { description }, set: { description = $0 }),
                onSubmit: {}
            )
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    // MARK: - 9. VoiceAudioPlayerView（VoiceAudioPlayerView.swift）

    /// 测试 VoiceAudioPlayerView 有转写文本状态的视觉一致性
    func testVoiceAudioPlayerViewWithTranscription() {
        setupMockEnvironment()

        let view = VoiceAudioPlayerView(
            title: "项目讨论录音",
            audioPath: nil,
            transcribedText: "[00:00] 今天讨论一下项目进度。[00:15] 后端 API 已完成 80%。[00:30] 前端需要加快速度。"
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 VoiceAudioPlayerView 空转写文本状态
    func testVoiceAudioPlayerViewEmptyTranscription() {
        setupMockEnvironment()

        let view = VoiceAudioPlayerView(
            title: "空白录音",
            audioPath: nil,
            transcribedText: ""
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 10. FormattedMarkdownText（FormattedMarkdownText.swift）

    /// 测试 FormattedMarkdownText 完整 Markdown 格式的视觉一致性
    func testFormattedMarkdownTextFullFormat() {
        setupMockEnvironment()

        let markdownText = """
        # 一级标题

        这是一段普通段落文本，用于测试基础排版。

        ## 二级标题

        - 列表项一
        - 列表项二
        - 列表项三

        ### 三级标题

        > 这是一段引用文本。

        `inline code` 示例。

        | 列1 | 列2 | 列3 |
        |:---|:---:|---:|
        | A | B | C |
        | D | E | F |
        """

        let view = FormattedMarkdownText(text: markdownText)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 FormattedMarkdownText 空文本状态
    func testFormattedMarkdownTextEmpty() {
        setupMockEnvironment()

        let view = FormattedMarkdownText(text: "")
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)))
    }

    // MARK: - 11. ZoomableOCRImageView（ZoomableOCRImageView.swift）

    /// 测试 ZoomableOCRImageView 默认状态的视觉一致性
    func testZoomableOCRImageViewDefault() {
        setupMockEnvironment()

        // 构造纯色测试图片，避免依赖外部资源
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 300))
        let image = renderer.image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 300))
            UIColor.white.setFill()
            context.cgContext.fill(CGRect(x: 20, y: 20, width: 160, height: 40))
        }

        let view = ZoomableOCRImageView(image: image)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 12. PDFDocumentRow（PDFComponents.swift）

    /// 测试 PDFDocumentRow 完整数据状态的视觉一致性
    func testPDFDocumentRowFullData() {
        setupMockEnvironment()

        let doc = PDFDocumentInfo(
            title: "深度学习论文合集",
            fileName: "deep_learning_papers.pdf",
            pageCount: 156,
            highlights: [
                PDFHighlight(pageIndex: 0, text: "重要结论", color: "yellow"),
                PDFHighlight(pageIndex: 5, text: "关键公式", color: "green")
            ],
            linkedPageTitles: ["深度学习基础"]
        )

        let view = PDFDocumentRow(doc: doc)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)))
    }

    /// 测试 PDFDocumentRow 无高亮数据状态
    func testPDFDocumentRowNoHighlights() {
        setupMockEnvironment()

        let doc = PDFDocumentInfo(
            title: "空白 PDF 文档",
            fileName: "blank.pdf",
            pageCount: 1,
            highlights: []
        )

        let view = PDFDocumentRow(doc: doc)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)))
    }

    // MARK: - 13. PDFIngestSheet（PDFComponents.swift）

    /// 测试 PDFIngestSheet 默认状态的视觉一致性
    func testPDFIngestSheetDefault() {
        setupMockEnvironment()

        let doc = PDFDocumentInfo(
            title: "研究报告",
            fileName: "report.pdf",
            pageCount: 42
        )
        let ingestStore = IngestStore()

        let view = NavigationStack {
            PDFIngestSheet(documentInfo: doc, ingestStore: ingestStore, pdfDocument: nil)
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }
}
