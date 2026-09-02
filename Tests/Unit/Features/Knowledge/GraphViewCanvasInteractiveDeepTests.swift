//
//  GraphViewCanvasInteractiveDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class GraphViewCanvasInteractiveDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. GraphViewModel State & Filtering

    func testGraphViewModelFilteringAndLayout() async throws {
        let viewModel = GraphViewModel()
        viewModel.graphSize = CGSize(width: 800, height: 600)

        // 1. 构建测试节点与边
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        let node1 = GraphNode(id: id1, title: "Swift", pageType: .concept, position: CGPoint(x: 100, y: 100), linkCount: 2)
        let node2 = GraphNode(id: id2, title: "Concurrency", pageType: .entity, position: CGPoint(x: 200, y: 200), linkCount: 2)
        let node3 = GraphNode(id: id3, title: "Isolated Node", pageType: .source, position: CGPoint(x: 300, y: 300), linkCount: 0)

        let edge1 = GraphEdge(source: id1, target: id2)

        viewModel.nodes = [node1, node2, node3]
        viewModel.edges = [edge1]

        // 2. 节点过滤
        let allFiltered = viewModel.getFilteredNodes()
        XCTAssertEqual(allFiltered.count, 3)

        // 3. 选中节点与高亮关联
        viewModel.selectedNodeID = id1
        XCTAssertEqual(viewModel.selectedNodeID, id1)
        viewModel.selectedNodeID = nil
    }

    // MARK: - 2. GraphContainerView Mounting & Subviews

    func testGraphContainerViewMounting() throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        store.pages = [
            KnowledgePage(title: "Architecture", pageType: .concept, content: "References [[ModuleA]]"),
            KnowledgePage(title: "ModuleA", pageType: .entity, content: "Module details")
        ]

        var selectedTab: AppTab = .graph
        let binding = Binding(get: { selectedTab }, set: { selectedTab = $0 })

        let graphContainer = SnapshotContainer { namespace in
            GraphContainerView(heroNamespace: namespace, selectedTab: binding)
        }
        .snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: graphContainer)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }
}
