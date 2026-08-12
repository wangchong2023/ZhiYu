# AppModel + swift-dependencies 迁移设计

> **设计日期**: 2026-08-12
> **来源**: 第三次深度审计（综合评分 8.65/10）→ 21 个有状态单例导致测试顺序依赖
> **方法论**: superpowers（brainstorming → writing-plans → 实施）
> **目标**: 根治测试顺序依赖 + CI 防复发 + 综合评分 8.65 → 9.5（A+）
> **方案**: 方案 A — 全量迁移 + CI 门禁（用户确认）

---

## 1. 目标与原则

### 1.1 目标

1. **根治测试顺序依赖**：21 个 `@MainActor` 有状态单例的可变全局状态全部迁移到 `@Observable` + `@Environment`/`@Dependency`，测试隔离零共享状态
2. **CI 防复发**：4 个 CI 门禁脚本硬阻断新增可变单例、`@EnvironmentObject`、`UserDefaults.standard` 直接调用、非 `@Observable` 状态对象
3. **顺带消除并发安全债**：3 个 `nonisolated(unsafe) static var testOverride` + `Localized` 静态缓存一并迁移
4. **综合评分提升**：8.65 → 9.5（A+），可测试性 7.5 → 9.5

### 1.2 原则

1. **渐进迁移，最终消灭 `@Inject`**：迁移期间 `@Inject` 与 `@Dependency` 共存避免大爆炸式重构，最后阶段统一删除 `@Inject` 属性包装器 + `ServiceContainer` 注册代码，CI 门禁硬阻断新增 `@Inject`
2. **低风险优先**：按引用频次从低到高迁移（🟢 → 🟡 → ⚪ → 🟠 → 🔴）
3. **每阶段配 CI 门禁**：迁移完成一个类别，立即加 CI 脚本锁定
4. **测试先行**：每阶段迁移前先写测试复现污染，迁移后验证零失败
5. **不破坏现有 `@Environment`/`@EnvironmentObject`**：225 处 `@Environment` 保留，仅替换 4 处 `@EnvironmentObject` 为 `@Environment`
6. **遵循 AGENTS.md 四大红线**：L10n 强约束、DesignSystem Token、L0-L3 分层、去魔鬼化数字

### 1.3 范围边界

- **包含**：21 个 `@MainActor` 单例 + 3 个 `testOverride` + `Localized` 静态缓存 + `@Inject` 属性包装器 + `ServiceContainer` 注册体系
- **最终态**：`@Inject` 完全删除，`ServiceContainer` 降级为 `swift-dependencies` 的 `DependencyContainer` 包装（或直接删除）
- **不包含**：`ServiceContainer`（DI 容器本身保留过渡，最终删除）

### 1.4 关键决策

- **`DatabaseManager` 特殊处理**：Tests/ 中 204 次引用，迁移成本极高。**最终也改为 `@Dependency`**，但放最后阶段，配专项测试 + `withDependencies { $0.databaseManager = .mock }` 覆盖
- **`TaskCenter`(76)/`PluginRegistry`(46)/`ToastManager`(42)**：迁移成本最高，放最后阶段，**最终也改为 `@Dependency`**

### 1.5 迁移终态

- `@Inject` → `@Dependency`（100% 替换）
- `ServiceContainer.shared.register(...)` → `DependencyContainer` 或直接删除
- `XxxService.shared` → `@Dependency(\.xxxService)`（100% 替换）
- `@EnvironmentObject` → `@Environment`（4 处替换）
- `setupFullMockEnvironment()` → `withDependencies { $0 = .mock }`（一行构造）

---

## 2. 架构设计

### 2.1 迁移终态架构

```
┌─────────────────────────────────────────────────────────────┐
│  ZhiYuApp (@main)                                           │
│  @State private var appModel = AppModel()                   │
│  @State private var dependencies = DependencyContainer()    │
│                                                             │
│  WindowGroup {                                              │
│      RootView()                                             │
│          .environment(appModel)        // UI 状态           │
│          .environment(dependencies)    // 服务依赖           │
│  }                                                          │
└─────────────────────────────────────────────────────────────┘
         │                              │
         ▼                              ▼
┌─────────────────────┐    ┌─────────────────────────────────┐
│  AppModel           │    │  DependencyContainer            │
│  @Observable        │    │  (swift-dependencies)           │
│                     │    │                                 │
│  // UI 状态         │    │  @Dependency(\.llmService)      │
│  var vaults: [...]  │    │  @Dependency(\.vaultService)    │
│  var onboarding     │    │  @Dependency(\.taskCenter)      │
│  var localization   │    │  @Dependency(\.pluginRegistry)  │
│  var theme          │    │  @Dependency(\.toastManager)    │
│  var router         │    │  @Dependency(\.authSession)     │
│  var medals         │    │  @Dependency(\.databaseManager) │
│  // ... 21 个状态   │    │  // ... 21 个服务               │
└─────────────────────┘    └─────────────────────────────────┘
         │                              │
         ▼                              ▼
┌─────────────────────┐    ┌─────────────────────────────────┐
│  View 层            │    │  Service 层                     │
│                     │    │                                 │
│  @Environment(...)  │    │  @Dependency(\.xxxService)      │
│  // 读取 UI 状态    │    │  // 读取服务依赖                │
│                     │    │                                 │
│  不再有 .shared     │    │  不再有 .shared                 │
│  不再有 @Inject     │    │  不再有 ServiceContainer        │
└─────────────────────┘    └─────────────────────────────────┘
```

