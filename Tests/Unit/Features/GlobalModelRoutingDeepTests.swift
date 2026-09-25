//
//  GlobalModelRoutingDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：GlobalModelManager 端云路由决策深度测试 — 覆盖 shouldRouteToCloud 全分支
//            （Chunking / LinkDiscovery / Synthesis / 通用 Chat / 未知标签 / 空字符串 / 大小写敏感）、
//            evaluateEligibility 硬件护栏（supported / warning / restricted）、综合优先级场景。
//

import XCTest
import UFPCore
@testable import ZhiYu

// MARK: - GlobalModelManager 路由决策深度测试

@MainActor
final class GlobalModelRoutingDeepTests: XCTestCase {

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

    // MARK: - shouldRouteToCloud - Chunking

    /// 验证 Chunking 任务强锁定本地端侧，返回 false。
    func testShouldRouteToCloudChunkingReturnsFalse() {
        XCTAssertFalse(manager.shouldRouteToCloud(for: "Chunking"))
    }

    /// 验证 Chunking 任务即使开启云端提权仍返回 false。
    func testShouldRouteToCloudChunkingCloudEscalationOnStillReturnsFalse() {
        manager.isCloudEscalationEnabled = true
        XCTAssertFalse(manager.shouldRouteToCloud(for: "Chunking"))
    }

    // MARK: - shouldRouteToCloud - LinkDiscovery

    /// 验证 LinkDiscovery 任务强锁定本地端侧，返回 false。
    func testShouldRouteToCloudLinkDiscoveryReturnsFalse() {
        XCTAssertFalse(manager.shouldRouteToCloud(for: "LinkDiscovery"))
    }

    /// 验证 LinkDiscovery 任务即使开启云端提权仍返回 false。
    func testShouldRouteToCloudLinkDiscoveryCloudEscalationOnStillReturnsFalse() {
        manager.isCloudEscalationEnabled = true
        XCTAssertFalse(manager.shouldRouteToCloud(for: "LinkDiscovery"))
    }

    // MARK: - shouldRouteToCloud - Synthesis

    /// 验证 Synthesis 任务在未开启云端提权时返回 false。
    func testShouldRouteToCloudSynthesisEscalationOffReturnsFalse() {
        manager.isCloudEscalationEnabled = false
        XCTAssertFalse(manager.shouldRouteToCloud(for: "Synthesis"))
    }

    /// 验证 Synthesis 任务在开启云端提权时返回 true。
    func testShouldRouteToCloudSynthesisEscalationOnReturnsTrue() {
        manager.isCloudEscalationEnabled = true
        XCTAssertTrue(manager.shouldRouteToCloud(for: "Synthesis"))
    }

    // MARK: - shouldRouteToCloud - 通用 Chat

    /// 验证通用 Chat 任务在本地模型未就绪时返回 true。
    func testShouldRouteToCloudChatLocalNotReadyReturnsTrue() {
        // activeModelId 默认 "gemma-4-e2b-it"，downloadStates 无记录 → 未就绪
        XCTAssertFalse(manager.isModelLocalReady(for: manager.activeModelId))
        XCTAssertTrue(manager.shouldRouteToCloud(for: "Chat"))
    }

    /// 验证通用 Chat 任务在本地模型未就绪时即使关闭提权也返回 true。
    func testShouldRouteToCloudChatLocalNotReadyEscalationOffStillReturnsTrue() {
        manager.isCloudEscalationEnabled = false
        XCTAssertTrue(manager.shouldRouteToCloud(for: "Chat"))
    }

    /// 验证未知任务标签在本地模型未就绪时返回 true。
    func testShouldRouteToCloudUnknownTagLocalNotReadyReturnsTrue() {
        XCTAssertTrue(manager.shouldRouteToCloud(for: "UnknownTask"))
    }

    /// 验证空字符串任务标签在本地模型未就绪时返回 true。
    func testShouldRouteToCloudEmptyStringTagReturnsTrue() {
        XCTAssertTrue(manager.shouldRouteToCloud(for: ""))
    }

    // MARK: - shouldRouteToCloud - 大小写敏感

    /// 验证 "chunking"（小写）不匹配 "Chunking"，走通用分支。
    func testShouldRouteToCloudLowercaseChunkingFallsToGenericBranch() {
        // "chunking" != "Chunking"，走通用分支，本地未就绪 → true
        XCTAssertTrue(manager.shouldRouteToCloud(for: "chunking"))
    }

