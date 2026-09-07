//
//  RouterTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 Router 开展自动化单元测试验证。
//
import XCTest
import SwiftUI
@testable import ZhiYu

@MainActor
final class RouterTests: XCTestCase {
    
    var router: Router!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        // Router 是单例，测试前清空历史
        router = Router.shared
        router.clearHistory()
    }
    
    @MainActor
    override func tearDown() async throws {
        router.clearHistory()
        router = nil
        try await super.tearDown()
    }
    
    // MARK: - History Tests
    
    /// 验证基础入栈逻辑 (SRS-6.4)
    func testAddToHistory_BasicPush() {
        let pageA = KnowledgePage(title: "Page A")
        router.addToHistory(pageA)
        
        XCTAssertEqual(router.navigationHistory.count, 1)
        XCTAssertEqual(router.navigationHistory.last?.id, pageA.id)
    }
    
    /// 验证连续去重逻辑 (A -> A 应只有 1 个 A) (SRS-6.4)
    func testAddToHistory_Deduplication() {
        let pageA = KnowledgePage(title: "Page A")
        router.addToHistory(pageA)
        router.addToHistory(pageA) // 再次尝试添加同一个页面
        
        XCTAssertEqual(router.navigationHistory.count, 1, "连续添加同一页面应当去重")
    }
    
    /// 验证非连续重复逻辑 (A -> B -> A 应保留 [A, B, A]) (SRS-6.4)
    /// 这是为了确保用户能从 A 跳到 B，再跳回 A 时，面包屑能正确反映路径
    func testAddToHistory_CircularNavigation() {
        let pageA = KnowledgePage(title: "Page A")
        let pageB = KnowledgePage(title: "Page B")
        
        router.addToHistory(pageA)
        router.addToHistory(pageB)
        router.addToHistory(pageA)
        
        XCTAssertEqual(router.navigationHistory.count, 3)
        XCTAssertEqual(router.navigationHistory.map { $0.title }, ["Page A", "Page B", "Page A"])
    }
    
    /// 验证历史长度限制 (最大 5 个) (SRS-6.4)
    func testAddToHistory_LimitLength() {
        let pages = (1...6).map { KnowledgePage(title: "Page \($0)") }
        
        for page in pages {
            router.addToHistory(page)
        }
        
        XCTAssertEqual(router.navigationHistory.count, 5, "历史长度不应超过 5 个")
        XCTAssertEqual(router.navigationHistory.first?.title, "Page 2", "最旧的 Page 1 应当被移除")
        XCTAssertEqual(router.navigationHistory.last?.title, "Page 6", "最新的 Page 6 应当在末尾")
    }
    
    /// 验证清空历史功能 (SRS-6.4)
    func testClearHistory() {
        router.addToHistory(KnowledgePage(id: UUID(), title: "Page 1", content: "", createdAt: Date(), updatedAt: Date()))
        router.clearHistory()
        XCTAssertTrue(router.navigationHistory.isEmpty, "清空后历史应为空")
    }
}