### 2.2 AppModel 设计（UI 状态容器）

```swift
// Sources/App/AppModel.swift
@MainActor
@Observable
public final class AppModel {
    // L3 表现层状态
    public var router: RouterState
    public var onboarding: OnboardingState
    public var theme: ThemeState
    public var localization: LocalizationState
    public var tooltip: TooltipState
    public var toast: ToastState
    public var pencil: PencilState
    public var voiceSpeech: VoiceSpeechState

    // L2 业务层状态
    public var vault: VaultState
    public var taskCenter: TaskCenterState
    public var medals: MedalState
    public var activity: ActivityState
    public var auth: AuthState
    public var storeKit: StoreKitState

    // L1 服务层状态（仅 UI 可观察部分）
    public var globalModel: GlobalModelState
    public var llmConfig: LLMConfigState

    // 预览工厂
    public static func preview() -> AppModel { ... }
}
```

**关键设计**：
- **状态 vs 服务分离**：`AppModel` 只持有 UI 可观察状态（`vaults`/`onboarding`/`theme`），服务方法（`TaskCenter.execute()`/`PluginRegistry.load()`）走 `@Dependency`
- **State 结构体**：每个单例拆为 `XxxState`（数据）+ `XxxService`（方法），`AppModel` 持有 State，`@Dependency` 注入 Service
- **`preview()` 工厂**：快照测试一行构造确定性状态，替代 `setupFullMockEnvironment()` + 手动重置

### 2.3 DependencyContainer 设计（服务依赖容器）

```swift
// Sources/Core/DependencyContainer.swift
import Dependencies

@MainActor
@Observable
public final class DependencyContainer {
    @Dependency(\.llmService) public var llmService
    @Dependency(\.vaultService) public var vaultService
    @Dependency(\.taskCenter) public var taskCenter
    @Dependency(\.pluginRegistry) public var pluginRegistry
    @Dependency(\.toastManager) public var toastManager
    @Dependency(\.authSession) public var authSession
    @Dependency(\.databaseManager) public var databaseManager
    // ... 21 个 @Dependency

    public init() {}

    // 测试预览工厂
    public static func mock() -> DependencyContainer { ... }
}
```

### 2.4 swift-dependencies 注册（替代 ServiceContainer）

```swift
// Sources/Core/Dependencies/Register.swift
import Dependencies

extension DependencyValues {
    @MainActor
    public var llmService: LLMService {
        get { self[LLMServiceKey.self] }
        set { self[LLMServiceKey.self] = newValue }
    }

    private enum LLMServiceKey: DependencyKey {
        static let live: LLMService = LLMService()
        static let test: LLMService = MockLLMService()
        static let preview: LLMService = MockLLMService()
    }
}
```

### 2.5 测试终态

```swift
// 迁移前（当前）
func testXxx() {
    setupFullMockEnvironment()           // 100+ 行注册
    VaultService.shared.vaults = []      // 手动重置
    OnboardingService.shared.reset()     // 手动重置
    Localized.languageMode = .auto       // 手动重置
    // ... 7 步清理
    let view = NotebookHubView()
        .environmentObject(ThemeManager.shared)
        .environmentObject(LLMService.shared)
        .environmentObject(MedalService.shared)
        .environmentObject(OnboardingService.shared)
        .environment(Router.shared)
        .environment(VaultService.shared)
        // ... 15 个 .environment + 4 个 .environmentObject
}

// 迁移后（终态）
func testXxx() {
    let model = AppModel.preview()                    // 一行构造 UI 状态
    let deps = DependencyContainer.mock()             // 一行构造服务依赖
    let view = NotebookHubView()
        .environment(model)
        .environment(deps)
    // 零手动重置，零 .shared，零 @EnvironmentObject
}
```

---

## 3. CI 门禁脚本设计

### 3.1 门禁脚本总览

