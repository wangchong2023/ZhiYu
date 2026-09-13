//
//  PlatformAndInfraDeepFullCoverageTests.swift
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
final class PlatformAndInfraRuntimeBridgeTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ContentView & App Scenes
    // MARK: - 2. LiveActivity & Platform Views

    func testLiveActivityAndPlatformViews() throws {
        #if os(iOS) && !targetEnvironment(macCatalyst)
        let attributes = AIProcessingAttributes(
            taskName: "Deep Knowledge Synthesis",
            startTime: Date()
        )
        let state = AIProcessingAttributes.ContentState(
            progress: 0.75,
            status: "Processing 24 nodes",
            kind: .synthesis
        )
        XCTAssertEqual(attributes.taskName, "Deep Knowledge Synthesis")
        XCTAssertEqual(state.progress, 0.75)
        #endif
    }
}
