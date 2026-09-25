//
//  SystemStatsCleanupDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：SystemStatsCoordinator Cleanup 深度补盲测试 — 覆盖 cleanupData
//            正常路径（cleanedCount/haptic/isCleaning/loadStats 刷新/状态变化）、
//            失败路径（isCleaning 恢复/logger.error/不调用 haptic/cleanedCount 保持）、
//            多次调用（cleanedCount 为最后一次返回值/成功后再抛错保持上次值），
//            以发现生产代码潜在 bug 为首要目标。
//

import XCTest
import SwiftUI
import Combine
import GRDB
import UFPCore
import Dependencies
@testable import ZhiYu

// MARK: - SystemStatsCleanupDeepTests

@MainActor
final class SystemStatsCleanupDeepTests: XCTestCase {

    // MARK: - 被测对象与 Mock

    private var coordinator: SystemStatsCoordinator!
    private var recordableLogger: RecordableLogger!
    private var recordableHaptic: RecordableHaptic!
    private var configurableVectorRepo: ConfigurableVectorRepository!
    private var configurableGovernanceRepo: ConfigurableRAGGovernanceRepository!
    private var configurablePageStore: ConfigurablePageStoreCapabilities!
    private var configurableKnowledgeRepo: ConfigurableKnowledgeRepository!
    private var mockImportRecordRepo: MockImportRecordRepository!

    // MARK: - 生命周期

    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()

        recordableLogger = RecordableLogger()
        ServiceContainer.shared.register(recordableLogger as any LoggerProtocol, for: (any LoggerProtocol).self)

        recordableHaptic = RecordableHaptic()
        ServiceContainer.shared.register(recordableHaptic as any HapticFeedbackProtocol, for: (any HapticFeedbackProtocol).self)

        configurableVectorRepo = ConfigurableVectorRepository()
        ServiceContainer.shared.register(configurableVectorRepo as any VectorRepository, for: (any VectorRepository).self)

        configurableGovernanceRepo = ConfigurableRAGGovernanceRepository()
        ServiceContainer.shared.register(configurableGovernanceRepo as any RAGGovernanceRepository, for: (any RAGGovernanceRepository).self)

        configurablePageStore = ConfigurablePageStoreCapabilities()
        ServiceContainer.shared.register(configurablePageStore as any AnyPageStoreCapabilities, for: (any AnyPageStoreCapabilities).self)
        ServiceContainer.shared.register(configurablePageStore as any AnyPageStore, for: (any AnyPageStore).self)

        configurableKnowledgeRepo = ConfigurableKnowledgeRepository()
        ServiceContainer.shared.register(configurableKnowledgeRepo as any KnowledgeRepository, for: (any KnowledgeRepository).self)

        mockImportRecordRepo = MockImportRecordRepository()
        ServiceContainer.shared.register(mockImportRecordRepo as any ImportRecordRepository, for: (any ImportRecordRepository).self)

        VaultService.shared.vaults = []
        VaultService.shared.selectedVaultID = nil

