# Phase 1：macOS 原生升级实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `ZhiYuMac` 从 Mac Catalyst 升级为原生 macOS target，获得原生窗口/菜单/拖放体验，并清理 Catalyst 条件编译分支与 UIKit 残留。

**Architecture:** 复用现有 `MacPlatformRegistrar`（15 个 macOS 服务）、`MacAppEnvironment`、`ZhiYuApp.swift` 的 `#if os(macOS)` 菜单栏扩展。改造 `project.yml.template` 中 `ZhiYuMac` 的 platform 为 macOS，删除 Catalyst 特有设置；清理 `#if targetEnvironment(macCatalyst)` 分支（Sources 生产 21 处、13 文件）；将 Shared/Features 层的 UIKit 使用替换为 AppKit/跨平台 API。

**Tech Stack:** Swift 6、SwiftUI、AppKit、xcodegen；平台版本 macOS 27.0。

## Global Constraints

- **分层红线**：Features/Domain 层禁用 `#if os()`；Shared 层 UIKit 用法须通过 PlatformContext/DesignSystem 抽象隔离。
- **跨平台 API 替换**：`UIColor`→`NSColor`、`UIImage`→`NSImage`、`UIView`→`NSView`、`UIPasteboard`→`NSPasteboard`；Catalyst 允许的 UIKit 在原生 macOS 需替换。
- **去魔鬼化**：禁止硬编码魔法数字/字符串；UI 尺寸用 `DesignSystem` token。
- **L10n 强约束**：新增菜单/文案必须走 `L10n.模块.属性`，禁硬编码。
- **测试质量红线**：语句覆盖率 ≥95%、分支覆盖率 ≥90%。
- **并发**：Swift 6 严格并发；UI 代码 `@MainActor`。
- **构建验证**：`make ios && make mac && make watch && make test` 全过（Gatekeeper 22 项全绿）。
- **无占位符**：所有替换必须产出可编译代码。

> ⚠️ **前置说明（已按 2026-11-18 代码核实修正文档偏差）**：以下任务中的文件路径与分支范围基于实际代码核实，与 `CROSS_PLATFORM_EXPANSION.md` §6.3 原文略有差异（原文路径为 `App/Scenes/Layout/Components/ContentView.swift` 等，实际为 `App/Scenes/ContentView.swift` 等；任务 4 的 `AIRainbowGlowBadge.swift:242` 实为 `#if targetEnvironment(macCatalyst)` 而非 UIKit 残留）。本计划采用核实后的真实路径。

---

## 任务清单

### 任务 1：target 配置改造为原生 macOS（0.5 天）

**Files:**
- Modify: `Config/project.yml.template:172-201`（ZhiYuMac target）

**Interfaces:**
- Consumes: 无
- Produces: `ZhiYuMac` target 以 `platform: macOS` 编译

- [ ] **Step 1: 修改 ZhiYuMac 的 platform 与目标设置**

在 `Config/project.yml.template` 中，将 `ZhiYuMac` target（约 L172-201）的：

```yaml
platform: iOS
deploymentTarget: "27.0"
settings:
  base:
    SUPPORTS_MACCATALYST: "YES"
    SDKROOT: iphoneos
    TARGETED_DEVICE_FAMILY: "2"
```

改为：

```yaml
platform: macOS
deploymentTarget: "27.0"
settings:
  base:
    # 移除 SUPPORTS_MACCATALYST / SDKROOT / TARGETED_DEVICE_FAMILY
```

即删除 `SUPPORTS_MACCATALYST`、`SDKROOT: iphoneos`、`TARGETED_DEVICE_FAMILY: 2` 三行，`platform: iOS` → `platform: macOS`。保留 `INFOPLIST_FILE: Sources/MacInfo.plist`。

- [ ] **Step 2: 重新生成项目**

```bash
make gen
```

预期：`xcodegen generate` 成功，ZhiYuMac 变为 macOS platform。

- [ ] **Step 3: 编译探测（预期失败，确认阻塞点）**

```bash
make mac
```

预期：编译报错——原生 macOS 下 UIKit scene 生命周期、Catalyst 分支不编译。收集报错清单，作为任务 3/4 的依据。

- [ ] **Step 4: Commit**

```bash
git add Config/project.yml.template Config/project.yml
git commit -m "refactor: ZhiYuMac 改为原生 macOS target"
```

---

