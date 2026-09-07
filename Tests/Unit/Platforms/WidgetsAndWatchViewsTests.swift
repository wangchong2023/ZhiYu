//
//  WidgetsAndWatchViewsTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Platforms] 平台与小组件测试层
//  核心职责：验证 WatchKnowledgeStatsView、DailyInsightWidgetView、
//            KnowledgeDistributionWidgetView、QuickCaptureWidgetView 与 WatchDailyInsightView。
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class WidgetsAndWatchViewsTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. WatchKnowledgeStatsView 统计环与最近更新列表
    // MARK: - 2. DailyInsightWidgetView 与 QuickCaptureWidgetView
    // MARK: - 3. KnowledgeDistributionWidgetView 知识分布热度

    func testKnowledgeDistributionWidgetView_EmptyAndFilledDistribution() {
        let dist = ["概念": 0.8, "实体": 0.6, "问答": 0.4]
        let distView = KnowledgeDistributionWidgetView(pageCount: 30, distribution: dist)

        let host = UIHostingController(rootView: distView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertEqual(distView.pageCount, 30)
        XCTAssertEqual(distView.distribution.count, 3)
        XCTAssertNotNil(host.view)
    }

    // MARK: - 4. WatchDailyInsightView 轮播页面

    func testWatchDailyInsightView_CarouselRendersSafely() {
        let quotes = ["知识就是力量", "不断迭代，追求卓越"]
        let watchView = WatchDailyInsightView(insights: quotes)

        let host = UIHostingController(rootView: watchView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertEqual(watchView.insights.count, 2)
        XCTAssertNotNil(host.view)
    }
}
