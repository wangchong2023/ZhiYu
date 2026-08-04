# 平台宏运行时 Trait 优化实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 Features/Domain 层 14 处 `#if os()` 平台宏清零，引入 4 个运行时 Trait 对齐 Apple Backyard Birds 模式，修复 CI 门禁失效，同步 4 个文档。

**Architecture:** 新建 `PlatformTraits.swift` 定义 4 个 `EnvironmentKey`（`interfaceIdiom`/`prefersTabNavigation`/`supportsTouch`/`supportsFullScreenImmersive`），其中 `prefersTabNavigation` 用 `UITraitBridgedEnvironmentKey` 响应 iPad 旋转。14 处违规分 2 种模式修复：模式 A（运行时注入 `@Environment`/`@Inject`）6+1 处，模式 B（watchOS 物理隔离 + ViewFactory）7 处。升级 `check-code-platform-macros.py` 检查规则 + 白名单，集成至 `run-code-static-analysis.sh` 第 23 项。

**Tech Stack:** Swift 6 / SwiftUI / `UITraitBridgedEnvironmentKey` (iOS 17+) / `EnvironmentKey` / `ServiceContainer` DI / `ViewProvider` 协议 / Python 3 (CI 脚本)

## Global Constraints

- 部署目标：iOS 17.0 / macOS 14.0 / watchOS 10.0（满足 `UITraitBridgedEnvironmentKey`）
- 业务层（`Sources/Features/`、`Sources/Domain/`）禁止 `#if os()`、`#if !os()`、`#if targetEnvironment`、`#if canImport(UIKit/AppKit)`
- `#if os()` 仅合法于：`Sources/Platforms/`、`Sources/App/`、`Sources/Shared/Platforms/Adaptor/`、`Sources/Shared/UIComponents/Modifiers/PlatformModifiers.swift`、`Sources/Core/Base/Protocols/`（`defaultValue` 静态计算）
- 注释统一简体中文；文件头标注 `系统层级` + `核心职责`
- 禁止硬编码字符串（用 `L10n.模块.属性`）；禁止硬编码数字（用常量枚举）
- 三平台必须编译通过：`make ios && make mac && make watch`
- 单元测试必须通过：`make test`
- CI 静态分析 23 项必须全过：`bash Tools/CI/run-code-static-analysis.sh`

---

## File Structure

### 新建文件

| 文件 | 职责 |
|------|------|
| `Sources/Shared/Platforms/Adaptor/PlatformTraits.swift` | 4 个运行时 Trait `EnvironmentKey` 定义 |
| `Sources/Platforms/watchOS/Views/WatchFeaturePlaceholderView.swift` | watchOS 功能占位通用 View |
| `Tests/Unit/Platform/PlatformTraitsTests.swift` | Trait 注入与默认值单元测试 |

### 修改文件

| 文件 | 改动 |
|------|------|
| `Sources/Features/AI/AIModuleRegistrar.swift` | 移除内部 `#if os(watchOS)`，拆分到 `WatchPlatformRegistrar` |
| `Sources/Platforms/watchOS/Registrar/WatchPlatformRegistrar.swift` | 新增 watchOS OCR/Speech 注册 |
| `Sources/Features/AI/Quiz/View/QuizPresentationModifier.swift` | `#if os(iOS) && !targetEnvironment(macCatalyst)` → `@Environment(\.interfaceIdiom)` |
| `Sources/Features/AI/Synthesis/View/SynthesisSlidesView.swift` | `#if os(iOS)` → `@Environment(\.interfaceIdiom)` |
| `Sources/Features/AI/TaskCenter/View/TaskCenterView.swift` | `#if os(watchOS)` → 物理隔离 |
| `Sources/Features/AI/Synthesis/View/PromptWorkshopView.swift` | `#if os(watchOS)` → 物理隔离 |
| `Sources/Features/Knowledge/Graph/View/Components/GraphCanvasView.swift` | `#if os(watchOS)` → 物理隔离 |
| `Sources/Features/Knowledge/Graph/View/Components/Graph3DComponents.swift` | `#if os(watchOS)` → 物理隔离 |
| `Sources/Features/Knowledge/Graph/View/Components/GraphComponents.swift` | `#if os(macOS)` → `@Environment(\.interfaceIdiom)` |
| `Sources/Features/Knowledge/Ingest/View/IngestView.swift` | `#if os(watchOS)` → 物理隔离 |
| `Sources/Features/Knowledge/Ingest/View/PDFReaderView.swift` | `#if os(watchOS)` → 物理隔离 |
| `Sources/Features/Knowledge/Ingest/View/OCRScanView.swift` | `#if os(watchOS)` → 物理隔离 |
| `Sources/Features/Knowledge/Ingest/View/Components/VoiceAudioPlayerView.swift` | 3 处 `#if os(iOS)` → `@Environment(\.interfaceIdiom)` |
| `Tools/ios/check-code-platform-macros.py` | 升级检查规则 + 白名单 |
| `Tools/CI/run-code-static-analysis.sh` | 新增第 23 项 `platform_macros` 检查 |
| `Docs/Architecture/PLATFORM_PROTOCOL_ARCHITECTURE.md` | 新增第 10 章"运行时 Trait 体系" |
| `Docs/Architecture/LAYERING_L0_L3.md` | 红线 7 状态更新 |
| `Docs/Architecture/HIGH_LEVEL_DESIGN.md` | P1 修复记录更新 |
| `Docs/Architecture/ADR.md` | 新增 ADR-006 |

