//
//  TestModeDetector.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/20.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：集中检测测试模式（UI 测试 / 单元测试 / Mock 数据），避免在视图/服务层散布测试耦合代码。
//

import Foundation

/// 测试模式检测器：集中管理所有测试模式判断，生产代码通过此工具类引用，不在各处散布 launch argument 检测。
public enum TestModeDetector {

    // MARK: - 缓存（避免重复解析）

    /// 是否为 UI 测试模式（`--uitesting` launch argument 或 `UITesting` 环境变量）
    public static let isUITesting: Bool = {
        let hasLaunchArg = CommandLine.arguments.contains("--uitesting")
        let hasEnvVar = ProcessInfo.processInfo.environment["UITesting"] == "true"
        return hasLaunchArg || hasEnvVar
    }()

    /// 是否为单元测试模式（`XCTestCase` 类存在且非 UI 测试 Mock 数据模式）
    public static let isUnitTesting: Bool = {
        let hasXCTest = NSClassFromString("XCTestCase") != nil
        let isMockDataMode = CommandLine.arguments.contains("-UITest_MockData")
        return hasXCTest && !isMockDataMode
    }()

    /// 是否为 UI 测试 Mock 数据模式（`-UITest_MockData` launch argument）
    public static let isMockDataMode: Bool = {
        CommandLine.arguments.contains("-UITest_MockData")
    }()

    /// 是否需要重置 UserDefaults（`-ResetUserDefaults` launch argument）
    public static let shouldResetUserDefaults: Bool = {
        CommandLine.arguments.contains("-ResetUserDefaults")
    }()

    /// 是否为任何测试环境（UI 测试或单元测试）
    public static var isAnyTesting: Bool {
        isUITesting || isUnitTesting
    }
}
