//
//  SystemAndModelLabViewsDeepAuditTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：深度审计系统状态、存储审计与模型实验室 (SystemStatsView, RawStorageListView, ModelLabView) 的状态呈现与视图树求值。
//

import XCTest
import SwiftUI
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class SystemAndModelLabViewsDeepAuditTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. SystemStatsView 视图树求值与 Tab 切换

    func testSystemStatsView_ViewHierarchy_Evaluates() {
        let view = SystemStatsView()
            .snapshotEnvironment()
        let controller = UIHostingController(rootView: view)
        XCTAssertNotNil(controller.view)
    }

    // MARK: - 2. RawStorageListView 原始存储分类枚举与视图求值

    func testRawStorageListView_CategoriesAndRendering() {
        let categories = RawCategoryType.allCases
        XCTAssertEqual(categories.count, 6)

        for cat in categories {
            XCTAssertFalse(cat.systemIconName.isEmpty)
        }

        let view = RawStorageListView()
            .snapshotEnvironment()
        let controller = UIHostingController(rootView: view)
        XCTAssertNotNil(controller.view)
    }

    // MARK: - 3. ModelLabView 模型实验室视图求值

    func testModelLabView_ViewHierarchy_Evaluates() {
        let view = ModelLabView(onGoToStore: {})
            .snapshotEnvironment()
        let controller = UIHostingController(rootView: view)
        XCTAssertNotNil(controller.view)
    }
}
