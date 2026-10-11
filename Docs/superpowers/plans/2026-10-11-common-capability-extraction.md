# 公共能力提取与抽象重构 实施计划（CCB / UFP 下沉）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将散落在 `Sources/`（App 层）中的通用工具、纯 UI 组件、跨域横切能力、重复实现，按「UFP 通用底座 / 业务侧公共 CCB（ZhiYuDomain / ZhiYuAICore）」两档下沉到 SPM 包，消除 7 组重复实现（网络栈、JSON、DateFormatter、确认弹窗、重排、空/错误状态、错位横切），落地闲置的 `AsyncStatus<T>`。

**Architecture:** 分 3 个方向、5 个阶段推进。方向 A：纯通用零业务依赖能力 → 下沉 `UFPCore` / `UFPStorage` / `UFPDesignSystem`。方向 B：依赖领域模型 / RAG / AI 语义能力 → 下沉 `ZhiYuDomain` / `ZhiYuAICore`。方向 C：跨域横切能力与重复实现 → 收敛到公共组件 / 上移错位模块。每阶段独立编译 + 单测验证，最终 3 端编译（iOS / macOS Catalyst / watchOS）+ `make audit` 门禁通过。

**Tech Stack:** Swift 6.4, SwiftUI, GRDB, swift-dependencies, SPM, Xcode 16

## Global Constraints

- 遵守 L0-L3 严格分层，依赖单向自顶向下：L3 App → ZhiYuFeatures → ZhiYuDomain → (ZhiYuAICore / UFPStorage) → UFPDesignSystem → UFPCore
- 领域层（ZhiYuDomain / UFPCore）严禁导入 UI 框架（UIKit / AppKit / SwiftUI）
- 遵守 DesignSystem Token 强约束：严禁硬编码字号/边距/圆角，统一引用 `DesignTokens.*`
- 遵守 L10n 强约束：视图/服务层无硬编码字符串，必须 `L10n.模块.属性`；下沉 UI 组件时 `L10nTableEntry` 协议与 `Localized` 执行中枢须同步下沉到 UFPCore
- 遵守去魔鬼化：下沉的常量（HTTP 状态码、字节换算、重试次数等）须抽为强类型常量枚举
- 平台差异不新增 `#if os()`，通过现有 `PlatformTraits` / `PlatformModifiers` 统一
- 下沉 UI 组件不改变视觉行为（快照测试验证）；下沉存储/工具不改变语义（单测验证）
- 下沉时保留公有 API 兼容（App 层通过 `import UFPCore` / `import ZhiYuDomain` 访问），优先复用/扩展已下沉 UFPCore 现有能力，避免再造重复底座
- 单测/语句覆盖率 ≥ 95%，分支 ≥ 90%；每阶段验证 3 端编译
- 最终门禁：`make audit` 全绿 + `pmd cpd` 重复率 < 3.0%

## 测试迁移策略（测试跟随代码下沉）

> **核心原则：代码下沉到哪个 SPM 包，其现有测试必须同步迁移到该包的 `Tests/` 目录。严禁「代码下沉但测试留在 App 层」导致 `Tests/Unit` 编译失败或覆盖率跌穿红线。**

1. **先迁移测试，再下沉代码**（移动顺序：测试 → 实现 → 兼容层，保证每步可编译）。每个下沉 Task 必须包含「迁移现有测试」步骤，不只是在包内新建测试。
2. **迁移映射表**：下方「测试迁移映射」章节列出每个被下沉能力对应的现有测试文件 → 目标 SPM 包 `Tests/` 路径。执行 Task 时按表迁移。
3. **App 层残留测试清理**：代码移除后，`Tests/Unit` 下原测试文件必须一并删除或移入 SPM 包，避免 `@testable import ZhiYu` 引用已删符号导致编译失败。
4. **包内 `@testable import` 适配**：迁移到 SPM 包后，测试的 import 从 `@testable import ZhiYu` 改为 `@testable import UFPCore` / `UFPStorage` / `UFPDesignSystem` / `ZhiYuDomain` / `ZhiYuAICore`；`Tests/Unit` 无法 import 的私有类型适配到包内 `internal` 访问。
5. **覆盖率守恒**：迁移后目标包的单测/语句覆盖率须保持 ≥ 95%（分支 ≥ 90%），迁移失败即回滚。
6. **跨包依赖测试**：若某个现有测试同时覆盖「已下沉能力 + 业务层」，拆分该测试——能力部分随代码迁移，业务部分保留在 App 层。

### 测试迁移映射表

| 下沉能力（Task） | 现有测试文件（`Tests/`） | 迁移目标 |
|----------------|------------------------|---------|
| RetryTask（A1.1） | `Tests/Unit/Core/RetryTaskTests.swift` | `Packages/UFPCore/Tests/UFPCoreTests/RetryTaskTests.swift` |
| ApiResponse/NetworkError（A1.2） | `Tests/Unit/Infrastructure/ApiResponseTests.swift`、`NetworkClientCoverageTests.swift`(纯类型部分) | `Packages/UFPCore/Tests/UFPCoreTests/ApiResponseTests.swift` |
| JSONExtractor（A1.3） | `Tests/Unit/Infrastructure/JSONExtractorTests.swift`、`JSONExtractorAndFrontmatterSupplementTests.swift`(Extractor 部分) | `Packages/UFPCore/Tests/UFPCoreTests/JSONExtractorTests.swift` |
| SSEParser（A1.4） | `Tests/Unit/Infrastructure/SSEParserTests.swift` | `Packages/UFPCore/Tests/UFPCoreTests/SSEParserTests.swift` |
| 安全/并发工具（A1.5） | `Tests/Unit/Core/AhoCorasickEngineTests.swift`、`SecurityComponentsSupplementTests.swift`(相关部分)、`CoreUtilitiesTests.swift` | `Packages/UFPCore/Tests/UFPCoreTests/SecurityToolsTests.swift` |
| CJK/耗时/文件/时间（A1.6） | `Tests/Unit/Infrastructure/CJKSpacingFormatterEdgeTests.swift`、`Tests/Unit/Core/DateExtensionsTests.swift`、`DateAppExtensionsTests.swift` | `Packages/UFPCore/Tests/UFPCoreTests/TextUtilityTests.swift` |
| DatabaseManager/Migrator（A2.1 引擎层） | `Tests/Unit/Infrastructure/DatabaseManagerLifecycleTests.swift`、`DatabaseManagerDegradationTests.swift`（2 个引擎测试） | `Packages/UFPStorage/Tests/UFPStorageTests/DatabaseManagerTests.swift` |
| SQLiteStore + Migrator 业务 schema（A2.1 装配层） | `Tests/Unit/Infrastructure/DatabaseSchemaMigratorTests.swift`、`DatabaseSchemaMigratorEdgeTests.swift`（测业务 schema，断言 pages/links/tags + 业务模型）、`SQLiteStoreSupplementTests.swift`、`SQLiteStoreFailureEdgeTests.swift`、`SQLiteTransactionConcurrencyStressTests.swift` | **留在 App 层**（Migrator 拆两层后业务 schema 留 App；SQLiteStore 薄装配层留 App，依赖 Domain 协议/业务模型） |
| SQLQuerySanitizer/TransactionGatekeeper（A2.2） | `Tests/Unit/Infrastructure/SQLQuerySanitizerTests.swift` | `Packages/UFPStorage/Tests/UFPStorageTests/StorageGuardTests.swift` |
| 流式下载器（A2.3） | `Tests/Unit/Infrastructure/ModelDownloadManagerTests.swift`、`ModelDownloadManagerEdgeTests.swift`、`ModelDownloadManagerDownloadTests.swift`、`ModelDownloadManagerStateTests.swift` | `Packages/UFPStorage/Tests/UFPStorageTests/StreamingDownloadTests.swift` |
| UI 组件（A3.1/A3.2） | `Tests/Unit/Shared/UIComponents/*`（快照/单测） | `Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/*` |
| TextChunkerProcessor（B3.1） | `Tests/Unit/Infrastructure/TextChunkerProcessorEdgeTests.swift`、`TextChunkerDeepTests.swift`、`TextChunkerSupplementTests.swift`、`ChunkingAlgorithmTests.swift`、`Tests/Unit/Domain/TextChunkerDeepEdgeTests.swift` | `Packages/ZhiYuAICore/Tests/ZhiYuAICoreTests/TextChunkerTests.swift` |
| EmbeddingManager（B3.1） | `Tests/Unit/Infrastructure/EmbeddingManagerTests.swift`、`EmbeddingManagerDeterminismTests.swift`、`EmbeddingManagerCrashResistanceTests.swift` | `Packages/ZhiYuAICore/Tests/ZhiYuAICoreTests/EmbeddingManagerTests.swift` |
| Rerank CCB（B3.2） | `Tests/Unit/Infrastructure/RerankServiceTests.swift`、`QueryRerankerDegradationTests.swift`、`ContextRerankerAndSSRFGuardPureLogicTests.swift`(Rerank 部分)、`Packages/ZhiYuAICore/.../ContextRerankerScoringTests.swift` | `Packages/ZhiYuAICore/Tests/ZhiYuAICoreTests/RerankTests.swift` |
| BaseMemoryEngine（B3.2） | `Tests/Unit/Infrastructure/MemoryEngineAdapterTests.swift`、`MemoryEngineSupplementTests.swift` | `Packages/ZhiYuAICore/Tests/ZhiYuAICoreTests/BaseMemoryEngineTests.swift` |
| FrontmatterParser（B4.1） | `Tests/Unit/Infrastructure/FrontmatterParserDeepTests.swift`、`FrontmatterSplitParseTests.swift`、`FrontmatterIntegrationTests.swift`(通用部分)、`JSONExtractorAndFrontmatterSupplementTests.swift`(Frontmatter 部分) | `Tests/Unit/Domain/FrontmatterParserTests.swift`（Domain 包测试，或 `ZhiYuDomain` 包内） |
| IngestProgressCalculator（B4.1） | `Tests/Unit/Features/Knowledge/`(Ingest 相关进度测试) | `ZhiYuDomain` 包对应测试 |
| PageContentUtility 标签提取（B4.2） | `Tests/Unit/Core/PageContentAndAppConstantsTests.swift`(extractAllTags 部分) | `ZhiYuDomain` 包对应测试 |

