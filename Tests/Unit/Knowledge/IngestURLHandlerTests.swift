//
//  IngestURLHandlerTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 IngestCoordinator URL 导入的 SSRF 防护、频控与批量任务编排逻辑。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class IngestURLHandlerTests: XCTestCase {

    /// 被测协调器
    private var coordinator: IngestCoordinator!
    /// 持有 handleBatchURLImport 返回的 Task handle，供 tearDown 等待异步任务完成后再清理 DI
    /// 架构修复：此前 handleBatchURLImport 内部启动未结构化 Task 无 handle 返回，
    /// tearDown 的 50ms sleep 不足以等待网络请求完成，DI 清空后异步任务访问 @Inject 触发 fatalError
    private var pendingImportTask: Task<Void, Never>?

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        _ = AppStore()
        coordinator = IngestCoordinator()
        pendingImportTask = nil
    }

    override func tearDown() async throws {
        // 先等待 handleBatchURLImport 启动的异步任务完成，再清理 DI
        // 避免异步任务在 DI 清空后访问 @Inject 属性触发 fatalError
        if let task = pendingImportTask {
            await task.value
            pendingImportTask = nil
        }
        coordinator = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - extractImagesFromURL SSRF 防护

    /// 验证无效 URL 返回空字符串
    func testExtractImagesFromURLInvalidURLReturnsEmpty() async throws {
        let result = try await coordinator.extractImagesFromURL("not-a-valid-url")
        XCTAssertTrue(result.isEmpty, "无效 URL 应返回空字符串")
    }

    /// 验证内网 IP URL 被 SSRF 阻断返回空
    func testExtractImagesFromURLPrivateIPBlocked() async throws {
        let result = try await coordinator.extractImagesFromURL("http://192.168.1.1/test")
        XCTAssertTrue(result.isEmpty, "内网 IP 应被 SSRF 阻断返回空")
    }

    /// 验证环回地址被 SSRF 阻断
    func testExtractImagesFromURLLoopbackBlocked() async throws {
        let result = try await coordinator.extractImagesFromURL("http://127.0.0.1/test")
        XCTAssertTrue(result.isEmpty, "环回地址应被 SSRF 阻断")
    }

    /// 验证链路本地地址被 SSRF 阻断
    func testExtractImagesFromURLLinkLocalBlocked() async throws {
        let result = try await coordinator.extractImagesFromURL("http://169.254.1.1/test")
        XCTAssertTrue(result.isEmpty, "链路本地地址应被 SSRF 阻断")
    }

    // MARK: - handleBatchURLImport 频控

    /// 验证冷却期内调用 handleBatchURLImport 跳过导入
    func testHandleBatchURLImportCooldownSkipsImport() {
        coordinator.lastImportTime = Date()
        pendingImportTask = coordinator.handleBatchURLImport([URL(string: "https://example.com")!])

        // 冷却期内应跳过，showURLImport 不被改变（保持默认 false）
        XCTAssertFalse(coordinator.showURLImport, "冷却期内应跳过导入，showURLImport 保持 false")
    }

    /// 验证非冷却期调用 handleBatchURLImport 关闭 URL 导入面板
    func testHandleBatchURLImportClosesPanel() {
        coordinator.lastImportTime = .distantPast
        coordinator.showURLImport = true
        pendingImportTask = coordinator.handleBatchURLImport([URL(string: "https://example.com")!])

        XCTAssertFalse(coordinator.showURLImport, "导入开始后应关闭 URL 导入面板")
    }

    /// 验证空 URL 列表不触发导入（totalCount=0）
    func testHandleBatchURLImportEmptyListNoError() {
        coordinator.lastImportTime = .distantPast
        pendingImportTask = coordinator.handleBatchURLImport([])

        // 空 list 不应崩溃，showURLImport 仍被关闭
        XCTAssertFalse(coordinator.showURLImport, "空列表应关闭面板")
        XCTAssertNil(coordinator.errorMessage, "空列表不应设置 errorMessage")
    }

    // MARK: - SSRF 防护边界

    /// 验证 file:// scheme 被 SSRF 阻断
    func testExtractImagesFromURLFileSchemeBlocked() async throws {
        let result = try await coordinator.extractImagesFromURL("file:///etc/passwd")
        XCTAssertTrue(result.isEmpty, "file:// scheme 应被 SSRF 阻断")
    }

    /// 验证非 http/https scheme 返回空
    func testExtractImagesFromURLNonHTTPSchemeReturnsEmpty() async throws {
        let result = try await coordinator.extractImagesFromURL("ftp://example.com/test")
        XCTAssertTrue(result.isEmpty, "ftp:// scheme 应返回空")
    }
}
