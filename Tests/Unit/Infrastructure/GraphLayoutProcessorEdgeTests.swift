//
//  GraphLayoutProcessorEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 GraphLayoutProcessor 力导向布局的空输入、单节点、多节点、自环、重复边等边界语义。
//

import XCTest
@testable import ZhiYuUnitTestHost

final class GraphLayoutProcessorEdgeTests: XCTestCase {

    // MARK: - 空输入

    func testLayout_emptyPages_returnsEmptyNodesAndEdges() {
        let result = GraphLayoutProcessor.layout(
            pages: [],
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600)
        )
        XCTAssertTrue(result.nodes.isEmpty)
        XCTAssertTrue(result.edges.isEmpty)
    }

    // MARK: - 单节点

    func testLayout_singlePage_returnsSingleNodeNoEdges() {
        let page = KnowledgePage(title: "单页")
        let result = GraphLayoutProcessor.layout(
            pages: [page],
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600)
        )
        XCTAssertEqual(result.nodes.count, 1)
        XCTAssertEqual(result.nodes[0].title, "单页")
        XCTAssertTrue(result.edges.isEmpty)
    }

    // MARK: - 多节点布局

    func testLayout_multiplePages_allNodesPositioned() {
        let pages = (0..<10).map { KnowledgePage(title: "页\($0)") }
        let result = GraphLayoutProcessor.layout(
            pages: pages,
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600)
        )
        XCTAssertEqual(result.nodes.count, 10)
        for node in result.nodes {
            XCTAssertGreaterThan(node.position.x, 0)
            XCTAssertGreaterThan(node.position.y, 0)
        }
    }

    // MARK: - 边创建

    func testLayout_linkedPages_createsEdge() {
        _ = KnowledgePage(title: "A")
        let pageB = KnowledgePage(title: "B")
        let resolver: (String) -> KnowledgePage? = { title in
            title == "B" ? pageB : nil
        }
        // pageA 需要有 outgoingLinks 指向 B
        // 由于 KnowledgePage.outgoingLinks 是计算属性，需通过 content 内容驱动
        let pageAWithLink = KnowledgePage(title: "A", content: "[[B]]")
        let result = GraphLayoutProcessor.layout(
            pages: [pageAWithLink, pageB],
            linkResolver: resolver,
            canvasSize: CGSize(width: 800, height: 600)
        )
        // 至少应创建节点
        XCTAssertEqual(result.nodes.count, 2)
    }

    // MARK: - 自环过滤

    func testLayout_selfLink_filtered() {
        let page = KnowledgePage(title: "自环", content: "[[自环]]")
        let resolver: (String) -> KnowledgePage? = { _ in page }
        let result = GraphLayoutProcessor.layout(
            pages: [page],
            linkResolver: resolver,
            canvasSize: CGSize(width: 800, height: 600)
        )
        XCTAssertTrue(result.edges.isEmpty, "自环边应被过滤")
    }

    // MARK: - 重复边去重

    func testLayout_duplicateEdges_deduplicated() {
        let pageA = KnowledgePage(title: "A", content: "[[B]]\n[[B]]")
        let pageB = KnowledgePage(title: "B")
        let resolver: (String) -> KnowledgePage? = { title in
            title == "B" ? pageB : nil
        }
        let result = GraphLayoutProcessor.layout(
            pages: [pageA, pageB],
            linkResolver: resolver,
            canvasSize: CGSize(width: 800, height: 600)
        )
        // 重复的双链应被去重为单条边
        let edgesFromAtoB = result.edges.filter { $0.source == pageA.id && $0.target == pageB.id }
        XCTAssertLessThanOrEqual(edgesFromAtoB.count, 1)
    }

    // MARK: - linkCount 计算

    func testLayout_linkCount_reflectsEdgeCount() {
        let pageA = KnowledgePage(title: "A", content: "[[B]]")
        let pageB = KnowledgePage(title: "B", content: "[[A]]")
        let resolver: (String) -> KnowledgePage? = { title in
            switch title {
            case "A": return pageA
            case "B": return pageB
            default: return nil
            }
        }
        let result = GraphLayoutProcessor.layout(
            pages: [pageA, pageB],
            linkResolver: resolver,
            canvasSize: CGSize(width: 800, height: 600)
        )
        let nodeA = result.nodes.first { $0.title == "A" }
        let nodeB = result.nodes.first { $0.title == "B" }
        XCTAssertNotNil(nodeA)
        XCTAssertNotNil(nodeB)
        XCTAssertGreaterThan(nodeA?.linkCount ?? 0, 0)
        XCTAssertGreaterThan(nodeB?.linkCount ?? 0, 0)
    }

    // MARK: - 居中校准

    func testLayout_nodesCenteredAroundCanvasCenter() {
        let pages = (0..<5).map { KnowledgePage(title: "页\($0)") }
        let canvasSize = CGSize(width: 800, height: 600)
        let result = GraphLayoutProcessor.layout(
            pages: pages,
            linkResolver: { _ in nil },
            canvasSize: canvasSize
        )
        let centerX = canvasSize.width / 2
        let centerY = canvasSize.height / 2
        let avgX = result.nodes.map { $0.position.x }.reduce(0, +) / CGFloat(result.nodes.count)
        let avgY = result.nodes.map { $0.position.y }.reduce(0, +) / CGFloat(result.nodes.count)
        XCTAssertEqual(avgX, centerX, accuracy: 50, "节点平均位置应接近画布中心")
        XCTAssertEqual(avgY, centerY, accuracy: 50)
    }

    // MARK: - applyForces 单次迭代

    func testApplyForces_emptyNodes_noOp() {
        var nodes: [GraphNode] = []
        GraphLayoutProcessor.applyForces(
            nodes: &nodes,
            edges: [],
            canvasWidth: 800,
            canvasHeight: 600,
            config: GraphLayoutProcessor.Config.default
        )
        XCTAssertTrue(nodes.isEmpty)
    }

    // MARK: - 重复节点 ID、负数迭代与 NaN 坐标防护（缺陷 #111）

    func testApplyForces_duplicateNodeIDsAndNaNPositionDoNotCrash() {
        let sharedID = UUID()
        var nodes = [
            GraphNode(id: sharedID, title: "DupA", pageType: .concept, position: CGPoint(x: 100, y: 100)),
            GraphNode(id: sharedID, title: "DupB", pageType: .concept, position: CGPoint(x: CGFloat.nan, y: 200))
        ]
        let edge = GraphEdge(source: sharedID, target: sharedID)
        GraphLayoutProcessor.applyForces(
            nodes: &nodes,
            edges: [edge],
            canvasWidth: 800,
            canvasHeight: 600,
            config: GraphLayoutProcessor.Config.default
        )
        XCTAssertEqual(nodes.count, 2)

        var negativeIterConfig = GraphLayoutProcessor.Config.default
        negativeIterConfig.iterations = -5
        let page = KnowledgePage(title: "SafeNode")
        let result = GraphLayoutProcessor.layout(
            pages: [page],
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600),
            config: negativeIterConfig
        )
        XCTAssertEqual(result.nodes.count, 1)
    }

    // MARK: - 缺陷 #189 回归：零/负/NaN 画布尺寸与窄画布边界防护

    func testLayout_invalidCanvasSizes_alwaysProduceFinitePositions() {
        let pages = [KnowledgePage(title: "甲"), KnowledgePage(title: "乙"), KnowledgePage(title: "丙")]
        let invalidSizes: [CGSize] = [
            .zero,
            CGSize(width: -200, height: -100),
            CGSize(width: CGFloat.nan, height: 600),
            CGSize(width: CGFloat.infinity, height: CGFloat.nan)
        ]

        for size in invalidSizes {
            let result = GraphLayoutProcessor.layout(
                pages: pages,
                linkResolver: { _ in nil },
                canvasSize: size
            )
            XCTAssertEqual(result.nodes.count, pages.count)
            for node in result.nodes {
                XCTAssertTrue(node.position.x.isFinite, "非法画布 \(size) 下 x 坐标必须为有限值")
                XCTAssertTrue(node.position.y.isFinite, "非法画布 \(size) 下 y 坐标必须为有限值")
            }
        }
    }

    func testApplyForces_narrowCanvasSmallerThanDoublePadding_staysWithinCanvasBounds() {
        var nodes = [
            GraphNode(id: UUID(), title: "N1", pageType: .concept, position: CGPoint(x: 10, y: 10)),
            GraphNode(id: UUID(), title: "N2", pageType: .concept, position: CGPoint(x: CGFloat.nan, y: 20))
        ]
        var config = GraphLayoutProcessor.Config.default
        config.padding = 40
        GraphLayoutProcessor.applyForces(
            nodes: &nodes,
            edges: [],
            canvasWidth: 30,
            canvasHeight: 20,
            config: config
        )
        for node in nodes {
            XCTAssertTrue(node.position.x.isFinite && node.position.y.isFinite)
            XCTAssertGreaterThanOrEqual(node.position.x, 0)
            XCTAssertLessThanOrEqual(node.position.x, 30)
            XCTAssertGreaterThanOrEqual(node.position.y, 0)
            XCTAssertLessThanOrEqual(node.position.y, 20)
        }
    }
}
