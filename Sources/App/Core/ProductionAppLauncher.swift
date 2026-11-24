//
//  ProductionAppLauncher.swift
//  ZhiYu
//
//  系统层级：[L3] 应用层
//  核心职责：启动正式应用，所有构建配置使用同一业务入口。
//
import SwiftUI

/// 正式应用入口不解析测试参数，也不加载测试设施。
@main
struct ProductionAppLauncher {
    @MainActor
    static func main() {
        ZhiYuApp.main()
    }
}