| 脚本 | 阶段 | 检测内容 | 阻断条件 | 严重级别 |
|------|------|----------|----------|----------|
| `audit-singleton-frozen.py` | P2 | 禁止新增 `static let shared` | 白名单外新增 | error |
| `audit-environment-object.py` | P3 | 禁止 `@EnvironmentObject` | `Sources/` 中任何使用 | error |
| `audit-userdefaults-standard.py` | P4 | 禁止 `UserDefaults.standard` 直接调用 | 白名单外直接调用 | error |
| `audit-inject-deprecated.py` | P7 | 禁止 `@Inject` + `nonisolated(unsafe) static var` | `Sources/` 中任何使用 | error |

### 3.2 CI-1: `audit-singleton-frozen.py`

**目的**：冻结单例白名单，禁止新增 `static let shared`，防止迁移期间恶化。

**白名单注册制**（`Config/exemptions/singleton_whitelist.yml`）：
```yaml
# 迁移期间白名单，每迁移一个单例就从这里删除
# 最终态：白名单为空（仅 DatabaseManager 基础设施层例外）
singleton_shared_whitelist:
  - file: Sources/Features/AI/TaskCenter/Service/TaskCenter.swift
    symbol: TaskCenter.shared
    reason: P6 阶段迁移
    expiry_check: "2026-09-30"
    migrated_to: "@Dependency(\\.taskCenter)"
  # ... 21 个存量白名单
```

**检测逻辑**：
```python
def audit_singleton_frozen():
    whitelist = load_yaml("Config/exemptions/singleton_whitelist.yml")
    violations = []
    for swift_file in glob("Sources/**/*.swift"):
        content = read(swift_file)
        # 检测模式：static let shared = XxxType()
        matches = re.findall(r'static\s+let\s+shared\s*[:=]', content)
        for match in matches:
            if not is_whitelisted(swift_file, match, whitelist):
                violations.append((swift_file, match))
    if violations:
        print_violations(violations)
        sys.exit(1)
```

**输出格式**（对齐现有审计脚本）：
```
❌ audit-singleton-frozen.py: 发现 2 个违规
   Sources/Features/NewFeature.swift:15
      static let shared = NewFeature()
      原因: 不在白名单中
      修复: 使用 @Dependency(\.newFeature) 替代
```

### 3.3 CI-2: `audit-environment-object.py`

**目的**：禁止 `@EnvironmentObject`，统一改为 `@Environment`（Apple 官方推荐）。

**检测逻辑**：
```python
def audit_environment_object():
    violations = []
    for swift_file in glob("Sources/**/*.swift"):
        content = read(swift_file)
        # 检测模式：@EnvironmentObject var xxx
        if re.search(r'@EnvironmentObject\s+var\s+\w+', content):
            violations.append(swift_file)
    # P3 阶段：白名单允许存量 4 处，每迁移一个就删除
    # P7 阶段：白名单清空，硬阻断
    whitelist = load_yaml("Config/exemptions/environment_object_whitelist.yml")
    violations = filter_whitelisted(violations, whitelist)
    if violations:
        sys.exit(1)
```

**白名单**（P3 阶段，4 处存量）：
```yaml
environment_object_whitelist:
  - file: Sources/App/ZhiYuApp.swift
    line: 45
    symbol: ThemeManager
    reason: P5 阶段迁移
  - file: Sources/App/ZhiYuApp.swift
    line: 46
    symbol: OnboardingService
    reason: P4 阶段迁移
  - file: Sources/App/ZhiYuApp.swift
    line: 47
    symbol: LLMService
    reason: P3 阶段迁移
  - file: Sources/App/ZhiYuApp.swift
    line: 48
    symbol: MedalService
    reason: P2 阶段迁移
```

### 3.4 CI-3: `audit-userdefaults-standard.py`

**目的**：禁止 `UserDefaults.standard` 直接调用，强制走 `@Dependency(\.userDefaults)` 或 `KeychainService`。

**检测逻辑**：
```python
def audit_userdefaults_standard():
    violations = []
    for swift_file in glob("Sources/**/*.swift"):
        content = read(swift_file)
        # 检测模式：UserDefaults.standard
        if re.search(r'UserDefaults\.standard', content):
            violations.append(swift_file)
    # 白名单：仅允许 DependencyKey 注册文件
    whitelist = load_yaml("Config/exemptions/userdefaults_whitelist.yml")
    violations = filter_whitelisted(violations, whitelist)
    if violations:
        sys.exit(1)
```

**白名单**（仅允许注册文件）：
```yaml
userdefaults_whitelist:
  - file: Sources/Core/Dependencies/Register.swift
    reason: DependencyKey 注册入口
  - file: Sources/Core/Base/Utils/Localized.swift
    reason: P7 阶段迁移
  - file: Sources/Infrastructure/LLM/LLMModels.swift
    reason: P3 阶段迁移（LLMConfigStore）
```

