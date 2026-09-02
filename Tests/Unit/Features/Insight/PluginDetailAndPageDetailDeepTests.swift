//
//  PluginDetailAndPageDetailDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 PluginDetailView、PageDetailAISection 与 ComparisonDetailBodyView 详情排版。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class PluginDetailAndPageDetailDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. PluginDetailView 渲染测试

    func testPluginDetailView_Hierarchy() {
        let plugin = MarketPlugin(
            id: "com.zhiyu.plugin.test",
            version: "1.2.0",
            author: "ZhiYu Team",
            downloads: "1.2k",
            rating: 4.8,
            icon: "https://zhiyu.app/icons/formatter.png",
            downloadURL: "https://zhiyu.app/plugins/formatter.zyplugin",
            minAppVersion: nil,
            requiredPermissions: ["readContent"],
            monetization: nil,
            reviewCount: 10,
            category: "Tool",
            source: "Community",
            names: ["zh": "代码美化器"],
            descriptions: ["zh": "自动格式化 Markdown 中的代码块"]
        )

        let registry = PluginRegistry()
        let host = NavigationStack {
            PluginDetailView(plugin: plugin, marketService: PluginMarketService(registry: registry))
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. PageDetailAISection 渲染测试

    func testPageDetailAISection_Hierarchy() {
        let page = KnowledgePage(
            title: "LLM 核心原理解析",
            pageType: .concept,
            content: "大型语言模型原理与实现细节..."
        )

        let host = PageDetailAISection(page: page, onLinkTap: { _ in })
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 3. ComparisonDetailBodyView 渲染测试

    func testComparisonDetailBodyView_Hierarchy() {
        let page = KnowledgePage(
            title: "Swift vs Rust",
            pageType: .comparison,
            content: """
            ---
            subjects:
              - name: Swift
                score: 9.0
              - name: Rust
                score: 9.2
            dimensions:
              - name: 学习曲线
                ratings: [8, 5]
              - name: 内存安全
                ratings: [9, 10]
            ---
            ## 核心对比
            Swift 与 Rust 在内存安全模型与语言设计上的权衡。
            """
        )

        let host = NavigationStack {
            ComparisonDetailBodyView(page: page, onLinkTap: { _ in })
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
    }
}
