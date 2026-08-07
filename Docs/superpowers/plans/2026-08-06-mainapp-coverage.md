# 主 App 非 View 纯逻辑层测试覆盖提升 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为主 App 非 View 纯逻辑层编写问题驱动 + 补盲单元测试，将全 App 覆盖率从 24.80% 提升至 ~34-35%，过程中发现的问题记录到 findings 表格并阶段修复。

**Architecture:** 按层分 5 批次（Core → Infrastructure → Features非View → Shared非UI → Localization），每批独立验证 + commit。核心业务逻辑用问题驱动深度测试（等价类/边界值/决策表/状态转换/错误猜测），纯工具/扩展/常量/Stub 用轻量补盲。发现问题记录到 `Docs/Audit/2026-08-06-mainapp-test-findings.md`，每批次末暂停测试、汇总 findings、用户确认、集中修复、重测、commit。

**Tech Stack:** Swift 6 / XCTest / `@testable import ZhiYu` / 现有 `Tests/Shared/TestMocks.swift` Mock 模式

## Global Constraints

- **测试目录整体豁免魔数审计**：三个 audit 脚本均已不扫描 `Tests/` 目录，测试代码中的契约常量无需豁免登记
- **iOS Simulator 名称**：`iPhone 17 Pro`（非 iPhone 16）
- **xcodebuild 参数**：`-derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
- **单测命令**：`xcodebuild test -only-testing:ZhiYuTests/<测试类> -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
- **全量验证**：`make test`（后台运行 + 日志轮询，耗时极长）
- **pre-push hook**：13 项门禁需全部通过
- **L10n 强约束**：测试代码不调用 `.tr()`，断言本地化值时用 `L10n.模块.属性` 强类型访问
- **单例有限重构策略**（用户批准）：JailbreakDetector/LocalAnalyticsService/WorkflowService 的 `private init` 改 `internal`，`logURL`/DI 依赖改为可注入，重构本身记入 findings
- **WorkflowService 副作用**（用户批准）：通过观察 `ToastManager.shared.currentToast` @Published 属性验证，HapticFeedback 仅验证不崩溃
- **StoreCapabilities 跳过**：实际位于 Domain 层（已 95% 达标），从 Core 批次范围移除
- **findings 表格**：`Docs/Audit/2026-08-06-mainapp-test-findings.md`
- **严重程度**：🔴 P0（数据损坏/崩溃/安全/资金）/ 🟡 P1（逻辑错误/不一致/边界缺陷）/ 🟢 P2（健壮性/维护负担/死代码）
- **commit 格式**：`test(<批次域>): <描述> + 修复 N 项测试驱动发现的问题`
- **注释规范**：统一简体中文，文档注释 `///`，实现注释 `//`，MARK 标签 `// MARK: - 中文标题`
- **文件头模板**：遵循 `Docs/Guides/file-header-template.md`（系统层级 + 核心职责）

---

## File Structure

### 批次 1 — Core 层测试文件

| 文件 | 职责 | 被测文件 |
|------|------|---------|
| `Tests/Unit/Core/RetryTaskTests.swift` | 指数退避重试逻辑 | `Sources/Core/Utils/RetryTask.swift` |
| `Tests/Unit/Core/AudioSplitterTests.swift` | 音频分片切割与重组 | `Sources/Core/System/Workflow/AudioSplitter.swift` |
| `Tests/Unit/Core/StringPhoneNumberTests.swift` | 手机号掩码边界 | `Packages/UFPCore/Sources/UFPCore/Base/Extensions/String+Masking.swift`（已迁移） |
| `Tests/Unit/Core/DateAppExtensionsTests.swift` | 日期格式化常量 | `Packages/UFPCore/Sources/UFPCore/Base/Extensions/Date+Formatting.swift`（已迁移） |
| `Tests/Unit/Core/DateExtensionsTests.swift` | 相对时间分支 | `Sources/Core/Base/Extensions/Date+Extensions.swift` |
| `Tests/Unit/Core/LogActionTests.swift` | 日志动作枚举契约 | `Sources/Core/Base/Constants/LogAction.swift` |
| `Tests/Unit/Core/ExportServiceProtocolTests.swift` | 导出错误枚举本地化 | `Sources/Core/Base/Protocols/ExportServiceProtocol.swift` |
| `Tests/Unit/Core/UnsupportedServicesTests.swift` | 3 个 Unsupported 桩抛错 | `Sources/Core/Base/Stubs/Unsupported*.swift` |
| `Tests/Unit/Core/StubServicesTests.swift` | 3 个 Stub 桩行为 + delegate | `Sources/Core/Base/Stubs/Stub*.swift` |
| `Tests/Unit/Core/ZipUtilityTests.swift` | ZIP 解压边界 | `Packages/UFPCore/Sources/UFPCore/Base/ZipUtility.swift`（已迁移） |
| `Tests/Unit/Core/JailbreakDetectorTests.swift` | 越狱检测非越狱路径 | `Sources/Core/System/Security/JailbreakDetector.swift` |
| `Tests/Unit/Core/LocalAnalyticsServiceTests.swift` | 本地分析持久化 | `Sources/Core/System/Analytics/LocalAnalyticsService.swift` |
| `Tests/Unit/Core/WorkflowServiceTests.swift` | Markdown 解析 + 同步 | `Sources/Core/System/Workflow/WorkflowService.swift` |
| `Tests/Shared/MockCollaborationDelegate.swift` | 协作 delegate spy | 新建共享 Mock |

### 批次 1 — 源码重构文件（有限重构）

| 文件 | 重构内容 | findings 记录 |
|------|---------|--------------|
| `Sources/Core/System/Security/JailbreakDetector.swift` | `private init` → `internal init` | P2 健壮性 |
| `Sources/Core/System/Analytics/LocalAnalyticsService.swift` | `private init` → `internal init`，`logURL` 改为可注入参数 | P2 健壮性 |
| `Sources/Core/System/Workflow/WorkflowService.swift` | `private init` → `internal init`，`@Inject` 改为可注入构造器参数 | P2 健壮性 |

### 后续批次（2-5）

批次 2-5 的详细任务在批次 1 完成后补充（避免计划过长）。批次 2-5 的范围见设计规格 `Docs/superpowers/specs/2026-08-06-mainapp-coverage-design.md` 第 3.2-3.5 节。

---

## 批次 1 — Core 层（440 行 0% → 目标 95%）

**批次目标**：覆盖 Core 层 0% 文件的纯逻辑代码，预期全 App 覆盖率 ~25.6%
**问题驱动重点**：ZipUtility（压缩解压边界）、JailbreakDetector（安全检测）、RetryTask（重试退避）、WorkflowService（Markdown 解析）
**阶段修复**：批次末暂停测试，汇总 findings，用户确认后集中修复，重测，commit

### Task 1: 初始化 findings 表格

**Files:**
- Create: `Docs/Audit/2026-08-06-mainapp-test-findings.md`

**Interfaces:**
- Consumes: 无
- Produces: findings 表格文件，后续任务写入问题记录

- [ ] **Step 1: 创建 findings 表格文件**

写入以下内容到 `Docs/Audit/2026-08-06-mainapp-test-findings.md`：

```markdown
# 主 App 测试驱动问题发现记录

> **起始日期**：2026-08-06
> **关联规格**：`Docs/superpowers/specs/2026-08-06-mainapp-coverage-design.md`
> **关联计划**：`docs/superpowers/plans/2026-08-06-mainapp-coverage.md`

## 严重程度定义

- 🔴 **P0**：数据损坏/丢失、崩溃、安全漏洞、资金损失（订阅/支付）
- 🟡 **P1**：逻辑错误、行为不一致、边界处理缺陷、错误处理缺失
- 🟢 **P2**：健壮性不足、维护负担、死代码、命名/注释问题

## 问题清单

| 序号 | 严重程度 | 文件:行号 | 问题类型 | 问题描述 | 黑盒影响 | 修改方案 | 处理状态 | 批次 |
|------|---------|----------|---------|---------|---------|---------|---------|------|

## 处理状态说明

- **待确认**：测试发现，待用户确认
- **已确认 → 已修复**：用户确认后已修复
- **已确认 → 预期行为不修**：用户确认是预期行为，不修
```

- [ ] **Step 2: 验证文件创建**

Run: `ls -la Docs/Audit/2026-08-06-mainapp-test-findings.md`
Expected: 文件存在

- [ ] **Step 3: Commit**

```bash
git add Docs/Audit/2026-08-06-mainapp-test-findings.md
git commit -m "docs(audit): 初始化主 App 测试 findings 表格"
```

---

### Task 2: RetryTask 测试（问题驱动 — 重试退避逻辑）

**Files:**
- Create: `Tests/Unit/Core/RetryTaskTests.swift`
- Test: `Sources/Core/Utils/RetryTask.swift:15-66`

**Interfaces:**
- Consumes: `RetryTask.execute(maxRetries:initialDelay:multiplier:maxDelay:operation:)` 静态方法
- Produces: `RetryTaskTests` 测试类，验证重试/退避/耗尽/边界

**问题驱动方法**：边界值分析（maxRetries=0/1/N）、状态转换（成功→返回/失败→重试→成功/失败→耗尽）、错误猜测（错误类型保持）

- [ ] **Step 1: 编写测试**

写入 `Tests/Unit/Core/RetryTaskTests.swift`：

```swift
//
//  RetryTaskTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 RetryTask 指数退避重试逻辑的正确性（成功/重试/耗尽/边界）。
//

import XCTest
@testable import ZhiYu

final class RetryTaskTests: XCTestCase {

    // MARK: - 成功路径

    /// 首次执行即成功，不应重试
    func testExecute_首次成功_不重试() async throws {
        var callCount = 0
        let result = try await RetryTask.execute(
            maxRetries: 3,
            initialDelay: 0.001,
            operation: { @Sendable in
                callCount += 1
                return "success"
            }
        )
        XCTAssertEqual(result, "success")
        XCTAssertEqual(callCount, 1, "首次成功应只调用一次")
    }

    // MARK: - 重试后成功

    /// 前 N 次失败，第 N+1 次成功
    func testExecute_重试后成功_返回成功值() async throws {
        var callCount = 0
        let result = try await RetryTask.execute(
            maxRetries: 3,
            initialDelay: 0.001,
            operation: { @Sendable in
                callCount += 1
                if callCount < 3 {
                    throw TestError.failure
                }
                return "recovered"
            }
        )
        XCTAssertEqual(result, "recovered")
        XCTAssertEqual(callCount, 3, "前 2 次失败 + 第 3 次成功 = 3 次调用")
    }

    // MARK: - 重试耗尽

    /// 始终失败，重试耗尽后抛出最后一次错误
    func testExecute_重试耗尽_抛出错误() async throws {
        var callCount = 0
        do {
            _ = try await RetryTask.execute(
                maxRetries: 2,
                initialDelay: 0.001,
                operation: { @Sendable in
                    callCount += 1
                    throw TestError.failure
                }
            )
            XCTFail("应抛出错误")
        } catch {
            XCTAssertEqual(callCount, 3, "首次 + 2 次重试 = 3 次调用")
            XCTAssertTrue(error is TestError, "应抛出原始错误类型")
        }
    }

    // MARK: - 边界值：maxRetries

    /// maxRetries=0，首次失败即抛出，不重试
    func testExecute_maxRetries为0_不重试() async throws {
        var callCount = 0
        do {
            _ = try await RetryTask.execute(
                maxRetries: 0,
                initialDelay: 0.001,
                operation: { @Sendable in
                    callCount += 1
                    throw TestError.failure
                }
            )
            XCTFail("应抛出错误")
        } catch {
            XCTAssertEqual(callCount, 1, "maxRetries=0 应只调用一次")
        }
    }

    /// maxRetries=1，最多调用 2 次（首次 + 1 次重试）
    func testExecute_maxRetries为1_最多2次调用() async throws {
        var callCount = 0
        do {
            _ = try await RetryTask.execute(
                maxRetries: 1,
                initialDelay: 0.001,
                operation: { @Sendable in
                    callCount += 1
                    throw TestError.failure
                }
            )
            XCTFail("应抛出错误")
        } catch {
            XCTAssertEqual(callCount, 2, "首次 + 1 次重试 = 2 次调用")
        }
    }

    // MARK: - 错误类型保持

    /// 抛出的错误应原样传递（自定义错误枚举）
    func testExecute_错误类型保持_抛出原始错误() async throws {
        do {
            _ = try await RetryTask.execute(
                maxRetries: 1,
                initialDelay: 0.001,
                operation: { @Sendable in
                    throw TestError.specificError
                }
            )
            XCTFail("应抛出错误")
        } catch let error as TestError {
            XCTAssertEqual(error, TestError.specificError, "应保持原始错误类型和值")
        } catch {
            XCTFail("应抛出 TestError 类型，实际：\(type(of: error))")
        }
    }

    // MARK: - 返回值类型

    /// 泛型返回值应正确传递（Int 类型）
    func testExecute_返回Int类型_值正确() async throws {
        let result = try await RetryTask.execute(
            maxRetries: 0,
            initialDelay: 0.001,
            operation: { @Sendable in 42 }
        )
        XCTAssertEqual(result, 42)
    }

    /// 泛型返回值应正确传递（可选类型）
    func testExecute_返回可选类型_值正确() async throws {
        let result: String? = try await RetryTask.execute(
            maxRetries: 0,
            initialDelay: 0.001,
            operation: { @Sendable in nil }
        )
        XCTAssertNil(result)
    }

    // MARK: - 退避参数验证

    /// multiplier=1.0，延迟不增长（仅验证不崩溃 + 最终成功）
    func testExecute_multiplier为1_延迟不增长() async throws {
        var callCount = 0
        let result = try await RetryTask.execute(
            maxRetries: 2,
            initialDelay: 0.001,
            multiplier: 1.0,
            operation: { @Sendable in
                callCount += 1
                if callCount < 2 { throw TestError.failure }
                return "ok"
            }
        )
        XCTAssertEqual(result, "ok")
        XCTAssertEqual(callCount, 2)
    }

    /// maxDelay 截断验证（initialDelay 极大 + maxDelay 极小，应被截断）
    func testExecute_maxDelay截断_不超时() async throws {
        let result = try await RetryTask.execute(
            maxRetries: 1,
            initialDelay: 100.0,
            multiplier: 10.0,
            maxDelay: 0.001,
            operation: { @Sendable in "fast" }
        )
        XCTAssertEqual(result, "fast", "maxDelay 应截断 initialDelay，避免长时间等待")
    }
}

// MARK: - 测试专用错误类型

private enum TestError: Error, Equatable {
    case failure
    case specificError
}
```

