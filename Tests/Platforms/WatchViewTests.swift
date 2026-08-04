//
//  WatchViewTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 WatchView 开展自动化单元测试验证。
//
import XCTest
import UFPCore
import SwiftUI
import WidgetKit
import AppIntents
#if os(watchOS)
@testable import ZhiYuWatch
#else
@testable import ZhiYu
#endif

/// 验证 watchOS SwiftUI 视图及表盘小组件 (Widget) 的加载和核心业务交互逻辑
@MainActor
final class WatchViewTests: XCTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
        // 设置极简测试沙盒，避免依赖冲突
        ServiceContainer.shared.reset()
    }
    
    override func tearDown() async throws {
        // 允许当前主线程/协程事件循环排水，避免 Race Condition
        try? await Task.sleep(nanoseconds: 50_000_000)
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }
    
    /// 测试 WatchKnowledgeStatsView (手表端简易统计视图)
    /// 验证其统计数据加载逻辑以及字数格式化多分支
    func testWatchKnowledgeStatsView() {
        let defaults = UserDefaults.standard
        defaults.set(10, forKey: "watch_totalPages")
        defaults.set(1500, forKey: "watch_totalWords")
        defaults.set(["测试页面1", "测试页面2"], forKey: "watch_recentTitles")
        
        var statsView = WatchKnowledgeStatsView()
        
        // 1. 测试直接调用已暴露的 loadData 以覆盖载入分支
        statsView.loadData()
        
        // 2. 使用可测试化 init 构建带有 mock 数据的实例，确保 body 中 ForEach 逻辑闭包被触发执行
        let statsViewWithData = WatchKnowledgeStatsView(totalPages: 10, totalWords: 1500, recentTitles: ["测试页面1", "测试页面2"])
        _ = statsViewWithData.body
        
        // 2.1 测试单独抽离的行视图组件，完整覆盖最近更新列表每一行的渲染细节
        let rowView = WatchRecentUpdateRowView(title: "测试最近页面标题")
        _ = rowView.body
        
        // 3. 测试直接调用 formatNumber 覆盖所有条件分支
        let formattedTenThousand = statsView.formatNumber(25000)
        XCTAssertTrue(formattedTenThousand.contains("万") || formattedTenThousand.contains("2.5"))
        
        let formattedThousand = statsView.formatNumber(1500)
        XCTAssertEqual(formattedThousand, "1.5k")
        
        let formattedUnderThousand = statsView.formatNumber(500)
        XCTAssertEqual(formattedUnderThousand, "500")
        
        // 4. 测试本地化 L.tr 未定义 key 路径，以覆盖空合并运算符 (?? key) 的隐式闭包分支
        let fallbackText = L.tr("nonexistent_key_for_testing")
        XCTAssertEqual(fallbackText, "nonexistent_key_for_testing")
        
        // 清理 UserDefaults
        defaults.removeObject(forKey: "watch_totalPages")
        defaults.removeObject(forKey: "watch_totalWords")
        defaults.removeObject(forKey: "watch_recentTitles")
    }
    
    /// 测试小组件相关定义、配置以及 Timeline Provider 的数据生成
    func testWatchWidgetsAndIntents() async throws {
        // 1. 测试 WatchCaptureIntent 执行，模拟表盘小组件被点击触发拉起 App 的动作
        let intent = WatchCaptureIntent()
        let result = try await intent.perform()
        XCTAssertNotNil(result, "Intent 应当成功返回 perform 结果")
        
        // 2. 测试 WatchWidgetView 视图渲染，验证其 body 是否能被正常计算
        let widgetView = WatchWidgetView(entry: SimpleEntry(date: Date()))
        _ = widgetView.body
        
        // 3. 测试 WatchCaptureWidget 及其配置 body，覆盖小组件描述和支持的家族列表
        let widget = WatchCaptureWidget()
        _ = widget.body
        
        // 4. 测试 Provider 重构后的逻辑函数
        let provider = Provider()
        let placeholderEntry = provider.makePlaceholder()
        XCTAssertNotNil(placeholderEntry)
        
        let snapshotExpectation = expectation(description: "getSnapshot")
        provider.makeSnapshot { entry in
            XCTAssertNotNil(entry)
            snapshotExpectation.fulfill()
        }
        
        let timelineExpectation = expectation(description: "getTimeline")
        provider.makeTimeline { timeline in
            XCTAssertEqual(timeline.entries.count, 1)
            timelineExpectation.fulfill()
        }
        
        await fulfillment(of: [
            snapshotExpectation,
            timelineExpectation
        ], timeout: 2.0)
    }
}
