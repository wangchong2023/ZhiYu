//
//  TestStateResetRegistry.swift
//  UFPCore
//
//  Created by Antigravity on 2026/09/06.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPCore]
//  核心职责：测试隔离注册表 — 单例通过协议自注册重置逻辑，避免硬编码维护重置列表。
//

import Foundation

// MARK: - TestStateResettable 协议

/// 测试状态可重置协议
///
/// 单例实现此协议并通过 `TestStateResetRegistry.shared.register(...)` 自注册，
/// `resetPersistentTestState()` 会遍历注册表统一调用，避免硬编码维护重置列表。
///
/// **设计动机**：原先 `resetPersistentTestState()` 硬编码 18 个单例重置调用，
/// 每次新增单例都要手动加一行，必然遗漏。注册式让单例自己负责声明重置逻辑。
///
/// **使用方式**：
/// ```swift
/// final class MySingleton: TestStateResettable {
///     static let shared = MySingleton()
///
///     func resetStateForTesting() {
///         // 清理状态
///     }
///
///     private init() {
///         TestStateResetRegistry.shared.register(self)
///     }
/// }
/// ```
public protocol TestStateResettable: AnyObject {
    /// 重置单例状态用于测试隔离
    ///
    /// 实现应清空所有可变状态（缓存、历史、下载状态等），
    /// 但不应重建单例本身（`shared` 保持不变）。
    func resetStateForTesting()
}

// MARK: - TestStateResetRegistry 注册表

/// 测试状态重置注册表
///
/// 单例通过 `register(...)` 自注册，`resetAll()` 统一遍历调用。
/// 线程安全：内部用 NSLock 保护（与 ServiceContainer 一致）。
///
/// **注册时机**：单例 `init()` 中注册（`static let shared` 首次访问时触发）。
/// **重置时机**：`XCTestCase.setUp` / `tearDown` 中调用 `resetAll()`。
///
/// **注意**：注册顺序不保证，各 `resetForTesting()` 实现不应依赖其他单例状态。
public final class TestStateResetRegistry: @unchecked Sendable {

    public static let shared = TestStateResetRegistry()

    private let lock = NSLock()
    private var resettables: [ObjectIdentifier: TestStateResettable] = [:]

    private init() {}

    /// 注册一个可重置单例
    ///
    /// 幂等：重复注册同一实例不会重复添加（以 ObjectIdentifier 去重）。
    /// - Parameter resettable: 实现 `TestStateResettable` 的单例实例
    public func register(_ resettable: TestStateResettable) {
        let id = ObjectIdentifier(resettable)
        lock.withLock {
            resettables[id] = resettable
        }
    }

    /// 注销一个可重置单例（通常不需要，单例生命周期 = 进程生命周期）
    public func unregister(_ resettable: TestStateResettable) {
        let id = ObjectIdentifier(resettable)
        lock.withLock {
            resettables.removeValue(forKey: id)
        }
    }

    /// 重置所有已注册的单例状态
    ///
    /// 遍历注册表，对每个单例调用 `resetStateForTesting()`。
    /// 某个单例重置抛出异常不会中断其他单例的重置（catch 后继续）。
    @MainActor
    public func resetAll() {
        let snapshot: [TestStateResettable] = lock.withLock {
            Array(resettables.values)
        }
        for resettable in snapshot {
            resettable.resetStateForTesting()
        }
    }

    /// 已注册的单例数量（诊断用）
    public var count: Int {
        lock.withLock { resettables.count }
    }

    /// 已注册的单例类型名称列表（诊断用）
    public var registeredTypeNames: [String] {
        lock.withLock {
            resettables.values.map { String(describing: type(of: $0)) }.sorted()
        }
    }
}

// MARK: - ServiceContainer 集成
//
// ServiceContainer 不通过 TestStateResetRegistry 自注册，原因：
// 1. ServiceContainer.resetForTesting() 清空整个 DI 容器，语义是"销毁所有服务"而非"重置单例状态"
// 2. 不是所有调用 resetPersistentTestState() 的测试都会随后调用 setupFullMockEnvironment()
// 3. ServiceContainer 的重置由 setupFullMockEnvironment() / tearDown 中的 ServiceContainer.shared.reset() 管理
//
// 如需在测试中清空 DI 容器，应显式调用 ServiceContainer.shared.resetForTesting()。