### 3.5 CI-4: `audit-inject-deprecated.py`

**目的**：P7 阶段最终收尾，禁止 `@Inject` + `nonisolated(unsafe) static var` + `static var testOverride`。

**检测逻辑**：
```python
def audit_inject_deprecated():
    violations = []
    for swift_file in glob("Sources/**/*.swift"):
        content = read(swift_file)
        # 检测模式 1：@Inject
        if re.search(r'@Inject\s+var\s+\w+', content):
            violations.append((swift_file, "@Inject"))
        # 检测模式 2：nonisolated(unsafe) static var
        if re.search(r'nonisolated\s*\(\s*unsafe\s*\)\s+static\s+var', content):
            violations.append((swift_file, "nonisolated(unsafe) static var"))
        # 检测模式 3：static var testOverride
        if re.search(r'static\s+var\s+testOverride', content):
            violations.append((swift_file, "static var testOverride"))
    if violations:
        sys.exit(1)
```

### 3.6 集成到现有 CI 流水线

**Makefile `audit` 目标扩展**：
```makefile
audit: ## 运行 CI 8 大架构与依赖审计门禁
	@echo "→ 运行架构审计门禁..."
	python3 Tools/ios/check-code-localization.py
	python3 Tools/ios/audit-design-magic-numbers.py
	python3 Tools/ios/audit-code-magic-strings.py
	python3 Tools/ios/audit-code-business-magic-numbers.py
	# 新增 4 个门禁
	python3 Tools/ios/audit-singleton-frozen.py
	python3 Tools/ios/audit-environment-object.py
	python3 Tools/ios/audit-userdefaults-standard.py
	python3 Tools/ios/audit-inject-deprecated.py
	@echo "✅ 架构审计门禁全部通过"
```

**pre-push hook 扩展**（`Tools/git/pre-push-hook.sh`）：
```bash
# 新增 4 个门禁（--full 模式）
if [[ "$FULL_MODE" == "1" ]]; then
    echo "→ 运行单例冻结门禁..."
    python3 Tools/ios/audit-singleton-frozen.py || exit 1
    echo "→ 运行 EnvironmentObject 门禁..."
    python3 Tools/ios/audit-environment-object.py || exit 1
    echo "→ 运行 UserDefaults.standard 门禁..."
    python3 Tools/ios/audit-userdefaults-standard.py || exit 1
    echo "→ 运行 @Inject 废弃门禁..."
    python3 Tools/ios/audit-inject-deprecated.py || exit 1
fi
```

### 3.7 白名单管理策略

**渐进收缩**：
- P2 启动：白名单 21 个单例 + 4 个 `@EnvironmentObject` + 3 个 `UserDefaults.standard`
- 每阶段迁移完成后：从白名单删除对应条目
- P7 收尾：白名单清空，硬阻断（仅 `DatabaseManager` 基础设施层例外）

**白名单 schema**（对齐 `manual_whitelist.yml`）：
```yaml
# Config/exemptions/singleton_whitelist.yml
singleton_shared_whitelist:
  - file: <文件路径>
    symbol: <符号名>
    reason: <迁移阶段>
    expiry_check: <截止日期>
    migrated_to: <@Dependency key>
```

**CI 检查白名单有效性**：
```python
def validate_whitelist():
    whitelist = load_yaml("Config/exemptions/singleton_whitelist.yml")
    for entry in whitelist["singleton_shared_whitelist"]:
        # 检查文件是否还存在
        if not os.path.exists(entry["file"]):
            error(f"白名单条目失效：{entry['file']} 已删除，请从白名单移除")
        # 检查符号是否还存在
        content = read(entry["file"])
        if entry["symbol"] not in content:
            error(f"白名单条目失效：{entry['symbol']} 已迁移，请从白名单移除")
```

### 3.8 与现有审计脚本对齐

**遵循现有模式**：
- 脚本路径：`Tools/ios/audit-*.py`（对齐 `audit-design-magic-numbers.py` 等）
- 白名单路径：`Config/exemptions/*.yml`（对齐 `manual_whitelist.yml`）
- 输出格式：`❌` / `✅` + 文件路径 + 行号 + 修复建议
- 退出码：0 通过，1 失败
- 集成点：`make audit` + pre-push hook `--full` 模式

**遵循 AGENTS.md 红线**：
- 不硬编码文件路径（走 `Config/exemptions/` 配置）
- 不硬编码错误消息（走 `L10n` 或常量）
- 三层守门全覆盖（CI + pre-push + 本地 `make audit`）

---

## 4. 详细实施计划

