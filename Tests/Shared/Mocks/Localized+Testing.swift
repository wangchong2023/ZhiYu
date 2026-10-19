//
//  Localized+Testing.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 测试辅助扩展
//  核心职责：为测试套件提供 Localized 的测试专用能力，隔离于 Sources/ 生产目录。
//

import Foundation
@testable import ZhiYu

extension Localized {
    /// 单元测试专用：重置本地化状态供测试隔离使用
    @MainActor
    public static func resetForTesting() {
        resetCache()
    }
}
