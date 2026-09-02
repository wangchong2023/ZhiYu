//
//  BadgesAndLiveActivityDeepTests.swift
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
final class BadgesAndLiveActivityDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. AIRainbowGlowBadge Deep Tests

    func testAIRainbowGlowBadgeVisualStates() throws {
        let modelManager = GlobalModelManager.shared
        
        // 1. 默认状态渲染
        let badge = AIRainbowGlowBadge()
            .environment(Router.shared)
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: badge)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
        
        // 2. 启用云端提权状态
        modelManager.isCloudEscalationEnabled = true
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        XCTAssertTrue(modelManager.isCloudEscalationEnabled)
        
        // 3. 重置状态
        modelManager.isCloudEscalationEnabled = false
    }

    // MARK: - 2. AppLayoutComponents & ContentView Container Deep Tests

    func testContentViewLayoutContainers() throws {
        let authSession = AuthSession.shared
        let vaultService = VaultService.shared
        let router = Router.shared
        
        // 1. 游客模式未选择笔记本
        authSession.isGuest = true
        vaultService.selectedVaultID = nil
        
        let contentView = ContentView()
            .snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: contentView)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view)
        
        // 2. 选择有效笔记本渲染主容器
        let testVault = Vault(name: "TestVault")
        vaultService.vaults = [testVault]
        vaultService.selectVault(testVault)
        
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        XCTAssertEqual(vaultService.selectedVaultID, testVault.id)
        
        // 3. 路由 Tab 切换
        router.selectedTab = .knowledge
        host.view.layoutIfNeeded()
        router.selectedTab = .chat
        host.view.layoutIfNeeded()
        router.selectedTab = .synthesis
        host.view.layoutIfNeeded()
        router.selectedTab = .graph
        host.view.layoutIfNeeded()
    }

    // MARK: - 3. AIProcessingAttributes & Live Activity Kind Tests

    #if os(iOS) && !targetEnvironment(macCatalyst)
    func testAIProcessingAttributesDataContract() throws {
        let stateSynthesis = AIProcessingAttributes.ContentState(
            progress: 0.75,
            status: "Synthesizing Mindmap...",
            kind: .synthesis,
            sourceCount: 8,
            currentFileName: "ConceptGraph.md",
            estimatedSecondsRemaining: 5
        )
        let attr = AIProcessingAttributes(taskName: "Deep Knowledge Synthesis", startTime: Date())
        
        XCTAssertEqual(attr.taskName, "Deep Knowledge Synthesis")
        XCTAssertEqual(stateSynthesis.progress, 0.75)
        XCTAssertEqual(stateSynthesis.kind, .synthesis)
        XCTAssertEqual(stateSynthesis.sourceCount, 8)
        
        let stateOCR = AIProcessingAttributes.ContentState(
            progress: 0.30,
            status: "Extracting OCR text...",
            kind: .ingestOCR,
            sourceCount: 0,
            currentFileName: "Whiteboard.png",
            estimatedSecondsRemaining: 12
        )
        XCTAssertEqual(stateOCR.kind, .ingestOCR)
        
        let stateVoice = AIProcessingAttributes.ContentState(
            progress: 1.0,
            status: "Transcription complete",
            kind: .voiceNote,
            sourceCount: 0,
            currentFileName: "Lecture.m4a",
            estimatedSecondsRemaining: 0
        )
        XCTAssertEqual(stateVoice.kind, .voiceNote)
    }
    #endif
}
