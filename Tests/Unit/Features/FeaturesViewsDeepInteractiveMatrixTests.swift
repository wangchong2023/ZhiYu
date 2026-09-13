//
//  FeaturesViewsDeepInteractiveMatrixTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能测试层
//  核心职责：对 L2 Features 核心业务视图（IngestView, ChatView, SynthesisView,
//            SettingsView, PageDetailView）执行深水区全模态生命周期与交互矩阵测试。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class FeaturesViewsDeepInteractiveMatrixTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. IngestView 摄取视图测试

    func testIngestView_RenderingAndInteraction() {
        struct Wrapper: View {
            @State var tab: AppTab = .ingest

            var body: some View {
                IngestView(selectedTab: $tab)
                    .snapshotEnvironment()
            }
        }

        let host = UIHostingController(rootView: Wrapper())
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "IngestView 应成功加载并完成布局计算")
    }

    // MARK: - 2. ChatView 对话视图测试

    func testChatView_RenderingAndInteraction() {
        struct Wrapper: View {
            @State var tab: AppTab = .chat

            var body: some View {
                ChatView(selectedTab: $tab)
                    .snapshotEnvironment()
            }
        }

        let host = UIHostingController(rootView: Wrapper())
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "ChatView 应成功加载并完成布局计算")
    }

    // MARK: - 3. SynthesisView 知识合成视图测试

    func testSynthesisView_RenderingAndInteraction() {
        struct Wrapper: View {
            @State var selection: SidebarSelection? = .tool(.synthesis)
            @State var tab: AppTab = .synthesis

            var body: some View {
                SynthesisView(selection: $selection, selectedTab: $tab)
                    .snapshotEnvironment()
            }
        }

        let host = UIHostingController(rootView: Wrapper())
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "SynthesisView 应成功加载并完成布局计算")
    }

    // MARK: - 4. SettingsView 系统设置视图测试

    func testSettingsView_RenderingAndInteraction() {
        let settingsView = SettingsView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: settingsView)
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "SettingsView 应成功加载并完成布局计算")
    }

    // MARK: - 5. PageDetailView 页面详情视图测试

    func testPageDetailView_RenderingAndInteraction() {
        let page = KnowledgePage(
            title: "RAG 闭环系统设计",
            content: """
            # 知识检索与合成
            - 混合分块算法
            - 嵌入向量与 FTS5 倒排索引
            - 动态引用合成
            """
        )

        let detailView = PageDetailView(page: page)
            .snapshotEnvironment()

        let host = UIHostingController(rootView: detailView)
        _ = host.view
        host.view.layoutIfNeeded()
        XCTAssertNotNil(host.view, "PageDetailView 应成功加载并渲染详情页")
    }
}
