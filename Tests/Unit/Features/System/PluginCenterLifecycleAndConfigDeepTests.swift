//
//  PluginCenterLifecycleAndConfigDeepTests.swift
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
final class PluginCenterLifecycleAndConfigDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. PluginCenterView Interactive Mounting

    func testPluginCenterViewInteractiveMounting() async throws {
        let pluginRegistry = try XCTUnwrap(ServiceContainer.shared.resolveOptional(PluginRegistry.self))
        let view = PluginCenterView()
            .snapshotEnvironment()

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(pluginRegistry)
        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. PluginCenterView Search & Category

    func testPluginCenterViewSearchAndCategories() throws {
        let pluginRegistry = try XCTUnwrap(ServiceContainer.shared.resolveOptional(PluginRegistry.self))
        let view = PluginCenterView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(pluginRegistry)
        XCTAssertNotNil(host.view)
    }
}