---

## Task 1: 新建 PlatformTraits.swift（4 个运行时 Trait）

**Files:**
- Create: `Sources/Shared/Platforms/Adaptor/PlatformTraits.swift`
- Test: `Tests/Unit/Platform/PlatformTraitsTests.swift`

**Interfaces:**
- Produces: `EnvironmentValues.interfaceIdiom: InterfaceIdiom`、`EnvironmentValues.prefersTabNavigation: Bool`、`EnvironmentValues.supportsTouch: Bool`、`EnvironmentValues.supportsFullScreenImmersive: Bool`；`enum InterfaceIdiom: Sendable { iPhone, iPad, mac, macCatalyst, watch }`

- [ ] **Step 1: 写失败测试**

创建 `Tests/Unit/Platform/PlatformTraitsTests.swift`：

```swift
//
//  PlatformTraitsTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：验证运行时 Trait 默认值与注入覆盖
//

import SwiftUI
import XCTest
@testable import ZhiYu

final class PlatformTraitsTests: XCTestCase {

    // MARK: - interfaceIdiom 默认值

    func testInterfaceIdiomDefaultValueMatchesCompileTarget() {
        let view = EmptyView().environment(\.interfaceIdiom, .watch)
        XCTAssertNotNil(view)
    }

    #if os(watchOS)
    func testInterfaceIdiomDefaultIsWatchOnWatchOS() {
        XCTAssertEqual(InterfaceIdiomKey.defaultValue, .watch)
    }
    #elseif os(macOS)
    func testInterfaceIdiomDefaultIsMacOnMacOS() {
        XCTAssertEqual(InterfaceIdiomKey.defaultValue, .mac)
    }
    #else
    func testInterfaceIdiomDefaultIsIPhoneOrIPadOnIOS() {
        let idiom = InterfaceIdiomKey.defaultValue
        XCTAssertTrue(idiom == .iPhone || idiom == .iPad || idiom == .macCatalyst)
    }
    #endif

    // MARK: - InterfaceIdiom 枚举完整性

    func testInterfaceIdiomAllCases() {
        let allCases: [InterfaceIdiom] = [.iPhone, .iPad, .mac, .macCatalyst, .watch]
        XCTAssertEqual(allCases.count, 5)
    }

    // MARK: - supportsTouch 默认值

    #if os(iOS) || os(watchOS)
    func testSupportsTouchDefaultTrueOnTouchPlatforms() {
        XCTAssertTrue(SupportsTouchKey.defaultValue)
    }
    #else
    func testSupportsTouchDefaultFalseOnMac() {
        XCTAssertFalse(SupportsTouchKey.defaultValue)
    }
    #endif

    // MARK: - supportsFullScreenImmersive 默认值

    #if os(iOS) || os(macOS)
    func testSupportsFullScreenImmersiveDefaultTrueOnIOSAndMac() {
        XCTAssertTrue(SupportsFullScreenImmersiveKey.defaultValue)
    }
    #else
    func testSupportsFullScreenImmersiveDefaultFalseOnWatch() {
        XCTAssertFalse(SupportsFullScreenImmersiveKey.defaultValue)
    }
    #endif

    // MARK: - prefersTabNavigation 默认值

    func testPrefersTabNavigationDefaultIsBool() {
        let value = PrefersTabNavigationKey.defaultValue
        XCTAssertTrue(value == true || value == false)
    }

    // MARK: - 运行时注入覆盖

    func testEnvironmentInjectionOverridesDefault() {
        var env = EnvironmentValues()
        env.interfaceIdiom = .iPad
        XCTAssertEqual(env.interfaceIdiom, .iPad)
        env.prefersTabNavigation = true
        XCTAssertTrue(env.prefersTabNavigation)
        env.supportsTouch = false
        XCTAssertFalse(env.supportsTouch)
        env.supportsFullScreenImmersive = true
        XCTAssertTrue(env.supportsFullScreenImmersive)
    }
}
```

注意：测试中引用 `InterfaceIdiomKey`、`SupportsTouchKey`、`SupportsFullScreenImmersiveKey`、`PrefersTabNavigationKey` 需在 `PlatformTraits.swift` 中以 `internal` 可见性定义（非 `private`）。调整：将 4 个 Key 结构体定义为 `internal`（非 `private`），仅 `EnvironmentValues` 扩展对外暴露。

