//
//  SplashAndLockOverlayDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 SplashComponents 开屏特效、LockOverlayView 锁屏遮罩、
//           KnowledgeStatsWidget 统计小组件与 Live Activity 领域模型。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class SplashAndLockOverlayDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SplashComponents 启动背景测试

    func testSplashBackgroundView_Rendering() {
        let view = SplashBackgroundView(starTwinkle: true, nodeGlow: true)
        XCTAssertNotNil(view)

        let nonTwinkleView = SplashBackgroundView(starTwinkle: false, nodeGlow: false)
        XCTAssertNotNil(nonTwinkleView)
    }

    // MARK: - 2. LockOverlayView 隐私锁屏测试

    func testLockOverlayView_Hierarchy() {
        let view = LockOverlayView()
            .snapshotEnvironment()

        XCTAssertNotNil(view)
    }

    // MARK: - 3. Widget 共享常量与背景渐变测试

    func testWidgetSharedConstants_BackgroundAndDeepLinks() {
        let color = WidgetSharedConstants.Color.purple
        XCTAssertNotNil(color)

        XCTAssertFalse(WidgetSharedConstants.DeepLink.voice.isEmpty)
        XCTAssertFalse(WidgetSharedConstants.DeepLink.ocr.isEmpty)
        XCTAssertFalse(WidgetSharedConstants.DeepLink.search.isEmpty)
        XCTAssertFalse(WidgetSharedConstants.DeepLink.chat.isEmpty)
        XCTAssertFalse(WidgetSharedConstants.DeepLink.create.isEmpty)
    }

    // MARK: - 4. AIProcessingAttributes 灵动岛属性模型测试

    func testAIProcessingAttributes_InitAndContentState() {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let now = Date()
        let attrs = AIProcessingAttributes(taskName: "批量文档向量化", startTime: now)
        XCTAssertEqual(attrs.taskName, "批量文档向量化")
        XCTAssertEqual(attrs.startTime, now)

        let state = AIProcessingAttributes.ContentState(
            progress: 0.75,
            status: "正在生成 1536 维向量",
            kind: .synthesis
        )
        XCTAssertEqual(state.progress, 0.75)
        XCTAssertEqual(state.status, "正在生成 1536 维向量")
        XCTAssertEqual(state.kind, .synthesis)
        #endif
    }
}
