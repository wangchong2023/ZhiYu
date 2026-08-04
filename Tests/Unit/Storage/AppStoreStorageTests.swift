//
//  AppStoreStorageTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 AppStoreStorage 开展自动化单元测试验证。
//
import XCTest
import UFPCore
@testable import ZhiYu

/// 核心状态管理器测试 (Expert QA Item #4)
/// 验证 AppStore 的 CRUD 逻辑、发布订阅一致性及内存状态安全。
@MainActor
final class AppStoreStorageTests: XCTestCase {
    var store: AppStore!
    
    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        store = AppStore()
    }
    
    override func tearDown() async throws {
        store = nil
        // 允许当前主线程/协程事件循环排水，确保所有未完成的异步任务运行完毕，规避重置 DI 导致的 Race Condition (@SRS-7.1)
        try? await Task.sleep(nanoseconds: 50_000_000)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }
    
    /// 测试页面添加与持久化
    func testAddPage() async {
        let initialCount = store.totalPages
        _ = await store.createPage(title: "测试页面", pageType: .concept, content: "内容")
        
        // 等待观察者更新内存状态
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        XCTAssertEqual(store.totalPages, initialCount + 1, "页面创建后总数应增加")
        XCTAssertTrue(store.pages.contains(where: { $0.title == "测试页面" }), "页面创建后应存在于列表中")
    }
    
    /// 测试页面更新逻辑 (Deep Scan 触发验证)
    func testUpdatePage() async {
        let page = await store.createPage(title: "初始标题", pageType: .concept, content: "初始内容")
        
        // 关键：必须等待观察者将新创建的页面同步到内存中，否则 updatePage 的 guard 将失败
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        var updatedPage = page
        updatedPage.content = "修改后的内容 [[链接测试]]"
        await store.updatePage(updatedPage, forceDeepScan: true)
        
        // 等待观察者更新内存状态
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
        
        let found = store.pages.first(where: { $0.id == page.id })
        XCTAssertEqual(found?.content, "修改后的内容 [[链接测试]]")
        XCTAssertTrue(found?.outgoingLinks.contains("链接测试") ?? false, "Deep Scan 应正确解析出反向链接")
    }
    
    /// 测试页面删除
    func testDeletePage() async {
        let page = await store.createPage(title: "待删除", pageType: .concept, content: "内容")
        let id = page.id
        
        await store.deletePage(page)
        XCTAssertFalse(store.pages.contains(where: { $0.id == id }), "页面删除后不应存在")
    }
    
    /// 测试搜索建议与过滤
    /// 验证在数据库中建立索引数据后，能够通过 SQLiteStore 检索出匹配模糊查询条件的页面。
    func testSearchSuggestions() async {
        // 1. 创建用于检索的实体测试页面
        _ = await store.createPage(title: "Apple", pageType: .entity, content: "Fruit")
        _ = await store.createPage(title: "Banana", pageType: .entity, content: "Yellow")
        
        // 2. 从依赖注入容器中解析底层的 SQLite 数据库存储实例
        let sqliteStore = ServiceContainer.shared.resolve(SQLiteStore.self)
        
        // 3. 执行关键词搜索
        let results = await sqliteStore.searchPages(query: "Apple")
        
        // 4. 断言验证检索精度
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Apple")
    }
}
