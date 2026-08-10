//
//  NotebookHubViewModelTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 NotebookHubViewModel 的过滤排序、创建/编辑/重命名流程与名称长度限制。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class NotebookHubViewModelTests: XCTestCase {

    private var viewModel: NotebookHubViewModel!
    private var vaultService: VaultService { VaultService.shared }

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        vaultService.vaults = []
        vaultService.selectedVaultID = nil
        viewModel = NotebookHubViewModel()
    }

    override func tearDown() async throws {
        viewModel = nil
        vaultService.vaults = []
        vaultService.selectedVaultID = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 初始状态

    /// 验证初始 displayMode 为 grid
    func testInitialDisplayModeGrid() {
        XCTAssertEqual(viewModel.displayMode, .grid)
    }

    /// 验证初始 sortOption 为 date
    func testInitialSortOptionDate() {
        XCTAssertEqual(viewModel.sortOption, .date)
    }

    /// 验证初始 isShowingCreateSheet 为 false
    func testInitialIsShowingCreateSheetFalse() {
        XCTAssertFalse(viewModel.isShowingCreateSheet)
    }

    /// 验证初始 newNotebookName 为空
    func testInitialNewNotebookNameEmpty() {
        XCTAssertEqual(viewModel.newNotebookName, "")
    }

    /// 验证初始 searchText 为空
    func testInitialSearchTextEmpty() {
        XCTAssertEqual(viewModel.searchText, "")
    }

    // MARK: - toggleDisplayMode

    /// 验证 toggleDisplayMode 切换 grid ↔ list
    func testToggleDisplayModeSwitches() {
        viewModel.toggleDisplayMode()
        XCTAssertEqual(viewModel.displayMode, .list)

        viewModel.toggleDisplayMode()
        XCTAssertEqual(viewModel.displayMode, .grid)
    }

    // MARK: - newNotebookName 长度限制

    /// 验证 newNotebookName 超长截断
    func testNewNotebookNameTruncates() {
        let limit = DesignSystem.Metrics.maxNotebookNameLength
        viewModel.newNotebookName = String(repeating: "a", count: limit + 10)
        XCTAssertEqual(viewModel.newNotebookName.count, limit)
    }

    /// 验证 editingName 超长截断
    func testEditingNameTruncates() {
        let limit = DesignSystem.Metrics.maxNotebookNameLength
        viewModel.editingName = String(repeating: "b", count: limit + 5)
        XCTAssertEqual(viewModel.editingName.count, limit)
    }

    // MARK: - notebooks 过滤与排序

    /// 验证 notebooks 按创建时间倒序
    func testNotebooksSortedByDateDescending() {
        let older = Vault(id: UUID(), name: "旧", createdAt: Date(timeIntervalSinceNow: -100), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: nil, description: nil)
        let newer = Vault(id: UUID(), name: "新", createdAt: Date(), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: nil, description: nil)
        vaultService.vaults = [older, newer]

        XCTAssertEqual(viewModel.notebooks.first?.name, "新")
        XCTAssertEqual(viewModel.notebooks.last?.name, "旧")
    }

    /// 验证 notebooks 按名称排序
    func testNotebooksSortedByName() {
        let b = Vault(id: UUID(), name: "Banana", createdAt: Date(), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: nil, description: nil)
        let a = Vault(id: UUID(), name: "Apple", createdAt: Date(), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: nil, description: nil)
        vaultService.vaults = [b, a]
        viewModel.sortOption = .name

        XCTAssertEqual(viewModel.notebooks.first?.name, "Apple")
        XCTAssertEqual(viewModel.notebooks.last?.name, "Banana")
    }

    /// 验证 notebooks 按 searchText 过滤
    func testNotebooksFilteredBySearchText() {
        let alpha = Vault(id: UUID(), name: "Alpha", createdAt: Date(), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: nil, description: nil)
        let beta = Vault(id: UUID(), name: "Beta", createdAt: Date(), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: nil, description: nil)
        vaultService.vaults = [alpha, beta]
        viewModel.searchText = "alp"

        XCTAssertEqual(viewModel.notebooks.count, 1)
        XCTAssertEqual(viewModel.notebooks.first?.name, "Alpha")
    }

    /// 验证 searchText 大小写不敏感
    func testNotebooksSearchCaseInsensitive() {
        let upper = Vault(id: UUID(), name: "UPPER", createdAt: Date(), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: nil, description: nil)
        vaultService.vaults = [upper]
        viewModel.searchText = "upper"

        XCTAssertEqual(viewModel.notebooks.count, 1)
    }

    /// 验证空 searchText 返回全部
    func testNotebooksEmptySearchReturnsAll() {
        vaultService.vaults = [
            Vault(id: UUID(), name: "A", createdAt: Date(), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: nil, description: nil),
            Vault(id: UUID(), name: "B", createdAt: Date(), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: nil, description: nil)
        ]
        XCTAssertEqual(viewModel.notebooks.count, 2)
    }

    // MARK: - createNotebook

    /// 验证 createNotebook 空名称不创建
    func testCreateNotebookEmptyNameNoOp() {
        viewModel.newNotebookName = "   "
        viewModel.createNotebook()
        XCTAssertTrue(vaultService.vaults.isEmpty)
        XCTAssertFalse(viewModel.isShowingCreateSheet)
    }

    /// 验证 createNotebook 有效名称创建并重置状态
    func testCreateNotebookValidNameCreatesAndResets() {
        viewModel.newNotebookName = "新笔记本"
        viewModel.newNotebookIcon = "📚"
        viewModel.newNotebookDescription = "描述"
        viewModel.isShowingCreateSheet = true

        viewModel.createNotebook()

        XCTAssertEqual(vaultService.vaults.count, 1)
        XCTAssertEqual(vaultService.vaults.first?.name, "新笔记本")
        XCTAssertEqual(viewModel.newNotebookName, "")
        XCTAssertEqual(viewModel.newNotebookDescription, "")
        XCTAssertFalse(viewModel.isShowingCreateSheet)
    }

    /// 验证 createNotebook 空白 icon 转为 nil
    func testCreateNotebookBlankIconBecomesNil() {
        viewModel.newNotebookName = "测试"
        viewModel.newNotebookIcon = "   "
        viewModel.createNotebook()

        XCTAssertNil(vaultService.vaults.first?.icon)
    }

    // MARK: - deleteNotebook

    /// 验证 deleteNotebook 删除指定笔记本
    func testDeleteNotebookRemovesVault() {
        vaultService.createVault(name: "待删")
        let id = vaultService.vaults.first?.id ?? UUID()

        viewModel.deleteNotebook(id: id)

        XCTAssertTrue(vaultService.vaults.isEmpty)
    }

    // MARK: - prepareEdit / confirmEdit

    /// 验证 prepareEdit 填充编辑字段
    func testPrepareEditPopulatesFields() {
        let vault = Vault(id: UUID(), name: "原名", createdAt: Date(), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: "icon", description: "desc")
        vaultService.vaults = [vault]

        viewModel.prepareEdit(vault)

        XCTAssertEqual(viewModel.editingVault?.id, vault.id)
        XCTAssertEqual(viewModel.editingName, "原名")
        XCTAssertEqual(viewModel.editingIcon, "icon")
        XCTAssertEqual(viewModel.editingDescription, "desc")
        XCTAssertTrue(viewModel.isShowingEditSheet)
    }

    /// 验证 confirmEdit 保存更新
    func testConfirmEditSavesUpdates() {
        let vault = Vault(id: UUID(), name: "原名", createdAt: Date(), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: nil, description: nil)
        vaultService.vaults = [vault]
        viewModel.prepareEdit(vault)
        viewModel.editingName = "新名"
        viewModel.editingIcon = "new"
        viewModel.editingDescription = "新描述"

        viewModel.confirmEdit()

        XCTAssertEqual(vaultService.vaults.first?.name, "新名")
        XCTAssertEqual(vaultService.vaults.first?.icon, "new")
        XCTAssertEqual(vaultService.vaults.first?.description, "新描述")
        XCTAssertNil(viewModel.editingVault)
        XCTAssertFalse(viewModel.isShowingEditSheet)
    }

    /// 验证 confirmEdit 无 editingVault 不崩溃
    func testConfirmEditNoEditingVaultNoCrash() {
        viewModel.confirmEdit()
        XCTAssertNil(viewModel.editingVault)
    }

    // MARK: - prepareRename / confirmRename

    /// 验证 prepareRename 设置状态
    func testPrepareRenameSetsState() {
        let vault = Vault(id: UUID(), name: "原名", createdAt: Date(), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: nil, description: nil)
        vaultService.vaults = [vault]

        viewModel.prepareRename(vault)

        XCTAssertEqual(viewModel.editingVault?.id, vault.id)
        XCTAssertEqual(viewModel.editingName, "原名")
        XCTAssertTrue(viewModel.isShowingRenameAlert)
    }

    /// 验证 confirmRename 执行重命名
    func testConfirmRenameRenames() {
        let vault = Vault(id: UUID(), name: "原名", createdAt: Date(), updatedAt: Date(), pageCount: 0, themePayload: nil, icon: nil, description: nil)
        vaultService.vaults = [vault]
        viewModel.prepareRename(vault)
        viewModel.editingName = "重命名后"

        viewModel.confirmRename()

        XCTAssertEqual(vaultService.vaults.first?.name, "重命名后")
        XCTAssertNil(viewModel.editingVault)
        XCTAssertFalse(viewModel.isShowingRenameAlert)
    }

    /// 验证 confirmRename 无 editingVault 不崩溃
    func testConfirmRenameNoEditingVaultNoCrash() {
        viewModel.confirmRename()
        XCTAssertNil(viewModel.editingVault)
    }
}