### 迁移后 App 层测试删除清单（避免残留编译失败）

执行每个下沉 Task 后，原 `Tests/Unit/Core|Infrastructure|Domain|Features` 下对应测试文件若已完整迁入 SPM 包，须从 App 层测试 target 移除（从 `ZhiYuTests` target 源码中删除，防止 `@testable import ZhiYu` 引用已删符号）。清单见上方映射表「现有测试文件」列。

## 文件结构

### 目标 SPM 包（新增/扩展）

| 包 | 新增能力 | 方向 |
|----|---------|------|
| `Packages/UFPCore` | RetryTask / ApiResponse+NetworkError / JSONExtractor / RegexReplacementHelper / CJKSpacingFormatter / AhoCorasickEngine / IntentRateLimiter / LLMLatencyCalculator / FileManager.folderSize / Date+timeAgo / 确定性种子向量(并入 VectorMath) / SSEParser | A |
| `Packages/UFPStorage` | SQLQuerySanitizer / TransactionGatekeeper / DatabaseManager+Migrator+SQLiteStore(完整能力池) / ModelDownloadManager 泛化下载器 | A |
| `Packages/UFPDesignSystem` | 50+ 纯 UI 组件(Buttons/Cards/Feedback/Chips/Layouts/Lists/Inputs/Modifiers) / `AppConfirmationDialog` / `AppErrorBanner` / DesignTokens+Domain 魔法数字回收 | A |
| `Packages/ZhiYuDomain` | AsyncStatus 落地 / FrontmatterParser 通用剥离 / IngestProgressCalculator / TaskCenter 任务模型(GlobalTask/TaskStatus/TaskStage) / PageContentUtility 标签提取 | B |
| `Packages/ZhiYuAICore` | TextChunkerProcessor / EmbeddingManager / BaseMemoryEngine / Rerank CCB(收敛三入口) / 脱敏助手 | B |

### App 层（修改/收敛）

| 位置 | 动作 | 方向 |
|------|------|------|
| `Sources/Infrastructure/Network/` | NetworkClient 骨架下沉 UFPCore；token 刷新策略留业务注入；LLMClient/RemoteConfig/ModelDownload 收敛统一 | A/C |
| `Sources/Core/` | Utils/Security 工具迁移到 UFPCore，App 层保留 re-export 或移除 | A |
| `Sources/Infrastructure/Storage/Persistence/` | 完整迁移到 UFPStorage，App 层 Repository 改为依赖 UFPStorage 引擎 | A |
| `Sources/Infrastructure/Processors/` | TextChunker→ZhiYuAICore，FrontmatterParser 通用部分→ZhiYuDomain，JSONExtractor/CJK→UFPCore | A/B |
| `Sources/Infrastructure/LLM/VectorDB/` | SSEParser/BaseMemory/Rerank→ZhiYuAICore；EmbeddingManager→ZhiYuAICore | B |
| `Sources/Features/*/Shared/` | subscribeClearAllData 上移；TaskCenter 模型下沉 Domain | B/C |
| `Sources/Shared/UIComponents/` | 纯 UI 下沉 UFPDesignSystem；AppConfirmationDialog 新增；各域私有空/错误状态收敛 | A/C |
| `Sources/Shared/DesignSystem/` | `DesignSystem+Domain.swift` 魔法数字回收；薄转发层收敛 | A |

---

# 方向 A：UFP 通用底座下沉

## 阶段 A1：UFPCore 纯通用工具下沉（P0，复用面最广）

**目标**：将 12 项零业务依赖/弱依赖工具迁移到 `Packages/UFPCore`，App 层改为引用包内实现。

### Task A1.1: 迁移 RetryTask

**Files:**
- Create: `Packages/UFPCore/Sources/UFPCore/Base/RetryTask.swift`
- Modify: `Sources/Core/Utils/RetryTask.swift`（改为 `typealias RetryTask = UFPCore.RetryTask` 或删除）
- Test: `Packages/UFPCore/Tests/UFPCoreTests/RetryTaskTests.swift`（**迁移自** `Tests/Unit/Core/RetryTaskTests.swift`，再补充新用例）

**Interfaces:**
- Consumes: `CoreConstants.RetryBackoff`（迁移到 UFPCore `SystemConstants`）、`Logger`（已是 UFPCore）、`RetryError`
- Produces: `public enum RetryTask.execute<T>(maxRetries:initialDelay:multiplier:maxDelay:shouldRetry:operation:) async throws -> T`、`public static func poll<T>(maxAttempts:interval:condition:) async throws -> T`、`public enum RetryError`

- [ ] **Step 0: 迁移现有测试到 UFPCore**

将 `Tests/Unit/Core/RetryTaskTests.swift` 移入 `Packages/UFPCore/Tests/UFPCoreTests/RetryTaskTests.swift`，`@testable import ZhiYu` → `@testable import UFPCore`，适配 `CoreConstants` 引用为 UFPCore 常量。确认迁移后该文件不再属于 `ZhiYuTests` target（从 xcodeproj 移除），防止残留编译失败。

- [ ] **Step 1: 编写 UFPCore 单测**

```swift
// Packages/UFPCore/Tests/UFPCoreTests/RetryTaskTests.swift
import XCTest
@testable import UFPCore

final class RetryTaskTests: XCTestCase {
    func testExecuteRetriesUntilSuccess() async throws {
        var attempts = 0
        let value = try await RetryTask.execute(maxRetries: 3, initialDelay: 0.01, multiplier: 1.0) {
            attempts += 1
            if attempts < 2 { throw RetryError.pollingExhausted(attempts: attempts) }
            return 42
        }
        XCTAssertEqual(value, 42)
        XCTAssertEqual(attempts, 2)
    }

    func testPollReturnsWhenConditionMet() async throws {
        var count = 0
        let result = try await RetryTask.poll(maxAttempts: 5, interval: 0.01) {
            count += 1
            return count >= 3 ? "done" : nil
        }
        XCTAssertEqual(result, "done")
    }
}
```

- [ ] **Step 2: 运行测试验证失败**

Run: `make test-spm PKG=UFPCore`
Expected: FAIL — `RetryTask` 未定义

- [ ] **Step 3: 迁移实现到 UFPCore**

将 `Sources/Core/Utils/RetryTask.swift` 整体搬入 `Packages/UFPCore/Sources/UFPCore/Base/RetryTask.swift`；将 `CoreConstants.RetryBackoff` 默认值改为 UFPCore 常量枚举（`RetryBackoffConstants`），`Logger` 改用包内 Logger。`RetryError` 一并迁移。

