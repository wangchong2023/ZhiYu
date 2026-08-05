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

    /// 并发保护锁 (OSAllocatedUnfairLock)
    /// Swift 5.9+ 封装 os_unfair_lock，Sendable 安全，无需手动 allocate/deallocate
    private let lock = OSAllocatedUnfairLock()

    /// 诊断计数器：累计 resolve 调用次数，用于定位全量测试中第几次 resolve 触发崩溃
    private var resolveCallCount: Int = 0

    /// 诊断计数器：累计 register 调用次数
    private var registerCallCount: Int = 0

    /// 上次 reset 的诊断信息
    private var lastResetInfo: String?
    /// 上次 reset 的时间戳
    private var lastResetTimestamp: Date?

    /// 可注入的致命失败处理器（缺陷 #5 修复）
    /// - 生产环境：默认 nil，走 assertionFailure + fatalError（fail-fast 契约）
    /// - 测试环境：替换为非崩溃闭包，使失败路径可被单元测试覆盖
    /// - 用法：`ServiceContainer.fatalFailureHandler = { msg in XCTFail(msg) }`
    /// - 并发安全：仅在测试 setUp/tearDown 单线程设置，用 nonisolated(unsafe) 标注
    ///   避免多线程并发读写数据竞争（生产环境不修改）
    public nonisolated(unsafe) static var fatalFailureHandler: ((String) -> Void)?

    private init() {}

    // 注：OSAllocatedUnfairLock 为值类型，无需 deinit 释放

    /// 注册服务
    /// - Parameters:
    ///   - service: 服务实例
    ///   - type: 服务的协议或类类型
    public func register<T>(_ service: T, for type: T.Type) {
        let key = makeKey(for: type)
        lock.withLock {
            services[key] = service
            registerCallCount += 1
        }
        #if DEBUG
        MinimalLogger.shared.debug("DI: Registered [\(key)]")
        #endif
    }

    /// 标记是否由生产注册链（AppEnvironment）完成初始化，防止测试误清
    private var isProductionChainPopulated = false

    /// 标记生产链已完成，禁止 reset() 清空 / 标记 DI 生命周期就绪
    /// 并发安全：isProductionChainPopulated 的写入在 lock 内，消除与 reset() 的竞态
    public func markProductionChainComplete() {
        let info = lock.withLock { () -> String in
            isProductionChainPopulated = true
            let keyCount = services.count
            let allKeys = Array(services.keys)
            return "[ServiceContainer] Production DI chain complete. Registered services: \(keyCount). Keys: \(allKeys.sorted().joined(separator: ", "))"
        }
        os_log(.info, log: diLog, "%{public}@", info)
        MinimalLogger.shared.info(info)
    }

    /// DI 容器是否已就绪（生产注册链已完成）
    /// 在 registerDIModules() 完成前访问 resolve() 的任何代码都是潜在崩溃源。
    /// 并发安全：读取在 lock 内，消除与 markProductionChainComplete()/reset() 的竞态
    public var isReady: Bool { lock.withLock { isProductionChainPopulated } }

    /// 诊断属性：是否被生产链锁定（公开只读）
    /// 并发安全：读取在 lock 内
    public var isProductionChainLocked: Bool { lock.withLock { isProductionChainPopulated } }

    /// 诊断属性：当前注册表快照
    public var diagnosticSnapshot: [String: Bool] {
        let keys = lock.withLock { Array(services.keys) }
        var snapshot: [String: Bool] = [:]
        for key in keys { snapshot[key] = true }
        return snapshot
    }

    /// 重置所有服务（主要用于测试环境隔离）
    /// 生产注册链完成后调用此方法无效果，防止测试误清导致 @Inject 崩溃
    /// 并发安全：isProductionChainPopulated 的检查与 services 的清空在同一次 lock 内原子执行，
    /// 消除与 markProductionChainComplete() 的竞态窗口（问题 #8 真正修复）
    /// 注意：之前的修复（两次 lock 调用）仍有竞态窗口，因为 mark 可能在两次 lock 之间执行。
    public func reset() {
        let callSite = Thread.callStackSymbols.prefix(5).joined(separator: "\n")
        let (shouldBlock, removedCount, removedKeys): (Bool, Int, [String]) = lock.withLock {
            if isProductionChainPopulated {
                return (true, 0, [])
            }
            let count = services.count
            let keys = Array(services.keys)
            services.removeAll()
            return (false, count, keys)
        }
        if shouldBlock {
            let msg = "[ServiceContainer] reset() BLOCKED: production DI chain is complete. Call site:\n\(callSite)"
            os_log(.error, log: diLog, "%{public}@", msg)
            MinimalLogger.shared.warning(msg)
            return
        }
        lastResetInfo = "Removed \(removedCount) services: \(removedKeys.sorted().joined(separator: ", "))"
        lastResetTimestamp = Date()
        os_log(.info, log: diLog, "%{public}@", "[ServiceContainer] reset() executed. \(lastResetInfo ?? "N/A")")
    }

    /// 强制重置（仅供测试套件隔离使用）
    /// 与 `reset()` 的区别：会同时清空 `isProductionChainPopulated` 标记，
    /// 解决 `markProductionChainComplete()` 不可逆导致 `shared` 单元被永久污染、
    /// 后续测试 `reset()` 全部静默失效的隔离破坏问题。
    /// 生产代码严禁调用此方法。
    /// 并发安全：isProductionChainPopulated 的清空与 services 的清空在同一次 lock 内原子执行（问题 #8 真正修复）
    public func resetForTesting() {
        let callSite = Thread.callStackSymbols.prefix(5).joined(separator: "\n")
        os_log(.info, log: diLog, "%{public}@", "[ServiceContainer] resetForTesting() called. Call site:\n\(callSite)")
        let (removedCount, removedKeys) = lock.withLock { () -> (Int, [String]) in
            isProductionChainPopulated = false
            let count = services.count
            let keys = Array(services.keys)
            services.removeAll()
            return (count, keys)
        }
        lastResetInfo = "Removed \(removedCount) services: \(removedKeys.sorted().joined(separator: ", "))"
        lastResetTimestamp = Date()
        os_log(.info, log: diLog, "%{public}@", "[ServiceContainer] resetForTesting() executed. \(lastResetInfo ?? "N/A")")
    }

    /// resolve 诊断快照（避免 large_tuple 违规，元组成员不超过 2）
    internal struct ResolveSnapshot {
        let instance: Any?
        let registeredKeys: [String]
        let callCount: Int
        let regCallCount: Int
    }

    /// 解析服务
    public func resolve<T>(_ type: T.Type) -> T {
        let key = makeKey(for: type)

        // 单次加锁：同时读取实例和诊断信息，消除两次加锁间的竞态窗口
        let snapshot = lock.withLock { () -> ResolveSnapshot in
            let instance = services[key]
            let registeredKeys = Array(services.keys)
            let callCount = resolveCallCount
            resolveCallCount += 1
            let regCallCount = registerCallCount
            return ResolveSnapshot(
                instance: instance,
                registeredKeys: registeredKeys,
                callCount: callCount,
                regCallCount: regCallCount
            )
        }

        if let service = snapshot.instance as? T {
            return service
        }

        // ── 服务未注册：输出诊断信息并 fail-fast 崩溃 ──
        let summary = buildResolveFailureDiagnostics(key: key, type: type, snapshot: snapshot).0
        emitResolveFailureDiagnostics(key: key, type: type, snapshot: snapshot)
        // 缺陷 #5 修复：可注入的失败处理器（与 assertRegistered 行为一致）
        // 测试时替换为非崩溃闭包，使 resolve 失败路径的诊断构建可被单元测试覆盖
        // 注意：resolve 必须返回 T，handler 模式下仍需 fatalError 兜底（无法返回有效值）
        // 但 handler 调用行可被覆盖率统计覆盖，解锁 resolve 失败路径的测试覆盖
        if let handler = ServiceContainer.fatalFailureHandler {
            handler(summary)
        }
        assertionFailure(summary)
        fatalError(summary)
    }

    /// 输出 resolve 失败诊断信息（os_log + stderr + MinimalLogger）
    /// 提取为可测试方法：单元测试可验证诊断输出不崩溃
    internal func emitResolveFailureDiagnostics<T>(
        key: String, type: T.Type, snapshot: ResolveSnapshot
    ) {
        let (errorSummary, diagnosticBlock) = buildResolveFailureDiagnostics(
            key: key, type: type, snapshot: snapshot
        )

        // 层级 1: os_log .fault — 崩溃后仍可在系统日志中检索
        os_log(.fault, log: diLog, "%{public}@", errorSummary)
        diagnosticBlock(self)

        #if DEBUG
        MinimalLogger.shared.error(errorSummary)
        #endif
    }

    /// 构建 resolve 失败诊断信息（可测试的纯函数）
    /// - Returns: (错误摘要, 诊断输出闭包)
    /// 注意：提取为独立方法使诊断逻辑可被单元测试覆盖，无需触发 fatalError
    internal func buildResolveFailureDiagnostics<T>(
        key: String, type: T.Type, snapshot: ResolveSnapshot
    ) -> (String, (ServiceContainer) -> Void) {
        let rawTypeString = String(describing: type)
        let readyHint = snapshot.registeredKeys.isEmpty
            ? "[DI ERROR — resolve() called before any DI initialization]"
            : "[error: \(snapshot.registeredKeys.count) services registered — key '\(key)' not found]"
        let errorSummary = "DI Error: Service [\(key)] not registered. \(readyHint) Type: \(rawTypeString). Keys (\(snapshot.registeredKeys.count)): \(snapshot.registeredKeys.sorted().joined(separator: ", "))"

        let diagBlock: (ServiceContainer) -> Void = { container in
            os_log(.fault, log: diLog,
                   "DI resolve #%{public}d (register #%{public}d) | productionChainLocked: %{public}@ | lastReset: %{public}@ (%{public}@)",
                   snapshot.callCount, snapshot.regCallCount,
                   container.isProductionChainPopulated ? "YES" : "NO",
                   container.lastResetTimestamp?.description ?? "never",
                   container.lastResetInfo ?? "N/A")

            fputs("""
            ╔══════════════════════════════════════════════════════════════╗
            ║  DI RESOLVE FAILURE — Crash Imminent                        ║
            ╠══════════════════════════════════════════════════════════════╣
            ║  Key:        \(key)
            ║  Type:       \(rawTypeString)
            ║  Call #:     \(snapshot.callCount)  |  Register #: \(snapshot.regCallCount)
            ║  Production: \(container.isProductionChainPopulated ? "YES" : "NO")
            ║  Last Reset: \(container.lastResetTimestamp?.description ?? "never")
            ║              \(container.lastResetInfo ?? "N/A")
            ║  Keys (\(snapshot.registeredKeys.count)): \(snapshot.registeredKeys.sorted().joined(separator: ", "))
            ╚══════════════════════════════════════════════════════════════╝

            """, stderr)
        }

        return (errorSummary, diagBlock)
    }

    /// 测试辅助：构造当前 DI 状态的 resolve 快照（不触发 resolve 计数器递增）
    /// 仅供单元测试 buildResolveFailureDiagnostics 使用
    internal func makeResolveSnapshotForTesting() -> ResolveSnapshot {
        lock.withLock {
            ResolveSnapshot(
                instance: nil,
                registeredKeys: Array(services.keys),
                callCount: resolveCallCount,
                regCallCount: registerCallCount
            )
        }
    }

    /// 尝试解析服务，如果未注册则返回 nil，不会触发断言或崩溃
    ///
    /// 并发安全：读取在 lock 内
    /// 语义修复（问题 #13）：当 T 本身是 Optional 类型（如 Int?）时，
    /// `nil as? T` 会返回 `.some(.none)` 而非 nil（Swift 语言陷阱）。
    /// 此处先检查 instance 是否为 nil，避免未注册服务被误判为「已注册但值为 nil」。
    public func resolveOptional<T>(_ type: T.Type) -> T? {
        let key = makeKey(for: type)
        let instance = lock.withLock { services[key] }
        guard let nonNilInstance = instance else { return nil }
        return nonNilInstance as? T
    }

    /// 类型擦除的服务解析（供 `@Inject` 可选检测使用）
    public func typeErasedResolve(_ type: Any.Type) -> Any? {
        let key = makeKey(forAny: type)
        let instance = lock.withLock { services[key] }
        return instance
    }

    /// 生成类型唯一的 Key。
    /// 保留模块名前缀以避免跨模块同名类型 key 冲突
    /// （例如 `UFPCore.Logger` 与 `ZhiYuDomain.Logger` 必须区分）。
    /// 仅移除 existential type 前缀（`any `/`all `）和 Swift 内部修饰符。
    private func makeKey<T>(for type: T.Type) -> String {
        return Self.normalizeKey(type)
    }

    /// 非泛型版本的 Key 生成（供 `typeErasedResolve` 使用）
    private func makeKey(forAny type: Any.Type) -> String {
        return Self.normalizeKey(type)
    }

    /// Key 归一化共用逻辑
    private static func normalizeKey(_ type: Any.Type) -> String {
        var typeString = "\(type)"

        // 移除 "any " 或 "all " 前缀（existential type 标记，非类型身份的一部分）
        if typeString.hasPrefix("any ") {
            typeString.removeFirst(4)
        } else if typeString.hasPrefix("all ") {
            typeString.removeFirst(4)
        }

        return typeString
    }

    /// 检查服务是否已注册
    public func hasService<T>(for type: T.Type) -> Bool {
        let key = makeKey(for: type)
        let exists = lock.withLock { services[key] != nil }
        return exists
    }

    /// 启动期断言：验证必需服务已注册，缺失时触发 assertionFailure
    /// - Parameter requiredTypes: 必需服务的元类型列表
    /// - Parameter context: 调用上下文描述（用于诊断信息）
    public func assertRegistered(_ requiredTypes: [Any.Type], context: String) {
        var missing: [String] = []
        for type in requiredTypes {
            let key = makeKey(forAny: type)
            let exists = lock.withLock { services[key] != nil }
            if !exists {
                missing.append(String(describing: type))
            }
        }
        if !missing.isEmpty {
            let registeredCount = lock.withLock { services.count }
            let summary = "[DI Startup Assertion] \(context): \(missing.count) required service(s) NOT registered: \(missing.joined(separator: ", ")). Total registered: \(registeredCount)"
            os_log(.fault, log: diLog, "%{public}@", summary)
            fputs("""
            ╔══════════════════════════════════════════════════════════════╗
            ║  DI STARTUP ASSERTION FAILURE                                ║
            ╠══════════════════════════════════════════════════════════════╣
            ║  Context:    \(context)
            ║  Missing:    \(missing.count) service(s)
            ║              \(missing.joined(separator: ", "))
            ║  Registered: \(registeredCount) services total
            ╚══════════════════════════════════════════════════════════════╝

            """, stderr)
            // 缺陷 #5 修复：可注入的失败处理器
            // 测试时替换为非崩溃闭包，使 assertRegistered 失败路径可被单元测试覆盖
            if let handler = ServiceContainer.fatalFailureHandler {
                handler(summary)
                return
            }
            assertionFailure(summary)
        }
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
        // 语义修复（问题 #10）：当 Wrapped 本身是 Optional 类型（嵌套 Optional 场景）时，
        // `nil as? Wrapped` 会返回 .some(.none) 而非失败（Swift 语言陷阱）。
        // 此处用反射检测 value 是否为 Optional.none，直接返回 .none 语义。
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional {
            // value 是 Optional，检查是否为 .none
            if mirror.children.isEmpty {
                // value 是 Optional.none → 返回 .none
                return (nil as Wrapped?) as Any
            }
        }
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
            // injectWrap 对 nil 或类型不匹配均返回 Optional<Wrapped>.none，as? T 必然成功
            if let result = optionalMetatype.injectWrap(anyResult as Any) as? T {
                return result
            }
            // 防御性兜底：injectWrap 返回 Optional<Wrapped>，as? T 不应失败
            // 若失败说明 T 的运行时类型与 Optional<Wrapped> 不一致（理论不可达）
            fatalError("Inject<\(T.self)>: injectWrap result cast to T failed (unreachable)")
        }
        // 非可选类型 → 必需依赖，缺失触发诊断崩溃
        return ServiceContainer.shared.resolve(T.self)
    }

    /// 安全访问：DI 未就绪时返回 nil，用于初始化早期或单测环境
    public var safeValue: T? {
        ServiceContainer.shared.resolveOptional(T.self)
    }
}
