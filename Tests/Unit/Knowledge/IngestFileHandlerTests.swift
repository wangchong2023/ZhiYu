//
//  IngestFileHandlerTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层测试
//  核心职责：验证 IngestCoordinator 文件导入的频控、错误处理与扩展名分派逻辑。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class IngestFileHandlerTests: XCTestCase {

    /// 被测协调器
    private var coordinator: IngestCoordinator!

    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()
        _ = AppStore()
        coordinator = IngestCoordinator()
    }

    override func tearDown() async throws {
        coordinator = nil
        resetPersistentTestState()
        try? await Task.sleep(nanoseconds: 50_000_000)
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - isImporting 频控

    /// 验证初始状态不在冷却期
    func testIsImportingInitialFalse() {
        coordinator.lastImportTime = .distantPast
        XCTAssertFalse(coordinator.isImporting, "初始 lastImportTime 为 distantPast，不应在冷却期")
    }

    /// 验证刚导入后处于冷却期
    func testIsImportingTrueAfterRecentImport() {
        coordinator.lastImportTime = Date()
        XCTAssertTrue(coordinator.isImporting, "刚导入后应在冷却期")
    }

    /// 验证冷却期结束后可再次导入
    func testIsImportingFalseAfterCooldown() {
        let cooldown = AppConstants.Keys.ImportLimits.importCooldownSeconds
        coordinator.lastImportTime = Date().addingTimeInterval(-cooldown - 1)
        XCTAssertFalse(coordinator.isImporting, "冷却期结束后不应在冷却期")
    }

    // MARK: - handleFileImport 频控分支

    /// 验证冷却期内调用 handleFileImport 不触发导入（errorMessage 不被设置）
    func testHandleFileImportCooldownSkipsImport() {
        coordinator.lastImportTime = Date()
        let url = URL(fileURLWithPath: "/tmp/test.md")
        coordinator.handleFileImport(.success([url]))

        // 冷却期内应跳过导入，errorMessage 保持 nil
        XCTAssertNil(coordinator.errorMessage, "冷却期内应跳过导入，不设置 errorMessage")
        XCTAssertFalse(coordinator.showError, "冷却期内不应显示错误")
    }

    // MARK: - handleFileImport 错误分支

    /// 验证 failure 结果设置 errorMessage 并显示
    func testHandleFileImportFailureSetsError() {
        coordinator.lastImportTime = .distantPast
        struct TestError: Error, LocalizedError {
            var errorDescription: String? { "导入失败测试" }
        }
        coordinator.handleFileImport(.failure(TestError()))

        XCTAssertEqual(coordinator.errorMessage, "导入失败测试", "failure 应设置 errorMessage")
        XCTAssertTrue(coordinator.showError, "failure 应显示错误")
    }

    /// 验证空 URL 列表的 success 不报错
    func testHandleFileImportEmptySuccessNoError() {
        coordinator.lastImportTime = .distantPast
        coordinator.handleFileImport(.success([]))

        XCTAssertNil(coordinator.errorMessage, "空 URL 列表不应设置 errorMessage")
        XCTAssertFalse(coordinator.showError, "空 URL 列表不应显示错误")
    }

    // MARK: - extractImagesFromFile 扩展名分派

    /// 验证未知扩展名返回空字符串
    func testExtractImagesFromFileUnknownExtensionReturnsEmpty() async {
        let url = URL(fileURLWithPath: "/tmp/test.unknown")
        let result = await coordinator.extractImagesFromFile(url: url)
        XCTAssertTrue(result.isEmpty, "未知扩展名应返回空字符串")
    }

    /// 验证 md 扩展名返回空字符串（不触发 OCR）
    func testExtractImagesFromFileMarkdownReturnsEmpty() async {
        let url = URL(fileURLWithPath: "/tmp/test.md")
        let result = await coordinator.extractImagesFromFile(url: url)
        XCTAssertTrue(result.isEmpty, "md 文件不触发 OCR，应返回空")
    }

    /// 验证 txt 扩展名返回空字符串
    func testExtractImagesFromFileTxtReturnsEmpty() async {
        let url = URL(fileURLWithPath: "/tmp/test.txt")
        let result = await coordinator.extractImagesFromFile(url: url)
        XCTAssertTrue(result.isEmpty, "txt 文件不触发 OCR，应返回空")
    }

    // MARK: - isLLMConfigured

    /// 验证 isLLMConfigured 反映 LLM 服务状态
    func testIsLLMConfiguredReflectsLLMService() {
        // MockLLMService 默认 isEnabled=true, apiKey=""
        XCTAssertFalse(coordinator.isLLMConfigured, "apiKey 为空时 isLLMConfigured 应为 false")
    }
}
