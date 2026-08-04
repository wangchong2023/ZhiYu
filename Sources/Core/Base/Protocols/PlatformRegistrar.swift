//
//  PlatformRegistrar.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：定义跨平台注册契约，允许各平台在独立文件中注入其特有实现。
//
import Foundation
import UFPCore

/// 平台特定服务注册契约
/// 核心价值：通过协议多态替代大量的 #if os 宏判断，实现应用层与平台实现的物理隔离。
@MainActor
protocol PlatformRegistrar {
    /// 注册当前平台特有的基础设施服务
    /// - Parameter container: DI 容器实例
    static func registerServices(in container: ServiceContainer)
}
