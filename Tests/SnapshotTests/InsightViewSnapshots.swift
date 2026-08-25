//
//  InsightViewSnapshots.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：Features/Insight View 快照测试，覆盖 WeeklyInsightCard/InsightStat/
//           TagCloudSubViews(经 TagCloudViewContent)/PageHistoryView/SnapshotDetailView/
//           TagBubbleCloudCanvas/TagCloudMainContent(经 TagCloudViewContent)/
//           LintAISuggestionsPanel/RefactorSuggestionRow/PotentialLinkRow 等 0% 大文件，
//           验证默认状态与数据/交互状态的视觉一致性
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class InsightViewSnapshots: XCTestCase {

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

    // MARK: - 1. WeeklyInsightCard（WeeklyInsightCard.swift）

    /// 测试 WeeklyInsightCard 无洞察数据（空状态，显示生成报告按钮）的视觉一致性
    func testWeeklyInsightCardEmpty() {
        setupMockEnvironment()

        // AIInsightStore 默认 weeklyInsight 为 nil，呈现"生成报告"入口
        let view = WeeklyInsightCard()
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试 WeeklyInsightCard 有洞察数据（核心指标 + 摘要正文）状态的视觉一致性
    func testWeeklyInsightCardWithInsight() {
        setupMockEnvironment()

        let aiStore = AIInsightStore()
        aiStore.weeklyInsight = KnowledgeInsightService.WeeklyInsight(
            dateRange: "2026-08-18 至 2026-08-24",
            totalNewPages: 7,
            topKeywords: ["量子计算", "机器学习", "神经网络", "深度学习"],
            aiSummary: "本周新增 7 篇知识页面，聚焦于**量子计算**与**机器学习**两大主题。建议加强神经网络基础概念的梳理，并补充深度学习相关实践案例。",
            growthTraction: "+15%"
        )

        let view = WeeklyInsightCard()
            .snapshotEnvironment()
            .environment(aiStore) // snapshot_env_exempt: 覆盖默认空 AIInsightStore 以注入 weeklyInsight 测试数据
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 InsightStat 指标项组件默认状态的视觉一致性
    func testInsightStatDefault() {
        setupMockEnvironment()

        let view = InsightStat(
            label: L10n.Common.Stats.newPages,
            value: "12",
            icon: DesignSystem.Icons.docBadgePlus,
            color: .blue
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth / 2, height: DesignSystem.Metrics.iconBoxSize * 2)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth / 2, height: DesignSystem.Metrics.iconBoxSize * 2)))
    }

    // MARK: - 2. TagCloudSubViews（经 TagCloudViewContent 宿主覆盖）

    /// 测试 TagCloudViewContent 空标签状态（emptyTagsView 占位）的视觉一致性
    /// 覆盖 TagCloudSubViews.emptyTagsView 与 TagCloudMainContent.mainContent 空态分支
    func testTagCloudViewContentEmptyTags() {
        setupMockEnvironment()

        let view = NavigationStack {
            TagCloudViewContent()
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试 TagCloudViewContent 有标签数据状态的视觉一致性
    /// 覆盖 TagCloudSubViews.tagScrollView/expandCollapseButton 与 TagCloudMainContent 搜索卡/控制舱/标签云区
    func testTagCloudViewContentWithTags() {
        setupMockEnvironment()

        let coordinator = TagCloudCoordinator()
        coordinator.tags = [
            (tag: "Swift", count: 8),
            (tag: "量子计算", count: 5),
            (tag: "机器学习", count: 12),
            (tag: "神经网络", count: 3),
            (tag: "深度学习", count: 6),
            (tag: "RAG", count: 4),
            (tag: "知识图谱", count: 9),
            (tag: "向量数据库", count: 2),
            (tag: "Embedding", count: 7),
            (tag: "Prompt工程", count: 5),
            (tag: "LLM", count: 11),
            (tag: "Transformer", count: 4),
            (tag: "注意力机制", count: 3),
            (tag: "强化学习", count: 2)
        ]

        let view = NavigationStack {
            TagCloudViewContent()
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    // MARK: - 3. PageHistoryView（PageHistoryView.swift）

    /// 测试 PageHistoryView 无历史快照（空列表）状态的视觉一致性
    func testPageHistoryViewEmpty() {
        setupMockEnvironment()

        let page = KnowledgePage(
            title: "测试页面",
            pageType: .concept,
            content: "用于测试历史快照视图的页面内容"
        )

        let view = PageHistoryView(page: page)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试 SnapshotDetailView 快照详情视图的视觉一致性
    func testSnapshotDetailViewDefault() {
        setupMockEnvironment()

        // 构造临时快照文件，供 SnapshotDetailView 读取内容
        let tempDir = FileManager.default.temporaryDirectory
        let snapshotURL = tempDir.appendingPathComponent("snapshot-\(UUID().uuidString).md")
        let content = "# 版本快照内容\n\n这是历史快照保存的页面内容，用于对比与回滚。"
        try? content.write(to: snapshotURL, atomically: true, encoding: .utf8)

        let snapshot = SnapshotInfo(url: snapshotURL, date: Date(timeIntervalSince1970: 1_725_148_400))

        let view = SnapshotDetailView(snapshot: snapshot, onRollback: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    // MARK: - 4. TagBubbleCloudCanvas（TagBubbleCloudCanvas.swift）

    /// 测试 TagBubbleCloudCanvas 少量标签状态的视觉一致性
    func testTagBubbleCloudCanvasFewTags() {
        setupMockEnvironment()

        let coordinator = TagCloudCoordinator()
        coordinator.tags = [
            (tag: "Swift", count: 5),
            (tag: "AI", count: 8),
            (tag: "知识", count: 3)
        ]

        let view = TagBubbleCloudCanvas(coordinator: coordinator)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotGraphCanvasHeight * 2 / 3)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotGraphCanvasHeight * 2 / 3)))
    }

    /// 测试 TagBubbleCloudCanvas 多标签状态的视觉一致性
    func testTagBubbleCloudCanvasManyTags() {
        setupMockEnvironment()

        let coordinator = TagCloudCoordinator()
        coordinator.tags = [
            (tag: "Swift", count: 8),
            (tag: "量子计算", count: 5),
            (tag: "机器学习", count: 12),
            (tag: "神经网络", count: 3),
            (tag: "深度学习", count: 6),
            (tag: "RAG", count: 4),
            (tag: "知识图谱", count: 9),
            (tag: "向量数据库", count: 2),
            (tag: "Embedding", count: 7),
            (tag: "Prompt工程", count: 5),
            (tag: "LLM", count: 11),
            (tag: "Transformer", count: 4)
        ]

        let view = TagBubbleCloudCanvas(coordinator: coordinator)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 5. TagCloudMainContent（经 TagCloudViewContent 宿主覆盖）

    /// 测试 TagCloudViewContent 编辑模式（批量操作底栏）状态的视觉一致性
    /// 覆盖 TagCloudSubViews.bulkActionBar 与 TagCloudMainContent.unifiedToolbar 编辑态
    func testTagCloudViewContentEditMode() {
        setupMockEnvironment()

        let coordinator = TagCloudCoordinator()
        coordinator.tags = [
            (tag: "Swift", count: 8),
            (tag: "机器学习", count: 12),
            (tag: "深度学习", count: 6)
        ]
        coordinator.isEditMode = true
        coordinator.selectedTagsForBulk = ["Swift", "深度学习"]

        let view = NavigationStack {
            TagCloudViewContent()
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    // MARK: - 6. LintAISuggestionsPanel（LintRuleManager.swift）

    /// 测试 LintAISuggestionsPanel 无建议（空状态）的视觉一致性
    func testLintAISuggestionsPanelEmpty() {
        setupMockEnvironment()

        let aiStore = AIWorkflowStore()

        let view = LintAISuggestionsPanel(aiStore: aiStore)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试 LintAISuggestionsPanel 有重构建议与潜在链接的视觉一致性
    func testLintAISuggestionsPanelWithSuggestions() {
        setupMockEnvironment()

        let aiStore = AIWorkflowStore()
        aiStore.refactorSuggestions = [
            RefactorSuggestionDTO(
                type: "merge",
                target: "量子计算入门 / 量子计算基础",
                reason: "两篇页面内容高度重叠，主题一致，建议合并以减少冗余。",
                suggestion: "将「量子计算基础」内容并入「量子计算入门」，保留后者作为主页面。"
            ),
            RefactorSuggestionDTO(
                type: "split",
                target: "机器学习全景",
                reason: "页面篇幅过长，涵盖多个独立子主题，不利于检索与引用。",
                suggestion: "拆分为「监督学习」「无监督学习」「强化学习」三篇独立页面。"
            ),
            RefactorSuggestionDTO(
                type: "rename",
                target: "DL笔记",
                reason: "标题过于模糊，无法体现页面内容主题。",
                suggestion: "重命名为「深度学习核心笔记」。"
            )
        ]
        aiStore.potentialLinks = [
            PotentialLinkSuggestion(
                sourcePageID: UUID(),
                sourceTitle: "神经网络基础",
                targetTitle: "反向传播算法"
            ),
            PotentialLinkSuggestion(
                sourcePageID: UUID(),
                sourceTitle: "Transformer架构",
                targetTitle: "注意力机制"
            )
        ]

        let view = LintAISuggestionsPanel(aiStore: aiStore)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 RefactorSuggestionRow 重构建议行的视觉一致性
    func testRefactorSuggestionRowDefault() {
        setupMockEnvironment()

        let suggestion = RefactorSuggestionDTO(
            type: "merge",
            target: "量子计算入门 / 量子计算基础",
            reason: "两篇页面内容高度重叠，主题一致，建议合并以减少冗余。",
            suggestion: "将「量子计算基础」内容并入「量子计算入门」，保留后者作为主页面。"
        )

        let view = RefactorSuggestionRow(suggestion: suggestion)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize + DesignSystem.Metrics.snapshotSmallComponentSize / 2)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize + DesignSystem.Metrics.snapshotSmallComponentSize / 2)))
    }

    /// 测试 PotentialLinkRow 潜在链接行的视觉一致性
    func testPotentialLinkRowDefault() {
        setupMockEnvironment()

        let link = PotentialLinkSuggestion(
            sourcePageID: UUID(),
            sourceTitle: "神经网络基础",
            targetTitle: "反向传播算法"
        )

        let view = PotentialLinkRow(link: link)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotNotebookRowHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotNotebookRowHeight)))
    }
}
