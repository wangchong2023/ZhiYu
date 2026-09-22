//
//  AuthAndSubscriptionInteractiveSnapshots.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Snapshot] 快照测试层
//  核心职责：身份认证 (AuthView) 与海外 OAuth 登录卡片的视觉快照与渲染回归。
//

import XCTest
import SwiftUI
import SnapshotTesting
import UFPCore
@testable import ZhiYu

@MainActor
final class AuthAndSubscriptionInteractiveSnapshots: XCTestCase {

    /// 依据环境变量判断快照录制策略，用于支持 CI/CD 脚本自动更新基准图片
    private nonisolated static var recordMode: SnapshotTestingConfiguration.Record {
        ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
    }

    override func invokeTest() {
        withSnapshotTesting(record: Self.recordMode) {
            super.invokeTest()
        }
    }

    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 认证主页手机号登录面板快照

    func testAuthView_ChinaRegion_RendersPhonePanel() {
        let view = NavigationStack {
            AuthView()
        }
        .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .device(config: .iPhone13Pro)))
    }

    // MARK: - 2. 海外 OAuth 登录卡片（Apple / Google / GitHub）快照

    func testOverseasLoginCardView_RendersOAuthButtons() {
        let view = OverseasLoginCardView()
            .padding()
            .snapshotEnvironment()

        assertSnapshot(of: view, as: .image(precision: SnapshotConfig.defaultPrecision, layout: .fixed(width: DesignSystem.Metrics.snapshotPhoneWidth, height: DesignSystem.Metrics.snapshotPhoneHeight)))
    }
}
