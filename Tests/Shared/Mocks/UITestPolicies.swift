//
//  UITestPolicies.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/10/18.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 测试替身与策略实现
//  核心职责：为 UI 自动化测试提供特定的策略协议实现，物理隔离于 Sources/ 生产目录。
//

import Foundation
@testable import ZhiYu

/// 自动化 UI 测试笔记本选择策略
public struct UITestVaultSelectionPolicy: VaultSelectionPolicyProtocol {
    public init() {}
    public var shouldAutoSelectFirstVault: Bool {
        CommandLine.arguments.contains("--uitesting") && !CommandLine.arguments.contains("--skip-auto-vault")
    }
}

/// 自动化测试笔记本标识交互策略
public struct UITestVaultBadgeInteractionPolicy: VaultBadgeInteractionPolicyProtocol {
    public init() {}
    public var isDirectButton: Bool {
        CommandLine.arguments.contains("--uitesting")
    }
}

/// 自动化测试导航布局策略
public struct UITestNavigationLayoutPolicy: NavigationLayoutPolicyProtocol {
    public init() {}
    public var prefersLegacyTabView: Bool {
        CommandLine.arguments.contains("--uitesting")
    }
    public var enablesAuxiliaryExitAccess: Bool {
        CommandLine.arguments.contains("--uitesting")
    }
}

/// 自动化测试自动登录策略
public struct UITestAutoLoginPolicy: AutoLoginPolicyProtocol {
    public init() {}
    public var shouldAttemptAutoLogin: Bool {
        let isTesting = CommandLine.arguments.contains("--uitesting")
        let injectedRealToken = !(ProcessInfo.processInfo.environment["UITest_InjectAccessToken"] ?? "").isEmpty
        return !isTesting || injectedRealToken
    }
}

/// 自动化测试笔记本播种策略
public struct UITestVaultSeedingPolicy: VaultSeedingPolicyProtocol {
    public init() {}
    public func shouldSeed(vaultID: UUID, hasSeededBefore: Bool) -> Bool {
        true
    }
}