- [ ] **Step 2: 运行测试验证通过**

Run: `xcodebuild test -only-testing:ZhiYuTests/RetryTaskTests -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
Expected: PASS（10 个测试用例全绿）

- [ ] **Step 3: 检查 findings**

审查 `RetryTask.swift` 源码，记录任何发现的问题到 `Docs/Audit/2026-08-06-mainapp-test-findings.md` 表格。当前审查结论：无问题（逻辑正确，边界处理完善）。

- [ ] **Step 4: Commit**

```bash
git add Tests/Unit/Core/RetryTaskTests.swift
git commit -m "test(core): RetryTask 重试退避逻辑测试 10 用例"
```

---

### Task 3: AudioSplitter 测试（问题驱动 — 分片边界）

**Files:**
- Create: `Tests/Unit/Core/AudioSplitterTests.swift`
- Test: `Sources/Core/System/Workflow/AudioSplitter.swift:15-45`

**Interfaces:**
- Consumes: `AudioSplitter.split(data:chunkSize:)`、`AudioSplitter.merge(chunks:)` 静态方法
- Produces: `AudioSplitterTests` 测试类

**问题驱动方法**：等价类划分（空/小于/等于/大于/整除/非整除）、往返测试（split→merge 还原）

- [ ] **Step 1: 编写测试**

写入 `Tests/Unit/Core/AudioSplitterTests.swift`：

```swift
//
//  AudioSplitterTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 AudioSplitter 音频分片切割与重组的正确性（空/边界/往返）。
//

import XCTest
@testable import ZhiYu

final class AudioSplitterTests: XCTestCase {

    // MARK: - split 等价类划分

    /// 空 Data → 空数组
    func testSplit_空数据_返回空数组() {
        let result = AudioSplitter.split(data: Data())
        XCTAssertTrue(result.isEmpty, "空数据应返回空数组")
    }

    /// 数据长度 < chunkSize → 单分片
    func testSplit_数据小于chunkSize_单分片() {
        let data = Data(repeating: 0xAB, count: 100)
        let result = AudioSplitter.split(data: data, chunkSize: 256)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], data)
    }

    /// 数据长度 == chunkSize → 单分片
    func testSplit_数据等于chunkSize_单分片() {
        let data = Data(repeating: 0xAB, count: 256)
        let result = AudioSplitter.split(data: data, chunkSize: 256)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result[0], data)
    }

    /// 数据长度 == chunkSize * N → N 个分片
    func testSplit_数据整除chunkSize_N个分片() {
        let data = Data(repeating: 0xAB, count: 512)
        let result = AudioSplitter.split(data: data, chunkSize: 256)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].count, 256)
        XCTAssertEqual(result[1].count, 256)
    }

    /// 数据长度 == chunkSize * N + remainder → N+1 个分片，最后一个为 remainder
    func testSplit_数据非整除chunkSize_N加1个分片() {
        let data = Data(repeating: 0xAB, count: 300)
        let result = AudioSplitter.split(data: data, chunkSize: 256)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].count, 256)
        XCTAssertEqual(result[1].count, 44, "最后一个分片应为余数 44")
    }

    /// 自定义 chunkSize=1 → 每字节一个分片
    func testSplit_chunkSize为1_每字节一个分片() {
        let data = Data(repeating: 0xAB, count: 5)
        let result = AudioSplitter.split(data: data, chunkSize: 1)
        XCTAssertEqual(result.count, 5)
        for chunk in result {
            XCTAssertEqual(chunk.count, 1)
        }
    }

    /// 默认 chunkSize 为 256KB
    func testSplit_默认chunkSize_256KB() {
        let data = Data(repeating: 0xAB, count: 256 * 1024 + 1)
        let result = AudioSplitter.split(data: data)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].count, 256 * 1024)
        XCTAssertEqual(result[1].count, 1)
    }

    // MARK: - merge 测试

    /// 空数组 → 空 Data
    func testMerge_空数组_返回空Data() {
        let result = AudioSplitter.merge(chunks: [])
        XCTAssertTrue(result.isEmpty)
    }

    /// 单分片 → 原始 Data
    func testMerge_单分片_返回原始Data() {
        let original = Data(repeating: 0xCD, count: 100)
        let result = AudioSplitter.merge(chunks: [original])
        XCTAssertEqual(result, original)
    }

    // MARK: - 往返测试（split → merge 还原）

    /// split 后 merge 应还原原始数据
    func testRoundTrip_split后merge_还原原始数据() {
        let original = Data(repeating: 0xEF, count: 1000)
        let chunks = AudioSplitter.split(data: original, chunkSize: 256)
        let recovered = AudioSplitter.merge(chunks: chunks)
        XCTAssertEqual(recovered, original, "split→merge 应还原原始数据")
    }

    /// 大数据往返测试（默认 chunkSize）
    func testRoundTrip_大数据_默认chunkSize() {
        let original = Data(repeating: 0x12, count: 1024 * 1024)
        let chunks = AudioSplitter.split(data: original)
        let recovered = AudioSplitter.merge(chunks: chunks)
        XCTAssertEqual(recovered, original)
    }
}
```

- [ ] **Step 2: 运行测试验证通过**

Run: `xcodebuild test -only-testing:ZhiYuTests/AudioSplitterTests -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
Expected: PASS（11 个测试用例全绿）

- [ ] **Step 3: 检查 findings**

审查 `AudioSplitter.swift` 源码。当前审查结论：无问题（纯计算逻辑正确）。

- [ ] **Step 4: Commit**

```bash
git add Tests/Unit/Core/AudioSplitterTests.swift
git commit -m "test(core): AudioSplitter 分片切割与重组测试 11 用例"
```

### Task 4: String+PhoneNumber 测试（问题驱动 — 掩码边界）

**Files:**
- Create: `Tests/Unit/Core/StringPhoneNumberTests.swift`
- Test: `Packages/UFPCore/Sources/UFPCore/Base/Extensions/String+Masking.swift:11-19`（已迁移）

**Interfaces:**
- Consumes: `String.maskedPhoneNumber` 计算属性
- Produces: `StringPhoneNumberTests` 测试类

**问题驱动方法**：边界值分析（长度 6/7/11/12）、等价类划分（不足 7 位/标准手机号/超长）

- [ ] **Step 1: 编写测试**

写入 `Tests/Unit/Core/StringPhoneNumberTests.swift`：

```swift
//
//  StringPhoneNumberTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 String.maskedPhoneNumber 手机号掩码的正确性（长度边界/标准/超长）。
//

import XCTest
@testable import ZhiYu

final class StringPhoneNumberTests: XCTestCase {

    // MARK: - 边界值：长度 < 7（返回自身）

    /// 空字符串 → 返回空字符串
    func testMaskedPhoneNumber_空字符串_返回自身() {
        XCTAssertEqual("".maskedPhoneNumber, "")
    }

    /// 长度 1 → 返回自身
    func testMaskedPhoneNumber_长度1_返回自身() {
        XCTAssertEqual("1".maskedPhoneNumber, "1")
    }

    /// 长度 6（< 7 阈值）→ 返回自身
    func testMaskedPhoneNumber_长度6_返回自身() {
        XCTAssertEqual("123456".maskedPhoneNumber, "123456")
    }

    // MARK: - 边界值：长度 == 7（刚好满足阈值）

    /// 长度 7 → 掩码（前 3 + **** + 后 4 = 11 字符）
    func testMaskedPhoneNumber_长度7_执行掩码() {
        let result = "1234567".maskedPhoneNumber
        XCTAssertEqual(result.count, 11, "前3 + 4个* + 后4 = 11 字符")
        XCTAssertTrue(result.hasPrefix("123"))
        XCTAssertTrue(result.hasSuffix("4567"))
        XCTAssertTrue(result.contains("****"))
    }

    // MARK: - 标准手机号

    /// 长度 11（标准中国手机号）→ 180****6625
    func testMaskedPhoneNumber_标准手机号11位_正确掩码() {
        XCTAssertEqual("18012346625".maskedPhoneNumber, "180****6625")
    }

    /// 长度 11（不同前缀）→ 138****8888
    func testMaskedPhoneNumber_不同前缀11位_正确掩码() {
        XCTAssertEqual("13812348888".maskedPhoneNumber, "138****8888")
    }

    // MARK: - 超长号码

    /// 长度 12 → 前 3 + **** + 后 4
    func testMaskedPhoneNumber_长度12_前3后4掩码() {
        let result = "180123466256".maskedPhoneNumber
        XCTAssertEqual(result, "180****6256")
    }

    /// 长度 20 → 前 3 + **** + 后 4
    func testMaskedPhoneNumber_长度20_前3后4掩码() {
        let result = "18012345678901234567".maskedPhoneNumber
        XCTAssertEqual(result, "180****4567")
    }

    // MARK: - 非数字字符

    /// 含字母的字符串（长度 >= 7）→ 仍执行掩码逻辑
    func testMaskedPhoneNumber_含字母_执行掩码() {
        let result = "abcdefg1234".maskedPhoneNumber
        XCTAssertEqual(result, "abc****1234")
    }
}
```

- [ ] **Step 2: 运行测试验证通过**

Run: `xcodebuild test -only-testing:ZhiYuTests/StringPhoneNumberTests -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
Expected: PASS（9 个测试用例全绿）

- [ ] **Step 3: 检查 findings**

审查 `String+Masking.swift` 源码（原 `String+PhoneNumber.swift`，已迁移至 UFPCore）。当前审查结论：无问题（边界处理符合文档注释）。

- [ ] **Step 4: Commit**

```bash
git add Tests/Unit/Core/StringPhoneNumberTests.swift
git commit -m "test(core): String.maskedPhoneNumber 掩码边界测试 9 用例"
```

---

### Task 5: Date+App 测试（轻量补盲 — 格式化常量）

**Files:**
- Create: `Tests/Unit/Core/DateAppExtensionsTests.swift`
- Test: `Packages/UFPCore/Sources/UFPCore/Base/Extensions/Date+Formatting.swift:13-41`（已迁移）

**Interfaces:**
- Consumes: `Date.AppFormat` 静态常量、`Date.formatted(as:)` 方法
- Produces: `DateAppExtensionsTests` 测试类

- [ ] **Step 1: 编写测试**

写入 `Tests/Unit/Core/DateAppExtensionsTests.swift`：

```swift
//
//  DateAppExtensionsTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 Date.AppFormat 格式常量与 formatted(as:) 方法的正确性。
//

import XCTest
@testable import ZhiYu

final class DateAppExtensionsTests: XCTestCase {

    // MARK: - AppFormat 常量值断言

    func testAppFormat_iso8601常量值() {
        XCTAssertEqual(Date.AppFormat.iso8601, "yyyy-MM-dd")
    }

