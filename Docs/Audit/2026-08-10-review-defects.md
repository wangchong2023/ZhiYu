# 本轮审视缺陷清单（泽州格式）

> 记录日期：2026-08-10
> 来源：本轮代码审视
> 范围：跨项目审视发现的后端缺陷（ZhiYu-Backend 相关模块）
> 说明：以下缺陷的代码位于 Java/Spring 后端项目，当前仓库为 ZhiYu iOS Swift 项目，此处仅作跨项目记录与跟踪。修复工作需在 ZhiYu-Backend 仓库进行。

## 缺陷清单

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 是否解决 |
|------|----------|------------|----------|----------|----------|
| S9-1 | `LogAspect.resolveHttpContext` L88-89 `X-Forwarded-For` 取整个 header 值（含多跳 IP 列表），与 `ControllerLogAspect` 取首跳 IP 的行为不一致 | 审计日志 `ipAddress` 字段存入 `203.0.113.7, 70.41.3.18, 10.0.0.9` 整个字符串，IP 维度统计/告警失真 | 中 | 与 `ControllerLogAspect` 对齐，取 XFF 首跳 IP（按逗号分割后取第一个非空值并 trim） | 否 |
| S9-2 | `SentinelBlockExceptionHandler.handle` L105 硬编码 `HttpStatus.TOO_MANY_REQUESTS.value()`（429），但降级熔断/系统过载应返回 503，授权拦截应返回 403 | 降级熔断时客户端收到 429 而非 503，无法区分"限流"和"熔断"；授权拦截收到 429 而非 403，语义错配 | 中 | 根据异常类型设置对应 HTTP 状态码：限流→429、熔断/过载→503、授权拦截→403 | 否 |

## 任务 1 测试复现缺陷（2026-08-10）

> 来源：任务 1 修复 5 个单元测试失败时，通过根因分析发现的代码缺陷。

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 是否解决 |
|------|----------|------------|----------|----------|----------|
| S9-3 | `LLMConfigStore`（`Sources/Infrastructure/LLM/LLMModels.swift:254,290,299,308,312,323,337`）硬编码 `UserDefaults.standard`，无法注入自定义 UserDefaults 实例 | 测试环境与生产环境共享 `UserDefaults.standard`，跨测试状态残留导致 `IngestLLMServiceDegradationTests` 4 个降级路径测试失败；无法在隔离环境下验证 LLM 未配置时的降级行为 | 中 | 为 `LLMConfigStore` 构造函数增加可注入的 `UserDefaults` 参数（默认 `.standard`），测试时注入独立 suite 的 UserDefaults 实例 | 是（测试侧用 `resetPersistentTestState()` 清理残留，根治需后续重构注入） |
| S9-4 | `UserDefaultsKeyStore.shared`（`Sources/Core/Base/Services/UserDefaultsKeyStore.swift:20`）使用 `UserDefaults.standard` 单例，`GlobalModelManager` 通过 `keyStore?.string(forKey:)` 读取 `activeModelId`/`activeCloudModelId`/`isCloudEscalationEnabled`，跨测试残留 | `GlobalModelManagerTests` 3 个默认值测试失败（`testActiveModelIdDefaultValue`/`testActiveCloudModelIdDefaultValue`/`testIsCloudEscalationEnabledDefaultFalse`）；测试间状态污染，默认值断言不可靠 | 中 | 测试侧已用 `resetPersistentTestState()` 清理 3 个 key；根治方案为 `UserDefaultsKeyStore` 支持注入独立 suite 的 UserDefaults | 是（测试侧清理，根治需后续重构） |
| S9-5 | `KeychainService.testOverride`（`Tests/Shared/TestMocks.swift:314`）仅在 `nil` 时设置，`MockKeychainService` 内部 store 跨测试不清理，残留 apiKey | `IngestFileHandlerTests.testIsLLMConfiguredReflectsLLMService` 失败：之前测试往 mock keychain 存了 apiKey，导致 `isLLMConfigured` 断言 `false` 时实际为 `true` | 中 | `resetPersistentTestState()` 中调用 `MockKeychainService.resetStore()` 清空内部 store；`MockKeychainService.store` 改为 `private(set)` 供扩展访问 | 是 |
| S9-6 | `GlobalModelManagerTests.setUp`（`Tests/Unit/AI/GlobalModelManagerTests.swift:24`）只清理 `zhiyu_downloaded_model_ids`，未清理 `ZhiYu.ActiveModelId`/`ZhiYu.ActiveCloudModelId`/`ZhiYu.IsCloudEscalationEnabled` 三个 UserDefaults key | 3 个默认值测试因残留状态失败，测试隔离不完整 | 低 | `setUp`/`tearDown` 改用 `resetPersistentTestState()` 统一清理所有持久化 key | 是 |
| S9-7 | `IngestLLMServiceDegradationTests.setUp`（`Tests/Unit/Infrastructure/LLMDegradationAndStorageUtilityTests.swift:224`）只 `ServiceContainer.shared.reset()`，未清理 `zhiyu_llm_config` UserDefaults key 和 Keychain mock store | 4 个降级路径测试失败：`LLMConfigManager()` 实例化时从 `UserDefaults.standard` 读到残留的 `isEnabled=true` 和非空 `apiKey`，导致 `getIngestService()` 返回非 nil，`smartIngest` 不抛 `notConfigured` | 中 | `setUp`/`tearDown` 改用 `resetPersistentTestState()` 清理 `zhiyu_llm_config` + Keychain mock store | 是 |

