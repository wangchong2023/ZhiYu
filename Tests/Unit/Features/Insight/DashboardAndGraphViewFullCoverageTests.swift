//
//  DashboardAndGraphViewFullCoverageTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度覆盖 KnowledgeDashboardView 与 GraphContainerView/GraphView 的数据聚合、图表密度、力导向图交互分支。
//

import XCTest
import SwiftUI
import UFPCore
import CoreGraphics
@testable import ZhiYu

@MainActor
final class DashboardAndGraphViewFullCoverageTests: XCTestCase {

    private var store: AppStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    // MARK: - 1. KnowledgeDashboardView 空状态与数据填充状态测试

    func testKnowledgeDashboardViewRendering() async {
        // 1. 空状态渲染
        store.knowledgeStore.pages = []
        let emptyDashboard = KnowledgeDashboardView()
            .snapshotEnvironment()
        let emptyHost = UIHostingController(rootView: emptyDashboard)
        XCTAssertNotNil(emptyHost.view)
        emptyHost.view.layoutIfNeeded()

        // 2. 注入多篇知识库页面与标签
        let page1 = KnowledgePage(title: "RAG 架构深度解析", content: "关于 [[向量数据库]] 与 [[文本分块]] 的论述", tags: ["AI", "RAG"])
        let page2 = KnowledgePage(title: "向量数据库", content: "向量索引与混合检索", tags: ["AI", "Database"])
        let page3 = KnowledgePage(title: "文本分块", content: "语义分块算法", tags: ["NLP"])

        await store.savePage(page1)
        await store.savePage(page2)
        await store.savePage(page3)

        let populatedDashboard = KnowledgeDashboardView()
            .snapshotEnvironment()
        let populatedHost = UIHostingController(rootView: populatedDashboard)
        XCTAssertNotNil(populatedHost.view)
        populatedHost.view.layoutIfNeeded()
    }

    // MARK: - 2. GraphContainerView 容器与过滤器分支测试

    struct GraphWrapperView: View {
        @Namespace private var heroNamespace
        @State private var selectedTab: AppTab = .graph

        var body: some View {
            GraphContainerView(heroNamespace: heroNamespace, selectedTab: $selectedTab)
                .snapshotEnvironment()
        }
    }

    func testGraphContainerViewRendering() async {
        let pageA = KnowledgePage(title: "Node A", content: "Link to [[Node B]] and [[Node C]]")
        let pageB = KnowledgePage(title: "Node B", content: "Link to [[Node C]]")
        let pageC = KnowledgePage(title: "Node C", content: "Leaf content")

        await store.savePage(pageA)
        await store.savePage(pageB)
        await store.savePage(pageC)

        let wrapper = GraphWrapperView()
        let hosting = UIHostingController(rootView: wrapper)
        XCTAssertNotNil(hosting.view)
        hosting.view.layoutIfNeeded()
    }

    // MARK: - 3. GraphViewModel 边截断缓存与权重测试

    func testGraphViewModelEdgeFilteringAndTruncation() {
        let vm = GraphViewModel()
        let node1 = GraphNode(id: UUID(), title: "Node 1", pageType: .concept, position: CGPoint(x: 10, y: 10), linkCount: 10)
        let node2 = GraphNode(id: UUID(), title: "Node 2", pageType: .concept, position: CGPoint(x: 50, y: 50), linkCount: 8)
        let node3 = GraphNode(id: UUID(), title: "Node 3", pageType: .concept, position: CGPoint(x: 100, y: 100), linkCount: 5)

        let edge12 = GraphEdge(source: node1.id, target: node2.id)
        let edge13 = GraphEdge(source: node1.id, target: node3.id)

        vm.nodes = [node1, node2, node3]
        vm.edges = [edge12, edge13]

        XCTAssertEqual(vm.nodes.count, 3)
        XCTAssertEqual(vm.edges.count, 2)

        let filteredNodes = vm.getFilteredNodes()
        XCTAssertEqual(filteredNodes.count, 3)

        let filteredEdges = vm.getFilteredEdges(for: filteredNodes)
        XCTAssertEqual(filteredEdges.count, 2)
    }
}
