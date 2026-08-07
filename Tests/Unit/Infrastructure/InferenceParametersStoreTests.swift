//
//  InferenceParametersStoreTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施层测试
//  核心职责：验证 InferenceParametersStore 的保存/加载/删除/清空流程
//

import XCTest
@testable import ZhiYu

@MainActor
final class InferenceParametersStoreTests: XCTestCase {

    private var store: InferenceParametersStore!

    override func setUp() {
        super.setUp()
        store = InferenceParametersStore.shared
        store.clearAll()
    }

    override func tearDown() {
        store.clearAll()
        store = nil
        super.tearDown()
    }

    // MARK: - 保存与加载

    func testSaveAndLoadParameters() {
        let config = InferenceParametersConfig(
            modelId: "test-model-1",
            presetName: "creative",
            temperature: 0.8,
            topP: 0.9,
            topK: 40,
            maxTokens: 1024
        )
        store.saveParameters(config)

        let loaded = store.loadParameters(for: "test-model-1")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.modelId, "test-model-1")
        XCTAssertEqual(loaded?.presetName, "creative")
        XCTAssertEqual(loaded?.temperature, 0.8)
        XCTAssertEqual(loaded?.topP, 0.9)
        XCTAssertEqual(loaded?.topK, 40)
        XCTAssertEqual(loaded?.maxTokens, 1024)
    }

    func testLoadParametersReturnsNilForNonExistentModel() {
        let loaded = store.loadParameters(for: "non-existent-model")
        XCTAssertNil(loaded)
    }

    // MARK: - 删除

    func testDeleteParametersRemovesConfig() {
        let config = InferenceParametersConfig(
            modelId: "test-model-2",
            presetName: "balanced",
            temperature: 0.5,
            topP: 0.95,
            topK: 50,
            maxTokens: 2048
        )
        store.saveParameters(config)
        XCTAssertNotNil(store.loadParameters(for: "test-model-2"))

        store.deleteParameters(for: "test-model-2")
        XCTAssertNil(store.loadParameters(for: "test-model-2"))
    }

    // MARK: - 全量配置

    func testAllConfigurationsReturnsSortedByUpdatedAt() async {
        let config1 = InferenceParametersConfig(
            modelId: "model-old",
            presetName: "precise",
            temperature: 0.2,
            topP: 0.8,
            topK: 30,
            maxTokens: 512,
            updatedAt: Date(timeIntervalSince1970: 1000)
        )
        store.saveParameters(config1)

        // 等待确保时间戳不同
        try? await Task.sleep(nanoseconds: 10_000_000)

        let config2 = InferenceParametersConfig(
            modelId: "model-new",
            presetName: "custom",
            temperature: 1.0,
            topP: 0.7,
            topK: 60,
            maxTokens: 4096,
            updatedAt: Date(timeIntervalSince1970: 2000)
        )
        store.saveParameters(config2)

        let all = store.allConfigurations()
        XCTAssertEqual(all.count, 2)
        // 按 updatedAt 降序排列
        XCTAssertEqual(all.first?.modelId, "model-new")
        XCTAssertEqual(all.last?.modelId, "model-old")
    }

    // MARK: - 清空

    func testClearAllRemovesAllConfigurations() {
        let config = InferenceParametersConfig(
            modelId: "test-model-3",
            presetName: "creative",
            temperature: 0.7,
            topP: 0.9,
            topK: 40,
            maxTokens: 1024
        )
        store.saveParameters(config)
        XCTAssertEqual(store.allConfigurations().count, 1)

        store.clearAll()
        XCTAssertTrue(store.allConfigurations().isEmpty)
        XCTAssertNil(store.loadParameters(for: "test-model-3"))
    }

    // MARK: - 覆盖更新

    func testSaveParametersOverwritesExistingConfig() {
        let config1 = InferenceParametersConfig(
            modelId: "test-model-4",
            presetName: "creative",
            temperature: 0.8,
            topP: 0.9,
            topK: 40,
            maxTokens: 1024
        )
        store.saveParameters(config1)

        let config2 = InferenceParametersConfig(
            modelId: "test-model-4",
            presetName: "precise",
            temperature: 0.2,
            topP: 0.8,
            topK: 30,
            maxTokens: 512
        )
        store.saveParameters(config2)

        let loaded = store.loadParameters(for: "test-model-4")
        XCTAssertEqual(loaded?.presetName, "precise")
        XCTAssertEqual(loaded?.temperature, 0.2)
        XCTAssertEqual(store.allConfigurations().count, 1)
    }
}
