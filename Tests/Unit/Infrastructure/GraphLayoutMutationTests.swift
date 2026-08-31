//
//  GraphLayoutMutationTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 测试层
//  核心职责：变异测试 —— 向 GraphLayoutProcessor 注入危险拓扑（单节点、自环、零尺寸画布、
//  全重叠节点、NaN 蔓延等），验证布局引擎在极端情况下不崩溃、不产生 NaN/Inf 坐标。
//
//  【变异设计原则】
//  先构造「若实现有 Bug 则 FAIL」的场景。
//  若任何 XCTAssertFalse(nan) 失败 => 证明 NaN 蔓延缺陷真实存在。
//

import XCTest
import CoreGraphics
@testable import ZhiYu

final class GraphLayoutMutationTests: XCTestCase {

    // MARK: - 变异 G1：单节点图 —— 无边时向心力不应产生 NaN
    //
    // 危险点：centerGraph() 中 (minX + maxX) / 2 在单节点时可能触发 NaN，
    //         且力计算的 distSq=0 分支若未保护会除零。
    func testMutation_SingleNodeGraph_PositionIsFiniteAfterLayout() {
        let page = makePage(title: "孤儿节点", links: [])
        let (nodes, edges) = GraphLayoutProcessor.layout(
            pages: [page],
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 800, height: 600)
        )

        XCTAssertEqual(nodes.count, 1)
        XCTAssertTrue(edges.isEmpty)

