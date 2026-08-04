# 架构技术债务修复 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 4 项架构技术债务：CI 主脚本缺失检查、`#if os` 正则漏洞、ServiceContainer 锁现代化、RouterProtocol 孤儿协议删除、audit-arch-dependency.py 白名单收紧。

**Architecture:** 4 个 Task 相互独立，可并行执行。Task 1 修复 CI 守卫网关（补齐 6 项缺失检查 + 正则漏洞）。Task 2 将 ServiceContainer 的 `os_unfair_lock` + `@unchecked Sendable` 升级为 `OSAllocatedUnfairLock`（两份副本同步）。Task 3 删除孤儿协议 RouterProtocol 及其死代码 `@Entry var router`。Task 4 收紧 audit-arch-dependency.py 白名单并新增 L0→L1.5 跨层引用拦截规则。

**Tech Stack:** Python 3（守卫脚本）、Swift 6（ServiceContainer/RouterProtocol）、Bash（CI 主脚本）。

## Global Constraints

- **语言**：所有注释使用简体中文（AGENTS.md 规范）。
- **L10n 红线**：禁止硬编码中文/ASCII 字符串到视图层（本计划不涉及视图层）。
- **架构分层**：L0→L1.5→L2→L3 单向依赖，底层禁止反向引用高层（AGENTS.md 红线 3）。
- **并发**：优先使用 `async/await` 和 `actor`；非 `Sendable` 单例 `static let shared` 标记 `nonisolated(unsafe)`（AGENTS.md）。但 ServiceContainer 因 `@Inject` 属性包装器要求同步访问，无法用 actor，采用 `OSAllocatedUnfairLock` 替代。
- **无魔法数字**：阈值常量抽取为命名常量（AGENTS.md 红线 4）。
- **测试**：每个 Task 完成后运行 `make test` 或对应 SPM 单测验证不回归。
- **提交规范**：`fix:` 前缀（AGENTS.md）。
- **pre-push 门禁**：9 项 hook 全过才能推送。

---

## Task 1: CI 主脚本补齐 6 项缺失检查 + `#if os` 正则漏洞修复

**背景**：`Tools/CI/run-code-static-analysis.sh` 当前 20 项检查（pid1-22 跳过 pid17），但 8 个守卫脚本中只有 2 个（`audit-arch-domain-purity.py`、`audit-arch-view-duplication.py`）已接入。6 个未接入脚本全部可独立运行且 exit code 正确。同时 `check-code-platform-macros.py:28` 正则 `#if\s+os\(` 不匹配 `#if !os(` 形式，导致 **30 处 Features 层 `#if !os(` 违规漏检**（违反 AGENTS.md 红线 3）。

**Files:**
- Modify: `Tools/ios/check-code-platform-macros.py:28`（正则修复）
- Modify: `Tools/CI/run-code-static-analysis.sh:56-99`（补齐 6 项检查 + wait 收拢）

**Interfaces:**
- Consumes: 6 个已存在守卫脚本（`check-code-platform-macros.py` / `check-arch-opensource-adapters.py` / `audit-code-magic-strings.py` / `check-code-file-headers.py` / `check-arch-di-registration.py` / `check-code-inject-safety.py`）
- Produces: CI 主脚本 26 项检查（原 20 + 新 6），`#if !os(` 违规可被拦截

- [ ] **Step 1: 修复 `check-code-platform-macros.py` 正则漏洞**

修改 `Tools/ios/check-code-platform-macros.py:28`，将单正则替换为 3 正则列表（与 `audit-arch-domain-purity.py:24-28` 对齐）：

```python
# 拦截平台条件编译宏的正则表达式（覆盖 #if os / #if !os / #elseif os 三种形式）
OS_MACRO_PATTERNS = [
    re.compile(r'#if\s+os\('),
    re.compile(r'#if\s+!os\('),
    re.compile(r'#elseif\s+os\('),
]
```

- [ ] **Step 2: 更新 `check-code-platform-macros.py` 扫描逻辑使用新正则列表**

修改 `Tools/ios/check-code-platform-macros.py:46`（`_scan_directory` 函数内的 `if OS_MACRO_PATTERN.search(line):`），替换为遍历 3 正则：

```python
        for swift_file in check_dir.rglob("*.swift"):
            violations = []
            try:
                with open(swift_file, 'r') as f:
                    for i, line in enumerate(f, 1):
                        for pattern in OS_MACRO_PATTERNS:
                            if pattern.search(line):
                                violations.append((i, line.strip()))
                                break  # 同一行不重复记录
            except Exception:
                pass
            if violations:
                rel_path = swift_file.relative_to(PROJECT_ROOT)
                results.append((rel_path, violations))
```

