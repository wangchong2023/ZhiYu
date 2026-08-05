# UFPCore 测试驱动问题发现报告

> **方法论**：采用业界最佳实践（等价类划分、边界值分析、决策表）设计测试用例，**以发现问题为目的**，不追求覆盖率数字。
>
> **日期**：2026-08-05
> **分析对象**：`Packages/UFPCore/Sources/UFPCore/Base/ServiceContainer.swift`（401 行）
> **当前覆盖率**：语句 90.14%（42/51 函数覆盖），`ServiceContainer.swift` 89.63%

## 问题清单

> **列说明**：
> - **黑盒业务现象**：从用户/调用方视角观察到的现象（不涉及代码内部机制）
> - **业务影响**：对产品功能、稳定性、安全性的实际影响
> - **是否解决**：✅ 已解决 / ⏳ 修复中 / ❌ 未解决
> - **解决方案**：实际采用的修复方案（修复后填写）

| # | 严重度 | 文件:行 | 问题分类 | 问题描述 | 黑盒业务现象 | 业务影响 | 复现/验证 | 是否解决 | 解决方案 |
|---|--------|---------|----------|----------|--------------|----------|-----------|----------|----------|
| 1 | 🔴 严重 | `ServiceContainer.swift:397-399` | 未定义行为 / 必崩 Bug | `optionalNoneSentinel` 使用 `unsafeBitCast(Bool?.none, to: T.self)` 将 `Bool?`（2 字节）强转为任意 `T`（如 `String?` 24 字节）。`unsafeBitCast` 要求源/目标类型大小一致，否则触发 `Fatal error: Can't unsafeBitCast between types of different sizes` 必然崩溃。当 `@Inject var x: String?` 且 `String` 未注册时，`wrappedValue` 走 383 行 `return Inject<T>.optionalNoneSentinel`，**必然崩溃**。 | 任何使用 `@Inject var x: String?`（或 `Int?`/`Double?`/`Data?` 等大小不同于 `Bool?` 的值类型 Optional）的视图/服务，在依赖未注册时**应用立即崩溃**，无任何恢复机会。现象为：启动时或导航到某页面时 App 突然闪退，控制台输出 `Fatal error: Can't unsafeBitCast between types of different sizes`。 | **P0 级生产事故**：① 任何可选依赖在 DI 未就绪的早期启动阶段（如 `AppEnvironment` 初始化顺序错误、模块注册器漏注册）必然崩溃，用户看到闪退；② 违反 `@Inject` 的"可选依赖未注册返回 nil"契约，调用方无法用 `if let` 安全降级；③ 崩溃发生在属性包装器 getter，无法被 `do-catch` 捕获，无法恢复；④ 测试环境任何遗漏注册的可选依赖测试用例都会崩溃，阻塞测试运行。 | 已验证：`unsafeBitCast(Bool?.none, to: String?.self)` → `Fatal error: Can't unsafeBitCast between types of different sizes`（见下方验证日志） | ✅ 已解决 | 删除 `optionalNoneSentinel` 属性（397-400 行）。`wrappedValue` 的 Optional 分支改为：`injectWrap(anyResult)` 已能安全构造 `Optional<Wrapped>.none`（nil 或类型不匹配时），`as? T` 转型必然成功，删除 383 行的 `optionalNoneSentinel` fallback，改为 `fatalError` 防御性兜底（理论不可达）。新增 11 个值类型 Optional 回归测试（`InjectValueOptionalTests.swift`）全部通过。 |
| 2 | 🟡 中等 | `ServiceContainer.swift:287-296` | 死代码 / 错误假设 | `normalizeKey` 的 `(unknown context at $xxx)` 分支基于错误假设：假设**类型描述**（`String(describing: Type.self)`）含此前缀。但实际只有**实例描述**（`String(describing: instance)`）含此前缀，类型描述输出纯类型名（如 `DummyService`）。此分支**永远不会被触发**，是死代码。 | 无直接业务现象（死代码不执行）。但维护者若基于此分支的"保护"假设，可能误认为跨模块同名类型已处理，实际未处理。 | **P2 级维护负担**：① 7 行死代码增加认知负担，维护者需理解从未触发的逻辑；② 给维护者虚假的安全感，误以为 `(unknown context)` 场景已覆盖；③ 若未来 Swift 版本改变类型描述格式导致此分支被触发，会暴露问题 3 的潜在 bug；④ 违反 YAGNI 原则，增加代码复杂度。 | 已验证：`String(describing: TestProto.self)` → `TestProto`（不含 `(unknown context)`）；`String(describing: TestImpl().self)` → `main.(unknown context at $xxx).TestImpl`（含前缀，但这是实例描述，非类型描述）。运行 `swift test` 观察所有注册 key 均不含 `unknown context` | ✅ 已解决 | 删除 `normalizeKey` 的 `(unknown context at $xxx)` 分支（原 287-296 行，共 10 行死代码）。`normalizeKey` 简化为仅处理 `any `/`all ` 前缀剥离。现有 82 个测试全部通过，证实无回归。 |
| 3 | 🟡 中等 | `ServiceContainer.swift:287-296` | 潜在 Bug（死代码内） | 若问题 2 的分支被触发，`else` 分支（293 行）会生成**空字符串 key**：当 `typeString = "(unknown context at $xxx)"`（无 `.` 后缀）时，`typeString[afterClose...]` 是空字符串。所有此类类型都映射到空 key，导致 key 冲突。此外，`if` 分支（291 行）会**砍掉模块名**：`(unknown context at $xxx).DummyService` → `DummyService`，丢失模块前缀，跨模块同名类型会 key 冲突（违反 261 行注释"保留模块名前缀以避免跨模块同名类型 key 冲突"的契约）。 | 无直接业务现象（死代码不执行）。若被触发，现象为：两个不同模块的同名类型注册时后者覆盖前者，`resolve` 返回错误类型的实例，调用方收到类型不匹配的依赖，行为异常。 | **P2 级潜在风险**：① 若未来 Swift 版本改变类型描述格式导致此分支被触发，跨模块同名类型（如 `UFPCore.Logger` 与 `ZhiYuDomain.Logger`）会 key 冲突，`resolve` 返回错误实例；② 空字符串 key 会导致所有无模块前缀类型共享一个 key，DI 容器完全混乱；③ 违反代码注释契约（261 行声明保留模块名前缀）。 | 代码审查 + 逻辑推演（因是死代码，无法运行时触发） | ✅ 已解决 | 随问题 2 一并删除（整个 `(unknown context)` 分支移除，潜在 bug 不复存在）。 |
| 4 | 🟡 中等 | `ServiceContainer.swift:47` + `171-172` | 不一致行为 / 测试覆盖阻塞 | `fatalFailureHandler` 注释声称"使失败路径可被单元测试覆盖"，但**只在 `assertRegistered`（337 行）使用**，`resolve` 失败路径（171-172 行 `assertionFailure` + `fatalError`）**不检查 handler**，无论是否设置 handler 都崩溃。这导致 `resolve` 失败路径（166/171/172 行）无法被单元测试覆盖（覆盖率报告显示这些行未覆盖），是覆盖率提升的阻塞点。 | 测试环境下，任何调用 `resolve(未注册类型)` 的测试用例都会崩溃，无法用 `fatalFailureHandler` 转为 `XCTFail`。生产环境下无差异（生产不设置 handler）。 | **P1 级测试阻塞**：① `resolve` 失败路径（3 行）无法被单元测试覆盖，阻塞 SonarQube 95% 覆盖率门禁；② `fatalFailureHandler` 的 API 契约不一致——`assertRegistered` 支持 handler，`resolve` 不支持，调用方困惑；③ 无法编写"resolve 未注册类型应触发诊断"的测试，只能用 `XCTExpectFailure` 规避（脆弱）；④ 迫使测试用 `fatalError` 不可恢复的方式验证，增加测试套件不稳定性。 | 代码审查：`grep fatalFailureHandler` 显示只在 337 行使用，`resolve` 的 171-172 行无 handler 检查 | ✅ 已解决 | 在 `resolve` 失败路径的 `assertionFailure` 前插入 `if let handler = ServiceContainer.fatalFailureHandler { handler(summary) }`，与 `assertRegistered` 行为一致。handler 调用行可被覆盖率统计覆盖，解锁 `resolve` 失败路径的测试覆盖。注意：`resolve` 必须返回 `T`，handler 模式下仍需 `fatalError` 兜底（无法返回有效值），但 handler 先记录消息使诊断构建逻辑可测试。 |
| 5 | 🟠 低 | `ServiceContainer.swift:47` | 并发安全 / Swift 6 违规 | `fatalFailureHandler` 是 `static var`，但 `ServiceContainer` 标记为 `@unchecked Sendable`。`static var` 无并发保护，在 Swift 6 严格并发模式下，多线程并发读写 `fatalFailureHandler` 会导致数据竞争。虽然实际使用场景（测试 setUp/tearDown 设置，生产环境不修改）竞争概率低，但违反 Swift 6 并发安全契约。 | 无直接业务现象（当前仅在测试 setUp/tearDown 单线程设置）。若并发设置，现象为：handler 可能被部分线程读到旧值，测试结果不确定。 | **P3 级技术债**：① 违反 Swift 6 严格并发模式（`SWIFT_STRICT_CONCURRENCY: complete`），编译器可能告警；② 虽然当前使用场景竞争概率低，但未来若有测试并行执行或生产代码动态配置 handler，会触发数据竞争；③ `@unchecked Sendable` 的类含可变 `static var` 是并发安全反模式；④ 阻碍 Swift 6 完全并发安全的目标。 | 代码审查：`public static var fatalFailureHandler: ((String) -> Void)?` 无 `nonisolated` 或锁保护 | ✅ 已解决 | 改为 `public nonisolated(unsafe) static var fatalFailureHandler`，明确标注不安全并发访问。实际使用场景（测试 setUp/tearDown 单线程设置，生产环境不修改）竞争概率低，`nonisolated(unsafe)` 是合理的折中，符合 Swift 6 并发安全契约（显式声明而非隐式违规）。 |
| 6 | 🟠 低 | `ServiceContainer.swift:64` | 信息泄露 / 隐私 | `register` 的 DEBUG 日志输出实例描述：`"DI: Registered [\(key)] with instance \(String(describing: service))"`。实例描述可能含敏感信息（如 `URLSession` 配置、`Keychain` 句柄、用户 token 等）。虽然仅 DEBUG 构建，但若 DEBUG 日志被收集到诊断报告或崩溃日志，可能泄露敏感数据。 | DEBUG 构建下，控制台/系统日志输出每个注册服务的实例描述，可能包含 URL、token、用户 ID 等敏感字段。用户/测试人员查看日志时可见。 | **P3 级隐私风险**：① DEBUG 日志可能含敏感数据（如 `RemoteConfigService` 的 API key、`Keychain` 句柄、`URLSession` 配置）；② 若 DEBUG 构建被测试人员/内测用户使用，日志被截图或收集到诊断报告，存在数据泄露风险；③ 违反最小信息原则——DI 注册日志只需 key 和类型名，无需实例内容；④ 可能违反 GDPR/个人信息保护法的数据最小化原则。 | 代码审查：64 行 `String(describing: service)` 输出实例描述 | ✅ 已解决 | DEBUG 日志改为只输出 key：`"DI: Registered [\(key)]"`，移除 `with instance \(String(describing: service))`。遵循最小信息原则，DI 注册日志只需 key 即可定位问题，无需实例内容。运行 `swift test` 确认日志输出已脱敏。 |
| 7 | 🟠 低 | 测试缺口 | 测试覆盖不足 | `optionalNoneSentinel` 的 `unsafeBitCast` 是高危代码，但现有测试（`InjectPropertyWrapperTests`）只测了 `OptionalServiceProtocol?`（class optional，与 `Bool?` 大小可能巧合一致），未测值类型 Optional（`Int?`/`String?`/`Bool?`）和大小不同的 Optional。未覆盖的边界值导致问题 1 的必崩 bug 未被发现。 | 无直接业务现象（测试缺口）。但缺陷逃逸到生产——问题 1 的必崩 bug 未被测试发现，说明测试用例设计未覆盖值类型 Optional 的边界值。 | **P2 级质量风险**：① 高危代码（`unsafeBitCast`）缺乏针对性测试，必崩 bug 逃逸到生产；② 测试用例只覆盖 class optional（`OptionalServiceProtocol?`），未覆盖值类型 optional（`String?`/`Int?`），等价类划分不完整；③ 违反边界值分析原则——`unsafeBitCast` 对大小敏感，必须测试不同大小的 Optional；④ 给团队虚假的质量信心——测试通过但 bug 存在。 | 代码审查：`InjectPropertyWrapperTests` 无 `String?`/`Int?` 的 `@Inject` 测试 | ✅ 已解决 | 新增 `InjectValueOptionalTests.swift`（11 个测试用例），覆盖值类型 Optional 的等价类：① 未注册返回 nil（`String?`/`Int?`/`Double?`/`Bool?`/`Data?`，大小从 2 到 24 字节）；② 已注册返回具体值；③ 类型不匹配安全降级 nil。全部通过，作为问题 1 的回归测试防止复发。 |

