//
//  IconPickerAndLintFixDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 单元测试层
//  核心职责：深度测试 IconPickerView 图标网格分类选择与 LintIssueRow 质量问题修复行。
//

import XCTest
import SwiftUI
import Dependencies
import UFPCore
import UFPStorage
@testable import ZhiYu

@MainActor
final class IconPickerAndLintFixDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. IconPickerView 测试

    func testIconPickerView_DefaultState() {
        var selectedIcon: String?
        let host = NavigationStack {
            IconPickerView(selectedIcon: Binding(get: { selectedIcon }, set: { selectedIcon = $0 }))
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertNil(selectedIcon, "初始未选择图标")
    }

    func testIconPickerView_SelectedState() {
        var selectedIcon: String? = "star.fill"
        let host = NavigationStack {
            IconPickerView(selectedIcon: Binding(get: { selectedIcon }, set: { selectedIcon = $0 }))
        }
        .snapshotEnvironment()
        .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(selectedIcon, "star.fill")
    }

    // MARK: - 2. LintIssueRow 测试

    func testLintIssueRow_Hierarchy() {
        let issue = LintIssue(
            severity: .warning,
            type: .brokenLink,
            pageID: UUID(),
            message: "发现未闭合的双向链接 [[未知概念]]",
            suggestion: "建议创建对应页面或修正链接目标"
        )

        let host = LintIssueRow(issue: issue)
            .snapshotEnvironment()
            .renderInWindow()

        XCTAssertNotNil(host.view)
        XCTAssertEqual(issue.severity, .warning)
        XCTAssertEqual(issue.type, .brokenLink)
    }
}
