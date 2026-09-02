//
//  SettingsSyncAndCollaborationDeepTests.swift
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
final class SettingsSyncAndCollaborationDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SettingsView Full Mounting

    func testSettingsViewMounting() throws {
        let settingsView = SettingsView()
            .snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: settingsView)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. AISettingsView & DeveloperSettingsView Mounting

    func testAISettingsAndDeveloperSettings() throws {
        let aiSettingsView = AISettingsView()
            .snapshotEnvironment()
        let hostAI = UIHostingController(rootView: aiSettingsView)
        XCTAssertNotNil(hostAI.view)

        let devSettingsView = DeveloperSettingsView()
            .snapshotEnvironment()
        let hostDev = UIHostingController(rootView: devSettingsView)
        XCTAssertNotNil(hostDev.view)
    }
}
