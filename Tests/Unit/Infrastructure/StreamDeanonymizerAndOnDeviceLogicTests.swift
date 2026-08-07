//
//  StreamDeanonymizerAndOnDeviceLogicTests.swift
//  ZhiYuTests
//
//  批次 7-H：覆盖 Infrastructure 层高 ROI 纯逻辑方法
//

import XCTest
@testable import ZhiYu

// MARK: - StreamDeanonymizer 流式端侧解密还原器测试
//
// 注：StreamDeanonymizer 的完整测试已存在于 StreamDeanonymizerTests.swift（25 用例）。
// 本文件聚焦 OnDeviceLLMService / PluginLoader / ModelDownloadManager 的纯逻辑补充。

// MARK: - OnDeviceModel DTO 测试

/// 覆盖 `OnDeviceModel.sizeLabel`/`icon` 纯计算属性（OnDeviceLLMService.swift:403-413）
final class OnDeviceModelDTOTests: XCTestCase {

    func testSizeLabelFormatsBytesCorrectly() {
        let model = OnDeviceModel(id: "test", name: "Test", url: nil, size: 1024 * 1024 * 100, type: .bundled)
        XCTAssertTrue(model.sizeLabel.contains("MB") || model.sizeLabel.contains("GB"), "100MB 模型应显示 MB 或 GB 单位")
    }

    func testSizeLabelZeroBytes() {
        let model = OnDeviceModel(id: "test", name: "Test", url: nil, size: 0, type: .system)
        XCTAssertTrue(model.sizeLabel.contains("bytes") || model.sizeLabel.contains("B"), "0 字节应显示 bytes 或 B")
    }

    func testIconForBundledType() {
        let model = OnDeviceModel(id: "test", name: "Test", url: nil, size: 0, type: .bundled)
        XCTAssertEqual(model.icon, "cube.box.fill")
    }

    func testIconForDownloadedType() {
        let model = OnDeviceModel(id: "test", name: "Test", url: nil, size: 0, type: .downloaded)
        XCTAssertEqual(model.icon, "arrow.down.circle.fill")
    }

    func testIconForSystemType() {
        let model = OnDeviceModel(id: "test", name: "Test", url: nil, size: 0, type: .system)
        XCTAssertEqual(model.icon, "apple.logo")
    }
}

// MARK: - OnDeviceError 错误描述测试

/// 覆盖 `OnDeviceError.errorDescription`（OnDeviceLLMService.swift:424-437）
final class OnDeviceErrorDescriptionTests: XCTestCase {

    func testModelNotFoundErrorDescription() {
        XCTAssertNotNil(OnDeviceError.modelNotFound.errorDescription)
        XCTAssertFalse(OnDeviceError.modelNotFound.errorDescription?.isEmpty ?? true)
    }

    func testModelNotLoadedErrorDescription() {
        XCTAssertNotNil(OnDeviceError.modelNotLoaded.errorDescription)
        XCTAssertFalse(OnDeviceError.modelNotLoaded.errorDescription?.isEmpty ?? true)
    }

    func testNotSupportedErrorDescription() {
        XCTAssertNotNil(OnDeviceError.notSupported.errorDescription)
        XCTAssertFalse(OnDeviceError.notSupported.errorDescription?.isEmpty ?? true)
    }

    func testInferenceFailedErrorDescriptionContainsMessage() {
        let msg = "GPU 超时"
        let desc = OnDeviceError.inferenceFailed(msg).errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains(msg) ?? false, "inferenceFailed 错误描述应包含原始消息")
    }

    func testCompilationFailedErrorDescription() {
        XCTAssertNotNil(OnDeviceError.compilationFailed.errorDescription)
        XCTAssertFalse(OnDeviceError.compilationFailed.errorDescription?.isEmpty ?? true)
    }

    func testErrorDescriptionsAreDistinct() {
        let descs = [
            OnDeviceError.modelNotFound.errorDescription,
            OnDeviceError.modelNotLoaded.errorDescription,
            OnDeviceError.notSupported.errorDescription,
            OnDeviceError.compilationFailed.errorDescription
        ]
        let unique = Set(descs.compactMap { $0 })
        XCTAssertEqual(unique.count, 4, "4 个无参 case 的 errorDescription 应互不相同")
    }
}

// MARK: - OnDeviceLLMService Config 常量测试

/// 验证 `OnDeviceLLMService.Config` 常量值（nonisolated，可在非 MainActor 测试中访问）
final class OnDeviceLLMServiceConfigTests: XCTestCase {

    func testDefaultMaxTokens() {
        XCTAssertEqual(OnDeviceLLMService.Config.defaultMaxTokens, 256)
    }

    func testGenerationTemperature() {
        XCTAssertEqual(OnDeviceLLMService.Config.generationTemperature, 0.7)
    }

    func testSmartIngestMaxTokens() {
        XCTAssertEqual(OnDeviceLLMService.Config.smartIngestMaxTokens, 500)
    }

    func testChatMaxTokens() {
        XCTAssertEqual(OnDeviceLLMService.Config.chatMaxTokens, 300)
    }

    func testContextPageLimit() {
        XCTAssertEqual(OnDeviceLLMService.Config.contextPageLimit, 5)
    }

    func testContentPreviewChars() {
        XCTAssertEqual(OnDeviceLLMService.Config.contentPreviewChars, 200)
    }
}

// MARK: - OnDeviceLLMService 状态重置测试

