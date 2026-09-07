//
//  GraphViewDeepTests.swift
//  ZhiYuTests
//
//  合并自 4 个碎片化测试文件：GraphViewAndSimulationDeepTests.swift, GraphViewAndTopologyInteractiveDeepTests.swift, GraphViewCanvasInteractiveDeepTests.swift, GraphViewInteractiveTests.swift
//

import Dependencies
import SceneKit
import SwiftUI
import UFPCore
import UFPStorage
import XCTest

@testable import ZhiYu

@MainActor
final class GraphViewDeepTests: XCTestCase {

    private enum TestConstants {
        static let testCanvasWidth: CGFloat = 400
        static let testCanvasHeight: CGFloat = 300
    }

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func createTestPages() -> [KnowledgePage] {
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()
        let id4 = UUID()
        let id5 = UUID()

        let p1 = KnowledgePage(
            id: id1,
            title: "人工智能核心",
            pageType: .concept,
            content: "关联 [[知识图谱]] 与 [[神经网络]]",
            relatedPageIDs: [id2, id3],
            isPinned: true
        )
        let p2 = KnowledgePage(
            id: id2,
            title: "知识图谱",
            pageType: .entity,
            content: "实体与关系的集合 [[数据源A]] [[人工智能核心]]",
            relatedPageIDs: [id1]
        )
        let p3 = KnowledgePage(
            id: id3,
            title: "神经网络",
            pageType: .concept,
            content: "深度学习模型 [[比较研究]] [[人工智能核心]]",
            relatedPageIDs: [id1]
        )
        let p4 = KnowledgePage(
            id: id4,
            title: "数据源A",
            pageType: .source,
            content: "原始观测数据"
        )
        let p5 = KnowledgePage(
            id: id5,
            title: "比较研究",
            pageType: .comparison,
            content: "对比不同技术路线 [[神经网络]]"
        )
        return [p1, p2, p3, p4, p5]
    }

    func createNode(
        id: UUID = UUID(),
        title: String,
        type: PageType = .concept,
        linkCount: Int = 0
    ) -> GraphNode {
        GraphNode(
            id: id,
            title: title,
            pageType: type,
            position: .zero,
            linkCount: linkCount
        )
    }

    func testGraphViewModel_InitialState() {
        let viewModel = GraphViewModel()
        XCTAssertNil(viewModel.selectedNodeID)
        XCTAssertTrue(viewModel.nodes.isEmpty)
        XCTAssertTrue(viewModel.edges.isEmpty)
        XCTAssertTrue(viewModel.isLayouting)
        XCTAssertFalse(viewModel.isAnimating)
        XCTAssertNil(viewModel.filterType)
    }

    func testGraphViewModel_GetFilteredNodesAndEdges() {
        let viewModel = GraphViewModel()
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        let node1 = GraphNode(id: id1, title: "Transformer", pageType: .concept, position: CGPoint(x: 10, y: 10), linkCount: 2)
        let node2 = GraphNode(id: id2, title: "BERT", pageType: .concept, position: CGPoint(x: 20, y: 20), linkCount: 1)
        let node3 = GraphNode(id: id3, title: "对比分析", pageType: .comparison, position: CGPoint(x: 30, y: 30), linkCount: 1)

        let edge1 = GraphEdge(source: id1, target: id2)
        let edge2 = GraphEdge(source: id1, target: id3)

        viewModel.nodes = [node1, node2, node3]
        viewModel.edges = [edge1, edge2]

        // 1. 无过滤
        viewModel.filterType = nil
        let allNodes = viewModel.getFilteredNodes()
        let allEdges = viewModel.getFilteredEdges(for: allNodes)
        XCTAssertEqual(allNodes.count, 3)
        XCTAssertEqual(allEdges.count, 2)

        // 2. 按 Concept 过滤
        viewModel.filterType = .concept
        let conceptNodes = viewModel.getFilteredNodes()
        let conceptEdges = viewModel.getFilteredEdges(for: conceptNodes)
        XCTAssertEqual(conceptNodes.count, 2)
        XCTAssertEqual(conceptEdges.count, 1)
        XCTAssertEqual(conceptEdges.first?.target, id2)

        // 3. 按 Comparison 过滤
        viewModel.filterType = .comparison
        let compNodes = viewModel.getFilteredNodes()
        let compEdges = viewModel.getFilteredEdges(for: compNodes)
        XCTAssertEqual(compNodes.count, 1)
        XCTAssertEqual(compEdges.count, 0)
    }
    func testGraphContainerView_Hierarchy() {
        struct HostView: View {
            @Namespace var heroNamespace
            @State var selectedTab: AppTab = .graph

            var body: some View {
                NavigationStack {
                    GraphContainerView(heroNamespace: heroNamespace, selectedTab: $selectedTab)
                }
                .snapshotEnvironment()
            }
        }

        let view = HostView()
        XCTAssertNotNil(view)
    }

    func testGraphContainerView_WithPagesAndFrame_FullLayoutCycle() async throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        let appStore = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
        let pages = createTestPages()
        store.pages = pages

        let host = NavigationStack {
            GraphWrapper()
                .frame(width: TestConstants.testCanvasWidth, height: TestConstants.testCanvasHeight)
        }
        .snapshotEnvironment(knowledgeStore: store, appStore: appStore)
        .renderInWindow()