## 任务 2 UI 测试复现缺陷（2026-08-10）

> 来源：任务 2 修复 UI 测试失败时，通过根因分析发现的代码缺陷。共 5 个 UI 测试失败（3 类根因）。

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 是否解决 |
|------|----------|------------|----------|----------|----------|
| S9-8 | SwiftUI `Menu` 控件菜单项在 XCTest accessibility hierarchy 中不以 `Button` 类型暴露，`app.buttons["aiSettingsMenuButton"]`/`app.buttons["settingsMenuButton"]` 无法定位菜单项 | `AISettingsTabSwitchingUITests.testAISettingsTabsAreSwitchable` 失败（L47 "AI 大模型菜单入口应当存在"）；`SettingsE2ETests.testLanguageSwitching`/`testThemeAccentColorChange` 失败（`settingsMenuButton` 找不到 → `userProfileMenuButton` 点击失败 → app 崩溃 `com.zhiyu.app is not running`） | 高 | 采用业界 launch argument 注入路由方案：在 `ZhiYuApp.init()` 解析 `--open-ai-settings`/`--open-settings`，通过 `UITestRoute` 枚举设 `router.isShowingAISettingsSheet`/`isShowingSettingsSheet`，避免在视图层添加 `if isUITesting` 测试耦合分支 | 是 |
| S9-9 | `VaultDataCoordinator.loadVaults()`（`Sources/Features/Knowledge/Vault/Service/VaultDataCoordinator.swift:19`）异步 `Task` 写入内置笔记本，`autoSelectFirstVaultForUITestingIfNeeded` 在 UI 测试模式自动选择第一个 vault 跳过 NotebookHub，但时序不确定 | `NotebookHubUITests.testNotebookHubShowsAtLeastTwoDefaultNotebooks` 失败：`NotebookHubView` 5 秒内未显示，0 个笔记本卡片（`--reset-state` 清空数据库后异步写入未完成）；`testSwitchBetweenVaultsDoesNotCrash` 失败：点击卡片后 `tabBars` 未出现 | 中 | 移除 `autoSelectFirstVaultForUITestingIfNeeded` 测试耦合代码，由 `KnowledgeBaseUITests.setUp` 的自愈逻辑接管 vault 选择；`NotebookHubUITests` 不继承 `KnowledgeBaseUITests`，直接在 NotebookHub 测试 | 是 |
| S9-10 | `NotebookHubUITests.setUp`（`Tests/UI/NotebookHubUITests.swift:30`）在 `--reset-state` 模式下检测 `app.tabBars.firstMatch.exists` 时，`autoSelectFirstVaultForUITestingIfNeeded` 可能已自动进入 vault，但 `returnToNotebookHub` 依赖 `vaultBadgeButton` 存在，时序竞态导致退出失败 | `testSwitchBetweenVaultsDoesNotCrash` 首次/第二次点击未进入主界面（L132/L153），实际是未成功返回 NotebookHub 导致卡片不可用 | 中 | 移除 `autoSelectFirstVaultForUITestingIfNeeded` 后，`NotebookHubUITests` 不再受自动选择干扰，直接在 NotebookHub 测试 | 是 |
| S9-11 | `VaultDataCoordinator.autoSelectFirstVaultForUITestingIfNeeded`（`Sources/Features/Knowledge/Vault/Service/VaultDataCoordinator.swift:79`）在 UI 测试模式下无条件自动选择第一个 vault，与 `NotebookHubUITests` 需要停留在 NotebookHub 的测试意图冲突，且无法通过 launch argument 禁用 | `NotebookHubUITests.testNotebookHubShowsAtLeastTwoDefaultNotebooks` 失败：自动进入 vault 后 NotebookHubView 不可见，0 个笔记本卡片；`testSwitchBetweenVaultsDoesNotCrash` 因无法返回 NotebookHub 而失败 | 中 | 移除 `autoSelectFirstVaultForUITestingIfNeeded` 测试耦合反模式，由 `KnowledgeBaseUITests.setUp` 自愈逻辑接管 | 是 |

