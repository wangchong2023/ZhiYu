//
//  KnowledgeStoreStressTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 KnowledgeStoreStress 开展自动化单元测试验证。
//
import XCTest
import Combine
@testable import ZhiYu

final class KnowledgeStoreStressTests: XCTestCase {
    
    @MainActor
    override func setUp() {
        super.setUp()
        setupFullMockEnvironment()
    }

    /// 验证高并发刷新下的稳定性
    @MainActor
    func testConcurrentRefreshStability() async {
        let store = KnowledgeStore()
        let iterations = 100
        
        print("🧪 [StressTest] 开始并发刷新压力测试 (迭代次数: \(iterations))...")
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    // 模拟从不同任务并发调用 MainActor 隔离的方法
                    await store.refresh()
                }
            }
        }
        
        // 压力测试后的基本状态检查
        XCTAssertEqual(store.totalPages, 0, "Mock 环境初始页面应为 0")
        XCTAssertTrue(store.pages.isEmpty)
        
        print("✅ [StressTest] 并发刷新稳定性测试通过。")
    }
    
    /// 验证动态处理器链的执行稳定性
    @MainActor
    func testProcessorInjectionAndExecution() async throws {
        let store = KnowledgeStore()
        
        // 1. 注入一个简单的处理器
        let prefixProcessor = MockPageProcessor(id: "prefix", name: "Prefixer") { page in
            var newPage = page
            newPage.content = "PROCESSED: " + page.content
            return newPage
        }
        
        store.registerProcessor(prefixProcessor)
        
        // 2. 创建页面，验证处理器是否生效
        let page = await store.createPage(title: "Test Page", pageType: .concept, content: "Hello")
        
        XCTAssertTrue(page.content.hasPrefix("PROCESSED: "))
        XCTAssertEqual(page.content, "PROCESSED: Hello")
        
        // 3. 注销处理器
        store.unregisterProcessor(id: "prefix")
        
        // 4. 再次创建页面，验证处理器已失效
        let page2 = await store.createPage(title: "Test Page 2", pageType: .concept, content: "World")
        XCTAssertEqual(page2.content, "World")
    }
}

// MARK: - 辅助 Mock 处理器
struct MockPageProcessor: KnowledgePageProcessor {
    let id: String
    let name: String
    let processHandler: @Sendable (KnowledgePage) async throws -> KnowledgePage
    
    func process(page: KnowledgePage) async throws -> KnowledgePage {
        try await processHandler(page)
    }
}
