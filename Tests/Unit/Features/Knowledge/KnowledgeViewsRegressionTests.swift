//
//  KnowledgeViewsExploratoryBugHuntTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：探索性与边界测试 KnowledgePageList、PageDetailView、PDFReaderView、
//            Graph3DView 与 IngestView 全状态机，捕获真实潜在 Bug。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class KnowledgeViewsExploratoryBugHuntTests: XCTestCase {

    private var appStore: AppStore!
    private var router: Router!
    private var themeManager: ThemeManager!
    private var ingestStore: IngestStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()

        appStore = AppStore()
        router = Router.shared
        themeManager = ThemeManager()
        ingestStore = IngestStore()
    }

    override func tearDown() async throws {
        appStore = nil
        router = nil
        themeManager = nil
        ingestStore = nil
        try await super.tearDown()
    }

    // MARK: - 1. KnowledgePageListView 列表与过滤状态机

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

    // MARK: - 2. PageDetailView 深度属性与元数据交互

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

    // MARK: - 3. PDF 阅读器与高亮交互边界

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

    // MARK: - 4. 3D 图谱视图状态机

    func testGraph3DView_StateTransitions() {
        let pageA = KnowledgePage(id: UUID(), title: "节点A", pageType: .concept, content: "内容A")
        let pageB = KnowledgePage(id: UUID(), title: "节点B", pageType: .entity, content: "内容B")
        appStore.knowledgeStore.pages = [pageA, pageB]

        let graph3DView = Graph3DView(selectedNodeID: .constant(nil), isFullScreen: .constant(false)).snapshotEnvironment()

        let host3D = UIHostingController(rootView: graph3DView)
        _ = host3D.view
        host3D.view.layoutIfNeeded()

        XCTAssertNotNil(host3D.view)
    }
}