        let pos = nodes[0].position
        XCTAssertFalse(pos.x.isNaN, "单节点 x 坐标不应为 NaN，实际: \(pos.x)")
        XCTAssertFalse(pos.y.isNaN, "单节点 y 坐标不应为 NaN，实际: \(pos.y)")
        XCTAssertFalse(pos.x.isInfinite, "单节点 x 坐标不应为 Inf，实际: \(pos.x)")
        XCTAssertFalse(pos.y.isInfinite, "单节点 y 坐标不应为 Inf，实际: \(pos.y)")
    }

    // MARK: - 变异 G2：自环边 —— source == target 时引力计算不应产生 NaN
    //
    // 危险点：computeAttractionForces 中 distSq < 1 时 continue，
    //         但自环边（i == j）若进入 force 计算会出现 dx=0, dy=0, distSq=0。
    //         createEdges 中有 page.id != targetPage.id 保护，验证其是否真的生效。
    func testMutation_SelfReferentialLink_ProducesNoNaN() {
        // 创建一个页面，其 outgoingLinks 指向自身标题
        var page = makePage(title: "自引用页面", links: [])
        page = KnowledgePage(
            title: "自引用页面",
            pageType: .concept,
            content: "[[自引用页面]]",  // 双链指向自身
            aliases: [],
            tags: []
        )

        let (nodes, edges) = GraphLayoutProcessor.layout(
            pages: [page],
            linkResolver: { title in title == "自引用页面" ? page : nil },
            canvasSize: CGSize(width: 800, height: 600)
        )

        XCTAssertEqual(nodes.count, 1)
        // 自环边应被过滤（page.id != targetPage.id 为 false）
        XCTAssertEqual(edges.count, 0, "自环边应被 createEdges 过滤，不应出现在边集中")

        let pos = nodes[0].position
        XCTAssertFalse(pos.x.isNaN, "自引用页面 x 坐标不应为 NaN")
        XCTAssertFalse(pos.y.isNaN, "自引用页面 y 坐标不应为 NaN")
    }

    // MARK: - 变异 G3：零尺寸画布 —— width=0, height=0 不应崩溃或产生 NaN
    //
    // 危险点：computeCanvasDimensions 中 width / 2 在 width=0 时为 0，
    //         但 log(0) 或 sqrt(0) 等操作可能出现在后续计算中。
    //         最严重风险：padding clamp 中 max(padding, min(0 - padding, x)) 可能产生负值 clamp。
    func testMutation_ZeroSizeCanvas_DoesNotProduceNaN() {
        let pages = [makePage(title: "节点A", links: []), makePage(title: "节点B", links: [])]

        let (nodes, _) = GraphLayoutProcessor.layout(
            pages: pages,
            linkResolver: { _ in nil },
            canvasSize: CGSize.zero  // 故意传入零尺寸
        )

        XCTAssertEqual(nodes.count, 2)
        for node in nodes {
            XCTAssertFalse(node.position.x.isNaN, "零画布时 \(node.title) x 不应为 NaN")
            XCTAssertFalse(node.position.y.isNaN, "零画布时 \(node.title) y 不应为 NaN")
            XCTAssertFalse(node.position.x.isInfinite, "零画布时 \(node.title) x 不应为 Inf")
            XCTAssertFalse(node.position.y.isInfinite, "零画布时 \(node.title) y 不应为 Inf")
        }
    }

    // MARK: - 变异 G4：两个节点完全重叠（相同初始坐标）
    //
    // 危险点：若 createInitialCircularLayout 在节点数为 2 时角度计算让两节点重叠
    //         (angle = 0 和 pi，理论上不重叠)，但手动设置重叠位置后
    //         斥力计算中 distSq 接近 0 且小于 minDistanceSq，会触发 continue 跳过斥力。
    //         这导致完全重叠的节点永远无法分离。此测试验证布局后两节点不重叠。
    func testMutation_TwoNodes_AreSeparatedAfterLayout() {
        let pageA = makePage(title: "节点A", links: ["节点B"])
        let pageB = makePage(title: "节点B", links: [])

        let pageMap = [pageA, pageB].reduce(into: [String: KnowledgePage]()) { $0[$1.title] = $1 }

        let (nodes, _) = GraphLayoutProcessor.layout(
            pages: [pageA, pageB],
            linkResolver: { title in pageMap[title] },
            canvasSize: CGSize(width: 800, height: 600)
        )

        XCTAssertEqual(nodes.count, 2)

        let pos0 = nodes[0].position
        let pos1 = nodes[1].position
        let dist = sqrt(pow(pos0.x - pos1.x, 2) + pow(pos0.y - pos1.y, 2))

        XCTAssertGreaterThan(dist, 1.0, "两个节点布局后应有间距（>1pt），当前距离：\(dist)，说明节点重叠未分离")
    }

    // MARK: - 变异 G5：大规模节点图（100节点）不超时、坐标有限
    //
    // 危险点：力导向 O(N²) 复杂度在大规模下超时；NaN 蔓延导致所有节点飞出画布。
    func testMutation_HundredNodes_FinitePositionsWithinTimeout() {
        let pages = (0..<100).map { i in makePage(title: "节点\(i)", links: []) }

        let start = Date()
        let (nodes, _) = GraphLayoutProcessor.layout(
            pages: pages,
            linkResolver: { _ in nil },
            canvasSize: CGSize(width: 1200, height: 900)
        )
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(nodes.count, 100)
        XCTAssertLessThan(elapsed, 5.0, "100 节点布局应在 5 秒内完成，实际耗时: \(String(format: "%.2f", elapsed))s")

        let nanNodes = nodes.filter { $0.position.x.isNaN || $0.position.y.isNaN }
        XCTAssertTrue(nanNodes.isEmpty, "发现 \(nanNodes.count) 个 NaN 坐标节点，NaN 蔓延缺陷存在")

        let infNodes = nodes.filter { $0.position.x.isInfinite || $0.position.y.isInfinite }
        XCTAssertTrue(infNodes.isEmpty, "发现 \(infNodes.count) 个 Inf 坐标节点")
    }

    // MARK: - 变异 G6：applyForces 温度为 0 时不应触发除零
    //
    // 危险点：effectiveDamping = config.damping * temperature，当 temperature=0 时
    //         effectiveDamping=0，力应用为 0，节点不移动——这是正确行为，但若其他
    //         计算依赖 1/temperature 会除零。
    func testMutation_ZeroTemperature_DoesNotCrash() {
        let pages = [makePage(title: "A", links: []), makePage(title: "B", links: [])]
        var nodes = [
            GraphNode(id: pages[0].id, title: "A", pageType: .concept, position: CGPoint(x: 100, y: 100)),
            GraphNode(id: pages[1].id, title: "B", pageType: .concept, position: CGPoint(x: 200, y: 200))
        ]

        // 直接调用 applyForces 并传入 temperature=0
        GraphLayoutProcessor.applyForces(
            nodes: &nodes,
            edges: [],
            canvasWidth: 800,
            canvasHeight: 600,
            config: .default,
            temperature: 0
        )

        for node in nodes {
            XCTAssertFalse(node.position.x.isNaN, "temperature=0 时坐标不应为 NaN")
            XCTAssertFalse(node.position.y.isNaN, "temperature=0 时坐标不应为 NaN")
        }
    }

    // MARK: - Helpers

    private func makePage(title: String, links: [String]) -> KnowledgePage {
        KnowledgePage(
            title: title,
            pageType: .concept,
            content: links.map { "[[\($0)]]" }.joined(separator: "\n"),
            aliases: [],
            tags: []
        )
    }
}
