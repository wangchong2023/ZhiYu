# 会话记忆 — UFPCore 测试驱动问题发现与修复

> **用途**：跨会话恢复上下文。新会话开头让 Agent 读取本文件即可恢复进度。
> **最后更新**：2026-08-06
> **状态**：UFPCore 13 个问题已全部修复（第二轮），待提交 commit

---

## Goal
- 用业界最佳实践（等价类划分、边界值、决策表等）为 UFPCore 编写测试用例，**目的是发现问题而非提高覆盖率**，发现的真实问题记录表格统一确认后修改
- 后续规划主 App 测试覆盖率提升（23%→50%→80%→95%）

## Constraints & Preferences
- UFPCore 只放业务无关的通用公共常量，ZhiYu 业务公共常量放 `CoreConstants.swift`
- pre-push hook 需全部通过才能提交（13 项门禁）
- `make test` 耗时极长，需用后台运行 + 日志轮询方式
- xcodebuild 需用 `-derivedDataPath build/DerivedData-mac-catalyst -disableAutomaticPackageResolution` 避免网络问题
- **测试目的是发现问题而非提高覆盖率**，使用业界最佳实践思路进行用例编写
- **发现实际问题记录下来表格，统一确认后修改**（与之前修复方式一致）
- 覆盖率脚本 `coverage-spm.py --pkg` 参数传**包名**（`UFPCore`），不是路径（`Packages/UFPCore`）
- 文档漂移检测的幽灵引用警告（WARNING 级别）不熔断 CI，合法引用无需修复

## Progress
### Done
- Core/Storage/Infrastructure 层全部魔鬼数字/短业务字符串违规已清零（commit `845555aa`/`37fb60ea`/`f3415149`，已推送 `gitlab/main`）
- 4 个失败测试已全部修复（commit `c4e1f828`，已推送 `gitlab/main`）
- SDD Task 2-5 已全部完成（Features/Domain 层 `#if os()` 残留 = 0）
- **UFPCore 第一轮测试驱动问题发现与修复**（commit `0a00d7ac`）：
  - 发现 7 个问题并全部修复，详见 `Docs/Audit/2026-08-05-ufpcore-test-findings.md`
  - 验证: `swift test` 82 通过 0 失败，pre-push 13 项全通过
  - 覆盖率: UFPCore 90.14% → 91.07%
- **UFPCore 第二轮测试驱动问题发现与修复**（待提交）：
  - 发现 6 个问题（#8-#13），5 个修复，1 个预期行为不修
  - 详见 `Docs/Audit/2026-08-05-ufpcore-test-findings.md` 第二轮章节
  - **问题 #8 (P0): `reset()` 与 `markProductionChainComplete()` 竞态** — 真正修复：`reset()`/`resetForTesting()` 在**同一次 `lock.withLock`** 内完成「检查 + 清空」，消除两次 lock 之间的竞态窗口。删除 `performReset()`。
    - 关键教训：`lock.withLock { read }` + `lock.withLock { write }` ≠ 原子操作
    - 验证：还原旧修复后 64/500 次失败；真正修复后 20 次全量测试 0 失败
  - 问题 #9 (P1): `resolve<T>` 类型不匹配 fatalError — **预期行为，不修**
  - 问题 #10 (P2): `@Inject Int??` 返回 `.some(.none)` — `injectWrap` 用 `Mirror` 检测 `Optional.none`
  - 问题 #11 (P3): `SystemConstants` 无测试 — 新增 16 个回归测试
  - 问题 #12 (P3): Logger 边界值未测试 — 新增 8 个边界值测试
  - 问题 #13 (P0): `resolveOptional<Int?>` 返回 `.some(.none)` — 加 `guard let nonNilInstance` 避免 `nil as? T` 陷阱
  - 验证: `swift test` 120 通过 0 失败（20 次稳定），pre-push 13 项全通过

### In Progress
- 提交第二轮修复 commit

### Blocked
- (none)

## Key Decisions
- `CoreConstants` 改为 `public enum`，子枚举和常量也加 `public`
- 与 UFPCore 重复的 `HTTPStatusCode`/`FileExtension` 从 `CoreConstants` 删除，改为引用 `SystemConstants`
- **`(?s)` 内联标志与 `.dotMatchesLineSeparators` options 不要混用**：iOS Simulator 的 ICU 实现存在行为差异
- **Mermaid mindmap 根节点关键字大小写敏感**：必须用小写 `root((标题))`
- **测试用例编写原则**：以发现问题为目的，不追求覆盖率数字；使用等价类划分、边界值、决策表等业界最佳实践
- `optionalNoneSentinel` 删除而非修复：`injectWrap` 已能安全构造 `Optional<Wrapped>.none`，`as? T` 必然成功，`optionalNoneSentinel` 是不必要的防御性 fallback
- `normalizeKey` 死代码直接删除：类型描述（`String(describing: Type.self)`）不含 `(unknown context)`，只有实例描述含，分支永不触发
- `fatalFailureHandler` 用 `nonisolated(unsafe)` 而非锁：实际使用场景（测试 setUp/tearDown 单线程设置）竞争概率低，`nonisolated(unsafe)` 是合理折中
- 文档漂移检测的 3 个幽灵引用（`TestProto`/`XCTExpectFailure`/`XCTFail`）均为合法引用，不需要修复
- **问题 #8 真正修复**：`reset()`/`resetForTesting()` 在**同一次 `lock.withLock`** 内完成「检查 + 清空」，删除 `performReset()`
- **问题 #9 是预期行为**：`resolve<T>` fail-fast 契约，类型不匹配 fatalError 是调用方错误，`resolveOptional` 已安全返回 nil
- **问题 #10 修复**：`injectWrap` 用 `Mirror(reflecting:).displayStyle == .optional && children.isEmpty` 检测 `Optional.none`
- **问题 #13 修复**：`resolveOptional` 加 `guard let nonNilInstance` 避免 `nil as? T` 当 T 是 Optional 时返回 `.some(.none)`
- **并发竞态测试非确定性**：竞态触发概率约 12.8%，需 500+ 轮 + 20+ 次运行才能稳定复现；确定性测试（先 mark 后 reset）作为主要回归保护
- **关键教训**：`lock.withLock { read }` + `lock.withLock { write }` ≠ 原子操作，必须在同一次 lock 内完成「检查 + 修改」

