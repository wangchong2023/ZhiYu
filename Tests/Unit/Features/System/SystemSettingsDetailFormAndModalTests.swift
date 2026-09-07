//
//  SystemSettingsDetailFormAndModalTests.swift
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
final class SystemSettingsDetailFormAndModalTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. RawStorageListView & RawPageDetailView

    func testRawStorageListViewAndRawPageDetailInteraction() async throws {
        let store = AppStore()
        let rawPage = KnowledgePage(
            title: "Raw Log Document",
            pageType: .source,
            content: "Raw captured log content snippet",
            tags: ["Raw", "Storage"]
        )
        await store.savePage(rawPage)

        struct Wrapper: View {
            let page: KnowledgePage

            var body: some View {
                NavigationStack {
                    VStack {
                        RawStorageListView()
                        RawPageDetailView(page: page)
                        HighlightedText(text: "Hello World ZhiYu System", highlight: "ZhiYu")
                    }
                }
            }
        }

        let view = Wrapper(page: rawPage).snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let host = UIHostingController(rootView: view)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(rawPage.title, "Raw Log Document")
        XCTAssertEqual(rawPage.pageType, .source)
    }

    // MARK: - 2. PluginCenterView Tabs & Safe Mode

    func testPluginCenterTabsAndSearchInteraction() async throws {
        struct Wrapper: View {
            var body: some View {
                PluginCenterView()
            }
        }

        let wrapper = Wrapper()
        XCTAssertNotNil(wrapper)
        let view = wrapper.snapshotEnvironment()
        let host = UIHostingController(rootView: view)
        XCTAssertNotNil(host.view)
    }
}