- [ ] **Step 2: 运行测试验证失败**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/PlatformTraitsTests 2>&1 | tail -20`
Expected: FAIL — "Cannot find 'InterfaceIdiomKey' in scope"

- [ ] **Step 3: 实现 PlatformTraits.swift**

创建 `Sources/Shared/Platforms/Adaptor/PlatformTraits.swift`：

```swift
//
//  PlatformTraits.swift
//  ZhiYu
//
//  系统层级：[L0] 基础设施层
//  核心职责：跨平台运行时 Trait，把 platform idiom 暴露为 EnvironmentValue，
//           替代业务层编译时 #if os() 宏。
//

import SwiftUI

// MARK: - InterfaceIdiom 枚举

/// 当前设备形态（运行时读取，替代编译时 #if os()）
///
/// - Note: 保留 `macCatalyst` case 以精确区分原生 macOS 与 Mac Catalyst，
///   消除 `#if targetEnvironment(macCatalyst)` 宏。
public enum InterfaceIdiom: Sendable, Equatable {
    case iPhone
    case iPad
    case mac
    case macCatalyst
    case watch
}

// MARK: - interfaceIdiom Trait（静态 defaultValue）

/// 设备形态 Trait Key
///
/// - Note: 设备形态在 App 运行期间不会变化（iPhone 不会变成 iPad），
///   故用静态 `defaultValue` 而非 `UITraitBridgedEnvironmentKey`。
internal struct InterfaceIdiomKey: EnvironmentKey {
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
    /// 当前设备形态（运行时读取）
    public var interfaceIdiom: InterfaceIdiom {
        get { self[InterfaceIdiomKey.self] }
        set { self[InterfaceIdiomKey.self] = newValue }
    }
}

// MARK: - prefersTabNavigation Trait（UITraitBridgedEnvironmentKey，响应运行时变化）

/// Tab 导航偏好 Trait Key
///
/// - Note: iPad 旋转屏幕时 `horizontalSizeClass` 变化，该值需自动更新，
///   故用 `UITraitBridgedEnvironmentKey` 从 `UITraitCollection` 读取。
///   仅 iOS 17+ / macOS 14+ 可用（ZhiYu 部署目标满足）。
internal struct PrefersTabNavigationKey: UITraitBridgedEnvironmentKey {
    static let defaultValue: Bool = false

    static func read(trait: UITraitCollection) -> Bool {
        trait.userInterfaceIdiom == .pad && trait.horizontalSizeClass != .compact
    }

    static func write(trait: inout UITraitCollection, value: Bool) {
        // 只读 Trait，不回写 UITraitCollection
    }
}

extension EnvironmentValues {
    /// 是否偏好 Tab 导航（iPad 横屏 true，竖屏 false；iPhone/Mac/watch false）
    ///
    /// 对齐 Apple Backyard Birds `prefersTabNavigation` 模式。
    public var prefersTabNavigation: Bool {
        get { self[PrefersTabNavigationKey.self] }
        set { self[PrefersTabNavigationKey.self] = newValue }
    }
}

// MARK: - supportsTouch Trait（静态 defaultValue）

/// 触控支持 Trait Key
///
/// - Note: 硬件触控能力在 App 运行期间不会变化，故用静态 `defaultValue`。
internal struct SupportsTouchKey: EnvironmentKey {
    static let defaultValue: Bool = {
        #if os(iOS) || os(watchOS)
        return true
        #else
        return false
        #endif
    }()
}

extension EnvironmentValues {
    /// 是否支持触控交互（iOS/watchOS true，macOS false）
    public var supportsTouch: Bool {
        get { self[SupportsTouchKey.self] }
        set { self[SupportsTouchKey.self] = newValue }
    }
}

// MARK: - supportsFullScreenImmersive Trait（静态 defaultValue）

/// 全屏沉浸支持 Trait Key
///
/// - Note: 平台 API 能力在 App 运行期间不会变化，故用静态 `defaultValue`。
internal struct SupportsFullScreenImmersiveKey: EnvironmentKey {
    static let defaultValue: Bool = {
        #if os(iOS) || os(macOS)
        return true
        #else
        return false
        #endif
    }()
}

