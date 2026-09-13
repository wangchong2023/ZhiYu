//
//  PrivacySecurityFeatureTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 privacy_security 特性的订阅套餐权限控制进行单元测试验证。
//  覆盖范围：
//    - User.hasPrivacySecurity 计算属性在 Lite/Pro 套餐下的正确性
//    - features 数组中 privacy_security 标识的精准匹配
//    - SettingsStore 中隐私模式/生物识别开关的读写与持久化
//

import XCTest
@testable import ZhiYu

@MainActor
final class PrivacySecurityFeatureTests: XCTestCase {

    // MARK: - User.hasPrivacySecurity 权限计算测试

    /// Lite 用户（planKey = "free"）且 features 不包含 privacy_security 时，应无权限
    func testLiteUserWithoutFeatureHasNoPrivacySecurity() {
        let user = User(
            name: "Lite 用户",
            email: "lite@test.com",
            planKey: "free",
            features: ["basic_chat", "text_search", "sandbox_plugins"]
        )
        XCTAssertFalse(user.isPro, "Lite 用户的 isPro 应为 false")
        XCTAssertFalse(user.hasPrivacySecurity, "Lite 用户不含 privacy_security 特性时应无权限")
    }

    /// Pro 用户（planKey = "pro"）即使 features 数组为空，也应自动拥有隐私安全权限
    func testProUserAlwaysHasPrivacySecurity() {
        let user = User(
            name: "Pro 用户",
            email: "pro@test.com",
            planKey: "pro",
            features: []
        )
        XCTAssertTrue(user.isPro, "Pro 用户的 isPro 应为 true")
        XCTAssertTrue(user.hasPrivacySecurity, "Pro 用户应始终拥有隐私安全权限，即使 features 为空")
    }

    /// Pro 用户且 features 显式包含 privacy_security 时，仍返回 true（双重保障）
    func testProUserWithExplicitFeatureStillHasPrivacySecurity() {
        let user = User(
            name: "Pro 全量用户",
            email: "pro_full@test.com",
            planKey: "pro",
            features: ["basic_chat", "privacy_security", "local_slm"]
        )
        XCTAssertTrue(user.hasPrivacySecurity, "Pro 用户 + 显式 privacy_security 应返回 true")
    }

    /// Lite 用户但 features 中包含 privacy_security（特殊授权场景），应有权限
    func testLiteUserWithExplicitFeatureHasPrivacySecurity() {
        let user = User(
            name: "特殊授权用户",
            email: "special@test.com",
            planKey: "free",
            features: ["basic_chat", "privacy_security"]
        )
        XCTAssertFalse(user.isPro, "planKey 为 free 时 isPro 应为 false")
        XCTAssertTrue(user.hasPrivacySecurity, "features 显式包含 privacy_security 时应有权限")
    }

    /// planKey 为 nil 且 features 为空时，应无权限
    func testNilPlanKeyWithoutFeatureHasNoPrivacySecurity() {
        let user = User(
            name: "无套餐用户",
            email: "none@test.com",
            planKey: nil,
            features: []
        )
        XCTAssertFalse(user.isPro, "planKey 为 nil 时 isPro 应为 false")
        XCTAssertFalse(user.hasPrivacySecurity, "无套餐且无特性时应无隐私安全权限")
    }

    /// features 中包含相似但不完全匹配的字符串，不应误判
    func testSimilarFeatureNameDoesNotGrantAccess() {
        let user = User(
            name: "误匹配测试",
            email: "mismatch@test.com",
            planKey: "free",
            features: ["privacy", "security", "privacy_sec"]
        )
        XCTAssertFalse(user.hasPrivacySecurity, "部分匹配的特性名称不应授予隐私安全权限，必须精确匹配 privacy_security")
    }

    // MARK: - SettingsStore 隐私开关持久化测试

    /// 验证隐私模式开关的写入与读取一致性
    func testPrivacyModeTogglePersistence() {
        let store = SettingsStore()
        store.reset()

        // 默认应为开启
        XCTAssertTrue(store.isPrivacyModeEnabled, "隐私模式默认应为开启")

        // 关闭后验证持久化
        store.isPrivacyModeEnabled = false
        XCTAssertFalse(store.isPrivacyModeEnabled, "关闭隐私模式后读取应为 false")

        // 重新开启后验证
        store.isPrivacyModeEnabled = true
        XCTAssertTrue(store.isPrivacyModeEnabled, "重新开启隐私模式后读取应为 true")

        // 清理
        store.reset()
    }

    /// 验证生物识别开关的写入与读取一致性
    func testBiometricTogglePersistence() {
        let store = SettingsStore()
        store.reset()

        // 默认应为开启
        XCTAssertTrue(store.isBiometricEnabled, "生物识别保护默认应为开启")

        // 关闭后验证持久化
        store.isBiometricEnabled = false
        XCTAssertFalse(store.isBiometricEnabled, "关闭生物识别后读取应为 false")

        // 重新开启后验证
        store.isBiometricEnabled = true
        XCTAssertTrue(store.isBiometricEnabled, "重新开启生物识别后读取应为 true")

        // 清理
        store.reset()
    }

    /// 验证隐私模式与生物识别两个开关互相独立，修改其中一个不影响另一个
    func testPrivacyAndBiometricTogglesAreIndependent() {
        let store = SettingsStore()
        store.reset()

        // 关闭隐私模式，验证生物识别不受影响
        store.isPrivacyModeEnabled = false
        XCTAssertTrue(store.isBiometricEnabled, "关闭隐私模式不应影响生物识别开关")

        // 关闭生物识别，验证隐私模式不受影响
        store.isBiometricEnabled = false
        XCTAssertFalse(store.isPrivacyModeEnabled, "隐私模式应保持关闭状态，不受生物识别修改影响")

        // 清理
        store.reset()
    }
}
