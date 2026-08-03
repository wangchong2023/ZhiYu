# 智宇 (ZhiYu) SRP 文件拆分原则与组织规范

> **版本**: 1.0  
> **生效日期**: 2026-06-22  
> **前置阅读**: [`LAYERING_L0_L3.md`](../Architecture/LAYERING_L0_L3.md) — L0-L3 严格分层依赖规范  
> **关联文档**: [`file-header-template.md`](./file-header-template.md) — 文件头注释模板规范  

---

## 1. SRP 文件拆分原则

### 1.1 单一职责原则（Single Responsibility Principle）

> **每个文件只做一件事，并且做好它。**

在智宇项目中，SRP 文件拆分遵循以下硬性约束：

| 规则 | 要求 |
|------|------|
| **最大行数** | 每个文件 ≤ **500 行** |
| **理想行数** | 100 – 300 行 |
| **硬上限** | 超过 500 行强制拆分（CI `audit-code-swift-quality.py` 会阻断） |
| **文件头规范** | 每个文件必须标注 `系统层级` + 独有 `核心职责` |

### 1.2 为什么需要 SRP 拆分？

大型 Swift 文件（600+ 行）在智宇项目中存在以下问题：

- **编译时间增长**：Swift 编译器对大型文件的重编译开销显著
- **代码审查困难**：PR diff 淹没在大量上下文中
- **命名冲突风险**：私有扩展和 helper 函数命名碰撞
- **测试覆盖不足**：巨型文件的方法难以独立单元测试
- **Swift 6 并发风险**：大型 `@MainActor` 类中的状态管理变得难以追踪

### 1.3 Swift Extension 跨文件拆分

Swift 的 `extension` 天然支持将类型的功能分散到多个文件中。但需要处理访问级别变化：

```swift
// ── 拆分前（单文件，700 行） ──
// PluginDetailView.swift
struct PluginDetailView: View {
    // MARK: - Properties (40 行)
    @State private var name: String = ""
    @State private var isEnabled: Bool = false
    // ... 大量属性 ...

    // MARK: - Body (30 行)
    var body: some View { /* ... */ }

    // MARK: - Header Section (150 行)
    private var headerSection: some View { /* ... */ }
    private func headerAction() { /* ... */ }

    // MARK: - Metadata Panel (120 行)
    private var metadataPanel: some View { /* ... */ }

    // MARK: - Permissions Panel (80 行)
    private var permissionsPanel: some View { /* ... */ }

    // MARK: - Changelog Section (90 行)
    private var changelogSection: some View { /* ... */ }

    // MARK: - Actions (60 行)
    private func installPlugin() { /* ... */ }
    private func uninstallPlugin() { /* ... */ }
}
```

```swift
// ── 拆分后（7 个文件，主文件 104 行） ──

// 1. PluginDetailView.swift (104 行) — 薄容器
struct PluginDetailView: View {
    @State var name: String = ""
    @State var isEnabled: Bool = false
    // ... 仅保留状态属性 ...

    var body: some View {
        ScrollView {
            PluginDetailHeader(name: $name)        // → 子组件
            PluginDetailMetadata(plugin: plugin)    // → 子组件
            PluginDetailPermissions(plugin: plugin) // → 子组件
            PluginDetailChangelog(logs: changelog)  // → 子组件
        }
    }
}

// 2. PluginDetailView+Header.swift (70 行)
// 3. PluginDetailView+Metadata.swift (80 行)
// 4. PluginDetailView+Permissions.swift (75 行)
// 5. PluginDetailView+Changelog.swift (65 行)
// 6. PluginDetailView+Actions.swift (60 行)
// 7. PluginDetailView+Preview.swift (30 行)
```

### 1.4 访问级别调整规则

跨文件拆分时，原本 `private` 的属性/方法需要提升为 `internal`：

```swift
// ❌ 拆分前：private 属性
struct PluginDetailView: View {
    private var plugin: PluginRecord  // ← 子文件无法访问
    private func installPlugin() { }
}

// ✅ 拆分后：internal 属性（同模块内 extension 可访问）
struct PluginDetailView: View {
    // 注意：从 private 提升为 internal
    var plugin: PluginRecord           // ← extension 文件可访问
    func installPlugin() { }           // ← extension 文件可调用
}

// extension 文件
extension PluginDetailView {
    var permissionsPanel: some View {
        // 可以访问 plugin 和 installPlugin()
    }
}
```