## 验证日志

### 问题 1 验证：`unsafeBitCast` 跨大小必崩

```
$ cat > /tmp/test-bitcast.swift << 'EOF'
import Foundation
let boolNone: Bool? = .none
let stringNone = unsafeBitCast(boolNone, to: String?.self)
print("stringNone: \(String(describing: stringNone))")
EOF
$ swift /tmp/test-bitcast.swift
Swift/arm64e-apple-macos.swiftinterface:3272: Fatal error: Can't unsafeBitCast between types of different sizes
```

**结论**：`unsafeBitCast(Bool?.none, to: String?.self)` 必然崩溃。`optionalNoneSentinel` 在 `T` 是 `String?`/`Int?` 等大小不同的 Optional 时**必然崩溃**。

### 问题 2 验证：类型描述不含 `(unknown context)`

```
$ swift /tmp/test-normalize.swift
Protocol type desc: TestProto          ← 类型描述，不含 (unknown context)
Impl type desc: TestImpl               ← 类型描述，不含 (unknown context)
Instance desc: main.(unknown context at $1149c02d8).TestImpl  ← 实例描述，含 (unknown context)
```

**结论**：`normalizeKey` 处理类型描述（`"\(type)"`），不含 `(unknown context)`，287-296 行分支是死代码。

### 问题 2 补充验证：运行时注册 key 均不含 `unknown context`

