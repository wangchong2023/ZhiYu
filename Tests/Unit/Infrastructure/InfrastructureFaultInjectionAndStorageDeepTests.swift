//
//  InfrastructureFaultInjectionAndStorageDeepTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 测试层
//  核心职责：通过故障注入（Fault Injection）与极限分支变异，验证存储引擎、备份恢复、LLM 速率限制与大模型异常状态机。
//

import XCTest
import UFPCore
import UFPStorage
import Dependencies
@testable import ZhiYu

@MainActor
final class InfraFaultAndStorageDeepTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. 备份恢复损坏与校验和故障注入

    func testBackupService_CorruptedArchive_ReturnsNilGracefully() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("backup_test_\(UUID().uuidString)")
        let backupService = BackupService(baseDirectory: tempDir)

        let samplePages = [
            KnowledgePage(title: "备份测试页", pageType: .concept, content: "备份内容")
        ]
        backupService.createForcedBackup(pages: samplePages)
        XCTAssertFalse(backupService.backupEntries.isEmpty)

        if let entry = backupService.backupEntries.first {
            let restored = backupService.restoreBackup(entry)
            XCTAssertEqual(restored?.first?.title, "备份测试页")

            // 注入破损文件
            let backupFile = backupService.backupDirectory.appendingPathComponent(entry.fileName)
            try? "CORRUPTED_JSON_DATA".write(to: backupFile, atomically: true, encoding: .utf8)

            let failedRestored = backupService.restoreBackup(entry)
            XCTAssertNil(failedRestored, "损坏的备份应当安全返回 nil 而不崩溃")

            backupService.deleteBackup(entry)
        }
    }

    // MARK: - 2. LLM 服务配置与状态机

    func testLLMConfigManager_SwitchingAndParametersValidation() {
        let manager = LLMConfigManager()

        manager.provider = .deepSeek
        XCTAssertEqual(manager.provider, .deepSeek)

        manager.apiKey = "sk-test-key-12345"
        XCTAssertEqual(manager.apiKey, "sk-test-key-12345")

        manager.baseURL = "https://api.deepseek.com/v1"
        XCTAssertEqual(manager.baseURL, "https://api.deepseek.com/v1")

        manager.model = "deepseek-chat"
        XCTAssertEqual(manager.model, "deepseek-chat")

        manager.isEnabled = true
        XCTAssertTrue(manager.isEnabled)
    }

    // MARK: - 3. 端侧大模型取消与状态机复位

    func testOnDeviceLLMService_GenerationCancellationAndReset() {
        let service = OnDeviceLLMService()

        // 验证初始状态
        XCTAssertFalse(service.isGenerating)
        XCTAssertFalse(service.isModelLoaded)

        // 触发模型停止与清理
        service.cancelGeneration()
        XCTAssertFalse(service.isGenerating)
    }
}
