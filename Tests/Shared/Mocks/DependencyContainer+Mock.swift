//
//  DependencyContainer+Mock.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Test] 单元测试共享基础设施
//  核心职责：提供 DependencyContainer 的测试工厂扩展，彻底将 mock() 从生产底座剥离。
//

import Foundation
@testable import ZhiYu

extension DependencyContainer {
    /// 测试用的全 mock 依赖工厂
    public static func mock() -> DependencyContainer {
        DependencyContainer()
    }
}