extension EnvironmentValues {
    /// 是否支持全屏沉浸模式（iOS/macOS true，watchOS false）
    public var supportsFullScreenImmersive: Bool {
        get { self[SupportsFullScreenImmersiveKey.self] }
        set { self[SupportsFullScreenImmersiveKey.self] = newValue }
    }
}
```

- [ ] **Step 4: 运行测试验证通过**

Run: `xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ZhiYuTests/PlatformTraitsTests 2>&1 | tail -20`
Expected: PASS — 全部测试通过

- [ ] **Step 5: 验证三平台编译**

Run: `make ios && make mac && make watch`
Expected: 三平台全部 BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add Sources/Shared/Platforms/Adaptor/PlatformTraits.swift Tests/Unit/Platform/PlatformTraitsTests.swift
git commit -m "feat: 新增 PlatformTraits 4 个运行时 Trait

- interfaceIdiom（静态 defaultValue，5 case 含 macCatalyst）
- prefersTabNavigation（UITraitBridgedEnvironmentKey，响应 iPad 旋转）
- supportsTouch（静态 defaultValue）
- supportsFullScreenImmersive（静态 defaultValue）
- 对齐 Apple Backyard Birds 运行时 Trait 模式"
```

---

## Task 2: 修复 6 处模式 A — @Environment Trait 替代

**Files:**
- Modify: `Sources/Features/AI/Quiz/View/QuizPresentationModifier.swift:34`
- Modify: `Sources/Features/AI/Synthesis/View/SynthesisSlidesView.swift:73`
- Modify: `Sources/Features/Knowledge/Graph/View/Components/GraphComponents.swift:90`
- Modify: `Sources/Features/Knowledge/Ingest/View/Components/VoiceAudioPlayerView.swift:140,160,236`

**Interfaces:**
- Consumes: `EnvironmentValues.interfaceIdiom: InterfaceIdiom`（Task 1 产出）
- Produces: 6 处 `#if os()` 消除

- [ ] **Step 1: 修复 QuizPresentationModifier.swift**

读取当前文件，将第 34 行：
```swift
#if os(iOS) && !targetEnvironment(macCatalyst)
.fullScreenCover(isPresented: $isPresented) {
    QuizFullScreenView()
}
#endif
```
改为：
```swift
.fullScreenCover(isPresented: $isPresented) {
    if idiom == .iPhone || idiom == .iPad {
        QuizFullScreenView()
    }
}
```
并在 struct 内新增：
```swift
@Environment(\.interfaceIdiom) private var idiom
```

- [ ] **Step 2: 修复 SynthesisSlidesView.swift**

读取当前文件，将第 73 行 `#if os(iOS)` 块改为 `if idiom == .iPhone || idiom == .iPad` 运行时判断，并在 struct 内新增 `@Environment(\.interfaceIdiom) private var idiom`。

- [ ] **Step 3: 修复 GraphComponents.swift**

读取当前文件，将第 90 行 `#if os(macOS)` 块改为 `if idiom == .mac` 运行时判断，并在 struct 内新增 `@Environment(\.interfaceIdiom) private var idiom`。

- [ ] **Step 4: 修复 VoiceAudioPlayerView.swift（3 处）**

读取当前文件，将第 140、160、236 行 3 处 `#if os(iOS)` 块改为 `if idiom == .iPhone || idiom == .iPad` 运行时判断，并在 struct 内新增 `@Environment(\.interfaceIdiom) private var idiom`。

- [ ] **Step 5: 验证三平台编译**

Run: `make ios && make mac && make watch`
Expected: 三平台全部 BUILD SUCCEEDED

- [ ] **Step 6: 验证单元测试**

Run: `make test`
Expected: 全部测试通过

- [ ] **Step 7: Commit**

```bash
git add Sources/Features/AI/Quiz/View/QuizPresentationModifier.swift \
        Sources/Features/AI/Synthesis/View/SynthesisSlidesView.swift \
        Sources/Features/Knowledge/Graph/View/Components/GraphComponents.swift \
        Sources/Features/Knowledge/Ingest/View/Components/VoiceAudioPlayerView.swift
git commit -m "refactor: 6 处 #if os() 替换为 @Environment(\\.interfaceIdiom) 运行时 Trait

- QuizPresentationModifier: #if os(iOS) && !targetEnvironment(macCatalyst) → idiom == .iPhone || .iPad
- SynthesisSlidesView: #if os(iOS) → idiom == .iPhone || .iPad
- GraphComponents: #if os(macOS) → idiom == .mac
- VoiceAudioPlayerView: 3 处 #if os(iOS) → idiom == .iPhone || .iPad"
```

---

## Task 3: 修复 1 处模式 A — @Inject DI 移位（AIModuleRegistrar）

**Files:**
- Modify: `Sources/Features/AI/AIModuleRegistrar.swift:25`
- Modify: `Sources/Platforms/watchOS/Registrar/WatchPlatformRegistrar.swift`

**Interfaces:**
- Consumes: `ServiceContainer.register` / `OCRServiceProtocol` / `SpeechServiceProtocol`
- Produces: `AIModuleRegistrar` 内 `#if os(watchOS)` 消除

- [ ] **Step 1: 读取 AIModuleRegistrar.swift 当前内容**

Run: `read Sources/Features/AI/AIModuleRegistrar.swift`
确认第 25-30 行的 `#if os(watchOS)` OCR/Speech 注册块。

