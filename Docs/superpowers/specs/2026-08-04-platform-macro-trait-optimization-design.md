# 平台宏运行时 Trait 优化设计方案

> 版本: 1.0 | 日期: 2026-08-04 | 状态: 待评审

## 一、动机与目标

### 1.1 问题背景

ZhiYu 全仓库存在 **333 处平台宏**（`#if os()` / `#if !os()` / `#if canImport()` / `#if targetEnvironment` / `#elseif os()`），涉及 166 个文件。其中：

- `os(watchOS)` 占比最高（173 处），是主要差异源
- `PlatformModifiers.swift` 单文件 24 处，最密集
- **Features/Domain 层 14 处违规**（红线 7 禁止业务层使用 `#if os()`）

更严重的是：**`check-code-platform-macros.py` 存在但未被 `run-code-static-analysis.sh` 调用**，CI 门禁失效，14 处违规未阻断流水线。

### 1.2 业界实践调研

调研 Apple 官方示例（Backyard Birds / Food Truck），提炼三大模式：

| 模式 | 来源 | 核心思想 |
|------|------|---------|
| 运行时 Trait | Backyard Birds `prefersTabNavigation` | `UITraitBridgedEnvironmentKey` 把平台差异变成运行时 `EnvironmentValue`，业务层零 `#if` |
| 物理目录分离 | Backyard Birds watchOS | watchOS 独立 target + 独立 ContentView，共享逻辑走 SPM Package |
| 单一 Multiplatform Target | Food Truck | iOS/iPadOS/macOS 单 target，依赖 SwiftUI 自适应组件（不含 watchOS） |

**Apple 关键代码**：`PrefersTabNavigationKey` 用 `UITraitBridgedEnvironmentKey` 从 `UITraitCollection.userInterfaceIdiom` 读取，ContentView 用 `@Environment(\.prefersTabNavigation)` 切换 Tab vs SplitView。

### 1.3 ZhiYu 现状对比

| 维度 | ZhiYu 现状 | 业界（Apple） | 差距 |
|------|-----------|--------------|------|
| 业务层 `#if os()` | 14 处违规 | 0 处 | ❌ |
| 运行时 Trait 模式 | 无 | `prefersTabNavigation` | ❌ 缺失 |
| watchOS 隔离 | 占位 View 越界在 Features 层 | 独立 target + 独立 View | ❌ |
| Mac Catalyst | `targetEnvironment` 散落 | 运行时 idiom | ❌ |
| 服务能力 DI | `PlatformRegistrar` 三层协议 | `ModelContainer` 注入 | ✅ 领先 |
| CI 门禁 | 脚本存在但未调用 | — | ❌ 失效 |

**ZhiYu 优势**：`PlatformRegistrar` 三层协议 + DI 分发体系业界领先（Apple 示例无此完善 DI），本方案在此基础上自然延伸。

### 1.4 设计目标

1. **Features/Domain 层 `#if os()` 清零**（14 处 → 0 处）
2. **引入运行时 Trait 模式**，对齐 Apple Backyard Birds
3. **watchOS 占位 View 物理隔离**到 `Platforms/watchOS/Views/`
4. **修复 CI 门禁失效**，`check-code-platform-macros.py` 集成至静态分析
5. **4 个文档同步**更新

### 1.5 部署目标确认

| 平台 | 最低版本 | 满足 `UITraitBridgedEnvironmentKey`？ |
|------|---------|--------------------------------------|
| iOS | 17.0 | ✅（需 ≥ 17.0） |
| macOS | 14.0 | ✅（需 ≥ 14.0） |
| watchOS | 10.0 | ✅ |

---

## 二、运行时 Trait 体系设计

### 2.1 设计原则

> **UI 形态差异用运行时 Trait（`@Environment`），服务能力差异用 DI（`@Inject`）。**
>
> **能用运行时值解决就用运行时值（Trait/DI），只有类型系统不兼容时才物理隔离。**

### 2.2 Trait 清单

