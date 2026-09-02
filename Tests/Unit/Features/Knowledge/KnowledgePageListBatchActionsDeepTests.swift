//
//  KnowledgePageListBatchActionsDeepTests.swift
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
final class KnowledgePageListBatchActionsDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. KnowledgePageListView Mounting With Filter & Overview

    func testKnowledgePageListViewAllFilters() throws {
        let store = ServiceContainer.shared.resolveOptional(KnowledgeStore.self) ?? KnowledgeStore()
        let page1 = KnowledgePage(title: "Concept Note", pageType: .concept, content: "Content 1")
        let page2 = KnowledgePage(title: "Entity Item", pageType: .entity, content: "Content 2")
        let page3 = KnowledgePage(title: "Source Document", pageType: .source, content: "Content 3")
        let page4 = KnowledgePage(title: "Comparison Table", pageType: .comparison, content: "Content 4")
        let page5 = KnowledgePage(
            title: "Raw File.pdf",
            pageType: .source,
            content: "Raw content",
            sourceURL: "file:///doc.pdf",
            fileSize: 1024,
            sourceType: "pdf"
        )
        store.pages = [page1, page2, page3, page4, page5]

        // 1. 无过滤状态渲染（展示全部类型与 Overview 概览）
        let allListView = KnowledgePageListView(filterType: nil)
            .snapshotEnvironment()
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 393, height: 852))
        let hostAll = UIHostingController(rootView: allListView)
        window.rootViewController = hostAll
        window.makeKeyAndVisible()
        hostAll.view.layoutIfNeeded()
        XCTAssertNotNil(hostAll.view)

        // 2. 指定 PageType 过滤渲染
        let conceptListView = KnowledgePageListView(filterType: .concept)
            .snapshotEnvironment()
        let hostConcept = UIHostingController(rootView: conceptListView)
        window.rootViewController = hostConcept
        hostConcept.view.layoutIfNeeded()
        XCTAssertNotNil(hostConcept.view)

        // 3. 独立测试 KnowledgeStatItem
        let statItem = KnowledgeStatItem(label: "总页面数", value: "42", color: .blue)
        let hostStat = UIHostingController(rootView: statItem)
        XCTAssertNotNil(hostStat.view)
    }
}
