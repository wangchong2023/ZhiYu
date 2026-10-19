//
//  SplashPresentationPolicy.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/10/19.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：评估并控制启动闪屏 (Splash) 的展示、跳过及持久化状态。
//

import Foundation
import UFPCore

/// 启动闪屏展示策略
/// 负责判断冷启动时是否跳过闪屏，以及管理持久化的 hasSeenSplash 状态。
public struct SplashPresentationPolicy: Sendable {

    /// 评估冷启动时是否应当跳过闪屏页
    /// - Parameters:
    ///   - isUITesting: 是否处于 UI 测试环境（--uitesting）
    ///   - hasSeenSplashBefore: 是否已持久化记录看过闪屏（非首次冷启动）
    ///   - isLoggedIn: 当前用户是否已处于登录状态
    /// - Returns: true 表示跳过闪屏，false 表示展示闪屏
    public static func shouldSkipSplash(
        isUITesting: Bool,
        hasSeenSplashBefore: Bool,
        isLoggedIn: Bool
    ) -> Bool {
        isUITesting || hasSeenSplashBefore || isLoggedIn
    }

    /// 检查持久化存储中是否已有看过闪屏的记录
    /// - Parameter keyStore: KeyStoreProtocol 实例，nil 时视为未看过（不降级 UserDefaults，避免绕过 DI 存储层）
    /// - Returns: true 表示非首次冷启动（曾经展示过）
    public static func hasSeenSplashBefore(keyStore: (any KeyStoreProtocol)?) -> Bool {
        keyStore?.bool(forKey: AppConstants.Keys.Storage.hasSeenSplashBefore) ?? false
    }

    /// 标记已看过闪屏，并固化持久化记录
    /// - Parameter keyStore: KeyStoreProtocol 实例，nil 时忽略
    public static func markSplashSeen(keyStore: (any KeyStoreProtocol)?) {
        keyStore?.set(true, forKey: AppConstants.Keys.Storage.hasSeenSplashBefore)
    }

    /// 重置看过闪屏的标记（主要用于开发者设置或测试隔离）
    /// - Parameter keyStore: KeyStoreProtocol 实例，nil 时忽略
    public static func resetSplashState(keyStore: (any KeyStoreProtocol)?) {
        keyStore?.removeObject(forKey: AppConstants.Keys.Storage.hasSeenSplashBefore)
    }
}