## Next Steps
- 提交第二轮修复 commit
- 后续规划主 App 测试覆盖率提升（23%→50%→80%→95%）

## Critical Context
- UFPCore 当前覆盖率（第一轮后）：语句 91.07%，`ServiceContainer.swift` 90.60%，`Logger.swift` 100%
- 第二轮新增测试文件后覆盖率预计提升（SystemConstants 0%→100%）
- `ServiceContainer.swift` 关键接口：`register<T>`/`resolve<T>`/`resolveOptional<T>`/`typeErasedResolve`/`hasService<T>`/`assertRegistered`/`reset()`/`resetForTesting()`/`markProductionChainComplete()`/`fatalFailureHandler`
- `Inject<T>` 属性包装器：检测 T 是否 Optional，Optional 未注册返回 nil（通过 `injectWrap` 安全构造），非 Optional 未注册触发 fatalError
- `OSAllocatedUnfairLock` 并发保护，`isProductionChainPopulated` 标记生产链锁定（现在所有读写都在同一次 lock 内）
- `normalizeKey` 仅处理 `any `/`all ` 前缀剥离
- `fatalFailureHandler` 在 `resolve` 和 `assertRegistered` 两处使用
- **Swift 语言陷阱**：`nil as? Optional<T>` 返回 `.some(.none)` 而非 nil；`nil as? Int??` 返回 `.some(.none)`
- **嵌套 Optional 行为**：`Int?? = .some(.none)` 的 `== nil` 为 false，`XCTAssertNil` 判定非 nil
- SPM 包覆盖率明细：UFPCore 91.07% / UFPDesignSystem 100% / ZhiYuDomain 100% / ZhiYuAICore 97.77% / ZhiYuFeatures 100%
- 主 App 覆盖率 ~23%，远低于 SonarQube 95% 门禁

## Relevant Files
- `Packages/UFPCore/Sources/UFPCore/Base/ServiceContainer.swift` — DI 容器核心，~413 行（第二轮修复后），含问题 #8/#10/#13 修复
- `Packages/UFPCore/Sources/UFPCore/Base/SystemConstants.swift` — 系统常量（现有测试覆盖）
- `Packages/UFPCore/Sources/UFPCore/System/Logger.swift` — 日志单例，100% 覆盖
- `Packages/UFPCore/Tests/UFPCoreTests/` — 21 个测试文件（含第二轮新增 5 个）
- `Packages/UFPCore/Tests/UFPCoreTests/ServiceContainerProductionLockRaceTests.swift` — 新增：并发竞态测试（问题 #8）
- `Packages/UFPCore/Tests/UFPCoreTests/ServiceContainerResolveTypeMismatchTests.swift` — 新增：类型不匹配测试（问题 #9/#13）
- `Packages/UFPCore/Tests/UFPCoreTests/InjectNestedOptionalTests.swift` — 新增：嵌套 Optional 测试（问题 #10）
- `Packages/UFPCore/Tests/UFPCoreTests/SystemConstantsTests.swift` — 新增：常量回归测试（问题 #11）
- `Packages/UFPCore/Tests/UFPCoreTests/LoggerBoundaryTests.swift` — 新增：Logger 边界值测试（问题 #12）
- `Docs/Audit/2026-08-05-ufpcore-test-findings.md` — 第一轮问题报告（7 个已解决），需追加 #8-#13
- `Docs/Work/session-memory.md` — 跨会话记忆文件
- `Tools/CI/coverage-spm.py` — SPM 覆盖率脚本
- `Tools/CI/assert-code-pre-push.sh` — pre-push 门禁脚本（13 项）

## Todo List
- [x] 修复问题 #8: isProductionChainPopulated 锁外读写竞态（真正修复：同一次 lock 原子操作） (priority: high)
- [x] 修复问题 #9: resolve 注册协议后用具体类型 fatalError（预期行为，不修） (priority: medium)
- [x] 修复问题 #10: @Inject Int?? 返回 .some(.none) (priority: medium)
- [x] 修复问题 #13: resolveOptional<Int?> 返回 .some(.none) (priority: high)
- [x] 恢复严格测试断言验证修复 (priority: high)
- [x] 运行全量测试 + pre-push 门禁（20 次稳定通过） (priority: high)
- [x] 更新 session-memory.md 和 findings 文档 (priority: medium)
- [ ] 提交第二轮修复 commit (priority: high)

---

## 下次恢复方式
新会话开头告诉 Agent：
> "读 `Docs/Work/session-memory.md` 恢复 UFPCore 测试工作的上下文，然后继续下一步"

或直接：
> "读 `Docs/Work/session-memory.md` 继续"