### 任务 2：删除未接入的 `AppWindowSceneDelegate`（0.5 天）

**Files:**
- Delete: `Sources/App/Lifecycle/AppWindowSceneDelegate.swift`
- Modify: `Tests/Unit/App/.../AppWindowSceneDelegateTests.swift`（如存在，随删除调整）

**Interfaces:**
- Consumes: 任务 1
- Produces: 移除 UIKit scene 生命周期死代码

- [ ] **Step 1: 确认死代码状态**

核验 `MacInfo.plist` 的 `UIApplicationSceneManifest` 无 `delegateClassName`（任务 5 会删除该键），且 `ZhiYuApp` 用纯 SwiftUI `WindowGroup` 建窗 → `AppWindowSceneDelegate` 未接入。

```bash
rg -n "AppWindowSceneDelegate" Sources/ Tests/ | grep -v "AppWindowSceneDelegate.swift"
```

预期：仅测试文件引用，无生产调用。

- [ ] **Step 2: 删除文件**

```bash
git rm Sources/App/Lifecycle/AppWindowSceneDelegate.swift
```

- [ ] **Step 3: 调整引用测试**

若 `Tests/` 有 `AppWindowSceneDelegateTests`，删除或改为验证 `ZhiYuApp` 主入口。删除对应测试文件。

```bash
git rm Tests/Unit/App/*AppWindowSceneDelegateTests.swift 2>/dev/null || true
```

- [ ] **Step 4: 编译验证**

```bash
make ios && make mac
```

预期：两平台编译通过（macOS 不再因 UIKit scene 报错）。

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: 删除未接入的 AppWindowSceneDelegate"
```

---

### 任务 3：清理 Catalyst 条件编译分支（2-3 天）

**Files:**
- Modify: `Sources/App/Scenes/ContentView.swift:170,267`
- Modify: `Sources/Shared/UIComponents/Menus/UserProfileMenu.swift:14,235,410`
- Modify: `Sources/Platforms/iOS/Registrar/iOSPlatformRegistrar.swift:44`
- Modify: `Sources/Platforms/iOS/Services/ActivityService.swift`（5 处）
- Modify: `Sources/Shared/Platforms/Adaptor/PlatformTraits.swift:40`
- Modify: `Sources/Platforms/iOS/Services/iOSAccessibilityService.swift:12`
- Modify: `Sources/Shared/UIComponents/Badges/AIRainbowGlowBadge.swift:242,245`
- Modify: `Sources/App/Lifecycle/...`（若有残留）
- Modify: `Sources/Platforms/iOS/Activity/AIProcessingAttributes.swift`
- Modify: `Sources/Platforms/iOS/Activity/LiveActivityView.swift`

**Interfaces:**
- Consumes: 任务 1
- Produces: 移除 `#if targetEnvironment(macCatalyst)`（Sources 生产 21 处）；原生 macOS 下 `os(iOS)` 自动排除，多数分支直接删除

> **分支处理原则**：原生 macOS 下 `#if os(iOS)` 为假 → Catalyst 专用分支（如 `#if targetEnvironment(macCatalyst)`）直接删除，配套 `#else` 分支保留。`os(iOS) && !targetEnvironment(macCatalyst)` 在原生 macOS 下整体为假 → 保持（已是 iOS 专属）。逐个核实。

- [ ] **Step 1: 处理 ContentView.swift 的 Catalyst 分支**

Read `Sources/App/Scenes/ContentView.swift:160-280`，删除 `:170`（隐藏 titlebar/toolbar 的 Catalyst 分支）与 `:267`（Catalyst 固定 sheet 尺寸）的 `#if targetEnvironment(macCatalyst)` 块，保留 `#else` 的 iPad/iOS 分支与 `#if #available` 逻辑。

- [ ] **Step 2: 处理 UserProfileMenu.swift 的 Catalyst 悬浮菜单**

Read `Sources/Shared/UIComponents/Menus/UserProfileMenu.swift:1-30,230-250,405-420`。删除 `:14` 的 `import UIKit` + `CatalystFloatingMenuManager` 声明、`:235` 的 Catalyst 悬浮覆盖层分支、`:410` 的 Catalyst 固定菜单宽度分支；`#elseif os(iOS)`/`#else` 分支改为直接逻辑。

- [ ] **Step 3: 处理 iOSPlatformRegistrar.swift 的 DummyActivityService**

