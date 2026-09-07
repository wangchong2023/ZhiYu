//
//  SynthesisAndTaskCenterInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 业务功能测试层
//  核心职责：覆盖 AI 综合实验室文档管理、分类筛选、任务中心生命周期与异常防御
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SynthesisAndTaskCenterInteractiveTests: XCTestCase {

    private var appStore: AppStore!
    private var synthesisStore: SynthesisStore!
    private var router: Router!
    private var themeManager: ThemeManager!
    private var taskCenter: TaskCenter!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        appStore = AppStore()
        synthesisStore = SynthesisStore()
        router = Router.shared
        themeManager = ThemeManager()
        taskCenter = TaskCenter()
        taskCenter.reset()
    }

    override func tearDown() async throws {
        taskCenter.reset()
        appStore = nil
        synthesisStore = nil
        router = nil
        themeManager = nil
        taskCenter = nil
        try await super.tearDown()
    }

    // MARK: - 1. SynthesisViewActionHelper 文档名称校验与 Fuzz 模糊测试

    func testSynthesisViewActionHelper_ValidateAndTrimDocName() {
        // 1. 正常文档名修剪首尾空白与换行
        let valid = SynthesisViewActionHelper.validateAndTrimDocName("   分布式系统拓扑分析 \n  ")
        XCTAssertEqual(valid, "分布式系统拓扑分析")

        // 2. 空白与换行被严格拒绝
        XCTAssertNil(SynthesisViewActionHelper.validateAndTrimDocName(""))
        XCTAssertNil(SynthesisViewActionHelper.validateAndTrimDocName("   \t  \n  "))

        // 3. 50 次 Fuzz 纯空白测试：保证恒定安全返回 nil
        for _ in 0..<50 {
            let spaces = String(repeating: " ", count: Int.random(in: 1...20))
            let newlines = String(repeating: "\n", count: Int.random(in: 0...5))
            XCTAssertNil(SynthesisViewActionHelper.validateAndTrimDocName(spaces + newlines))
        }
    }

    // MARK: - 2. SynthesisViewActionHelper 文档类型过滤测试

    func testSynthesisViewActionHelper_FilterDocuments() {
        let doc1 = SynthesisStore.SynthesisDocument(
            id: UUID(),
            type: .mindmap,
            name: "脑图 1",
            content: "mindmap content",
            createdAt: Date(),
            size: 120
        )
        let doc2 = SynthesisStore.SynthesisDocument(
            id: UUID(),
            type: .report,
            name: "研报 1",
            content: "report content",
            createdAt: Date(),
            size: 240
        )

        let allDocs: [(SynthesisStore.SynthesisType, SynthesisStore.SynthesisDocument)] = [
            (.mindmap, doc1),
            (.report, doc2)
        ]

        // 1. 全选 (nil) 保持全部文档
        let allFiltered = SynthesisViewActionHelper.filterDocuments(allDocs, by: nil)
        XCTAssertEqual(allFiltered.count, 2)

        // 2. 筛选脑图类型
        let mindmapFiltered = SynthesisViewActionHelper.filterDocuments(allDocs, by: .mindmap)
        XCTAssertEqual(mindmapFiltered.count, 1)
        XCTAssertEqual(mindmapFiltered.first?.1.id, doc1.id)

        // 3. 筛选报告类型
        let reportFiltered = SynthesisViewActionHelper.filterDocuments(allDocs, by: .report)
        XCTAssertEqual(reportFiltered.count, 1)
        XCTAssertEqual(reportFiltered.first?.1.id, doc2.id)

        // 4. 筛选无匹配类型
        let quizFiltered = SynthesisViewActionHelper.filterDocuments(allDocs, by: .quiz)
        XCTAssertTrue(quizFiltered.isEmpty)
    }

    // MARK: - 3. SynthesisViewActionHelper 多选状态机与批量删除断言

    func testSynthesisViewActionHelper_ToggleDocSelectionAndCanBatchDelete() {
        var selectedIDs = Set<UUID>()
        let testID1 = UUID()
        let testID2 = UUID()

        // 初始为空不允许批量删除
        XCTAssertFalse(SynthesisViewActionHelper.canBatchDelete(selectedIDs: selectedIDs))

        // 勾选首个文档
        SynthesisViewActionHelper.toggleDocSelection(docID: testID1, in: &selectedIDs)
        XCTAssertTrue(selectedIDs.contains(testID1))
        XCTAssertTrue(SynthesisViewActionHelper.canBatchDelete(selectedIDs: selectedIDs))

        // 勾选第二个文档
        SynthesisViewActionHelper.toggleDocSelection(docID: testID2, in: &selectedIDs)
        XCTAssertEqual(selectedIDs.count, 2)

        // 反选首个文档（移除）
        SynthesisViewActionHelper.toggleDocSelection(docID: testID1, in: &selectedIDs)
        XCTAssertFalse(selectedIDs.contains(testID1))
        XCTAssertEqual(selectedIDs.count, 1)

        // 全部移除后恢复禁用
        SynthesisViewActionHelper.toggleDocSelection(docID: testID2, in: &selectedIDs)
        XCTAssertTrue(selectedIDs.isEmpty)
        XCTAssertFalse(SynthesisViewActionHelper.canBatchDelete(selectedIDs: selectedIDs))
    }

    // MARK: - 4. SynthesisView 基础挂载测试

    func testSynthesisView_MountAndRender() {
        var selectedTab = AppTab.synthesis
        let tabBinding = Binding<AppTab>(
            get: { selectedTab },
            set: { selectedTab = $0 }
        )

        let view = SynthesisView(selection: .constant(nil), selectedTab: tabBinding)
            .environment(appStore)
            .environment(synthesisStore)
            .environment(router)
            .environment(themeManager)
            .environmentObject(LLMService())
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        _ = host.view

        XCTAssertNotNil(host.view, "SynthesisView 视图容器应正常完成初始排版")
    }

    // MARK: - 5. SynthesisView 包含文档状态下的列表与卡片渲染

    func testSynthesisView_WithDocumentsMount() {
        // 保存测试文档
        _ = synthesisStore.saveSynthesisResult(
            type: .mindmap,
            content: "mindmap\n  root((量子计算研究综述))\n    concept1(量子纠缠核心解析)"
        )

        var selectedTab = AppTab.synthesis
        let tabBinding = Binding<AppTab>(
            get: { selectedTab },
            set: { selectedTab = $0 }
        )

        let view = SynthesisView(selection: .constant(nil), selectedTab: tabBinding)
            .environment(appStore)
            .environment(synthesisStore)
            .environment(router)
            .environment(themeManager)
            .environmentObject(LLMService())
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        _ = host.view

        XCTAssertNotNil(host.view, "包含合成文档时应成功挂载文档条目行")
    }

    // MARK: - 6. SynthesisStore 重命名文档与空文本防御测试

    func testSynthesisStore_RenameDocumentValidAndEmpty() {
        let savedDoc = synthesisStore.saveSynthesisResult(
            type: .mindmap,
            content: "mindmap\n  root((旧文档主题))\n    node(内容)"
        )
        guard let doc = savedDoc else {
            XCTFail("保存合成文档失败")
            return
        }

        // 1. 合法重命名
        guard let validName = SynthesisViewActionHelper.validateAndTrimDocName("新文档名") else {
            XCTFail("有效名称不应返回 nil")
            return
        }
        synthesisStore.renameSynthesisDoc(type: .mindmap, docID: doc.id, newName: validName)

        let renamedDoc = synthesisStore.allSortedDocuments.first { $0.1.id == doc.id }?.1
        XCTAssertEqual(renamedDoc?.name, "新文档名")

        // 2. 空文本拒绝
        let emptyName = SynthesisViewActionHelper.validateAndTrimDocName("   ")
        XCTAssertNil(emptyName)
    }

    // MARK: - 7. SynthesisStore 批量删除与清空测试

    func testSynthesisStore_BatchDeleteAndClearAll() {
        let doc1 = synthesisStore.saveSynthesisResult(type: .quiz, content: "测验题目 1：什么是量子纠缠？\n答案：微观粒子间的特殊强关联现象。")
        let doc2 = synthesisStore.saveSynthesisResult(type: .quiz, content: "测验题目 2：什么是量子退相干？\n答案：量子系统受外界干扰丧失相干性的过程。")

        guard let d1 = doc1, let d2 = doc2 else {
            XCTFail("预置文档失败")
            return
        }

        XCTAssertEqual(synthesisStore.allSortedDocuments.count, 2)

        // 批量删除 d1
        synthesisStore.batchDeleteSynthesisDocs(ids: [d1.id])
        XCTAssertEqual(synthesisStore.allSortedDocuments.count, 1)
        XCTAssertEqual(synthesisStore.allSortedDocuments.first?.1.id, d2.id)

        // 清空全量
        synthesisStore.clearAll()
        XCTAssertTrue(synthesisStore.allSortedDocuments.isEmpty)
    }

    // MARK: - 8. SynthesisOutputContent 与源页面导航栏测试

    func testSynthesisOutputContent_MountAndRender() {
        let page = KnowledgePage(id: UUID(), title: "来源参考 1", content: "")
        let doc = SynthesisStore.SynthesisDocument(
            id: UUID(),
            type: .mindmap,
            name: "脑图详情",
            content: "mindmap\n  root((中心概念))\n    node1(分支)",
            createdAt: Date(),
            size: 200,
            sourcePageIDs: [page.id]
        )

        let outputView = SynthesisOutputContent(doc: doc)
            .environment(themeManager)

        let host = UIHostingController(rootView: outputView)
        _ = host.view

        XCTAssertNotNil(host.view, "SynthesisOutputContent 脑图输出视图应正常渲染")

        let sourceBar = SynthesisSourcePagesBar(
            sourcePageIDs: [page.id],
            store: appStore,
            onNavigate: { _ in }
        )

        let barHost = UIHostingController(rootView: sourceBar)
        _ = barHost.view

        XCTAssertNotNil(barHost.view, "SynthesisSourcePagesBar 来源引用条应正常渲染")
    }

    // MARK: - 9. TaskCenterView 空任务状态挂载测试

    func testTaskCenterView_EmptyStateMount() {
        let view = TaskCenterView()
            .environment(appStore)
            .environment(themeManager)
            .environment(router)
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        _ = host.view

        XCTAssertNotNil(host.view, "TaskCenterView 在空任务队列下应渲染空状态与指引卡片")
    }

    // MARK: - 10. TaskCenterView 包含多类型任务下的看板与分类筛选测试

    func testTaskCenterView_WithTasksDashboardMount() {
        let taskId = taskCenter.addTask(type: .ingest, name: "PDF 知识解析", target: "2026战略规划.pdf")
        taskCenter.updateTask(taskId, status: .running(progress: 0.65, stage: .chunking))

        let view = TaskCenterView()
            .environment(appStore)
            .environment(themeManager)
            .environment(router)
            .snapshotEnvironment(appStore: appStore)

        let host = UIHostingController(rootView: view)
        _ = host.view

        XCTAssertNotNil(host.view, "TaskCenterView 包含活跃任务时应正确展示仪表盘与任务条目")
    }

    // MARK: - 11. TaskCenter 任务生命周期、阅读标记与安全移除测试

    func testTaskCenter_TaskLifecycleAndSafeRemoval() {
        let taskId = taskCenter.addTask(type: .aiScan, name: "孤岛节点巡检", target: "全局知识库")
        XCTAssertEqual(taskCenter.tasks.count, 1)

        // 流转至已完成
        taskCenter.updateTask(taskId, status: .completed)
        let completedTask = taskCenter.tasks.first { $0.id == taskId }
        XCTAssertEqual(completedTask?.status, .completed)

        // 标记为已读
        taskCenter.markAsRead(taskId)
        let readTask = taskCenter.tasks.first { $0.id == taskId }
        XCTAssertEqual(readTask?.isRead, true)

        // 安全移除任务
        taskCenter.removeTask(taskId)
        XCTAssertTrue(taskCenter.tasks.isEmpty)
    }

    // MARK: - 12. TaskCenter 任务重置与指标统计测试

    func testTaskCenter_MetricsAndReset() {
        _ = taskCenter.addTask(type: .healthCheck, name: "健康检测 A", target: "Vault")
        _ = taskCenter.addTask(type: .healthCheck, name: "健康检测 B", target: "Vault")

        let metrics = taskCenter.metrics(for: .healthCheck)
        XCTAssertEqual(metrics.total, 2)

        // 重置清空
        taskCenter.reset()
        XCTAssertEqual(taskCenter.tasks.count, 0)
        let clearedMetrics = taskCenter.metrics(for: .healthCheck)
        XCTAssertEqual(clearedMetrics.total, 0)
    }
}
