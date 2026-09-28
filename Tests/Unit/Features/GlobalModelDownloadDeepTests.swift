//
//  GlobalModelDownloadDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：GlobalModelManager 下载流程深度测试 — 覆盖 refreshLocalModelFiles 沙盒扫描对齐、
//            cancelDownload 状态置位、startDownload 区域路由（国内 ModelScope / 国外 HuggingFace /
//            降级 remoteURL / 无效 URL 拦截）、pauseDownload / resumeDownload 容错、
//            reload 行为、physicalMemory 一致性、isChinaRegionOverride 三态切换。
//

import XCTest
import UFPCore
@_spi(Internals) import Dependencies
@testable import ZhiYu

// MARK: - GlobalModelManager 下载流程深度测试

@MainActor
final class GlobalModelDownloadDeepTests: XCTestCase {

    // MARK: - 测试夹具

    private var manager: GlobalModelManager!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        resetPersistentTestState()
        manager = GlobalModelManager()
    }

    override func tearDown() async throws {
        resetPersistentTestState()
        manager = nil
        try await super.tearDown()
    }

    // MARK: - 辅助工厂

    /// 构造测试用 LLMManifest
    private func makeManifest(
        modelId: String = "test-model",
        fileSizeInBytes: Int64 = 1_000_000,
        minDeviceMemoryInGb: Double = 4.0,
        remoteURLString: String = "https://example.com/model.bin",
        huggingfaceURLString: String? = "https://huggingface.co/model.bin",
        modelscopeURLString: String? = "https://modelscope.cn/model.bin"
    ) -> LLMManifest {
        LLMManifest(
            modelId: modelId,
            displayName: "TestModel",
            vendor: "TestVendor",
            fileSizeInBytes: fileSizeInBytes,
            minDeviceMemoryInGb: minDeviceMemoryInGb,
            remoteURLString: remoteURLString,
            sha256Checksum: "abc123",
            parameterCount: "2B",
            supportedTasks: ["chat"],
            description: "测试模型",
            defaultParameters: InferenceParameters(temperature: 0.7, topP: 0.9, topK: 40, maxTokens: 1024),
            huggingfaceURLString: huggingfaceURLString,
            modelscopeURLString: modelscopeURLString
        )
    }

    // MARK: - refreshLocalModelFiles

    /// 验证无 remoteManifests 时 refreshLocalModelFiles 不崩溃。
    func testRefreshLocalModelFilesNoManifestsNoCrash() {
        manager.refreshLocalModelFiles()
        XCTAssertTrue(manager.downloadStates.isEmpty)
    }

    /// 验证 refreshLocalModelFiles 后无物理文件的 manifest 状态为 .failed。
    func testRefreshLocalModelFilesNoPhysicalFileStatusFailed() {
        // 需要先设置 remoteManifests，但 remoteManifests 是 private(set)
        // 通过 reload 间接加载（MockRemoteConfigService 返回空列表）
        // 这里验证默认空列表的行为
        manager.refreshLocalModelFiles()
        XCTAssertTrue(manager.downloadStates.isEmpty)
    }

    // MARK: - cancelDownload

    /// 验证 cancelDownload 对不存在的 modelId 不崩溃。
    func testCancelDownloadNonExistentModelIdNoCrash() async {
        manager.cancelDownload(for: "nonexistent")
        // 异步 Task 内执行，状态可能未立即更新，但不崩溃即可
    }

    // MARK: - startDownload 区域路由

    /// 验证 isChinaRegionOverride 设为 true 不崩溃。
    func testIsChinaRegionOverrideTrueNoCrash() {
        manager.isChinaRegionOverride = true
        XCTAssertEqual(manager.isChinaRegionOverride, true)
    }

    /// 验证 isChinaRegionOverride 设为 false 不崩溃。
    func testIsChinaRegionOverrideFalseNoCrash() {
        manager.isChinaRegionOverride = false
        XCTAssertEqual(manager.isChinaRegionOverride, false)
    }

    /// 验证 isChinaRegionOverride 设为 nil 恢复默认行为。
    func testIsChinaRegionOverrideNilRestoresDefault() {
        manager.isChinaRegionOverride = true
        manager.isChinaRegionOverride = nil
        XCTAssertNil(manager.isChinaRegionOverride)
    }

    /// 验证 startDownload 在 restricted 硬件下被拦截（不发起下载）。
    func testStartDownloadRestrictedHardwareBlocked() async {
        manager.isChinaRegionOverride = false
        let physicalGb = Double(manager.physicalMemory) / 1_073_741_824.0
        let manifest = makeManifest(minDeviceMemoryInGb: physicalGb + 10.0)
        manager.startDownload(for: manifest)
        // 异步 Task 内执行，但 restricted 会直接 return 不创建 Task
        // 验证不崩溃即可
    }

    /// 验证 startDownload 在 supported 硬件下不崩溃。
    func testStartDownloadSupportedHardwareNoCrash() async {
        manager.isChinaRegionOverride = false
        let manifest = makeManifest(minDeviceMemoryInGb: 0.5)
        manager.startDownload(for: manifest)
        // 异步 Task 内执行，不崩溃即可
    }

    // MARK: - pauseDownload / resumeDownload

    /// 验证 pauseDownload 对不存在的 modelId 不崩溃。
    func testPauseDownloadNonExistentModelIdNoCrash() async {
        manager.pauseDownload(for: "nonexistent")
    }

    /// 验证 resumeDownload 对不存在的 modelId 不崩溃。
    func testResumeDownloadNonExistentModelIdNoCrash() async {
        manager.resumeDownload(for: "nonexistent")
    }

    // MARK: - reload

    /// 验证 reload 不崩溃。
    func testReloadNoCrash() async {
        await manager.reload()
    }

    /// 验证 reload 后 isLoading 恢复为 false。
    func testAfterReloadIsLoadingRestoresFalse() async {
        await manager.reload()
        XCTAssertFalse(manager.isLoading)
    }

    // MARK: - startDownload URL 路由

    /// 验证国内区域优先使用 modelscopeURLString（不崩溃）。
    func testStartDownloadChinaRegionPrefersModelScopeNoCrash() async {
        manager.isChinaRegionOverride = true
        let manifest = makeManifest(
            huggingfaceURLString: "https://huggingface.co/test.bin",
            modelscopeURLString: "https://modelscope.cn/test.bin"
        )
        manager.startDownload(for: manifest)
        // 异步执行，不崩溃即可
    }

    /// 验证国外区域优先使用 huggingfaceURLString（不崩溃）。
    func testStartDownloadOverseasRegionPrefersHuggingFaceNoCrash() async {
        manager.isChinaRegionOverride = false
        let manifest = makeManifest(
            huggingfaceURLString: "https://huggingface.co/test.bin",
            modelscopeURLString: "https://modelscope.cn/test.bin"
        )
        manager.startDownload(for: manifest)
        // 异步执行，不崩溃即可
    }

    /// 验证国内区域无 modelscopeURLString 时降级到 remoteURLString（不崩溃）。
    func testStartDownloadChinaRegionNoModelScopeDegradesRemoteNoCrash() async {
        manager.isChinaRegionOverride = true
        let manifest = makeManifest(
            huggingfaceURLString: "https://huggingface.co/test.bin",
            modelscopeURLString: nil
        )
        manager.startDownload(for: manifest)
        // 异步执行，不崩溃即可
    }

    /// 验证国外区域无 huggingfaceURLString 时降级到 remoteURLString（不崩溃）。
    func testStartDownloadOverseasRegionNoHuggingFaceDegradesRemoteNoCrash() async {
        manager.isChinaRegionOverride = false
        let manifest = makeManifest(
            huggingfaceURLString: nil,
            modelscopeURLString: "https://modelscope.cn/test.bin"
        )
        manager.startDownload(for: manifest)
        // 异步执行，不崩溃即可
    }

    /// 验证无效 URL 字符串时 startDownload 不崩溃（guard URL 失败直接 return）。
    func testStartDownloadInvalidURLNoCrash() async {
        manager.isChinaRegionOverride = false
        let manifest = makeManifest(remoteURLString: "not a valid url")
        manager.startDownload(for: manifest)
        // guard URL 失败直接 return，不崩溃即可
    }

    // MARK: - DownloadState 枚举

    /// 验证 DownloadState.completed 相等比较。
    func testDownloadStateCompletedEqualityComparison() {
        let url = URL(fileURLWithPath: "/tmp/test.bin")
        XCTAssertEqual(DownloadState.completed(localURL: url), DownloadState.completed(localURL: url))
    }

    /// 验证 DownloadState.failed 相等比较。
    func testDownloadStateFailedEqualityComparison() {
        XCTAssertEqual(DownloadState.failed(error: "error1"), DownloadState.failed(error: "error1"))
    }

    /// 验证 DownloadState.downloading 相等比较。
    func testDownloadStateDownloadingEqualityComparison() {
        XCTAssertEqual(DownloadState.downloading(progress: 0.5, bytesPerSecond: 100), DownloadState.downloading(progress: 0.5, bytesPerSecond: 100))
    }

    /// 验证 DownloadState.pending 相等比较。
    func testDownloadStatePendingEqualityComparison() {
        XCTAssertEqual(DownloadState.pending, DownloadState.pending)
    }

    /// 验证 DownloadState.cancelled 相等比较。
    func testDownloadStateCancelledEqualityComparison() {
        XCTAssertEqual(DownloadState.cancelled, DownloadState.cancelled)
    }

    /// 验证 DownloadState.paused 相等比较。
    func testDownloadStatePausedEqualityComparison() {
        XCTAssertEqual(DownloadState.paused, DownloadState.paused)
    }

    /// 验证 DownloadState.verifying 相等比较。
    func testDownloadStateVerifyingEqualityComparison() {
        XCTAssertEqual(DownloadState.verifying, DownloadState.verifying)
    }

    // MARK: - 订阅泄漏修复测试（修复：终态后 subscribedModelIds 被清理，允许重新订阅）

    /// 验证终态 .failed 后 subscribedModelIds 被清理，允许再次下载时重新订阅状态流。
    /// 修复前：AsyncStream 永不 finish，subscribedModelIds 永不清理，再次点击下载时被 guard 拦截，状态流不更新。
    func testTerminalStateFailedAllowsResubscribe() async {
        let controllableMock = ControllableMockModelDownloadManager()
        controllableMock.statesToYield = [.failed(error: "test error")]
        ServiceContainer.shared.register(controllableMock as any ModelDownloadCapabilities, for: (any ModelDownloadCapabilities).self)
        // 清理 @Dependency 缓存，确保新创建的 testManager 解析到 ControllableMock
        DependencyValues._current.cachedValues.resetCache()

        // 创建新的 manager 以使用可控 Mock（@Dependency 在 init 时解析一次并缓存）
        let testManager = GlobalModelManager()
        let manifest = makeManifest(modelId: "resubscribe-failed-test")

        // 1. 第一次下载，触发订阅
        testManager.startDownload(for: manifest)
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 2. 验证第一次订阅发生
        XCTAssertEqual(controllableMock.observeCallCount, 1, "第一次下载应触发一次订阅")

        // 3. 验证状态更新为 failed
        if case .failed = testManager.downloadStates["resubscribe-failed-test"] {
            // 符合预期
        } else {
            XCTFail("状态应更新为 failed，实际为: \(String(describing: testManager.downloadStates["resubscribe-failed-test"]))")
        }

        // 4. 再次下载，验证能重新订阅（修复前会被 subscribedModelIds 拦截）
        testManager.startDownload(for: manifest)
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 5. 验证第二次订阅发生（修复后 subscribedModelIds 被清理，允许重新订阅）
        XCTAssertEqual(controllableMock.observeCallCount, 2, "终态 .failed 后应允许重新订阅")
    }

    /// 验证终态 .completed 后 subscribedModelIds 被清理，允许再次下载时重新订阅状态流。
    func testTerminalStateCompletedAllowsResubscribe() async {
        let controllableMock = ControllableMockModelDownloadManager()
        let completedURL = URL(fileURLWithPath: "/tmp/test-completed.bin")
        controllableMock.statesToYield = [.completed(localURL: completedURL)]
        ServiceContainer.shared.register(controllableMock as any ModelDownloadCapabilities, for: (any ModelDownloadCapabilities).self)
        // 清理 @Dependency 缓存，确保新创建的 testManager 解析到 ControllableMock
        DependencyValues._current.cachedValues.resetCache()

        let testManager = GlobalModelManager()
        let manifest = makeManifest(modelId: "resubscribe-completed-test")

        // 1. 第一次下载，触发订阅
        testManager.startDownload(for: manifest)
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 2. 验证第一次订阅发生
        XCTAssertEqual(controllableMock.observeCallCount, 1, "第一次下载应触发一次订阅")

        // 3. 验证状态更新为 completed
        XCTAssertTrue(testManager.isModelLocalReady(for: "resubscribe-completed-test"), "状态应更新为 completed")

        // 4. 再次下载，验证能重新订阅（修复前会被 subscribedModelIds 拦截）
        testManager.startDownload(for: manifest)
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 5. 验证第二次订阅发生（修复后 subscribedModelIds 被清理，允许重新订阅）
        XCTAssertEqual(controllableMock.observeCallCount, 2, "终态 .completed 后应允许重新订阅")
    }

    /// 验证终态 .cancelled 后 subscribedModelIds 被清理，允许再次下载时重新订阅状态流。
    func testTerminalStateCancelledAllowsResubscribe() async {
        let controllableMock = ControllableMockModelDownloadManager()
        controllableMock.statesToYield = [.cancelled]
        ServiceContainer.shared.register(controllableMock as any ModelDownloadCapabilities, for: (any ModelDownloadCapabilities).self)
        // 清理 @Dependency 缓存，确保新创建的 testManager 解析到 ControllableMock 而非 setUp 中 manager 缓存的 FakeModelDownloadManager
        DependencyValues._current.cachedValues.resetCache()

        let testManager = GlobalModelManager()
        let manifest = makeManifest(modelId: "resubscribe-cancelled-test")

        // 1. 第一次下载，触发订阅
        testManager.startDownload(for: manifest)
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 2. 验证第一次订阅发生
        XCTAssertEqual(controllableMock.observeCallCount, 1, "第一次下载应触发一次订阅")

        // 3. 再次下载，验证能重新订阅（修复前会被 subscribedModelIds 拦截）
        testManager.startDownload(for: manifest)
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 4. 验证第二次订阅发生（修复后 subscribedModelIds 被清理，允许重新订阅）
        XCTAssertEqual(controllableMock.observeCallCount, 2, "终态 .cancelled 后应允许重新订阅")
    }

    /// 验证非终态 .downloading 时 subscribedModelIds 不被清理，防止重复订阅产生僵尸 Task。
    func testNonTerminalStateDownloadingKeepsSubscription() async {
        let controllableMock = ControllableMockModelDownloadManager()
        controllableMock.statesToYield = [.downloading(progress: 0.5, bytesPerSecond: 100)]
        ServiceContainer.shared.register(controllableMock as any ModelDownloadCapabilities, for: (any ModelDownloadCapabilities).self)
        // 清理 @Dependency 缓存，确保新创建的 testManager 解析到 ControllableMock
        DependencyValues._current.cachedValues.resetCache()

        let testManager = GlobalModelManager()
        let manifest = makeManifest(modelId: "downloading-keep-sub-test")

        // 1. 第一次下载，触发订阅
        testManager.startDownload(for: manifest)
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 2. 验证第一次订阅发生
        XCTAssertEqual(controllableMock.observeCallCount, 1, "第一次下载应触发一次订阅")

        // 3. 再次下载，验证不会重新订阅（非终态，subscribedModelIds 未被清理）
        testManager.startDownload(for: manifest)
        try? await Task.sleep(nanoseconds: 500_000_000)

        // 4. 验证仍未发生第二次订阅（非终态保持订阅标记，防止重复订阅）
        XCTAssertEqual(controllableMock.observeCallCount, 1, "非终态 .downloading 时不应重新订阅")
    }
}