### 4.1 阶段总览

| 阶段 | 名称 | 工时 | 依赖 | CI 门禁 | 验证标准 |
|------|------|------|------|---------|----------|
| P1 | 基建搭建 | 3 天 | 无 | 无 | `swift-dependencies` 编译通过 + `AppModel`/`DependencyContainer` 骨架就绪 |
| P2 | 低风险迁移 | 1 周 | P1 | CI-1 上线 | 6 个低引用单例迁移完成 + 白名单减少 6 项 |
| P3 | 中风险迁移 | 1.5 周 | P2 | CI-2 上线 | 4 个中引用单例迁移完成 + `@EnvironmentObject` 白名单减少 4 项 |
| P4 | 已半迁移收尾 | 1 周 | P3 | CI-3 上线 | 4 个已半迁移单例收尾 + `UserDefaults.standard` 白名单减少 3 项 |
| P5 | 高风险迁移 | 2 周 | P4 | 无 | 4 个高引用单例迁移完成 + `DatabaseManager` 测试改造 |
| P6 | 极高风险迁移 | 2 周 | P5 | 无 | 3 个极高频单例迁移完成 + 全量测试零失败 |
| P7 | 收尾清理 | 1 周 | P6 | CI-4 上线 | `@Inject`/`ServiceContainer`/`testOverride`/`Localized` 静态缓存全部删除 |
| P8 | 最终验证 | 3 天 | P7 | 全部门禁 | 综合评分 9.5 + 全量测试零失败 + 快照零漂移 |

**总工时**：6-8 周

### 4.2 P1: 基建搭建（3 天）

#### 任务分解

| # | 任务 | 文件 | 验证 |
|---|------|------|------|
| P1-1 | 新增 `swift-dependencies` SPM 依赖 | `Packages/UFPCore/Package.swift` | `swift build` 通过 |
| P1-2 | 创建 `AppModel` 骨架 | `Sources/App/AppModel.swift` | 编译通过，21 个 State 占位 |
| P1-3 | 创建 `DependencyContainer` 骨架 | `Sources/Core/DependencyContainer.swift` | 编译通过，21 个 `@Dependency` 占位 |
| P1-4 | 创建 `DependencyValues` 注册入口 | `Sources/Core/Dependencies/Register.swift` | 编译通过，21 个 DependencyKey 占位 |
| P1-5 | `ZhiYuApp` 注入 `AppModel` + `DependencyContainer` | `Sources/App/ZhiYuApp.swift` | App 启动正常，现有功能不受影响 |
| P1-6 | 创建 `AppModel.preview()` + `DependencyContainer.mock()` | `Sources/App/AppModel.swift` | 快照测试可调用 |

#### P1 验证标准
- [ ] `swift build` 编译通过
- [ ] `make ios` 构建通过
- [ ] App 启动正常，现有功能不受影响
- [ ] `AppModel.preview()` 可调用
- [ ] `DependencyContainer.mock()` 可调用
- [ ] 现有测试全部通过（无回归）

### 4.3 P2: 低风险迁移（1 周）

#### 迁移对象（6 个 🟢 低引用单例）

| # | 单例 | Sources/ 引用 | State | Service | 迁移策略 |
|---|------|---------------|-------|---------|----------|
| P2-1 | `ActivityService` | 1 | `ActivityState` | `@Dependency(\.activityService)` | 最简单，先做 |
| P2-2 | `AppEnvironment` | 2 | `AppState` | `@Dependency(\.appEnvironment)` | 已半迁移 |
| P2-3 | `MedalService` | 2 | `MedalState` | `@Dependency(\.medalService)` | `@EnvironmentObject` → `@Environment` |
| P2-4 | `StoreKitService` | 3 | `StoreKitState` | `@Dependency(\.storeKitService)` | IAP 服务 |
| P2-5 | `TooltipManager` | 2 | `TooltipState` | `@Dependency(\.tooltipManager)` | UI 提示状态 |
| P2-6 | `VoiceSpeechState` | 4 | `VoiceSpeechState` | `@Dependency(\.voiceSpeech)` | 语音状态 |

#### P2 迁移模板（以 `ActivityService` 为例）

**Step 1: 拆分 State + Service**
```swift
// Sources/Features/Insight/Activity/ActivityState.swift
@MainActor
public struct ActivityState: Sendable {
    public var activities: [Activity] = []
    public var totalCount: Int = 0
}

// Sources/Features/Insight/Activity/ActivityService.swift
@MainActor
@Observable
public final class ActivityService {
    public var state: ActivityState

    public init(state: ActivityState = .init()) {
        self.state = state
    }

    public func record(_ activity: Activity) {
        state.activities.append(activity)
        state.totalCount += 1
    }
}
```