- [ ] **Step 4: 更新 UFPCore Package.swift / 生成工程**

确认 `UFPCore` target 的 sources 包含新文件。Run: `make gen` 重新生成工程。

- [ ] **Step 5: App 层替换引用**

将 `Sources/Core/Utils/RetryTask.swift` 改为 `@_exported import UFPCore` 兼容层（或删除并全局替换 `import UFPCore`），替换 `LLMClient.swift:67`、`NetworkClient` 等调用点。

- [ ] **Step 5b: 删除 App 层原测试文件**

确认 `Tests/Unit/Core/RetryTaskTests.swift` 已迁入 UFPCore 包，将该文件从 `ZhiYuTests` target 移除（避免引用已删符号），并检查是否有其他 App 层测试间接依赖 `RetryTask`（grep 确认无残留）。

- [ ] **Step 6: 运行测试验证通过**

Run: `make test-spm PKG=UFPCore && make test-unit`
Expected: PASS

- [ ] **Step 7: 提交**

```bash
git add Packages/UFPCore Sources/Core/Utils/RetryTask.swift
git commit -m "refactor: 下沉 RetryTask 到 UFPCore 通用底座"
```

### Task A1.2: 迁移 ApiResponse + NetworkError

**Files:**
- Create: `Packages/UFPCore/Sources/UFPCore/Base/Network/ApiResponse.swift`
- Modify: `Sources/Infrastructure/Network/Models/ApiResponse.swift`（兼容层）
- Test: `Packages/UFPCore/Tests/UFPCoreTests/ApiResponseTests.swift`（**迁移自** `Tests/Unit/Infrastructure/ApiResponseTests.swift`，再补充用例）

**Interfaces:**
- Produces: `public struct ApiResponse<T: Codable & Sendable>: Codable, Sendable { code: Int; message: String; data: T?; requestId: String; timestamp: Int64; var isSuccess: Bool }`、`public struct EmptyData`、`public enum NetworkError`

- [ ] **Step 0: 迁移现有测试到 UFPCore**

将 `Tests/Unit/Infrastructure/ApiResponseTests.swift` 移入 `Packages/UFPCore/Tests/UFPCoreTests/ApiResponseTests.swift`，import 改为 `@testable import UFPCore`。检查 `NetworkClientCoverageTests.swift` 中纯类型断言部分（不依赖 NetworkClient 的 `ApiResponse`/`NetworkError` 单测）拆分迁移；从 `ZhiYuTests` target 移除原文件。

- [ ] **Step 1: 迁移实现到 UFPCore**

将 `ApiResponse` / `EmptyData` / `NetworkError` 搬入 UFPCore（保留 `NetworkError` 的纯错误码设计，不含 L10n 字符串）。App 层 `NetworkError+UserMessage.userMessage` 扩展保留在业务层。

- [ ] **Step 2: 编写单测**

```swift
// Packages/UFPCore/Tests/UFPCoreTests/ApiResponseTests.swift
final class ApiResponseTests: XCTestCase {
    func testIsSuccessWhenCodeZero() throws {
        let resp = ApiResponse<String>(code: 0, message: "ok", data: nil, requestId: "r1", timestamp: 0)
        XCTAssertTrue(resp.isSuccess)
    }
    func testDecode() throws {
        let json = #"{"code":0,"message":"ok","data":"hello","requestId":"r1","timestamp":1}"#
        let decoded = try JSONDecoder().decode(ApiResponse<String>.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.data, "hello")
    }
}
```

- [ ] **Step 3: 运行测试 + 编译验证 + 提交**

Run: `make test-spm PKG=UFPCore && make ios`
Commit: `refactor: 下沉 ApiResponse/NetworkError 到 UFPCore`

### Task A1.3: 迁移 JSONExtractor（统一 11 处反序列化样板）

**Files:**
- Create: `Packages/UFPCore/Sources/UFPCore/Base/JSONExtractor.swift`
- Modify: `Sources/Infrastructure/Processors/Document/JSONExtractor.swift`（兼容层）
- Test: `Packages/UFPCore/Tests/UFPCoreTests/JSONExtractorTests.swift`（**迁移自** `Tests/Unit/Infrastructure/JSONExtractorTests.swift` + `JSONExtractorAndFrontmatterSupplementTests.swift` 的 Extractor 部分）

**Interfaces:**
- Produces: `public enum JSONExtractor.extractJSONObject(from:) -> [String: Any]?` / `extractJSONArray(from:) -> [[String: Any]]?` 及泛型解码辅助

- [ ] **Step 0: 迁移现有测试到 UFPCore**

将 `Tests/Unit/Infrastructure/JSONExtractorTests.swift` 移入 UFPCore 包；`JSONExtractorAndFrontmatterSupplementTests.swift` 拆出 Extractor 相关用例迁入、Frontmatter 部分留给 B4.1。原文件从 `ZhiYuTests` target 移除。

- [ ] **Step 1: 迁移实现 + 补充泛型解码**

将 `JSONExtractor` 搬入 UFPCore，新增 `static func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T` 统一反序列化入口。

- [ ] **Step 2: 编写单测**（覆盖 markdown 包裹 JSON 提取、多 JSON 选择、无效输入返回 nil）

- [ ] **Step 3: 替换 11 处反序列化样板**

将 `RAGEvaluationService.swift:164`、`SynthesisStore.swift:379`、`AppConfig.swift:22`、`RemoteConfigService.swift:66`、`LocalAnalyticsService.swift:70`、`CollaborationService.swift:208`、`LLMClient.swift:92,100,262`、`SQLitePluginRepository.swift:164` 的 `JSONSerialization.jsonObject(with:)` 替换为 `JSONExtractor.decode`。

- [ ] **Step 4: 测试 + 编译 + 提交**

Run: `make test-spm PKG=UFPCore && make test-unit`
Commit: `refactor: 下沉 JSONExtractor 并统一 JSON 反序列化`

### Task A1.4: 迁移 SSEParser（提升为独立 CCB）

**Files:**
- Create: `Packages/UFPCore/Sources/UFPCore/Base/Network/SSEParser.swift`
- Modify: `Sources/Infrastructure/LLM/LLMClient.swift:193-291`（引用包内 SSEParser）
- Test: `Packages/UFPCore/Tests/UFPCoreTests/SSEParserTests.swift`（**迁移自** `Tests/Unit/Infrastructure/SSEParserTests.swift`，再补充用例）

**Interfaces:**
- Produces: `public final class SSEParser`（从 SSE 字节流解析事件，兼容 OpenAI/DeepSeek/Qwen 格式，含 `data:` / `[DONE]` 处理）

- [ ] **Step 0: 迁移现有测试到 UFPCore**

将 `Tests/Unit/Infrastructure/SSEParserTests.swift` 移入 UFPCore 包，import 改 `@testable import UFPCore`，从 `ZhiYuTests` target 移除原文件。

- [ ] **Step 1: 将 LLMClient 内嵌的 SSEParser 提取为 UFPCore 公有类**（保留解析语义）
- [ ] **Step 2: 编写单测**（分块字节流、多事件、`[DONE]` 终止、空行跳过）
- [ ] **Step 3: LLMChatService / LLMAdapters 改为依赖包内 SSEParser**
- [ ] **Step 4: 测试 + 编译 + 提交**

Run: `make test-spm PKG=UFPCore && make test-unit`
Commit: `refactor: SSEParser 提升为 UFPCore 公共能力`

### Task A1.5: 迁移安全/并发工具（AhoCorasickEngine / IntentRateLimiter / RegexReplacementHelper）

**Files:**
- Create（UFPCore）: `Security/AhoCorasickEngine.swift`、`Security/IntentRateLimiter.swift`、`Security/RegexReplacementHelper.swift`
- Modify: `Sources/Core/System/Security/*`（兼容层）
- Test: `Packages/UFPCore/Tests/UFPCoreTests/SecurityToolsTests.swift`（**迁移自** `Tests/Unit/Core/AhoCorasickEngineTests.swift` + `SecurityComponentsSupplementTests.swift`/`CoreUtilitiesTests.swift` 相关部分）

**Interfaces:**
- Produces: `final class AhoCorasickEngine`（`build(patterns:)` + `containsAny(in:)`）、`final class IntentRateLimiter`、`enum RegexReplacementHelper`

- [ ] **Step 0: 迁移现有测试到 UFPCore**