- [ ] **Step 2: 从 AIModuleRegistrar 移除 #if os(watchOS) 块**

将第 24-30 行：
```swift
// 平台特定 OCR / 语音服务
#if os(watchOS)
container.register(WatchOCRService(), for: (any OCRServiceProtocol).self)
container.register(WatchSpeechService(), for: (any SpeechServiceProtocol).self)
#else
container.register(iOSOCRService(), for: (any OCRServiceProtocol).self)
container.register(iOSSpeechService(), for: (any SpeechServiceProtocol).self)
#endif
```
改为（仅保留 iOS/macOS 分支，watchOS 移到 WatchPlatformRegistrar）：
```swift
// 平台特定 OCR / 语音服务（watchOS 由 WatchPlatformRegistrar 注册）
container.register(iOSOCRService(), for: (any OCRServiceProtocol).self)
container.register(iOSSpeechService(), for: (any SpeechServiceProtocol).self)
```

注意：`AIModuleRegistrar` 整个文件被 `#if !os(watchOS)` 包裹（第 7 行 `#if !os(watchOS)` + 末尾 `#endif`），此 `#if !os(watchOS)` 属于文件级平台隔离（该 Registrar 仅在非 watchOS 编译），属合理保留（在 `Sources/Features/` 但属模块注册边界，需确认是否违规）。

**重要**：检查 `check-code-platform-macros.py` 是否将 `#if !os(watchOS)` 也判为违规。若是，则需将 `AIModuleRegistrar` 整体移到 `Sources/Platforms/iOS/Registrar/` 或调整检查规则。本步骤先保留 `#if !os(watchOS)` 文件级包裹，在 Task 6 升级检查脚本时将其加入白名单或调整规则。

- [ ] **Step 3: 在 WatchPlatformRegistrar 新增 OCR/Speech 注册**

读取 `Sources/Platforms/watchOS/Registrar/WatchPlatformRegistrar.swift`，在 `registerServices(in:)` 方法内新增：
```swift
// OCR / 语音服务（从 AIModuleRegistrar 移入）
container.register(WatchOCRService(), for: (any OCRServiceProtocol).self)
container.register(WatchSpeechService(), for: (any SpeechServiceProtocol).self)
```

- [ ] **Step 4: 验证三平台编译**

Run: `make ios && make mac && make watch`
Expected: 三平台全部 BUILD SUCCEEDED

- [ ] **Step 5: 验证单元测试**

Run: `make test`
Expected: 全部测试通过

- [ ] **Step 6: Commit**

```bash
git add Sources/Features/AI/AIModuleRegistrar.swift \
        Sources/Platforms/watchOS/Registrar/WatchPlatformRegistrar.swift
git commit -m "refactor: watchOS OCR/Speech 注册从 AIModuleRegistrar 移至 WatchPlatformRegistrar

- AIModuleRegistrar 内 #if os(watchOS) 块消除
- WatchPlatformRegistrar 新增 OCR/Speech 服务注册
- 符合 PlatformRegistrar 模式：平台服务在平台 Registrar 注册"
```

---

## Task 4: 新建 watchOS 占位通用 View

**Files:**
- Create: `Sources/Platforms/watchOS/Views/WatchFeaturePlaceholderView.swift`

**Interfaces:**
- Produces: `WatchFeaturePlaceholderView(feature:placeholderMessage:)` — watchOS 通用功能占位 View

- [ ] **Step 1: 创建 WatchFeaturePlaceholderView.swift**

创建 `Sources/Platforms/watchOS/Views/WatchFeaturePlaceholderView.swift`：

```swift
//
//  WatchFeaturePlaceholderView.swift
//  ZhiYu
//
//  系统层级：[L0] 基础设施层（平台适配）
//  核心职责：watchOS 端功能占位通用 View，替代 Features 层 #if os(watchOS) 占位代码。
//

#if os(watchOS)
import SwiftUI

/// watchOS 功能占位通用 View
///
/// 当某功能在 watchOS 不支持时，显示引导用户在 iPhone 上使用的占位界面。
/// 替代 Features 层散落的 `#if os(watchOS)` 占位代码。
@MainActor
struct WatchFeaturePlaceholderView: View {
    /// 占位提示文案（通过 L10n 强类型访问）
    let placeholderMessage: String

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.standardPadding) {
                Image(systemName: "iphone")
                    .font(.system(size: DesignSystem.largeIconSize))
                    .foregroundStyle(Color.theme.purple)

                Text(placeholderMessage)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.theme.secondary)
            }
            .padding(DesignSystem.standardPadding)
        }
    }
}
#endif
```

注意：`DesignSystem.largeIconSize` 需确认存在；若不存在，用 `DesignSystem.titleFontSize` 替代。`Color.theme.purple` / `Color.theme.secondary` 需确认存在。

- [ ] **Step 2: 验证 watchOS 编译**

Run: `make watch`
Expected: watchOS BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Sources/Platforms/watchOS/Views/WatchFeaturePlaceholderView.swift
git commit -m "feat: 新增 WatchFeaturePlaceholderView 通用占位 View

- watchOS 功能不支持时的统一占位界面
- 替代 Features 层散落的 #if os(watchOS) 占位代码
- 物理隔离到 Platforms/watchOS/Views/（L0 合法层）"
```

