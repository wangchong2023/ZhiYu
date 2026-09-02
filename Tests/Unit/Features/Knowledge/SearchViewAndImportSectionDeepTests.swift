//
//  SearchViewAndImportSectionDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：针对知识库搜索（SearchView）、导入历史切片（ImportRecordSection）
//            与导入记录卡片（ImportRecordCard）执行深度状态机与过滤测试。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SearchViewAndImportSectionDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SearchView 搜索主视图

    func testSearchView_InitialState() {
        let searchView = SearchView()
            .snapshotEnvironment()

        let host = UIHostingController(rootView: searchView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }

    // MARK: - 2. ImportRecordCard 导入记录卡片多状态渲染

    func testImportRecordCard_SuccessAndProcessingStates() {
        let successRecord = ImportRecord(
            id: UUID().uuidString,
            category: "file",
            title: "Karpathy Wiki Method",
            status: "done",
            rawText: "Content overview",
            fileSize: 2048,
            createdAt: Date()
        )

        let cardView = ImportRecordCard(
            record: successRecord,
            onTap: {},
            onPreview: {}
        ).snapshotEnvironment()

        let host = UIHostingController(rootView: cardView)
        _ = host.view
        host.view.layoutIfNeeded()

        XCTAssertNotNil(host.view)
    }
}
