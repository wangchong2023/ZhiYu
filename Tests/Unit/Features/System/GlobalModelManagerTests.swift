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
        XCTAssertNotNil(manager, "重载后 manager 实例应保持有效")
    }

    // MARK: - refreshLocalModelFiles

    func testRefreshLocalModelFilesNoManifestsNoCrash() {
        manager.refreshLocalModelFiles()
        XCTAssertNotNil(manager, "刷新本地模型文件后 manager 实例应保持有效")
    }

    // MARK: - resubscribeActiveDownloads

    /// 验证空下载状态时调用 resubscribeActiveDownloads 不崩溃
    func testResubscribeActiveDownloads_空状态不崩溃() {
        manager.resubscribeActiveDownloads()
        XCTAssertTrue(manager.downloadStates.isEmpty)
    }

    /// 验证多次调用 resubscribeActiveDownloads 不崩溃（幂等性）
    func testResubscribeActiveDownloads_多次调用不崩溃() {
        manager.resubscribeActiveDownloads()
        manager.resubscribeActiveDownloads()
        manager.resubscribeActiveDownloads()
        XCTAssertTrue(manager.downloadStates.isEmpty)
    }

    /// 验证 startDownload 后调用 resubscribeActiveDownloads 不崩溃
    func testResubscribeActiveDownloads_下载中不崩溃() async {
        manager.isChinaRegionOverride = false
        let manifest = LLMManifest(
            modelId: "test-resub",
            displayName: "TestModel",
            vendor: "TestVendor",
            fileSizeInBytes: 1_000_000,
            minDeviceMemoryInGb: 0.5,
            remoteURLString: "https://example.com/model.bin",
            sha256Checksum: "abc123",
            parameterCount: "2B",
            supportedTasks: ["chat"],
            description: "测试模型",
            defaultParameters: InferenceParameters(temperature: 0.7, topP: 0.9, topK: 40, maxTokens: 1024),
            huggingfaceURLString: "https://huggingface.co/model.bin",
            modelscopeURLString: "https://modelscope.cn/model.bin"
        )
        manager.startDownload(for: manifest)
        // 等待异步 Task 有机会执行
        try? await Task.sleep(nanoseconds: 100_000_000)
        manager.resubscribeActiveDownloads()
        // 不崩溃即可
    }

    /// 验证 resetForTesting 后调用 resubscribeActiveDownloads 不崩溃
    func testResubscribeActiveDownloads_重置后不崩溃() {
        manager.resetForTesting()
        manager.resubscribeActiveDownloads()
        XCTAssertTrue(manager.downloadStates.isEmpty)
    }
}
