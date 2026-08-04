//
//  AppStoreTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 AppStore 开展自动化单元测试验证。
//
import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class AppStoreTests: XCTestCase {
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
    
    func testPageCreation() async {
        let initialCount = store.totalPages
        _ = await store.createPage(title: "Test Page", pageType: .concept, content: "Test Content")
        
        // Wait for ValueObservation
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertEqual(store.totalPages, initialCount + 1)
    }
    
    func testUndoRedo() async {
        let initialCount = store.totalPages
        _ = await store.createPage(title: "Undo Test", pageType: .concept)
        
        // Wait for ValueObservation
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(store.totalPages, initialCount + 1)
        
        await store.undo()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(store.totalPages, initialCount)
        
        await store.redo()
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertEqual(store.totalPages, initialCount + 1)
    }
    
    func testTagManagement() async {
        _ = await store.createPage(title: "Tag Test", pageType: .concept, tags: ["OldTag"])
        
        // Wait for ValueObservation
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(store.pages.contains { $0.tags.contains("OldTag") })
        
        await store.renameTag("OldTag", to: "NewTag")
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(store.pages.contains { $0.tags.contains("NewTag") })
        XCTAssertFalse(store.pages.contains { $0.tags.contains("OldTag") })
        
        await store.deleteTag("NewTag")
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertFalse(store.pages.contains { $0.tags.contains("NewTag") })
    }
}
