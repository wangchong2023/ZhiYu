//
//  UITestRoute.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试基础设施
//  核心职责：在测试应用中解析并应用自动化导航目标。
//
import Foundation

enum UITestRoute {
    case aiSettings
    case settings

    /// 从 CommandLine.arguments 解析 UI 测试路由
    static func fromLaunchArguments(_ arguments: [String] = CommandLine.arguments) -> UITestRoute? {
        if arguments.contains("--open-ai-settings") { return .aiSettings }
        if arguments.contains("--open-settings") { return .settings }
        return nil
    }

    /// 将路由应用到 Router 状态
    @MainActor
    func apply(to router: Router) {
        switch self {
        case .aiSettings:
            router.isShowingAISettingsSheet = true
        case .settings:
            router.isShowingSettingsSheet = true
        }
    }
}
