//
//  MutexBox.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：线程安全的 Sendable 包装器 — 在 @Sendable 闭包（DispatchQueue.async /
//            NotificationCenter observer）中安全捕获可变状态，消除 SendableClosureCaptures 警告。
//

import Foundation

/// 线程安全的 Sendable 包装器：在并发闭包中安全捕获和修改可变值。
/// 使用 NSLock 保证互斥，标记 `@unchecked Sendable` 因为线程安全由内部锁保证。
final class MutexBox<T>: @unchecked Sendable {
    private var value: T
    private let lock = NSLock()

    init(_ value: T) {
        self.value = value
    }

    /// 在锁保护下修改内部值。
    func mutate(_ body: (inout T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&value)
    }

    /// 在锁保护下读取内部值。
    func get() -> T {
        lock.lock()
        defer { lock.unlock() }
        return value
    }
}