- [ ] **Step 3: 验证正则修复后脚本能检测 `#if !os(` 违规**

Run: `python3 Tools/ios/check-code-platform-macros.py > /dev/null 2>&1; echo "exit=$?"`
Expected: `exit=1`（检测到 30+ 处违规）

- [ ] **Step 4: 在 CI 主脚本中补齐 6 项缺失检查**

修改 `Tools/CI/run-code-static-analysis.sh`，在现有 `run_parallel_task` 块（第 56-76 行）末尾（`pid22` 之后）新增 6 行：

```bash
run_parallel_task "Platform Macros Guard" "platform_macros" "python3 Tools/ios/check-code-platform-macros.py" & pid23=$!
run_parallel_task "Open-Source Adapters" "opensource_adapters" "python3 Tools/ios/check-arch-opensource-adapters.py" & pid24=$!
run_parallel_task "Magic Strings Audit" "magic_strings" "python3 Tools/ios/audit-code-magic-strings.py" & pid25=$!
run_parallel_task "File Headers" "file_headers" "python3 Tools/ios/check-code-file-headers.py" & pid26=$!
run_parallel_task "DI Registration" "di_registration" "python3 Tools/ios/check-arch-di-registration.py" & pid27=$!
run_parallel_task "Inject Safety" "inject_safety" "python3 Tools/ios/check-code-inject-safety.py --strict" & pid28=$!
```

> **注意**：`check-code-inject-safety.py` 必须加 `--strict` 参数，否则非严格模式只警告不阻断（脚本提示语：`运行 python3 Tools/ios/check-code-inject-safety.py --strict 以在 CI 中断构建`）。

- [ ] **Step 5: 在 CI 主脚本 wait 收拢区新增 6 行**

修改 `Tools/CI/run-code-static-analysis.sh:99`（`wait $pid22 || EXIT_CODE=1` 之后），新增：

```bash
wait $pid23 || EXIT_CODE=1
wait $pid24 || EXIT_CODE=1
wait $pid25 || EXIT_CODE=1
wait $pid26 || EXIT_CODE=1
wait $pid27 || EXIT_CODE=1
wait $pid28 || EXIT_CODE=1
```

- [ ] **Step 6: 验证 CI 主脚本语法正确**

Run: `bash -n Tools/CI/run-code-static-analysis.sh; echo "exit=$?"`
Expected: `exit=0`（语法无误）

- [ ] **Step 7: 运行 `check-code-inject-safety.py --strict` 确认当前状态**

Run: `python3 Tools/ios/check-code-inject-safety.py --strict > /dev/null 2>&1; echo "exit=$?"`
Expected: `exit=1`（37 处 HIGH 级发现，需人工审核后修复或加白名单）

> **说明**：本 Task 只负责接入检查脚本，不负责修复 37 处 HIGH 级 inject safety 违规。接入后 CI 会熔断，需在后续 Task 或独立 Task 中处理。**如果用户希望暂不阻断 CI，可先不加 `--strict`，但需在计划中标注为已知债务。**

- [ ] **Step 8: 运行 `check-arch-di-registration.py` 确认当前状态**

Run: `python3 Tools/ios/check-arch-di-registration.py > /dev/null 2>&1; echo "exit=$?"`
Expected: `exit=1`（1 个未注册的 @Inject 依赖类型）

> **说明**：同 Step 7，接入后 CI 会熔断，需修复未注册依赖或加白名单。

- [ ] **Step 9: 提交 Task 1**

```bash
git add Tools/ios/check-code-platform-macros.py Tools/CI/run-code-static-analysis.sh
git commit -m "fix: 补齐 CI 主脚本 6 项缺失检查并修复 #if os 正则漏洞

- check-code-platform-macros.py 正则新增 #if !os( 和 #elseif os( 匹配
- run-code-static-analysis.sh 接入 6 项守卫脚本（pid23-28）
- 修复 30 处 Features 层 #if !os( 违规漏检（AGENTS.md 红线 3）"
```

---

## Task 2: ServiceContainer 锁现代化（OSAllocatedUnfairLock）

**背景**：`ServiceContainer` 使用 `UnsafeMutablePointer<os_unfair_lock>` + 手动 `os_unfair_lock_lock/unlock` + `@unchecked Sendable`，违反 AGENTS.md 并发规范（"绝不使用锁或信号量"）。8 处加锁点分散在 `register`/`resolve`/`resolveOptional`/`typeErasedResolve`/`hasService`/`optionalResolve`/`reset`/`diagnosticSnapshot`/`markProductionChainComplete`。`@Inject` 属性包装器要求同步访问（`wrappedValue` 非 async），无法用 actor。采用 `OSAllocatedUnfairLock`（Swift 5.9+，封装 `os_unfair_lock`，Sendable，无需 `@unchecked`）。

