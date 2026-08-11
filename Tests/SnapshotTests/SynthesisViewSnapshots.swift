//
//  SynthesisViewSnapshots.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：AI 合成实验室子视图的快照测试，覆盖错误状态、文档行、报告、幻灯片、思维导图、控制弹窗。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class SynthesisViewSnapshots: XCTestCase {

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

    // MARK: - SynthesisErrorStateView

    /// 测试错误状态视图 — 仅显示重试按钮（无切换到文本）
    func testSynthesisErrorStateView_WithRetryOnly() {
        let view = SynthesisErrorStateView(
            docType: .mindmap,
            onSwitchToText: nil,
            onRetry: { }
        )
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试错误状态视图 — 同时显示切换到文本和重试按钮
    func testSynthesisErrorStateView_WithBothActions() {
        let view = SynthesisErrorStateView(
            docType: .report,
            onSwitchToText: { },
            onRetry: { }
        )
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试错误状态视图 — 无任何按钮
    func testSynthesisErrorStateView_NoActions() {
        let view = SynthesisErrorStateView(
            docType: .slides,
            onSwitchToText: nil,
            onRetry: nil
        )
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - SynthesisDocRow

    /// 测试文档行 — 非编辑模式，无来源页面
    func testSynthesisDocRow_InactiveMode_NoSources() {
        let doc = SynthesisStore.SynthesisDocument(
            type: .report,
            name: "测试报告文档",
            content: "# 报告内容",
            size: 1024,
            sourcePageIDs: []
        )

        let view = SynthesisDocRow(
            doc: doc,
            type: .report,
            editMode: .inactive,
            isSelected: false,
            onTap: { },
            onRename: { },
            onDelete: { }
        )
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize)))
    }

    /// 测试文档行 — 编辑模式，选中状态，含来源页面
    func testSynthesisDocRow_ActiveMode_Selected_WithSources() {
        let doc = SynthesisStore.SynthesisDocument(
            type: .mindmap,
            name: "思维导图文档",
            content: "mindmap\n  root((测试))",
            size: 2048,
            sourcePageIDs: [UUID(), UUID(), UUID()]
        )

        let view = SynthesisDocRow(
            doc: doc,
            type: .mindmap,
            editMode: .active,
            isSelected: true,
            onTap: { },
            onRename: { },
            onDelete: { }
        )
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize)))
    }

    /// 测试文档行 — 编辑模式，未选中状态
    func testSynthesisDocRow_ActiveMode_Unselected() {
        let doc = SynthesisStore.SynthesisDocument(
            type: .slides,
            name: "演示文稿",
            content: "## 第一页\n内容",
            size: 512,
            sourcePageIDs: [UUID()]
        )

        let view = SynthesisDocRow(
            doc: doc,
            type: .slides,
            editMode: .active,
            isSelected: false,
            onTap: { },
            onRename: { },
            onDelete: { }
        )
        .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize)
        .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize)))
    }

    // MARK: - SynthesisReportView

    /// 测试报告视图 — 标准 Markdown 内容
    func testSynthesisReportView_StandardMarkdown() {
        let doc = SynthesisStore.SynthesisDocument(
            type: .report,
            name: "测试报告",
            content: "# 测试报告\n\n这是一段**测试内容**，用于验证报告视图的渲染。\n\n## 二级标题\n\n- 列表项 1\n- 列表项 2",
            size: 100
        )

        let view = SynthesisReportView(doc: doc)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - SynthesisSlidesView

    /// 测试幻灯片视图 — 多页内容（--- 分隔）
    /// 注意：`SynthesisSlidesView` 内部使用 `MarkdownRendererView`，后者通过
    /// `@Environment(AppStore.self) var store` 强依赖 `AppStore`，未注入会触发
    /// SwiftUI `_assertionFailure` 崩溃（见缺陷 S9-18）。此处注入 `AppStore` 实例。
    func testSynthesisSlidesView_MultipleSlides() {
        let doc = SynthesisStore.SynthesisDocument(
            type: .slides,
            name: "演示文稿",
            content: "## 第一页\n\n内容 A\n---\n## 第二页\n\n内容 B",
            size: 100
        )

        let view = SynthesisSlidesView(doc: doc)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试幻灯片视图 — 单页内容
    func testSynthesisSlidesView_SingleSlide() {
        let doc = SynthesisStore.SynthesisDocument(
            type: .slides,
            name: "单页演示",
            content: "## 唯一一页\n\n这是单页幻灯片的内容。",
            size: 50
        )

        let view = SynthesisSlidesView(doc: doc)
            .snapshotEnvironment()
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - SynthesisMindmapView

    /// 测试思维导图视图 — 含 Mermaid 代码块
    func testSynthesisMindmapView_WithMermaidCode() {
        let doc = SynthesisStore.SynthesisDocument(
            type: .mindmap,
            name: "思维导图",
            content: "# 测试思维导图\n\n```mermaid\nmindmap\n  root((根节点))\n    子节点1\n    子节点2\n```",
            size: 100
        )

        let view = SynthesisMindmapView(doc: doc)
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试思维导图视图 — 无 Mermaid 代码（回退到文本模式）
    func testSynthesisMindmapView_FallbackToText() {
        let doc = SynthesisStore.SynthesisDocument(
            type: .mindmap,
            name: "纯文本思维导图",
            content: "# 纯文本思维导图\n\n这是一段不含 Mermaid 代码的内容。",
            size: 80
        )

        let view = SynthesisMindmapView(doc: doc)
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - SynthesisControlSheet

    /// 测试控制弹窗 — 报告类型
    func testSynthesisControlSheet_ReportType() {
        let view = SynthesisControlSheet(type: .report) { _ in }
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    /// 测试控制弹窗 — 思维导图类型
    func testSynthesisControlSheet_MindmapType() {
        let view = SynthesisControlSheet(type: .mindmap) { _ in }
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - SynthesisTimelineView

    /// 测试时间线视图 — 无运行中任务
    func testSynthesisTimelineView_NoRunningTasks() {
        let taskCenter = TaskCenter()
        let view = SynthesisTimelineView(taskCenter: taskCenter)
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize)))
    }

    /// 测试时间线视图 — 含运行中合成任务
    func testSynthesisTimelineView_WithRunningTask() {
        let taskCenter = TaskCenter()
        taskCenter.tasks = [
            GlobalTask(
                type: .synthesis,
                name: "合成测试任务",
                target: "测试目标",
                status: .running(progress: 0.5, stage: .synthesis)
            )
        ]

        let view = SynthesisTimelineView(taskCenter: taskCenter)
            .frame(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize)
            .background(Color.appBackground)

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotMediumComponentSize)))
    }
}