**Step 2: 注册 `@Dependency`**
```swift
// Sources/Core/Dependencies/Register.swift
extension DependencyValues {
    @MainActor var activityService: ActivityService {
        get { self[ActivityServiceKey.self] }
        set { self[ActivityServiceKey.self] = newValue }
    }
}

private enum ActivityServiceKey: DependencyKey {
    static let live: ActivityService = ActivityService()
    static let test: ActivityService = ActivityService(state: .mock())
    static let preview: ActivityService = ActivityService(state: .preview())
}
```

**Step 3: 替换 `.shared` 引用**
```swift
// 迁移前
ActivityService.shared.record(activity)

// 迁移后（Service 层）
@Dependency(\.activityService) var activityService
activityService.record(activity)

// 迁移后（View 层）
@Environment(DependencyContainer.self) var dependencies
dependencies.activityService.record(activity)
```

**Step 4: `AppModel` 持有 State**
```swift
// Sources/App/AppModel.swift
public var activity: ActivityState = .init()

// 同步状态
func syncActivityState(from service: ActivityService) {
    activity = service.state
}
```

**Step 5: 从白名单删除**
```yaml
# Config/exemptions/singleton_whitelist.yml
# 删除：- file: Sources/Features/Insight/Activity/ActivityService.swift
```

#### P2 CI 门禁上线

**CI-1: `audit-singleton-frozen.py`**：
- 白名单从 21 项减少到 15 项
- 禁止新增 `static let shared`

#### P2 验证标准
- [ ] 6 个单例全部迁移完成
- [ ] `audit-singleton-frozen.py` 通过（白名单 15 项）
- [ ] `make test` 全部通过
- [ ] `make ios` 构建通过
- [ ] 快照测试零精度漂移

### 4.4 P3: 中风险迁移（1.5 周）

#### 迁移对象（4 个 🟡 中引用单例）

| # | 单例 | Sources/ 引用 | 特殊处理 |
|---|------|---------------|----------|
| P3-1 | `Router` | 6 | `@Observable` 已有，改 `@Environment` |
| P3-2 | `GlobalModelManager` | 7 | `activeModelId`/`activeCloudModelId` 状态 |
| P3-3 | `LLMService` | 7 | `@EnvironmentObject` → `@Environment` + `@Dependency` |
| P3-4 | `SourceStore` | 7 | 知识源存储 |

#### P3 特殊处理：`LLMService` 双重注入

`LLMService` 既是 `@EnvironmentObject`（View 层）又是 `@Inject`（Service 层），需要双重迁移：

```swift
// View 层：@EnvironmentObject → @Environment
// 迁移前
@EnvironmentObject var llmService: LLMService

// 迁移后
@Environment(DependencyContainer.self) var dependencies
var llmService: LLMService { dependencies.llmService }

// Service 层：@Inject → @Dependency
// 迁移前
@Inject var llmService: LLMService

// 迁移后
@Dependency(\.llmService) var llmService
```

#### P3 CI 门禁上线

**CI-2: `audit-environment-object.py`**：
- 白名单从 4 项减少到 1 项（仅剩 `OnboardingService`/`ThemeManager`/`MedalService` 待 P4/P5 迁移）
- 禁止 `Sources/` 中新增 `@EnvironmentObject`

#### P3 验证标准
- [ ] 4 个单例全部迁移完成
- [ ] `audit-environment-object.py` 通过（白名单 1 项）
- [ ] `audit-singleton-frozen.py` 通过（白名单 11 项）
- [ ] `make test` 全部通过
- [ ] 快照测试零精度漂移

### 4.5 P4: 已半迁移收尾（1 周）

#### 迁移对象（4 个 ⚪ 已半迁移单例）

| # | 单例 | Sources/ 引用 | 特殊处理 |
|---|------|---------------|----------|
| P4-1 | `OnboardingService` | 0 | `@EnvironmentObject` → `@Environment` |
| P4-2 | `IngestQueue` | 0 | `@Published isProcessing` → `@Observable` |
| P4-3 | `SchemaService` | 0 | Schema 状态 |
| P4-4 | `PencilManager` | 0 | Pencil 状态 |

#### P4 特殊处理：`OnboardingService`

`OnboardingService` 是 `NotebookHubViewSnapshots` 失败的根因之一，迁移后快照测试应稳定：

```swift
// 迁移前
@EnvironmentObject var onboardingService: OnboardingService

// 迁移后
@Environment(AppModel.self) var appModel
var hasCompletedOnboarding: Bool { appModel.onboarding.hasCompletedOnboarding }
```

#### P4 CI 门禁上线