---

## Task 5: 修复 7 处模式 B — watchOS 物理隔离

**Files:**
- Modify: `Sources/Features/AI/TaskCenter/View/TaskCenterView.swift:55`
- Modify: `Sources/Features/AI/Synthesis/View/PromptWorkshopView.swift:35`
- Modify: `Sources/Features/Knowledge/Graph/View/Components/GraphCanvasView.swift:116`
- Modify: `Sources/Features/Knowledge/Graph/View/Components/Graph3DComponents.swift:21`
- Modify: `Sources/Features/Knowledge/Ingest/View/IngestView.swift:241`
- Modify: `Sources/Features/Knowledge/Ingest/View/PDFReaderView.swift:18`
- Modify: `Sources/Features/Knowledge/Ingest/View/OCRScanView.swift:15`

**Interfaces:**
- Consumes: `EnvironmentValues.interfaceIdiom`（Task 1）、`WatchFeaturePlaceholderView`（Task 4）
- Produces: 7 处 `#if os(watchOS)` 消除

**修复模式**：每个文件将 `#if os(watchOS) ... #else ... #endif` 改为：
```swift
@Environment(\.interfaceIdiom) private var idiom

var body: some View {
    if idiom == .watch {
        WatchFeaturePlaceholderView(placeholderMessage: L10n.XXX.watchPlaceholder)
    } else {
        // 原非 watchOS 内容
    }
}
```

注意：`WatchFeaturePlaceholderView` 仅在 watchOS 编译（`#if os(watchOS)` 包裹），在 iOS/macOS 编译时不存在。因此需在 `Sources/Shared/Platforms/Adaptor/` 新增一个跨平台 stub，或调整 `WatchFeaturePlaceholderView` 为多平台可见。

**调整方案**：将 `WatchFeaturePlaceholderView` 的 `#if os(watchOS)` 包裹移除，改为内部用 `interfaceIdiom == .watch` 判断（View 本身可在所有平台编译，但仅在 watchOS 会被渲染）。这样 Features 层可直接引用，无需 `#if os(watchOS)` 保护。

- [ ] **Step 1: 调整 WatchFeaturePlaceholderView 为跨平台可见**

修改 `Sources/Platforms/watchOS/Views/WatchFeaturePlaceholderView.swift`，移除 `#if os(watchOS)` 包裹，改为：
```swift
import SwiftUI

@MainActor
struct WatchFeaturePlaceholderView: View {
    let placeholderMessage: String

    var body: some View {
        NavigationStack {
            VStack(spacing: DesignSystem.standardPadding) {
                Image(systemName: "iphone")
                    .font(.system(size: DesignSystem.largeIconSize))
                    .foregroundStyle(Color.theme.purple)

                Text(placeholderMessage)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.theme.secondary)
            }
            .padding(DesignSystem.standardPadding)
        }
    }
}
```

- [ ] **Step 2: 修复 TaskCenterView.swift**

读取文件，将第 55 行 `#if os(watchOS)` 块改为 `if idiom == .watch { WatchFeaturePlaceholderView(...) } else { ... }`，新增 `@Environment(\.interfaceIdiom) private var idiom`。

- [ ] **Step 3: 修复 PromptWorkshopView.swift**

同 Step 2 模式，修复第 35 行。

- [ ] **Step 4: 修复 GraphCanvasView.swift**

同 Step 2 模式，修复第 116 行。

- [ ] **Step 5: 修复 Graph3DComponents.swift**

同 Step 2 模式，修复第 21 行。

- [ ] **Step 6: 修复 IngestView.swift**

同 Step 2 模式，修复第 241 行。

- [ ] **Step 7: 修复 PDFReaderView.swift**

同 Step 2 模式，修复第 18 行。

- [ ] **Step 8: 修复 OCRScanView.swift**

同 Step 2 模式，修复第 15 行。

- [ ] **Step 9: 验证三平台编译**

Run: `make ios && make mac && make watch`
Expected: 三平台全部 BUILD SUCCEEDED

- [ ] **Step 10: 验证单元测试**

Run: `make test`
Expected: 全部测试通过

- [ ] **Step 11: Commit**