将 `Tests/Unit/Core/AhoCorasickEngineTests.swift` 整体移入 UFPCore 包；从 `SecurityComponentsSupplementTests.swift`/`CoreUtilitiesTests.swift` 拆分出 AhoCorasick/限流/正则相关用例迁入。原文件从 `ZhiYuTests` target 移除。

- [ ] **Step 1: 三件工具迁移到 UFPCore**（幂等、无业务依赖）
- [ ] **Step 2: 合并 `CJKSpacingFormatter+Helpers.applyCaptureGroupReplacement` 到 `RegexReplacementHelper`**（消除 R5 重复）
- [ ] **Step 3: 编写单测**（AC 匹配、限流计数、正则替换）
- [ ] **Step 4: 测试 + 编译 + 提交**

Run: `make test-spm PKG=UFPCore && make test-unit`
Commit: `refactor: 下沉安全/并发工具到 UFPCore`

### Task A1.6: 迁移 CJKSpacingFormatter / LLMLatencyCalculator / FileManager.folderSize / Date+timeAgo

**Files:**
- Create（UFPCore）: `Base/Extensions/String+CJKSpacing.swift`（并入现有 `Character+CJK`）、`Base/LLMLatencyCalculator.swift`、`Base/Extensions/FileManager+FolderSize.swift`、`Base/Extensions/Date+RelativeTime.swift`（并入现有 `Date+Formatting`）
- Modify: `Sources/` 对应原文件（兼容层）
- Test: `Packages/UFPCore/Tests/UFPCoreTests/TextUtilityTests.swift`（**迁移自** `Tests/Unit/Infrastructure/CJKSpacingFormatterEdgeTests.swift` + `Tests/Unit/Core/DateExtensionsTests.swift` + `DateAppExtensionsTests.swift`）

- [ ] **Step 0: 迁移现有测试到 UFPCore**

将 `CJKSpacingFormatterEdgeTests.swift`、`DateExtensionsTests.swift`、`DateAppExtensionsTests.swift` 移入 UFPCore 包（Date 相关与现有 `Date+Formatting` 测试合并），import 改 `@testable import UFPCore`，从 `ZhiYuTests` target 移除原文件。

- [ ] **Step 1: 逐项迁移到 UFPCore**（CJK 混排空格、毫秒耗时计算、目录大小统计、相对时间显示）
- [ ] **Step 2: 统一 DateFormatter**：以 `UFPCore.Date+Formatting` 为唯一出口，替换 `Sources/` 20+ 处独立构造（`VersionInfoFormatter`、`iOSSpeechService`、`SnapshotService`、`SystemStatsChartView` 等）—— 见 Task C2
- [ ] **Step 3: 编写单测**（CJK 注入、耗时、文件夹统计、timeAgo 各档位）
- [ ] **Step 4: 测试 + 编译 + 提交**

Run: `make test-spm PKG=UFPCore && make test-unit`
Commit: `refactor: 下沉 CJK/耗时/文件/时间工具到 UFPCore`

---

## 阶段 A2：UFPStorage 完整能力池（P1）

**目标**：将 GRDB 物理引擎完整下沉，`UFPStorage` 从空壳变成可复用存储底座。

### Task A2.1: 下沉 GRDB 存储引擎（引擎层 + 装配层拆分）

> **方案变更（ADR-013 + USER 确认二次拆分）**：探查发现 SQLiteStore 深度依赖 Domain/App 层（`AnyPageStoreCapabilities`/`KnowledgeRepository` 等协议 + `KnowledgePage` 等业务模型），且 DatabaseSchemaMigrator 内嵌业务 schema（registerMigration 闭包，17 处业务表），**且 DatabaseManager 深度耦合业务符号**（SecurityManager 完整性校验/VaultDatabaseSwitcher 协议/KnowledgePage.fetchCount/L10n/AppConstants/App 版 StorageConstants）。改为**引擎层 + 装配层拆分 + DatabaseManager 二次拆分**：UFPStorage 下沉 `GenericDatabaseManager`（纯物理引擎）+ `GenericSchemaMigrator`（通用迁移执行器）+ `GenericSQLiteEngine`（泛型骨架）；Migrator 业务 schema、DatabaseManager 业务扩展（SecurityManager 适配/VaultDatabaseSwitcher conform/countPages）、SQLiteStore 薄装配层留 App。业务协议不物理下沉。详见 `Docs/Architecture/2026-10-11-ufpstorage-downstream-design.md`。

**Files:**
- Create（UFPStorage）: `Sources/UFPStorage/Engine/GenericDatabaseManager.swift`、`GenericSchemaMigrator.swift`、`GenericSQLiteEngine.swift`、`StorageConstants.swift`(扩展)
- Modify: `Sources/Infrastructure/Storage/Persistence/DatabaseManager.swift`（保留业务扩展，基于 GenericDatabaseManager）、`DatabaseSchemaMigrator.swift`（保留业务 schema，基于 GenericSchemaMigrator）
- Modify: `Sources/Infrastructure/Storage/Engine/SQLiteStore.swift`（改为基于 GenericSQLiteEngine 的薄装配层，conform 不变）
- Modify: `Packages/UFPStorage/Package.swift`（确认 GRDB 依赖，已有）
- Test: `Packages/UFPStorage/Tests/UFPStorageTests/GenericDatabaseManagerTests.swift`（**迁移自** `DatabaseManagerLifecycleTests.swift`/`DegradationTests.swift` 的**物理引擎用例**：reset/事务计数/排空/降级状态）；业务断言用例（FeedbackEntry 表、countPages）+ `DatabaseSchemaMigratorTests`/`MigratorEdgeTests`（测业务 schema）+ `SQLiteStoreSupplementTests`/`FailureEdgeTests`/`TransactionConcurrencyStressTests` 共 5+ **留在 App 层**

**Interfaces:**
- Produces: `final class GenericDatabaseManager`（setup(at:)/连接管理/降级骨架，完整性校验闭包注入、文件名注入，零业务符号）、`GenericSchemaMigrator`（通用迁移执行器，无业务 schema，业务迁移由 App 注入）、`GenericSQLiteEngine`（泛型 CRUD/事务骨架，无业务依赖）

- [ ] **Step 0: 拆分 DatabaseManager 二次 + Migrator 两层**

DatabaseManager 拆为 UFPStorage `GenericDatabaseManager`（纯物理引擎：建库/连接/WAL/降级骨架，校验/文件名闭包注入）+ App 业务扩展（SecurityManager 适配/VaultDatabaseSwitcher conform/countPages/L10n/AppConstants/App 版 StorageConstants）。Migrator 拆为 UFPStorage `GenericSchemaMigrator`（GRDB `DatabaseMigrator` 机制，无业务 schema）+ App 业务 schema（v1-v13+全局，setup 注入）。`.sql` 资源为 bundled 参考，不迁移。

- [ ] **Step 1: 迁移引擎测试到 UFPStorage**

迁移 DatabaseManager 物理引擎用例（reset/事务计数/排空/降级状态，`@testable import UFPStorage`）到 `GenericDatabaseManagerTests.swift`；业务断言用例（FeedbackEntry 表、countPages）留 App。从 `ZhiYuTests` target 移除已迁物理引擎测试文件。**Migrator ×2 + SQLiteStore ×3 测试 + DatabaseManager 业务用例留 App 层**。

- [ ] **Step 2: 新增 UFPStorage 通用引擎**

`GenericDatabaseManager`（Logger 适配 MinimalLogger，`TestStateResettable` 保持，单例语义保留）+ `GenericSchemaMigrator` + `GenericSQLiteEngine`（泛型 CRUD/事务骨架，Codable 泛型，零业务模型依赖）+ `StorageConstants` 扩展通用常量。

- [ ] **Step 3: 重构 App 层装配**

`DatabaseManager` 保留业务扩展基于 GenericDatabaseManager；`DatabaseSchemaMigrator` 保留业务 schema 基于 GenericSchemaMigrator；`SQLiteStore` 改薄装配层基于 GenericSQLiteEngine，`AnyPageStoreCapabilities` conform 不变；更新 `StorageModuleRegistrar` 注册引用。

- [ ] **Step 5: 测试 + 编译 + 提交**

Run: `make test-spm PKG=UFPStorage && make ios`
Commit: `refactor: 下沉 GRDB 存储引擎到 UFPStorage`

### Task A2.2: 下沉 TransactionGatekeeper + SQLQuerySanitizer