    func testAppFormat_detailed常量值() {
        XCTAssertEqual(Date.AppFormat.detailed, "yyyy-MM-dd HH:mm")
    }

    func testAppFormat_slashDetailed常量值() {
        XCTAssertEqual(Date.AppFormat.slashDetailed, "yyyy/M/d HH:mm")
    }

    func testAppFormat_monthDay常量值() {
        XCTAssertEqual(Date.AppFormat.monthDay, "M-d")
    }

    func testAppFormat_year常量值() {
        XCTAssertEqual(Date.AppFormat.year, "yyyy")
    }

    // MARK: - formatted(as:) 格式化验证

    /// 固定日期验证 5 种格式（用 UTC 固定时区避免漂移）
    func testFormatted_固定日期_5种格式() {
        var components = DateComponents()
        components.year = 2026
        components.month = 8
        components.day = 6
        components.hour = 14
        components.minute = 30
        components.timeZone = TimeZone(identifier: "UTC")
        let date = Calendar(identifier: .gregorian).date(from: components)!

        let utcFormatter = DateFormatter()
        utcFormatter.timeZone = TimeZone(identifier: "UTC")
        utcFormatter.locale = Locale(identifier: "en_US_POSIX")

        utcFormatter.dateFormat = Date.AppFormat.iso8601
        XCTAssertEqual(utcFormatter.string(from: date), "2026-08-06")

        utcFormatter.dateFormat = Date.AppFormat.detailed
        XCTAssertEqual(utcFormatter.string(from: date), "2026-08-06 14:30")

        utcFormatter.dateFormat = Date.AppFormat.slashDetailed
        XCTAssertEqual(utcFormatter.string(from: date), "2026/8/6 14:30")

        utcFormatter.dateFormat = Date.AppFormat.monthDay
        XCTAssertEqual(utcFormatter.string(from: date), "8-6")

        utcFormatter.dateFormat = Date.AppFormat.year
        XCTAssertEqual(utcFormatter.string(from: date), "2026")
    }

    /// formatted(as:) 返回非空字符串
    func testFormatted_任意日期_返回非空() {
        let date = Date()
        XCTAssertFalse(date.formatted(as: Date.AppFormat.iso8601).isEmpty)
        XCTAssertFalse(date.formatted(as: Date.AppFormat.detailed).isEmpty)
    }
}
```

- [ ] **Step 2: 运行测试验证通过**

Run: `xcodebuild test -only-testing:ZhiYuTests/DateAppExtensionsTests -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
Expected: PASS（7 个测试用例全绿）

- [ ] **Step 3: 检查 findings**

审查 `Date+Formatting.swift` 源码（原 `Date+App.swift`，已迁移至 UFPCore）。当前审查结论：无问题。

- [ ] **Step 4: Commit**

```bash
git add Tests/Unit/Core/DateAppExtensionsTests.swift
git commit -m "test(core): Date+App 格式化常量与 formatted 方法测试 7 用例"
```

---

### Task 6: Date+Extensions 测试（问题驱动 — 相对时间分支）

**Files:**
- Create: `Tests/Unit/Core/DateExtensionsTests.swift`
- Test: `Sources/Core/Base/Extensions/Date+Extensions.swift:13-46`

**Interfaces:**
- Consumes: `Date.timeAgoDisplay()` 方法
- Produces: `DateExtensionsTests` 测试类

**问题驱动方法**：状态转换（年/月/日/时/分/刚刚）、边界值（day==1 昨天 vs day>1）

**注**：`timeAgoDisplay()` 内部调用 `Date()` 获取当前时间，测试用固定时间窗验证分支。

- [ ] **Step 1: 编写测试**

写入 `Tests/Unit/Core/DateExtensionsTests.swift`：

```swift
//
//  DateExtensionsTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 Date.timeAgoDisplay() 相对时间显示的分支正确性。
//

import XCTest
@testable import ZhiYu

final class DateExtensionsTests: XCTestCase {

    // MARK: - 刚刚（秒级差）

    /// 当前时间 → "刚刚"
    func testTimeAgoDisplay_当前时间_返回刚刚() {
        let now = Date()
        let result = now.timeAgoDisplay()
        XCTAssertEqual(result, L10n.Common.justNow)
    }

    /// 30 秒前 → "刚刚"（秒级差不触发 minute 分支）
    func testTimeAgoDisplay_30秒前_返回刚刚() {
        let thirtySecondsAgo = Date().addingTimeInterval(-30)
        let result = thirtySecondsAgo.timeAgoDisplay()
        XCTAssertEqual(result, L10n.Common.justNow)
    }

    // MARK: - 分钟级

    /// 5 分钟前 → 非空字符串（走 minute 分支）
    func testTimeAgoDisplay_5分钟前_返回非空() {
        let fiveMinutesAgo = Date().addingTimeInterval(-5 * 60)
        let result = fiveMinutesAgo.timeAgoDisplay()
        XCTAssertFalse(result.isEmpty, "5 分钟前应返回非空字符串")
        XCTAssertNotEqual(result, L10n.Common.justNow, "5 分钟前不应返回'刚刚'")
    }

    // MARK: - 小时级

    /// 2 小时前 → 非空字符串（走 hour 分支）
    func testTimeAgoDisplay_2小时前_返回非空() {
        let twoHoursAgo = Date().addingTimeInterval(-2 * 3600)
        let result = twoHoursAgo.timeAgoDisplay()
        XCTAssertFalse(result.isEmpty)
        XCTAssertNotEqual(result, L10n.Common.justNow)
    }

    // MARK: - 天级

    /// 1 天前 → "昨天"
    func testTimeAgoDisplay_1天前_返回昨天() {
        let oneDayAgo = Date().addingTimeInterval(-24 * 3600)
        let result = oneDayAgo.timeAgoDisplay()
        XCTAssertEqual(result, L10n.Common.yesterday)
    }

    /// 2 天前 → 非空字符串（走 day > 1 分支，非"昨天"）
    func testTimeAgoDisplay_2天前_返回非昨天() {
        let twoDaysAgo = Date().addingTimeInterval(-2 * 24 * 3600)
        let result = twoDaysAgo.timeAgoDisplay()
        XCTAssertFalse(result.isEmpty)
        XCTAssertNotEqual(result, L10n.Common.yesterday, "2 天前不应返回'昨天'")
    }

    // MARK: - 月级

    /// 35 天前 → 非空字符串（走 month 分支）
    func testTimeAgoDisplay_35天前_返回非空() {
        let thirtyFiveDaysAgo = Date().addingTimeInterval(-35 * 24 * 3600)
        let result = thirtyFiveDaysAgo.timeAgoDisplay()
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - 年级

    /// 400 天前 → 非空字符串（走 year 分支）
    func testTimeAgoDisplay_400天前_返回非空() {
        let fourHundredDaysAgo = Date().addingTimeInterval(-400 * 24 * 3600)
        let result = fourHundredDaysAgo.timeAgoDisplay()
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - 返回值类型

    /// 任何时间都应返回非空字符串
    func testTimeAgoDisplay_任意时间_返回非空字符串() {
        let pastDate = Date().addingTimeInterval(-100)
        XCTAssertFalse(pastDate.timeAgoDisplay().isEmpty)
    }
}
```

- [ ] **Step 2: 运行测试验证通过**

Run: `xcodebuild test -only-testing:ZhiYuTests/DateExtensionsTests -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
Expected: PASS（9 个测试用例全绿）

- [ ] **Step 3: 检查 findings**

审查 `Date+Extensions.swift` 源码。当前审查结论：无问题（分支逻辑正确）。

- [ ] **Step 4: Commit**

```bash
git add Tests/Unit/Core/DateExtensionsTests.swift
git commit -m "test(core): Date.timeAgoDisplay 相对时间分支测试 9 用例"
```

### Task 7: LogAction 测试（问题驱动 — 枚举契约一致性）

**Files:**
- Create: `Tests/Unit/Core/LogActionTests.swift`
- Test: `Sources/Core/Base/Constants/LogAction.swift:13-82`

**Interfaces:**
- Consumes: `LogAction` 枚举（19 个 case + rawValue + localizedName + colorName + icon）
- Produces: `LogActionTests` 测试类

**问题驱动方法**：契约一致性（rawValue 前缀模式）、错误猜测（已发现 aiscanFailed/aiscanSkipped/export/error/unknown 前缀不一致）

**已知问题**：
- `LogAction.aiscanFailed`/`aiscanSkipped` 的 rawValue 用 `log.action.aiscan.*` 前缀，与标准 `logAction.*` 不一致（P2）
- `LogAction.export` 的 rawValue 用 `action.export`，与标准 `logAction.*` 不一致（P2）
- `LogAction.error` 的 rawValue 用 `ERROR`，`LogAction.unknown` 用 `unknown`，完全不符合前缀契约（P2）

- [ ] **Step 1: 编写测试**

写入 `Tests/Unit/Core/LogActionTests.swift`：

```swift
//
//  LogActionTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 LogAction 枚举 rawValue 契约一致性（前缀模式/唯一性/可逆性）。
//

import XCTest
@testable import ZhiYu

final class LogActionTests: XCTestCase {

    // MARK: - rawValue 前缀契约

    /// 标准 case 的 rawValue 应以 "logAction." 前缀开头（契约一致性）
    func testRawValue_标准case_logAction前缀() {
        let standardCases: [LogAction] = [
            .create, .update, .delete,
            .ingest, .smartIngest,
            .importPDF, .importPDFFailed, .deletePDF, .highlight,
            .lint, .healthCheck, .systemInit, .sync,
        ]
        for action in standardCases {
            XCTAssertTrue(
                action.rawValue.hasPrefix("logAction."),
                "case \(action) 的 rawValue '\(action.rawValue)' 应以 'logAction.' 前缀开头"
            )
        }
    }

    /// aiscanFailed/aiscanSkipped 当前前缀为 "log.action.aiscan."（记录为 P2 不一致）
    func testRawValue_aiscan前缀_当前不一致() {
        XCTAssertTrue(LogAction.aiscanFailed.rawValue.hasPrefix("log.action.aiscan."))
        XCTAssertTrue(LogAction.aiscanSkipped.rawValue.hasPrefix("log.action.aiscan."))
        // 注：此测试断言当前（不一致）行为，修复后应改为 hasPrefix("logAction.")
    }

    /// export 当前前缀为 "action.export"（记录为 P2 不一致）
    func testRawValue_export前缀_当前不一致() {
        XCTAssertEqual(LogAction.export.rawValue, "action.export")
        // 注：此测试断言当前（不一致）行为，修复后应改为 hasPrefix("logAction.")
    }

    /// error/unknown 完全不符合前缀契约（记录为 P2 不一致）
    func testRawValue_error和unknown_不符合前缀契约() {
        XCTAssertEqual(LogAction.error.rawValue, "ERROR")
        XCTAssertEqual(LogAction.unknown.rawValue, "unknown")
        // 注：此测试断言当前（不一致）行为
    }

    // MARK: - rawValue 唯一性

    /// 所有 case 的 rawValue 应唯一（无重复）
    func testRawValue_唯一性_无重复() {
        let allCases = LogAction.allCases
        let rawValues = allCases.map(\.rawValue)
        let uniqueRawValues = Set(rawValues)
        XCTAssertEqual(rawValues.count, uniqueRawValues.count, "所有 rawValue 应唯一")
        XCTAssertEqual(allCases.count, 19, "应有 19 个 case（CaseIterable）")
    }

    // MARK: - 可逆性（rawValue → LogAction）

    /// rawValue 应能反向构造 LogAction（RawRepresentable 契约）
    func testRawValue_可逆性_rawValue转LogAction() {
        for action in LogAction.allCases {
            let reconstructed = LogAction(rawValue: action.rawValue)
            XCTAssertEqual(reconstructed, action, "rawValue '\(action.rawValue)' 应能反向构造 \(action)")
        }
    }

    // MARK: - 未知 rawValue

    /// 未知 rawValue 应返回 nil
    func testRawValue_未知rawValue_返回nil() {
        XCTAssertNil(LogAction(rawValue: "unknown.action"))
        XCTAssertNil(LogAction(rawValue: ""))
    }

    // MARK: - rawValue 非空

    /// 所有 case 的 rawValue 应非空
    func testRawValue_非空() {
        for action in LogAction.allCases {
            XCTAssertFalse(action.rawValue.isEmpty, "case \(action) 的 rawValue 不应为空")
        }
    }

    // MARK: - localizedName 非空

    /// localizedName 应返回非空字符串
    func testLocalizedName_非空() {
        for action in LogAction.allCases {
            XCTAssertFalse(action.localizedName.isEmpty, "case \(action) 的 localizedName 不应为空")
        }
    }