> ⚠️ **注意**：`internal` 是 Swift 的默认访问级别。跨文件 extension 需要访问的属性**不能**保持 `private`。

---

## 2. SRP 重构方法论

### 2.1 四步重构流程

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  ① 分析      │ → │  ② 拆分      │ → │  ③ 组合      │ → │  ④ 验证      │
│  识别功能域   │    │  提取子文件   │    │  主文件变薄   │    │  编译+SwiftLint│
│               │    │               │    │  容器         │    │  +CI Gatekeeper│
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
```

#### 步骤 ①：分析 — 识别功能域分组

打开目标文件，按 `// MARK: -` 注释和实际功能识别可以独立的分组：

| 分组类型 | 识别特征 | 拆分方式 |
|---------|---------|---------|
| Section | `var xxxSection: some View` | 提取为独立子 View struct |
| Method | 功能独立的方法组（如 Auth 方法） | 提取为 Service extension 文件 |
| Panel | 复杂的面板视图 | 提取为独立子 View struct |
| Helper | 工具函数集合 | 提取为 Utility extension 文件 |
| Preview | `#Preview` 宏 | 提取为 `+Preview.swift` |

#### 步骤 ②：拆分 — 每个功能域提取为新文件

命名规范：`{原文件名}+{功能域}.swift`

```swift
// 文件命名示例
ModelLabView.swift              // 主容器
ModelLabView+Sections.swift     // Section 视图组
ModelLabView+LabGrid.swift      // 网格布局
ModelLabView+DetailPanel.swift  // 详情面板
ModelLabView+SearchBar.swift    // 搜索栏
ModelLabView+Actions.swift      // 操作按钮组
```

#### 步骤 ③：组合 — 主文件变为薄容器

```swift
// 拆分后的主文件（薄容器模式）
struct ModelLabView: View {
    // 仅保留：
    // 1. @State / @StateObject / @EnvironmentObject 状态
    // 2. @Inject 依赖
    // 3. body 组合调用子组件
    // 4. 跨子组件共享的回调方法
    @State private var searchText = ""
    @State private var selectedModel: ModelInfo?
    @Inject private var modelManager: any ModelDownloadCapabilities

    var body: some View {
        VStack {
            ModelLabSearchBar(text: $searchText)       // → 子组件
            ModelLabGrid(
                models: filteredModels,
                selected: $selectedModel                // → @Binding 传递
            )
            if let model = selectedModel {
                ModelLabDetailPanel(model: model)        // → 子组件
            }
        }
    }

    // 跨子组件共享的计算属性
    var filteredModels: [ModelInfo] {
        modelManager.models.filter { $0.name.contains(searchText) }
    }
}
```

#### 步骤 ④：验证 — 编译 + SwiftLint + CI Gatekeeper

```bash
# 1. 编译验证
xcodebuild -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator' build

# 2. SwiftLint 检查
swiftlint lint --config .swiftlint.yml

# 3. CI 门禁
bash Tools/ci/run-code-static-analysis.sh

# 4. 文件头检查
python3 Tools/ios/check-code-file-headers.py
```

---

## 3. SRP 重构案例表

以下是智宇项目中已完成的 9 个大文件 SRP 重构结果：

| 文件 | 重构前行数 | 重构后行数 | 新建文件数 | 减少比例 | 拆分策略 |
|------|-----------|-----------|-----------|---------|---------|
| `ModelLabView` | 1,239 | 126 | 10 | **-90%** | Sections + Grid + Detail + Search |
| `TagCloudView` | 778 | 93 | 5 | **-88%** | Layout + Bubble + Animation + Config |
| `PluginDetailView` | 732 | 104 | 7 | **-86%** | Header + Meta + Permissions + Changelog |
| `RAGEvaluationView` | 678 | 146 | 3 | **-78%** | Results + Metrics + Controls |
| `LintView` | 626 | 146 | 3 | **-77%** | RuleList + DetailPanel + Actions |
| `PluginRegistry` | 706 | 159 | 3 | **-77%** | Loader + Validator + Store |
| `SubscriptionPlanView` | 700 | 259 | 3 | **-63%** | PlanCard + FeatureList + Checkout |
| `AuthService` | 683 | 283 | 3 | **-59%** | OAuth + PhoneAuth + TokenManager |
| `SynthesisView` | 696 | 523 | 3 | **-25%** | SourceList + OutputPanel + Controls |

