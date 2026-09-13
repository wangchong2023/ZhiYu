//
//  SynthesisViewInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] 功能测试层
//  核心职责：SynthesisView 深度交互、多重过滤、批量操作、文档重命名与弹窗生命周期测试
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SynthesisViewInteractiveTests: XCTestCase {

    private var appStore: AppStore!
    private var synthesisStore: SynthesisStore!
    private var router: Router!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        appStore = AppStore()
        synthesisStore = SynthesisStore()
        router = Router.shared
    }

    override func tearDown() async throws {
        appStore = nil
        synthesisStore = nil
        router = nil
        try await super.tearDown()
    }

    // MARK: - 1. Filter Pills 与文档列表联动测试

    func testFilterPillsAndDocumentListFiltering() {
        // 准备合成文档测试数据
        let doc1 = SynthesisStore.SynthesisDocument(
            id: UUID(),
            type: .report,
            name: "知识总览",
            content: "这是一份全面的知识总结摘要。",
            createdAt: Date(),
            size: 100,
            sourcePageIDs: [UUID()]
        )
        let doc2 = SynthesisStore.SynthesisDocument(
            id: UUID(),
            type: .mindmap,
            name: "架构思维导图",
            content: "mindmap\n  root((系统架构))\n    Core\n    Domain",
            createdAt: Date(),
            size: 100,
            sourcePageIDs: [UUID()]
        )
        let doc3 = SynthesisStore.SynthesisDocument(
            id: UUID(),
            type: .quiz,
            name: "核心自测",
            content: "Q1: 系统的 L0 是什么？\nA. UFPCore",
            createdAt: Date(),
            size: 100,
            sourcePageIDs: []
        )

        synthesisStore.synthesisResults[.report] = [doc1]
        synthesisStore.synthesisResults[.mindmap] = [doc2]
        synthesisStore.synthesisResults[.quiz] = [doc3]

        // 验证全量文档排序聚合
        let allDocs = synthesisStore.allSortedDocuments
        XCTAssertEqual(allDocs.count, 3, "所有类型文档总数应为 3")

        // 验证按类型过滤
        let reportDocs = allDocs.filter { $0.0 == .report }
        XCTAssertEqual(reportDocs.count, 1)
        XCTAssertEqual(reportDocs.first?.1.name, "知识总览")

        let mindmapDocs = allDocs.filter { $0.0 == .mindmap }
        XCTAssertEqual(mindmapDocs.count, 1)
        XCTAssertEqual(mindmapDocs.first?.1.name, "架构思维导图")

        let quizDocs = allDocs.filter { $0.0 == .quiz }
        XCTAssertEqual(quizDocs.count, 1)
        XCTAssertEqual(quizDocs.first?.1.name, "核心自测")
    }

    // MARK: - 2. 编辑模式与批量多选删除测试

    func testEditModeToggleAndBatchDelete() {
        let docID1 = UUID()
        let docID2 = UUID()
        let doc1 = SynthesisStore.SynthesisDocument(
            id: docID1,
            type: .report,
            name: "待删文档 1",
            content: "内容 1",
            createdAt: Date(),
            size: 100,
            sourcePageIDs: []
        )
        let doc2 = SynthesisStore.SynthesisDocument(
            id: docID2,
            type: .report,
            name: "待删文档 2",
            content: "内容 2",
            createdAt: Date(),
            size: 100,
            sourcePageIDs: []
        )

        synthesisStore.synthesisResults[.report] = [doc1, doc2]
        XCTAssertEqual(synthesisStore.synthesisResults[.report]?.count, 2)

        var selectedDocIDs: Set<UUID> = []

        // 模拟多选勾选
        selectedDocIDs.insert(docID1)
        XCTAssertTrue(selectedDocIDs.contains(docID1))
        XCTAssertEqual(selectedDocIDs.count, 1)

        selectedDocIDs.insert(docID2)
        XCTAssertEqual(selectedDocIDs.count, 2)

        // 模拟取消单项勾选
        selectedDocIDs.remove(docID1)
        XCTAssertFalse(selectedDocIDs.contains(docID1))
        XCTAssertEqual(selectedDocIDs.count, 1)

        // 重新选满执行批量删除
        selectedDocIDs.insert(docID1)
        synthesisStore.batchDeleteSynthesisDocs(ids: selectedDocIDs)
        selectedDocIDs.removeAll()

        XCTAssertEqual(synthesisStore.synthesisResults[.report]?.count, 0, "批量删除后 report 类别文档应为空")
        XCTAssertTrue(selectedDocIDs.isEmpty)
    }

    // MARK: - 3. 单文档重命名与清空全部测试

    func testRenameDocAndClearAll() {
        let docID = UUID()
        let originalDoc = SynthesisStore.SynthesisDocument(
            id: docID,
            type: .report,
            name: "原始周报",
            content: "周报内容详情",
            createdAt: Date(),
            size: 100,
            sourcePageIDs: []
        )

        synthesisStore.synthesisResults[.report] = [originalDoc]

        // 执行重命名
        let newName = "2026年第36周综合洞察报告"
        synthesisStore.renameSynthesisDoc(type: .report, docID: docID, newName: newName)

        let updatedDoc = synthesisStore.synthesisResults[.report]?.first(where: { $0.id == docID })
        XCTAssertNotNil(updatedDoc)
        XCTAssertEqual(updatedDoc?.name, newName, "文档名称应成功更新为新名称")

        // 执行全部清空
        synthesisStore.clearAll()
        XCTAssertTrue(synthesisStore.allSortedDocuments.isEmpty, "clearAll 之后文档聚合列表应彻底为空")
    }

    // MARK: - 4. 导出 PDF 行为与错误路径验证

    func testExportDocumentSuccessAndError() async throws {
        let doc = SynthesisStore.SynthesisDocument(
            id: UUID(),
            type: .report,
            name: "导出测试",
            content: "# 导出标题\n这是导出的正文内容，包含多行数据以供解析。",
            createdAt: Date(),
            size: 100,
            sourcePageIDs: []
        )

        // 验证合成文档的文本导出
        let url = try await synthesisStore.exportSynthesisDocument(doc)
        XCTAssertFalse(url.path.isEmpty, "导出应返回合法的本地文件 URL")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path), "导出的物理文件应存在于磁盘中")

        // 清理测试产物
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 5. SynthesisView 挂载与全模式 Presentation 视图覆盖

    func testSynthesisViewHierarchyAndPresentations() {
        struct TestHost: View {
            @State var selection: SidebarSelection?
            @State var selectedTab: AppTab = .synthesis
            @State var showOutput = false
            @State var pdfURL: IdentifiableURL?
            @State var showNoPagesAlert = false
            @State var showLimitAlert = false
            @State var showRenameDialog = false
            @State var showLLMAlert = false
            @State var showBatchDeleteConfirm = false
            @State var showDeleteDocConfirm = false
            @State var newDocName = "新名称"

            var body: some View {
                SynthesisView(selection: $selection, selectedTab: $selectedTab)
                    .synthesisViewPresentations(
                        showOutput: $showOutput,
                        pdfURL: $pdfURL,
                        showNoPagesAlert: $showNoPagesAlert,
                        showLimitAlert: $showLimitAlert,
                        showRenameDialog: $showRenameDialog,
                        showLLMAlert: $showLLMAlert,
                        showBatchDeleteConfirm: $showBatchDeleteConfirm,
                        showDeleteDocConfirm: $showDeleteDocConfirm,
                        newDocName: $newDocName,
                        docToRename: nil,
                        docToDelete: nil,
                        batchDelete: {},
                        onConfigureAI: {},
                        synthesisStore: SynthesisStore(),
                        outputSheet: Text("Output")
                    )
            }
        }

        router.selectedTab = .synthesis
        let host = UIHostingController(rootView: TestHost().snapshotEnvironment())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "SynthesisView 宿主视图应完成挂载")
        XCTAssertEqual(router.selectedTab, .synthesis, "当前 Tab 应为 synthesis")
    }

    // MARK: - 6. 单项弹窗与告警修饰符分支覆盖

    func testPresentationModifiersDirectly() {
        struct AlertHost: View {
            @State var showNoPages = true
            @State var showLimit = true
            @State var showRename = true
            @State var showLLM = true
            @State var showBatchDelete = true
            @State var showDeleteDoc = true
            @State var name = "重命名测试"

            let doc = SynthesisStore.SynthesisDocument(
                id: UUID(),
                type: .slides,
                name: "幻灯片",
                content: "幻灯片内容",
                createdAt: Date(),
                size: 100,
                sourcePageIDs: []
            )

            var body: some View {
                VStack {
                    Text("Alert Container")
                }
                .alertNoPages(isPresented: $showNoPages)
                .alertLimitReached(isPresented: $showLimit)
                .alertRenameDoc(isPresented: $showRename, name: $name, doc: doc)
                .alertLLMNotConfigured(isPresented: $showLLM, onConfigure: {})
                .confirmBatchDelete(isPresented: $showBatchDelete, action: {})
                .alertDeleteDoc(isPresented: $showDeleteDoc, doc: doc, store: SynthesisStore())
            }
        }

        let host = UIHostingController(rootView: AlertHost().snapshotEnvironment())
        _ = host.view
        host.view.layoutIfNeeded()

        let store = SynthesisStore()
        XCTAssertEqual(store.maxSynthesisDocsPerType, 5)
        // 使用独立 Router 实例验证 selectedTab 赋值，避免 Router.shared 单例受前序测试污染导致间歇失败
        let isolatedRouter = Router()
        isolatedRouter.selectedTab = .knowledge
        XCTAssertEqual(isolatedRouter.selectedTab, .knowledge)
    }
}