**Files:**
- Create（UFPStorage）: `Engine/TransactionGatekeeper.swift`、`Utility/SQLQuerySanitizer.swift`
- Modify: `Sources/Infrastructure/Storage/Utility/SQLQuerySanitizer.swift`（兼容层）
- Test: `Packages/UFPStorage/Tests/UFPStorageTests/StorageGuardTests.swift`（**迁移自** `Tests/Unit/Infrastructure/SQLQuerySanitizerTests.swift`，再补充事务门禁用例）

**Interfaces:**
- Produces: `actor TransactionGatekeeper`（`begin/commit/rollback` 计数 + 排空）、`enum SQLQuerySanitizer`（LIKE 转义 + 有效性校验）

- [ ] **Step 0: 迁移现有测试到 UFPStorage**

将 `Tests/Unit/Infrastructure/SQLQuerySanitizerTests.swift` 移入 UFPStorage 包，import 改 `@testable import UFPStorage`，从 `ZhiYuTests` target 移除原文件。

- [ ] **Step 1: 迁移到 UFPStorage**
- [ ] **Step 2: 编写单测**（并发事务计数、`%`/`_` 转义、非法 SQL 拒绝）
- [ ] **Step 3: 测试 + 编译 + 提交**

Run: `make test-spm PKG=UFPStorage`
Commit: `refactor: 下沉事务门禁与 SQL 清洗到 UFPStorage`

### Task A2.3: ModelDownloadManager 泛化为通用下载器

**Files:**
- Create（UFPStorage）: `Utility/StreamingDownloadManager.swift`
- Modify: `Sources/Infrastructure/Network/ModelDownloadManager.swift`（改为依赖通用下载器）
- Test: `Packages/UFPStorage/Tests/UFPStorageTests/StreamingDownloadTests.swift`（**迁移自** `Tests/Unit/Infrastructure/ModelDownloadManagerTests.swift`、`ModelDownloadManagerEdgeTests.swift`、`ModelDownloadManagerDownloadTests.swift`、`ModelDownloadManagerStateTests.swift`）

**Interfaces:**
- Produces: `actor StreamingDownloadManager`（断点续传 + SHA256 流式校验 + 速率采样），大模型业务逻辑留在 App 层

- [ ] **Step 0: 迁移现有测试到 UFPStorage**

将 4 个 ModelDownloadManager 测试文件移入 UFPStorage 包，拆出「下载器通用逻辑」用例迁入；依赖业务（模型文件名/URL）的用例留在 App 层对应测试。import 适配 `@testable import UFPStorage`。

- [ ] **Step 1: 抽取通用下载器（去业务化）**
- [ ] **Step 2: 编写单测**（断点续传偏移、SHA256 校验失败拒绝、速率统计）
- [ ] **Step 3: ModelDownloadManager 改为薄封装**
- [ ] **Step 4: 测试 + 编译 + 提交**

Run: `make test-spm PKG=UFPStorage && make ios`
Commit: `refactor: 抽取通用流式下载器到 UFPStorage`

---

## 阶段 A3：UFPDesignSystem UI 下沉（P1）

**目标**：将 50+ 纯 UI 组件下沉，并新增 `AppConfirmationDialog` / `AppErrorBanner` 横切组件。

### Task A3.1: 下沉 Buttons / Cards / Layouts / Lists / Chips / Inputs（约 30+ 组件）

**Files:**
- Create（UFPDesignSystem）: `Sources/UFPDesignSystem/Components/Buttons.swift`、`Cards.swift`、`Layouts.swift`、`Lists.swift`、`Chips.swift`、`Inputs.swift`、`Feedback.swift`
- Modify: `Sources/Shared/UIComponents/` 原文件（删除或 re-export）
- Test: `Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/ComponentSnapshotTests.swift`（**迁移自** `Tests/Unit/Shared/UIComponents/` 下对应组件快照/单测）

**Interfaces:**
- Produces: `AppPrimaryButton` / `AppBorderedButton` / `AppCapsuleButton` / `AppFilledActionButton` / `ScaleButtonStyle` / `AppCard` / `AppBorderedCard` / `AppGlassCard` / `FlowLayout` / `StandardSection` / `AnimatedSection` / `AppSectionHeader` / `AppLabeledRow` / `AppStepRow` / `AppDivider` / `AppAccentLine` / `AppIconBox` / `AppChip` / `AppIconChip` / `AppBadge` / `AppScrollableChips` / `AppSubtlePill` / `AppTextField` / `AppTagField` / `AppMonospacedEditor` / `AppTextEditor` / `AdaptiveTextEditor`

- [ ] **Step 0: 迁移现有 UIComponents 测试到 UFPDesignSystem**

将 `Tests/Unit/Shared/UIComponents/` 下对应组件的快照测试与单元测试迁入 `Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/`，import 适配 `UFPDesignSystem`；快照引用图片路径迁移到 `UFPDesignSystemTestMocks` 资源。从 `ZhiYuTests` target 移除原文件。

- [ ] **Step 1: 逐组件迁移到 UFPDesignSystem**（确认全部使用 `DesignTokens.*`，无业务依赖；补 `import UFPDesignSystem`）
- [ ] **Step 2: 快照测试**（`UFPDesignSystemTestMocks`）验证视觉行为不变
- [ ] **Step 3: App 层删除原文件 / 改 re-export，全局替换引用**
- [ ] **Step 4: 编译验证 + 提交**

Run: `make test-spm PKG=UFPDesignSystem && make ios`
Commit: `refactor: 下沉基础 UI 组件到 UFPDesignSystem`

### Task A3.2: 下沉 Feedback 五大件 + 新增 AppConfirmationDialog / AppErrorBanner（横切，最显著）

**Files:**
- Create（UFPDesignSystem）: `Sources/UFPDesignSystem/Components/Feedback.swift`（AppToast/ToastManager/AppEmptyState/AppErrorView/AppLoadingOverlay/AppLoadingSkeleton）、`ConfirmationDialog.swift`、`ErrorBanner.swift`
- Modify: `Sources/Shared/UIComponents/Feedback/*`（删除/re-export）
- Modify: `Sources/` 17+ 处 `.confirmationDialog` / `.alert` 视图
- Test: `Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/ConfirmationDialogTests.swift`（**迁移自** `Tests/Unit/Shared/UIComponents/Feedback/` 下 AppToast/AppEmptyState/AppErrorView/AppLoading* 现有测试，再新增 ConfirmationDialog/ErrorBanner 用例）

**Interfaces:**
- Produces: `struct AppConfirmationDialog`（title / message / confirmLabel / cancelLabel / isPresented / onConfirm）、`.appConfirmationDialog(_:isPresented:onConfirm:)` 修饰符、`struct AppErrorBanner`（inline 错误横幅）

- [ ] **Step 0: 迁移现有 Feedback 测试到 UFPDesignSystem**

将 `Tests/Unit/Shared/UIComponents/Feedback/` 下 AppToast/AppEmptyState/AppErrorView/AppLoadingOverlay/AppLoadingSkeleton 现有测试迁入 `Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/`，import 适配；`toastService` 的 `@Dependency` mock 随包迁移。从 `ZhiYuTests` target 移除原文件。

- [ ] **Step 1: 下沉 Feedback 五大件**（L10n 默认文案走 `L10nTableEntry`，将该协议同步下沉 UFPCore）
- [ ] **Step 2: 新增 `AppConfirmationDialog` 通用组件**（消除 17+ 处 `@State isPresented + .confirmationDialog` 样板）
- [ ] **Step 3: 新增 `AppErrorBanner`**（补充缺失的通用错误横幅）
- [ ] **Step 4: 批量替换 17+ 处重复的确认弹窗/错误横幅**，并为每个被替换视图补充行为验证
- [ ] **Step 5: 测试 + 编译 + 提交**

Run: `make test-spm PKG=UFPDesignSystem && make ios`
Commit: `feat: 新增 AppConfirmationDialog/AppErrorBanner 横切组件`

### Task A3.3: DesignSystem Token 魔法数字回收 + 薄转发收敛

**Files:**
- Modify: `Sources/Shared/DesignSystem/DesignSystem+Domain.swift`（Auth/Voice/Lint 魔法数字下沉到 `DesignTokens.Metrics/Spacing`）
- Modify: `Sources/Shared/DesignSystem/DesignSystem+*.swift`（薄转发层收敛）
- Test: `Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/TokenCoverageTests.swift`

