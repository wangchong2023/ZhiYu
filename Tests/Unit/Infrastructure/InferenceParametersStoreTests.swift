//
//  InferenceParametersStoreTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证推理参数持久化存储管理器的 CRUD、排序、解码容错与清空语义。
//

import XCTest
@testable import ZhiYu

@MainActor
final class InferenceParametersStoreTests: XCTestCase {

    // MARK: - 测试夹具

    private func makeConfig(
        modelId: String = "test-model",
        presetName: String = "balanced",
        temperature: Double = 0.7,
        topP: Double = 0.9,
        topK: Int = 40,
        maxTokens: Int = 2048,
        updatedAt: Date = Date()
    ) -> InferenceParametersConfig {
        InferenceParametersConfig(
            modelId: modelId,
            presetName: presetName,
            temperature: temperature,
            topP: topP,
            topK: topK,
            maxTokens: maxTokens,
            updatedAt: updatedAt
        )
    }

    override func setUp() {
        super.setUp()
        InferenceParametersStore.shared.clearAll()
    }

    override func tearDown() {
        InferenceParametersStore.shared.clearAll()
        super.tearDown()
    }

    // MARK: - 保存与加载

    func testSaveParameters_singleConfig_canBeLoaded() {
        let config = makeConfig(modelId: "model-A", temperature: 0.5)
        InferenceParametersStore.shared.saveParameters(config)

        let loaded = InferenceParametersStore.shared.loadParameters(for: "model-A")

        XCTAssertNotNil(loaded, "保存后应能加载到配置")
        XCTAssertEqual(loaded?.modelId, "model-A")
        XCTAssertEqual(loaded?.temperature, 0.5)
    }

    func testLoadParameters_nonExistentModel_returnsNil() {
        let result = InferenceParametersStore.shared.loadParameters(for: "non-existent")
        XCTAssertNil(result, "未保存的模型应返回 nil")
    }

    func testSaveParameters_overwriteExistingConfig() {
        let original = makeConfig(modelId: "model-B", temperature: 0.3)
        InferenceParametersStore.shared.saveParameters(original)

        let updated = makeConfig(modelId: "model-B", temperature: 0.9)
        InferenceParametersStore.shared.saveParameters(updated)

        let loaded = InferenceParametersStore.shared.loadParameters(for: "model-B")
        XCTAssertEqual(loaded?.temperature, 0.9, "同 modelId 保存应覆盖旧值")
    }

    func testSaveParameters_multipleModels_allPersisted() {
        InferenceParametersStore.shared.saveParameters(makeConfig(modelId: "m1"))
        InferenceParametersStore.shared.saveParameters(makeConfig(modelId: "m2"))
        InferenceParametersStore.shared.saveParameters(makeConfig(modelId: "m3"))

        XCTAssertNotNil(InferenceParametersStore.shared.loadParameters(for: "m1"))
        XCTAssertNotNil(InferenceParametersStore.shared.loadParameters(for: "m2"))
        XCTAssertNotNil(InferenceParametersStore.shared.loadParameters(for: "m3"))
    }

    // MARK: - 删除

    func testDeleteParameters_removesConfig() {
        InferenceParametersStore.shared.saveParameters(makeConfig(modelId: "to-delete"))
        XCTAssertNotNil(InferenceParametersStore.shared.loadParameters(for: "to-delete"))

        InferenceParametersStore.shared.deleteParameters(for: "to-delete")

        XCTAssertNil(InferenceParametersStore.shared.loadParameters(for: "to-delete"), "删除后应返回 nil")
    }

    func testDeleteParameters_nonExistentModel_noCrash() {
        InferenceParametersStore.shared.deleteParameters(for: "never-existed")
        XCTAssertTrue(true, "删除不存在的 modelId 不应崩溃")
    }

    // MARK: - 全量获取与排序

    func testAllConfigurations_emptyStore_returnsEmptyArray() {
        let all = InferenceParametersStore.shared.allConfigurations()
        XCTAssertTrue(all.isEmpty, "空存储应返回空数组")
    }

    func testAllConfigurations_sortedByUpdatedAtDescending() {
        let oldDate = Date(timeIntervalSince1970: 1000)
        let midDate = Date(timeIntervalSince1970: 2000)
        let newDate = Date(timeIntervalSince1970: 3000)

        InferenceParametersStore.shared.saveParameters(makeConfig(modelId: "old", updatedAt: oldDate))
        InferenceParametersStore.shared.saveParameters(makeConfig(modelId: "new", updatedAt: newDate))
        InferenceParametersStore.shared.saveParameters(makeConfig(modelId: "mid", updatedAt: midDate))

        let all = InferenceParametersStore.shared.allConfigurations()

        XCTAssertEqual(all.count, 3)
        XCTAssertEqual(all[0].modelId, "new", "最新更新的应排在第一位")
        XCTAssertEqual(all[1].modelId, "mid")
        XCTAssertEqual(all[2].modelId, "old", "最早更新的应排在最后")
    }

    // MARK: - 清空

    func testClearAll_removesAllConfigs() {
        InferenceParametersStore.shared.saveParameters(makeConfig(modelId: "m1"))
        InferenceParametersStore.shared.saveParameters(makeConfig(modelId: "m2"))

        InferenceParametersStore.shared.clearAll()

        XCTAssertTrue(InferenceParametersStore.shared.allConfigurations().isEmpty, "清空后应无配置")
        XCTAssertNil(InferenceParametersStore.shared.loadParameters(for: "m1"))
    }

    // MARK: - 持久化跨实例验证

    func testSaveParameters_persistsAcrossSharedInstanceAccess() {
        InferenceParametersStore.shared.saveParameters(makeConfig(modelId: "persist-test", temperature: 0.42))

        let loaded = InferenceParametersStore.shared.loadParameters(for: "persist-test")
        XCTAssertEqual(loaded?.temperature, 0.42, "shared 单例应持久化到 UserDefaults")
    }

    // MARK: - 配置结构体 Equatable

    func testInferenceParametersConfig_equality() {
        let date = Date(timeIntervalSince1970: 12345)
        let config1 = makeConfig(modelId: "eq", updatedAt: date)
        let config2 = makeConfig(modelId: "eq", updatedAt: date)

        XCTAssertEqual(config1, config2, "相同参数的配置应相等")
    }

    func testInferenceParametersConfig_inequalityOnDifferentTemperature() {
        let date = Date(timeIntervalSince1970: 12345)
        let config1 = makeConfig(modelId: "eq", temperature: 0.1, updatedAt: date)
        let config2 = makeConfig(modelId: "eq", temperature: 0.2, updatedAt: date)

        XCTAssertNotEqual(config1, config2, "不同 temperature 的配置不应相等")
    }
}