| Trait | EnvironmentKey | 实现方式 | 响应运行时变化 | 用途 |
|-------|---------------|---------|--------------|------|
| `interfaceIdiom` | `InterfaceIdiomKey` | 静态 `defaultValue` | ❌ | 设备形态（5 case） |
| `prefersTabNavigation` | `PrefersTabNavigationKey` | `UITraitBridgedEnvironmentKey` | ✅ | Tab vs SplitView |
| `supportsTouch` | `SupportsTouchKey` | 静态 `defaultValue` | ❌ | 触控交互 |
| `supportsFullScreenImmersive` | `SupportsFullScreenImmersiveKey` | 静态 `defaultValue` | ❌ | 全屏沉浸 |

### 2.3 实现方式选择依据

**核心判据：Trait 的值是否会在 App 运行期间发生变化。**

| Trait | 值会变吗？ | 例子 | 适合的方式 |
|-------|----------|------|-----------|
| `interfaceIdiom` | ❌ 不会变 | iPhone 永远是 iPhone | 静态 `defaultValue` |
| `supportsTouch` | ❌ 不会变 | Mac 永远无触控 | 静态 `defaultValue` |
| `supportsFullScreenImmersive` | ❌ 不会变 | 平台 API 能力固定 | 静态 `defaultValue` |
| `prefersTabNavigation` | ✅ **会变** | iPad 旋转屏幕 `false→true` | `UITraitBridgedEnvironmentKey` |

**`prefersTabNavigation` 为什么会变？**

```
iPad 竖屏（compact size class）  →  prefersTabNavigation = false  →  用 SplitView
iPad 横屏（regular size class）  →  prefersTabNavigation = true   →  用 TabView
```

- **`UITraitBridgedEnvironmentKey`**：从 `UITraitCollection.userInterfaceIdiom` + `horizontalSizeClass` 读取，Trait 变化（旋转）时 SwiftUI 自动触发 View 重绘 ✅
- **静态 `defaultValue`**：App 启动时算一次，旋转后**不更新**，UI 卡在错误状态 ❌

**其他 3 个为什么不需要？**

- `interfaceIdiom`：iPhone 不会变成 iPad — 设备形态物理固定
- `supportsTouch`：Mac 不会突然支持触控 — 硬件能力固定
- `supportsFullScreenImmersive`：平台 API 能力固定

这 3 个用静态 `defaultValue` 即可，用 `UITraitBridgedEnvironmentKey` 是过度设计（多写 `read`/`write` 方法，但值永远不变）。

### 2.4 `InterfaceIdiom` 枚举设计

**5 个 case**：`iPhone / iPad / mac / macCatalyst / watch`

| 维度 | 7 个 case | 5 个 case（采用） | 4 个 case |
|------|----------|----------------|-----------|
| `macCatalyst` | ✅ 区分 | ✅ 区分 | ❌ 合并到 `mac` |
| `tv` / `vision` | ✅ | ❌ YAGNI | ❌ |
| 实际需求 | 过度 | 匹配 ZhiYu | 1 处违规无法精确判断 |

**保留 `macCatalyst` 的价值**：`QuizPresentationModifier.swift:34` 原始代码 `#if os(iOS) && !targetEnvironment(macCatalyst)` 可用 `idiom == .iPhone || idiom == .iPad` 精确替代，运行时消除 `targetEnvironment` 宏。

### 2.5 代码实现

**文件位置**：`Sources/Shared/Platforms/Adaptor/PlatformTraits.swift`

