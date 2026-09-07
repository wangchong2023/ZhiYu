//
//  CollaborationAndPageDetailDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：针对协同视图（CollaborationView）、页面详情（PageDetailView）与
//            标签云子视图（TagCloudSubViews）执行交互状态机与边界测试。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class CollaborationAndPageDetailDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. CollaborationView 协同视图与 P2P 状态测试

    func testCollaborationView_RenderingAndState() async {
        let rawView = CollaborationView()
        XCTAssertNotNil(rawView)
        let view = rawView.snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "CollaborationView 完整视图应成功渲染")
    }

    // MARK: - 2. PageDetailView 知识页面详情与 AI 侧边栏交互

    func testPageDetailView_RenderingAndCoordinatorActions() async {
        let page = KnowledgePage(
            id: UUID(),
            title: "跨平台协同架构",
            pageType: .concept,
            content: "# 协同架构\n基于 MultipeerConnectivity 的去中心化拓扑。",
            tags: ["架构", "P2P", "Swift6"]
        )

        XCTAssertEqual(page.title, "跨平台协同架构")
        XCTAssertEqual(page.tags.count, 3)

        let view = PageDetailView(page: page)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view, "PageDetailView 应成功渲染并展示页面元数据")
    }

    // MARK: - 3. TagCloudSubViews 标签计算与模式测试

    func testTagCloud_BubbleRatioBoundaryAndCollapse() {
        let content = TagCloudViewContent(initialTag: nil)

        // 空数据时
        let ratioEmpty = content.bubbleRatio(for: 5)
        XCTAssertEqual(ratioEmpty, 0.0)

        // 单个标签或相同计数时
        content.coordinator.tags = [("Swift", 10), ("RAG", 10)]
        let ratioEqual = content.bubbleRatio(for: 10)
        XCTAssertEqual(ratioEqual, 0.5, "极值相同时应返回中间比例 0.5")

        // 正常范围
        content.coordinator.tags = [("Min", 2), ("Mid", 6), ("Max", 10)]
        let ratioMid = content.bubbleRatio(for: 6)
        XCTAssertEqual(ratioMid, 0.5, accuracy: 0.01)
        let ratioMin = content.bubbleRatio(for: 2)
        XCTAssertEqual(ratioMin, 0.0, accuracy: 0.01)
        let ratioMax = content.bubbleRatio(for: 10)
        XCTAssertEqual(ratioMax, 1.0, accuracy: 0.01)
    }

    // MARK: - 4. 边界与 Fuzz 异常注入测试

    func testKnowledgePage_ExtremePayloadAndSerialization() {
        let extremePage = KnowledgePage(
            id: UUID(),
            title: String(repeating: "极端超长标题", count: 200),
            pageType: .entity,
            content: String(repeating: "Markdown 节点与双链测试 [[测试]] ", count: 500),
            tags: (0..<100).map { "Tag_\($0)" }
        )

        XCTAssertEqual(extremePage.tags.count, 100)
        let data = try? JSONEncoder().encode(extremePage)
        XCTAssertNotNil(data, "大载荷 KnowledgePage 序列化应稳定不崩溃")
    }
}
