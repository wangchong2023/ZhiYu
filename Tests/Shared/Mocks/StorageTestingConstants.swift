//
//  StorageTestingConstants.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试基础设施
//  核心职责：保存测试专用启动参数与名称匹配标记。
//
@testable import ZhiYuUnitTestHost

extension StorageConstants {
    // MARK: - 环境变量与启动参数 (Launch Environment & Arguments)
    enum LaunchEnvironment {
        /// UI 自动化测试环境变量 Key
        static let uitestingEnvKey = "UITesting"
        /// UI 自动化测试启动参数
        static let uitestingLaunchArg = "--uitesting"
    }

    // MARK: - 测试名称匹配标记 (Test Name Markers)
    /// 测试环境下笔记本名称子串匹配标记
    enum TestName {
        /// 默认知识管理笔记本名称标记
        static let vaultMarker: String = "Vault"
        /// 项目调研笔记本名称标记
        static let researchMarker: String = "Research"
    }

}