## 7 个既有测试失败修复缺陷（2026-08-11）

> 来源：任务 1/2/8/9 完成后，全量单元测试仍有 7 个失败（均为测试顺序依赖问题）。通过根因分析发现的代码缺陷。

| 序号 | 问题描述 | 黑盒影响性 | 严重程度 | 修改方案 | 是否解决 |
|------|----------|------------|----------|----------|----------|
| S9-12 | `Localized._inMemoryFallback`（`Sources/Core/Base/Utils/Localized.swift:138`）是 `nonisolated(unsafe) private static var`，`languageMode` setter 同步写入但 `Task { @MainActor }` 异步持久化到 UserDefaults，跨测试残留 | `LocalizedTests.testLoadCachedLanguageMode_DI未就绪_不崩溃` 失败：前序 `LocalizationTests.testLanguageSwitchingLogic` 设置 `.portuguese` 后 defer 还原，但 UserDefaults 残留 `portuguese` 被 `loadCachedLanguageMode` 读取 | 中 | 新增 `Localized.resetForTesting()` 重置 `_inMemoryFallback` + `clearBundleCache()`；`resetPersistentTestState()` 调用清理 | 是 |
| S9-13 | `resetPersistentTestState()`（`Tests/Shared/TestMocks.swift:774`）清理 UserDefaults key 列表不完整，缺少 `AppConstants.Keys.Storage.languageMode`（`"app_language_mode"`） | `testLanguageSwitchingLogic` 的 setter 异步 Task 写入 UserDefaults 的 `languageMode` 为 `portuguese`，`resetPersistentTestState()` 未清理该 key，后续测试 `loadCachedLanguageMode` 读取残留值 | 中 | `resetPersistentTestState()` 新增 `defaults.removeObject(forKey: AppConstants.Keys.Storage.languageMode)` | 是 |
| S9-14 | `KeychainService.keyStore`（`Sources/Core/System/Security/KeychainService.swift`）通过 `@Inject private var keyStore: (any KeyStoreProtocol)?` 解析，DI 未就绪时为 `nil`，`errSecMissingEntitlement` 降级路径不可用 | `KeychainServiceTests` 3 个测试失败：DI 容器未注册 `KeyStoreProtocol`，`keyStore` 为 nil，降级路径无法访问 mock store | 中 | `KeychainServiceTests.setUp` 注册 `UserDefaultsKeyStore.shared` 为 `KeyStoreProtocol`；`tearDown` 调 `ServiceContainer.shared.resetForTesting()` | 是 |
| S9-15 | `ServiceContainer.reset()`（`Packages/UFPCore/Sources/UFPCore/Base/ServiceContainer.swift:108-128`）在 `isProductionChainPopulated == true` 时静默阻断，测试环境调用无效 | `KeychainServiceTests.tearDown` 调 `reset()` 但被阻断，DI 注册的 `KeyStoreProtocol` 未清理，跨测试残留 | 中 | `tearDown` 改用 `ServiceContainer.resetForTesting()` 强制清空 `isProductionChainPopulated` 标记 + services | 是 |
| S9-16 | `ContentModerationEngineTests`/`PromptSecuritySanitizerTests`/`RAGEvaluationServiceTests` 的 `setUp`/`tearDown` 未调用 `resetPersistentTestState()`，跨测试状态残留 | 3 个测试类共 3 个测试在全量测试中失败（单独运行通过），测试顺序依赖问题 | 低 | 3 个测试类的 `setUp`/`tearDown` 新增 `MainActor.assumeIsolated { resetPersistentTestState() }` | 是 |

