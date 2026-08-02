//
//  ServiceContainer.swift
//  UFPCore
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPCore]
//  核心职责：通用依赖注入容器 (Service Locator 模式)，提供类型安全与并发保护的服务注册与解析。
//

import Foundation
import os

// MARK: - DI 诊断专用日志子系统
/// 使用 os_log .fault 级别确保诊断信息在崩溃时写入系统日志，避免 Logger 异步刷新丢失
private let diLog = OSLog(subsystem: "com.zhiyu.app", category: "DI-Container")

/// 依赖注入容器 (L2 层：解耦中枢)
/// 遵循 Service Locator 模式，支持 Mock 替换 (@SR-04: 受权限管控的插件访问基础)
public final class ServiceContainer: @unchecked Sendable {
    /// 全局单例
    public static let shared = ServiceContainer()

    /// 服务注册表
    private var services: [String: Any] = [:]

    /// 并发保护锁 (os_unfair_lock)，比 NSLock 更轻量且具备极佳的高并发性能
    private let lockPointer: UnsafeMutablePointer<os_unfair_lock>

    /// 诊断计数器：累计 resolve 调用次数，用于定位全量测试中第几次 resolve 触发崩溃
    private var resolveCallCount: Int = 0

    /// 诊断计数器：累计 register 调用次数
    private var registerCallCount: Int = 0

    /// 上次 reset 的诊断信息
    private var lastResetInfo: String?
    /// 上次 reset 的时间戳
    private var lastResetTimestamp: Date?

    private init() {
        lockPointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        lockPointer.initialize(to: os_unfair_lock())
    }

    deinit {
        lockPointer.deallocate()
    }

    /// 注册服务
    /// - Parameters:
    ///   - service: 服务实例
    ///   - type: 服务的协议或类类型
    public func register<T>(_ service: T, for type: T.Type) {
        let key = makeKey(for: type)
        os_unfair_lock_lock(lockPointer)
        services[key] = service
        registerCallCount += 1
        os_unfair_lock_unlock(lockPointer)
        #if DEBUG
        Logger.shared.debug("DI: Registered [\(key)] with instance \(String(describing: service))")
        #endif
    }

    /// 标记是否由生产注册链（AppEnvironment）完成初始化，防止测试误清
    private var isProductionChainPopulated = false

    /// 标记生产链已完成，禁止 reset() 清空 / 标记 DI 生命周期就绪
    public func markProductionChainComplete() {
        isProductionChainPopulated = true
        // 记录生产链完成时的诊断快照
        os_unfair_lock_lock(lockPointer)
        let keyCount = services.count
        let allKeys = Array(services.keys)
        os_unfair_lock_unlock(lockPointer)
        let info = "[ServiceContainer] Production DI chain complete. Registered services: \(keyCount). Keys: \(allKeys.sorted().joined(separator: ", "))"
        os_log(.info, log: diLog, "%{public}@", info)
        Logger.shared.info(info)
    }

    /// DI 容器是否已就绪（生产注册链已完成）
    /// 在 registerDIModules() 完成前访问 resolve() 的任何代码都是潜在崩溃源。
    public var isReady: Bool { isProductionChainPopulated }

    /// 诊断属性：是否被生产链锁定（公开只读）
    public var isProductionChainLocked: Bool { isProductionChainPopulated }

    /// 诊断属性：当前注册表快照
    public var diagnosticSnapshot: [String: Bool] {
        os_unfair_lock_lock(lockPointer)
        let keys = Array(services.keys)
        os_unfair_lock_unlock(lockPointer)
        var snapshot: [String: Bool] = [:]
        for key in keys { snapshot[key] = true }
        return snapshot
    }

    /// 重置所有服务（主要用于测试环境隔离）
    /// 生产注册链完成后调用此方法无效果，防止测试误清导致 @Inject 崩溃
    public func reset() {
        let callSite = Thread.callStackSymbols.prefix(5).joined(separator: "\n")
        guard !isProductionChainPopulated else {
            let msg = "[ServiceContainer] reset() BLOCKED: production DI chain is complete. Call site:\n\(callSite)"
            os_log(.error, log: diLog, "%{public}@", msg)
            Logger.shared.warning(msg)
            return
        }
        os_unfair_lock_lock(lockPointer)
        let removedCount = services.count
        let removedKeys = Array(services.keys)
        services.removeAll()
        os_unfair_lock_unlock(lockPointer)
        lastResetInfo = "Removed \(removedCount) services: \(removedKeys.sorted().joined(separator: ", "))"
        lastResetTimestamp = Date()
        os_log(.info, log: diLog, "%{public}@", "[ServiceContainer] reset() executed. \(lastResetInfo ?? "N/A")")
    }

