//
//  KnowledgeStoreTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 KnowledgeStore 的纯逻辑与数据操作开展单元测试。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class KnowledgeStoreSimpleTests: XCTestCase {

    // MARK: - 初始状态

    func testInitialState() {
        let store = KnowledgeStore()
        XCTAssertTrue(store.pages.isEmpty, "初始页面列表应为空")
        XCTAssertEqual(store.totalPages, 0)
        XCTAssertEqual(store.totalWords, 0)
        XCTAssertFalse(store.isScanning)
        XCTAssertFalse(store.showCreateSheet)
    }

    func testPagesMutability() {
        let store = KnowledgeStore()
        let page = KnowledgePage(title: "测试")
        store.pages = [page]
        XCTAssertEqual(store.pages.count, 1)
        XCTAssertEqual(store.pages.first?.title, "测试")
    }

    func testTotalWordsSettable() {
        let store = KnowledgeStore()
        store.totalWords = 100
        XCTAssertEqual(store.totalWords, 100)
    }
}

// MARK: - 知识库与金库数据同步测试
@MainActor
final class KnowledgeStoreSyncTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    /// 验证当 KnowledgeStore 创建新页面时，当前活跃金库的 pageCount 会被同步更新并存回元数据
    func testPageCountSynchronizationWithVaultService() async throws {
        // 临时使用真实的 DatabaseManager 注册为 switcher，以支持真实数据库的页面计数
        let mockSwitcher = ServiceContainer.shared.resolve((any VaultDatabaseSwitcher).self)
        ServiceContainer.shared.register(DatabaseManager.shared as any VaultDatabaseSwitcher, for: (any VaultDatabaseSwitcher).self)
        
        defer {
            // 测试结束恢复 mock switcher，避免污染其他用例
            ServiceContainer.shared.register(mockSwitcher, for: (any VaultDatabaseSwitcher).self)
        }

        let vaultID = UUID()
        let vault = Vault(
            id: vaultID,
            name: "SyncTestVault",
            createdAt: Date(),
            updatedAt: Date(),
            pageCount: 0,
            themePayload: nil,
            icon: "📚",
            description: "Test description"
        )
        
        // 设置当前活跃的笔记本
        VaultService.shared.vaults = [vault]
        VaultService.shared.selectedVaultID = vaultID
        
        // 验证初始页数为 0
        XCTAssertEqual(VaultService.shared.vaults.first?.pageCount, 0)
        
        // 构造并解析 KnowledgeStore
        let store = ServiceContainer.shared.resolve(KnowledgeStore.self)
        
        // 新建一个页面，会自动触发 refresh() 并同步 pageCount
        _ = await store.createPage(title: "Test Sync Page", pageType: .concept, content: "Hello Test")
        
        // 验证 VaultService 中的当前笔记本页面数量也被自动同步为 1
        XCTAssertEqual(VaultService.shared.vaults.first?.pageCount, 1)
        XCTAssertEqual(VaultService.shared.currentVault?.pageCount, 1)
    }
}