```
$ cd Packages/UFPCore && swift test 2>&1 | grep "Registered \[" | grep -i "unknown\|context"
(no output)
```

**结论**：所有注册 key 均不含 `unknown context`，证实 287-296 行从未被触发。

## 修复优先级与状态

| 优先级 | 问题 # | 修复内容 | 状态 |
|--------|--------|----------|------|
| **P0** | 1 | `optionalNoneSentinel` 必崩 bug — 删除 `unsafeBitCast`，`injectWrap` 安全构造 Optional.none | ✅ 已解决 |
| **P1** | 2+3 | 删除 `normalizeKey` 死代码分支，消除维护负担和潜在 key 冲突 | ✅ 已解决 |
| **P1** | 4 | `resolve` 失败路径接入 `fatalFailureHandler`，解锁覆盖率提升 | ✅ 已解决 |
| **P2** | 5 | `fatalFailureHandler` 并发安全（`nonisolated(unsafe)` 标注） | ✅ 已解决 |
| **P2** | 6 | DEBUG 日志脱敏（只输出 key，不输出实例描述） | ✅ 已解决 |
| **P2** | 7 | 新增值类型 Optional 测试用例（`String?`/`Int?`/`Bool?`/`Double?`/`Data?`）作为回归测试 | ✅ 已解决 |