**两份副本需同步修改**：
- `Sources/Core/Base/ServiceContainer.swift`（332 行，internal）
- `Packages/UFPCore/Sources/UFPCore/Base/ServiceContainer.swift`（316 行，public）

**Files:**
- Modify: `Sources/Core/Base/ServiceContainer.swift:13-49,55-64,70-117,120-186,189-258`
- Modify: `Packages/UFPCore/Sources/UFPCore/Base/ServiceContainer.swift:13-49,55-64,70-117,120-186,189-258`

**Interfaces:**
- Consumes: `OSAllocatedUnfairLock`（Swift 5.9+，`import os`）
- Produces: ServiceContainer API 不变（`register`/`resolve`/`resolveOptional`/`typeErasedResolve`/`hasService`/`optionalResolve`/`reset`/`diagnosticSnapshot`/`markProductionChainComplete`/`isReady`/`isProductionChainLocked` 签名完全保留），292 处 `@Inject` 调用点零改动

- [ ] **Step 1: 编写 ServiceContainer 锁现代化单元测试（TDD）**

创建 `Tests/Unit/Core/ServiceContainerLockTests.swift`：

```swift
import XCTest
@testable import ZhiYu

/// ServiceContainer 锁现代化回归测试
/// 验证 OSAllocatedUnfairLock 迁移后并发安全与 API 兼容性
final class ServiceContainerLockTests: XCTestCase {

    /// 测试并发 register 不崩溃且最终可 resolve
    func testConcurrentRegisterAndResolve() {
        let container = ServiceContainer.shared
        // 使用测试专用协议，避免污染生产注册表
        protocol TestLockServiceProtocol {}
        struct TestLockService: TestLockServiceProtocol {}

        // 并发注册 100 次（同一 key 覆盖）
        let expectations = (0..<100).map { i in
            XCTestExpectation(description: "register-\(i)")
        }
        for i in 0..<100 {
            DispatchQueue.global().async {
                container.register(TestLockService() as any TestLockServiceProtocol, for: (any TestLockServiceProtocol).self)
                expectations[i].fulfill()
            }
        }
        wait(for: expectations, timeout: 5.0)

        // 并发 resolve 不崩溃
        let resolveExpectations = (0..<100).map { i in
            XCTestExpectation(description: "resolve-\(i)")
        }
        for i in 0..<100 {
            DispatchQueue.global().async {
                _ = container.resolveOptional((any TestLockServiceProtocol).self)
                resolveExpectations[i].fulfill()
            }
        }
        wait(for: resolveExpectations, timeout: 5.0)
    }

    /// 测试 diagnosticSnapshot 并发访问安全
    func testConcurrentDiagnosticSnapshot() {
        let container = ServiceContainer.shared
        let expectations = (0..<50).map { i in
            XCTestExpectation(description: "snapshot-\(i)")
        }
        for i in 0..<50 {
            DispatchQueue.global().async {
                _ = container.diagnosticSnapshot
                expectations[i].fulfill()
            }
        }
        wait(for: expectations, timeout: 5.0)
    }

    /// 测试 hasService 并发访问安全
    func testConcurrentHasService() {
        let container = ServiceContainer.shared
        let expectations = (0..<50).map { i in
            XCTestExpectation(description: "has-\(i)")
        }
        for i in 0..<50 {
            DispatchQueue.global().async {
                _ = container.hasService(for: (any TestLockServiceProtocol).self)
                expectations[i].fulfill()
            }
        }
        wait(for: expectations, timeout: 5.0)
    }
}
```

- [ ] **Step 2: 运行测试验证它编译通过（此时应 PASS，因为旧锁实现功能正确）**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/ServiceContainerLockTests 2>&1 | tail -20`
Expected: 3 个测试全 PASS（验证旧实现功能正确，为迁移后回归对比建立基线）

- [ ] **Step 3: 修改 `Sources/Core/Base/ServiceContainer.swift` 锁声明与初始化**

修改 `Sources/Core/Base/ServiceContainer.swift:13-49`，替换锁声明：

```swift
import Foundation
import os

// MARK: - DI 诊断专用日志子系统
private let diLog = OSLog(subsystem: "com.zhiyu.app", category: "DI-Container")

/// 依赖注入容器 (L2 层：解耦中枢)
/// 遵循 Service Locator 模式，支持 Mock 替换 (@SR-04: 受权限管控的插件访问基础)
final class ServiceContainer: @unchecked Sendable {
    /// 全局单例
    static let shared = ServiceContainer()

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

    private init() {}

