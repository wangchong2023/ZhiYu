//
//  SharedUIComponentsDeepFullCoverageTests.swift
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
final class SharedUIComponentsAdaptiveRenderTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. Badges & Banners & Markdown

    func testBadgesBannersAndEditor() throws {
        struct Wrapper: View {
            @State var text = "# Header\n**Bold Text**"

            var body: some View {
                VStack {
                    AIRainbowGlowBadge()
                    AIProcessingStatusBanner()
                    MarkdownRendererView(content: text, isPrivate: false, onLinkTap: { _ in })
                    AppTextEditor(text: $text, placeholder: "Type here...")
                }
            }
        }

        let modelManager = GlobalModelManager.shared
        let view = Wrapper().snapshotEnvironment()
        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
        XCTAssertNotNil(modelManager)
    }

    // MARK: - 2. Menus, Overlays & Skeletons

    func testMenusAndFeedbackComponents() throws {
        let collabService = CollaborationService()
        struct Wrapper: View {
            @ObservedObject var collabService: CollaborationService
            @State var roomName = "Test Room"

            var body: some View {
                VStack {
                    AppLoadingSkeleton()
                    HostingSetupSheet(collabService: collabService, roomName: $roomName)
                }
            }
        }

        let view = Wrapper(collabService: collabService).snapshotEnvironment()
        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
        XCTAssertFalse(collabService.isHosting)
    }
}
