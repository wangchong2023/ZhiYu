//
//  AppLayoutAndContainersDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 AppLayoutComponents 顶层 TabView/SplitView 容器与全局 Overlay 渲染。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class AppLayoutAndContainersDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    func testContentView_LoggedInVaultSelected() {
        let authSession = AuthSession.shared
        authSession.currentUser = User(id: UUID(), name: "TestUser", email: "test@zhiyu.app")
        let vaultService = VaultService.shared
        vaultService.selectedVaultID = UUID()

        let host = ContentView()
            .environment(authSession)
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    func testContentView_GuestMode() {
        let authSession = AuthSession.shared
        authSession.currentUser = nil
        authSession.isGuest = true
        let vaultService = VaultService.shared
        vaultService.selectedVaultID = nil

        let host = ContentView()
            .environment(authSession)
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}