```swift
// 系统层级：[L0] 基础设施层
// 核心职责：跨平台运行时 Trait，把 platform idiom 暴露为 EnvironmentValue

import SwiftUI

/// 当前设备形态（运行时读取，替代编译时 #if os()）
enum InterfaceIdiom: Sendable {
    case iPhone, iPad, mac, macCatalyst, watch
}

// MARK: - interfaceIdiom（静态 defaultValue）

private struct InterfaceIdiomKey: EnvironmentKey {
    static let defaultValue: InterfaceIdiom = {
        #if os(watchOS)
        return .watch
        #elseif os(macOS)
        return .mac
        #else
        #if targetEnvironment(macCatalyst)
        return .macCatalyst
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
        #endif
        #endif
    }()
}

extension EnvironmentValues {
    var interfaceIdiom: InterfaceIdiom {
        get { self[InterfaceIdiomKey.self] }
        set { self[InterfaceIdiomKey.self] = newValue }
    }
}

// MARK: - prefersTabNavigation（UITraitBridgedEnvironmentKey，响应运行时变化）

private struct PrefersTabNavigationKey: UITraitBridgedEnvironmentKey {
    static let defaultValue: Bool = false

    static func read(trait: UITraitCollection) -> Bool {
        trait.userInterfaceIdiom == .pad && trait.horizontalSizeClass != .compact
    }

    static func write(trait: inout UITraitCollection, value: Bool) {
        // 只读 Trait，不回写
    }
}

extension EnvironmentValues {
    var prefersTabNavigation: Bool {
        get { self[PrefersTabNavigationKey.self] }
        set { self[PrefersTabNavigationKey.self] = newValue }
    }
}

// MARK: - supportsTouch（静态 defaultValue）

private struct SupportsTouchKey: EnvironmentKey {
    static let defaultValue: Bool = {
        #if os(iOS) || os(watchOS)
        return true
        #else
        return false
        #endif
    }()
}

extension EnvironmentValues {
    var supportsTouch: Bool {
        get { self[SupportsTouchKey.self] }
        set { self[SupportsTouchKey.self] = newValue }
    }
}

// MARK: - supportsFullScreenImmersive（静态 defaultValue）

private struct SupportsFullScreenImmersiveKey: EnvironmentKey {
    static let defaultValue: Bool = {
        #if os(iOS) || os(macOS)
        return true
        #else
        return false
        #endif
    }()
}

extension EnvironmentValues {
    var supportsFullScreenImmersive: Bool {
        get { self[SupportsFullScreenImmersiveKey.self] }
        set { self[SupportsFullScreenImmersiveKey.self] = newValue }
    }
}
```

**关键设计决策**：

| 决策 | 选择 | 理由 |
|------|------|------|
| `#if os()` 位置 | 仅在 `EnvironmentKey.defaultValue` 静态计算内 | 这是 L0 适配层，合法；业务层零 `#if` |
| iOS 17+ `UITraitBridgedEnvironmentKey` | 仅 `prefersTabNavigation` 采用 | 部署目标 ≥ iOS 17，且该 Trait 需响应旋转 |
| `InterfaceIdiom` 枚举 | 自定义而非 `UIUserInterfaceIdiom` | 跨平台（mac/watch 不依赖 UIKit），可 `Sendable` |
| Trait 注入时机 | App 启动时根 View `.environment(\.interfaceIdiom, ...)` | 允许运行时覆盖（测试/预览方便） |

### 2.6 与现有 PlatformRegistrar 的关系

```
PlatformRegistrar (DI 注入)     →  服务能力（DeviceInfo/URLOpener/ShareSheet）
PlatformTraits (Environment 注入) →  UI 形态差异（idiom/navigation/touch）
```

**分工原则**：

| 机制 | 注入载体 | 适用场景 | 业界对应 |
|------|---------|---------|---------|
| `PlatformTraits` | `@Environment` | UI 形态（纯值，影响 View 渲染） | Backyard Birds Trait |
| `PlatformRegistrar` | `@Inject` | 服务能力（有副作用、async） | Backyard Birds DI |

两者互补，不冲突。

### 2.7 测试策略

```swift
// 测试时可注入任意 idiom，无需 Mock 整个平台
ContentView()
    .environment(\.interfaceIdiom, .watch)
    .environment(\.prefersTabNavigation, false)
```

---

## 三、14 处违规修复映射

### 3.1 修复模式（统一为 2 种，对齐业界）

**业界原则**：业务层（Features/Domain）零 `#if os()`。所有平台差异通过"运行时值注入"解决。

两种"注入"本质是同一模式的两种载体：

| 模式 | 注入载体 | 适用场景 | 业界对应 |
|------|---------|---------|---------|
| **A. 运行时注入** | `@Environment` (UI 形态) | View 层平台差异 | Backyard Birds Trait |
| **A. 运行时注入** | `@Inject` (服务能力) | Service 注册差异 | Backyard Birds DI |
| **B. 物理隔离** | ViewFactory + 独立目录 | watchOS 结构性差异（类型系统不同） | Backyard Birds watchOS 独立 target |

**模式选择判据**：能用运行时值解决就用运行时值（Trait/DI），只有类型系统不兼容时才物理隔离。

### 3.2 修复映射表