**CI-3: `audit-userdefaults-standard.py`**：
- 白名单从 3 项减少到 1 项（仅剩 `Register.swift`）
- 禁止 `Sources/` 中新增 `UserDefaults.standard` 直接调用

#### P4 验证标准
- [ ] 4 个单例全部迁移完成
- [ ] `audit-userdefaults-standard.py` 通过（白名单 1 项）
- [ ] `audit-environment-object.py` 通过（白名单 0 项，硬阻断）
- [ ] `audit-singleton-frozen.py` 通过（白名单 7 项）
- [ ] `make test` 全部通过
- [ ] `NotebookHubViewSnapshots` 零精度漂移（关键验证点）

### 4.6 P5: 高风险迁移（2 周）

#### 迁移对象（4 个 🟠 高引用单例）

| # | 单例 | Sources/ 引用 | Tests/ 引用 | 特殊处理 |
|---|------|---------------|-------------|----------|
| P5-1 | `VaultService` | 18 | ~30 | `vaults`/`selectedVaultID` 状态 |
| P5-2 | `ThemeManager` | 17 | ~20 | `@EnvironmentObject` → `@Environment` |
| P5-3 | `AuthSession` | 23 | ~40 | 认证状态 |
| P5-4 | `DatabaseManager` | 21 | **204** | 保留 `shared` + `private(set)` + `@testable reset()` |

#### P5 特殊处理：`DatabaseManager`（204 次测试引用）

**策略**：保留 `shared` 单例（基础设施层），但改造为 `private(set)` + `@testable`：

```swift
// Sources/Infrastructure/Storage/Persistence/DatabaseManager.swift
@MainActor
public final class DatabaseManager {
    public static let shared = DatabaseManager()

    // 状态改为 private(set)
    @available(*, deprecated, message: "使用 @Dependency(\\.databaseManager)")
    public private(set) var database: Connection?

    // 测试专用 reset
    @testable internal func reset() { ... }
}
```

**测试迁移策略**：
```swift
// 迁移前（204 次引用）
DatabaseManager.shared.database

// 迁移后
@Dependency(\.databaseManager) var databaseManager
databaseManager.database
```

**白名单特殊处理**：
```yaml
# Config/exemptions/singleton_whitelist.yml
# DatabaseManager 保留白名单（基础设施层例外）
- file: Sources/Infrastructure/Storage/Persistence/DatabaseManager.swift
  symbol: DatabaseManager.shared
  reason: 基础设施层例外，保留单例
  expiry_check: never
  migrated_to: "@Dependency(\\.databaseManager) + private(set)"
```

#### P5 验证标准
- [ ] 4 个单例全部迁移完成
- [ ] `audit-singleton-frozen.py` 通过（白名单 4 项，含 `DatabaseManager` 例外）
- [ ] `make test` 全部通过
- [ ] `DatabaseManager` 测试改造完成（204 次引用迁移）
- [ ] 快照测试零精度漂移

### 4.7 P6: 极高风险迁移（2 周）

#### 迁移对象（3 个 🔴 极高频单例）

| # | 单例 | Sources/ 引用 | 特殊处理 |
|---|------|---------------|----------|
| P6-1 | `TaskCenter` | 76 | 任务中心，最高频 |
| P6-2 | `PluginRegistry` | 46 | 插件注册表 |
| P6-3 | `ToastManager` | 42 | Toast 提示 |

#### P6 迁移策略：分批替换 + 回归测试

**每个单例迁移流程**：
1. **Day 1-2**：拆分 State + Service + 注册 `@Dependency`
2. **Day 3-4**：替换 `Sources/` 中所有 `.shared` 引用（分批，每批 10 个文件）
3. **Day 5**：运行 `make test` 回归测试
4. **Day 6-7**：修复回归问题 + 从白名单删除

**`TaskCenter` 迁移示例**（76 次引用）：
```swift
// Sources/Features/AI/TaskCenter/Service/TaskCenter.swift
@MainActor
@Observable
public final class TaskCenter {
    public var state: TaskCenterState

    public init(state: TaskCenterState = .init()) {
        self.state = state
    }

    public func execute(_ task: Task) async throws {
        // 业务逻辑
    }
}

// Sources/Core/Dependencies/Register.swift
private enum TaskCenterKey: DependencyKey {
    static let live: TaskCenter = TaskCenter()
    static let test: TaskCenter = TaskCenter(state: .mock())
    static let preview: TaskCenter = TaskCenter(state: .preview())
}
```

#### P6 验证标准
- [ ] 3 个单例全部迁移完成
- [ ] `audit-singleton-frozen.py` 通过（白名单 1 项，仅剩 `DatabaseManager`）
- [ ] `make test` 全部通过
- [ ] 全量测试零失败（关键验证点）
- [ ] 快照测试零精度漂移