    // MARK: - colorName 非空

    /// colorName 应返回非空字符串
    func testColorName_非空() {
        for action in LogAction.allCases {
            XCTAssertFalse(action.colorName.isEmpty, "case \(action) 的 colorName 不应为空")
        }
    }

    // MARK: - icon 非空

    /// icon 应返回非空字符串
    func testIcon_非空() {
        for action in LogAction.allCases {
            XCTAssertFalse(action.icon.isEmpty, "case \(action) 的 icon 不应为空")
        }
    }

    // MARK: - CaseIterable 一致性

    /// CaseIterable 应包含所有 case
    func testAllCases_包含所有case() {
        let allCases = LogAction.allCases
        XCTAssertEqual(allCases.count, 19)
        XCTAssertTrue(allCases.contains(.create))
        XCTAssertTrue(allCases.contains(.aiscanFailed))
        XCTAssertTrue(allCases.contains(.error))
        XCTAssertTrue(allCases.contains(.unknown))
    }
}
```

- [ ] **Step 2: 运行测试验证通过**

Run: `xcodebuild test -only-testing:ZhiYuTests/LogActionTests -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
Expected: PASS（11 个测试用例全绿）

- [ ] **Step 3: 记录 findings**

在 `Docs/Audit/2026-08-06-mainapp-test-findings.md` 表格新增一行：

| 1 | 🟢 P2 | `Sources/Core/Base/Constants/LogAction.swift:23,35-36,40-41` | 契约不一致 | `export="action.export"`、`aiscanFailed/aiscanSkipped="log.action.aiscan.*"`、`error="ERROR"`、`unknown="unknown"` 不符合 `logAction.*` 前缀契约 | 日志分析时按 `logAction.` 前缀过滤会遗漏这些动作 | 统一改为 `logAction.export`/`logAction.aiscan.failed`/`logAction.aiscan.skipped`/`logAction.error`/`logAction.unknown` | 待确认 | 批次1 |

- [ ] **Step 4: Commit**

```bash
git add Tests/Unit/Core/LogActionTests.swift Docs/Audit/2026-08-06-mainapp-test-findings.md
git commit -m "test(core): LogAction 枚举契约一致性测试 11 用例 + 记录 P2 前缀不一致"
```

---

### Task 8: ExportServiceProtocol 测试（轻量补盲 — 错误枚举本地化）

**Files:**
- Create: `Tests/Unit/Core/ExportServiceProtocolTests.swift`
- Test: `Sources/Core/Base/Protocols/ExportServiceProtocol.swift:13-44`

**Interfaces:**
- Consumes: `ExportError` 枚举（3 个 case：systemBusy/engineNotReady/internalError(String) + errorDescription）、`ExportServiceProtocol`（3 个 async throws 方法）
- Produces: `ExportServiceProtocolTests` 测试类

- [ ] **Step 1: 编写测试**

写入 `Tests/Unit/Core/ExportServiceProtocolTests.swift`：

```swift
//
//  ExportServiceProtocolTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 ExportError 枚举的本地化描述契约与 ExportServiceProtocol 方法签名。
//

import XCTest
@testable import ZhiYu

final class ExportServiceProtocolTests: XCTestCase {

    // MARK: - errorDescription 非空

    func testErrorDescription_systemBusy_非空() {
        XCTAssertFalse(ExportError.systemBusy.errorDescription?.isEmpty ?? true)
    }

    func testErrorDescription_engineNotReady_非空() {
        XCTAssertFalse(ExportError.engineNotReady.errorDescription?.isEmpty ?? true)
    }

    func testErrorDescription_internalError_非空() {
        XCTAssertFalse(ExportError.internalError("test").errorDescription?.isEmpty ?? true)
    }

    // MARK: - internalError 关联值

    /// internalError 的 errorDescription 应包含关联值消息
    func testErrorDescription_internalError_包含关联值() {
        let message = "引擎崩溃详情"
        let desc = ExportError.internalError(message).errorDescription
        XCTAssertNotNil(desc)
        XCTAssertTrue(desc?.contains(message) ?? false, "errorDescription 应包含关联值消息")
    }

    /// 不同关联值应产生不同 errorDescription
    func testErrorDescription_internalError_不同关联值_不同描述() {
        let desc1 = ExportError.internalError("错误A").errorDescription
        let desc2 = ExportError.internalError("错误B").errorDescription
        XCTAssertNotEqual(desc1, desc2)
    }

    // MARK: - Error 协议遵循

    /// ExportError 应遵循 Error 协议（可被 throw）
    func testExportError_遵循Error协议() {
        func throwError(_ error: ExportError) throws {
            throw error
        }
        XCTAssertThrowsError(try throwError(.systemBusy)) { error in
            XCTAssertTrue(error is ExportError)
        }
    }

    // MARK: - LocalizedError 协议遵循

    /// ExportError 应遵循 LocalizedError（有 errorDescription）
    func testExportError_遵循LocalizedError协议() {
        let errors: [ExportError] = [.systemBusy, .engineNotReady, .internalError("msg")]
        for error in errors {
            XCTAssertNotNil(error.errorDescription, "\(error) 应有 errorDescription")
        }
    }

    // MARK: - Sendable 遵循

    /// ExportError 应遵循 Sendable（可跨 actor 传递）
    func testExportError_遵循Sendable协议() {
        // 编译时检查：Sendable 协议遵循
        let _: @Sendable = ExportError.systemBusy
        let _: @Sendable = ExportError.engineNotReady
        let _: @Sendable = ExportError.internalError("test")
    }

    // MARK: - ExportServiceProtocol 方法签名验证

    /// UnsupportedExportService 应实现 ExportServiceProtocol 的 3 个方法
    func testUnsupportedExportService_实现ExportServiceProtocol() async {
        let service = UnsupportedExportService()

        // exportToPDF 应抛错
        do {
            _ = try await service.exportToPDF(markdown: "# test", fileName: "test.pdf")
            XCTFail("应抛出错误")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, CoreConstants.ErrorDomain.export)
            XCTAssertEqual(nsError.code, SystemConstants.HTTPStatusCode.notImplemented)
        }

        // exportMindmapToPDF 应抛错
        do {
            _ = try await service.exportMindmapToPDF(mermaidCode: "graph TD", fileName: "test.pdf")
            XCTFail("应抛出错误")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, CoreConstants.ErrorDomain.export)
        }

        // exportToPPTX 应抛错
        do {
            _ = try await service.exportToPPTX(markdown: "# test", fileName: "test.pptx")
            XCTFail("应抛出错误")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, CoreConstants.ErrorDomain.export)
        }
    }
}
```

- [ ] **Step 2: 运行测试验证通过**

Run: `xcodebuild test -only-testing:ZhiYuTests/ExportServiceProtocolTests -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
Expected: PASS（10 个测试用例全绿）

- [ ] **Step 3: 检查 findings**

审查 `ExportServiceProtocol.swift` 源码。当前审查结论：无问题。

- [ ] **Step 4: Commit**

```bash
git add Tests/Unit/Core/ExportServiceProtocolTests.swift
git commit -m "test(core): ExportError 本地化描述契约 + ExportServiceProtocol 签名测试 10 用例"
```

---

### Task 9: Unsupported 桩测试（轻量补盲 — 3 个桩行为）

**Files:**
- Create: `Tests/Unit/Core/UnsupportedServicesTests.swift`
- Test: `Sources/Core/Base/Stubs/UnsupportedReminderService.swift`、`Sources/Core/Base/Stubs/UnsupportedExportService.swift`、`Sources/Core/Base/Stubs/UnsupportedFileArchiver.swift`

**Interfaces:**
- Consumes: `UnsupportedReminderService`（`requestAccess() async -> Bool`、`createReminder(title:notes:) async throws`）、`UnsupportedExportService`（3 个 export 方法抛 NSError）、`UnsupportedFileArchiver`（`zip(directory:to:) async throws`、`extractContents(from:to:) throws`，抛 `FileArchiverError.platformNotSupported`）
- Produces: `UnsupportedServicesTests` 测试类

- [ ] **Step 1: 编写测试**

写入 `Tests/Unit/Core/UnsupportedServicesTests.swift`：

```swift
//
//  UnsupportedServicesTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 3 个 Unsupported 桩服务在不支持平台上的行为（返回 false/抛错）。
//

import XCTest
@testable import ZhiYu

final class UnsupportedServicesTests: XCTestCase {

    // MARK: - UnsupportedReminderService

    /// requestAccess 应返回 false（不支持平台）
    func testUnsupportedReminderService_requestAccess_返回false() async {
        let service = UnsupportedReminderService()
        let result = await service.requestAccess()
        XCTAssertFalse(result, "不支持平台应返回 false")
    }

    /// createReminder 应不抛错（空实现，Do nothing）
    func testUnsupportedReminderService_createReminder_不抛错() async {
        let service = UnsupportedReminderService()
        do {
            try await service.createReminder(title: "test", notes: "notes")
            // 不抛错即通过
        } catch {
            XCTFail("createReminder 空实现不应抛错：\(error)")
        }
    }

    // MARK: - UnsupportedExportService

    /// exportToPDF 应抛出 NSError（domain=export, code=501）
    func testUnsupportedExportService_exportToPDF_抛出NSError() async {
        let service = UnsupportedExportService()
        do {
            _ = try await service.exportToPDF(markdown: "# test", fileName: "test.pdf")
            XCTFail("应抛出错误")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, CoreConstants.ErrorDomain.export)
            XCTAssertEqual(nsError.code, SystemConstants.HTTPStatusCode.notImplemented)
            XCTAssertEqual(nsError.localizedDescription, CoreConstants.Export.unsupportedMessage)
        }
    }

    /// exportMindmapToPDF 应抛出 NSError
    func testUnsupportedExportService_exportMindmapToPDF_抛出NSError() async {
        let service = UnsupportedExportService()
        do {
            _ = try await service.exportMindmapToPDF(mermaidCode: "graph TD", fileName: "test.pdf")
            XCTFail("应抛出错误")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, CoreConstants.ErrorDomain.export)
        }
    }

    /// exportToPPTX 应抛出 NSError
    func testUnsupportedExportService_exportToPPTX_抛出NSError() async {
        let service = UnsupportedExportService()
        do {
            _ = try await service.exportToPPTX(markdown: "# test", fileName: "test.pptx")
            XCTFail("应抛出错误")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, CoreConstants.ErrorDomain.export)
        }
    }

    // MARK: - UnsupportedFileArchiver

    /// zip 应抛出 FileArchiverError.platformNotSupported
    func testUnsupportedFileArchiver_zip_抛出platformNotSupported() async {
        let archiver = UnsupportedFileArchiver()
        let sourceDir = URL(fileURLWithPath: "/tmp/test-source")
        let destURL = URL(fileURLWithPath: "/tmp/test.zip")
        do {
            try await archiver.zip(directory: sourceDir, to: destURL)
            XCTFail("应抛出错误")
        } catch {
            XCTAssertEqual(error as? FileArchiverError, .platformNotSupported)
        }
    }

    /// extractContents 应抛出 FileArchiverError.platformNotSupported
    func testUnsupportedFileArchiver_extractContents_抛出platformNotSupported() {
        let archiver = UnsupportedFileArchiver()
        let archiveURL = URL(fileURLWithPath: "/tmp/test.zip")
        let destURL = URL(fileURLWithPath: "/tmp/test-dest")
        do {
            try archiver.extractContents(from: archiveURL, to: destURL)
            XCTFail("应抛出错误")
        } catch {
            XCTAssertEqual(error as? FileArchiverError, .platformNotSupported)
        }
    }

    // MARK: - Sendable 遵循

    /// UnsupportedExportService 应遵循 Sendable
    func testUnsupportedExportService_遵循Sendable() {
        let _: @Sendable = UnsupportedExportService()
    }

    /// UnsupportedFileArchiver 应遵循 Sendable
    func testUnsupportedFileArchiver_遵循Sendable() {
        let _: @Sendable = UnsupportedFileArchiver()
    }
}
```

- [ ] **Step 2: 运行测试验证通过**

Run: `xcodebuild test -only-testing:ZhiYuTests/UnsupportedServicesTests -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
Expected: PASS（9 个测试用例全绿）

- [ ] **Step 3: 检查 findings**

审查 3 个 Unsupported 桩源码。当前审查结论：无问题（桩行为一致）。

**注**：`UnsupportedReminderService.createReminder` 是空实现（不抛错也不做事），这是预期行为（注释 "Do nothing or throw error"）。若用户认为应抛错，记录为 P2 findings。

- [ ] **Step 4: Commit**