Read `Sources/Platforms/iOS/Registrar/iOSPlatformRegistrar.swift:40-50`。原生 macOS 下该文件整体被 `os(iOS)` 包裹不编译，`:44` 的 `#if !targetEnvironment(macCatalyst)` 分支在 iOS 下恒真 → 可删除 `#if !targetEnvironment(macCatalyst)` 包裹，直接注册 `ActivityService.shared`。

- [ ] **Step 4: 处理 PlatformTraits.swift 的 Catalyst idiom**

Read `Sources/Shared/Platforms/Adaptor/PlatformTraits.swift:30-50`。`:40` 的 `InterfaceIdiomKey` Catalyst 分支 `.macCatalyst`：原生 macOS 下该分支位于 `#elseif os(macOS)` 后不会走到 Catalyst，删除 `#if targetEnvironment(macCatalyst)` 的 `.macCatalyst` case（改为 macOS 直接返回 `.desktop`/`InterfaceIdiom` 适值）。

- [ ] **Step 5: 处理 AIRainbowGlowBadge.swift 的 Catalyst 分支**

Read `Sources/Shared/UIComponents/Badges/AIRainbowGlowBadge.swift:238-250`。`:242` 为 `#if targetEnvironment(macCatalyst)`，`:245` 为 `#elseif os(iOS)` 的 `UIDevice` 用法。删除 Catalyst 分支；`UIDevice.current.userInterfaceIdiom` 改为通过 `PlatformTraits`/`InterfaceIdiomKey` 跨平台抽象获取，避免直接 UIKit 依赖。

- [ ] **Step 6: 清理 iOS Accessory 文件**

检查 `AIProcessingAttributes.swift`、`LiveActivityView.swift` 的 Catalyst 分支（灵动岛 ActivityKit 相关），确认 `os(iOS) && !targetEnvironment(macCatalyst)` 在原生 macOS 下不编译即可，无需改动。

- [ ] **Step 7: 全仓残留扫描**

```bash
rg -n "targetEnvironment\(macCatalyst\)" Sources/
```

预期：Sources 生产代码 0 处（Tests 的 12 处保留，仅测试用）。

- [ ] **Step 8: 编译验证**

```bash
make ios && make mac
```

预期：两平台编译通过。

- [ ] **Step 9: Commit**

```bash
git add Sources/
git commit -m "refactor: 清理 Catalyst 条件编译分支"
```

---

### 任务 4：UIKit API 替换（3-5 天）

**Files:**
- Modify: `Sources/Shared/Platforms/Adaptor/CrossPlatform.swift:34,70`
- Modify: `Sources/Shared/UIComponents/Menus/UserProfileMenu.swift:15`
- Modify: `Sources/Shared/UIComponents/Modifiers/PlatformModifiers.swift:13`
- Modify: `Sources/Features/System/ModelManager/Utility/LabVisualSampleProvider.swift:15`
- Modify: `Sources/Features/System/Auth/Strategy/CarrierAuthStrategy.swift:16`
- Modify: `Sources/Features/System/Auth/Strategy/GitHubAuthStrategy.swift:16`
- Modify: `Sources/Features/System/Auth/Strategy/WeChatAuthStrategy.swift:14`
- Modify: `Sources/Features/Knowledge/Graph/View/Components/Graph3DComponents.swift:15`
- Modify: `Sources/Features/System/ModelManager/View/Sections/ModelLabInputsPanel.swift:16`
- Modify: `Sources/Features/System/ModelManager/View/Sections/InstantMediaSearchPanel.swift:450`
- Modify: `Sources/Features/Knowledge/Ingest/View/Components/ZoomableOCRImageView.swift:14`

**Interfaces:**
- Consumes: 任务 3
- Produces: Shared/Features 层 UIKit 使用替换为 AppKit/跨平台 API

> **范围**（2026-11-18 核实）：`import UIKit` 在 Shared 3 文件（CrossPlatform/UserProfileMenu/PlatformModifiers）、Features 8 文件。UIKit 类使用：`UIImage` F8/S2、`UIView` F3/S2、`UIColor` F1/S0、`UIPasteboard` 0。逐文件替换。

- [ ] **Step 1: 替换 Shared 层 UIKit**