- [ ] **Step 1: 将 `DesignSystem+Domain.swift` 中 Auth(logo 60/按钮 120/38)/Voice(80)/Lint(110) 等魔法数字注册为 `DesignTokens.Metrics/Spacing` 命名空间 Token**
- [ ] **Step 2: 收敛薄转发层**：Features 层直接引用 `DesignTokens.*`，删除冗余 `DesignSystem+XXX` 转发
- [ ] **Step 3: 编写 Token 覆盖率测试**（断言无散落魔法数字）
- [ ] **Step 4: 编译 + 审计 + 提交**

Run: `make test-spm PKG=UFPDesignSystem && make audit`
Commit: `refactor: 回收 DesignSystem 域魔法数字并收敛薄转发层`

---

# 方向 B：业务侧公共 CCB 下沉

## 阶段 B1：落地 AsyncStatus + 统一异步状态（P0，消除 22+ 处三件套）

**目标**：启用已定义但闲置的 `AsyncStatus<T>`，替代各 Store/Coordinator 的「布尔 loading + errorMessage + showError」三件套。

### Task B1.1: 落地 AsyncStatus 并接入首个 Coordinator

**Files:**
- Modify: `Packages/ZhiYuDomain/Sources/ZhiYuDomain/Models/AsyncStatus.swift`（确认已入包）
- Modify: `Sources/Features/AI/Chat/Coordinator/ChatCoordinator.swift:24,29,30,142-143,216-217`
- Modify: `Sources/Features/Knowledge/Ingest/Coordinator/IngestCoordinator.swift:38,49,50,146-147,181-182`
- Test: `Tests/Unit/Domain/AsyncStatusTests.swift`（**抽取自** `Tests/Unit/Domain/DomainModelsTests.swift` 中已有 AsyncStatus 用例，迁移为独立测试文件）

**Interfaces:**
- Consumes: `public enum AsyncStatus<T>: Equatable where T: Equatable { idle / loading(String) / success(T) / failure(String) }`
- Produces: 业务层模式 `@Observable var status: AsyncStatus<Void>`，配合 computed `isLoading` / `errorMessage`

- [ ] **Step 1: 抽取 AsyncStatus 现有用例 + 补充**

从 `Tests/Unit/Domain/DomainModelsTests.swift` 拆出 AsyncStatus 相关用例为独立 `AsyncStatusTests.swift`（isLoading 判定、Equatable、四态流转），补充分支覆盖。

- [ ] **Step 2: 将 ChatCoordinator / IngestCoordinator 的布尔三件套替换为 `AsyncStatus`**，错误文案从 `.failure(message)` 提取，对应 Coordinator 单测同步适配新状态接口
- [ ] **Step 3: 测试 + 编译 + 提交**

Run: `make test-unit`
Commit: `refactor: 落地 AsyncStatus 统一异步状态管理`

### Task B1.2: 推广 AsyncStatus 到其余 22 处 loading 标志

**Files:**
- Modify: `Sources/Features/` 下 `GlobalModelManager.swift:42`、`ModelLabManager.swift:153`、`AIWorkflowStore.swift:35`、`AIInsightStore.swift:40`、`DashboardCoordinator.swift:27`、`SystemStatsCoordinator.swift:48`、`NotebookHubViewModel.swift:63` 等
- Test: 相应 Store 单测适配

- [ ] **Step 1: 逐 Store 替换布尔 loading 为 `AsyncStatus`**（保持对外行为，单测同步）
- [ ] **Step 2: 收敛 `AsyncStatus` 状态到 `L10n` 文案**（loading 描述、failure 消息走 L10n）
- [ ] **Step 3: 测试 + 编译 + 提交**

Run: `make test-unit`
Commit: `refactor: 全面推广 AsyncStatus 消除 loading 三件套`

---

## 阶段 B2：TaskCenter 跨域任务模型下沉 + runTrackedTask（P1）

**目标**：TaskCenter 跨 AI + Knowledge 域复用，模型层下沉 Domain，消除 8 处 addTask/completeTask/failTask 样板。

### Task B2.1: 下沉 TaskCenter 任务模型到 ZhiYuDomain

**Files:**
- Create: `Packages/ZhiYuDomain/Sources/ZhiYuDomain/Models/Task/TaskModels.swift`
- Modify: `Sources/Features/AI/TaskCenter/Service/TaskCenter.swift`（模型引用包内定义）
- Test: `Packages/ZhiYuDomain/Tests/ZhiYuDomainTests/TaskModelsTests.swift`（**迁移/抽取自** `Tests/Unit/Features/AI/TaskCenterTests.swift`、`TaskCenterDeepTests.swift` 中 `GlobalTask`/`TaskType`/`TaskStatus`/`TaskStage` 模型纯逻辑用例）

**Interfaces:**
- Produces: `struct GlobalTask`、`enum TaskType`、`enum TaskStatus { pending / running(progress: Double, stage: TaskStage) / completed / failed }`、`enum TaskStage`

- [ ] **Step 0: 迁移任务模型测试到 ZhiYuDomain**

从 `Tests/Unit/Features/AI/TaskCenterTests.swift`、`TaskCenterDeepTests.swift` 拆出任务模型的纯逻辑用例（Codable/状态流转/进度断言），迁入 `Packages/ZhiYuDomain/Tests/ZhiYuDomainTests/TaskModelsTests.swift`（`@testable import ZhiYuDomain`）；依赖 TaskCenter 服务调度行为的用例保留在 `Tests/Unit/Features/AI/`。

- [ ] **Step 1: 任务模型（GlobalTask/TaskType/TaskStatus/TaskStage）下沉 ZhiYuDomain**
- [ ] **Step 2: TaskCenter 服务改为依赖包内模型**，`TaskStatus` 与 `AsyncStatus` 建立映射关系
- [ ] **Step 3: 测试 + 编译 + 提交**

Run: `make test-spm PKG=ZhiYuDomain && make ios`
Commit: `refactor: 下沉 TaskCenter 任务模型到 ZhiYuDomain`

### Task B2.2: 新增 runTrackedTask 公共 API 消除样板

**Files:**
- Modify: `Sources/Features/AI/TaskCenter/Service/TaskCenter.swift`
- Modify: `AIWorkflowStore.swift:111,130,248`、`SynthesisStore.swift:223`、`IngestStore.swift:159`、`IngestURLHandler.swift:46`、`IngestFileHandler.swift:43`、`IngestService.swift:339`
- Test: `Tests/Unit/Features/AI/TaskCenterTests.swift`

**Interfaces:**
- Produces: `func runTrackedTask<T>(type: TaskType, name: String, operation: () async throws -> T) async throws -> T`（内部 addTask + do/catch + complete/failTask）

- [ ] **Step 1: 在 TaskCenter 新增 `runTrackedTask` 泛型 API**
- [ ] **Step 2: 替换 8 处 addTask/completeTask/failTask 三段式样板**
- [ ] **Step 3: 测试 + 编译 + 提交**

Run: `make test-unit`
Commit: `feat: TaskCenter.runTrackedTask 消除任务样板`

---

## 阶段 B3：AI/RAG 能力下沉 ZhiYuAICore（P1）

**目标**：TextChunker / Embedding / BaseMemory / Rerank 收敛为业务 CCB。

### Task B3.1: 下沉 TextChunkerProcessor + EmbeddingManager

**Files:**
- Create（ZhiYuAICore）: `Sources/ZhiYuAICore/RAG/TextChunkerProcessor.swift`、`VectorDB/EmbeddingManager.swift`
- Modify: `Sources/Infrastructure/Processors/Document/TextChunkerProcessor.swift`、`Sources/Infrastructure/VectorDB/EmbeddingManager.swift`（兼容层）
- Test: `Packages/ZhiYuAICore/Tests/ZhiYuAICoreTests/TextChunkerTests.swift`（**迁移自** `Tests/Unit/Infrastructure/TextChunkerProcessorEdgeTests.swift`、`TextChunkerDeepTests.swift`、`TextChunkerSupplementTests.swift`、`ChunkingAlgorithmTests.swift`、`Tests/Unit/Domain/TextChunkerDeepEdgeTests.swift`）、`EmbeddingManagerTests.swift`（**迁移自** `Tests/Unit/Infrastructure/EmbeddingManagerTests.swift`、`EmbeddingManagerDeterminismTests.swift`、`EmbeddingManagerCrashResistanceTests.swift`）

**Interfaces:**
- Produces: `struct TextChunkerProcessor`（递归语义分块 + 面包屑上下文注入）、`actor EmbeddingManager`（NLEmbedding 向量化 + 内存缓存 + 余弦检索 + 确定性哈希回退向量）