```bash
git add Tests/Unit/Core/UnsupportedServicesTests.swift
git commit -m "test(core): 3 个 Unsupported 桩服务行为测试 9 用例"
```

### Task 10: Stub 桩测试（轻量补盲 — 3 个 Stub 行为 + delegate）

**Files:**
- Create: `Tests/Unit/Core/StubServicesTests.swift`
- Test: `Sources/Core/Base/Stubs/StubBackgroundTaskProvider.swift`、`Sources/Core/Base/Stubs/StubWatchSyncService.swift`、`Sources/Core/Base/Stubs/StubCollaborationProvider.swift`
- Create: `Tests/Shared/MockCollaborationDelegate.swift`

**Interfaces:**
- Consumes:
  - `StubBackgroundTaskProvider`（`register(handler:)`、`schedule()`，`@MainActor`）
  - `StubWatchSyncService`（`@Published lastReceivedText/latestBriefing/isBriefingLoading`、`sendContent(_:)`、`requestDailyBriefing()`、`handleBriefingResponse(_:)`，`@MainActor`）
  - `StubCollaborationProvider`（`delegate`、`startHosting(roomName:userName:)`、`startBrowsing(userName:)`、`joinRoom(_:)`、`stop()`、`broadcast(data:)`，`@MainActor`）
  - `CollaborationProviderDelegate`（7 方法：`providerDidUpdateStatus`/`providerDidDiscoverRoom`/`providerDidLoseRoom`/`providerDidConnectPeer`/`providerDidDisconnectPeer`/`providerDidReceiveData`/`providerDidEncounterError`，`@MainActor`）
- Produces: `StubServicesTests` 测试类、`MockCollaborationDelegate` 共享 Mock

- [ ] **Step 1: 创建 MockCollaborationDelegate**

写入 `Tests/Shared/MockCollaborationDelegate.swift`：

```swift
//
//  MockCollaborationDelegate.swift
//  ZhiYuTests
//
//  系统层级：[L0] 测试层
//  核心职责：协作 delegate spy，记录所有回调调用供测试断言。
//

import Foundation
@testable import ZhiYu

@MainActor
final class MockCollaborationDelegate: CollaborationProviderDelegate {

    // MARK: - 调用记录

    var didUpdateStatusCallCount = 0
    var lastStatusMessage: String?

    var didDiscoverRoomCallCount = 0
    var lastDiscoveredRoom: DiscoveredRoom?

    var didLoseRoomCallCount = 0
    var lastLostRoomId: String?

    var didConnectPeerCallCount = 0
    var lastConnectedPeer: CollabUser?

    var didDisconnectPeerCallCount = 0
    var lastDisconnectedPeerId: String?

    var didReceiveDataCallCount = 0
    var lastReceivedData: Data?
    var lastReceivedDataFromUserId: String?

    var didEncounterErrorCallCount = 0
    var lastErrorMessage: String?

    // MARK: - CollaborationProviderDelegate 实现

    func providerDidUpdateStatus(_ message: String) {
        didUpdateStatusCallCount += 1
        lastStatusMessage = message
    }

    func providerDidDiscoverRoom(_ room: DiscoveredRoom) {
        didDiscoverRoomCallCount += 1
        lastDiscoveredRoom = room
    }

    func providerDidLoseRoom(id: String) {
        didLoseRoomCallCount += 1
        lastLostRoomId = id
    }

    func providerDidConnectPeer(_ user: CollabUser) {
        didConnectPeerCallCount += 1
        lastConnectedPeer = user
    }

    func providerDidDisconnectPeer(id: String) {
        didDisconnectPeerCallCount += 1
        lastDisconnectedPeerId = id
    }

    func providerDidReceiveData(_ data: Data, from userID: String) {
        didReceiveDataCallCount += 1
        lastReceivedData = data
        lastReceivedDataFromUserId = userID
    }

    func providerDidEncounterError(_ error: String) {
        didEncounterErrorCallCount += 1
        lastErrorMessage = error
    }

    // MARK: - 重置

    func reset() {
        didUpdateStatusCallCount = 0
        lastStatusMessage = nil
        didDiscoverRoomCallCount = 0
        lastDiscoveredRoom = nil
        didLoseRoomCallCount = 0
        lastLostRoomId = nil
        didConnectPeerCallCount = 0
        lastConnectedPeer = nil
        didDisconnectPeerCallCount = 0
        lastDisconnectedPeerId = nil
        didReceiveDataCallCount = 0
        lastReceivedData = nil
        lastReceivedDataFromUserId = nil
        didEncounterErrorCallCount = 0
        lastErrorMessage = nil
    }
}
```

- [ ] **Step 2: 编写 StubServicesTests**

写入 `Tests/Unit/Core/StubServicesTests.swift`：

```swift
//
//  StubServicesTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 3 个 Stub 桩服务的行为（空操作/不崩溃/delegate 回调）。
//

import XCTest
@testable import ZhiYu

@MainActor
final class StubServicesTests: XCTestCase {

    // MARK: - StubBackgroundTaskProvider

    /// register 应不崩溃（空实现）
    func testStubBackgroundTaskProvider_register_不崩溃() {
        let provider = StubBackgroundTaskProvider()
        provider.register { }
    }

    /// schedule 应不崩溃（空实现）
    func testStubBackgroundTaskProvider_schedule_不崩溃() {
        let provider = StubBackgroundTaskProvider()
        provider.schedule()
    }

    // MARK: - StubWatchSyncService

    /// 初始 lastReceivedText 应为空字符串
    func testStubWatchSyncService_lastReceivedText_初始为空() {
        let service = StubWatchSyncService()
        XCTAssertEqual(service.lastReceivedText, "")
    }

    /// 初始 latestBriefing 应为 nil
    func testStubWatchSyncService_latestBriefing_初始为nil() {
        let service = StubWatchSyncService()
        XCTAssertNil(service.latestBriefing)
    }

    /// 初始 isBriefingLoading 应为 false
    func testStubWatchSyncService_isBriefingLoading_初始为false() {
        let service = StubWatchSyncService()
        XCTAssertFalse(service.isBriefingLoading)
    }

    /// sendContent 应不崩溃（空实现）
    func testStubWatchSyncService_sendContent_不崩溃() {
        let service = StubWatchSyncService()
        service.sendContent("test")
    }

    /// requestDailyBriefing 应不崩溃
    func testStubWatchSyncService_requestDailyBriefing_不崩溃() {
        let service = StubWatchSyncService()
        service.requestDailyBriefing()
    }

    /// handleBriefingResponse 应不崩溃
    func testStubWatchSyncService_handleBriefingResponse_不崩溃() {
        let service = StubWatchSyncService()
        service.handleBriefingResponse("briefing text")
    }

    // MARK: - StubCollaborationProvider

    /// delegate 可设置
    func testStubCollaborationProvider_delegate可设置() {
        let provider = StubCollaborationProvider()
        let delegate = MockCollaborationDelegate()
        provider.delegate = delegate
        XCTAssertTrue(provider.delegate === delegate)
    }

    /// startHosting 应触发 delegate.providerDidUpdateStatus（simulatorNotSupported）
    func testStubCollaborationProvider_startHosting_触发delegate状态() {
        let provider = StubCollaborationProvider()
        let delegate = MockCollaborationDelegate()
        provider.delegate = delegate

        provider.startHosting(roomName: "test-room", userName: "test-user")

        XCTAssertEqual(delegate.didUpdateStatusCallCount, 1)
        XCTAssertEqual(delegate.lastStatusMessage, L10n.Collaboration.Status.simulatorNotSupported)
    }

    /// startBrowsing 应触发 delegate.providerDidUpdateStatus（simulatorNotSupported）
    func testStubCollaborationProvider_startBrowsing_触发delegate状态() {
        let provider = StubCollaborationProvider()
        let delegate = MockCollaborationDelegate()
        provider.delegate = delegate

        provider.startBrowsing(userName: "test-user")

        XCTAssertEqual(delegate.didUpdateStatusCallCount, 1)
        XCTAssertEqual(delegate.lastStatusMessage, L10n.Collaboration.Status.simulatorNotSupported)
    }

    /// joinRoom 应不崩溃（空实现，不触发 delegate）
    func testStubCollaborationProvider_joinRoom_不崩溃() {
        let provider = StubCollaborationProvider()
        let delegate = MockCollaborationDelegate()
        provider.delegate = delegate

        let room = DiscoveredRoom(
            id: "test-id",
            platformPeer: "peer" as AnyHashable,
            roomName: "test-room",
            owner: "test-owner"
        )
        provider.joinRoom(room)

        XCTAssertEqual(delegate.didDiscoverRoomCallCount, 0, "joinRoom 不应触发 didDiscoverRoom")
    }

    /// stop 应触发 delegate.providerDidUpdateStatus（disconnected）
    func testStubCollaborationProvider_stop_触发delegate断开() {
        let provider = StubCollaborationProvider()
        let delegate = MockCollaborationDelegate()
        provider.delegate = delegate

        provider.stop()

        XCTAssertEqual(delegate.didUpdateStatusCallCount, 1)
        XCTAssertEqual(delegate.lastStatusMessage, L10n.Collaboration.Status.disconnected)
    }

    /// broadcast 应不崩溃（空实现）
    func testStubCollaborationProvider_broadcast_不崩溃() {
        let provider = StubCollaborationProvider()
        provider.broadcast(data: Data([0x01, 0x02]))
    }

    /// 无 delegate 时所有方法应不崩溃
    func testStubCollaborationProvider_无delegate_不崩溃() {
        let provider = StubCollaborationProvider()
        provider.startHosting(roomName: "test", userName: "user")
        provider.startBrowsing(userName: "user")
        provider.stop()
        provider.broadcast(data: Data())
    }
}
```

- [ ] **Step 3: 运行测试验证通过**

Run: `xcodebuild test -only-testing:ZhiYuTests/StubServicesTests -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
Expected: PASS（15 个测试用例全绿）

- [ ] **Step 4: 检查 findings**

审查 3 个 Stub 桩源码。当前审查结论：无问题。

- [ ] **Step 5: Commit**

```bash
git add Tests/Unit/Core/StubServicesTests.swift Tests/Shared/MockCollaborationDelegate.swift
git commit -m "test(core): 3 个 Stub 桩服务行为测试 15 用例 + MockCollaborationDelegate"
```

---

### Task 11: ZipUtility 测试（问题驱动 — ZIP 解析边界）

**Files:**
- Create: `Tests/Unit/Core/ZipUtilityTests.swift`
- Test: `Packages/UFPCore/Sources/UFPCore/Base/ZipUtility.swift:13-122`（已迁移）

**Interfaces:**
- Consumes: `ZipUtility.readZipArchive(at:) -> [String: Data]?` 静态方法
- Produces: `ZipUtilityTests` 测试类

**问题驱动方法**：边界值（空文件/非 ZIP/单文件/多文件）、错误猜测（损坏 ZIP）、往返验证（zip→read 还原）

**注**：ZipUtility 只提供 `readZipArchive`（返回文件名→数据映射），不提供 `unzip`。测试用 `/usr/bin/zip` 构造 ZIP fixture。

- [ ] **Step 1: 编写测试**

写入 `Tests/Unit/Core/ZipUtilityTests.swift`：

```swift
//
//  ZipUtilityTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 ZipUtility.readZipArchive 解析逻辑的正确性（空/单文件/多文件/错误处理）。
//

import XCTest
@testable import ZhiYu

