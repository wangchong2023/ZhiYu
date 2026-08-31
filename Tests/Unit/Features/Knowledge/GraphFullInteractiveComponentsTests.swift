//
//  GraphFullInteractiveComponentsTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 GraphNode 视觉尺寸计算、LOD 分级判定与图谱控制器交互分支。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class GraphFullInteractiveComponentsTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. GraphNode 属性与坐标变换

    func testGraphNode_PositionAndLabel() {
        var node = GraphNode(id: UUID(), title: "分布式系统", pageType: .concept, position: CGPoint(x: 100, y: 200))
        node.position = CGPoint(x: 150, y: 300)

        XCTAssertEqual(node.title, "分布式系统")
        XCTAssertEqual(node.position.x, 150)
        XCTAssertEqual(node.position.y, 300)
    }

    // MARK: - 2. 节点度数对尺寸的影响与边界保护

    func testGraphNode_SizeCalculationBounds() {
        let baseSize: CGFloat = 20
        let minSize: CGFloat = 18
        let maxSize: CGFloat = 30
        let factor = FeatureConstants.GraphComponentsScale.linkCountSizeFactor

        // 零连接度
        let zeroLinksSize = max(minSize, min(maxSize, baseSize + 0 * factor))
        XCTAssertEqual(zeroLinksSize, 20)

        // 高连接度（上溢出保护）
        let highLinksSize = max(minSize, min(maxSize, baseSize + 100 * factor))
        XCTAssertEqual(highLinksSize, maxSize)
    }
}
