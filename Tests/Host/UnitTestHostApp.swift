//
//  UnitTestHostApp.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试基础设施
//  核心职责：为空单测宿主提供入口，不构造业务环境或启动后台任务。
//
import SwiftUI

@main
struct UnitTestHostApp: App {
    var body: some Scene {
        WindowGroup {
            Text(L10n.Common.testRunnerWorking)
        }
    }
}