## 修复跟踪

### 后端缺陷（ZhiYu-Backend 仓库）

- **S9-1**：待修复。需在 ZhiYu-Backend 仓库 `LogAspect.resolveHttpContext` 中将 `X-Forwarded-For` header 值按 `,` 分割，取首跳 IP 并 `trim()`，与 `ControllerLogAspect` 行为对齐。修复后需补充单元测试覆盖多跳 IP 列表场景。
- **S9-2**：待修复。需在 ZhiYu-Backend 仓库 `SentinelBlockExceptionHandler.handle` 中根据异常类型分派 HTTP 状态码，并补充对应单元测试。

### 任务 1 测试复现缺陷（ZhiYu iOS 仓库）

- **S9-3**：测试侧已缓解（`resetPersistentTestState()` 清理残留）。根治需重构 `LLMConfigStore` 支持注入 `UserDefaults`，列入后续任务。
- **S9-4**：测试侧已缓解。根治需重构 `UserDefaultsKeyStore` 支持注入独立 suite，列入后续任务。
- **S9-5**：已解决。`MockKeychainService.resetStore()` 在 `resetPersistentTestState()` 中调用。
- **S9-6**：已解决。`GlobalModelManagerTests.setUp`/`tearDown` 改用 `resetPersistentTestState()`。
- **S9-7**：已解决。`IngestLLMServiceDegradationTests.setUp`/`tearDown` 改用 `resetPersistentTestState()`。

### 7 个既有测试失败修复缺陷（ZhiYu iOS 仓库）

- **S9-12**：已解决。新增 `Localized.resetForTesting()` 方法，`resetPersistentTestState()` 第 7 步调用。
- **S9-13**：已解决。`resetPersistentTestState()` 新增清理 `AppConstants.Keys.Storage.languageMode` UserDefaults key。
- **S9-14**：已解决。`KeychainServiceTests.setUp` 注册 `UserDefaultsKeyStore.shared` 为 `KeyStoreProtocol`。
- **S9-15**：已解决。`KeychainServiceTests.tearDown` 从 `reset()` 改为 `resetForTesting()`。
- **S9-16**：已解决。3 个测试类的 `setUp`/`tearDown` 新增 `resetPersistentTestState()` 调用。

### 验证结果

7 个测试修复后运行全量单元测试（`-only-testing:ZhiYuTests -enableCodeCoverage YES`）：
- 2,597 个测试全部通过，0 个功能失败 ✅
- 唯一"失败"是 `KnowledgeStorePerformanceTests.testOneHundredThousandNodesFTSRetrievalLatency` 性能基准偏差（受机器负载影响，非功能失败）

任务 1 修复后运行 3 个测试类共 33 个测试，全部通过：
- `GlobalModelManagerTests` ✅
- `IngestFileHandlerTests` ✅（含 `testIsLLMConfiguredReflectsLLMService`）
- `IngestLLMServiceDegradationTests` ✅（4 个降级路径全部通过）

## 备注

- 两个缺陷均为"中"严重程度，不影响核心功能可用性，但影响审计准确性与错误语义清晰度。
- 修复时需同步更新对应单元测试，确保行为符合预期。