## 修复验证结果

- **测试运行**：`swift test` 执行 82 个测试，0 失败（含新增 11 个值类型 Optional 回归测试）
- **覆盖率提升**：UFPCore 语句覆盖率从 90.14% → 91.07%，`ServiceContainer.swift` 从 89.63% → 90.60%
- **DEBUG 日志脱敏**：确认日志只输出 `DI: Registered [key]`，不含实例描述
- **回归防护**：`InjectValueOptionalTests` 覆盖 5 种大小不同的值类型 Optional，防止问题 1 复发

## 备注

- 本报告记录通过测试用例设计发现的问题，并跟踪修复状态
- **黑盒业务现象**列从用户/调用方视角描述，不涉及代码内部机制
- **业务影响**列按 P0/P1/P2/P3 分级，P0=生产事故，P1=核心功能受损，P2=质量风险，P3=技术债
- **是否解决**列已全部更新为 ✅，**解决方案**列已填写实际采用的修复方案
- 问题 1 和问题 7 关联：修复问题 1 后，问题 7 的测试用例作为回归测试防止复发
- 所有修复已通过 `swift test` 验证，82 个测试 0 失败

---

## 第二轮测试驱动问题发现（2026-08-06）

> **方法论**：针对第一轮修复后的代码，进一步用并发竞态测试、类型边界测试、常量回归测试挖掘深层问题。
>
> **当前覆盖率**：语句 91.07%（第一轮后），目标通过第二轮测试进一步提升。

