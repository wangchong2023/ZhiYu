//
//  KnowledgeDomainComprehensiveDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests/Unit] Features/Knowledge 知识域深度集成测试
//  核心职责：深度覆盖 GraphInsightDetection、NotebookThemeFactory、
//            NotebookHubViewModel、TagStore 及 SearchStore 的算法边界与业务规则。
//  质量标准：依据 unit-test-quality-review 规范，全方位覆盖图谱孤岛识别、
//            跨社区桥接节点检测、笔记本名称长度截断及语义主题哈希分发。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class KnowledgeDomainComprehensiveDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        try? await Task.sleep(nanoseconds: 50_000_000)
        try await super.tearDown()
    }

    // MARK: - 1. GraphInsightDetection 孤立节点与拓扑图洞察深测

    func testGraphInsightDetection_OrphanNodesAndEmptyGraph() {
        let nodeA = GraphNode(id: UUID(), title: "节点 A", pageType: .concept, position: .zero)
        let nodeB = GraphNode(id: UUID(), title: "节点 B", pageType: .concept, position: .zero)
        let orphan1 = GraphNode(id: UUID(), title: "孤立节点 1", pageType: .entity, position: .zero)
        let orphan2 = GraphNode(id: UUID(), title: "孤立节点 2", pageType: .entity, position: .zero)

        let edgeAB = GraphEdge(source: nodeA.id, target: nodeB.id)

        // 1. 混合拓扑孤岛检测
        let orphans = GraphLayoutProcessor.orphanNodes(
            nodes: [nodeA, nodeB, orphan1, orphan2],
            edges: [edgeAB]
        )
        XCTAssertEqual(orphans.count, 2, "应精准识别出未被任何边关联的 2 个孤立节点")
        XCTAssertTrue(orphans.contains(orphan1.id), "孤立列表必须包含 orphan1")
        XCTAssertTrue(orphans.contains(orphan2.id), "孤立列表必须包含 orphan2")
        XCTAssertFalse(orphans.contains(nodeA.id), "有连接的 nodeA 绝不能被判定为孤立节点")

        // 2. 空图谱零数据防御
        let emptyOrphans = GraphLayoutProcessor.orphanNodes(nodes: [], edges: [])
        XCTAssertTrue(emptyOrphans.isEmpty, "空图谱应返回空孤立数组，不应发生数组越界")
    }

    // MARK: - 2. GraphInsightDetection 跨社区桥接与意外关联深测 (图算法变异)

    func testGraphInsightDetection_BridgesAndSurprisingConnections() {
        let hubID = UUID()
        let comm1Node = UUID()
        let comm2Node = UUID()
        let comm3Node = UUID()

        let hubNode = GraphNode(id: hubID, title: "跨界枢纽", pageType: .concept, position: .zero, communityID: 0)
        let n1 = GraphNode(id: comm1Node, title: "社区1节点", pageType: .concept, position: .zero, communityID: 1)
        let n2 = GraphNode(id: comm2Node, title: "社区2实体", pageType: .entity, position: .zero, communityID: 2)
        let n3 = GraphNode(id: comm3Node, title: "社区3信源", pageType: .source, position: .zero, communityID: 3)

        let allNodes = [hubNode, n1, n2, n3]
        let edges = [
            GraphEdge(source: hubID, target: comm1Node),
            GraphEdge(source: hubID, target: comm2Node),
            GraphEdge(source: hubID, target: comm3Node)
        ]

        let insights = GraphLayoutProcessor.detectInsights(
            nodes: allNodes,
            edges: edges,
            pages: []
        )

        // 1. 桥接节点检测：hubNode 同时连接社区 1、2、3（>= 3 个独立社区），必须被标记为桥接节点
        XCTAssertTrue(insights.bridges.contains(hubID), "连接 3 个以上独立社区的 hubID 必须被判定为 Bridge 桥接节点")

        // 2. 意外关联检测：hubNode (.concept) 与 n2 (.entity) 或 n3 (.source) 类型不同且跨社区，应被标记为意外关联
        XCTAssertFalse(insights.surprising.isEmpty, "跨社区且跨类型页面连接应被标记为意外关联")
        XCTAssertTrue(insights.surprising.contains(hubID))
    }

    // MARK: - 3. NotebookThemeFactory 语义启发与哈希回退深测

    func testNotebookThemeFactory_SemanticPalettesAndDeterministicHash() {
        let testID = UUID()

        // 1. 科技语义启发
        let techTheme = NotebookThemeFactory.generate(from: "Swift Core AI 架构", id: testID)
        XCTAssertEqual(techTheme.type, .mesh, "主题类型应默认为 mesh 流体渐变")
        XCTAssertTrue(techTheme.colors.contains("#4A90E2"), "包含 AI/Swift 关键字应精准匹配科技蓝绿色调")

        // 2. 艺术与设计语义启发
        let artTheme = NotebookThemeFactory.generate(from: "UI Design 灵感手册", id: testID)
        XCTAssertTrue(artTheme.colors.contains("#FF9A9E"), "包含 Design 关键字应精准匹配艺术粉紫色调")

        // 3. 极客语义启发
        let geekTheme = NotebookThemeFactory.generate(from: "Geek Tools Collection", id: testID)
        XCTAssertTrue(geekTheme.colors.contains("#00FF41"), "包含 Geek 关键字应精准匹配黑绿终端色调")

        // 4. 无特定关键字的哈希分发确定性
        let randomName = "纯文本读书笔记"
        let fallbackTheme1 = NotebookThemeFactory.generate(from: randomName, id: testID)
        let fallbackTheme2 = NotebookThemeFactory.generate(from: randomName, id: testID)
        XCTAssertFalse(fallbackTheme1.colors.isEmpty, "回退配色不应为空")
        XCTAssertEqual(fallbackTheme1.colors, fallbackTheme2.colors, "相同名称必须通过哈希分发产生严格相同的稳定调色板")
        XCTAssertEqual(fallbackTheme1.seed, fallbackTheme2.seed, "相同 UUID 必须生成确定性的渲染种子")
    }

    // MARK: - 4. NotebookHubViewModel 业务规则与输入防越界深测

    func testNotebookHubViewModel_NameLengthTruncationAndSortTransitions() {
        let viewModel = NotebookHubViewModel()

        // 1. 测试超长笔记本标题截断保护（防止数据库溢出与 UI 换行破坏）
        let excessiveName = String(repeating: "超长笔记本名称", count: 20)
        viewModel.newNotebookName = excessiveName

        let maxLength = DesignSystem.Metrics.maxNotebookNameLength
        XCTAssertLessThanOrEqual(viewModel.newNotebookName.count, maxLength, "笔记本名称在赋值时必须受 didSet 保护自动截断至最大上限")
        XCTAssertEqual(viewModel.newNotebookName.count, maxLength, "截断后长度必须严格等于最大合法长度")

        // 2. 显示模式切换
        viewModel.displayMode = .grid
        XCTAssertEqual(viewModel.displayMode.icon, DesignSystem.Icons.gridOutline)

        viewModel.displayMode = .list
        XCTAssertEqual(viewModel.displayMode.icon, DesignSystem.Icons.list)

        // 3. 排序模式切换
        viewModel.sortOption = .date
        XCTAssertEqual(viewModel.sortOption, .date)
        viewModel.sortOption = .name
        XCTAssertEqual(viewModel.sortOption, .name)
    }

    // MARK: - 5. SearchStore 搜索状态与查询过滤深测

    func testSearchStore_QueryManagementAndState() {
        let searchStore = SearchStore()

        // 1. 初始状态
        XCTAssertTrue(searchStore.searchText.isEmpty, "初始搜索文本应当为空")
        XCTAssertFalse(searchStore.isSearching, "初始状态下不应处于搜索中")

        // 2. 更新搜索文本
        searchStore.searchText = "RAG 混合检索"
        XCTAssertEqual(searchStore.searchText, "RAG 混合检索")

        // 3. 清空搜索文本
        searchStore.searchText = ""
        XCTAssertTrue(searchStore.searchText.isEmpty, "清空搜索文本应复位为空")
    }

    // MARK: - 6. TagStore 标签频次聚合与排序算法深测

    func testTagStore_TagCollectionAndFrequencySorting() {
        let tagStore = TagStore()

        let page1 = KnowledgePage(
            title: "Swift 基础",
            pageType: .concept,
            content: "内容",
            tags: ["Swift", "编程", "iOS"]
        )

        let page2 = KnowledgePage(
            title: "Swift 并发",
            pageType: .concept,
            content: "并发内容",
            tags: ["Swift", "并发", "iOS"]
        )

        let page3 = KnowledgePage(
            title: "Python 脚本",
            pageType: .concept,
            content: "自动化脚本",
            tags: ["Python", "编程"]
        )

        let allPages = [page1, page2, page3]

        // 1. 频率聚合计算
        let counts = tagStore.getAllTags(from: allPages)
        XCTAssertEqual(counts["Swift"], 2, "Swift 标签应被 2 个页面引用")
        XCTAssertEqual(counts["iOS"], 2, "iOS 标签应被 2 个页面引用")
        XCTAssertEqual(counts["编程"], 2, "编程 标签应被 2 个页面引用")
        XCTAssertEqual(counts["Python"], 1, "Python 标签应被 1 个页面引用")
        XCTAssertEqual(counts["并发"], 1, "并发 标签应被 1 个页面引用")
        XCTAssertNil(counts["不存在的标签"], "未引用的标签计数应当为 nil")

        // 2. 排序去重列表
        let sortedTags = tagStore.sortedTags(from: allPages)
        XCTAssertEqual(sortedTags.count, 5, "去重后的标签总数应为 5")
        XCTAssertEqual(sortedTags, ["Python", "Swift", "iOS", "并发", "编程"].sorted(), "标签列表必须严格按字典序排序")
    }
}
