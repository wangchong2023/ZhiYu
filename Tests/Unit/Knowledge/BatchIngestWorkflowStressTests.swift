//
//  BatchIngestWorkflowStressTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 测试层
//  核心职责：深入验证 IngestQueue 离线摄入队列并发控制、保险库切换任务取消、PDF 元数据持久化与 IngestStore 业务分支。
//

import XCTest
import UFPCore
import Dependencies
@testable import ZhiYu

@MainActor
final class BatchIngestWorkflowStressTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    override func tearDown() async throws {
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 1. 队列任务入队与计数分支

    func testIngestQueue_EnqueueTasks_IncrementsPendingCount() {
        let queue = IngestQueue.shared
        let initialPending = queue.pendingCount

        let mockLLM = MockLLMService()
        queue.enqueue(title: "文档 A", content: "内容 A", llmService: mockLLM, pages: []) { _ in }

        XCTAssertEqual(queue.pendingCount, initialPending + 1, "入队后 pendingCount 应当自增")
    }

    // MARK: - 2. 保险库切换时全局任务强制取消与状态重置分支

    func testIngestQueue_WhenVaultWillSwitch_CancelsAllTasks() {
        let queue = IngestQueue.shared
        let mockLLM = MockLLMService()
        queue.enqueue(title: "大文档 B", content: "超长内容", llmService: mockLLM, pages: []) { _ in }

        // 发送 vaultWillSwitch 广播通知
        NotificationCenter.default.post(name: .vaultWillSwitch, object: nil)

        XCTAssertEqual(queue.pendingCount, 0, "保险库切换时应立即清空所有挂起任务计数")
        XCTAssertFalse(queue.isProcessing, "处理状态应当重置为 false")
    }

    // MARK: - 3. IngestStore PDF 元数据管理分支

    func testIngestStore_PDFMetadataOperations() async {
        let store = IngestStore()
        let pdfInfo = PDFDocumentInfo(
            id: UUID(),
            title: "WWDC 2026 RAG 架构设计指南",
            fileName: "wwdc2026_rag.pdf",
            pageCount: 15,
            addedDate: Date()
        )

        await store.savePDFDocument(pdfInfo)
        let loaded = await store.loadPDFDocument(id: pdfInfo.id)

        XCTAssertEqual(loaded?.title, "WWDC 2026 RAG 架构设计指南")
        XCTAssertEqual(loaded?.pageCount, 15)
    }
}