| # | 文件:行 | 原始宏 | 修复模式 | 用哪个 Trait / 机制 |
|---|--------|--------|---------|-------------------|
| 1 | `AIModuleRegistrar.swift:25` | `#if os(watchOS)` | A（`@Inject`） | 移到 `Platforms/watchOS/Registrar/WatchPlatformRegistrar.swift` |
| 2 | `TaskCenterView.swift:55` | `#if os(watchOS)` | B | `interfaceIdiom` + ViewFactory |
| 3 | `PromptWorkshopView.swift:35` | `#if os(watchOS)` | B | `interfaceIdiom` + ViewFactory |
| 4 | `SynthesisSlidesView.swift:73` | `#if os(iOS)` | A（`@Environment`） | `interfaceIdiom` |
| 5 | `QuizPresentationModifier.swift:34` | `#if os(iOS) && !targetEnvironment(macCatalyst)` | A（`@Environment`） | `interfaceIdiom`（含 `macCatalyst` case） |
| 6 | `GraphCanvasView.swift:116` | `#if os(watchOS)` | B | `interfaceIdiom` + ViewFactory |
| 7 | `Graph3DComponents.swift:21` | `#if os(watchOS)` | B | `interfaceIdiom` + ViewFactory |
| 8 | `GraphComponents.swift:90` | `#if os(macOS)` | A（`@Environment`） | `interfaceIdiom` |
| 9 | `IngestView.swift:241` | `#if os(watchOS)` | B | `interfaceIdiom` + ViewFactory |
| 10 | `PDFReaderView.swift:18` | `#if os(watchOS)` | B | `interfaceIdiom` + ViewFactory |
| 11 | `OCRScanView.swift:15` | `#if os(watchOS)` | B | `interfaceIdiom` + ViewFactory |
| 12 | `VoiceAudioPlayerView.swift:140` | `#if os(iOS)` | A（`@Environment`） | `interfaceIdiom` |
| 13 | `VoiceAudioPlayerView.swift:160` | `#if os(iOS)` | A（`@Environment`） | `interfaceIdiom` |
| 14 | `VoiceAudioPlayerView.swift:236` | `#if os(iOS)` | A（`@Environment`） | `interfaceIdiom` |

### 3.3 修复模式分布

| 模式 | 数量 | 说明 |
|------|------|------|
| A（`@Environment` Trait） | 6 处 | UI 形态差异，运行时判断 |
| A（`@Inject` DI 移位） | 1 处 | 服务注册移到 Platforms 层 |
| B（物理隔离 + ViewFactory） | 7 处 | watchOS 结构性差异 |

### 3.4 修复前后对比示例

#### 示例 1：`QuizPresentationModifier.swift:34`（模式 A - 运行时 Trait）

**修复前**：
```swift
// 系统层级：[L2] 业务功能层
struct QuizPresentationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            #if os(iOS) && !targetEnvironment(macCatalyst)
            .fullScreenCover(isPresented: $isPresented) {
                QuizFullScreenView()
            }
            #endif
    }
}
```

**修复后**：
```swift
// 系统层级：[L2] 业务功能层
struct QuizPresentationModifier: ViewModifier {
    @Environment(\.interfaceIdiom) private var idiom

    func body(content: Content) -> some View {
        content
            .fullScreenCover(isPresented: $isPresented) {
                if idiom == .iPhone || idiom == .iPad {
                    QuizFullScreenView()
                }
            }
    }
}
```

**关键变化**：
- `#if os(iOS) && !targetEnvironment(macCatalyst)` → `idiom == .iPhone || idiom == .iPad`
- `macCatalyst` case 的价值：运行时精确排除 Mac Catalyst，无需 `targetEnvironment` 宏
- 业务层零 `#if`，纯运行时判断

#### 示例 2：`IngestView.swift:241`（模式 B - watchOS 物理隔离）

**修复前**：
```swift
// 系统层级：[L2] 业务功能层
struct IngestView: View {
    var body: some View {
        #if os(watchOS)
        // watchOS 极简占位（NavigationStack 类型不同）
        NavigationStack {
            Text("导入功能请在 iPhone 上使用")
        }
        #else
        NavigationStack {
            IngestContentList()
                .adaptiveListStyle()
        }
        #endif
    }
}
```

**修复后**：