- [ ] **Step 0: 迁移现有测试到 ZhiYuAICore**

将 TextChunker 相关 5 个测试文件与 Embedding 相关 3 个测试文件移入 `Packages/ZhiYuAICore/Tests/ZhiYuAICoreTests/`，`@testable import ZhiYu` → `@testable import ZhiYuAICore`。从 `ZhiYuTests` / Domain 测试 target 移除原文件。

- [ ] **Step 1: 迁移 TextChunkerProcessor 到 ZhiYuAICore**（保留 Karpathy 切片标准）
- [ ] **Step 2: 迁移 EmbeddingManager**，确定性种子向量生成并入 `UFPCore.VectorMath`
- [ ] **Step 3: 编写单测**（分块大小/上下文注入、向量缓存命中、余弦检索）
- [ ] **Step 4: 测试 + 编译 + 提交**

Run: `make test-spm PKG=ZhiYuAICore && make ios`
Commit: `refactor: 下沉 TextChunker/EmbeddingManager 到 ZhiYuAICore`

### Task B3.2: 下沉 BaseMemoryEngine + 收敛 Rerank CCB

**Files:**
- Create（ZhiYuAICore）: `Sources/ZhiYuAICore/Adapters/BaseMemoryEngine.swift`、`RAG/RerankService.swift`
- Modify: `Sources/Infrastructure/LLM/Adapters/BaseMemoryEngine.swift`、`RerankService.swift`、`QueryReranker.swift`、`VectorDB/ContextReranker.swift`（收敛三入口）
- Test: `Packages/ZhiYuAICore/Tests/ZhiYuAICoreTests/RerankTests.swift`（**迁移自** `Tests/Unit/Infrastructure/RerankServiceTests.swift`、`QueryRerankerDegradationTests.swift`、`ContextRerankerAndSSRFGuardPureLogicTests.swift` 的 Rerank 部分 + 包内 `ContextRerankerScoringTests.swift`）、`BaseMemoryEngineTests.swift`（**迁移自** `Tests/Unit/Infrastructure/MemoryEngineAdapterTests.swift`、`MemoryEngineSupplementTests.swift`）

**Interfaces:**
- Produces: `open class BaseMemoryEngine`（历史切片 + 线程安全 session 摘要）、`enum RerankService`（统一频次/LLM/上下文重排策略）

- [ ] **Step 0: 迁移现有测试到 ZhiYuAICore**

将 Rerank 相关与 BaseMemory 相关测试移入 ZhiYuAICore 包（`@testable import ZhiYuAICore`）；`ContextRerankerAndSSRFGuardPureLogicTests` 拆出 Rerank 用例迁入、SSRFGuard 部分留给 UFPCore（若适用）。从 `ZhiYuTests` target 移除原文件。

- [ ] **Step 1: 迁移 BaseMemoryEngine 到 ZhiYuAICore**
- [ ] **Step 2: 收敛 RerankService/QueryReranker/ContextReranker 三入口为单一 Rerank CCB**（消除 R6 重叠）
- [ ] **Step 3: 编写单测**
- [ ] **Step 4: 测试 + 编译 + 提交**

Run: `make test-spm PKG=ZhiYuAICore && make ios`
Commit: `refactor: 下沉 BaseMemoryEngine 并收敛 Rerank CCB`

---

## 阶段 B4：业务侧其余 CCB（P2）

### Task B4.1: 下沉 FrontmatterParser 通用剥离 + IngestProgressCalculator

**Files:**
- Create（ZhiYuDomain）: `Sources/ZhiYuDomain/Processors/FrontmatterParser.swift`、`Sources/ZhiYuDomain/Utility/IngestProgressCalculator.swift`
- Modify: `Sources/Infrastructure/Processors/FrontmatterParser.swift`、`Sources/Features/Knowledge/Ingest/Utility/IngestProgressCalculator.swift`
- Test: `Tests/Unit/Domain/FrontmatterParserTests.swift`（**迁移自** `Tests/Unit/Infrastructure/FrontmatterParserDeepTests.swift`、`FrontmatterSplitParseTests.swift`、`FrontmatterIntegrationTests.swift` 的通用部分、`JSONExtractorAndFrontmatterSupplementTests.swift` 的 Frontmatter 部分）、`IngestProgressCalculatorTests.swift`（**迁移自** `Tests/Unit/Features/Knowledge/` 下 Ingest 进度测试）

**Interfaces:**
- Produces: `enum FrontmatterParser.split(_:) -> (frontmatter: String?, body: String)`、`convertYamlToJson`、`enum IngestProgressCalculator`（`clampProgress` / `formatPercentage` / `resolveTaskProgress`）

- [ ] **Step 0: 迁移现有测试到 Domain**

将 FrontmatterParser 相关测试移入 `Tests/Unit/Domain/`（`@testable import ZhiYu` 保持，因 Domain 包测试需编译进 App 测试 target 或 `ZhiYuDomain` 包测试）；确认其 import 与 target 归属，随代码下沉到 `ZhiYuDomain` 包对应 `Tests/`。IngestProgress 测试移入对应位置。原文件从 `Tests/Unit/Infrastructure` / `Features` 移除。

- [ ] **Step 1: 迁移 FrontmatterParser 通用剥离逻辑**（具体 `XxxFrontmatter` 模型留业务层）
- [ ] **Step 2: 消除 R4**：`SnapshotService.swift:78-82` 自制 frontmatter 剥离改为复用 `FrontmatterParser.split`
- [ ] **Step 3: 下沉 IngestProgressCalculator**（Ingest 与 TaskCenter 跨域复用）
- [ ] **Step 4: 测试 + 编译 + 提交**

Run: `make test-spm PKG=ZhiYuDomain && make ios`
Commit: `refactor: 下沉 FrontmatterParser/进度计算器到 ZhiYuDomain`

### Task B4.2: 下沉 PageContentUtility 标签提取 + 上移 subscribeClearAllData

**Files:**
- Create（ZhiYuDomain）: `Sources/ZhiYuDomain/Utility/PageContentUtility.swift`
- Move: `Sources/Features/AI/Shared/AppEventBus+ClearDataSubscription.swift` → `Sources/Shared/` 公共位置（或 AppEventBus 原生）
- Modify: `Sources/Core/Base/Utils/PageContentUtility.swift`、6 处 `subscribeClearAllData` 调用方 import
- Test: 迁移 `Tests/Unit/Core/PageContentAndAppConstantsTests.swift` 中 `extractAllTags` 用例到对应 Domain 测试

**Interfaces:**
- Produces: `enum PageContentUtility.extractAllTags(from:) -> [String]`
- 移动后 `subscribeClearAllData` 供 AI + Knowledge + System 三域共用（消除 B3 错位）

- [ ] **Step 0: 迁移 extractAllTags 测试到 Domain**

从 `Tests/Unit/Core/PageContentAndAppConstantsTests.swift` 拆出 `extractAllTags` 用例，迁入 `ZhiYuDomain` 包对应测试；`wordCount` 相关用例已由 UFPCore 覆盖，保留在 App 层或迁移。

- [ ] **Step 1: 迁移 `extractAllTags` 到 ZhiYuDomain**（`wordCount` 已在 UFPCore.TextAnalyzer）
- [ ] **Step 2: 上移 `subscribeClearAllData` 到公共位置**，更新 6 处调用 import
- [ ] **Step 3: 测试 + 编译 + 提交**

Run: `make test-spm PKG=ZhiYuDomain && make test-unit`
Commit: `refactor: 下沉标签提取并上移清数据订阅横切能力`

---

# 方向 C：重复实现清理

## 阶段 C1：网络栈收敛（R1）

### Task C1.1: 统一 HTTP 网络栈

**Files:**
- Modify: `Sources/Infrastructure/LLM/LLMClient.swift:156-177`、`Sources/Infrastructure/Network/RemoteConfigService.swift:41-50`、`Sources/Infrastructure/Network/ModelDownloadManager.swift:60-72`、`Sources/Infrastructure/Network/NetworkClient.swift`
- Test: `Tests/Unit/Infrastructure/NetworkClientTests.swift`

