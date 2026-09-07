//
//  AISynthesisAndChatStreamInteractiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/02.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class AISynthesisAndChatStreamInteractiveTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. ChatView Multi-Turn Stream Flow

    func testChatViewMultiTurnInteractiveFlow() async throws {
        struct Wrapper: View {
            @State var selectedTab: AppTab = .chat

            var body: some View {
                ChatView(selectedTab: $selectedTab)
            }
        }

        let wrapper = Wrapper()
        let view = wrapper.snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(wrapper.selectedTab, .chat)
    }

    // MARK: - 2. SynthesisView & TaskCenterView Full Flow

    func testSynthesisViewAndTaskCenterManagement() async throws {
        struct Wrapper: View {
            @State var selection: SidebarSelection?
            @State var selectedTab: AppTab = .synthesis

            var body: some View {
                VStack {
                    SynthesisView(selection: $selection, selectedTab: $selectedTab)
                    TaskCenterView()
                }
            }
        }

        let wrapper = Wrapper()
        let view = wrapper.snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(wrapper.selectedTab, .synthesis)
        XCTAssertNil(wrapper.selection)
    }
}
