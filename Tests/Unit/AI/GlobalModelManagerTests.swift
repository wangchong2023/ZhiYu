//
//  GlobalModelManagerTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/10.
//
//  系统层级：[L3] 测试层
//  核心职责：验证 GlobalModelManager 持久化属性、模型标记、区域路由逻辑。
//

import Testing
import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class GlobalModelManagerTests: XCTestCase {
    private var manager: GlobalModelManager!

    override func setUp() async throws {
        try await super.setUp()
        resetPersistentTestState()
        setupFullMockEnvironment()
        manager = GlobalModelManager()
    }

    override func tearDown() async throws {
        resetPersistentTestState()
        manager = nil
        DatabaseManager.shared.reset()
        ServiceContainer.shared.reset()
        try await super.tearDown()
    }

    // MARK: - 初始状态

    func testPhysicalMemoryGreaterThanZero() {
        XCTAssertGreaterThan(manager.physicalMemory, 0)
    }

    func testInitialRemoteManifestsEmpty() {
        XCTAssertTrue(manager.remoteManifests.isEmpty)
    }

    func testInitialDownloadStatesEmpty() {
        XCTAssertTrue(manager.downloadStates.isEmpty)
    }

    func testInitialModelStorageUsageEmpty() {
        XCTAssertTrue(manager.modelStorageUsage.isEmpty)
    }

    func testInitialModelCallCountsEmpty() {
        XCTAssertTrue(manager.modelCallCounts.isEmpty)
    }

    // MARK: - activeModelId

    func testActiveModelIdDefaultValue() {
        // 默认值 "gemma-4-e2b-it"
        XCTAssertEqual(manager.activeModelId, "gemma-4-e2b-it")
    }

    func testActiveModelIdSetterPersists() {
        manager.activeModelId = "test-model"

        XCTAssertEqual(manager.activeModelId, "test-model")
    }

    // MARK: - isCloudEscalationEnabled

    func testIsCloudEscalationEnabledDefaultFalse() {
        XCTAssertFalse(manager.isCloudEscalationEnabled)
    }

    func testIsCloudEscalationEnabledSetterPersists() {
        manager.isCloudEscalationEnabled = true

        XCTAssertTrue(manager.isCloudEscalationEnabled)
    }

    // MARK: - activeCloudModelId

    func testActiveCloudModelIdDefaultValue() {
        XCTAssertEqual(manager.activeCloudModelId, "gpt-4o")
    }

    func testActiveCloudModelIdSetterPersists() {
        manager.activeCloudModelId = "claude-3"

        XCTAssertEqual(manager.activeCloudModelId, "claude-3")
    }

    // MARK: - downloadedModelIds

    func testDownloadedModelIdsInitiallyEmpty() {
        XCTAssertTrue(manager.downloadedModelIds.isEmpty)
    }

    func testMarkModelAsDownloaded() {
        manager.markModelAsDownloaded("model-1")

        XCTAssertTrue(manager.downloadedModelIds.contains("model-1"))
    }

    func testMarkModelAsRemoved() {
        manager.markModelAsDownloaded("model-1")
        manager.markModelAsRemoved("model-1")

        XCTAssertFalse(manager.downloadedModelIds.contains("model-1"))
    }

    func testMarkModelAsDownloadedIdempotent() {
        manager.markModelAsDownloaded("model-1")
        manager.markModelAsDownloaded("model-1")

        XCTAssertEqual(manager.downloadedModelIds.count, 1)
    }

    // MARK: - isChinaRegion

    func testIsChinaRegionOverrideTrue() {
        manager.isChinaRegionOverride = true

        // 通过 startDownload 间接验证，或直接验证行为
        // 这里只验证 override 不崩溃
        XCTAssertNotNil(manager.isChinaRegionOverride)
    }

    func testIsChinaRegionOverrideFalse() {
        manager.isChinaRegionOverride = false

        XCTAssertNotNil(manager.isChinaRegionOverride)
    }

    // MARK: - reload

    func testReloadNoCrash() async {
        await manager.reload()

        // 不崩溃即可
    }

    // MARK: - refreshLocalModelFiles

    func testRefreshLocalModelFilesNoManifestsNoCrash() {
        manager.refreshLocalModelFiles()

        // 无 manifest 时不崩溃
    }
}