### 3.1 案例分析：ModelLabView（1,239 → 126 行，-90%）

**重构前问题**：
- 1,239 行单文件，包含 12 个 `// MARK: -` 分组
- 每次编译增量改动需重新编译整个文件
- PR review 时 diff 淹没在大量上下文中

**拆分方案**：

```text
Sources/Features/AI/ModelLab/View/
├── ModelLabView.swift               (126 行) ← 薄容器
├── ModelLabView+Sections.swift      (95 行)  ← Section 视图
├── ModelLabView+LabGrid.swift       (110 行) ← 网格布局
├── ModelLabView+SearchBar.swift     (85 行)  ← 搜索栏
├── ModelLabView+ModelCard.swift     (120 行) ← 模型卡片
├── ModelLabView+DetailPanel.swift   (130 行) ← 详情面板
├── ModelLabView+DownloadQueue.swift (105 行) ← 下载队列
├── ModelLabView+EmptyState.swift    (65 行)  ← 空状态
├── ModelLabView+LoadingState.swift  (55 行)  ← 加载态
├── ModelLabView+ErrorState.swift    (60 行)  ← 错误态
└── ModelLabView+Preview.swift       (35 行)  ← Preview
```

---

## 4. View 拆分模式

### 4.1 Container → Sections/Components 拆分

**模式**：将巨型 View 的 `body` 中的各个 `Section`/`Panel` 提取为独立 `struct`：

```swift
// ── 拆分前：所有 Section 内联在 body 中 ──
struct SettingsView: View {
    var body: some View {
        List {
            Section("通用") {
                Toggle("暗色模式", isOn: $isDarkMode)
                Picker("语言", selection: $language) { /* ... */ }
            }
            Section("同步") {
                Toggle("iCloud 同步", isOn: $iCloudSync)
                Button("立即同步") { /* ... */ }
            }
            Section("关于") {
                Text("版本 \(appVersion)")
                Link("隐私政策", destination: privacyURL)
            }
        }
    }
}

// ── 拆分后：Section 提取为独立 View ──
struct SettingsView: View {
    @State private var isDarkMode = false
    @State private var language = "zh-Hans"
    @State private var iCloudSync = true
    @Inject private var appEnv: any AppEnvironmentProtocol

    var body: some View {
        List {
            GeneralSettingsSection(isDarkMode: $isDarkMode, language: $language)
            SyncSettingsSection(iCloudSync: $iCloudSync)
            AboutSettingsSection()
        }
    }
}

// Sources/Features/System/Settings/View/Sections/GeneralSettingsSection.swift
struct GeneralSettingsSection: View {
    @Binding var isDarkMode: Bool
    @Binding var language: String

    var body: some View {
        Section(L10n.Settings.general) {
            Toggle(L10n.Settings.darkMode, isOn: $isDarkMode)
            Picker(L10n.Settings.language, selection: $language) { /* ... */ }
        }
    }
}
```

### 4.2 状态管理保留在容器中

**核心原则**：状态（`@State`、`@StateObject`、`@EnvironmentObject`）始终保留在**主容器 View** 中，子视图通过 `@Binding` 接收：

```swift
// ✅ 正确：状态在容器中，子视图通过 @Binding 通信
struct ContainerView: View {
    @State private var searchText = ""         // ← 状态在此
    @State private var selectedItem: Item?     // ← 状态在此

    var body: some View {
        VStack {
            SearchBar(text: $searchText)        // ← @Binding 传递
            ItemList(items: filteredItems, selected: $selectedItem)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String                  // ← 接收 @Binding
    var body: some View { TextField("搜索", text: $text) }
}
```

```swift
// ❌ 错误：子视图中创建独立状态
struct SearchBar: View {
    @State private var text = ""               // ← 重复状态！
    var body: some View { TextField("搜索", text: $text) }
}
```