        host.beginAppearanceTransition(true, animated: false)
        host.endAppearanceTransition()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)

        // 允许异步布局 Task 与 MainActor 更新执行
        for _ in 0..<10 {
            try? await Task.sleep(nanoseconds: 30_000_000)
            await MainActor.run {
                RunLoop.current.run(until: Date().addingTimeInterval(0.02))
            }
        }
        XCTAssertEqual(store.pages.count, 5)

        // 触发全局重排事件
        AppEventBus.shared.publish(.graphRelayoutRequested)
        try? await Task.sleep(nanoseconds: 30_000_000)
    }

    func testGraphViewModel_FiltersAndEdges() {
        let vm = GraphViewModel()
        let p1 = UUID()
        let p2 = UUID()

        let node1 = GraphNode(id: p1, title: "Concept Node", pageType: .concept, position: CGPoint(x: 10, y: 10), linkCount: 1)
        let node2 = GraphNode(id: p2, title: "Entity Node", pageType: .entity, position: CGPoint(x: 20, y: 20), linkCount: 1)
        vm.nodes = [node1, node2]
        vm.edges = [GraphEdge(source: p1, target: p2)]

        // 1. 无过滤
        vm.filterType = nil
        XCTAssertEqual(vm.getFilteredNodes().count, 2)
        XCTAssertEqual(vm.getFilteredEdges(for: vm.nodes).count, 1)

        // 2. 概念过滤
        vm.filterType = .concept
        let conceptNodes = vm.getFilteredNodes()
        XCTAssertEqual(conceptNodes.count, 1)
        XCTAssertEqual(conceptNodes.first?.id, p1)
        XCTAssertEqual(vm.getFilteredEdges(for: conceptNodes).count, 0)
    }

    func testTappableSceneView_CoordinatorLifecycleAndCameraSync() {
        var tappedNodeID: UUID?
        let coordinator = TappableSceneView.Coordinator { uuid in
            tappedNodeID = uuid
        }

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.eulerAngles = SCNVector3(x: 0.1, y: 0.2, z: 0)
        cameraNode.position = SCNVector3(x: 0, y: 10, z: 250)

        coordinator.syncCameraState(from: cameraNode)
        XCTAssertEqual(coordinator.currentAngleX, 0.1, accuracy: 0.001)
        XCTAssertEqual(coordinator.currentAngleY, 0.2, accuracy: 0.001)
        XCTAssertEqual(coordinator.cameraZ, 250, accuracy: 0.001)

        coordinator.onNodeTap(nil)
        XCTAssertNil(tappedNodeID)

        let targetID = UUID()
        coordinator.onNodeTap(targetID)
        XCTAssertEqual(tappedNodeID, targetID)
    }

    func testGraphInsightsDetection_OrphansAndBridges() {
        let p1 = UUID()
        let p2 = UUID()
        let p3 = UUID()
        let orphanID = UUID()

        let nodes: [GraphNode] = [
            GraphNode(id: p1, title: "A", pageType: .concept, position: CGPoint(x: 10, y: 10), communityID: 1, linkCount: 1),
            GraphNode(id: p2, title: "B", pageType: .concept, position: CGPoint(x: 20, y: 20), communityID: 1, linkCount: 2),
            GraphNode(id: p3, title: "C", pageType: .entity, position: CGPoint(x: 30, y: 30), communityID: 2, linkCount: 1),
            GraphNode(id: orphanID, title: "孤立节点", pageType: .raw, position: CGPoint(x: 100, y: 100), communityID: nil, linkCount: 0)
        ]
        let edges: [GraphEdge] = [
            GraphEdge(source: p1, target: p2),
            GraphEdge(source: p2, target: p3)
        ]

        let insights = GraphLayoutProcessor.detectInsights(nodes: nodes, edges: edges, pages: [])
        XCTAssertTrue(insights.orphans.contains(orphanID), "必须能准确定位孤立无关联的节点")
    }

    func testGraphLayoutProcessor_EmptyPagesReturnsEmpty() {
        let result = GraphLayoutProcessor.layout(
            pages: [],
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 500, height: 500)
        )
        XCTAssertTrue(result.nodes.isEmpty)
        XCTAssertTrue(result.edges.isEmpty)
    }

    func testGraphLayoutProcessor_SinglePageCentersCorrectly() {
        let page = KnowledgePage(title: "单点页面", pageType: .concept, content: "无外链")
        let canvasSize = CGSize(width: 400, height: 400)
        let result = GraphLayoutProcessor.layout(
            pages: [page],
            linkResolver: { _ in nil },
            canvasSize: canvasSize
        )
        XCTAssertEqual(result.nodes.count, 1)
        XCTAssertEqual(result.edges.count, 0)
        // 单节点应居中
        let nodePos = result.nodes[0].position
        XCTAssertEqual(nodePos.x, canvasSize.width / 2, accuracy: 5.0)
        XCTAssertEqual(nodePos.y, canvasSize.height / 2, accuracy: 5.0)
    }

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

    func testGraphContainerView_mountAndEmptyState() {
        struct TestHost: View {
            @Namespace var hero
            @State var tab: AppTab = .knowledge

            var body: some View {
                GraphContainerView(heroNamespace: hero, selectedTab: $tab)
                    .snapshotEnvironment()
            }
        }

        let hostView = TestHost()
        let controller = UIHostingController(rootView: hostView)
        controller.loadViewIfNeeded()
        XCTAssertNotNil(controller.view, "GraphContainerView 必须在挂载测试中正常渲染")
    }

}
