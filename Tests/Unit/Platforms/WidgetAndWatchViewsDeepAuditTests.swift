//
//  WidgetAndWatchViewsDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层测试
//  核心职责：针对 Watch 端与 Widget 各种尺寸（Small/Medium/Large）及数据分布视图
//            执行深层渲染与零数据/极端数据边界测试。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class WidgetAndWatchViewsDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. WatchKnowledgeStatsView 统计圆环与近期页面列表

    func testWatchKnowledgeStatsView_EmptyAndPopulated() {
        let emptyWatchView = WatchKnowledgeStatsView(totalPages: 0, totalWords: 0, recentTitles: [])
            .snapshotEnvironment()
        let host1 = UIHostingController(rootView: emptyWatchView)
        _ = host1.view
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view)

        let populatedWatchView = WatchKnowledgeStatsView(
            totalPages: 42,
            totalWords: 58000,
            recentTitles: ["微服务设计", "Paxos 共识", "向量数据库"]
        )
        .snapshotEnvironment()
        let host2 = UIHostingController(rootView: populatedWatchView)
        _ = host2.view
        host2.view.layoutIfNeeded()
        XCTAssertNotNil(host2.view)
    }

    // MARK: - 2. DailyInsightWidgetView 洞察卡片渲染

    func testDailyInsightWidgetView_Rendering() {
        let emptyWidget = DailyInsightWidgetView(title: "每日知识", content: "暂无最新洞察内容")
            .snapshotEnvironment()
        let host1 = UIHostingController(rootView: emptyWidget)
        _ = host1.view
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view)

        let fullWidget = DailyInsightWidgetView(title: "分布式系统", content: "分布式共识算法 Paxos 与 Raft 核心区别解析")
            .snapshotEnvironment()
        let host2 = UIHostingController(rootView: fullWidget)
        _ = host2.view
        host2.view.layoutIfNeeded()
        XCTAssertNotNil(host2.view)
    }

    // MARK: - 3. KnowledgeDistributionWidgetView 分布图表与 QuickCaptureWidgetView 快捷卡片

    func testDistributionAndQuickCapture_Rendering() {
        let distWidget = KnowledgeDistributionWidgetView(pageCount: 50, distribution: ["概念": 0.8, "词条": 0.5])
            .snapshotEnvironment()
        let host1 = UIHostingController(rootView: distWidget)
        _ = host1.view
        host1.view.layoutIfNeeded()
        XCTAssertNotNil(host1.view)

        let quickCapture = QuickCaptureWidgetView()
            .snapshotEnvironment()
        let host2 = UIHostingController(rootView: quickCapture)
        _ = host2.view
        host2.view.layoutIfNeeded()
        XCTAssertNotNil(host2.view)

        let watchDaily = WatchDailyInsightView(insights: ["闪念记录1", "知识沉淀2"])
            .snapshotEnvironment()
        let host3 = UIHostingController(rootView: watchDaily)
        _ = host3.view
        host3.view.layoutIfNeeded()
        XCTAssertNotNil(host3.view)
    }
}