    // 注：OSAllocatedUnfairLock 无需 deinit 释放（值类型自动管理）
```

> **关键变更**：
> - 删除 `lockPointer: UnsafeMutablePointer<os_unfair_lock>` 声明
> - 新增 `lock = OSAllocatedUnfairLock()`
> - 删除 `init()` 中的 `lockPointer.allocate/initialize`
> - 删除 `deinit` 中的 `lockPointer.deallocate`
> - 保留 `@unchecked Sendable`（因 `services`/`resolveCallCount` 等可变状态仍需通过锁保护，Sendable 推断无法自动满足）

- [ ] **Step 4: 修改 `Sources/Core/Base/ServiceContainer.swift` register 方法**

修改 `Sources/Core/Base/ServiceContainer.swift:55-64`：

```swift
    /// 注册服务
    /// - Parameters:
    ///   - service: 服务实例
    ///   - type: 服务的协议或类类型
    func register<T>(_ service: T, for type: T.Type) {
        let key = makeKey(for: type)
        lock.withLock {
            services[key] = service
            registerCallCount += 1
        }
        #if DEBUG
        Logger.shared.debug("DI: Registered [\(key)] with instance \(String(describing: service))")
        #endif
    }
```

- [ ] **Step 5: 修改 `Sources/Core/Base/ServiceContainer.swift` markProductionChainComplete 方法**

修改 `Sources/Core/Base/ServiceContainer.swift:70-80`：

```swift
    /// 标记生产链已完成，禁止 reset() 清空 / 标记 DI 生命周期就绪
    func markProductionChainComplete() {
        isProductionChainPopulated = true
        // 记录生产链完成时的诊断快照
        let info = lock.withLock { () -> String in
            let keyCount = services.count
            let allKeys = Array(services.keys)
            return "[ServiceContainer] Production DI chain complete. Registered services: \(keyCount). Keys: \(allKeys.sorted().joined(separator: ", "))"
        }
        os_log(.info, log: diLog, "%{public}@", info)
        Logger.shared.info(info)
    }
```

- [ ] **Step 6: 修改 `Sources/Core/Base/ServiceContainer.swift` diagnosticSnapshot 属性**

修改 `Sources/Core/Base/ServiceContainer.swift:90-97`：

```swift
    /// 诊断属性：当前注册表快照
    var diagnosticSnapshot: [String: Bool] {
        let keys = lock.withLock { Array(services.keys) }
        var snapshot: [String: Bool] = [:]
        for key in keys { snapshot[key] = true }
        return snapshot
    }
```

- [ ] **Step 7: 修改 `Sources/Core/Base/ServiceContainer.swift` reset 方法**

修改 `Sources/Core/Base/ServiceContainer.swift:101-117`：

```swift
    /// 重置所有服务（主要用于测试环境隔离）
    /// 生产注册链完成后调用此方法无效果，防止测试误清导致 @Inject 崩溃
    func reset() {
        let callSite = Thread.callStackSymbols.prefix(5).joined(separator: "\n")
        guard !isProductionChainPopulated else {
            let msg = "[ServiceContainer] reset() BLOCKED: production DI chain is complete. Call site:\n\(callSite)"
            os_log(.error, log: diLog, "%{public}@", msg)
            Logger.shared.warning(msg)
            return
        }
        let (removedCount, removedKeys) = lock.withLock { () -> (Int, [String]) in
            let count = services.count
            let keys = Array(services.keys)
            services.removeAll()
            return (count, keys)
        }
        lastResetInfo = "Removed \(removedCount) services: \(removedKeys.sorted().joined(separator: ", "))"
        lastResetTimestamp = Date()
        os_log(.info, log: diLog, "%{public}@", "[ServiceContainer] reset() executed. \(lastResetInfo ?? "N/A")")
    }
```

- [ ] **Step 8: 修改 `Sources/Core/Base/ServiceContainer.swift` resolve 方法**

修改 `Sources/Core/Base/ServiceContainer.swift:120-177`（只改加锁部分，诊断输出逻辑不变）：

```swift
    /// 解析服务
    func resolve<T>(_ type: T.Type) -> T {
        let key = makeKey(for: type)

        // 单次加锁：同时读取实例和诊断信息，消除两次加锁间的竞态窗口
        let (instance, registeredKeys, callCount, regCallCount) = lock.withLock { () -> (Any?, [String], Int, Int) in
            let instance = services[key]
            let registeredKeys = Array(services.keys)
            let callCount = resolveCallCount
            resolveCallCount += 1
            let regCallCount = registerCallCount
            return (instance, registeredKeys, callCount, regCallCount)
        }

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
```

- [ ] **Step 9: 修改 `Sources/Core/Base/ServiceContainer.swift` resolveOptional / typeErasedResolve / hasService / optionalResolve**

修改 `Sources/Core/Base/ServiceContainer.swift:180-258`：

```swift
    /// 尝试解析服务，如果未注册则返回 nil，不会触发断言或崩溃
    func resolveOptional<T>(_ type: T.Type) -> T? {
        let key = makeKey(for: type)
        let instance = lock.withLock { services[key] }
        return instance as? T
    }

    /// 类型擦除的服务解析（供 `@Inject` 可选检测使用）
    func typeErasedResolve(_ type: Any.Type) -> Any? {
        let key = makeKey(forAny: type)
        let instance = lock.withLock { services[key] }
        return instance
    }
```

（`makeKey` 方法不变，保留原样）

```swift
    /// 检查服务是否已注册
    func hasService<T>(for type: T.Type) -> Bool {
        let key = makeKey(for: type)
        let exists = lock.withLock { services[key] != nil }
        return exists
    }

    /// 安全解析服务，未注册时返回 nil（不 fatalError）
    func optionalResolve<T>(_ type: T.Type) -> T? {
        let key = makeKey(for: type)
        let service = lock.withLock { services[key] }
        return service as? T
    }
```

- [ ] **Step 10: 同步修改 `Packages/UFPCore/Sources/UFPCore/Base/ServiceContainer.swift`**

对 SPM 包副本执行与 Step 3-9 完全相同的修改，区别仅是 `public` 修饰符（原文件已有 `public`，保留）。具体改动点：

1. 锁声明：`private let lock = OSAllocatedUnfairLock()`（替换 `lockPointer`）
2. `init()` 清空（删除 allocate/initialize）
3. 删除 `deinit`
4. `register`：`lock.withLock { ... }`
5. `markProductionChainComplete`：`lock.withLock { ... }`
6. `diagnosticSnapshot`：`lock.withLock { ... }`
7. `reset`：`lock.withLock { ... }`
8. `resolve`：`lock.withLock { ... }`（返回元组）
9. `resolveOptional`/`typeErasedResolve`/`hasService`/`optionalResolve`：`lock.withLock { ... }`

> **关键**：SPM 包副本的 `public` 修饰符全部保留，API 签名不变。

- [ ] **Step 11: 运行 ServiceContainerLockTests 验证迁移后并发安全**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/ServiceContainerLockTests 2>&1 | tail -20`
Expected: 3 个测试全 PASS

- [ ] **Step 12: 运行全量主 App 单元测试验证无回归**

Run: `make test 2>&1 | tail -30`
Expected: 全部 PASS（292 处 @Inject 调用点零改动，API 完全兼容）

- [ ] **Step 13: 运行 UFPCore SPM 单测验证包副本无回归**

Run: `make test-spm PKG=UFPCore 2>&1 | tail -20`
Expected: 全部 PASS

- [ ] **Step 14: 提交 Task 2**

```bash
git add Sources/Core/Base/ServiceContainer.swift Packages/UFPCore/Sources/UFPCore/Base/ServiceContainer.swift Tests/Unit/Core/ServiceContainerLockTests.swift
git commit -m "fix: ServiceContainer 锁现代化为 OSAllocatedUnfairLock

- 替换 UnsafeMutablePointer<os_unfair_lock> 为 OSAllocatedUnfairLock
- 8 处加锁点统一为 lock.withLock { } 闭包风格
- 删除手动 allocate/deallocate/init 代码
- 两份副本（Sources/Core + Packages/UFPCore）同步修改
- 新增 ServiceContainerLockTests 并发回归测试
- API 完全兼容，292 处 @Inject 调用点零改动"
```

---

## Task 3: RouterProtocol 孤儿协议删除

**背景**：`RouterProtocol` 是孤儿协议——`Router` 类未遵循它（`Sources/App/Navigation/Router.swift:159` `final class Router {` 无 `: RouterProtocol`），全代码库无任何类遵循它，只有 `RouterProtocol.swift:77` 的 `@Entry var router: any RouterProtocol` 自我引用。所有视图使用 `@Environment(Router.self)`（具体类型），**无任何视图使用 `@Environment(\.router)`**（EnvironmentValues 路径）。`RouterProtocol` 还违反 AGENTS.md 红线 3（L0 协议引用 L3 类型 `SidebarSelection`/`AppRoute` + `import SwiftUI`）。

**Files:**
- Delete: `Sources/Core/Base/Protocols/RouterProtocol.swift`（整个文件，79 行）
- Verify: `Sources/App/Navigation/Router.swift`（无需修改，Router 类本就未遵循 RouterProtocol）

**Interfaces:**
- Consumes: 无（RouterProtocol 无任何消费者）
- Produces: 删除死代码，消除 L0→L3 跨层引用

- [ ] **Step 1: 编写删除前验证测试（确认无代码依赖 RouterProtocol）**

创建 `Tests/Unit/Core/RouterProtocolDeletionTests.swift`：

```swift
import XCTest
@testable import ZhiYu

/// RouterProtocol 删除前验证测试
/// 确认删除孤儿协议后编译通过、Router 功能不受影响
final class RouterProtocolDeletionTests: XCTestCase {

    /// 测试 Router 单例可正常访问（不依赖 RouterProtocol）
    func testRouterSharedAccessible() {
        let router = Router.shared
        XCTAssertNotNil(router)
    }

    /// 测试 Router path 属性可读写（不依赖 RouterProtocol）
    func testRouterPathAccessible() {
        let router = Router.shared
        let initialCount = router.path.count
        router.path.append(AppRoute.pageDetail(id: UUID()))
        XCTAssertEqual(router.path.count, initialCount + 1)
        router.path.removeLast()
        XCTAssertEqual(router.path.count, initialCount)
    }

    /// 测试 Router sidebarSelection 属性可读写（不依赖 RouterProtocol）
    func testRouterSidebarSelectionAccessible() {
        let router = Router.shared
        router.sidebarSelection = nil
        XCTAssertNil(router.sidebarSelection)
    }
}
```

- [ ] **Step 2: 运行测试验证它编译通过（删除前基线）**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/RouterProtocolDeletionTests 2>&1 | tail -20`
Expected: 3 个测试全 PASS

- [ ] **Step 3: 删除 `Sources/Core/Base/Protocols/RouterProtocol.swift` 整个文件**

Run: `rm Sources/Core/Base/Protocols/RouterProtocol.swift`

- [ ] **Step 4: 验证编译通过（确认无任何代码引用 RouterProtocol）**

Run: `xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'generic/platform=iOS' 2>&1 | tail -10`
Expected: BUILD SUCCEEDED（证明 RouterProtocol 确实是孤儿协议）

> **如果编译失败**：说明有代码引用 RouterProtocol，需先修复引用再删除。根据调研，唯一引用点是 `@Entry var router`，删除文件即一并删除。

- [ ] **Step 5: 运行 RouterProtocolDeletionTests 验证删除后功能正常**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/RouterProtocolDeletionTests 2>&1 | tail -20`
Expected: 3 个测试全 PASS

- [ ] **Step 6: 运行全量主 App 单元测试验证无回归**

Run: `make test 2>&1 | tail -30`
Expected: 全部 PASS

- [ ] **Step 7: 提交 Task 3**

```bash
git add -A Sources/Core/Base/Protocols/RouterProtocol.swift Tests/Unit/Core/RouterProtocolDeletionTests.swift
git commit -m "fix: 删除孤儿协议 RouterProtocol 及死代码 @Entry var router

- RouterProtocol 是孤儿协议：Router 类未遵循它，全代码库无消费者
- 所有视图使用 @Environment(Router.self) 具体类型，无视图使用 @Environment(\\.router)
- 消除 L0 协议引用 L3 类型 (SidebarSelection/AppRoute) 的跨层违规 (AGENTS.md 红线 3)
- 消除 L0 协议 import SwiftUI 的跨层违规
- 新增 RouterProtocolDeletionTests 回归测试"
```

---

## Task 4: audit-arch-dependency.py 白名单收紧 + L0→L1.5 跨层引用拦截

**背景**：`audit-arch-dependency.py:58-67` 的 `COMMON_KEYWORDS` 白名单过宽，豁免了 9 个领域实体（`PageChunk`/`KnowledgePage`/`LintIssue`/`PotentialLinkSuggestion`/`Tag`/`OnDeviceModel`/`PDFDocumentInfo`/`VoiceRecording`/`Ingest`），导致 L0→L1.5 跨层引用未拦截。同时 `forbidden_rules["Core"]` 当前只禁止 `high_level_ui_entities ∪ domain_services_entities ∪ infra_entities`，但**不禁止 `domain_models_entities`**（L0 可以引用 L1.5 Models），这是架构违规——L0 应禁止引用所有 L1.5 实体（Models + Services）。

**Files:**
- Modify: `Tools/ios/audit-arch-dependency.py:58-67`（白名单收紧）
- Modify: `Tools/ios/audit-arch-dependency.py:250-257`（forbidden_rules Core 层新增 domain_models_entities）

**Interfaces:**
- Consumes: 无
- Produces: audit-arch-dependency.py 能拦截 L0→L1.5 跨层引用（Models + Services）

- [ ] **Step 1: 编写白名单收紧后的预期违规清单测试**

创建 `Tests/Tools/test_audit_arch_dependency_whitelist.py`：

```python
#!/usr/bin/env python3
"""audit-arch-dependency.py 白名单收紧后的回归测试"""
import subprocess
import sys
import os

PROJECT_ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

def test_whitelist_excludes_domain_entities():
    """验证 COMMON_KEYWORDS 不再豁免领域实体"""
    sys.path.insert(0, os.path.join(PROJECT_ROOT, "Tools", "ios"))
    import audit_arch_dependency
    
    domain_entities_in_whitelist = [
        name for name in audit_arch_dependency.COMMON_KEYWORDS
        if name in {"PageChunk", "KnowledgePage", "LintIssue", "PotentialLinkSuggestion",
                    "Tag", "OnDeviceModel", "PDFDocumentInfo", "VoiceRecording", "Ingest"}
    ]
    assert len(domain_entities_in_whitelist) == 0, \
        f"COMMON_KEYWORDS 仍豁免领域实体: {domain_entities_in_whitelist}"

def test_core_forbidden_includes_domain_models():
    """验证 Core 层 forbidden_rules 包含 domain_models_entities"""
    # 此测试需在 run_architecture_audit 执行后验证，这里只检查配置
    sys.path.insert(0, os.path.join(PROJECT_ROOT, "Tools", "ios"))
    import audit_arch_dependency
    
    # 重新提取 domain_models_entities
    domain_models_dir = os.path.join(audit_arch_dependency.LAYER_PATHS["Domain"], "Models")
    domain_models_entities = audit_arch_dependency.extract_entities_from_dir(domain_models_dir)
    
    # 模拟 forbidden_rules 构建逻辑
    # 预期 Core 层应禁止 domain_models_entities
    # 此测试在 Step 4 修改后才会 PASS
    assert len(domain_models_entities) > 0, "Domain Models 实体提取为空"

if __name__ == "__main__":
    test_whitelist_excludes_domain_entities()
    test_core_forbidden_includes_domain_models()
    print("✅ 白名单回归测试通过")
```

- [ ] **Step 2: 运行测试验证它当前 FAIL（白名单仍豁免领域实体）**

Run: `python3 Tests/Tools/test_audit_arch_dependency_whitelist.py 2>&1; echo "exit=$?"`
Expected: `exit=1`（AssertionError: COMMON_KEYWORDS 仍豁免领域实体）

- [ ] **Step 3: 收紧 `audit-arch-dependency.py` 白名单**

修改 `Tools/ios/audit-arch-dependency.py:58-67`，删除 9 个领域实体：

```python
# 忽略提取的通用 Swift 关键字与常见类型名（避免因同名匹配造成误报）
# 注意：领域实体（PageChunk/KnowledgePage/Tag 等）不在此白名单中，
# 以便 audit-arch-dependency 能拦截 L0→L1.5 跨层引用
COMMON_KEYWORDS = {
    "View", "Text", "Button", "Label", "Image", "String", "Int", "Double", "CGFloat",
    "Bool", "UUID", "URL", "Task", "Color", "Font", "Spacer", "ZStack", "VStack", "HStack",
    "ForEach", "EmptyView", "Binding", "Environment", "State", "Observable", "MainActor",
    "App", "Scene", "Widget", "Capsule", "Circle", "Rectangle", "RoundedRectangle", "Empty",
    "Done", "User", "Plan", "Theme", "Error", "Log", "Logger", "Date", "Data",
    "Status", "Columns", "CodingKeys"
}
```

> **删除的 9 个实体**：`Ingest`、`LLMProvider`、`VoiceRecording`、`PDFDocumentInfo`、`OnDeviceModel`、`PageChunk`、`KnowledgePage`、`LintIssue`、`PotentialLinkSuggestion`、`Tag`。
> **保留**：`LLMProvider` 也删除（它是 L1.5/L2 实体，不应在白名单）。

- [ ] **Step 4: 修改 `forbidden_rules` Core 层新增 domain_models_entities**

修改 `Tools/ios/audit-arch-dependency.py:250-257`：

```python
    # 2. 定义各层不应该引用的实体名单
    # Core (L0) 严禁调用任何高层实体：UI 视图、Domain Services、Domain Models、Infrastructure
    # 架构红线：L0 底座层禁止反向引用 L1.5 领域层（含 Models 和 Services）
    forbidden_rules = {
        # Core (L0) 禁止调用高层 UI 视图、底层具体 Infra，以及 Domain 层全部实体（Models + Services）
        "Core": high_level_ui_entities.union(domain_all_entities).union(infra_entities),
        # Infrastructure (L1) 禁止直接调用表现层 UI
        "Infrastructure": high_level_ui_entities,
        # Domain (L1.5) 作为大脑层，可以调用 Infra 和 Core，但绝对禁止直接调用表现层 UI (View/Coordinator)
        "Domain": high_level_ui_entities
    }
```

> **关键变更**：`domain_services_entities` 替换为 `domain_all_entities`（Models + Services 全部禁止）。

- [ ] **Step 5: 运行白名单回归测试验证 PASS**

Run: `python3 Tests/Tools/test_audit_arch_dependency_whitelist.py 2>&1; echo "exit=$?"`
Expected: `exit=0`（`✅ 白名单回归测试通过`）

- [ ] **Step 6: 运行 audit-arch-dependency.py 查看当前违规数**

Run: `python3 Tools/ios/audit-arch-dependency.py 2>&1 | tail -10; echo "exit=$?"`
Expected: `exit=1`（检测到 L0→L1.5 跨层引用违规，违规数 > 0）

> **说明**：根据调研，L0 协议有 50+ 处引用 `KnowledgePage`/`PageChunk` 等 L1.5 类型。本 Task 只负责收紧白名单和新增拦截规则，不负责修复 50+ 处违规。**接入后 CI 会熔断，需在后续独立 Task 中处理 L0→L1.5 跨层引用（将 L1.5 Models 下移到 L0，或将 L0 协议上移到 L1.5）。**

- [ ] **Step 7: 提交 Task 4**

```bash
git add Tools/ios/audit-arch-dependency.py Tests/Tools/test_audit_arch_dependency_whitelist.py
git commit -m "fix: 收紧 audit-arch-dependency 白名单并拦截 L0→L1.5 跨层引用

- COMMON_KEYWORDS 删除 9 个领域实体（PageChunk/KnowledgePage/Tag 等）
- forbidden_rules Core 层从 domain_services_entities 扩展为 domain_all_entities
- 新增 L0→L1.5 Models 跨层引用拦截（AGENTS.md 红线 3）
- 新增白名单回归测试 test_audit_arch_dependency_whitelist.py"
```

---

## Self-Review

### 1. Spec 覆盖

| 调研发现 | 对应 Task |
|---------|----------|
| CI 主脚本缺失 6 项检查 | Task 1 Step 4-5 |
| `#if os` 正则不匹配 `#if !os(` | Task 1 Step 1-2 |
| ServiceContainer 8 处 os_unfair_lock | Task 2 Step 3-9 |
| ServiceContainer 两份副本需同步 | Task 2 Step 10 |
| RouterProtocol 孤儿协议 | Task 3 Step 3 |
| RouterProtocol `@Entry var router` 死代码 | Task 3 Step 3（删除文件一并删除） |
| audit-arch-dependency 白名单过宽 | Task 4 Step 3 |
| L0→L1.5 跨层引用未拦截 | Task 4 Step 4 |

### 2. 占位符扫描

- 无 "TBD"/"TODO"/"implement later"
- 无 "Add appropriate error handling"
- 所有代码步骤含完整代码块
- 所有命令含 expected output

### 3. 类型一致性

- `OSAllocatedUnfairLock` 在 Step 3-10 一致使用
- `lock.withLock { }` 闭包风格在所有 8 处加锁点一致
- `domain_all_entities` 在 Step 4 与 Step 6 一致
- `COMMON_KEYWORDS` 在 Step 3 与测试 Step 1 一致

### 4. 已知债务（本计划不修复，标注供后续 Task 处理）

- **30 处 Features 层 `#if !os(` 违规**：Task 1 接入检查后 CI 会熔断，需独立 Task 修复（通过 PlatformRegistrar DI 注入替代）
- **37 处 HIGH 级 inject safety 违规**：Task 1 Step 7 接入 `--strict` 后 CI 会熔断，需独立 Task 修复
- **1 个未注册 @Inject 依赖**：Task 1 Step 8 接入后 CI 会熔断，需独立 Task 修复
- **50+ 处 L0→L1.5 跨层引用**：Task 4 收紧白名单后 CI 会熔断，需独立 Task 修复（L1.5 Models 下移 L0 或 L0 协议上移 L1.5）
- **Security 模块 4 文件 NSLock 使用**：本计划未涵盖，需独立 Task 处理

> **重要提示**：Task 1 和 Task 4 完成后 CI 会立即熔断（因检测到既有违规）。这是预期行为——熔断即说明守卫生效。需在后续独立 Task 中逐项修复违规。如果用户希望 CI 暂不熔断，可先合并 Task 2 和 Task 3（不引入新熔断），Task 1 和 Task 4 待违规修复后再合并。

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-08-04-arch-debt-fixes.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
