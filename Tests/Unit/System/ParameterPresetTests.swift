//
//  ParameterPresetTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证推理参数预设模板（创意/均衡/精准）的温度、Top-P、Top-K、MaxTokens 等配置语义。
//

import XCTest
@testable import ZhiYu

final class ParameterPresetTests: XCTestCase {

    // MARK: - CaseIterable

    func testParameterPreset_allCases_containsThreePresets() {
        XCTAssertEqual(ParameterPreset.allCases.count, 3)
        XCTAssertTrue(ParameterPreset.allCases.contains(.creative))
        XCTAssertTrue(ParameterPreset.allCases.contains(.balanced))
        XCTAssertTrue(ParameterPreset.allCases.contains(.precise))
    }

    // MARK: - displayName

    func testDisplayName_creative_nonEmpty() {
        XCTAssertFalse(ParameterPreset.creative.displayName.isEmpty)
    }

    func testDisplayName_balanced_nonEmpty() {
        XCTAssertFalse(ParameterPreset.balanced.displayName.isEmpty)
    }

    func testDisplayName_precise_nonEmpty() {
        XCTAssertFalse(ParameterPreset.precise.displayName.isEmpty)
    }

    func testDisplayName_allDistinct() {
        let names = ParameterPreset.allCases.map { $0.displayName }
        XCTAssertEqual(names.count, Set(names).count, "所有预设名称应唯一")
    }

    // MARK: - icon

    func testIcon_creative_isPaintbrush() {
        XCTAssertEqual(ParameterPreset.creative.icon, "paintbrush.fill")
    }

    func testIcon_balanced_isScale3d() {
        XCTAssertEqual(ParameterPreset.balanced.icon, "scale.3d")
    }

    func testIcon_precise_isTarget() {
        XCTAssertEqual(ParameterPreset.precise.icon, "target")
    }

    func testIcon_allNonEmpty() {
        for preset in ParameterPreset.allCases {
            XCTAssertFalse(preset.icon.isEmpty, "图标名不应为空")
        }
    }

    // MARK: - parameters 创意

    func testParameters_creative_highTemperature() {
        let params = ParameterPreset.creative.parameters
        XCTAssertEqual(params.temperature, 1.2, "创意模式温度应为 1.2")
    }

    func testParameters_creative_highTopP() {
        let params = ParameterPreset.creative.parameters
        XCTAssertEqual(params.topP, 0.95, "创意模式 Top-P 应为 0.95")
    }

    func testParameters_creative_highTopK() {
        let params = ParameterPreset.creative.parameters
        XCTAssertEqual(params.topK, 50, "创意模式 Top-K 应为 50")
    }

    func testParameters_creative_maxTokens2048() {
        let params = ParameterPreset.creative.parameters
        XCTAssertEqual(params.maxTokens, 2048)
    }

    // MARK: - parameters 均衡

    func testParameters_balanced_mediumTemperature() {
        let params = ParameterPreset.balanced.parameters
        XCTAssertEqual(params.temperature, 0.7, "均衡模式温度应为 0.7")
    }

    func testParameters_balanced_mediumTopP() {
        let params = ParameterPreset.balanced.parameters
        XCTAssertEqual(params.topP, 0.9)
    }

    func testParameters_balanced_mediumTopK() {
        let params = ParameterPreset.balanced.parameters
        XCTAssertEqual(params.topK, 40)
    }

    func testParameters_balanced_maxTokens2048() {
        let params = ParameterPreset.balanced.parameters
        XCTAssertEqual(params.maxTokens, 2048)
    }

    // MARK: - parameters 精准

    func testParameters_precise_lowTemperature() {
        let params = ParameterPreset.precise.parameters
        XCTAssertEqual(params.temperature, 0.3, "精准模式温度应为 0.3")
    }

    func testParameters_precise_lowTopP() {
        let params = ParameterPreset.precise.parameters
        XCTAssertEqual(params.topP, 0.85)
    }

    func testParameters_precise_lowTopK() {
        let params = ParameterPreset.precise.parameters
        XCTAssertEqual(params.topK, 20)
    }

    func testParameters_precise_maxTokens1024() {
        let params = ParameterPreset.precise.parameters
        XCTAssertEqual(params.maxTokens, 1024, "精准模式 maxTokens 应为 1024（比创意/均衡少）")
    }

    // MARK: - 温度排序

    func testTemperature_ordering_creativeHighestPreciseLowest() {
        let creativeTemp = ParameterPreset.creative.parameters.temperature
        let balancedTemp = ParameterPreset.balanced.parameters.temperature
        let preciseTemp = ParameterPreset.precise.parameters.temperature
        XCTAssertTrue(creativeTemp > balancedTemp, "创意温度应高于均衡")
        XCTAssertTrue(balancedTemp > preciseTemp, "均衡温度应高于精准")
    }
}