| # | 严重度 | 文件:行 | 问题分类 | 问题描述 | 黑盒业务现象 | 业务影响 | 复现/验证 | 是否解决 | 解决方案 |
|---|--------|---------|----------|----------|--------------|----------|-----------|----------|----------|
| 8 | 🔴 严重 | `ServiceContainer.swift:107-117` | 并发竞态 / 数据竞争 | `reset()` 与 `markProductionChainComplete()` 存在竞态窗口。原始实现：`reset()` 锁外读 `isProductionChainPopulated`。第一轮修复：`reset()` 锁内读 + `performReset()` 锁内清空（两次 lock）。**两次 lock 之间 `mark` 可执行**：① reset 第一次 lock 读到 false → ② mark lock 设 true → ③ reset 第二次 lock 清空 services。结果：`isProductionChainPopulated=true` 但 services 为空（不一致状态）。 | 生产环境下，若 `AppEnvironment` 调用 `markProductionChainComplete()` 的同时，某处（如测试代码、热重载逻辑）调用 `reset()`，DI 容器进入不一致状态：标记为已锁定但服务已清空。后续 `@Inject` 解析失败崩溃，但 `isReady` 返回 true 误导诊断。 | **P0 级生产事故**：① DI 容器不一致状态导致 `@Inject` 崩溃但 `isReady=true` 误导排查；② 竞态触发概率约 12.8%（64/500 次复现），非偶发；③ 两次 lock 的修复给虚假安全感（测试通过但竞态仍在）；④ 违反 Swift 6 严格并发安全契约。 | 复现测试：`testResetReadsStaleValueThenMarkThenPerformReset`（500 轮并发），还原旧修复后 64/500 次失败。修复后 20 次全量测试 0 失败。 | ✅ 已解决 | `reset()` 和 `resetForTesting()` 都在**同一次 `lock.withLock`** 内完成「检查 `isProductionChainPopulated` + 清空 services」，消除两次 lock 之间的竞态窗口。删除不再使用的 `performReset()`。新增 3 个并发测试：① `testResetAfterMarkIsBlocked`（确定性，先 mark 后 reset）；② `testResetForTestingClearsLockAndServices`（确定性，resetForTesting 同时清空两者）；③ `testConcurrentMarkAndResetNoInconsistency`（压力测试，500 轮并发）。 |
| 9 | 🟡 中等 | `ServiceContainer.swift:166-172` | 预期行为 / 契约设计 | `resolve<T>` 注册协议后用具体类型 resolve 触发 fatalError。例如 `register(x as Proto, for: Proto.self)` 后 `resolve(Impl.self)` 崩溃。 | 调用方用具体类型 resolve 协议注册的服务时崩溃。 | **P2 级契约清晰度**：调用方需理解「注册类型必须与 resolve 类型一致」。 | 代码审查 + 测试验证 | ✅ 预期行为 | **不修**。这是 fail-fast 契约：类型不匹配是调用方错误，`resolveOptional` 已安全返回 nil 供降级使用。`resolve<T>` 的 fatalError 是有意设计，防止类型不匹配的依赖被误用。 |
| 10 | 🟡 中等 | `ServiceContainer.swift:383` | 嵌套 Optional 语义错误 | `@Inject var x: Int??`（嵌套 Optional）未注册时返回 `.some(.none)` 而非 nil。`XCTAssertNil` 判定非 nil，调用方 `if let` 不触发，行为违反直觉。 | 使用 `@Inject var x: Int??` 的代码，未注册时 `x != nil` 为 true，但 `x!` 是 `.none`，行为混乱。 | **P2 级语义错误**：① 嵌套 Optional 行为违反直觉；② 调用方 `if let` 降级逻辑失效；③ Swift 语言陷阱 `nil as? Optional<T>` 返回 `.some(.none)`。 | 测试验证：`InjectNestedOptionalTests` | ✅ 已解决 | `injectWrap` 用 `Mirror(reflecting:).displayStyle == .optional && children.isEmpty` 检测 `Optional.none`，直接返回 `.none`，避免 `nil as? Wrapped` 陷阱。 |
| 11 | 🟠 低 | `SystemConstants.swift` | 测试缺口 | `SystemConstants` 的 16 个系统常量无任何测试覆盖。 | 无直接业务现象（测试缺口）。 | **P3 级质量风险**：常量值变更无回归保护。 | 代码审查：`SystemConstantsTests` 不存在 | ✅ 已解决 | 新增 `SystemConstantsTests.swift`，16 个常量回归测试。 |
| 12 | 🟠 低 | `Logger.swift` | 测试缺口 | Logger 边界值（空消息、超长消息、unicode）未测试。 | 无直接业务现象（测试缺口）。 | **P3 级质量风险**：边界行为无回归保护。 | 代码审查：`LoggerBoundaryTests` 不存在 | ✅ 已解决 | 新增 `LoggerBoundaryTests.swift`，8 个边界值测试。 |
| 13 | 🔴 严重 | `ServiceContainer.swift:185` | Optional 解析陷阱 | `resolveOptional<Int?>` 未注册时返回 `.some(.none)` 而非 nil。根因：`instance`（`Any?`）为 nil 时，`nil as? T`（T 是 `Int?`）返回 `.some(.none)` 而非 nil（Swift 语言陷阱）。 | 调用方 `if let x = resolveOptional<Int?>()` 降级逻辑失效——未注册时 `x` 是 `.some(.none)`，`if let` 不触发，但 `x!` 是 nil。 | **P0 级语义错误**：① `resolveOptional` 返回非 nil 但实际是空 Optional，调用方降级失效；② Swift 语言陷阱 `nil as? Optional<T>` 返回 `.some(.none)`；③ 与 `@Inject` 的 Optional 处理不一致。 | 测试验证：`ServiceContainerResolveTypeMismatchTests` | ✅ 已解决 | `resolveOptional` 加 `guard let nonNilInstance = instance else { return nil }`，避免 `nil as? T` 当 T 是 Optional 时返回 `.some(.none)`。 |

