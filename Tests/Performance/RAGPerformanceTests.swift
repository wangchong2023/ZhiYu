//
//  RAGPerformanceTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 RAGPerformance 开展自动化单元测试验证。
//
import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class RAGPerformanceTests: XCTestCase {
    var llmService: LLMService!
    var largeCandidates: [KnowledgePage] = []
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()

        // 由于 RerankService 是一个真实服务单例，获取其实例
        llmService = LLMService.shared
        
        // 构建用于压测性能的大规模文本语料假数据 (1000 篇 Page)
        var mockPages: [KnowledgePage] = []
        for i in 0..<1000 {
            // 设置部分相关的语料
            let keyword = (i % 50 == 0) ? "Apple Vision Pro 空间计算" : "这是一段与苹果设备完全不相关的随机填充文档测试内容"
            
            let page = KnowledgePage(
                title: "MockPage_\(i)",
                pageType: .source,
                content: "这是第 \(i) 篇测试文档，它包含的特征短语是：\(keyword)"
            )
            mockPages.append(page)
        }
        self.largeCandidates = mockPages
    }
    
    @MainActor
    override func tearDown() async throws {
        self.largeCandidates = []
        self.llmService = nil
        // 允许当前协程事件循环排水，确保未完成的异步任务执行完毕
        try? await Task.sleep(nanoseconds: 50_000_000)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }
    
    /// 测量 1000 篇长文档在单次 Rerank 重排计算下消耗的 CPU 时钟周期
    ///
    /// 使用 ContinuousClock 进行手动计时，替代同步 measure { Task + expectation + wait } 模式，
    /// 根治 Swift 6 严格并发下非结构化 Task 的 task-local 未正确清理导致的 _swift_task_dealloc_specific SIGABRT 崩溃。
    func testRerankAlgorithmPerformance() async throws {
        let query = "Apple Vision Pro 空间"

        guard let service = self.llmService else {
            XCTFail("LLMService is not initialized")
            return
        }
        let candidates = self.largeCandidates

        let clock = ContinuousClock()
        let elapsed = try await clock.measure {
            _ = try await service.rerank(query: query, candidates: candidates)
        }

        Logger.shared.info("[RAGPerformance] Rerank 1000篇文档耗时: \(elapsed.components.seconds)秒")
        // 断言重排在合理时间内完成（连续定时器场景下10秒为安全阈值）
        XCTAssertLessThan(elapsed, .seconds(10), "重排计算应在合理时间内完成")
    }
}