`Sources/Features/Knowledge/Ingest/View/IngestView.swift`（共享入口）：
```swift
// 系统层级：[L2] 业务功能层
struct IngestView: View {
    @Environment(\.interfaceIdiom) private var idiom
    @Inject private var viewFactory: ViewFactory

    var body: some View {
        if idiom == .watch {
            viewFactory.makeWatchPlaceholderView(feature: .ingest)
        } else {
            IngestContentNavigation()
        }
    }
}

struct IngestContentNavigation: View {
    var body: some View {
        NavigationStack {
            IngestContentList()
                .adaptiveListStyle()
        }
    }
}
```

`Sources/Platforms/watchOS/Views/WatchPlaceholderView.swift`（watchOS 专属）：
```swift
// 系统层级：[L0] 基础设施层（平台适配）
struct WatchPlaceholderView: View {
    let feature: FeatureDomain
    var body: some View {
        NavigationStack {
            Text(feature.placeholderMessage)
        }
    }
}
```

`Sources/Platforms/watchOS/Registrar/WatchPlatformRegistrar.swift`（注册）：
```swift
// 系统层级：[L0] 基础设施层
struct WatchPlatformRegistrar {
    static func registerServices(in container: ServiceContainer) {
        // ... 已有注册
        container.register(ViewFactoryProtocol.self) { WatchViewFactory() }
    }
}
```

**关键变化**：
- watchOS 的 `NavigationStack` 占位代码物理移到 `Platforms/watchOS/Views/`
- Features 层通过 `@Inject viewFactory` + `@Environment(\.interfaceIdiom)` 运行时分发
- `#if os(watchOS)` 从 Features 层消失，仅存在于 `Platforms/watchOS/`（合法）
- 符合 Apple Backyard Birds 模式：watchOS 独立 View + 共享逻辑通过 DI

### 3.5 修复后违规数预期

| 层级 | 修复前 | 修复后 | 变化 |
|------|--------|--------|------|
| Features 层 `#if os()` | 14 | **0** | -14 |
| Domain 层 `#if os()` | 0 | 0 | — |
| `PlatformModifiers` 内部 | 24 | 24（合法，L0 层） | — |
| `Platforms/` 目录 | 若干 | 若干（合法） | — |

---

## 四、CI 门禁加固

### 4.1 现状问题

**关键发现**：`check-code-platform-macros.py` 存在但**未被 `run-code-static-analysis.sh` 调用**！这是 14 处违规未阻断 CI 的根因。

`run-code-static-analysis.sh` 当前 22 项并行检查中不包含 `check-code-platform-macros.py`。

### 4.2 修复方案

#### 4.2.1 集成 `check-code-platform-macros.py` 至 CI

在 `run-code-static-analysis.sh` 新增第 23 项检查：

```bash
run_parallel_task "Platform Macros Gate" "platform_macros" "python3 Tools/ios/check-code-platform-macros.py" & pid23=$!

# 等待区域新增
wait $pid23 || EXIT_CODE=1
```

#### 4.2.2 升级 `check-code-platform-macros.py` 检查规则

当前脚本只检查 `#if os()`，需扩展检查范围以匹配新设计：

| 检查项 | 当前 | 升级后 |
|--------|------|--------|
| `#if os()` | ✅ | ✅ |
| `#if !os()` | ❌ | ✅ 新增 |
| `#if targetEnvironment` | ❌ | ✅ 新增（Features/Domain 禁止） |
| `#if canImport(UIKit/AppKit)` | ❌ | ✅ 新增（Features/Domain 禁止） |
| 白名单 | 无 | ✅ 新增（允许 L0 适配层文件） |

#### 4.2.3 白名单机制

并非所有 `#if os()` 都违规，需白名单：

```python
# check-code-platform-macros.py 白名单
WHITELIST = {
    # L0 适配层：合法使用 #if os()
    "Sources/Shared/Platforms/Adaptor/",
    "Sources/Shared/UIComponents/Modifiers/PlatformModifiers.swift",
    "Sources/Platforms/",  # 平台实现层
    "Sources/App/",        # 入口层
    "Sources/Core/Base/Protocols/",  # 协议定义层（defaultValue 静态计算）
    # 新增 Trait 文件
    "Sources/Shared/Platforms/Adaptor/PlatformTraits.swift",
}
```

