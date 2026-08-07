//
//  MainActorBridge.swift
//  UFPCore
//
//  Created by CodeFree on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：提供从任意线程安全访问 @MainActor 隔离代码的桥接函数。
//           主线程直接执行（避免 DispatchQueue.main.sync 死锁），
//           后台线程同步调度到主队列。
//

import Foundation

// MARK: - 泛型版本（有返回值）

/// 在任意线程安全地执行一段 @MainActor 隔离代码块并获取返回值。
/// - 主线程：通过 MainActor.assumeIsolated 直接执行
/// - 后台线程：通过 DispatchQueue.main.sync 同步调度
/// - Parameter block: 需要在主 Actor 上执行的代码块
/// - Returns: 代码块的返回值
public func runOnMainSync<T: Sendable>(_ block: @MainActor @Sendable () -> T) -> T {
    if Thread.isMainThread {
        return MainActor.assumeIsolated { block() }
    } else {
        return DispatchQueue.main.sync(execute: block)
    }
}

// MARK: - Void 版本（无返回值，避免 void_function_in_ternary SwiftLint 违规）

/// 在任意线程安全地执行一段无返回值的 @MainActor 隔离代码块。
/// - 主线程：通过 MainActor.assumeIsolated 直接执行
/// - 后台线程：通过 DispatchQueue.main.sync 同步调度
/// - Parameter block: 需要在主 Actor 上执行的代码块
public func runOnMainSync(_ block: @MainActor @Sendable () -> Void) {
    if Thread.isMainThread {
        MainActor.assumeIsolated { block() }
    } else {
        DispatchQueue.main.sync(execute: block)
    }
}