### 4.8 P7: 收尾清理（1 周）

#### 任务分解

| # | 任务 | 文件 | 验证 |
|---|------|------|------|
| P7-1 | 删除 `@Inject` 属性包装器 | `Packages/UFPCore/Sources/UFPCore/Base/ServiceContainer.swift` | 全量替换为 `@Dependency` |
| P7-2 | 删除 `ServiceContainer` 注册代码 | `Sources/App/ModuleRegistrar.swift` | `ModuleRegistrar` 改为 `DependencyRegistrar` |
| P7-3 | 删除 `setupFullMockEnvironment()` | `Tests/Shared/TestMocks.swift` | 替换为 `withDependencies { $0 = .mock }` |
| P7-4 | 删除 3 个 `testOverride` | `KeychainService`/`SecurityManager`/`SecureEnclaveCryptoService` | 改为 `@Dependency` |
| P7-5 | 迁移 `Localized` 静态缓存 | `Sources/Core/Base/Utils/Localized.swift` | `languageMode`/`cachedBundle`/`cachedLanguage` → `@Dependency` |
| P7-6 | 删除 `resetPersistentTestState()` | `Tests/Shared/TestMocks.swift` | 不再需要手动重置 |
| P7-7 | 删除 `NotebookHubViewSnapshots.setUp` 手动重置 | `Tests/SnapshotTests/NotebookHubViewSnapshots.swift` | 改为 `AppModel.preview()` |
| P7-8 | 删除 `IngestQueueTests.tearDown` 手动清理 | `Tests/Integration/IngestQueueTests.swift` | 改为 `withDependencies` |

#### P7 CI 门禁上线

**CI-4: `audit-inject-deprecated.py`**：
- 禁止 `@Inject`
- 禁止 `nonisolated(unsafe) static var`
- 禁止 `static var testOverride`

#### P7 验证标准
- [ ] `@Inject` 完全删除
- [ ] `ServiceContainer` 完全删除
- [ ] `setupFullMockEnvironment()` 完全删除
- [ ] 3 个 `testOverride` 完全删除
- [ ] `Localized` 静态缓存迁移完成
- [ ] `audit-inject-deprecated.py` 通过
- [ ] `audit-singleton-frozen.py` 通过（白名单 1 项，仅 `DatabaseManager`）
- [ ] `make test` 全部通过

### 4.9 P8: 最终验证（3 天）

#### 验证清单

| # | 验证项 | 命令 | 期望结果 |
|---|--------|------|----------|
| P8-1 | 全量测试 | `make test` | 零失败 |
| P8-2 | 全量 SPM 单测 | `make test-spm-all` | 零失败 |
| P8-3 | 架构审计 | `make audit` | 12 项门禁全通过 |
| P8-4 | iOS 构建 | `make ios` | 通过 |
| P8-5 | macOS 构建 | `make mac` | 通过 |
| P8-6 | watchOS 构建 | `make watch` | 通过 |
| P8-7 | 快照测试 | `make test-snapshots` | 零精度漂移 |
| P8-8 | 综合评分 | 第四次审计 | 9.5/10 |
| P8-9 | pre-push hook | `Tools/git/pre-push-hook.sh --full` | 13 项门禁全通过 |

#### P8 交付物
- 第四次深度审计报告（综合评分 9.5）
- 改进任务清单全部完成
- 缺陷文档 S9-1 ~ S9-26 全部关闭
- CI 4 个新门禁脚本上线
- 白名单最终态：仅 `DatabaseManager` 例外

### 4.10 风险与缓解

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|----------|
| `DatabaseManager` 204 次测试引用迁移失败 | 中 | 高 | 保留 `shared` + `private(set)` + `@testable reset()`，白名单例外 |
| `TaskCenter` 76 次引用迁移引入回归 | 中 | 高 | 分批替换（每批 10 文件）+ 每批回归测试 |
| `swift-dependencies` 与 Swift 6 严格并发不兼容 | 低 | 高 | P1 阶段先验证编译，不兼容则回退方案 B |
| 快照测试精度漂移 | 中 | 中 | 每阶段验证快照，`AppModel.preview()` 保证确定性 |
| 迁移工时超预期 | 中 | 中 | 每阶段独立可验证，可暂停在任意阶段 |

---

## 5. 参考文档

- [第三次深度审计报告](../Audit/2026-08-10-third-deep-quality-audit.md)
- [改进任务清单](../Audit/2026-08-10-improvement-task-list.md)
- [缺陷清单](../Audit/2026-08-10-review-defects.md)
- [分层架构定义](LAYERING_L0_L3.md)
- [swift-dependencies 官方文档](https://swiftpackage.com/pointfreeco/swift-dependencies)
