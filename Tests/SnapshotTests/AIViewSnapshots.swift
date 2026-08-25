//
//  AIViewSnapshots.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：Features/AI View 快照测试，覆盖 PromptWorkshopView/SynthesisReportView 系列/
//           ChatComponents（ChatBubbleView/ChatContentView/SuggestedFollowUpCardView）/
//           VoiceNoteComponents（SaveVoiceNoteSheet/VoiceRecordingRow）等低覆盖率文件，
//           验证视觉一致性并暴露源码潜在问题。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AIViewSnapshots: XCTestCase {

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

        // 重置提示词服务到默认状态，防止设置修改污染快照
        @Dependency(\.promptService) var promptService: PromptService
        promptService.reset()
    }

    // MARK: - 1. PromptWorkshopView（PromptWorkshopView.swift）

    /// 测试 PromptWorkshopView 默认状态（含简介展开 + 默认快捷指令）的视觉一致性
    func testPromptWorkshopViewDefault() {
        setupMockEnvironment()

        let view = NavigationStack {
            PromptWorkshopView()
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 PromptWorkshopView watch 占位状态 — 验证 WatchFeaturePlaceholderView 分支
    /// 注意：interfaceIdiom 在快照测试中无法注入为 .watch（依赖平台环境），
    /// 此测试仅验证默认 idiom 路径的稳定性，watch 分支需在 watchOS target 测试。
    func testPromptWorkshopViewNonWatchIdiom() {
        setupMockEnvironment()

        let view = NavigationStack {
            PromptWorkshopView()
        }
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. SynthesisSourcePagesBar（SynthesisReportView.swift）

    /// 测试 SynthesisSourcePagesBar 有来源页面状态的视觉一致性
    func testSynthesisSourcePagesBarWithSources() {
        setupMockEnvironment()

        let store = AppStore()
        let page1 = KnowledgePage(title: "深度学习基础", pageType: .concept, content: "深度学习是机器学习的一个分支...")
        let page2 = KnowledgePage(title: "神经网络架构", pageType: .entity, content: "神经网络由多层神经元组成...")
        let page3 = KnowledgePage(title: "Transformer 论文", pageType: .source, content: "Attention Is All You Need")
        store.knowledgeStore.pages = [page1, page2, page3]

        let view = SynthesisSourcePagesBar(
            sourcePageIDs: [page1.id, page2.id, page3.id],
            store: store,
            onNavigate: { _ in }
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 180)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 180)))
    }

    /// 测试 SynthesisSourcePagesBar 空来源页面状态（sourcePageIDs 为空但 store 有页面）
    func testSynthesisSourcePagesBarEmptySources() {
        setupMockEnvironment()

        let store = AppStore()

        let view = SynthesisSourcePagesBar(
            sourcePageIDs: [],
            store: store,
            onNavigate: { _ in }
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)))
    }

    // MARK: - 3. SynthesisOutputContent（SynthesisReportView.swift）

    /// 测试 SynthesisOutputContent report 类型 + 有内容的视觉一致性
    func testSynthesisOutputContentReportWithContent() {
        setupMockEnvironment()

        let doc = SynthesisStore.SynthesisDocument(
            type: .report,
            name: "测试报告",
            content: "# 测试报告\n\n这是一段**测试内容**，用于验证输出内容分发视图。\n\n## 二级标题\n\n- 列表项 1\n- 列表项 2",
            size: 100
        )

        let view = SynthesisOutputContent(doc: doc)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试 SynthesisOutputContent 空内容回退到错误状态视图
    func testSynthesisOutputContentEmptyContentFallback() {
        setupMockEnvironment()

        let doc = SynthesisStore.SynthesisDocument(
            type: .report,
            name: "空报告",
            content: "   \n  ",
            size: 0
        )

        let view = SynthesisOutputContent(doc: doc)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 4. ChatBubbleView（ChatComponents.swift）

    /// 测试 ChatBubbleView 用户消息气泡的视觉一致性
    func testChatBubbleViewUserMessage() {
        setupMockEnvironment()

        var selectedTab = AppTab.chat
        let message = ChatMessage(
            role: .user,
            content: "请帮我解释一下量子纠缠现象。",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let view = ChatBubbleView(
            message: message,
            pages: [],
            selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 })
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 200)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 200)))
    }

    /// 测试 ChatBubbleView AI 助手消息（含追问推荐）的视觉一致性
    func testChatBubbleViewAssistantWithFollowUps() {
        setupMockEnvironment()

        var selectedTab = AppTab.chat
        let message = ChatMessage(
            role: .assistant,
            content: "量子纠缠是量子力学中的一种现象，两个或多个粒子之间存在关联...",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            relatedPageIDs: []
        )

        let view = ChatBubbleView(
            message: message,
            pages: [],
            selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 }),
            predictedQuestions: [
                "什么是贝尔不等式？",
                "量子纠缠如何用于通信？",
                "量子退相干是什么？"
            ],
            onSelectQuestion: { _ in }
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 ChatBubbleView 系统消息气泡的视觉一致性
    func testChatBubbleViewSystemMessage() {
        setupMockEnvironment()

        var selectedTab = AppTab.chat
        let message = ChatMessage(
            role: .system,
            content: "对话已清空，开始新的会话。",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let view = ChatBubbleView(
            message: message,
            pages: [],
            selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 })
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)))
    }

    /// 测试 ChatBubbleView 选择模式 + AI 消息含引用面板（折叠态）
    func testChatBubbleViewSelectionModeWithReferences() {
        setupMockEnvironment()

        var selectedTab = AppTab.chat
        let page1 = KnowledgePage(title: "量子力学基础", pageType: .concept, content: "量子力学基础内容")
        let page2 = KnowledgePage(title: "薛定谔方程", pageType: .entity, content: "薛定谔方程描述量子态演化")
        let message = ChatMessage(
            role: .assistant,
            content: "根据量子力学原理...",
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            relatedPageIDs: [page1.id, page2.id]
        )

        let view = ChatBubbleView(
            message: message,
            pages: [page1, page2],
            selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 }),
            isSelectionMode: true,
            isSelected: true
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    // MARK: - 5. ChatContentView（ChatComponents.swift）

    /// 测试 ChatContentView 普通文本（无思考过程）的视觉一致性
    func testChatContentViewPlainText() {
        setupMockEnvironment()

        var selectedTab = AppTab.chat
        let view = ChatContentView(
            text: "这是一段普通的 AI 回复文本，包含 **加粗** 和 `行内代码`。",
            pages: [],
            selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 })
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 200)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 200)))
    }

    /// 测试 ChatContentView 含思考过程（<think> 标签）的视觉一致性
    func testChatContentViewWithThinkingBlock() {
        setupMockEnvironment()

        var selectedTab = AppTab.chat
        let text = """
        <thinking>
        用户询问量子纠缠，我需要从定义、原理、应用三个维度回答。
        </thinking>
        量子纠缠是量子力学中的一种现象...
        """

        let view = ChatContentView(
            text: text,
            pages: [],
            selectedTab: Binding(get: { selectedTab }, set: { selectedTab = $0 })
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 300)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 300)))
    }

    // MARK: - 6. SuggestedFollowUpCardView（ChatComponents.swift）

    /// 测试 SuggestedFollowUpCardView 多问题列表的视觉一致性
    func testSuggestedFollowUpCardViewMultipleQuestions() {
        setupMockEnvironment()

        let view = SuggestedFollowUpCardView(
            questions: [
                "什么是贝尔不等式？",
                "量子纠缠如何用于通信？",
                "量子退相干是什么？"
            ],
            onSelect: { _ in }
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 SuggestedFollowUpCardView 单问题的视觉一致性
    func testSuggestedFollowUpCardViewSingleQuestion() {
        setupMockEnvironment()

        let view = SuggestedFollowUpCardView(
            questions: ["能否再详细解释一下？"],
            onSelect: { _ in }
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 180)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 180)))
    }

    // MARK: - 7. SaveVoiceNoteSheet（VoiceNoteComponents.swift）

    /// 测试 SaveVoiceNoteSheet 有转写文本状态的视觉一致性
    func testSaveVoiceNoteSheetWithTranscription() {
        setupMockEnvironment()

        @Dependency(\.speechService) var speechService: any SpeechServiceProtocol
        speechService.transcribedText = "今天讨论了项目进度，后端 API 已完成 80%，前端需要加快速度。明天开始集成测试。"
        var title = "项目讨论录音"

        let view = SaveVoiceNoteSheet(
            speechService: speechService,
            title: Binding(get: { title }, set: { title = $0 })
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// 测试 SaveVoiceNoteSheet 空转写文本状态
    func testSaveVoiceNoteSheetEmptyTranscription() {
        setupMockEnvironment()

        @Dependency(\.speechService) var speechService: any SpeechServiceProtocol
        speechService.transcribedText = ""
        var title = ""

        let view = SaveVoiceNoteSheet(
            speechService: speechService,
            title: Binding(get: { title }, set: { title = $0 })
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 8. VoiceRecordingRow（VoiceNoteComponents.swift）

    /// 测试 VoiceRecordingRow 完整数据状态的视觉一致性
    func testVoiceRecordingRowFullData() {
        setupMockEnvironment()

        let recording = VoiceRecording(
            title: "项目讨论录音",
            text: "今天讨论了项目进度，后端 API 已完成 80%，前端需要加快速度。明天开始集成测试。",
            language: "zh-CN",
            duration: 185.5,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let view = VoiceRecordingRow(recording: recording)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)))
    }

    /// 测试 VoiceRecordingRow 长文本截断状态（验证 prefix(50) 截断逻辑）
    func testVoiceRecordingRowLongTextTruncation() {
        setupMockEnvironment()

        let longText = String(repeating: "这是一段很长的转录文本内容，用于测试截断逻辑。", count: 10)
        let recording = VoiceRecording(
            title: "超长转录录音",
            text: longText,
            language: "zh-CN",
            duration: 600.0,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let view = VoiceRecordingRow(recording: recording)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: 100)))
    }
}
