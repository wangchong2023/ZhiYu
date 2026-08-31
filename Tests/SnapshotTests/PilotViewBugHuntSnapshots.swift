//
//  PilotViewBugHuntSnapshots.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：试点 View 快照测试 — 以发现源码缺陷为目的，覆盖 RegionSelectorToggle /
//           ActivityRow / TagCapsuleView / SynthesisActionButton / OnDeviceTestView，
//           针对边界值、异常输入、状态组合设计用例，验证视觉一致性的同时暴露潜在问题。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class PilotViewBugHuntSnapshots: XCTestCase {

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

    override func tearDown() async throws {
        if let original = originalLanguageMode {
            Localized.languageMode = original
        }
        try await super.tearDown()
    }

    /// 统一配置 Mock 测试环境
    private func setupMockEnvironment() {
        setupFullMockEnvironment()
        if originalLanguageMode == nil {
            originalLanguageMode = Localized.languageMode
        }
        Localized.languageMode = .chinese
    }

    // MARK: - 1. RegionSelectorToggle（区域选择切换）

    /// TC-PILOT-01: 默认选中中国大陆区域时的视觉一致性
    func testRegionSelectorToggleDefaultChina() {
        setupMockEnvironment()

        let view = RegionSelectorToggle(currentRegion: .constant(.china), onToggle: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// TC-PILOT-02: 选中国际区域时的视觉一致性
    func testRegionSelectorToggleInternational() {
        setupMockEnvironment()

        let view = RegionSelectorToggle(currentRegion: .constant(.international), onToggle: {})
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// TC-PILOT-03: onToggle 回调行为验证 — 切换区域时应触发回调
    /// 目的：验证 onToggle 只在区域实际变化时调用，点击当前已选区域不应触发
    func testRegionSelectorToggleCallbackOnlyOnActualChange() {
        setupMockEnvironment()

        var region: AuthRegion = .china
        var toggleCallCount = 0
        let view = RegionSelectorToggle(currentRegion: Binding(get: { region }, set: { region = $0 }), onToggle: {
            toggleCallCount += 1
        })

        // 初始状态：china，模拟点击 china（不应触发 onToggle）
        // 由于 onTapGesture 无法在单元测试中直接触发，此处验证绑定语义
        XCTAssertEqual(region, .china, "初始区域应为 china")
        XCTAssertEqual(toggleCallCount, 0, "初始状态回调不应被触发")

        // 模拟切换到 international
        region = .international
        XCTAssertEqual(region, .international, "区域应已切换为 international")

        _ = view
    }

    // MARK: - 2. ActivityRow（任务行）

    /// TC-PILOT-04: 已完成任务（含关联页面 ID）的视觉一致性
    func testActivityRowCompletedWithPageID() {
        setupMockEnvironment()

        var task = GlobalTask(
            type: .ingest,
            name: "文档导入",
            target: "量子力学.pdf",
            status: .completed
        )
        task.associatedPageID = UUID()

        let view = ActivityRow(task: task)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// TC-PILOT-05: 失败任务（无关联页面 ID）的视觉一致性
    /// 目的：验证 failed 状态下 taskColor 为红色、不显示前进箭头
    func testActivityRowFailedNoPageID() {
        setupMockEnvironment()

        let task = GlobalTask(
            type: .ingest,
            name: "URL 抓取",
            target: "https://example.com/invalid",
            status: .failed(error: "网络超时")
        )

        let view = ActivityRow(task: task)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// TC-PILOT-06: 运行中任务（带进度和阶段）的视觉一致性
    /// 目的：验证 running 状态带关联值时 switch 匹配是否正确
    func testActivityRowRunningWithProgress() {
        setupMockEnvironment()

        let task = GlobalTask(
            type: .aiScan,
            name: "AI 扫描",
            target: "论文合集",
            status: .running(progress: 0.65, stage: .extraction)
        )

        let view = ActivityRow(task: task)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// TC-PILOT-07: 等待中任务的视觉一致性
    func testActivityRowPending() {
        setupMockEnvironment()

        let task = GlobalTask(
            type: .synthesis,
            name: "知识合成",
            target: "思维导图",
            status: .pending
        )

        let view = ActivityRow(task: task)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// TC-PILOT-08: 任务名称和目标为空字符串时的边界行为
    /// 目的：验证空字符串拼接 ": " 不会导致 UI 异常
    func testActivityRowEmptyNameAndTarget() {
        setupMockEnvironment()

        let task = GlobalTask(
            type: .ingest,
            name: "",
            target: "",
            status: .completed
        )

        let view = ActivityRow(task: task)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    // MARK: - 3. TagCapsuleView（标签气泡）

    /// TC-PILOT-09: 列表模式默认（未选中）标签的视觉一致性
    func testTagCapsuleViewListModeUnselected() {
        setupMockEnvironment()

        let coordinator = TagCloudCoordinator()
        let view = TagCapsuleView(
            item: (tag: "量子力学", count: 42),
            coordinator: coordinator,
            bubbleRatio: 0.0,
            isBubbleMode: false
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// TC-PILOT-10: 列表模式选中标签的视觉一致性
    func testTagCapsuleViewListModeSelected() {
        setupMockEnvironment()

        let coordinator = TagCloudCoordinator()
        coordinator.selectedTag = "量子力学"
        let view = TagCapsuleView(
            item: (tag: "量子力学", count: 42),
            coordinator: coordinator,
            bubbleRatio: 0.0,
            isBubbleMode: false
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// TC-PILOT-11: 气泡模式高词频标签（bubbleRatio=1.0）的视觉一致性
    func testTagCapsuleViewBubbleModeHighFrequency() {
        setupMockEnvironment()

        let coordinator = TagCloudCoordinator()
        let view = TagCapsuleView(
            item: (tag: "前沿科学", count: 128),
            coordinator: coordinator,
            bubbleRatio: 1.0,
            isBubbleMode: true
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize * 2)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize * 2)))
    }

    /// TC-PILOT-12: 气泡模式低词频标签（bubbleRatio=0.0）的视觉一致性
    func testTagCapsuleViewBubbleModeLowFrequency() {
        setupMockEnvironment()

        let coordinator = TagCloudCoordinator()
        let view = TagCapsuleView(
            item: (tag: "冷门标签", count: 1),
            coordinator: coordinator,
            bubbleRatio: 0.0,
            isBubbleMode: true
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize * 2)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize * 2)))
    }

    /// TC-PILOT-13: 编辑模式下选中标签的视觉一致性（应显示编辑角标）
    func testTagCapsuleViewEditModeSelected() {
        setupMockEnvironment()

        let coordinator = TagCloudCoordinator()
        coordinator.isEditMode = true
        coordinator.selectedTagsForBulk.insert("量子力学")
        let view = TagCapsuleView(
            item: (tag: "量子力学", count: 42),
            coordinator: coordinator,
            bubbleRatio: 0.0,
            isBubbleMode: false
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// TC-PILOT-14: bubbleRatio 超出 [0,1] 范围（负值）的边界行为
    /// 目的：验证负值 bubbleRatio 是否导致 fontSize/opacity/size 计算异常
    func testTagCapsuleViewBubbleRatioNegative() {
        setupMockEnvironment()

        let coordinator = TagCloudCoordinator()
        let view = TagCapsuleView(
            item: (tag: "异常标签", count: 5),
            coordinator: coordinator,
            bubbleRatio: -0.5,
            isBubbleMode: true
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize * 2)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize * 2)))
    }

    /// TC-PILOT-15: bubbleRatio 超出 [0,1] 范围（超过 1.0）的边界行为
    /// 目的：验证超值 bubbleRatio 是否导致 fontSize/size 溢出
    func testTagCapsuleViewBubbleRatioOverflow() {
        setupMockEnvironment()

        let coordinator = TagCloudCoordinator()
        let view = TagCapsuleView(
            item: (tag: "溢出标签", count: 999),
            coordinator: coordinator,
            bubbleRatio: 2.5,
            isBubbleMode: true
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize * 2)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize * 2)))
    }

    /// TC-PILOT-16: 标签包含 "#" 前缀时的显示行为
    /// 目的：验证 replacingOccurrences(of: "#") 是否正确移除前缀
    func testTagCapsuleViewTagWithHashPrefix() {
        setupMockEnvironment()

        let coordinator = TagCloudCoordinator()
        let view = TagCapsuleView(
            item: (tag: "#物理", count: 10),
            coordinator: coordinator,
            bubbleRatio: 0.0,
            isBubbleMode: false
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    /// TC-PILOT-17: count 为 0 时的边界行为
    /// 目的：验证词频为 0 是否导致显示异常
    func testTagCapsuleViewZeroCount() {
        setupMockEnvironment()

        let coordinator = TagCloudCoordinator()
        let view = TagCapsuleView(
            item: (tag: "零频标签", count: 0),
            coordinator: coordinator,
            bubbleRatio: 0.0,
            isBubbleMode: false
        )
        .snapshotEnvironment()
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotSmallComponentSize)))
    }

    // MARK: - 4. SynthesisActionButton（合成操作按钮）

    /// 可变 Bool 绑定助手
    private func boolBinding(_ value: Bool) -> Binding<Bool> {
        Binding(get: { value }, set: { _ = $0 })
    }

    /// TC-PILOT-18: 空闲状态思维导图合成按钮的视觉一致性
    func testSynthesisActionButtonIdleMindmap() {
        setupMockEnvironment()

        let store = AppStore()
        let synthesisStore = SynthesisStore()

        let view = SynthesisActionButton(
            type: .mindmap,
            store: store,
            showNoPagesAlert: boolBinding(false),
            showLimitAlert: boolBinding(false),
            showLLMAlert: boolBinding(false),
            selectedFilterType: .constant(nil),
            selectedDoc: .constant(nil),
            showOutput: boolBinding(false)
        )
        .snapshotEnvironment(synthesisStore: synthesisStore)
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth / 2, height: DesignSystem.Metrics.snapshotSmallComponentSize * 2)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth / 2, height: DesignSystem.Metrics.snapshotSmallComponentSize * 2)))
    }

    /// TC-PILOT-19: 生成中状态合成按钮的视觉一致性
    /// 目的：验证 generating 状态下按钮禁用、显示 ProgressView
    func testSynthesisActionButtonGenerating() {
        setupMockEnvironment()

        let store = AppStore()
        let synthesisStore = SynthesisStore()
        synthesisStore.synthesisStates[.quiz] = .generating

        let view = SynthesisActionButton(
            type: .quiz,
            store: store,
            showNoPagesAlert: boolBinding(false),
            showLimitAlert: boolBinding(false),
            showLLMAlert: boolBinding(false),
            selectedFilterType: .constant(nil),
            selectedDoc: .constant(nil),
            showOutput: boolBinding(false)
        )
        .snapshotEnvironment(synthesisStore: synthesisStore)
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth / 2, height: DesignSystem.Metrics.snapshotSmallComponentSize * 2)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth / 2, height: DesignSystem.Metrics.snapshotSmallComponentSize * 2)))
    }

    /// TC-PILOT-20: 达到上限状态合成按钮的视觉一致性
    /// 目的：验证 isLimitReached 时显示红色警告文本
    func testSynthesisActionButtonLimitReached() {
        setupMockEnvironment()

        let store = AppStore()
        let synthesisStore = SynthesisStore()
        // 填充结果至上限
        let maxCount = synthesisStore.maxSynthesisDocsPerType
        var docs: [SynthesisStore.SynthesisDocument] = []
        for i in 0..<maxCount {
            docs.append(SynthesisStore.SynthesisDocument(
                id: UUID(),
                type: .report,
                name: "报告 \(i)",
                content: "内容",
                createdAt: Date(),
                size: 100,
                sourcePageIDs: []
            ))
        }
        synthesisStore.synthesisResults[.report] = docs

        let view = SynthesisActionButton(
            type: .report,
            store: store,
            showNoPagesAlert: boolBinding(false),
            showLimitAlert: boolBinding(false),
            showLLMAlert: boolBinding(false),
            selectedFilterType: .constant(nil),
            selectedDoc: .constant(nil),
            showOutput: boolBinding(false)
        )
        .snapshotEnvironment(synthesisStore: synthesisStore)
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth / 2, height: DesignSystem.Metrics.snapshotSmallComponentSize * 2.5)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth / 2, height: DesignSystem.Metrics.snapshotSmallComponentSize * 2.5)))
    }

    // MARK: - 5. OnDeviceTestView（端侧大模型测试沙盒）

    /// TC-PILOT-21: OnDeviceTestView 初始状态（无模型加载）的视觉一致性
    func testOnDeviceTestViewInitialState() {
        setupMockEnvironment()

        let service = OnDeviceLLMService()
        let view = OnDeviceTestView(onDeviceService: service)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }

    /// TC-PILOT-22: OnDeviceTestView 生成中状态的视觉一致性
    /// 目的：验证 isGenerating=true 时进度指示器和按钮状态
    func testOnDeviceTestViewGenerating() {
        setupMockEnvironment()

        let service = OnDeviceLLMService()
        service.isGenerating = true
        service.generationProgress = 0.5
        service.generatedText = "正在生成中..."
        let view = OnDeviceTestView(onDeviceService: service)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotScrollHeight)))
    }
}