### 4.3 View 文件命名规范

| 文件类型 | 命名规范 | 示例 |
|---------|---------|------|
| 主容器 View | `{Feature}View.swift` | `ModelLabView.swift` |
| Section 扩展 | `{Feature}View+{Section}.swift` | `ModelLabView+Sections.swift` |
| 子组件 View | `{ComponentName}.swift` | `ModelCard.swift` |
| 状态视图 | `{Feature}View+{State}.swift` | `ModelLabView+EmptyState.swift` |
| Preview | `{Feature}View+Preview.swift` | `ModelLabView+Preview.swift` |

---

## 5. Service 拆分模式

### 5.1 按功能域拆分

Service 类通常包含多个功能域，每个功能域一个 extension 文件：

```swift
// ── 拆分前：AuthService.swift (683 行) ──
final class AuthService {
    // OAuth 相关 (200 行)
    func signInWithApple() async throws { }
    func signInWithWeChat() async throws { }
    func signInWithGitHub() async throws { }

    // 手机号认证 (150 行)
    func sendVerificationCode(to phone: String) async throws { }
    func verifyCode(_ code: String, for phone: String) async throws { }

    // Token 管理 (120 行)
    func refreshToken() async throws { }
    func storeToken(_ token: AuthToken) { }
    func loadToken() -> AuthToken? { }

    // 会话管理 (100 行)
    func signOut() { }
    var currentSession: AuthSession? { }
}

// ── 拆分后：AuthService 薄协调器 + 3 个功能文件 ──

// 1. AuthService.swift (283 行) — Thin Coordinator
final class AuthService: ObservableObject {
    @Published var currentSession: AuthSession?
    private let oauthHandler = OAuthHandler()
    private let phoneAuthHandler = PhoneAuthHandler()
    private let tokenManager = TokenManager()

    func signInWithApple() async throws {
        let token = try await oauthHandler.signInWithApple()
        try tokenManager.storeToken(token)
        currentSession = AuthSession(token: token, provider: .apple)
    }

    func signOut() {
        tokenManager.clearToken()
        currentSession = nil
    }
}

// 2. AuthService+OAuth.swift (140 行)
extension AuthService {
    struct OAuthHandler {
        func signInWithApple() async throws -> AuthToken { /* ... */ }
        func signInWithWeChat() async throws -> AuthToken { /* ... */ }
        func signInWithGitHub() async throws -> AuthToken { /* ... */ }
    }
}

// 3. AuthService+PhoneAuth.swift (120 行)
extension AuthService {
    struct PhoneAuthHandler {
        func sendVerificationCode(to phone: String) async throws { /* ... */ }
        func verifyCode(_ code: String, for phone: String) async throws { /* ... */ }
    }
}

// 4. AuthService+TokenManager.swift (100 行)
extension AuthService {
    struct TokenManager {
        private let keychain = KeychainWrapper()
        func refreshToken() async throws { /* ... */ }
        func storeToken(_ token: AuthToken) { /* ... */ }
        func loadToken() -> AuthToken? { /* ... */ }
        func clearToken() { /* ... */ }
    }
}
```

### 5.2 Thin Coordinator 聚合模式

```swift
// 主 Service 文件只做两件事：
// 1. 持有子功能 handler 实例
// 2. 编排跨功能域的调用流程

final class AuthService: ObservableObject {
    // 子功能 handler（internal，允许 extension 文件访问）
    let oauthHandler = OAuthHandler()
    let phoneAuthHandler = PhoneAuthHandler()
    let tokenManager = TokenManager()

    // 跨功能域编排
    func authenticateWithApple() async throws {
        let token = try await oauthHandler.signInWithApple()  // → OAuth
        try tokenManager.storeToken(token)                     // → Token
        await loadUserProfile(token: token)                    // → 编排
    }
}
```

---

## 6. 注意事项

### 6.1 @Published 不能用于计算属性

`@Published` 只能修饰存储属性（`var x: T`），不能修饰计算属性（`var x: T { get set }`）。