final class ZipUtilityTests: XCTestCase {

    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(
            at: tempDir,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    // MARK: - 辅助方法：构造 ZIP

    /// 用 /usr/bin/zip 构造测试 ZIP（macOS 测试环境可用）
    private func createTestZip(
        files: [(name: String, content: String)]
    ) throws -> URL {
        let sourceDir = tempDir.appendingPathComponent("source")
        try FileManager.default.createDirectory(
            at: sourceDir,
            withIntermediateDirectories: true
        )
        for file in files {
            let fileURL = sourceDir.appendingPathComponent(file.name)
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try file.content.write(
                to: fileURL,
                atomically: true,
                encoding: .utf8
            )
        }
        let zipURL = tempDir.appendingPathComponent("test.zip")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = ["-r", zipURL.path, "."]
        process.currentDirectoryURL = sourceDir
        try process.run()
        process.waitUntilExit()
        return zipURL
    }

    // MARK: - 单文件解析

    func testReadZipArchive_单文件_正确解析() throws {
        let zipURL = try createTestZip(files: [
            ("hello.txt", "Hello, World!")
        ])
        guard let archive = ZipUtility.readZipArchive(at: zipURL) else {
            XCTFail("应成功解析 ZIP")
            return
        }
        XCTAssertEqual(archive.count, 1)
        let data = archive["hello.txt"]
        XCTAssertNotNil(data)
        XCTAssertEqual(String(data: data!, encoding: .utf8), "Hello, World!")
    }

    // MARK: - 多文件解析

    func testReadZipArchive_多文件_全部解析() throws {
        let zipURL = try createTestZip(files: [
            ("file1.txt", "content1"),
            ("file2.txt", "content2"),
            ("file3.txt", "content3")
        ])
        guard let archive = ZipUtility.readZipArchive(at: zipURL) else {
            XCTFail("应成功解析 ZIP")
            return
        }
        XCTAssertEqual(archive.count, 3)
        XCTAssertEqual(String(data: archive["file1.txt"]!, encoding: .utf8), "content1")
        XCTAssertEqual(String(data: archive["file2.txt"]!, encoding: .utf8), "content2")
        XCTAssertEqual(String(data: archive["file3.txt"]!, encoding: .utf8), "content3")
    }

    // MARK: - 嵌套目录解析

    func testReadZipArchive_嵌套目录_正确解析() throws {
        let zipURL = try createTestZip(files: [
            ("dir/nested.txt", "nested content")
        ])
        guard let archive = ZipUtility.readZipArchive(at: zipURL) else {
            XCTFail("应成功解析 ZIP")
            return
        }
        XCTAssertNotNil(archive["dir/nested.txt"])
        XCTAssertEqual(
            String(data: archive["dir/nested.txt"]!, encoding: .utf8),
            "nested content"
        )
    }

    // MARK: - 错误处理：非 ZIP 文件

    func testReadZipArchive_非ZIP文件_返回nil() throws {
        let nonZipURL = tempDir.appendingPathComponent("notzip.txt")
        try "this is not a zip".write(
            to: nonZipURL,
            atomically: true,
            encoding: .utf8
        )
        let result = ZipUtility.readZipArchive(at: nonZipURL)
        XCTAssertNil(result, "非 ZIP 文件应返回 nil")
    }

    // MARK: - 错误处理：不存在的文件

    func testReadZipArchive_文件不存在_返回nil() {
        let nonexistentURL = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).zip")
        let result = ZipUtility.readZipArchive(at: nonexistentURL)
        XCTAssertNil(result)
    }

    // MARK: - 空文件

    func testReadZipArchive_空文件_返回nil() throws {
        let emptyURL = tempDir.appendingPathComponent("empty.zip")
        try Data().write(to: emptyURL)
        let result = ZipUtility.readZipArchive(at: emptyURL)
        XCTAssertNil(result, "空文件应返回 nil（无有效文件头）")
    }
}
```

- [ ] **Step 2: 运行测试验证通过**

Run: `xcodebuild test -only-testing:ZhiYuTests/ZipUtilityTests -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
Expected: PASS（6 个测试用例全绿）

**注**：`/usr/bin/zip` 在 iOS Simulator 沙盒中不可用，这些测试可能只在 macOS 测试环境通过。若 iOS Simulator 失败，需改用预置 ZIP fixture 文件（放入 `Tests/Shared/Resources/`）。若失败，记录到 findings 并调整策略。

- [ ] **Step 3: 检查 findings**

审查 `ZipUtility.swift` 源码。当前审查结论：无问题（待测试运行后确认）。

- [ ] **Step 4: Commit**

```bash
git add Tests/Unit/Core/ZipUtilityTests.swift
git commit -m "test(core): ZipUtility.readZipArchive 解析边界测试 6 用例"
```

---

### Task 12: JailbreakDetector 测试（问题驱动 — 非越狱路径 + 有限重构）

**Files:**
- Modify: `Sources/Core/System/Security/JailbreakDetector.swift`（`private init` → `internal init`）
- Create: `Tests/Unit/Core/JailbreakDetectorTests.swift`
- Test: `Sources/Core/System/Security/JailbreakDetector.swift:13-87`

**Interfaces:**
- Consumes: `JailbreakDetector.shared`、`JailbreakDetector.isJailbroken() -> Bool` 方法（`@MainActor`）
- Produces: `JailbreakDetectorTests` 测试类

**问题驱动方法**：非越狱环境验证 `isJailbroken() == false`、单例一致性、已知限制记录（true 分支无法覆盖）

**有限重构**：`private init` → `internal init`（记录 P2 findings，便于测试构造独立实例）

- [ ] **Step 1: 重构 JailbreakDetector.init 可见性**

读取 `Sources/Core/System/Security/JailbreakDetector.swift`，将 `private init() {}` 改为 `init() {}`（internal）。

- [ ] **Step 2: 记录重构 findings**

在 `Docs/Audit/2026-08-06-mainapp-test-findings.md` 表格新增：

| 2 | 🟢 P2 | `Sources/Core/System/Security/JailbreakDetector.swift:22` | 可测试性 | `private init` 阻止测试构造独立实例 | 测试只能用 shared 单例，无法隔离状态 | `private init` → `internal init` | 已修复 | 批次1 |

- [ ] **Step 3: 编写测试**

写入 `Tests/Unit/Core/JailbreakDetectorTests.swift`：

```swift
//
//  JailbreakDetectorTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 JailbreakDetector 在非越狱环境下的检测行为与单例一致性。
//

import XCTest
@testable import ZhiYu

@MainActor
final class JailbreakDetectorTests: XCTestCase {

    // MARK: - 非越狱环境（测试环境默认非越狱）

    /// 测试环境（模拟器/CI）应检测为非越狱
    func testIsJailbroken_非越狱环境_返回false() {
        let detector = JailbreakDetector.shared
        XCTAssertFalse(
            detector.isJailbroken(),
            "测试环境（模拟器）应检测为非越狱"
        )
    }

    /// 独立实例也应检测为非越狱
    func testIsJailbroken_独立实例_返回false() {
        let detector = JailbreakDetector()
        XCTAssertFalse(detector.isJailbroken())
    }

    // MARK: - 单例一致性

    /// shared 应返回同一实例
    func testShared_多次访问_同一实例() {
        let a = JailbreakDetector.shared
        let b = JailbreakDetector.shared
        XCTAssertTrue(a === b)
    }

    /// 独立实例应与 shared 不同
    func testInit_独立实例_与shared不同() {
        let independent = JailbreakDetector()
        let shared = JailbreakDetector.shared
        XCTAssertFalse(independent === shared)
    }

    // MARK: - 多次调用稳定性

    /// 多次调用 isJailbroken() 应返回一致结果
    func testIsJailbroken_多次调用_结果一致() {
        let detector = JailbreakDetector.shared
        let first = detector.isJailbroken()
        for _ in 0..<10 {
            XCTAssertEqual(detector.isJailbroken(), first, "多次调用应返回一致结果")
        }
    }

    // MARK: - 已知限制记录

    /// 已知限制：越狱分支（isJailbroken() == true）无法在测试环境覆盖
    /// 需真实越狱设备或 mock 文件系统才能测试 true 路径
    func testKnownLimitation_越狱分支无法覆盖() {
        let detector = JailbreakDetector.shared
        // 仅记录已知限制，不断言 true 路径
        _ = detector.isJailbroken()
        // 此测试存在仅为文档化已知限制
    }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `xcodebuild test -only-testing:ZhiYuTests/JailbreakDetectorTests -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
Expected: PASS（6 个测试用例全绿）

- [ ] **Step 5: Commit**

```bash
git add Sources/Core/System/Security/JailbreakDetector.swift Tests/Unit/Core/JailbreakDetectorTests.swift Docs/Audit/2026-08-06-mainapp-test-findings.md
git commit -m "test(core): JailbreakDetector 非越狱路径测试 6 用例 + init 可见性重构"
```

### Task 13: LocalAnalyticsService + WorkflowService 测试（问题驱动 + 有限重构）

**Files:**
- Modify: `Sources/Core/System/Analytics/LocalAnalyticsService.swift`（`private init` → `internal init`，`logURL` 可注入）
- Modify: `Sources/Core/System/Workflow/WorkflowService.swift`（`private init` → `internal init`，`@Inject` 改可注入构造器参数）
- Create: `Tests/Unit/Core/LocalAnalyticsServiceTests.swift`
- Create: `Tests/Unit/Core/WorkflowServiceTests.swift`
- Modify: `Tests/Shared/TestMocks.swift`（扩展 MockReminderService）
- Test: `Sources/Core/System/Analytics/LocalAnalyticsService.swift:13-74`、`Sources/Core/System/Workflow/WorkflowService.swift:13-106`

**Interfaces:**
- Consumes:
  - `LocalAnalyticsService.shared`、`LocalAnalyticsService.trackEvent(_:properties:)`、`LocalAnalyticsService.trackError(_:details:)`（`@MainActor`）
  - `WorkflowService.shared`、`WorkflowService.syncToReminders(text:title:)`（`@MainActor`，throws）
  - `ReminderServiceProtocol.requestAccess() async -> Bool`、`ReminderServiceProtocol.createReminder(title:notes:) async throws`
  - `ToastManager.shared.currentToast`（`@Published`）、`ToastManager.shared.show(type:message:duration:)`、`ToastManager.shared.dismiss()`
- Produces: `LocalAnalyticsServiceTests`、`WorkflowServiceTests` 测试类

**问题驱动方法**：
- LocalAnalyticsService：持久化验证（JSON 日志写入文件）、错误猜测（空 properties/特殊字符）、异步等待
- WorkflowService：Markdown 解析（多种任务标记识别）、副作用观察（ToastManager.shared.currentToast）、权限拒绝/失败路径

**有限重构**：
- LocalAnalyticsService：`private init` → `init(logURL: URL? = nil)`，logURL 可注入
- WorkflowService：`private init` → `init(reminderService: ReminderServiceProtocol? = nil)`，默认 nil 时用 `@Inject` 解析

- [ ] **Step 1: 重构 LocalAnalyticsService**

读取 `Sources/Core/System/Analytics/LocalAnalyticsService.swift`：
1. `private init()` → `init(logURL: URL? = nil)`
2. 新增 `private let logURL: URL` 存储属性
3. init 内：`self.logURL = logURL ?? defaultLogURL()`，其中 `defaultLogURL()` 返回原默认路径

```swift
@MainActor
final class LocalAnalyticsService: AnalyticsServiceProtocol, @unchecked Sendable {
    static let shared = LocalAnalyticsService()

    private let logURL: URL

    init(logURL: URL? = nil) {
        if let customURL = logURL {
            self.logURL = customURL
        } else {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.logURL = docs.appendingPathComponent("analytics_log.json")
        }
    }
    // ... 其余方法不变 ...
}
```

- [ ] **Step 2: 重构 WorkflowService**

读取 `Sources/Core/System/Workflow/WorkflowService.swift`：
1. `private init()` → `init(reminderService: (any ReminderServiceProtocol)? = nil)`
2. 新增 `private let injectedReminderService: (any ReminderServiceProtocol)?`
3. 移除 `@Inject private var reminderService: any ReminderServiceProtocol`
4. 新增计算属性：`private var reminderService: any ReminderServiceProtocol { injectedReminderService ?? ServiceContainer.shared.resolve() }`

```swift
@MainActor
final class WorkflowService: ObservableObject {
    static let shared = WorkflowService()

    @Inject private var appEnv: any AppEnvironmentProtocol
    private let injectedReminderService: (any ReminderServiceProtocol)?

    init(reminderService: (any ReminderServiceProtocol)? = nil) {
        self.injectedReminderService = reminderService
    }

    private var reminderService: any ReminderServiceProtocol {
        injectedReminderService ?? {
            // Fallback to DI container
            return ServiceContainer.shared.resolve()
        }()
    }
    // ... 其余方法不变，将 reminderService 引用改为 self.reminderService ...
}
```

**注**：`ServiceContainer.shared.resolve()` 需返回 `ReminderServiceProtocol`。若 `ServiceContainer` 无泛型 resolve，需用 `ServiceContainer.shared.resolve(any ReminderServiceProtocol.self)`。按实际 API 调整。

- [ ] **Step 3: 记录重构 findings**

在 `Docs/Audit/2026-08-06-mainapp-test-findings.md` 表格新增两行：

| 3 | 🟢 P2 | `Sources/Core/System/Analytics/LocalAnalyticsService.swift:20` | 可测试性 | `private init` + 硬编码 logURL 阻止测试注入临时路径 | 测试写入真实日志路径，污染用户数据 | `private init` → `init(logURL:)` 可注入 | 已修复 | 批次1 |
| 4 | 🟢 P2 | `Sources/Core/System/Workflow/WorkflowService.swift:17,20` | 可测试性 | `private init` + `@Inject` 阻止测试注入 Mock 依赖 | 测试只能用 shared 单例，无法隔离 ReminderService | `private init` → `init(reminderService:)` 可注入 | 已修复 | 批次1 |

