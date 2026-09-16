//
//  DIResolver.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/14.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：为 DependencyKey 实现提供统一的 ServiceContainer 解析辅助，
//           消除各 Protocol 文件中 liveValue/testValue 的重复样板代码。
//

import Foundation
import UFPCore

/// 依赖注入解析辅助工具
///
/// 统一各 `DependencyKey` 实现中 `liveValue`/`testValue` 的解析逻辑：
/// - 优先从 `ServiceContainer.shared` 解析已注册的服务实例
/// - 解析失败时降级到提供的默认实现
public enum DIResolver {

    /// 从 ServiceContainer 解析已注册的协议实例，失败时返回默认实现
    /// - Parameters:
    ///   - type: 协议类型
    ///   - fallback: 解析失败时的降级实现
    /// - Returns: 已注册的实例或降级实现
    public static func resolve<T>(_ type: T.Type, fallback: @autoclosure () -> T) -> T {
        if let resolved = ServiceContainer.shared.resolveOptional(type) {
            return resolved
        }
        return fallback()
    }

    /// 从 ServiceContainer 解析已注册的协议实例（可选，无降级）
    /// - Parameter type: 协议类型
    /// - Returns: 已注册的实例或 nil
    public static func resolveOptional<T>(_ type: T.Type) -> T? {
        ServiceContainer.shared.resolveOptional(type)
    }
}