    /// 解析服务
    public func resolve<T>(_ type: T.Type) -> T {
        let key = makeKey(for: type)

        // 单次加锁：同时读取实例和诊断信息，消除两次加锁间的竞态窗口
        os_unfair_lock_lock(lockPointer)
        let instance = services[key]
        let registeredKeys = Array(services.keys)
        let callCount = resolveCallCount
        resolveCallCount += 1
        let regCallCount = registerCallCount
        os_unfair_lock_unlock(lockPointer)

        if let service = instance as? T {
            return service
        }

        // ── 服务未注册：输出多层次诊断信息 ──
        let rawTypeString = String(describing: type)
        let readyHint = registeredKeys.isEmpty
            ? "[DI ERROR — resolve() called before any DI initialization]"
            : "[error: \(registeredKeys.count) services registered — key '\(key)' not found]"
        let errorSummary = "DI Error: Service [\(key)] not registered. \(readyHint) Type: \(rawTypeString). Keys (\(registeredKeys.count)): \(registeredKeys.sorted().joined(separator: ", "))"

        // 层级 1: os_log .fault — 崩溃后仍可在系统日志中检索
        os_log(.fault, log: diLog, "%{public}@", errorSummary)
        os_log(.fault, log: diLog,
               "DI resolve #%{public}d (register #%{public}d) | productionChainLocked: %{public}@ | lastReset: %{public}@ (%{public}@)",
               callCount, regCallCount,
               isProductionChainPopulated ? "YES" : "NO",
               lastResetTimestamp?.description ?? "never",
               lastResetInfo ?? "N/A")

        // 层级 2: stderr — 同步打印，不经过任何异步缓冲区
        fputs("""
        ╔══════════════════════════════════════════════════════════════╗
        ║  DI RESOLVE FAILURE — Crash Imminent                        ║
        ╠══════════════════════════════════════════════════════════════╣
        ║  Key:        \(key)
        ║  Type:       \(rawTypeString)
        ║  Call #:     \(callCount)  |  Register #: \(regCallCount)
        ║  Production: \(isProductionChainPopulated ? "YES" : "NO")
        ║  Last Reset: \(lastResetTimestamp?.description ?? "never")
        ║              \(lastResetInfo ?? "N/A")
        ║  Keys (\(registeredKeys.count)): \(registeredKeys.sorted().joined(separator: ", "))
        ╚══════════════════════════════════════════════════════════════╝

        """, stderr)

        #if DEBUG
        Logger.shared.error(errorSummary)
        #endif

        // 使用断言而非 fatalError，在开发环境下更容易追踪
        assertionFailure(errorSummary)

        // 兜底返回（仅在非调试模式下运行到此）
        fatalError(errorSummary)
    }

    /// 尝试解析服务，如果未注册则返回 nil，不会触发断言或崩溃
    public func resolveOptional<T>(_ type: T.Type) -> T? {
        let key = makeKey(for: type)
        os_unfair_lock_lock(lockPointer)
        let instance = services[key]
        os_unfair_lock_unlock(lockPointer)
        return instance as? T
    }

    /// 类型擦除的服务解析（供 `@Inject` 可选检测使用）
    public func typeErasedResolve(_ type: Any.Type) -> Any? {
        let key = makeKey(forAny: type)
        os_unfair_lock_lock(lockPointer)
        let instance = services[key]
        os_unfair_lock_unlock(lockPointer)
        return instance
    }