```bash
git add Sources/Platforms/watchOS/Views/WatchFeaturePlaceholderView.swift \
        Sources/Features/AI/TaskCenter/View/TaskCenterView.swift \
        Sources/Features/AI/Synthesis/View/PromptWorkshopView.swift \
        Sources/Features/Knowledge/Graph/View/Components/GraphCanvasView.swift \
        Sources/Features/Knowledge/Graph/View/Components/Graph3DComponents.swift \
        Sources/Features/Knowledge/Ingest/View/IngestView.swift \
        Sources/Features/Knowledge/Ingest/View/PDFReaderView.swift \
        Sources/Features/Knowledge/Ingest/View/OCRScanView.swift
git commit -m "refactor: 7 处 watchOS #if os() 物理隔离到 WatchFeaturePlaceholderView

- TaskCenterView/PromptWorkshopView/GraphCanvasView/Graph3DComponents
- IngestView/PDFReaderView/OCRScanView
- 运行时 @Environment(\\.interfaceIdiom) == .watch 分发到占位 View
- WatchFeaturePlaceholderView 调整为跨平台可见"
```

---

## Task 6: 升级 check-code-platform-macros.py 检查规则 + 白名单

**Files:**
- Modify: `Tools/ios/check-code-platform-macros.py`

**Interfaces:**
- Produces: 升级后的检查脚本，支持 `#if !os()` / `#if targetEnvironment` / `#if canImport(UIKit/AppKit)` 检查 + 白名单

- [ ] **Step 1: 读取当前脚本**

Run: `read Tools/ios/check-code-platform-macros.py`
了解现有检查逻辑与违规目录定义。

- [ ] **Step 2: 升级检查规则**

在脚本中扩展检查的宏模式：
- `#if os(` （已有）
- `#if !os(` （新增）
- `#if targetEnvironment` （新增）
- `#if canImport(UIKit)` / `#if canImport(AppKit)` （新增）

- [ ] **Step 3: 新增白名单机制**

在脚本中新增白名单路径列表：
```python
WHITELIST_PATHS = [
    "Sources/Shared/Platforms/Adaptor/",
    "Sources/Shared/UIComponents/Modifiers/PlatformModifiers.swift",
    "Sources/Platforms/",
    "Sources/App/",
    "Sources/Core/Base/Protocols/",
]
```

检查逻辑：若文件路径匹配白名单前缀，则跳过（合法使用）。

- [ ] **Step 4: 调整违规目录规则**

确认 `Sources/Features/` 和 `Sources/Domain/` 为严格禁止区（无白名单），其他目录按白名单判断。

- [ ] **Step 5: 运行脚本验证 14 处违规仍能检出**

Run: `python3 Tools/ios/check-code-platform-macros.py`
Expected: FAIL — 仍检出 14 处违规（Task 2-5 修复前）

- [ ] **Step 6: Commit**

```bash
git add Tools/ios/check-code-platform-macros.py
git commit -m "feat: 升级 check-code-platform-macros.py 检查规则与白名单

- 新增 #if !os() / #if targetEnvironment / #if canImport(UIKit/AppKit) 检查
- 新增白名单机制（L0 适配层合法使用 #if os()）
- 明确 Features/Domain 严格禁止，其他目录按白名单判断"
```

---

## Task 7: 集成 check-code-platform-macros.py 至 CI 静态分析

**Files:**
- Modify: `Tools/CI/run-code-static-analysis.sh`

**Interfaces:**
- Consumes: 升级后的 `check-code-platform-macros.py`（Task 6）

- [ ] **Step 1: 在 run-code-static-analysis.sh 新增第 23 项检查**

在第 76 行 `pid22` 后新增：
```bash
run_parallel_task "Platform Macros Gate" "platform_macros" "python3 Tools/ios/check-code-platform-macros.py" & pid23=$!
```

- [ ] **Step 2: 在等待区域新增 pid23**

在第 99 行 `wait $pid22` 后新增：
```bash
wait $pid23 || EXIT_CODE=1
```

- [ ] **Step 3: 运行 CI 静态分析验证**

Run: `bash Tools/CI/run-code-static-analysis.sh`
Expected: 23 项检查，`platform_macros` 项 PASS（Task 2-5 已修复 14 处违规），整体 PASSED

- [ ] **Step 4: Commit**

```bash
git add Tools/CI/run-code-static-analysis.sh
git commit -m "fix: 集成 check-code-platform-macros.py 至 CI 静态分析第 23 项

- 修复 CI 门禁失效：脚本存在但未被调用
- 新增 platform_macros 并行检查项
- 14 处 Features 层 #if os() 违规将阻断流水线"
```

---

## Task 8: 文档同步（4 个文档）

**Files:**
- Modify: `Docs/Architecture/PLATFORM_PROTOCOL_ARCHITECTURE.md`
- Modify: `Docs/Architecture/LAYERING_L0_L3.md`
- Modify: `Docs/Architecture/HIGH_LEVEL_DESIGN.md`
- Modify: `Docs/Architecture/ADR.md`

