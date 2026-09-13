//
//  InferenceParameterConfigurationTests.swift
//  ZhiYuTests
//
//  系统层级：[L2] 业务功能测试 - System
//  核心职责：验证推理参数微调公差与 ModelLabView 模拟任务状态定义。
//

import XCTest
import SwiftUI
import UFPCore
@testable import ZhiYu

@MainActor
final class InferenceParameterConfigurationTests: XCTestCase {

    /// 验证 customNudgeDelta 大于 presetMatchTolerance，确保预设匹配能正确识别自定义微调
    func testInferenceParam_customNudgeDelta_exceedsTolerance() {
        let delta = FeatureConstants.InferenceParam.customNudgeDelta
        let tolerance = FeatureConstants.InferenceParam.presetMatchTolerance
        XCTAssertGreaterThan(
            delta, tolerance,
            "customNudgeDelta (\(delta)) 必须大于 presetMatchTolerance (\(tolerance))"
        )
    }

    /// 验证 customNudgeDelta 是正值
    func testInferenceParam_customNudgeDelta_isPositive() {
        XCTAssertGreaterThan(
            FeatureConstants.InferenceParam.customNudgeDelta, 0,
            "customNudgeDelta 应为正值"
        )
    }

    /// 验证 ModelLabView 具有 simulationTask 状态属性以支持任务取消
    func testModelLabView_simulationTaskState_exists() {
        let view = ModelLabView(embedInScrollView: false, onGoToStore: {})
        let mirror = Mirror(reflecting: view)
        let hasSimulationTask = mirror.children.contains { label, _ in
            label?.contains("simulationTask") == true
        }
        XCTAssertTrue(hasSimulationTask, "ModelLabView 应包含 simulationTask 状态属性以支持 Task cancel")
    }
}
