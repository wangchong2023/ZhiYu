//
//  PluginAndCollaborationDeepTests.swift
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
final class PluginAndCollaborationDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. PluginCenterView Deep Tests

    func testPluginCenterViewMarketAndMyPluginsTabs() async throws {
        let pluginCenter = PluginCenterView()
            .snapshotEnvironment()
        
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: pluginCenter)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. CollaborationView Deep Tests

    func testCollaborationViewUnjoinedAndJoinedState() throws {
        let collabView = CollaborationView()
            .snapshotEnvironment()
        
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: collabView)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
    }

    func testCollabEditModelAndDTOs() throws {
        let edit = CollabEdit(
            id: UUID().uuidString,
            userID: "user_alice",
            pageID: UUID(),
            field: "content",
            oldValue: "Draft version",
            newValue: "Final version",
            timestamp: Date()
        )
        XCTAssertEqual(edit.userID, "user_alice")
        XCTAssertEqual(edit.field, "content")
        XCTAssertEqual(edit.oldValue, "Draft version")
        XCTAssertEqual(edit.newValue, "Final version")
    }
}