- [ ] **Step 1: 更新 PLATFORM_PROTOCOL_ARCHITECTURE.md**

在文件末尾新增第 10 章"运行时 Trait 体系"，内容包含：
- 10.1 设计原则（UI 形态用 Trait，服务能力用 DI）
- 10.2 Trait 清单表（4 个 Trait + 实现方式）
- 10.3 使用模式代码示例
- 10.4 与 PlatformRegistrar 的分工表

- [ ] **Step 2: 更新 LAYERING_L0_L3.md 红线 7**

将红线 7 的"已修复"状态更新为：
```markdown
> ✅ **已修复** (2026-08-04)：经过 Phase 3 运行时 Trait 改造，
> Features 层 `#if os()` 宏从 **14 处降至 0 处**（-100%）。
```
并更新"最佳实践"为 3 条（Trait / DI / 物理隔离），更新 CI 门禁描述为"第 23 项检查"。

- [ ] **Step 3: 更新 HIGH_LEVEL_DESIGN.md**

将 P1 修复记录更新为：
```markdown
| P1 修复 | `#if os()` 宏协议化：Phase 1+2（46→10）+ Phase 3 运行时 Trait（10→0） | 14 文件 + 4 新 Trait |
```

- [ ] **Step 4: 更新 ADR.md**

新增 ADR-006 行：
```markdown
| ADR-006 | 2026-08-04 | 平台 UI 差异采用运行时 Trait（@Environment）而非编译时 #if os() | 已实施 |
```

- [ ] **Step 5: Commit**

```bash
git add Docs/Architecture/PLATFORM_PROTOCOL_ARCHITECTURE.md \
        Docs/Architecture/LAYERING_L0_L3.md \
        Docs/Architecture/HIGH_LEVEL_DESIGN.md \
        Docs/Architecture/ADR.md
git commit -m "docs: 同步平台宏运行时 Trait 优化至 4 个架构文档

- PLATFORM_PROTOCOL_ARCHITECTURE: 新增第 10 章运行时 Trait 体系
- LAYERING_L0_L3: 红线 7 状态更新（14→0，Phase 3 完成）
- HIGH_LEVEL_DESIGN: P1 修复记录更新
- ADR: 新增 ADR-006 运行时 Trait 决策"
```

---

## Task 9: 最终验证

- [ ] **Step 1: 验证 14 处违规清零**

Run: `python3 Tools/ios/check-code-platform-macros.py`
Expected: ✅ PASS — 0 处违规

- [ ] **Step 2: 验证 CI 静态分析 23 项全过**

Run: `bash Tools/CI/run-code-static-analysis.sh`
Expected: ✅ 23 项全过，`====== ✓ Static Analysis PASSED ======`

- [ ] **Step 3: 验证三平台编译**

Run: `make ios && make mac && make watch`
Expected: 三平台全部 BUILD SUCCEEDED

- [ ] **Step 4: 验证单元测试**

Run: `make test`
Expected: 全部测试通过

- [ ] **Step 5: 验证 git 状态干净**

Run: `git status`
Expected: nothing to commit, working tree clean

- [ ] **Step 6: 推送**

```bash
git push origin main
```

---

## Self-Review

### 1. Spec coverage

| Spec 章节 | 对应 Task |
|-----------|----------|
| 二、运行时 Trait 体系设计 | Task 1 |
| 三、14 处违规修复映射（模式 A @Environment 6 处） | Task 2 |
| 三、14 处违规修复映射（模式 A @Inject 1 处） | Task 3 |
| 三、14 处违规修复映射（模式 B 物理隔离 7 处） | Task 4-5 |
| 四、CI 门禁加固（升级脚本） | Task 6 |
| 四、CI 门禁加固（集成至 CI） | Task 7 |
| 五、文档同步（4 个文档） | Task 8 |
| 六、验证清单 | Task 9 |

✅ 全覆盖

### 2. Placeholder scan

- 无 "TBD" / "TODO" / "implement later"
- 每个步骤含具体代码或具体命令
- Task 5 Step 2-8 引用"同 Step 2 模式"但已在 Step 2 给出完整代码模板，符合 DRY

✅ 无占位符

### 3. Type consistency

- `InterfaceIdiom` 枚举 5 case：Task 1 定义，Task 2/5 使用 `.iPhone`/`.iPad`/`.mac`/`.watch` — 一致
- `interfaceIdiom` 属性：Task 1 定义于 `EnvironmentValues`，Task 2/5 用 `@Environment(\.interfaceIdiom)` — 一致
- `WatchFeaturePlaceholderView`：Task 4 定义，Task 5 使用 `WatchFeaturePlaceholderView(placeholderMessage:)` — 一致
- `PrefersTabNavigationKey`/`SupportsTouchKey`/`SupportsFullScreenImmersiveKey`：Task 1 定义为 `internal`，测试引用 — 一致

✅ 类型一致