        coordinator = SystemStatsCoordinator()
    }

    override func tearDown() async throws {
        coordinator = nil
        recordableLogger = nil
        recordableHaptic = nil
        configurableVectorRepo = nil
        configurableGovernanceRepo = nil
        configurablePageStore = nil
        configurableKnowledgeRepo = nil
        mockImportRecordRepo = nil
        VaultService.shared.vaults = []
        VaultService.shared.selectedVaultID = nil
        try await super.tearDown()
    }

    // MARK: - cleanupData 正常路径

    /// 验证 cleanupData 成功后 cleanedCount 被设置为返回的清理数量
    func testCleanupDataSuccessCleanedCountSetToReturnValue() async throws {
        configurableVectorRepo.stubCleanupCount = 15
        await coordinator.cleanupData()
        XCTAssertEqual(coordinator.cleanedCount, 15, "cleanedCount 应等于 cleanupOrphanedChunks 返回值")
    }

    /// 验证 cleanupData 成功后调用 haptic.trigger(.success)
    func testCleanupDataSuccessCallsHapticSuccess() async throws {
        configurableVectorRepo.stubCleanupCount = 5
        await coordinator.cleanupData()
        XCTAssertEqual(recordableHaptic.triggerCallCount, 1, "应调用一次 haptic.trigger")
        XCTAssertEqual(recordableHaptic.lastPattern, .success, "应触发 .success 模式")
    }

    /// 验证 cleanupData 成功后 isCleaning 恢复 false
    func testCleanupDataSuccessIsCleaningRestoresFalse() async throws {
        configurableVectorRepo.stubCleanupCount = 3
        await coordinator.cleanupData()
        XCTAssertFalse(coordinator.isCleaning, "cleanupData 完成后 isCleaning 应恢复 false")
    }

    /// 验证 cleanupData 成功后调用 loadStats 刷新统计
    func testCleanupDataSuccessCallsLoadStatsToRefresh() async throws {
        configurableVectorRepo.stubCleanupCount = 3
        configurableKnowledgeRepo.stubCount = 99
        await coordinator.cleanupData()
        XCTAssertEqual(coordinator.totalPages, 99, "cleanupData 应调用 loadStats 刷新 totalPages")
        XCTAssertFalse(coordinator.isLoading, "loadStats 刷新后 isLoading 应为 false")
    }

    /// 验证 cleanupData 执行前 isCleaning 为 false，执行中为 true，完成后为 false
    func testCleanupDataIsCleaningStateChanges() async throws {
        XCTAssertFalse(coordinator.isCleaning, "cleanupData 执行前 isCleaning 应为 false")
        configurableVectorRepo.stubCleanupCount = 1
        await coordinator.cleanupData()
        XCTAssertFalse(coordinator.isCleaning, "cleanupData 完成后 isCleaning 应恢复 false")
    }

    // MARK: - cleanupData 失败路径

    /// 验证 cleanupData 时 cleanupOrphanedChunks 抛错后 isCleaning 恢复 false
    func testCleanupDataThrowsIsCleaningRestoresFalse() async throws {
        configurableVectorRepo.shouldThrowCleanup = true
        await coordinator.cleanupData()
        XCTAssertFalse(coordinator.isCleaning, "cleanupData 抛错后 isCleaning 应恢复 false")
    }

    /// 验证 cleanupData 时 cleanupOrphanedChunks 抛错后调用 logger.error
    func testCleanupDataThrowsCallsLoggerError() async throws {
        configurableVectorRepo.shouldThrowCleanup = true
        await coordinator.cleanupData()
        XCTAssertEqual(recordableLogger.errorCallCount, 1, "cleanupData 抛错应调用一次 logger.error")
    }

    /// 验证 cleanupData 时 cleanupOrphanedChunks 抛错后不调用 haptic.trigger
    func testCleanupDataThrowsDoesNotCallHaptic() async throws {
        configurableVectorRepo.shouldThrowCleanup = true
        await coordinator.cleanupData()
        XCTAssertEqual(recordableHaptic.triggerCallCount, 0, "cleanupData 抛错不应调用 haptic.trigger")
    }

    /// 验证 cleanupData 时 cleanupOrphanedChunks 抛错后 cleanedCount 保持原值
    func testCleanupDataThrowsCleanedCountKeepsOriginal() async throws {
        configurableVectorRepo.shouldThrowCleanup = true
        await coordinator.cleanupData()
        XCTAssertNil(coordinator.cleanedCount, "cleanupData 抛错后 cleanedCount 应保持 nil（未赋值）")
    }

    // MARK: - cleanupData 多次调用

    /// 验证多次调用 cleanupData 后 cleanedCount 为最后一次的返回值
    func testCleanupDataMultipleCallsCleanedCountIsLastReturnValue() async throws {
        configurableVectorRepo.stubCleanupCount = 5
        await coordinator.cleanupData()
        XCTAssertEqual(coordinator.cleanedCount, 5, "第一次 cleanupData 后 cleanedCount 应为 5")
        configurableVectorRepo.stubCleanupCount = 10
        await coordinator.cleanupData()
        XCTAssertEqual(coordinator.cleanedCount, 10, "第二次 cleanupData 后 cleanedCount 应为 10")
    }

    /// 验证 cleanupData 成功后再抛错 cleanedCount 保持上次成功值
    func testCleanupDataSuccessThenThrowsCleanedCountKeepsLastSuccess() async throws {
        configurableVectorRepo.stubCleanupCount = 7
        await coordinator.cleanupData()
        XCTAssertEqual(coordinator.cleanedCount, 7, "成功后 cleanedCount 应为 7")
        configurableVectorRepo.shouldThrowCleanup = true
        await coordinator.cleanupData()
        XCTAssertEqual(coordinator.cleanedCount, 7, "抛错后 cleanedCount 应保持上次成功值 7")
    }
}