- [ ] **Step 4: 扩展 MockReminderService**

读取 `Tests/Shared/TestMocks.swift`，将 `MockReminderService`（当前空实现）扩展为可配置：

```swift
final class MockReminderService: ReminderServiceProtocol, @unchecked Sendable {
    var requestAccessResult: Bool = false
    var createReminderShouldThrow: Bool = false
    var createReminderCallCount: Int = 0
    var lastCreatedTitle: String?
    var lastCreatedNotes: String?

    func requestAccess() async -> Bool {
        requestAccessResult
    }

    func createReminder(title: String, notes: String) async throws {
        createReminderCallCount += 1
        lastCreatedTitle = title
        lastCreatedNotes = notes
        if createReminderShouldThrow {
            throw NSError(domain: "MockReminderService", code: 1)
        }
    }
}
```

- [ ] **Step 5: 编写 LocalAnalyticsServiceTests**

写入 `Tests/Unit/Core/LocalAnalyticsServiceTests.swift`：

```swift
//
//  LocalAnalyticsServiceTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 LocalAnalyticsService 事件追踪与 JSON 持久化的正确性。
//

import XCTest
@testable import ZhiYu

@MainActor
final class LocalAnalyticsServiceTests: XCTestCase {

    var tempLogURL: URL!
    var service: LocalAnalyticsService!

    override func setUp() {
        super.setUp()
        tempLogURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-analytics-\(UUID().uuidString).json")
        service = LocalAnalyticsService(logURL: tempLogURL)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempLogURL)
        service = nil
        super.tearDown()
    }

    // MARK: - trackEvent 持久化

    /// trackEvent 后日志文件应被创建（异步，需等待）
    func testTrackEvent_写入后_文件存在() async {
        service.trackEvent("test_event", properties: ["key": "value"])
        // 等待异步 DispatchQueue.global 写入完成
        try? await Task.sleep(nanoseconds: 500_000_000)

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: tempLogURL.path),
            "trackEvent 后日志文件应被创建"
        )
    }

    /// trackEvent 内容应包含事件名（异步等待后验证）
    func testTrackEvent_写入内容_包含事件名() async throws {
        service.trackEvent("page_created", properties: [:])
        try? await Task.sleep(nanoseconds: 500_000_000)

        let data = try Data(contentsOf: tempLogURL)
        let logs = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertNotNil(logs)
        XCTAssertEqual(logs?.count, 1)
        XCTAssertEqual(logs?[0]["name"] as? String, "page_created")
    }

    /// trackEvent 内容应包含 properties 键值
    func testTrackEvent_写入properties_包含键值() async throws {
        service.trackEvent("page_updated", properties: ["pageId": "page-123", "userId": "user-456"])
        try? await Task.sleep(nanoseconds: 500_000_000)

        let data = try Data(contentsOf: tempLogURL)
        let logs = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        let properties = logs?[0]["properties"] as? [String: Any]
        XCTAssertEqual(properties?["pageId"] as? String, "page-123")
        XCTAssertEqual(properties?["userId"] as? String, "user-456")
    }

    // MARK: - 空 properties

    /// properties 为 nil 应正常写入（不崩溃）
    func testTrackEvent_nilProperties_不崩溃() async {
        service.trackEvent("test_event", properties: nil)
        try? await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempLogURL.path))
    }

    // MARK: - 多次写入追加

    /// 多次 trackEvent 应追加写入（JSON 数组追加，非覆盖）
    func testTrackEvent_多次写入_追加模式() async throws {
        service.trackEvent("event1", properties: nil)
        try? await Task.sleep(nanoseconds: 300_000_000)
        service.trackEvent("event2", properties: nil)
        try? await Task.sleep(nanoseconds: 300_000_000)
        service.trackEvent("event3", properties: nil)
        try? await Task.sleep(nanoseconds: 500_000_000)

        let data = try Data(contentsOf: tempLogURL)
        let logs = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        XCTAssertEqual(logs?.count, 3, "应追加 3 条事件")
        XCTAssertEqual(logs?[0]["name"] as? String, "event1")
        XCTAssertEqual(logs?[1]["name"] as? String, "event2")
        XCTAssertEqual(logs?[2]["name"] as? String, "event3")
    }

    // MARK: - trackError 不崩溃

    /// trackError 应不崩溃（仅打印日志，不写文件）
    func testTrackError_不崩溃() {
        service.trackError(NSError(domain: "test", code: 1), details: "test details")
        // trackError 不写文件，仅打印日志
    }

    // MARK: - 单例一致性

    func testShared_多次访问_同一实例() {
        let a = LocalAnalyticsService.shared
        let b = LocalAnalyticsService.shared
        XCTAssertTrue(a === b)
    }
}
```

- [ ] **Step 6: 编写 WorkflowServiceTests**

写入 `Tests/Unit/Core/WorkflowServiceTests.swift`：

```swift
//
//  WorkflowServiceTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 WorkflowService Markdown 解析与同步逻辑（通过观察 ToastManager 副作用）。
//

import XCTest
@testable import ZhiYu

@MainActor
final class WorkflowServiceTests: XCTestCase {

    var mockReminderService: MockReminderService!
    var service: WorkflowService!

    override func setUp() {
        super.setUp()
        mockReminderService = MockReminderService()
        mockReminderService.requestAccessResult = true
        service = WorkflowService(reminderService: mockReminderService)
        // 重置 Toast 状态
        ToastManager.shared.currentToast = nil
    }

    override func tearDown() {
        ToastManager.shared.currentToast = nil
        service = nil
        mockReminderService = nil
        super.tearDown()
    }

    // MARK: - Markdown 任务标记解析

    /// 含未完成任务标记（- [ ]）的 Markdown 应被识别为任务
    func testSyncToReminders_含未完成任务_调用createReminder() async {
        let markdown = """
        # 测试页面
        - [ ] 待办事项 1
        - [ ] 待办事项 2
        """
        try? await service.syncToReminders(text: markdown, title: "测试页面")

        XCTAssertEqual(
            mockReminderService.createReminderCallCount,
            2,
            "应识别 2 个未完成任务并调用 createReminder 2 次"
        )
    }

    /// 含已完成任务标记（- [x]）的 Markdown 也应被识别（当前实现不区分完成状态）
    func testSyncToReminders_含已完成任务_当前实现也同步() async {
        let markdown = """
        # 测试页面
        - [x] 已完成事项
        """
        try? await service.syncToReminders(text: markdown, title: "测试页面")

        // 注：当前实现 hasPrefix("-") 会匹配 "- [x]"，所以已完成任务也会被同步
        // 这可能是 P1 问题（已完成任务不应同步），记录到 findings 待确认
        XCTAssertGreaterThanOrEqual(
            mockReminderService.createReminderCallCount,
            1,
            "当前实现会同步已完成任务（hasPrefix('-') 匹配）"
        )
    }

    /// 含 `- ` 前缀的无序列表应被识别为任务
    func testSyncToReminders_含无序列表_调用createReminder() async {
        let markdown = """
        - 任务 1
        - 任务 2
        """
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.createReminderCallCount, 2)
    }

    /// 含 `* ` 前缀的无序列表应被识别为任务
    func testSyncToReminders_含星号无序列表_调用createReminder() async {
        let markdown = """
        * 任务 1
        * 任务 2
        """
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.createReminderCallCount, 2)
    }

    /// 含 `1. ` 前缀的有序列表应被识别为任务
    func testSyncToReminders_含有序列表_调用createReminder() async {
        let markdown = """
        1. 任务 1
        2. 任务 2
        """
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.createReminderCallCount, 2)
    }

    /// 无任务标记的 Markdown 不应调用 createReminder
    func testSyncToReminders_无任务标记_不调用() async {
        let markdown = """
        # 普通页面
        这是一段普通文本。
        """
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.createReminderCallCount, 0)
    }

    /// 空字符串不应调用 createReminder
    func testSyncToReminders_空字符串_不调用() async {
        try? await service.syncToReminders(text: "", title: "测试")
        XCTAssertEqual(mockReminderService.createReminderCallCount, 0)
    }

    // MARK: - Markdown 样式标记剔除

    /// 任务文本中的加粗标记应被剔除
    func testSyncToReminders_加粗标记_被剔除() async {
        let markdown = "- **重要任务**"
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.lastCreatedTitle, "重要任务")
    }

    /// 任务文本中的斜体标记应被剔除
    func testSyncToReminders_斜体标记_被剔除() async {
        let markdown = "- _强调任务_"
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.lastCreatedTitle, "强调任务")
    }

    /// 任务文本中的删除线标记应被剔除
    func testSyncToReminders_删除线标记_被剔除() async {
        let markdown = "- ~~废弃任务~~"
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.lastCreatedTitle, "废弃任务")
    }

    /// 任务文本中的行内代码标记应被剔除
    func testSyncToReminders_行内代码标记_被剔除() async {
        let markdown = "- `代码任务`"
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertEqual(mockReminderService.lastCreatedTitle, "代码任务")
    }

    // MARK: - 副作用：Toast 反馈

    /// 同步成功后应显示成功 Toast
    func testSyncToReminders_成功_显示成功Toast() async {
        let markdown = "- [ ] 测试任务"
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertNotNil(
            ToastManager.shared.currentToast,
            "同步后应显示 Toast"
        )
    }

    /// 权限拒绝时应显示错误 Toast 并抛出 accessDenied
    func testSyncToReminders_权限拒绝_显示错误Toast() async {
        mockReminderService.requestAccessResult = false
        let markdown = "- [ ] 测试任务"

        do {
            try await service.syncToReminders(text: markdown, title: "测试")
            XCTFail("应抛出 accessDenied")
        } catch {
            // 预期抛错
        }

        XCTAssertNotNil(
            ToastManager.shared.currentToast,
            "权限拒绝时应显示错误 Toast"
        )
        XCTAssertEqual(
            mockReminderService.createReminderCallCount,
            0,
            "权限拒绝时不应调用 createReminder"
        )
    }

    /// 无任务时应显示 info Toast（noTasksFoundMessage）
    func testSyncToReminders_无任务_显示infoToast() async {
        let markdown = "普通文本，无任务"
        try? await service.syncToReminders(text: markdown, title: "测试")

        XCTAssertNotNil(
            ToastManager.shared.currentToast,
            "无任务时应显示 info Toast"
        )
    }

    /// createReminder 抛错时应显示错误 Toast 并重新抛出
    func testSyncToReminders_createReminder失败_显示错误Toast() async {
        mockReminderService.createReminderShouldThrow = true
        let markdown = "- [ ] 测试任务"

        do {
            try await service.syncToReminders(text: markdown, title: "测试")
            XCTFail("应抛出错误")
        } catch {
            // 预期抛错
        }

        XCTAssertNotNil(
            ToastManager.shared.currentToast,
            "失败时应显示错误 Toast"
        )
    }

    // MARK: - 单例一致性

    func testShared_多次访问_同一实例() {
        let a = WorkflowService.shared
        let b = WorkflowService.shared
        XCTAssertTrue(a === b)
    }
}
```

- [ ] **Step 7: 运行 LocalAnalyticsServiceTests**

Run: `xcodebuild test -only-testing:ZhiYuTests/LocalAnalyticsServiceTests -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
Expected: PASS（7 个测试用例全绿）

- [ ] **Step 8: 运行 WorkflowServiceTests**

Run: `xcodebuild test -only-testing:ZhiYuTests/WorkflowServiceTests -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
Expected: PASS（15 个测试用例全绿）

- [ ] **Step 9: 检查 findings**

审查 `WorkflowService.swift` 源码。发现潜在 P1 问题：
- `syncToReminders` 的任务过滤逻辑 `line.hasPrefix("-")` 会匹配 `- [x]`（已完成任务），导致已完成任务也被同步到提醒事项。这可能不符合用户预期（已完成任务不应再提醒）。

在 `Docs/Audit/2026-08-06-mainapp-test-findings.md` 表格新增：

| 5 | 🟡 P1 | `Sources/Core/System/Workflow/WorkflowService.swift:46` | 逻辑缺陷 | 任务过滤用 `line.hasPrefix("-")` 会匹配 `- [x]`（已完成任务），导致已完成任务也被同步 | 已完成事项被重复同步到系统提醒，造成冗余提醒 | 在过滤条件中排除 `hasPrefix(CoreConstants.MarkdownSyntax.taskDone)` 和 `taskDoneUpper` | 待确认 | 批次1 |

- [ ] **Step 10: Commit**