- [ ] **Step 1: 抽取 NetworkClient 统一骨架到 UFPCore**（URLRequest 构造 + 状态码校验 + JSON 解码 + 错误映射），401 无感刷新策略留业务层通过协议注入
- [ ] **Step 2: LLMClient / RemoteConfigService / ModelDownloadManager 改为依赖统一骨架**，消除各自手写 URLRequest/解码样板
- [ ] **Step 3: 复用 `RetryTask` 语义替换 NetworkClient 手写 401 刷新重试（:257-324）**
- [ ] **Step 4: 测试 + 编译 + 提交**

Run: `make test-unit && make ios`
Commit: `refactor: 统一 HTTP 网络栈消除多套实现`

---

## 阶段 C2：DateFormatter 集中化（R3）

### Task C2.1: 收敛 20+ 处 DateFormatter

**Files:**
- Modify: `Sources/` 下 `VersionInfoFormatter.swift:46,50`、`iOSSpeechService.swift:68`、`SnapshotService.swift:41,68`、`KnowledgeInsightService.swift:166,240`、`SynthesisDocRow.swift:142`、`SynthesisStore.swift:388`、`BirthdayDateFormatter.swift:18`、`SystemStatsChartView.swift:197`、`SystemStatsCoordinator.swift:154`、`ConflictDiffView.swift:398`、`iCloudSyncCoordinator.swift:260-262`、`UserProfileView.swift:129,377`、`AppBackupService.swift:69,141`、`FileImportFileStore.swift:62,96`
- Test: `Packages/UFPCore/Tests/UFPCoreTests/DateFormatterUnificationTests.swift`

- [ ] **Step 1: 以 `UFPCore.Date+Formatting` 为唯一出口，新增统一 DateFormatter 工厂**（线程安全 + 缓存）
- [ ] **Step 2: 替换 20+ 处独立构造**
- [ ] **Step 3: 快照/单测验证日期格式输出一致**
- [ ] **Step 4: 测试 + 编译 + 提交**

Run: `make test-spm PKG=UFPCore && make test-unit`
Commit: `refactor: 集中化 DateFormatter 消除散落构造`

---

## 阶段 C3：空/错误状态视图收敛（B5）

### Task C3.1: 收敛各域私有空/错误状态视图

**Files:**
- Delete: `Sources/Features/Insight/Dashboard/View/Components/InsightEmptyState.swift`、`Sources/Features/Knowledge/Graph/View/Components/GraphEmptyStateView.swift`、`Sources/Features/AI/Synthesis/View/Components/SynthesisErrorStateView.swift`
- Modify: 相应调用视图 → `AppEmptyState` / `AppErrorView`
- Test: `Tests/Unit/Features/*` 适配

- [ ] **Step 1: 逐域将私有空/错误视图替换为 `AppEmptyState` / `AppErrorView` 公共组件**（L10n 文案映射）
- [ ] **Step 2: 删除私有视图文件**
- [ ] **Step 3: 快照测试 + 编译 + 提交**

Run: `make test-unit && make ios`
Commit: `refactor: 收敛各域空/错误状态视图到公共组件`

---

## 阶段 C4：DependencyKey 注册样板宏化（B4）

### Task C4.1: 生成统一 DependencyKey 注册（消除 10 处样板）

**Files:**
- Create: `Sources/Shared/DI/DependencyKeyMacro.swift`（或辅助生成器）
- Modify: 10 个 Store 尾部（`AIWorkflowStore.swift:306-323`、`AIInsightStore.swift:128-144`、`SynthesisStore.swift:422-439`、`TaskCenter.swift:327-345`、`IngestStore.swift:212-228`、`KnowledgeStore.swift:331-352`、`TagStore`、`SettingsStore`、`IngestService`、`KnowledgeInsightService`）
- Test: `Tests/Unit/Core/DependencyKeyMacroTests.swift`

- [ ] **Step 1: 定义 `@DependencyKey` 宏或注册辅助方法**，统一生成 `DependencyKey` + `DependencyValues` 样板
- [ ] **Step 2: 替换 10 处复制粘贴注册块**
- [ ] **Step 3: 测试（DI 解析正确性）+ 编译 + 提交**

Run: `make test-unit && make ios`
Commit: `refactor: 用宏统一 DependencyKey 注册样板`

---

## 阶段 C5：最终门禁验证

### Task C5.1: 全量验证

**Files:**
- Run: 全量 SPM 单测 + App 单测 + 架构审计 + 测试迁移一致性检查

- [ ] **Step 1: 全量单测**

Run: `make test-spm-all && make test-unit`
Expected: 全部 PASS，覆盖率 ≥ 95% / 分支 ≥ 90%

- [ ] **Step 1b: 测试迁移一致性检查**

逐 Task 核对「测试迁移映射表」：确认每个下沉能力的现有测试已迁入对应 SPM 包 `Tests/`，且原 `Tests/Unit` 文件已从 `ZhiYuTests` target 移除（grep 确认无残留 `@testable import ZhiYu` 引用已删符号）。Run: 对每个已下沉能力 `grep -rn "func test" Packages/<pkg>/Tests/ | wc -l` 比对迁移前后用例数守恒（允许拆分导致的 ± 合理波动，须在报告中说明）。

- [ ] **Step 2: 架构与依赖审计**

Run: `make audit`
Expected: 无反向跨层依赖、无魔法数字、无 L10n 违规、无 `@Inject` 新增

- [ ] **Step 3: 重复率检查**

Run: `pmd cpd --minimum-tokens 20`（或项目 CPD 门禁）
Expected: 重复率 < 3.0%

- [ ] **Step 4: 3 端编译**

Run: `make ios && make mac && make watch`
Expected: 全部成功

- [ ] **Step 5: 文档更新**

更新 `Docs/Architecture/CODEBASE_ANALYSIS.md`（标注已下沉项）、`Docs/Guides/implementation-patterns.md`（新增公共能力索引）、`Docs/Requirements/FEATURE_LIST.md`（下沉状态）

- [ ] **Step 6: 提交**

```bash
git add .
git commit -m "docs: 更新公共能力下沉后的架构文档"
```

---

## 自检记录（Self-Review）

**1. 覆盖度（Spec → Task 映射）：**
- UFP 下沉：A1.1–A1.6（工具）、A2.1–A2.3（存储/下载）、A3.1–A3.3（UI/Token）
- 业务 CCB：B1.1–B1.2（AsyncStatus）、B2.1–B2.2（TaskCenter）、B3.1–B3.2（AI/RAG）、B4.1–B4.2（其余）
- 重复清理：C1（网络栈）、C2（DateFormatter）、C3（空/错误状态）、C4（DI 宏）、C5（门禁）
- 重复实现 7 组全覆盖：R1→C1.1、R2→A1.3、R3→A1.6/C2.1、R4→B4.1、R5→A1.5、R6→B3.2、R7→C1.1

**2. 占位符扫描：** 各 Task 均给出精确文件路径、接口签名、验证命令；A1.1/A1.2/A1.3 含完整测试代码，其余迁移类任务（因搬移现有代码）给出明确步骤与验证命令，无 "TBD/TODO"。

**3. 测试迁移覆盖：** 每个下沉 Task 已补充「Step 0: 迁移现有测试到对应 SPM 包」步骤，并按「测试迁移映射表」列出现有测试文件 → 目标路径。已核查的现有测试迁移点：RetryTaskTests、ApiResponseTests、JSONExtractorTests、SSEParserTests、AhoCorasickEngineTests、CJKSpacingFormatterEdgeTests、DateExtensionsTests、DatabaseManager 物理引擎用例（迁 UFPStorage `GenericDatabaseManagerTests`）+ DatabaseManager 业务断言用例 + Migrator 2 个业务 schema 测试 + SQLiteStore 3 个装配测试（留 App 层，ADR-013 二次拆分设计）、ModelDownloadManager 共 4 个测试、TextChunker 共 5 个测试、EmbeddingManager 共 3 个测试、Rerank/BaseMemory 相关、FrontmatterParser 相关、AsyncStatus（从 DomainModelsTests 抽取）、TaskModels（从 TaskCenterTests 抽取）、UIComponents 快照测试。跨包测试（同时覆盖下沉能力 + 业务层）按第 6 条拆分策略处理。

**4. 类型一致性：** `AsyncStatus` 四态、`RetryTask.execute/poll`、`ApiResponse` 字段、`SSEParser`、`TaskStatus` 各 case 在定义与消费处保持一致。

**建议执行顺序：** A1（基础工具）→ B1（AsyncStatus）→ A3.2（确认弹窗）→ A2（存储）→ B2/B3/B4（业务 CCB）→ C 系列（清理）→ C5（门禁）。每阶段独立可交付、可回滚。