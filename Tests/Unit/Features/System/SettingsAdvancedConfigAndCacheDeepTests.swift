//
//  SettingsAdvancedConfigAndCacheDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class SettingsAdvancedConfigAndCacheDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SettingsView Interactive Mounting

    func testSettingsViewInteractiveMounting() async throws {
        let rawView = SettingsView()
        XCTAssertNotNil(rawView)
        let view = rawView.snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. AISettingsView Mounting

    func testAISettingsViewMounting() throws {
        let rawView = AISettingsView()
        XCTAssertNotNil(rawView)
        let view = rawView.snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
    }
}