Read `Sources/Shared/Platforms/Adaptor/CrossPlatform.swift`。将 `import UIKit`（:34/:70 对应不同平台分支）改为按平台 `#if os(iOS)` 保留 UIKit、`#elseif os(macOS)` 用 AppKit。`UIImage`→`NSImage`、`UIView`→`NSView` 的跨平台类型统一收敛到 `CrossPlatform` 抽象（新增 `typealias CrossImage = UIImage`/`NSImage` 等）。

- [ ] **Step 2: 替换 UserProfileMenu 与 PlatformModifiers**

在 `UserProfileMenu.swift`（去掉 Catalyst 悬浮菜单后）与 `PlatformModifiers.swift` 中，将残余 UIKit 替换为 SwiftUI 原生或 `CrossPlatform` 抽象。

- [ ] **Step 3: 替换 Features 层 Auth 策略**

`CarrierAuthStrategy.swift:16`、`GitHubAuthStrategy.swift:16`、`WeChatAuthStrategy.swift:14` 的 `import UIKit`：若仅用 `UIApplication`，替换为跨平台 `NSApplication`/`UIApplication` 抽象（经 `PlatformContext`）。

- [ ] **Step 4: 替换 Features 层 ModelManager 的 UIImage**

`LabVisualSampleProvider.swift:15`、`ModelLabInputsPanel.swift:16`、`InstantMediaSearchPanel.swift:450` 的 `UIImage`：替换为 `CrossPlatform` 的跨平台图片类型（`CrossImage`），加载逻辑经抽象。

- [ ] **Step 5: 替换 Graph3DComponents 与 ZoomableOCRImageView**

`Graph3DComponents.swift:15`、`ZoomableOCRImageView.swift:14` 的 UIKit 图片/视图：替换为跨平台抽象。

- [ ] **Step 6: 编译验证**

```bash
make ios && make mac
```

预期：两平台编译通过，无 UIKit 编译错误。

- [ ] **Step 7: 残留扫描**

```bash
rg -n "import UIKit" Sources/Shared/ Sources/Features/
```

预期：Shared/Features 层 0 处（Platforms/ 保留合法）。

- [ ] **Step 8: Commit**

```bash
git add Sources/Shared/ Sources/Features/
git commit -m "refactor: 替换 Shared/Features 层 UIKit 为跨平台抽象"
```

---

### 任务 5：Info.plist 与 Entitlements 配置（0.5 天）

**Files:**
- Modify: `Sources/MacInfo.plist`

**Interfaces:**
- Consumes: 任务 1-4
- Produces: 原生 macOS 的 Info.plist

- [ ] **Step 1: 删除 UIKit 专属键**

从 `Sources/MacInfo.plist` 删除：
- `UIApplicationSceneManifest`（L65）
- `UILaunchScreen`（L72）
- `UIUserInterfaceStyle`（L77）
- `NSSupportsLiveActivities`（L63）

保留 `LSApplicationCategoryType`（L41，已存在，无需新增）。

- [ ] **Step 2: 核对原生 macOS 必需键**

确认保留 `LSMinimumSystemVersion`（27.0）、`CFBundleURLTypes`、沙箱/网络相关键。若需原生 macOS 额外键（如 `NSSupportsAutomaticGraphicsSwitching`），按需添加。

- [ ] **Step 3: 编译验证**

```bash
make gen && make mac
```

预期：编译通过，Info.plist 无 UIKit 键报错。

- [ ] **Step 4: Commit**

```bash
git add Sources/MacInfo.plist
git commit -m "refactor: MacInfo.plist 移除 UIKit 专属键"
```

---

### 任务 6：第三方 SDK 验证（0.5 天）

**Files:**
- Modify: `Config/project.yml.template`（必要时禁用 SDK）

**Interfaces:**
- Consumes: 任务 1-5
- Produces: WechatOpenSDK/ATAuthSDK 在原生 macOS 的可用性结论

- [ ] **Step 1: 检查 xcframework slice**

检查 `WechatOpenSDK`/`ATAuthSDK` 的 `.xcframework` 是否含 macOS slice：

```bash
find ~/Documents/work/code/opensrc -name "*.xcframework" -path "*Wechat*" -o -name "*.xcframework" -path "*ATAuth*" 2>/dev/null
```

对每个 `.xcframework`，检查 `Info.plist` 的 `AvailableLibraries` 是否含 `macosx` platform。

- [ ] **Step 2: 决策与处理**

