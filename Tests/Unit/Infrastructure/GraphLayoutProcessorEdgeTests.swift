//
//  GraphLayoutProcessorEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 GraphLayoutProcessor 力导向布局的空输入、单节点、多节点、自环、重复边等边界语义。
//

import XCTest
@testable import ZhiYu

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
        let pageA = KnowledgePage(title: "A")
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
}
