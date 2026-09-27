//
//  WidgetAndWatchViewsBodyTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/09/27.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] L3 Platforms
//  核心职责：验证 WidgetAndWatchViews 各 SwiftUI 视图 body 渲染不崩溃，
//           覆盖默认初始化与自定义参数路径。
//

import XCTest
import SwiftUI
@testable import ZhiYu

@MainActor
final class WidgetAndWatchViewsBodyTests: XCTestCase {

    // MARK: - DailyInsightWidgetView

    /// 默认初始化渲染 body 不崩溃
    func testDailyInsightWidgetView_defaultInit_bodyRendered() {
        let view = DailyInsightWidgetView()
        let body = view.body
        XCTAssertNotNil(body, "DailyInsightWidgetView 默认初始化 body 应非空")
    }

    /// 自定义标题与内容渲染 body 不崩溃
    func testDailyInsightWidgetView_customTitleAndContent_bodyRendered() {
        let view = DailyInsightWidgetView(title: "自定义标题", content: "自定义内容")
        XCTAssertEqual(view.title, "自定义标题")
        XCTAssertEqual(view.content, "自定义内容")
        let body = view.body
        XCTAssertNotNil(body, "DailyInsightWidgetView 自定义参数 body 应非空")
    }

    // MARK: - KnowledgeDistributionWidgetView

    /// 默认初始化渲染 body 不崩溃
    func testKnowledgeDistributionWidgetView_defaultInit_bodyRendered() {
        let view = KnowledgeDistributionWidgetView()
        XCTAssertEqual(view.pageCount, PlatformConstants.WidgetWatch.defaultPageCount)
        XCTAssertEqual(view.distribution, PlatformConstants.WidgetWatch.defaultDistribution)
        let body = view.body
        XCTAssertNotNil(body, "KnowledgeDistributionWidgetView 默认初始化 body 应非空")
    }

    /// 自定义页面数与分布渲染 body 不崩溃
    func testKnowledgeDistributionWidgetView_customParams_bodyRendered() {
        let customDist: [String: Double] = ["source": 0.5, "concept": 0.3, "entity": 0.15, "map": 0.05]
        let view = KnowledgeDistributionWidgetView(pageCount: 100, distribution: customDist)
        XCTAssertEqual(view.pageCount, 100)
        XCTAssertEqual(view.distribution, customDist)
        let body = view.body
        XCTAssertNotNil(body, "KnowledgeDistributionWidgetView 自定义参数 body 应非空")
    }

    /// 空分布字典渲染 body 不崩溃（边界条件）
    func testKnowledgeDistributionWidgetView_emptyDistribution_bodyRendered() {
        let view = KnowledgeDistributionWidgetView(pageCount: 0, distribution: [:])
        XCTAssertEqual(view.pageCount, 0)
        XCTAssertTrue(view.distribution.isEmpty)
        let body = view.body
        XCTAssertNotNil(body, "KnowledgeDistributionWidgetView 空分布 body 应非空")
    }

    // MARK: - QuickCaptureWidgetView

    /// 默认初始化渲染 body 不崩溃
    func testQuickCaptureWidgetView_defaultInit_bodyRendered() {
        let view = QuickCaptureWidgetView()
        let body = view.body
        XCTAssertNotNil(body, "QuickCaptureWidgetView 默认初始化 body 应非空")
    }

    // MARK: - WatchDailyInsightView

    /// 默认初始化渲染 body 不崩溃
    func testWatchDailyInsightView_defaultInit_bodyRendered() {
        let view = WatchDailyInsightView()
        XCTAssertEqual(view.insights.count, 3, "默认应包含 3 条洞察")
        let body = view.body
        XCTAssertNotNil(body, "WatchDailyInsightView 默认初始化 body 应非空")
    }

    /// 自定义洞察列表渲染 body 不崩溃
    func testWatchDailyInsightView_customInsights_bodyRendered() {
        let customInsights = ["洞察一", "洞察二", "洞察三", "洞察四"]
        let view = WatchDailyInsightView(insights: customInsights)
        XCTAssertEqual(view.insights, customInsights)
        let body = view.body
        XCTAssertNotNil(body, "WatchDailyInsightView 自定义洞察 body 应非空")
    }

    /// 空洞察列表渲染 body 不崩溃（边界条件）
    func testWatchDailyInsightView_emptyInsights_bodyRendered() {
        let view = WatchDailyInsightView(insights: [])
        XCTAssertTrue(view.insights.isEmpty)
        let body = view.body
        XCTAssertNotNil(body, "WatchDailyInsightView 空洞察 body 应非空")
    }
}