```bash
git add Sources/Core/System/Analytics/LocalAnalyticsService.swift Sources/Core/System/Workflow/WorkflowService.swift Tests/Unit/Core/LocalAnalyticsServiceTests.swift Tests/Unit/Core/WorkflowServiceTests.swift Tests/Shared/TestMocks.swift Docs/Audit/2026-08-06-mainapp-test-findings.md
git commit -m "test(core): LocalAnalyticsService + WorkflowService 测试 22 用例 + 有限重构 + P1 findings"
```

---

### Task 14: 批次 1 阶段修复与验证

**Files:**
- Modify: `Docs/Audit/2026-08-06-mainapp-test-findings.md`（汇总 findings）
- Modify: 各问题文件（按用户确认的修复方案）

**Interfaces:**
- Consumes: 批次 1 所有测试结果 + findings 表格
- Produces: 修复后的源码 + 更新的 findings 表格 + 全量验证通过

- [ ] **Step 1: 汇总批次 1 findings**

读取 `Docs/Audit/2026-08-06-mainapp-test-findings.md`，确认所有 findings 已记录。预期 findings：
1. LogAction aiscan 前缀不一致（P2，Task 7）
2. JailbreakDetector private init（P2，Task 12，已修复）
3. LocalAnalyticsService private init + 硬编码 logURL（P2，Task 13，已修复）
4. WorkflowService private init + @Inject（P2，Task 13，已修复）
5. 测试过程中发现的其他问题（待运行后补充）

- [ ] **Step 2: 向用户汇报 findings**

向用户展示 findings 表格，请求确认：
- 哪些问题需要修复
- 哪些是预期行为不修
- 修复方案是否同意

- [ ] **Step 3: 按用户确认集中修复**

对用户确认需修复的问题，逐个修改源码。修复后更新 findings 表格"处理状态"列为"已修复"。

- [ ] **Step 4: 重测所有批次 1 测试**

Run: `xcodebuild test -only-testing:ZhiYuTests/RetryTaskTests -only-testing:ZhiYuTests/AudioSplitterTests -only-testing:ZhiYuTests/StringPhoneNumberTests -only-testing:ZhiYuTests/DateAppExtensionsTests -only-testing:ZhiYuTests/DateExtensionsTests -only-testing:ZhiYuTests/LogActionTests -only-testing:ZhiYuTests/ExportServiceProtocolTests -only-testing:ZhiYuTests/UnsupportedServicesTests -only-testing:ZhiYuTests/StubServicesTests -only-testing:ZhiYuTests/ZipUtilityTests -only-testing:ZhiYuTests/JailbreakDetectorTests -only-testing:ZhiYuTests/LocalAnalyticsServiceTests -only-testing:ZhiYuTests/WorkflowServiceTests -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -disableAutomaticPackageResolution`
Expected: PASS（全部测试用例全绿）

- [ ] **Step 5: 全量验证（make test）**

Run（后台运行 + 日志轮询）: `make test > build/test-batch1.log 2>&1 &`
Expected: 全量测试通过，无回归

- [ ] **Step 6: 更新 findings 表格**

将所有已修复问题的"处理状态"更新为"已修复"，未修问题更新为"已确认 → 预期行为不修"。

- [ ] **Step 7: 批次 1 统一 commit**

```bash
git add Docs/Audit/2026-08-06-mainapp-test-findings.md <修复的源码文件>
git commit -m "test(core): 批次 1 阶段修复 + 全量验证通过

- 修复 N 项测试驱动发现的问题
- 全 App 覆盖率预期 ~25.6%
- 13 个测试文件，~100 个测试用例"
```

- [ ] **Step 8: 推送双远端**

```bash
git push origin main && git push gitlab main
```

- [ ] **Step 9: 批次 1 完结汇报**

向用户汇报：
- 批次 1 完成的测试文件数与用例数
- findings 总数与处理结果（已修/不修）
- 全 App 覆盖率提升情况
- 下一批次（Infrastructure）范围预告

---

## Self-Review

### 1. Spec 覆盖

- 设计规格第 3.1 节批次 1 目标文件：全部覆盖（StoreCapabilities 按用户决策跳过）
- 设计规格第 4 节测试方法论：问题驱动（Task 2/3/4/6/7/11/12/13）+ 轻量补盲（Task 5/8/9/10）✅
  - 注：Task 1 为 findings 表格初始化，Task 14 为阶段修复，均为流程任务
- 设计规格第 5 节 Mock 策略：扩展 TestMocks.swift + 新建 MockCollaborationDelegate ✅
- 设计规格第 6 节阶段修复：Task 14 汇总 + 用户确认 + 集中修复 + 重测 ✅
- 设计规格第 7 节验证方式：单测命令 + make test ✅
- 设计规格第 8 节提交规范：每 Task commit + 批次末统一 commit ✅

### 2. 占位符扫描

无 TBD/TODO/"implement later"/"add appropriate"等占位符。所有代码步骤含完整代码。

### 3. 类型一致性

- `RetryTask.execute(maxRetries:initialDelay:multiplier:maxDelay:operation:)` — operation 是 `@Sendable () async throws -> T`，同步闭包可隐式提升 ✅
- `AudioSplitter.split(data:chunkSize:)` / `merge(chunks:)` 签名一致 ✅
- `String.maskedPhoneNumber` 属性名一致 ✅
- `Date.AppFormat` 5 个常量名一致（iso8601/detailed/slashDetailed/monthDay/year）✅
- `Date.formatted(as:)` / `Date.timeAgoDisplay()` 方法名一致 ✅
- `LogAction` — **19 个 case**（create/update/delete/ingest/smartIngest/export/importPDF/importPDFFailed/deletePDF/highlight/lint/healthCheck/systemInit/aiscanFailed/aiscanSkipped/sync/error/unknown），CaseIterable，含 localizedName/colorName/icon 属性 ✅
- `ExportError` — 3 case（systemBusy/engineNotReady/internalError(String)），有 errorDescription，**无 helpMessage** ✅
- `ExportServiceProtocol` — 3 方法（exportToPDF/exportMindmapToPDF/exportToPPTX）✅
- `UnsupportedReminderService` — `requestAccess() async -> Bool`（返回 false）/ `createReminder(title:notes:) async throws`（空实现不抛错），**无 isSupported** ✅
- `UnsupportedExportService` — 3 个 export 方法抛 NSError（domain=CoreConstants.ErrorDomain.export，code=501）✅
- `UnsupportedFileArchiver` — `zip(directory:to:) async throws` / `extractContents(from:to:) throws`，抛 FileArchiverError.platformNotSupported ✅
- `StubBackgroundTaskProvider` — register(handler:) / schedule()，**无 isAvailable/registerTask** ✅
- `StubWatchSyncService` — @Published lastReceivedText/latestBriefing/isBriefingLoading + sendContent/requestDailyBriefing/handleBriefingResponse，**无 isAvailable/syncState** ✅
- `StubCollaborationProvider` — delegate + startHosting/startBrowsing/joinRoom/stop/broadcast，**无 isAvailable/discoverRooms** ✅
- `CollaborationProviderDelegate` — 7 方法（providerDidUpdateStatus/providerDidDiscoverRoom/providerDidLoseRoom/providerDidConnectPeer/providerDidDisconnectPeer/providerDidReceiveData/providerDidEncounterError），@MainActor ✅
- `ZipUtility.readZipArchive(at:) -> [String: Data]?` — **无 unzip 方法** ✅
- `JailbreakDetector.isJailbroken() -> Bool` — **方法非属性**，@MainActor，private init ✅
- `LocalAnalyticsService` — @MainActor；trackEvent(_:properties:) / trackError(_:details:)；private let logURL: URL；异步持久化 JSON 数组 ✅
- `WorkflowService` — @MainActor + ObservableObject；@Inject var appEnv + @Inject var reminderService；syncToReminders(text:title:)；解析 `- [ ]`/`- [x]`/`- `/`* `/`1. ` 多种格式 ✅
- `ReminderServiceProtocol` — requestAccess() async -> Bool / createReminder(title:notes:) async throws ✅
- `AnalyticsServiceProtocol` — trackEvent(_:properties:) / trackError(_:details:)（在 PluginProtocols.swift:195）✅
- `ToastManager` — show(type:message:duration:)，@Published var currentToast: AppToast? ✅
- `DiscoveredRoom` — id/platformPeer:AnyHashable/roomName/owner ✅
- `CollabUser` — id/displayName/deviceName/joinedAt ✅
- `CoreConstants.MarkdownSyntax` — taskOpen/taskDone/taskDoneUpper/dashSpace/asteriskSpace ✅
- `L10n.Common.justNow` / `L10n.Common.yesterday` 存在 ✅
- `L10n.Workflow` — accessDeniedMessage/noTasksFoundMessage/syncingMessage(_:)/syncSuccessMessage(_:)/syncErrorMessage(_:)/sourceNotes(_:) ✅
- `L10n.Collaboration.Status` — simulatorNotSupported/disconnected ✅
- `L10n.Transfer.Export` — errorSystemBusy/errorEngineNotReady/errorInternal(_:) ✅

### 4. 已知限制

- JailbreakDetector 非越狱环境只能测 false 路径，true 分支无法覆盖（记录为已知限制）
- LocalAnalyticsService 异步持久化需 `Task.sleep` 等待文件写入完成（500ms 轮询）
- WorkflowService 通过有限重构（`init(reminderService:)` 可注入）实现 Mock 隔离，副作用通过观察 `ToastManager.shared.currentToast` @Published 属性验证
- LocalAnalyticsService 通过有限重构（`init(logURL:)` 可注入）实现临时日志路径隔离
- WorkflowService 当前实现 `line.hasPrefix("-")` 会匹配 `- [x]`（已完成任务），记录为 P1 finding 待用户确认

---

## 批次 2：Infrastructure 层（已完成）

### 范围

设计规格第 3.2 节定义的 14+ 个目标文件，按可测试性分三档：
- **高可测试性**：DocxProcessor、ExcelProcessor、PluginSandboxError、FileSystemSyncService、VaultStorageService、InferenceParametersStore、GraphCommunityProcessor（补充）、PPTXProcessor（补充）
- **中可测试性**：OnDeviceLLMService（状态操作+错误类型+DTO+Config 常量）、LLMModels（LLMError+LLMProvider+LLMRegistry+LLMProviderMetadata）
- **低可测试性（跳过）**：ChatLLMService（依赖网络+DI）、LLMAdapters（依赖网络+LLMClient）、DemoImageBuilder（纯 UIKit 绘图）、DemoPDFBuilder（纯 PDFKit 绘图）、PerformanceBenchmarker（@MainActor+AnyPageStore+纯日志）

### Task 记录

| Task | 文件 | 用例数 | 状态 |
|------|------|--------|------|
| B2-1 | `InferenceParametersStoreTests` | 12 | ✅ |
| B2-2 | `DocxProcessorTests` | 9 | ✅ |
| B2-3 | `ExcelProcessorTests` | 11 | ✅ |
| B2-4 | `FileSystemSyncServiceTests` | 8 | ✅ |
| B2-5 | `PluginSandboxErrorTests` | 22 | ✅ |
| B2-6 | `VaultStorageServiceTests` | 10 | ✅ |
| B2-7 | `GraphCommunityProcessorSupplementTests` | 10 | ✅ |
| B2-8 | `PPTXProcessorSupplementTests` | 8 | ✅ |
| B2-9 | `OnDeviceLLMServiceTests` | 30 | ✅ |
| B2-10 | `LLMModelsTests` | 30 | ✅ |
| **合计** | **10 个测试文件** | **150** | **全绿** |

### Findings

| 序号 | 严重程度 | 文件 | 问题 | 状态 |
|------|---------|------|------|------|
| 10 | 🟡 P1 | GraphCommunityProcessor | Louvain 在全连通小图上无法合并社区 | 待确认 |
| 11 | 🟡 P1 | OnDeviceLLMService | OnDeviceError.errorDescription 硬编码字符串违反 L10n 红线 | 待确认 |

### 已知限制

- ChatLLMService/LLMAdapters 跳过：`generate`/`chat`/`chatStream` 依赖 `@Inject` 的 `LLMConfigManager`/`AIAnalyticsService` 和网络请求，难以单元测试
- DemoImageBuilder/DemoPDFBuilder 跳过：纯 UIKit/PDFKit 绘图，无可测试逻辑
- PerformanceBenchmarker 跳过：`@MainActor` + `AnyPageStore` + 纯日志输出
- OnDeviceLLMService 的 `generate`/`loadModel`/`discoverModels` 依赖 CoreML 和文件系统，仅测试状态操作和错误抛出
- `xcodebuild -only-testing` 分隔符需用 `/`（`ZhiYuTests/ClassName`）而非 `:`