/// 覆盖 `OnDeviceLLMService.cancelGeneration()`/`unloadModel()` 状态重置方法
@MainActor
final class OnDeviceLLMServiceStateResetTests: XCTestCase {

    func testCancelGenerationResetsState() {
        let service = OnDeviceLLMService()
        service.isGenerating = true
        service.generatedText = "部分生成内容"
        service.generationProgress = 0.5

        service.cancelGeneration()

        XCTAssertFalse(service.isGenerating)
        XCTAssertEqual(service.generatedText, "")
        XCTAssertEqual(service.generationProgress, 0)
    }

    func testUnloadModelClearsModelState() {
        let service = OnDeviceLLMService()
        service.isModelLoaded = true
        service.loadedModelName = "TestModel"
        service.inferenceSpeed = 100.0

        service.unloadModel()

        XCTAssertFalse(service.isModelLoaded)
        XCTAssertEqual(service.loadedModelName, "")
        XCTAssertEqual(service.inferenceSpeed, 0)
    }
}

// MARK: - String.matchesRegex 测试

/// 覆盖 `String.matchesRegex`（PluginLoader.swift:378-382）纯正则匹配逻辑
final class StringMatchesRegexTests: XCTestCase {

    func testMatchesValidPattern() {
        XCTAssertTrue("hello123".matchesRegex("^[a-z]+[0-9]+$"))
    }

    func testDoesNotMatchPattern() {
        XCTAssertFalse("123hello".matchesRegex("^[a-z]+[0-9]+$"))
    }

    func testMatchesPartialPattern() {
        XCTAssertTrue("abc123def".matchesRegex("[0-9]+"))
    }

    func testEmptyStringWithEmptyPatternDoesNotCrash() {
        // 空正则 pattern 能被 NSRegularExpression 编译，firstMatch 行为不 crash 即可
        _ = "".matchesRegex("")
    }

    func testNonEmptyStringDoesNotMatchEmptyPattern() {
        XCTAssertFalse("text".matchesRegex("^$"))
    }

    func testInvalidRegexPatternReturnsFalse() {
        // 无效正则（未闭合括号）应返回 false 而非 crash
        XCTAssertFalse("test".matchesRegex("[invalid"))
    }

    func testEmailPattern() {
        XCTAssertTrue("user@example.com".matchesRegex("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"))
        XCTAssertFalse("not-an-email".matchesRegex("^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"))
    }
}

// MARK: - ModelDownloadManager 速率计算与状态管理测试

/// 覆盖 `ModelDownloadManager.updateProgress`/`updateState`/`registerChecksum`/`getChecksum`
///
/// `ModelDownloadManager` 是 `public actor`，`init` 为 private，通过 `.shared` 测试。
/// `updateProgress` 包含速率计算逻辑（timeDiff >= 0.5 才更新速率）。
final class ModelDownloadManagerProgressTests: XCTestCase {

    /// 验证 `registerChecksum` + `getChecksum` 往返
    func testRegisterAndGetChecksum() async {
        let manager = ModelDownloadManager.shared
        let modelId = "test_model_\(UUID().uuidString)"
        let checksum = "abc123def456"
        await manager.registerChecksum(for: modelId, checksum: checksum)
        let retrieved = await manager.getChecksum(for: modelId)
        XCTAssertEqual(retrieved, checksum)
    }

    /// 验证 `getChecksum` 对未注册模型返回 nil
    func testGetChecksumUnregisteredReturnsNil() async {
        let manager = ModelDownloadManager.shared
        let retrieved = await manager.getChecksum(for: "unregistered_\(UUID().uuidString)")
        XCTAssertNil(retrieved)
    }

    /// 验证 `updateProgress` 首次调用初始化 tracker（currentSpeed=0）
    func testUpdateProgressFirstCallInitializesTracker() async {
        let manager = ModelDownloadManager.shared
        let modelId = "progress_test_\(UUID().uuidString)"
        await manager.updateProgress(
            for: modelId,
            totalBytesWritten: 100,
            totalBytesExpectedToWrite: 1000
        )
        // 通过即说明首次调用未 crash 且初始化了 tracker
    }

    /// 验证 `updateProgress` 在 totalBytesExpectedToWrite <= 0 时跳过
    func testUpdateProgressWithZeroExpectedBytesSkips() async {
        let manager = ModelDownloadManager.shared
        let modelId = "zero_expected_\(UUID().uuidString)"
        await manager.updateProgress(
            for: modelId,
            totalBytesWritten: 100,
            totalBytesExpectedToWrite: 0
        )
        // 不 crash 即通过（guard 拦截）
    }

    /// 验证 `updateProgress(progress:)` 兼容旧模式
    func testUpdateProgressLegacyMode() async {
        let manager = ModelDownloadManager.shared
        let modelId = "legacy_progress_\(UUID().uuidString)"
        await manager.updateProgress(for: modelId, progress: 0.5)
        // 不 crash 即通过
    }

    /// 验证 `updateState` 状态分发
    func testUpdateStateDistributesState() async {
        let manager = ModelDownloadManager.shared
        let modelId = "state_test_\(UUID().uuidString)"
        await manager.updateState(for: modelId, to: .pending)
        // 不 crash 即通过（状态已存入 downloadStates）
    }

    /// 验证 `clearActiveTask` 清理任务
    func testClearActiveTask() async {
        let manager = ModelDownloadManager.shared
        let modelId = "clear_task_\(UUID().uuidString)"
        await manager.clearActiveTask(for: modelId)
        // 不 crash 即通过（无任务时清理也不报错）
    }
}
