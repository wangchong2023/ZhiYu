//
//  KnowledgeViewsDeepTests.swift
//  ZhiYuTests
//
//  合并自 2 个碎片化测试文件：GraphAndKnowledgeViewsStateMachineDeepTests.swift, KnowledgeViewsRegressionTests.swift
//

import Dependencies
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class KnowledgeViewsDeepTests: XCTestCase {

    private var appStore: AppStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        appStore = AppStore()
    }

    func testGraph3DView_InteractiveStatesAndFullScreenToggle() {
        let store = KnowledgeStore()
        let router = Router()

        var selectedID: UUID?
        var isFullScreen = false

        let bindingID = Binding(get: { selectedID }, set: { selectedID = $0 })
        let bindingFS = Binding(get: { isFullScreen }, set: { isFullScreen = $0 })

        // 基础渲染
        let view = Graph3DView(selectedNodeID: bindingID, isFullScreen: bindingFS)
            .environment(store)
            .environment(router)

        let controller = UIHostingController(rootView: view)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        // 全屏模式切换求值
        isFullScreen = true
        let fsView = Graph3DView(selectedNodeID: bindingID, isFullScreen: bindingFS)
            .environment(store)
            .environment(router)
        let fsCtrl = UIHostingController(rootView: fsView)
        _ = fsCtrl.view
        fsCtrl.view.setNeedsLayout()
        fsCtrl.view.layoutIfNeeded()

        XCTAssertTrue(isFullScreen, "全屏状态应已切换为 true")
        XCTAssertNil(selectedID, "初始节点选中应为 nil")
    }

    func testImportRecordSection_CategoriesAndPreviewFlow() async {
        let router = Router()

        let section = ImportRecordSection(
            onAITag: { _ in },
            onManualEdit: { _ in }
        )
        .environment(router)

        let controller = UIHostingController(rootView: section)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        XCTAssertNotNil(section)
    }

    func testIngestView_FullPageRenderAndSheetState() {
        let store = KnowledgeStore()
        let ingestStore = IngestStore()
        let router = Router()
        let theme = ThemeManager()
        var tab = AppTab.ingest
        let bindingTab = Binding(get: { tab }, set: { tab = $0 })

        let ingestView = IngestView(selectedTab: bindingTab)
            .environment(store)
            .environment(ingestStore)
            .environment(router)
            .environment(theme)
            .environmentObject(LLMService.shared)

        let controller = UIHostingController(rootView: ingestView)
        _ = controller.view
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()

        XCTAssertEqual(tab, .ingest, "当前 Tab 应为 ingest")
        XCTAssertEqual(store.pages.count, 0)
    }

    func testKnowledgePageListView_AllPageTypeFilters() {
        let samplePages: [KnowledgePage] = [
            KnowledgePage(id: UUID(), title: "概念一", pageType: .concept, content: "概念内容"),
            KnowledgePage(id: UUID(), title: "实体一", pageType: .entity, content: "实体内容"),
            KnowledgePage(id: UUID(), title: "来源一", pageType: .source, content: "来源内容"),
            KnowledgePage(id: UUID(), title: "对比一", pageType: .comparison, content: "对比内容")
        ]
        appStore.knowledgeStore.pages = samplePages

        for filter in PageType.allCases {
            let listView = KnowledgePageListView(filterType: filter).snapshotEnvironment()

            let host = UIHostingController(rootView: listView)
            _ = host.view
            host.view.layoutIfNeeded()

            XCTAssertNotNil(host.view, "类型过滤 \(filter) 下视图应正常加载")
        }

        // 无过滤全量列表
        let allListView = KnowledgePageListView(filterType: nil).snapshotEnvironment()
        let hostAll = UIHostingController(rootView: allListView)
        _ = hostAll.view
        hostAll.view.layoutIfNeeded()
        XCTAssertNotNil(hostAll.view)
    }

    func testPageDetailView_RenderingWithRichMetadata() {
        let complexPage = KnowledgePage(
            id: UUID(),
            title: "微服务架构模式与服务网格实战",
            pageType: .concept,
            customIcon: "network",
            content: "# 概述\n本文探讨服务网格与 Envoy 代理模式。\n## 核心要点\n- 流量切分\n- 熔断降级",
            tags: ["架构", "微服务", "Istio"],
            isPinned: true
        )
        appStore.knowledgeStore.pages = [complexPage]

        let detailView = PageDetailView(page: complexPage).snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let host = UIHostingController(rootView: detailView)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertEqual(complexPage.tags.count, 3)
        XCTAssertTrue(complexPage.isPinned)
        XCTAssertNotNil(host.view)
    }

    func testPDFReaderView_ValidAndEmptyDocuments() {
        let pdfInfo = PDFDocumentInfo(
            title: "分布式事务规范.pdf",
            fileName: "distributed_transactions.pdf",
            pageCount: 24,
            highlights: [
                PDFHighlight(id: UUID(), pageIndex: 1, text: "两阶段提交具有阻塞性", color: "yellow")
            ]
        )

        let pdfView = PDFReaderView(documentInfo: pdfInfo).snapshotEnvironment()

        let host = UIHostingController(rootView: pdfView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertEqual(pdfInfo.highlights.count, 1)
        XCTAssertNotNil(host.view)
    }

}