    /// 验证 "synthesis"（小写）不匹配 "Synthesis"，走通用分支。
    func testShouldRouteToCloudLowercaseSynthesisFallsToGenericBranch() {
        manager.isCloudEscalationEnabled = true
        // "synthesis" != "Synthesis"，走通用分支，本地未就绪 → true
        XCTAssertTrue(manager.shouldRouteToCloud(for: "synthesis"))
    }

    // MARK: - evaluateEligibility

    /// 验证 minDeviceMemoryInGb 远低于物理内存时返回 .supported。
    func testEvaluateEligibilityMemorySufficientReturnsSupported() {
        let manifest = makeManifest(minDeviceMemoryInGb: 0.5)
        let eligibility = manager.evaluateEligibility(for: manifest)
        XCTAssertEqual(eligibility, .supported)
    }

    /// 验证 minDeviceMemoryInGb 接近物理内存（差 < 1GB）时返回 .warning。
    func testEvaluateEligibilityMemoryCriticalReturnsWarning() {
        let physicalGb = Double(manager.physicalMemory) / 1_073_741_824.0
        let manifest = makeManifest(minDeviceMemoryInGb: physicalGb)
        let eligibility = manager.evaluateEligibility(for: manifest)
        XCTAssertEqual(eligibility, .warning)
    }

    /// 验证 minDeviceMemoryInGb 远超物理内存（差 > 1GB）时返回 .restricted。
    func testEvaluateEligibilityMemorySeverelyInsufficientReturnsRestricted() {
        let physicalGb = Double(manager.physicalMemory) / 1_073_741_824.0
        let manifest = makeManifest(minDeviceMemoryInGb: physicalGb + 10.0)
        let eligibility = manager.evaluateEligibility(for: manifest)
        XCTAssertEqual(eligibility, .restricted)
    }

    /// 验证 evaluateEligibility 委托给 hardwareGuard（结果一致性）。
    func testEvaluateEligibilityConsistentWithHardwareGuard() {
        let manifest = makeManifest(minDeviceMemoryInGb: 0.5)
        let guardEligibility = DeviceHardwareGuard(physicalMemory: manager.physicalMemory).evaluateEligibility(for: manifest)
        let managerEligibility = manager.evaluateEligibility(for: manifest)
        XCTAssertEqual(guardEligibility, managerEligibility)
    }

    // MARK: - shouldRouteToCloud 综合场景

    /// 验证 Chunking 优先级高于云端提权开关。
    func testShouldRouteToCloudChunkingPriorityHigherThanEscalationSwitch() {
        manager.isCloudEscalationEnabled = true
        XCTAssertFalse(manager.shouldRouteToCloud(for: "Chunking"))
    }

    /// 验证 LinkDiscovery 优先级高于云端提权开关。
    func testShouldRouteToCloudLinkDiscoveryPriorityHigherThanEscalationSwitch() {
        manager.isCloudEscalationEnabled = true
        XCTAssertFalse(manager.shouldRouteToCloud(for: "LinkDiscovery"))
    }

    /// 验证 Synthesis 不受本地模型就绪状态影响（仅看提权开关）。
    func testShouldRouteToCloudSynthesisNotAffectedByLocalReadiness() {
        manager.isCloudEscalationEnabled = false
        // 本地模型未就绪，但 Synthesis 仅看提权开关 → false
        XCTAssertFalse(manager.shouldRouteToCloud(for: "Synthesis"))
    }

    // MARK: - DeviceEligibility 枚举

    /// 验证 DeviceEligibility.supported 的 rawValue。
    func testDeviceEligibilitySupportedRawValue() {
        XCTAssertEqual(DeviceEligibility.supported.rawValue, "supported")
    }

    /// 验证 DeviceEligibility.warning 的 rawValue。
    func testDeviceEligibilityWarningRawValue() {
        XCTAssertEqual(DeviceEligibility.warning.rawValue, "warning")
    }

    /// 验证 DeviceEligibility.restricted 的 rawValue。
    func testDeviceEligibilityRestrictedRawValue() {
        XCTAssertEqual(DeviceEligibility.restricted.rawValue, "restricted")
    }

    /// 验证 DeviceEligibility 可相等比较。
    func testDeviceEligibility_Equatable() {
        XCTAssertEqual(DeviceEligibility.supported, DeviceEligibility.supported)
        XCTAssertNotEqual(DeviceEligibility.supported, DeviceEligibility.warning)
    }
}
