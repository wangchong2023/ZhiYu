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

    // MARK: - isChinaRegion & 下载源路由测试

    func testIsChinaRegionOverrideTrue() {
        manager.isChinaRegionOverride = true
        XCTAssertTrue(manager.isChinaRegion, "当 override 为 true 时，isChinaRegion 必须返回 true")
    }

    func testIsChinaRegionOverrideFalse() {
        manager.isChinaRegionOverride = false
        XCTAssertFalse(manager.isChinaRegion, "当 override 为 false 时，isChinaRegion 必须返回 false")
    }

    func testIsChinaRegionMultiDimensionalConstantsCoverage() {
        // 验证多维判断所依赖的中国时区集合与语言代码常量完备性
        XCTAssertTrue(FeatureConstants.LocaleIdentifier.chinaTimeZones.contains("Asia/Shanghai"))
        XCTAssertTrue(FeatureConstants.LocaleIdentifier.chinaTimeZones.contains("Asia/Chongqing"))
        XCTAssertTrue(FeatureConstants.LocaleIdentifier.chinaTimeZones.contains("Asia/Urumqi"))
        XCTAssertEqual(FeatureConstants.LocaleIdentifier.zh, "zh")
        XCTAssertEqual(FeatureConstants.LocaleIdentifier.cn, "CN")
    }

    func testStartDownload_ChinaRegion_PrefersModelScope() async throws {
        let recordingMock = RecordingMockModelDownloadManager()
        ServiceContainer.shared.register(recordingMock as any ModelDownloadCapabilities, for: (any ModelDownloadCapabilities).self)
        let localManager = GlobalModelManager()
        localManager.isChinaRegionOverride = true

        let manifest = LLMManifest(
            modelId: "test-china-route",
            displayName: "TestModel",
            vendor: "Vendor",
            fileSizeInBytes: 1_000,
            minDeviceMemoryInGb: 0.1,
            remoteURLString: "https://fallback.com/model.bin",
            sha256Checksum: "abc",
            parameterCount: "1B",
            supportedTasks: ["chat"],
            description: "Desc",
            defaultParameters: InferenceParameters(temperature: 0.7, topP: 0.9, topK: 40, maxTokens: 1024),
            huggingfaceURLString: "https://huggingface.co/model.bin",
            modelscopeURLString: "https://modelscope.cn/model.bin"
        )

        localManager.startDownload(for: manifest)
        try await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(recordingMock.downloadedURLs.first?.absoluteString, "https://modelscope.cn/model.bin", "中国境内必须优先路由至 ModelScope")
    }

    func testStartDownload_NonChinaRegion_PrimaryHuggingFace_FailoverToModelScope() async throws {
        let failoverMock = FailoverMockModelDownloadManager()
        ServiceContainer.shared.register(failoverMock as any ModelDownloadCapabilities, for: (any ModelDownloadCapabilities).self)
        let localManager = GlobalModelManager()
        localManager.isChinaRegionOverride = false

        let manifest = LLMManifest(
            modelId: "test-failover-route",
            displayName: "TestModel",
            vendor: "Vendor",
            fileSizeInBytes: 1_000,
            minDeviceMemoryInGb: 0.1,
            remoteURLString: "https://default.com/model.bin",
            sha256Checksum: "abc",
            parameterCount: "1B",
            supportedTasks: ["chat"],
            description: "Desc",
            defaultParameters: InferenceParameters(temperature: 0.7, topP: 0.9, topK: 40, maxTokens: 1024),
            huggingfaceURLString: "https://huggingface.co/model.bin",
            modelscopeURLString: "https://modelscope.cn/model.bin"
        )

        localManager.startDownload(for: manifest)
        try await Task.sleep(nanoseconds: 120_000_000)

        // 验证首选为 HuggingFace，失败后自动 Failover 降级调用 ModelScope
        XCTAssertEqual(failoverMock.recordedURLs.first?.absoluteString, "https://huggingface.co/model.bin", "海外优先路由至 HuggingFace")
        XCTAssertTrue(failoverMock.recordedURLs.contains(where: { $0.absoluteString == "https://modelscope.cn/model.bin" }), "首选源失败后必须自动无缝 Failover 重试 ModelScope")
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
    func testResubscribeActiveDownloadsEmptyStateNoCrash() {
        manager.resubscribeActiveDownloads()
        XCTAssertTrue(manager.downloadStates.isEmpty)
    }

    /// 验证多次调用 resubscribeActiveDownloads 不崩溃（幂等性）
    func testResubscribeActiveDownloadsMultipleCallsNoCrash() {
        manager.resubscribeActiveDownloads()
        manager.resubscribeActiveDownloads()
        manager.resubscribeActiveDownloads()
        XCTAssertTrue(manager.downloadStates.isEmpty)
    }

    /// 验证 startDownload 后调用 resubscribeActiveDownloads 不崩溃
    func testResubscribeActiveDownloadsDuringDownloadNoCrash() async {
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
    func testResubscribeActiveDownloadsAfterResetNoCrash() {
        manager.resetForTesting()
        manager.resubscribeActiveDownloads()
        XCTAssertTrue(manager.downloadStates.isEmpty)
    }
}

// MARK: - 测试辅助 Mock 类

private final class RecordingMockModelDownloadManager: ModelDownloadCapabilities, @unchecked Sendable {
    var downloadedURLs: [URL] = []

    func startDownload(modelId: String, remoteURL: URL) async throws {
        downloadedURLs.append(remoteURL)
    }
    func pauseDownload(modelId: String) async throws {}
    func resumeDownload(modelId: String) async throws {}
    func cancelDownload(modelId: String) async throws {}
    func observeDownloadState(for modelId: String) async -> AsyncStream<DownloadState> {
        AsyncStream { $0.finish() }
    }
}

private final class FailoverMockModelDownloadManager: ModelDownloadCapabilities, @unchecked Sendable {
    var recordedURLs: [URL] = []

    func startDownload(modelId: String, remoteURL: URL) async throws {
        recordedURLs.append(remoteURL)
        if remoteURL.host?.contains("huggingface") == true {
            throw NSError(domain: "NetworkError", code: -1001, userInfo: [NSLocalizedDescriptionKey: "HuggingFace connection timeout"])
        }
    }
    func pauseDownload(modelId: String) async throws {}
    func resumeDownload(modelId: String) async throws {}
    func cancelDownload(modelId: String) async throws {}
    func observeDownloadState(for modelId: String) async -> AsyncStream<DownloadState> {
        AsyncStream { $0.finish() }
    }
}