若缺 macOS slice：在 `project.yml.template` 的 ZhiYuMac 中排除该 SDK 或改用 `#if os(iOS)` 隔离其使用代码（WeChat/ATAuth 登录仅 iOS 场景），并记录 ADR。

- [ ] **Step 3: Commit**

```bash
git add Config/project.yml.template
git commit -m "refactor: 处理第三方 SDK 原生 macOS 兼容"
```

---

### 任务 7：三平台编译 + 全量测试验证（0.5 天）

**Files:**
- 无源码改动（仅验证）

**Interfaces:**
- Consumes: 任务 1-6
- Produces: 全量验证通过

- [ ] **Step 1: 三平台编译**

```bash
make ios && make mac && make watch
```

预期：三平台编译通过，Gatekeeper 22 项全绿。

- [ ] **Step 2: 单元测试**

```bash
make test
```

预期：主 App 全量单测通过。

- [ ] **Step 3: SPM 包测试**

```bash
make test-spm-all
```

预期：6 大 SPM 包单测全绿。

- [ ] **Step 4: Commit（若有测试调整）**

```bash
git add -A
git commit -m "test: Phase1 三平台编译与全量测试验证"
```

---

### 任务 8：文档同步 + ADR 记录（0.5 天）

**Files:**
- Modify: `Docs/Architecture/CROSS_PLATFORM_EXPANSION.md`（§6.3 标记完成）
- Modify: `Docs/Architecture/ADR.md`（追加 ADR-016）
- Modify: `AGENTS.md`（外部依赖/ZhiYuMac 描述）
- Modify: `Docs/Guides/ACKNOWLEDGMENTS.md`（如有 SDK 变更）

**Interfaces:**
- Consumes: 任务 1-7
- Produces: 文档与代码一致

- [ ] **Step 1: 更新 CROSS_PLATFORM_EXPANSION.md §6.3**

将 §6.3 标题后加 `（✅ 已完成 YYYY-MM-DD）`，更新：任务 1-7 勾选、风险（原生 macOS 真机回归）、交付物（原生 macOS target）。同时修正文档中的路径偏差（ContentView/UserProfileMenu/iOSPlatformRegistrar/iOSAccessibilityService/MacInfo.plist 真实路径；任务 4 的 AIRainbowGlowBadge 描述）。

- [ ] **Step 2: 记录 ADR-016**

在 `Docs/Architecture/ADR.md` 追加 ADR-016：macOS 原生升级方案、Catalyst 清理策略、UIKit 跨平台抽象、第三方 SDK 处理。

- [ ] **Step 3: 更新 AGENTS.md**

更新外部依赖与 Targets 描述：ZhiYuMac 为原生 macOS，Wechat/ATAuth 处理结果。

- [ ] **Step 4: Commit**

```bash
git add Docs/ AGENTS.md
git commit -m "docs: Phase1 macOS 原生升级完成 + ADR-016"
```

---

## 验收标准（AC）

1. `Config/project.yml.template` 中 `ZhiYuMac` 的 `platform: macOS`，移除 Catalyst 三设置。
2. `Sources/App/Lifecycle/AppWindowSceneDelegate.swift` 已删除，无生产引用。
3. Sources 生产代码 `targetEnvironment(macCatalyst)` 0 处。
4. Shared/Features 层 `import UIKit` 0 处（Platforms/ 保留合法）。
5. `Sources/MacInfo.plist` 无 `UIApplicationSceneManifest`/`UILaunchScreen`/`UIUserInterfaceStyle`/`NSSupportsLiveActivities`。
6. Wechat/ATAuth SDK 兼容性结论已记录。
7. `make ios && make mac && make watch && make test` 全过，Gatekeeper 22 项全绿。
8. 覆盖率红线（语句 ≥95%、分支 ≥90%）满足。
9. 文档（CROSS_PLATFORM_EXPANSION/ADR/AGENTS）与代码一致。

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| Shared/Features 层 UIKit 残留远超预估 | 任务 4 用 `make mac` 编译扫出，逐文件替换；优先级 UIImage/UIView 高于 UIPasteboard |
| Wechat/ATAuth 缺 macOS slice | 任务 6 提前检查，缺则 `#if os(iOS)` 隔离并记录 ADR |
| Catalyst 分支清理破坏 iOS 逻辑 | 逐个核实配套 `#else`，iOS 编译验证兜底 |
| 原生 macOS 真机回归未覆盖 | 文档风险标注，建议后续人工回归 |