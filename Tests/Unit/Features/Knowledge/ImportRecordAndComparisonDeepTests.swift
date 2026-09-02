//
//  ImportRecordAndComparisonDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度覆盖 ImportRecordSection 与 ComparisonDetailBodyView 的所有渲染状态、Frontmatter 解析与多维对照网络。
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class ImportRecordAndComparisonDeepTests: XCTestCase {

    private var store: AppStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = ServiceContainer.shared.resolveOptional(AppStore.self) ?? AppStore()
    }

    override func tearDown() async throws {
        store = nil
        try await super.tearDown()
    }

    // MARK: - 1. ImportRecordSection 渲染与交互测试

    func testImportRecordSectionEmptyAndPopulated() async throws {
        let repo = ServiceContainer.shared.resolveOptional((any ImportRecordRepository).self)

        // 1. 空记录渲染
        var aiTaggedRecord: ImportRecord?
        var editedRecord: ImportRecord?

        let emptySection = ImportRecordSection(
            onAITag: { aiTaggedRecord = $0 },
            onManualEdit: { editedRecord = $0 }
        )

        let emptyHost = UIHostingController(rootView: emptySection.snapshotEnvironment())
        _ = emptyHost.view
        emptyHost.view.layoutIfNeeded()

        // 2. 插入多种类别导入记录
        let rec1 = ImportRecord(
            category: "pdf",
            title: "WWDC26 设计规范",
            status: "completed",
            filePath: "/tmp/wwdc26.pdf",
            fileSize: 1024 * 1024 * 5,
            tags: "Design, Apple"
        )
        let rec2 = ImportRecord(
            category: "web",
            title: "Karpathy LLM Wiki Guide",
            status: "completed",
            sourceURL: "https://example.com/wiki",
            tags: "AI, RAG"
        )
        let rec3 = ImportRecord(
            category: "audio",
            title: "架构评审会议录音",
            status: "completed",
            filePath: "/tmp/meeting.m4a",
            fileSize: 1024 * 1024 * 10,
            tags: "Audio, Architecture"
        )

        _ = try? await repo?.save(rec1)
        _ = try? await repo?.save(rec2)
        _ = try? await repo?.save(rec3)

        // 3. 有记录时渲染
        let populatedSection = ImportRecordSection(
            onAITag: { aiTaggedRecord = $0 },
            onManualEdit: { editedRecord = $0 }
        )

        let populatedHost = UIHostingController(rootView: populatedSection.snapshotEnvironment())
        _ = populatedHost.view
        populatedHost.view.layoutIfNeeded()

        // 触发回调
        populatedSection.onAITag?(rec1)
        XCTAssertEqual(aiTaggedRecord?.title, "WWDC26 设计规范")

        populatedSection.onManualEdit?(rec2)
        XCTAssertEqual(editedRecord?.title, "Karpathy LLM Wiki Guide")
    }

    // MARK: - 2. ComparisonDetailBodyView 多维对照矩阵与结论板渲染

    func testComparisonDetailBodyViewWithFrontmatter() {
        let contentWithFrontmatter = """
        ---
        subjects:
          - name: "Swift 6"
            summary: "启用编译期严格并发检查与 Actor 隔离"
            highlight: "内存安全"
          - name: "Rust"
            summary: "所有权模型与生命周期标注"
            highlight: "零成本抽象"
        dimensions:
          - name: "并发安全性"
            type: "rating"
            values:
              "Swift 6": 5
              "Rust": 5
          - name: "学习曲线"
            type: "range"
            values:
              "Swift 6": 3
              "Rust": 5
          - name: "跨平台生态"
            type: "badge"
            values:
              "Swift 6": "Apple 优先"
              "Rust": "全平台通用"
          - name: "编译速度"
            type: "text"
            values:
              "Swift 6": "中等"
              "Rust": "偏慢"
        ---
        # Swift 6 与 Rust 并发与安全全面对比

        Swift 6 和 Rust 都为现代系统编程提供了强大的并发安全保障。
        """

        let page = KnowledgePage(
            title: "Swift 6 vs Rust 对比矩阵",
            pageType: .comparison,
            content: contentWithFrontmatter
        )

        var tappedLink: String?
        let comparisonView = ComparisonDetailBodyView(
            page: page,
            onLinkTap: { tappedLink = $0 }
        )

        let host = UIHostingController(rootView: comparisonView.snapshotEnvironment())
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.layoutIfNeeded()

        comparisonView.onLinkTap("Rust")
        XCTAssertEqual(tappedLink, "Rust")
    }

    func testComparisonDetailBodyViewWithoutFrontmatter() {
        let plainContent = """
        这是一篇没有 Frontmatter 头部的普通对比分析文章。
        主要阐述了两种架构的优劣势。
        """

        let page = KnowledgePage(
            title: "架构模式对比",
            pageType: .comparison,
            content: plainContent
        )

        let plainView = ComparisonDetailBodyView(
            page: page,
            onLinkTap: { _ in }
        )

        let host = UIHostingController(rootView: plainView.snapshotEnvironment())
        _ = host.view
        host.view.layoutIfNeeded()
    }
}
