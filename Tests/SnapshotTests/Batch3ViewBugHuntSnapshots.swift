//
//  Batch3ViewBugHuntSnapshots.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：批次3 低覆盖 View 快照测试 — 以发现源码缺陷为目的，覆盖
//           QuizView / ConceptDetailBodyView / SourceDetailBodyView /
//           ComparisonDetailBodyView / EntityDetailBodyView / MedalCard /
//           MedalRewardPopup / SubscriptionPlanCard / CollaborationComponents /
//           NotebookCoverView，
//           针对边界值、异常输入、状态组合设计用例。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class Batch3ViewBugHuntSnapshots: XCTestCase {

    /// 保存原始语言模式，在 tearDown 中恢复
    private var originalLanguageMode: LanguageMode?

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
        if originalLanguageMode == nil {
            originalLanguageMode = Localized.languageMode
        }
        Localized.languageMode = .chinese
    }

    override func tearDown() async throws {
        if let original = originalLanguageMode {
            Localized.languageMode = original
        }
        try await super.tearDown()
    }

    // MARK: - 1. QuizView（知识测评视图）

    /// TC-B3-01: QuizView 初始状态 — 第一题未作答
    /// 目的：验证 2 题 QuizModel 的初始渲染（进度条 1/2，score 0），
    ///       同时检测 L10n.Quiz.questionFormat / scoreFormat 在中文模式下的格式化输出
    func testQuizViewInitialTwoQuestions() {
        let quiz = QuizModel(title: "批次3测评", questions: [
            QuizQuestion(id: 0, text: "智宇底层存储依赖哪个框架？", options: ["GRDB", "CoreData", "Realm"], answer: 0, explanation: "采用 GRDB.swift 驱动 SQLite + FTS5。"),
            QuizQuestion(id: 1, text: "RAG 闭环的入口是？", options: ["语义分块", "UI 渲染", "网络请求"], answer: 0, explanation: "语义分块是 RAG 闭环的第一步。")
        ])

        let view = QuizView(quiz: quiz)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-02: QuizView 空题目边界 — questions 为空数组
    /// 目的：验证 questions=[] 时的渲染行为，
    ///       潜在 Bug：currentIndex=0 时 `quiz.questions[currentIndex].text` 越界访问空数组导致崩溃；
    ///                 且 ProgressView(value: 1, total: 0) 存在除零风险。
    ///       若源码未做空数组守卫，此用例将触发 fatal error 暴露缺陷。
    func testQuizViewEmptyQuestionsBoundary() {
        let quiz = QuizModel(title: "空题目边界", questions: [])

        let view = QuizView(quiz: quiz)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. ConceptDetailBodyView（主题详情视图）

    /// TC-B3-03: ConceptDetailBodyView 无 Frontmatter — 纯 Markdown 降级大纲
    /// 目的：验证 content 为纯 Markdown（含 `## 标题1` 和 `### 标题2`）时降级大纲提取，
    ///       同时检测 deriveOutlinesFromMarkdown() 对 h2/h3 前缀的识别与 dropFirst 偏移正确性
    func testConceptDetailBodyViewNoFrontmatterDerivedOutlines() {
        let page = KnowledgePage(
            title: "降级大纲测试",
            pageType: .concept,
            content: """
            ## 第一章 概述
            这是概述正文。

            ### 1.1 背景
            背景说明。

            ## 第二章 架构
            架构正文。
            """
        )

        let view = ConceptDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-04: ConceptDetailBodyView 空 outgoingLinks — 脑图空状态
    /// 目的：验证 content 无 `[[链接]]` 时脑图区域显示"无结果"空状态，
    ///       同时检测 outgoing.isEmpty 分支的 L10n.Search.noResults 渲染
    func testConceptDetailBodyViewEmptyOutgoingLinksGraph() {
        let page = KnowledgePage(
            title: "无链接主题",
            pageType: .concept,
            content: "这是一个没有任何双向链接的纯文本主题页面。"
        )

        let view = ConceptDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-05: ConceptDetailBodyView 含 Frontmatter — 完整渲染
    /// 目的：验证 content 含 YAML frontmatter（outlines + surprisingInsights）+ body 时完整渲染，
    ///       同时检测 FrontmatterParser 对 snake_case 键名（surprising_insights / linked_concept_id）的解析正确性
    func testConceptDetailBodyViewFullFrontmatter() {
        let page = KnowledgePage(
            title: "完整主题",
            pageType: .concept,
            content: """
            ---
            outlines:
              - id: "1"
                title: "第一章"
                level: 1
                associated_page_id: null
              - id: "2"
                title: "1.1 子节"
                level: 2
                associated_page_id: "概念A"
            surprising_insights:
              - insight_title: "反直觉洞察"
                linked_concept_id: "关联概念"
                reason: "因为X所以Y"
            ---
            # 正文标题
            这是正文内容，含 [[关联概念]] 双向链接。
            """
        )

        let view = ConceptDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 3. SourceDetailBodyView（来源详情视图）

    /// TC-B3-06: SourceDetailBodyView 音频类型 — 音频播放器窗口
    /// 目的：验证 sourceType="audio" + frontmatter type=audio + waveform 时音频播放器渲染，
    ///       同时检测 playerCanvasSection 的 type 分支匹配（audio/voice/mp3/m4a/wav）
    func testSourceDetailBodyViewAudioPlayer() {
        let page = KnowledgePage(
            title: "音频来源",
            pageType: .source,
            content: """
            ---
            type: audio
            file_name: "lecture.m4a"
            file_size: 2048000
            voice_amplitude_waveform:
              - 0.2
              - 0.6
              - 0.9
              - 0.4
              - 0.7
            ---
            这是音频转录正文。
            """,
            fileSize: 2_048_000,
            sourceType: "audio"
        )

        let view = SourceDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.relaxedPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-07: SourceDetailBodyView OCR 类型 — OCR 画布窗口
    /// 目的：验证 sourceType="ocr" 时 OCR 画布渲染，
    ///       同时检测 playerCanvasSection 的 type 分支匹配（ocr/png/jpg/jpeg）
    func testSourceDetailBodyViewOCRCanvas() {
        let page = KnowledgePage(
            title: "OCR 来源",
            pageType: .source,
            content: """
            ---
            type: ocr
            file_name: "scan.png"
            ---
            OCR 识别出的文本内容。
            """,
            sourceType: "ocr"
        )

        let view = SourceDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-08: SourceDetailBodyView 文档类型 — 文档预览窗口
    /// 目的：验证 sourceType="pdf" 时文档预览窗口渲染，
    ///       同时检测 playerCanvasSection 的 else 兜底分支（documentPreviewWindow），
    ///       以及 frontmatter?.fileName ?? page.displaySourceName 的回退逻辑
    func testSourceDetailBodyViewDocumentPreview() {
        let page = KnowledgePage(
            title: "PDF 来源",
            pageType: .source,
            content: """
            ---
            type: pdf
            file_name: "paper.pdf"
            file_size: 512000
            ---
            PDF 文本提取正文。
            """,
            fileSize: 512_000,
            sourceType: "pdf"
        )

        let view = SourceDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 4. ComparisonDetailBodyView（对比详情视图）

    /// TC-B3-09: ComparisonDetailBodyView 无 Frontmatter — 仅结论板 + 正文
    /// 目的：验证 content 为纯 Markdown 时无矩阵网格的渲染，
    ///       同时检测 extractFirstLineSummary() 跳过 # / - / * 前缀行提取首行总结的逻辑
    func testComparisonDetailBodyViewNoFrontmatter() {
        let page = KnowledgePage(
            title: "无矩阵对比",
            pageType: .comparison,
            content: """
            # 对比标题
            - 列表项
            * 星号项
            这是首行有效总结文本。
            后续正文段落。
            """
        )

        let view = ComparisonDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-10: ComparisonDetailBodyView 完整矩阵 — 5 种单元格类型
    /// 目的：验证 content 含 frontmatter（2 subjects + 4 dimensions + matrix 含 text/rating/range/imageList/null）时矩阵网格渲染，
    ///       同时检测 cellContentView 对 5 种 MatrixValue 类型的分发渲染，
    ///       以及 getCellValue 在无匹配 cell 时返回 .null 的兜底逻辑
    func testComparisonDetailBodyViewFullMatrixFiveCellTypes() {
        let page = KnowledgePage(
            title: "完整矩阵对比",
            pageType: .comparison,
            content: """
            ---
            subjects:
              - id: "A"
                name: "方案A"
              - id: "B"
                name: "方案B"
            dimensions:
              - id: "d1"
                name: "价格"
                type: "text"
                unit: "元"
              - id: "d2"
                name: "评分"
                type: "rating"
              - id: "d3"
                name: "区间"
                type: "range"
                unit: "ms"
              - id: "d4"
                name: "标签"
                type: "image_list"
            matrix:
              - subject_id: "A"
                dimension_id: "d1"
                value: "99元"
              - subject_id: "B"
                dimension_id: "d1"
                value: "199元"
              - subject_id: "A"
                dimension_id: "d2"
                value: 4.5
              - subject_id: "B"
                dimension_id: "d2"
                value: 3.8
              - subject_id: "A"
                dimension_id: "d3"
                value:
                  min: 10
                  max: 50
              - subject_id: "B"
                dimension_id: "d3"
                value:
                  min: 20
                  max: 80
              - subject_id: "A"
                dimension_id: "d4"
                value:
                  - "快"
                  - "轻"
              - subject_id: "B"
                dimension_id: "d4"
                value: null
            ---
            这是对比正文总结。
            """
        )

        let view = ComparisonDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 5. EntityDetailBodyView（词条详情视图）

    /// TC-B3-11: EntityDetailBodyView 无 Frontmatter — 仅正文
    /// 目的：验证 content 为纯 Markdown 时无释义板/百科/概述的渲染，
    ///       同时检测 frontmatter 为 nil 时 factSummarySection 的 pronunciation/definition 空分支跳过
    func testEntityDetailBodyViewNoFrontmatter() {
        let page = KnowledgePage(
            title: "无释义词条",
            pageType: .entity,
            content: "这是一个没有 frontmatter 的纯文本词条页面。"
        )

        let view = EntityDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-12: EntityDetailBodyView 完整 Frontmatter — 释义+别名+百科+概述
    /// 目的：验证 content 含 frontmatter（pronunciation + definition + aliases + infobox + overview）+ body 时完整渲染，
    ///       同时检测 FrontmatterParser 对 EntityFrontmatter 各字段的解析与 LazyVGrid 布局
    func testEntityDetailBodyViewFullFrontmatter() {
        let page = KnowledgePage(
            title: "完整词条",
            pageType: .entity,
            content: """
            ---
            pronunciation: "zhì yǔ"
            definition: "智宇是一款 AI 原生知识管理应用"
            aliases:
              - "ZhiYu"
              - "智宇App"
            infobox:
              - key: "开发者"
                value: "WangChong"
              - key: "平台"
                value: "iOS/macOS"
              - key: "语言"
                value: "Swift"
              - key: "许可"
                value: "专有"
            overview:
              - "基于 RAG 闭环的知识管理"
              - "支持语义分块与向量检索"
              - "提供 AI 合成实验室"
            ---
            # 词条正文
            这是词条的详细正文内容。
            """
        )

        let view = EntityDetailBodyView(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 6. MedalCard（奖章卡片）

    /// TC-B3-13: MedalCard 已解锁状态
    /// 目的：验证 isEarned=true 时彩色渲染（baseColor 填充 + 图标着色 + 阴影），
    ///       同时检测 Color(hex:) 对 "#FFD700" 的解析与 grayscale(0) / opacity(1.0) 状态
    func testMedalCardEarnedState() {
        let medal = MedalService.Medal(
            id: "test_earned_medal",
            titleKey: "insight.medal.firstPage.title",
            descKey: "insight.medal.firstPage.desc",
            icon: "sparkles",
            colorHex: "#FFD700",
            threshold: 1,
            category: .explore
        )

        let view = MedalCard(medal: medal, isEarned: true)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 200)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-14: MedalCard 未解锁状态
    /// 目的：验证 isEarned=false 时灰度 + 锁图标渲染，
    ///       同时检测 grayscale(1) / opacity(0.9) 与 lock 图标 offset 定位
    func testMedalCardLockedState() {
        let medal = MedalService.Medal(
            id: "test_locked_medal",
            titleKey: "insight.medal.firstPage.title",
            descKey: "insight.medal.firstPage.desc",
            icon: "sparkles",
            colorHex: "#FFD700",
            threshold: 1,
            category: .explore
        )

        let view = MedalCard(medal: medal, isEarned: false)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 200)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 7. MedalRewardPopup（奖章奖励弹窗）

    /// TC-B3-15: MedalRewardPopup 默认状态
    /// 目的：验证弹窗初始渲染（含 isAnimating=false 时的 scaleEffect(0.5)/opacity(0) 初始帧），
    ///       潜在 Bug：onAppear 触发 spring 动画后 isAnimating=true，快照捕获时机不确定，
    ///                 可能捕获到动画中间帧导致快照不稳定。此处验证初始布局结构。
    func testMedalRewardPopupDefaultState() {
        let medal = MedalService.Medal(
            id: "test_popup_medal",
            titleKey: "insight.medal.firstPage.title",
            descKey: "insight.medal.firstPage.desc",
            icon: "sparkles",
            colorHex: "#FFD700",
            threshold: 1,
            category: .explore
        )

        let view = MedalRewardPopup(medal: medal, onDismiss: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 8. SubscriptionPlanCard（订阅套餐卡片）

    /// TC-B3-16: SubscriptionPlanCard 月付选中
    /// 目的：验证 selectedCycle=.monthly 时月付高亮 + Lite/Pro 卡片对比，
    ///       同时检测 cycleTabSelector 的 monthly 分支描边渐变与 tierCardsSection 的 Pro 价格显示
    func testSubscriptionPlanCardMonthlySelected() {
        let view = SubscriptionPlanCard(selectedCycle: .monthly, onCycleChange: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 400)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-17: SubscriptionPlanCard 年付选中
    /// 目的：验证 selectedCycle=.yearly 时年付高亮 + "省20%"徽章，
    ///       同时检测 yearly 分支的 save20Percent 徽章渲染与 Pro 价格切换为 priceMonthlyProEquivalent
    func testSubscriptionPlanCardYearlySelected() {
        let view = SubscriptionPlanCard(selectedCycle: .yearly, onCycleChange: { _ in })
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 400)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 9. CollaborationComponents（协作组件）

    /// TC-B3-18: CollabInfoRow 基本渲染
    /// 目的：验证 icon + text 的紧凑行渲染，
    ///       同时检测 DesignSystem.CompositeRow.spacing 与 ComponentSpacing.section 的布局令牌
    func testCollabInfoRowBasic() {
        let view = CollabInfoRow(icon: "wifi", text: "局域网协作已开启")
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 60)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-19: DiscoveredRoomRow 基本渲染
    /// 目的：验证房间名 + 房主 + 加入箭头的列表行渲染，
    ///       同时检测 L10n.Collaboration.hostedBy 格式化与 accessibilityIdentifier 拼接
    func testDiscoveredRoomRowBasic() {
        let room = DiscoveredRoom(
            id: "room1",
            platformPeer: "peer1" as AnyHashable,
            roomName: "知识库协作室",
            owner: "张三"
        )

        let view = DiscoveredRoomRow(room: room, onJoin: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 80)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-20: ConnectedPeerRow 显示角色
    /// 目的：验证 showRole=true + roleDisplayName 时角色文本渲染，
    ///       同时检测 showRole 分支优先于 joinedAt 时间显示的逻辑
    func testConnectedPeerRowShowRole() {
        let peer = CollabUser(
            id: "user1",
            displayName: "李四",
            deviceName: "iPhone 15 Pro",
            joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let view = ConnectedPeerRow(peer: peer, showRole: true, roleDisplayName: "编辑")
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 80)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-21: ConnectedPeerRow 显示加入时间
    /// 目的：验证 showRole=false 时显示 joinedAt 时间，
    ///       同时检测 else 分支的 Text(peer.joinedAt, style: .time) 渲染
    func testConnectedPeerRowShowJoinTime() {
        let peer = CollabUser(
            id: "user1",
            displayName: "李四",
            deviceName: "iPhone 15 Pro",
            joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let view = ConnectedPeerRow(peer: peer, showRole: false, roleDisplayName: nil)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 80)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-22: RecentEditRow 基本渲染
    /// 目的：验证编辑记录行的用户名提取 + 字段/新值预览 + 时间戳渲染，
    ///       同时检测 userID.components(separatedBy: "|").first 的分隔提取逻辑，
    ///       以及 newValue.prefix(maxCollabEditPreviewLength) 的截断行为
    func testRecentEditRowBasic() {
        let edit = CollabEdit(
            id: "edit1",
            userID: "user1|device1",
            pageID: UUID(),
            field: "标题",
            oldValue: "旧标题",
            newValue: "新标题",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let view = RecentEditRow(edit: edit)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 80)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-23: CollabRoleBadge 三种角色
    /// 目的：验证 .owner / .editor / .viewer 三种角色的颜色和文案，
    ///       同时检测 color switch 分支（yellow/appAccent/appSecondary）与 role.displayName 本地化
    func testCollabRoleBadgeThreeRoles() {
        let view = VStack(spacing: DesignSystem.medium) {
            CollabRoleBadge(role: .owner)
            CollabRoleBadge(role: .editor)
            CollabRoleBadge(role: .viewer)
        }
        .padding()
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 160)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 10. NotebookCoverView（笔记本封面视图）

    /// TC-B3-24: NotebookCoverView 线性渐变
    /// 目的：验证 type=.linear + 2 色 hex 数组时 LinearGradient 渲染，
    ///       同时检测 parsedColors() 对 ["#4F46E5", "#7C3AED"] 的 Color(hex:) 解析与标题/页数显示
    func testNotebookCoverViewLinearGradient() {
        let config = NotebookThemeConfig(type: .linear, colors: ["#4F46E5", "#7C3AED"], seed: 42)

        let view = NotebookCoverView(
            config: config,
            title: "机器学习笔记",
            icon: "book.closed.fill",
            pageCount: 42
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 220)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-25: NotebookCoverView 网格渐变
    /// 目的：验证 type=.mesh 时 RadialGradient 渲染，
    ///       同时检测 mesh 分支的 startRadius/endRadius 参数与 pageCount=0 的 L10n.Shared.pageCountFormat 格式化
    func testNotebookCoverViewMeshGradient() {
        let config = NotebookThemeConfig(type: .mesh, colors: ["#10B981", "#3B82F6"], seed: 7)

        let view = NotebookCoverView(
            config: config,
            title: "深度学习",
            icon: "book.closed.fill",
            pageCount: 0
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 220)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-26: NotebookCoverView 空颜色兜底
    /// 目的：验证 colors=[] 时 parsedColors() 返回兜底 [blue, purple] 的渲染，
    ///       潜在 Bug：空 colors 数组时静默回退到默认蓝紫配色，用户无感知；
    ///                 若 NotebookThemeConfig 允许空数组则应在上游校验或显式提示。
    func testNotebookCoverViewEmptyColorsFallback() {
        let config = NotebookThemeConfig(type: .linear, colors: [], seed: 0)

        let view = NotebookCoverView(
            config: config,
            title: "空颜色兜底",
            icon: "book.closed.fill",
            pageCount: 1
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 220)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// TC-B3-27: NotebookCoverView 按下状态
    /// 目的：验证 isPressed=true 时 scaleEffect(0.95) 的缩放渲染，
    ///       同时检测 spring 动画修饰符对 isPressed 状态变化的响应
    func testNotebookCoverViewPressedState() {
        let config = NotebookThemeConfig(type: .linear, colors: ["#4F46E5", "#7C3AED"], seed: 42)

        let view = NotebookCoverView(
            config: config,
            title: "机器学习笔记",
            icon: "book.closed.fill",
            pageCount: 42,
            isPressed: true
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 220)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }
}
