//
//  VaultTestHelpers.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 测试替身与扩展
//  核心职责：为单元测试提供笔记本自动选择策略的测试替身与兼容调用桥接。
//

import Foundation
@testable import ZhiYu

/// 测试用可自定义决策的笔记本选择策略
public struct MockVaultSelectionPolicy: VaultSelectionPolicyProtocol {
    public let shouldAutoSelectFirstVault: Bool

    public init(shouldAutoSelectFirstVault: Bool) {
        self.shouldAutoSelectFirstVault = shouldAutoSelectFirstVault
    }
}

extension VaultService {
    /// 兼容存量测试调用，代理至正式策略方法
    public func autoSelectFirstVaultForUITesting() {
        applyDefaultVaultSelectionPolicy()
    }
}