#### 4.2.4 检查规则明确化

| 层级 | `#if os()` | `#if !os()` | `#if targetEnvironment` | `#if canImport(UIKit/AppKit)` |
|------|-----------|------------|------------------------|------------------------------|
| `Sources/Features/` | ❌ 禁止 | ❌ 禁止 | ❌ 禁止 | ❌ 禁止 |
| `Sources/Domain/` | ❌ 禁止 | ❌ 禁止 | ❌ 禁止 | ❌ 禁止 |
| `Sources/Shared/` | ⚠️ 仅白名单 | ⚠️ 仅白名单 | ⚠️ 仅白名单 | ⚠️ 仅白名单 |
| `Sources/Platforms/` | ✅ 合法 | ✅ 合法 | ✅ 合法 | ✅ 合法 |
| `Sources/App/` | ✅ 合法 | ✅ 合法 | ✅ 合法 | ✅ 合法 |
| `Sources/Core/` | ⚠️ 仅白名单 | ⚠️ 仅白名单 | ⚠️ 仅白名单 | ⚠️ 仅白名单 |
| `Sources/Infrastructure/` | ⚠️ 仅白名单 | ⚠️ 仅白名单 | ⚠️ 仅白名单 | ⚠️ 仅白名单 |

---

## 五、文档同步

### 5.1 `PLATFORM_PROTOCOL_ARCHITECTURE.md` 更新

新增第 10 章"运行时 Trait 体系"：

```markdown
## 10. 运行时 Trait 体系（新增）

### 10.1 设计原则

> UI 形态差异用运行时 Trait（@Environment），服务能力差异用 DI（@Inject）。

### 10.2 Trait 清单

| Trait | EnvironmentKey | 实现方式 | 用途 |
|-------|---------------|---------|------|
| interfaceIdiom | InterfaceIdiomKey | 静态 defaultValue | 设备形态（5 case） |
| prefersTabNavigation | PrefersTabNavigationKey | UITraitBridgedEnvironmentKey | Tab vs SplitView |
| supportsTouch | SupportsTouchKey | 静态 defaultValue | 触控交互 |
| supportsFullScreenImmersive | SupportsFullScreenImmersiveKey | 静态 defaultValue | 全屏沉浸 |

### 10.3 使用模式

// ... 代码示例

### 10.4 与 PlatformRegistrar 的分工

| 机制 | 注入载体 | 适用场景 |
|------|---------|---------|
| PlatformTraits | @Environment | UI 形态（纯值） |
| PlatformRegistrar | @Inject | 服务能力（async/副作用） |
```

### 5.2 `LAYERING_L0_L3.md` 红线 7 更新

```markdown
### 红线 7：业务层 (Features) 禁止直接使用 `#if os()` 平台宏

> ✅ **已修复** (2026-08-04)：经过 Phase 3 运行时 Trait 改造，
> Features 层 `#if os()` 宏从 **14 处降至 0 处**（-100%）。

*   **违规行为**：在 `Sources/Features/` 和 `Sources/Domain/` 使用
    `#if os()`、`#if !os()`、`#if targetEnvironment`、`#if canImport(UIKit/AppKit)` 宏。
*   **最佳实践**（已验证生效）：
    1. UI 形态差异 → `@Environment(\.interfaceIdiom)` 运行时 Trait
    2. 服务能力差异 → `@Inject var service: any Protocol` DI 注入
    3. watchOS 结构性差异 → `Platforms/watchOS/Views/` 物理隔离 + ViewFactory 注入
*   **CI 门禁**：`check-code-platform-macros.py` 已集成至
    `run-code-static-analysis.sh` 第 23 项检查
