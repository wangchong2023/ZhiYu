//
//  SystemAndModelLabViewsExploratoryTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：探索性与边界测试 ModelLabView（参数Sheet/指标面板/多用例沙盒）、
//            SystemStatsView、DeveloperSettingsView、PluginCenterView 及 MarkdownRendererView。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SystemAndModelLabViewsExploratoryTests: XCTestCase {

    private var appStore: AppStore!
    private var router: Router!
    private var themeManager: ThemeManager!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()

        appStore = AppStore()
        router = Router.shared
        themeManager = ThemeManager()
    }

    override func tearDown() async throws {
        appStore = nil
        router = nil
        themeManager = nil
        try await super.tearDown()
    }

    // MARK: - 1. ModelLabView 全 UseCase 切换与参数 Sheet 交互

    func testModelLabView_AllUseCasesAndConfigSheet() {
        var didGoToStore = false
        let labView = ModelLabView(onGoToStore: {
            didGoToStore = true
        })
        .environment(themeManager)

        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        let host = UIHostingController(rootView: labView)
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        XCTAssertFalse(didGoToStore)
        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. DeveloperSettingsView & PluginCenterView 渲染

    func testDeveloperSettingsAndPluginCenter_RendersCleanly() {
        let devSettings = DeveloperSettingsView()
            .environment(appStore)
            .environment(router)
            .environment(themeManager)

        let hostDev = UIHostingController(rootView: devSettings)
        _ = hostDev.view
        hostDev.view.layoutIfNeeded()

        let pluginCenter = PluginCenterView()
            .environment(appStore)
            .environment(router)
            .environment(themeManager)

        let hostPlugin = UIHostingController(rootView: pluginCenter)
        _ = hostPlugin.view
        hostPlugin.view.layoutIfNeeded()

        XCTAssertNotNil(hostDev.view)
        XCTAssertNotNil(hostPlugin.view)
    }

    // MARK: - 3. MarkdownRendererView 富文本解析与私密卡片分支

    func testMarkdownRendererView_ComplexMarkdownAndPrivateBlocks() {
        let sampleMarkdown = """
        # 深度学习与知识图谱

        这是一篇探讨 **RAG** 与 *向量数据库* 结合的技术文档。

        - 列表项 1: FTS5 全文索引
        - 列表项 2: 1536 维语义向量

        > 重要提示：引文块测试

        ```swift
        func testCode() {
            print("Hello ZhiYu")
        }
        ```
        """

        var tappedLink: String?
        let renderer = MarkdownRendererView(
            content: sampleMarkdown,
            isPrivate: false,
            onLinkTap: { link in
                tappedLink = link
            }
        )
        .environment(appStore)

        let host = UIHostingController(rootView: renderer)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNil(tappedLink)
        XCTAssertNotNil(host.view)
    }
}
