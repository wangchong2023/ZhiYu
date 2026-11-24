//
//  KnowledgeDashboardViewTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：验证 DashboardCoordinator 拓扑计算、连接密度 Top N 排序与标签词频聚合分支。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYuUnitTestHost

@MainActor
final class KnowledgeDashboardViewTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 反链计算与连接密度 Top N 排序分支

    func testDashboardCoordinator_CalculateStatsAndDensity() async {
        let store = AppStore()

        let pageA = KnowledgePage(title: "分布式系统", pageType: .concept, content: "包含 [[CAP 定理]] 和 [[共识算法]]")
        let pageB = KnowledgePage(title: "CAP 定理", pageType: .concept, content: "参见 [[分布式系统]]")
        let pageC = KnowledgePage(title: "共识算法", pageType: .concept, content: "参见 [[分布式系统]]")

        await store.savePage(pageA)
        await store.savePage(pageB)
        await store.savePage(pageC)

        let coordinator = DashboardCoordinator()
        await coordinator.calculateStats(store: store)

        XCTAssertGreaterThan(coordinator.totalLinks, 0)
        XCTAssertFalse(coordinator.densityData.isEmpty)

        // 验证第一名密度的节点
        let topDensity = coordinator.densityData.first
        XCTAssertNotNil(topDensity)
        XCTAssertEqual(topDensity?.name, "分布式系统")
    }

    // MARK: - 2. 标签聚合与词频统计分支

    func testDashboardCoordinator_UpdateTagsFrequency() async {
        let store = AppStore()

        let page1 = KnowledgePage(title: "P1", pageType: .concept, content: "C1", tags: ["Swift", "iOS"])
        let page2 = KnowledgePage(title: "P2", pageType: .concept, content: "C2", tags: ["Swift", "Server"])

        await store.savePage(page1)
        await store.savePage(page2)

        let coordinator = DashboardCoordinator()
        coordinator.updateTags(store: store)

        XCTAssertFalse(coordinator.tags.isEmpty)
        let swiftTag = coordinator.tags.first { $0.tag == "Swift" }
        XCTAssertEqual(swiftTag?.count, 2)
    }

    // MARK: - 3. 连接密度水平堆叠柱状图计算与渲染验证

    func testConnectionDensityChart_MaxTotalAndRatios_ProportionalCalculation() {
        let items = [
            DensityInfo(name: "个人知识图谱指南", inbound: 7, outbound: 3),
            DensityInfo(name: "卡片盒笔记法", inbound: 4, outbound: 2),
            DensityInfo(name: "双向链接的价值", inbound: 1, outbound: 2)
        ]

        let maxTotal = ConnectionDensityChartView.maxTotal(in: items)
        XCTAssertEqual(maxTotal, 10.0, accuracy: 0.0001)

        let topRatios = ConnectionDensityChartView.ratios(for: items[0], maxTotal: maxTotal)
        XCTAssertEqual(topRatios.outbound, 0.3, accuracy: 0.0001)
        XCTAssertEqual(topRatios.inbound, 0.7, accuracy: 0.0001)
        XCTAssertEqual(topRatios.outbound + topRatios.inbound, 1.0, accuracy: 0.0001)

        let midRatios = ConnectionDensityChartView.ratios(for: items[1], maxTotal: maxTotal)
        XCTAssertEqual(midRatios.outbound, 0.2, accuracy: 0.0001)
        XCTAssertEqual(midRatios.inbound, 0.4, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(midRatios.outbound + midRatios.inbound, 1.0)

        let lowRatios = ConnectionDensityChartView.ratios(for: items[2], maxTotal: maxTotal)
        XCTAssertEqual(lowRatios.outbound, 0.2, accuracy: 0.0001)
        XCTAssertEqual(lowRatios.inbound, 0.1, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(lowRatios.outbound + lowRatios.inbound, 1.0)
    }

    func testConnectionDensityChart_Ratios_HandlesZeroAndSingleSidedValues() {
        XCTAssertEqual(ConnectionDensityChartView.maxTotal(in: []), 0)

        let zeroItem = DensityInfo(name: "零连接页面", inbound: 0, outbound: 0)
        XCTAssertEqual(ConnectionDensityChartView.maxTotal(in: [zeroItem]), 0)
        XCTAssertEqual(
            ConnectionDensityChartView.ratios(for: zeroItem, maxTotal: 0),
            DensityBarRatios(outbound: 0, inbound: 0)
        )
        XCTAssertEqual(
            ConnectionDensityChartView.ratios(for: zeroItem, maxTotal: -5),
            DensityBarRatios(outbound: 0, inbound: 0)
        )

        let outboundOnly = DensityInfo(name: "仅出链", inbound: 0, outbound: 5)
        let outboundRatios = ConnectionDensityChartView.ratios(for: outboundOnly, maxTotal: 5)
        XCTAssertEqual(outboundRatios.outbound, 1.0, accuracy: 0.0001)
        XCTAssertEqual(outboundRatios.inbound, 0.0, accuracy: 0.0001)

        let inboundOnly = DensityInfo(name: "仅入链", inbound: 5, outbound: 0)
        let inboundRatios = ConnectionDensityChartView.ratios(for: inboundOnly, maxTotal: 5)
        XCTAssertEqual(inboundRatios.outbound, 0.0, accuracy: 0.0001)
        XCTAssertEqual(inboundRatios.inbound, 1.0, accuracy: 0.0001)

        let negativeItem = DensityInfo(name: "异常负值", inbound: -3, outbound: -2)
        XCTAssertEqual(ConnectionDensityChartView.maxTotal(in: [negativeItem]), 0)
        XCTAssertEqual(
            ConnectionDensityChartView.ratios(for: negativeItem, maxTotal: 10),
            DensityBarRatios(outbound: 0, inbound: 0)
        )

        let mixedNegativeItem = DensityInfo(name: "负入链", inbound: -4, outbound: 4)
        let mixedRatios = ConnectionDensityChartView.ratios(for: mixedNegativeItem, maxTotal: 8)
        XCTAssertEqual(mixedRatios.outbound, 0.5, accuracy: 0.0001)
        XCTAssertEqual(mixedRatios.inbound, 0.0, accuracy: 0.0001)

        let overflowItem = DensityInfo(name: "越界值", inbound: 8, outbound: 12)
        let overflowRatios = ConnectionDensityChartView.ratios(for: overflowItem, maxTotal: 10)
        XCTAssertEqual(overflowRatios.outbound, 1.0, accuracy: 0.0001)
        XCTAssertEqual(overflowRatios.inbound, 0.0, accuracy: 0.0001)
        XCTAssertLessThanOrEqual(overflowRatios.outbound + overflowRatios.inbound, 1.0)
    }

    func testConnectionDensityChart_SegmentWidths_HandlesValidAndNonPositiveContainerWidth() {
        let ratios = DensityBarRatios(outbound: 0.3, inbound: 0.5)

        let validWidths = ConnectionDensityChartView.segmentWidths(for: ratios, totalWidth: 300)
        XCTAssertEqual(validWidths.outbound, 90.0, accuracy: 0.0001)
        XCTAssertEqual(validWidths.inbound, 150.0, accuracy: 0.0001)

        let zeroWidths = ConnectionDensityChartView.segmentWidths(for: ratios, totalWidth: 0)
        XCTAssertEqual(zeroWidths.outbound, 0)
        XCTAssertEqual(zeroWidths.inbound, 0)

        let negativeWidths = ConnectionDensityChartView.segmentWidths(for: ratios, totalWidth: -120)
        XCTAssertEqual(negativeWidths.outbound, 0)
        XCTAssertEqual(negativeWidths.inbound, 0)
    }

    func testConnectionDensityChart_ViewRendersAcrossItemCountsAndDuplicateTitles() {
        let measureBounds = CGSize(width: 320, height: UIView.layoutFittingExpandedSize.height)

        let emptyHost = UIHostingController(rootView: ConnectionDensityChartView(items: []))
        let emptySize = emptyHost.sizeThatFits(in: measureBounds)
        XCTAssertGreaterThanOrEqual(emptySize.height, 0)

        let singleItem = [DensityInfo(name: "个人知识图谱指南", inbound: 6, outbound: 4)]
        let singleHost = UIHostingController(rootView: ConnectionDensityChartView(items: singleItem))
        let singleSize = singleHost.sizeThatFits(in: measureBounds)
        XCTAssertGreaterThan(singleSize.height, 0)

        let fiveItems = [
            DensityInfo(name: "个人知识图谱指南", inbound: 6, outbound: 4),
            DensityInfo(name: "同名知识节点", inbound: 3, outbound: 2),
            DensityInfo(name: "同名知识节点", inbound: 1, outbound: 4),
            DensityInfo(name: "这是一段非常非常长的中文标题用于验证单行省略与多平台自适应高度不会发生重叠", inbound: 2, outbound: 1),
            DensityInfo(name: "零连接条目", inbound: 0, outbound: 0)
        ]
        let fiveHost = UIHostingController(rootView: ConnectionDensityChartView(items: fiveItems))
        let fiveSize = fiveHost.sizeThatFits(in: measureBounds)

        XCTAssertGreaterThan(fiveSize.height, singleSize.height)
    }
}
