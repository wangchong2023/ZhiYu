//
//  GraphLayoutSupplementTests.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/09/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Test] 单元测试
//  核心职责：GraphLayoutProcessor 补充测试 — Config 默认值、layout 边界条件、applyForces 边界条件
//

import XCTest
import Foundation
import Dependencies
import UFPCore
@testable import ZhiYu

// MARK: - GraphLayoutProcessor 补充测试

final class GraphLayoutProcessorSupplementTests: XCTestCase {

    // MARK: - Config 默认值

    func testConfig_default_hasExpectedValues() {
        let config = GraphLayoutProcessor.Config.default
        XCTAssertEqual(config.iterations, GraphConstants.TwoD.simulationIterations)
        XCTAssertEqual(config.padding, DesignSystem.Graph.layoutPadding)
    }

    func testConfig_customIterations() {
        let config = GraphLayoutProcessor.Config(iterations: 1)
        XCTAssertEqual(config.iterations, 1)
    }

    // MARK: - layout 边界条件
    func testLayout_multiplePages_allNodesHavePositions() {
        let pages = [
            KnowledgePage(title: "Page1"),
            KnowledgePage(title: "Page2"),
            KnowledgePage(title: "Page3")
        ]
        let result = GraphLayoutProcessor.layout(
            pages: pages,
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600),
            config: GraphLayoutProcessor.Config(iterations: 1)
        )
        XCTAssertEqual(result.nodes.count, 3)
        for node in result.nodes {
            XCTAssertFalse(node.position.x.isNaN)
            XCTAssertFalse(node.position.y.isNaN)
        }
    }

    func testLayout_linkedPages_createsEdges() {
        let page1 = KnowledgePage(title: "Page1", content: "[[Page2]]")
        let page2 = KnowledgePage(title: "Page2")
        let pages = [page1, page2]
        let result = GraphLayoutProcessor.layout(
            pages: pages,
            linkResolver: { title in pages.first { $0.title == title } },
            canvasSize: CGSize(width: 800, height: 600),
            config: GraphLayoutProcessor.Config(iterations: 1)
        )
        XCTAssertEqual(result.nodes.count, 2)
        XCTAssertGreaterThanOrEqual(result.edges.count, 1)
    }
    func testLayout_relatedPageIDs_createsEdges() {
        let page2ID = UUID()
        let page1 = KnowledgePage(title: "Page1", relatedPageIDs: [page2ID])
        let page2 = KnowledgePage(id: page2ID, title: "Page2")
        let pages = [page1, page2]
        let result = GraphLayoutProcessor.layout(
            pages: pages,
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600),
            config: GraphLayoutProcessor.Config(iterations: 1)
        )
        XCTAssertEqual(result.edges.count, 1)
    }
    // MARK: - applyForces 边界条件
    func testApplyForces_singleNode_noEdges_staysInBounds() {
        let page = KnowledgePage(title: "Single")
        let initial = GraphLayoutProcessor.layout(
            pages: [page],
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600),
            config: GraphLayoutProcessor.Config(iterations: 1)
        )
        var nodes = initial.nodes
        let originalCount = nodes.count
        GraphLayoutProcessor.applyForces(
            nodes: &nodes,
            edges: [],
            canvasWidth: 800,
            canvasHeight: 600,
            config: .default
        )
        XCTAssertEqual(nodes.count, originalCount)
        for node in nodes {
            XCTAssertGreaterThanOrEqual(node.position.x, 0)
            XCTAssertLessThanOrEqual(node.position.x, 800)
            XCTAssertGreaterThanOrEqual(node.position.y, 0)
            XCTAssertLessThanOrEqual(node.position.y, 600)
        }
    }

    // MARK: - detectCommunities 边界条件
}