### 问题 8 验证：竞态窗口复现

**还原旧修复（两次 lock）后**，`testResetReadsStaleValueThenMarkThenPerformReset`（500 轮并发）：
```
XCTAssertEqual failed: ("64") is not equal to ("0") - 问题 #8 竞态未完全修复：64/500 次出现 isProductionChainLocked=true 但 services 为空的不一致状态
```

**应用真正修复（同一次 lock）后**，20 次全量测试（120 个测试）：
```
Run 1-20: Executed 120 tests, with 0 failures
```

### 关键教训

1. **`lock.withLock { read }` + `lock.withLock { write }` ≠ 原子操作**：两次 lock 之间其他线程可修改共享状态。必须在**同一次** lock 内完成「检查 + 修改」。
2. **Swift Optional 陷阱**：`nil as? Optional<T>` 返回 `.some(.none)` 而非 nil。处理 `Any?` 转 `T?` 时必须先 `guard let` 检查 nil。
3. **并发测试非确定性**：竞态触发概率不稳定（12.8%），需高轮次（500+）+ 多次运行（20+）才能稳定复现。确定性测试（先 mark 后 reset）作为主要回归保护，压力测试作为补充。
4. **测试目的是发现问题**：第一轮修复（两次 lock）测试通过但竞态仍在，说明「测试通过」≠「问题已修复」。必须用「还原修复 → 测试失败」验证测试有效性。