    /// 生成类型唯一的 Key，移除 existential type 和模块名前缀的干扰
    private func makeKey<T>(for type: T.Type) -> String {
        var typeString = "\(type)"

        // 1. 移除 "any " 或 "all " 前缀
        if typeString.hasPrefix("any ") {
            typeString.removeFirst(4)
        } else if typeString.hasPrefix("all ") {
            typeString.removeFirst(4)
        }

        // 2. 移除模块名前缀 (例如 "ZhiYu.LoggerProtocol" -> "LoggerProtocol")
        if !typeString.contains("<") {
            if let lastDot = typeString.lastIndex(of: ".") {
                typeString = String(typeString[typeString.index(after: lastDot)...])
            }
        }

        // 3. 移除 Swift 内部修饰符 (例如 "(unknown context at $109403...)")
        if let bracketIndex = typeString.firstIndex(of: " ") {
            typeString = String(typeString[..<bracketIndex])
        }

        return typeString
    }

    /// 非泛型版本的 Key 生成（供 `typeErasedResolve` 使用）
    private func makeKey(forAny type: Any.Type) -> String {
        var typeString = "\(type)"
        if typeString.hasPrefix("any ") {
            typeString.removeFirst(4)
        } else if typeString.hasPrefix("all ") {
            typeString.removeFirst(4)
        }
        if !typeString.contains("<") {
            if let lastDot = typeString.lastIndex(of: ".") {
                typeString = String(typeString[typeString.index(after: lastDot)...])
            }
        }
        if let bracketIndex = typeString.firstIndex(of: " ") {
            typeString = String(typeString[..<bracketIndex])
        }
        return typeString
    }

    /// 检查服务是否已注册
    public func hasService<T>(for type: T.Type) -> Bool {
        let key = makeKey(for: type)
        os_unfair_lock_lock(lockPointer)
        let exists = services[key] != nil
        os_unfair_lock_unlock(lockPointer)
        return exists
    }

    /// 安全解析服务，未注册时返回 nil（不 fatalError）
    public func optionalResolve<T>(_ type: T.Type) -> T? {
        let key = makeKey(for: type)
        os_unfair_lock_lock(lockPointer)
        let service = services[key]
        os_unfair_lock_unlock(lockPointer)
        return service as? T
    }
}

// MARK: - Factory 风格可选检测

/// 内部协议：仅 `Optional` 遵循，供 `@Inject` 在运行时检测属性类型是否为可选。
public protocol OptionalDetectableProtocol {
    static var injectWrappedType: Any.Type { get }
    /// 将解析出的值包装为 Optional<Wrapped>，用于安全构造返回类型
    static func injectWrap(_ value: Any) -> Any
}

extension Optional: OptionalDetectableProtocol {
    public static var injectWrappedType: Any.Type { Wrapped.self }
    public static func injectWrap(_ value: Any) -> Any {
        // 尝试将值转型为 Wrapped，成功则包装为 .some，失败则返回 .none
        if let wrapped = value as? Wrapped {
            return Optional.some(wrapped) as Any
        }
        return (nil as Wrapped?) as Any
    }
}

/// 依赖注入属性包装器（Factory 风格）。
@propertyWrapper
public struct Inject<T>: @unchecked Sendable {
    public init() {}
    
    // swiftlint:disable:next implicitly_unwrapped_optional
    public var wrappedValue: T {
        // 检测 T 是否为 Optional<Wrapped>
        if let optionalMetatype = T.self as? OptionalDetectableProtocol.Type {
            let wrappedType = optionalMetatype.injectWrappedType
            // 尝试解析被包装的类型，返回 nil（依赖未注册）或具体值
            let anyResult = ServiceContainer.shared.typeErasedResolve(wrappedType)
            // 通过协议的 injectWrap 安全构造 Optional<Wrapped>，再转为 T
            if let result = optionalMetatype.injectWrap(anyResult as Any) as? T {
                return result
            }
            // 依赖未注册或类型不匹配 → 返回 nil
            return Inject<T>.optionalNoneSentinel
        }
        // 非可选类型 → 必需依赖，缺失触发诊断崩溃
        return ServiceContainer.shared.resolve(T.self)
    }

    /// 安全访问：DI 未就绪时返回 nil，用于初始化早期或单测环境
    public var safeValue: T? {
        ServiceContainer.shared.resolveOptional(T.self)
    }

    // MARK: - 内部哨兵

    /// 类型无关的 Optional.none 哨兵。
    private static var optionalNoneSentinel: T {
        let sentinel: Bool? = .none
        return unsafeBitCast(sentinel, to: T.self)
    }
}