```

### 5.3 `HIGH_LEVEL_DESIGN.md` 更新

```markdown
| P1 修复 | `#if os()` 宏协议化：Phase 1+2（46→10）+ Phase 3 运行时 Trait（10→0） | 14 文件 + 4 新 Trait |
```

### 5.4 `ADR.md` 新增 ADR-006

```markdown
| ADR-006 | 2026-08-04 | 平台 UI 差异采用运行时 Trait（@Environment）而非编译时 #if os() | 已实施 |
```

---

## 六、验证清单

修复完成后需验证：

| 验证项 | 命令 | 预期 |
|--------|------|------|
| 14 处违规清零 | `python3 Tools/ios/check-code-platform-macros.py` | ✅ PASS |
| CI 静态分析通过 | `bash Tools/CI/run-code-static-analysis.sh` | ✅ 23 项全过 |
| 三平台编译 | `make ios && make mac && make watch` | ✅ 全部通过 |
| 单元测试 | `make test` | ✅ 全部通过 |
| 文档同步 | 4 个文档已更新 | ✅ |

---

## 七、风险与权衡

### 7.1 风险点

1. **模式 B 物理隔离**：需新建 `Platforms/watchOS/Views/` 目录 + 注册机制，改动较大
2. **ViewFactory 扩展**：watchOS 占位 View 需通过 ViewFactory 注入，避免 Features 层直接 import 平台代码
3. **测试覆盖**：每个修复点需补单元测试（注入不同 `interfaceIdiom` 验证分支）
4. **`UITraitBridgedEnvironmentKey` 兼容性**：需确认 watchOS 10.0 是否支持（watchOS 不依赖 UIKit，可能需 `#if os(iOS)` 保护）

### 7.2 权衡分析

| 方案 | 优势 | 劣势 | 工作量 |
|------|------|------|--------|
| **方案 A（采用）** | 对齐 Apple 官方，业务层零 `#if`，复用现有 DI | 需学习 Trait 模式 | 中 |
| 方案 B（watchOS 独立 target） | 彻底消除 watchOS 差异 | 现有已能编译，收益边际递减 | 大 |
| 方案 C（最小修复） | 工作量最小 | 未对齐业界，未来仍需扩展 | 小 |

**选择方案 A 的理由**：
1. 对齐 Apple Backyard Birds 官方模式
2. 复用 ZhiYu 现有 `PlatformRegistrar` + `@Inject` DI 体系
3. 14 处违规 + `PlatformModifiers` 24 处 + 未来扩展一次性解决
4. 工作量可控（方案 B 收益边际递减）

---

## 八、实施计划

### 8.1 实施顺序

| 阶段 | 内容 | 依赖 |
|------|------|------|
| 1 | 新建 `PlatformTraits.swift`（4 个 Trait） | 无 |
| 2 | 修复 6 处模式 A（`@Environment` Trait） | 阶段 1 |
| 3 | 修复 1 处模式 A（`@Inject` DI 移位） | 无 |
| 4 | 修复 7 处模式 B（watchOS 物理隔离 + ViewFactory） | 阶段 1 |
| 5 | 升级 `check-code-platform-macros.py`（新增 3 类检查 + 白名单） | 阶段 2-4 |
| 6 | 集成至 `run-code-static-analysis.sh`（第 23 项） | 阶段 5 |
| 7 | 文档同步（4 个文档） | 阶段 2-6 |
| 8 | 验证（三平台编译 + 单测 + CI） | 阶段 1-7 |

### 8.2 预期收益

| 指标 | 修复前 | 修复后 | 变化 |
|------|--------|--------|------|
| Features 层 `#if os()` | 14 | 0 | -100% |
| CI 静态分析项 | 22 | 23 | +1 |
| 运行时 Trait 数 | 0 | 4 | +4 |
| 文档同步 | — | 4 个 | — |
| 对齐 Apple 官方模式 | ❌ | ✅ | — |

---

## 九、相关文档

- [`Docs/Architecture/PLATFORM_PROTOCOL_ARCHITECTURE.md`](../../Docs/Architecture/PLATFORM_PROTOCOL_ARCHITECTURE.md) — 跨平台协议分层架构（将新增第 10 章）
- [`Docs/Architecture/LAYERING_L0_L3.md`](../../Docs/Architecture/LAYERING_L0_L3.md) — 严格分层规范（红线 7 将更新）
- [`Docs/Architecture/HIGH_LEVEL_DESIGN.md`](../../Docs/Architecture/HIGH_LEVEL_DESIGN.md) — 概要设计（P1 修复记录将更新）
- [`Docs/Architecture/ADR.md`](../../Docs/Architecture/ADR.md) — 架构决策记录（将新增 ADR-006）
- [Apple Backyard Birds 示例](https://developer.apple.com/documentation/swiftui/backyard-birds-sample) — 运行时 Trait 模式参考
