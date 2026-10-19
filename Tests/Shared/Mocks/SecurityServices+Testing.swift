//
//  SecurityServices+Testing.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Test] 单元测试共享基础设施
//  核心职责：为 KeychainService、SecurityManager、SecureEnclaveCryptoService 提供 testOverride 计算属性桥接，
//            内部映射到标准 ServiceContainer 注册与注销，彻底将后门从生产代码中移除。
//

import Foundation
import UFPCore
@testable import ZhiYu

extension KeychainService {
    /// 单元测试专用 override 属性：写入时向 DI 容器注册测试替身，置 nil 时注销
    public static var testOverride: KeychainService? {
        get {
            ServiceContainer.shared.resolveOptional(KeychainService.self)
        }
        set {
            if let newValue = newValue {
                ServiceContainer.shared.register(newValue, for: KeychainService.self)
            } else {
                ServiceContainer.shared.unregister(KeychainService.self)
            }
        }
    }
}

extension SecurityManager {
    /// 单元测试专用 override 属性：写入时向 DI 容器注册测试替身，置 nil 时注销
    public static var testOverride: SecurityManager? {
        get {
            ServiceContainer.shared.resolveOptional(SecurityManager.self)
        }
        set {
            if let newValue = newValue {
                ServiceContainer.shared.register(newValue, for: SecurityManager.self)
            } else {
                ServiceContainer.shared.unregister(SecurityManager.self)
            }
        }
    }
}

extension SecureEnclaveCryptoService {
    /// 单元测试专用 override 属性：写入时向 DI 容器注册测试替身，置 nil 时注销
    public static var testOverride: SecureEnclaveCryptoService? {
        get {
            ServiceContainer.shared.resolveOptional(SecureEnclaveCryptoService.self)
        }
        set {
            if let newValue = newValue {
                ServiceContainer.shared.register(newValue, for: SecureEnclaveCryptoService.self)
            } else {
                ServiceContainer.shared.unregister(SecureEnclaveCryptoService.self)
            }
        }
    }
}