```swift
// ❌ 编译错误：@Published 不能用于计算属性
@Published var displayName: String {
    firstName + " " + lastName
}

// ✅ 方案 1：存储属性 + didSet 同步
@Published var displayName: String = ""
private var firstName: String = "" {
    didSet { displayName = firstName + " " + lastName }
}

// ✅ 方案 2：Combine relay（跨文件拆分时推荐）
@Published private var firstName: String = ""
@Published private var lastName: String = ""
var displayNamePublisher: AnyPublisher<String, Never> {
    $firstName.combineLatest($lastName)
        .map { $0 + " " + $1 }
        .eraseToAnyPublisher()
}
```

### 6.2 跨文件 extension 需要 `internal` 访问级别

```swift
// 主文件：PluginDetailView.swift
struct PluginDetailView: View {
    var plugin: PluginRecord        // ← internal（不是 private）
    var onInstall: () -> Void       // ← internal
    @State var isLoading = false    // ← internal

    var body: some View { /* ... */ }
}

// 子文件：PluginDetailView+Header.swift
extension PluginDetailView {
    var headerSection: some View {
        VStack {
            Text(plugin.name)       // ← 可访问 internal 属性
            Button("安装") {
                isLoading = true
                onInstall()
            }
        }
    }
}
```

### 6.3 子文件必须通过 xcodegen generate 注册

智宇项目使用 XcodeGen 管理 `.xcodeproj` 文件。每次添加新文件后，必须更新 `project.yml` 并重新生成：

```bash
# 1. 在 project.yml 的 sources 中添加新文件
# 2. 重新生成项目
xcodegen generate

# 或使用项目提供的构建脚本
bash Tools/ci/build-pipeline-all.sh
```

### 6.4 拆分后确保文件头注释完整

每个新文件必须包含正确的文件头：

```swift
//
//  ModelLabView+Sections.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/22.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：ModelLabView 的 Section 分组视图组件。
//
```

参见 [`file-header-template.md`](./file-header-template.md) 了解完整规范。

### 6.5 避免过度拆分

| 信号 | 含义 | 行动 |
|------|------|------|
| 文件 < 50 行 | 可能拆分过细 | 合并回父文件 |
| 单一方法提取 | 拆分粒度过细 | 至少按功能域分组 |
| 大量 `internal` 暴露 | 耦合过紧 | 考虑提取为新类型而非 extension |
| extension 文件间相互调用 | 循环依赖 | 提取为独立 struct/class |

### 6.6 Swift 6 严格并发注意事项

拆分后的文件需确保并发安全：

```swift
// ✅ 拆分后仍需标注 @MainActor
@MainActor
struct PluginDetailView: View { /* ... */ }

// ✅ 子文件同样标注
@MainActor
extension PluginDetailView {
    var headerSection: some View { /* ... */ }
}

// ✅ 非 UI 子文件使用 Sendable
extension AuthService {
    struct TokenManager: Sendable {
        func storeToken(_ token: AuthToken) { /* ... */ }
    }
}
```

---

## 附录 A：文件行数检查命令

```bash
# 检查所有 Swift 文件行数，标记超过 500 行的文件
find Sources -name "*.swift" -exec wc -l {} + | awk '$1 > 500 {print $0}' | sort -rn

# 在 CI 中自动执行（audit-code-swift-quality.py）
python3 Tools/ios/audit-code-swift-quality.py
```

## 附录 B：xcodegen project.yml 文件注册示例

```yaml
# project.yml 中添加新文件路径
targets:
  ZhiYu:
    sources:
      - path: Sources/Features/AI/ModelLab/View/ModelLabView.swift
      - path: Sources/Features/AI/ModelLab/View/ModelLabView+Sections.swift
      - path: Sources/Features/AI/ModelLab/View/ModelLabView+LabGrid.swift
      - path: Sources/Features/AI/ModelLab/View/ModelLabView+SearchBar.swift
      - path: Sources/Features/AI/ModelLab/View/ModelLabView+ModelCard.swift
      # ... 更多文件 ...
```

---

> **维护者**: 架构组  
> **最后更新**: 2026-06-22  
> **关联参考**:  
> - [`development-standards.md`](./development-standards.md) — 核心编码规范  
> - [`swift-coding-style.md`](./swift-coding-style.md) — Swift 代码风格  
> - [`implementation-patterns.md`](./implementation-patterns.md) — 实现模式参考
