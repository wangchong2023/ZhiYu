//
//  NotebookHubViewModelDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：深入验证 NotebookHubViewModel 的名称长度安全截断、搜索词过滤、按日期/名称排序与显示模式切换分支。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class NotebookHubViewModelDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 新建名称长度防溢出截断分支

    func testNewNotebookName_LengthLimit_CapsSafely() {
        let vm = NotebookHubViewModel()
        let hugeName = String(repeating: "A", count: DesignSystem.Metrics.maxNotebookNameLength + 20)

        vm.newNotebookName = hugeName

        XCTAssertEqual(vm.newNotebookName.count, DesignSystem.Metrics.maxNotebookNameLength,
                       "笔记本名称应当被安全截断至最大限制长度")
    }

    // MARK: - 2. 搜索词动态过滤分支

    func testNotebooks_FilteringBySearchText() {
        let vm = NotebookHubViewModel()
        let v1 = Vault(id: UUID(), name: "机器学习调研", createdAt: Date(), updatedAt: Date(), pageCount: 1)
        let v2 = Vault(id: UUID(), name: "个人生活随笔", createdAt: Date(), updatedAt: Date(), pageCount: 1)
        VaultService.shared.vaults = [v1, v2]

        vm.searchText = "机器"
        XCTAssertEqual(vm.notebooks.count, 1)
        XCTAssertEqual(vm.notebooks.first?.name, "机器学习调研")
    }

    // MARK: - 3. 排序策略切换分支（按日期 vs 按名称）

    func testNotebooks_SortingByDateAndName() {
        let vm = NotebookHubViewModel()
        let now = Date()
        let v1 = Vault(id: UUID(), name: "B 笔记本", createdAt: now.addingTimeInterval(-100), updatedAt: now.addingTimeInterval(-100), pageCount: 1)
        let v2 = Vault(id: UUID(), name: "A 笔记本", createdAt: now, updatedAt: now, pageCount: 1)
        VaultService.shared.vaults = [v1, v2]

        // 1. 按日期排序（最新在前）
        vm.sortOption = .date
        XCTAssertEqual(vm.notebooks.first?.name, "A 笔记本")

        // 2. 按名称排序（A-Z）
        vm.sortOption = .name
        XCTAssertEqual(vm.notebooks.first?.name, "A 笔记本")
        XCTAssertEqual(vm.notebooks.last?.name, "B 笔记本")
    }

    // MARK: - 4. 空白名称重命名拦截分支

    func testConfirmRename_WhenWhitespace_DoesNotRename() {
        let vm = NotebookHubViewModel()
        let vault = Vault(id: UUID(), name: "原名称", createdAt: Date(), updatedAt: Date(), pageCount: 1)
        VaultService.shared.vaults = [vault]

        vm.prepareRename(vault)
        vm.editingName = "   "
        vm.confirmRename()

        XCTAssertEqual(VaultService.shared.vaults.first(where: { $0.id == vault.id })?.name, "原名称",
                       "空白名称应当被拒绝重命名")
    }
}
