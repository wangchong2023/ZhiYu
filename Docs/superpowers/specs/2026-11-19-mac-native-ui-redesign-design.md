# ZhiYu Mac 界面全面原生化 Design Spec

**Goal:** 将 macOS 原生版 ZhiYuMac 从"iOS 风格 UI 套桌面窗口"升级为符合 macOS 平台规范的全面原生体验（原生场景结构、系统偏好设置风格、完整菜单栏、独立辅助窗口、原生视觉质感），并严格遵循项目平台宏内聚架构规范。

**Scope:** macOS target 界面层改造（App 场景 + Platforms/macOS 视图），最小化共享层影响。

**日期:** 2026-11-19

---

## 背景与现状

ZhiYuMac 已从 Catalyst 迁移为原生 macOS target（`platform: macOS`，SDKROOT=macosx），但界面仍是 iOS 风格直接套进桌面窗口：

| 现状 | 问题 |
|------|------|
| 单一 `WindowGroup` + `ContentView` | 无多窗口、无独立辅助窗口 |
| 设置用 `fullScreenCover` sheet 弹出 `SettingsView` | 未接入 macOS 原生 `Settings` scene / ⌘, 菜单 |
| 菜单仅 `.commands` 中 ⌘N 新建页 | 无完整菜单栏（文件/编辑/查看/窗口/帮助） |
| 侧边栏固定 280 宽度 | 未按平台启用已定义的 `macCompactWidth` |
| 工具栏用共享组件 | 非 Mac 原生工具栏呈现 |

### 平台宏内聚约束（对齐项目规范）

依据 `Docs/Architecture/PLATFORM_PROTOCOL_ARCHITECTURE.md` 与 `ModuleRegistrar` 实践：

- **业务层（Features/Domain）绝不使用 `#if os()`**；平台差异通过协议 + DI + PlatformRegistrar + 运行时 Trait 解耦。
- `#if os()` 仅允许在基础设施/App 层，且**收敛到单一分发点**。
- 平台专属代码下沉到 `Platforms/<platform>` 目录，靠**目录隔离**而非散落宏。

---

## 架构方案：平台宏内聚的 Scene 构建

### 场景单一分发点（`AppSceneBuilder`）

不直接在 `ZhiYuApp.body` 写多个 `#if os(macOS)`，仿照 `ModuleRegistrar` 建一个场景分发点，把平台 scene 差异收敛：

```swift
// Sources/App/Scenes/AppSceneBuilder.swift — 唯一 #if os 三平台分发点
@MainActor
enum AppSceneBuilder {
    /// 场景根分发：平台差异在此收敛，业务层无宏
    static var root: some Scene {
        #if os(macOS)
        MacSceneBuilder.root          // macOS：主窗口 + Settings + 辅助窗口
        #else
        iOSSceneBuilder.root          // iOS/watchOS：现有 WindowGroup + ContentView
        #endif
    }
}
```

### `ZhiYuApp.body` 极简化

```swift
var body: some Scene {
    AppSceneBuilder.root
}
```

### 平台场景实现（`MacSceneBuilder`，Platforms/macOS 层）

```swift
// Sources/Platforms/macOS/Scenes/MacSceneBuilder.swift
@MainActor
struct MacSceneBuilder {
    static var root: some Scene {
        WindowGroup("智宇", id: "main") {
            MacMainWindow()                    // 复用现有三栏布局
                .modifier(MacEnvironmentInjection())
        }
        .defaultSize(width: 1200, height: 800)
        .commands {
            MacMenuCommands()
        }

        Settings {                             // 原生设置（⌘,）
            MacSettingsView()
        }

        Window("笔记本中心", id: "notebook-hub") {
            NotebookHubView()
        }
    }
}
```

### 环境注入内聚（`MacEnvironmentInjection`）

现有 `ZhiYuApp.body` 中 20+ 个 `.environment` 注入抽成公共 modifier，macOS 与 iOS 共用，避免重复：

```swift
// Sources/App/Scenes/Mac/MacEnvironmentInjection.swift
struct MacEnvironmentInjection: ViewModifier {
    func body(content: Content) -> some View {
        content
            .environment(appEnv)
            .environment(AuthService.shared)
            .environment(appEnv.store)
            // ... 全部 20+ 注入
    }
}
```

### 文件布局（平台宏内聚）

```
Sources/App/Scenes/AppSceneBuilder.swift                     # 单一分发点（#if 三平台，App 层）
Sources/App/Scenes/SceneEnvironmentInjection.swift            # 环境注入公共 modifier（两平台共用）
Sources/Platforms/macOS/Scenes/MacSceneBuilder.swift         # macOS 场景根（主窗口+Settings+辅助窗口）
Sources/Platforms/macOS/Scenes/MacMainWindow.swift           # 主窗口三栏外壳
Sources/Platforms/macOS/Scenes/MacMenuCommands.swift         # 完整菜单栏
Sources/Platforms/macOS/Scenes/MacSettingsView.swift         # 原生设置（Sidebar+Detail，7 Section）
Sources/Platforms/iOS/Scenes/iOSSceneBuilder.swift            # iOS 场景根（现有 WindowGroup）
```

---

## 登录页：运行时 Trait 桌面化 AuthView

### 现状

`AuthView`（`Sources/Features/System/Auth/View/AuthView.swift`）在业务层（Features），纯移动端风格：全屏 ZStack + ScrollView + 3D 翻转 + 顶部区域/语言切换条。未登录时由 `mainContainer`（`AppLayoutComponents.swift:39`）直接显示。无任何平台适配，Mac 上呈现 iOS 风格全屏登录页。

### 方案：运行时 Trait 分派（符合业务层规范）

`AuthView` 在业务层，**禁用 `#if os()`**。采用项目已确立的运行时 Trait 模式（先例：`SettingsView.swift:108`、`GraphComponents.swift:108` 用 `@Environment(\.interfaceIdiom)` 判断 `.mac`）：

```swift
struct AuthView: View {
    @Environment(\.interfaceIdiom) private var idiom

    var body: some View {
        if idiom == .mac {
            macLoginLayout                    // 桌面居中布局
        } else {
            mobileLoginLayout                 // 现有移动端布局（原 body）
        }
    }
}
```

- 桌面布局 `macLoginLayout` 作为 `AuthView` 的**私有 computed 属性**（同文件，可访问 `@State` 与 `handleAuth`/`handleThirdPartyLogin`）。
- 复用现有 `heroHeader`/`topControlBar`/`AuthPhonePanel`/`AuthOAuthPanel`/`AuthGuestSection`，不改业务逻辑。
- 无 `#if os()`，纯运行时 Trait，符合业务层规范。

### Mac 桌面登录布局（`macLoginLayout`）

```swift
private var macLoginLayout: some View {
    ZStack {
        themeManager.pageBackground().ignoresSafeArea()

        HStack(spacing: 0) {
            // 左侧品牌展示区
            heroHeader
                .frame(maxWidth: DesignTokens.Metrics.authHeroWidth)
                .padding(.leading, DesignTokens.Spacing.huge)

            Divider()
                .background(Color.appBorder.opacity(DesignTokens.Opacity.shadow))

            // 右侧登录卡片（居中，非全屏滚动）
            ScrollView(showsIndicators: false) {
                VStack(spacing: DesignTokens.Spacing.large) {
                    topControlBar
                    if displayedRegion == .china {
                        AuthPhonePanel(...)
                    } else {
                        OverseasLoginCardView()
                            .id(Localized.currentLanguage)
                    }
                    AuthOAuthPanel(...)
                    AuthGuestSection()
                }
                .frame(maxWidth: DesignTokens.Metrics.authFormWidth)
                .padding(DesignTokens.Spacing.wide)
            }
            .frame(maxWidth: .infinity)
        }
    }
    .policySheet(...)      // 复用政策弹窗
}
```

### 新增 Design Token

在 `UFPDesignSystem` 的 `DesignTokens+Metrics.swift`（对齐 `settingsSidebarWidth` 风格）新增：

```swift
// DesignTokens+Metrics.swift — Metrics 枚举扩展
/// Mac 登录页品牌区宽度 (420pt)
public static let authHeroWidth: CGFloat = 420
/// Mac 登录页登录表单最大宽度 (420pt)
public static let authFormWidth: CGFloat = 420
```

### 登录页与场景的关系

未登录时 `MacMainWindow` 直接呈现 `AuthView`（经 trait 分派到桌面布局），无额外弹窗；登录成功后进入主三栏。登录状态切换逻辑保持不变（`mainContainer` 的 `isLoggedIn || isGuest` 判断）。

---

## 多窗口与弹窗入口分层（Mac 原生化）

### 现状问题

`ContentView.swift:92-146` 有 **6 个 `appFullScreenCover` 弹窗**（`appFullScreenCover` 在 macOS 用 `sheet`，见 `DesignModifiers.swift:234`）：
`SettingsView`/`AISettingsView`/`UserProfileView`/`SubscriptionPlanView`/`PluginCenterView`/`AboutView`。

设计若只迁移"设置"会遗漏其余 5 个，且 `UserProfileMenu`（共享组件）的"设置/订阅/AI设置/插件"入口在 Mac 上仍走 sheet 路径，与原生 Settings 冲突。

### 分层方案（按类型）

| 视图 | 类型 | Mac 呈现 |
|------|------|----------|
| `SettingsView` | 设置类 | 原生 `Settings` scene（⌘,） |
| `AISettingsView` | 设置类 | 并入 Settings scene（AI Section） |
| `UserProfileView` | 账户类 | 独立 `Window` scene（profile） |
| `SubscriptionPlanView` | 账户类 | 独立 `Window` scene（plan） |
| `PluginCenterView` | 插件类 | 独立 `Window` scene（plugins） |
| `AboutView` | 关于类 | macOS 原生 About 面板（`NSApplication.orderFrontStandardAboutPanel`）或独立 Window |

### MacSceneBuilder 补充窗口

```swift
@MainActor
struct MacSceneBuilder {
    static var root: some Scene {
        WindowGroup("智宇", id: "main") {
            MacMainWindow().modifier(MacEnvironmentInjection())
        }
        .defaultSize(width: 1200, height: 800)
        .commands { MacMenuCommands() }

        Settings { MacSettingsView() }   // 设置 scene

        // 辅助窗口（原生多窗口）
        Window("个人资料", id: "profile") { UserProfileView() }
        Window("订阅计划", id: "plan") { SubscriptionPlanView() }
        Window("插件中心", id: "plugins") { PluginCenterView() }
        Window("笔记本中心", id: "notebook-hub") { NotebookHubView() }
    }
}
```

### UserProfileMenu Mac 化（共享组件）

`UserProfileMenu`（`UserProfileMenu.swift:14`）在 macOS 分支用 `SettingsLink`（设置）与 `@Environment(\.openWindow)`（其余窗口）：

```swift
// UserProfileMenu body — 在现有 #if os(watchOS)/#else 基础上，
// 增加 macOS 分支（#if os(macOS)，共享组件允许平台宏，但需内聚）
#if os(macOS)
Menu {
    Button { openWindow(id: "profile") } { Label(..., systemImage: "person") }
    Divider()
    SettingsLink { Label(L10n.Common.settings, systemImage: "gearshape") }  // 原生设置
    Button { openWindow(id: "plan") } { Label(L10n.Auth.subscription, ...) }
    Button { openWindow(id: "plugins") } { Label(L10n.Plugin.title, ...) }
    Divider()
    Button(role: .destructive) { authService.logout() } { Label(logout, ...) }
} label: { profileLabel }
#endif
```

> **Note**: `UserProfileMenu` 属 Shared 层（非业务层），允许 `#if os(macOS)`，但仅在此一处内聚，不散落。

### 窗口级配置

```swift
WindowGroup("智宇", id: "main") { ... }
    .defaultSize(width: 1200, height: 800)
    .windowResizability(.contentSize)          // 随内容调整，非固定
    // 辅助窗口最小尺寸由视图内容决定
```

### 辅助窗口登录态约束

辅助 `Window`（profile/plan/plugins/notebook-hub）仅登录/游客状态可打开；未登录时 `openWindow` 不触发或先引导登录。在 `UserProfileMenu` 与 `MacMenuCommands` 中用 `authSession.isLoggedIn || authSession.isGuest` 守卫。

### 无障碍（Accessibility）

- 现有 `accessibilityIdentifier`（如 `settingsMenuButton`/`aiSettingsMenuButton`/`logoutButton`）在 Mac 上保留，供 UI 自动化与 VoiceOver 定位。
- `UserProfileMenu` Mac 化后保留 `accessibilityIdentifier`，不因平台分支丢失。
- 侧边栏/设置列表用系统默认焦点行为（`NavigationSplitView` 自带键盘导航）。
- 菜单命令带 `keyboardShortcut`，支持键盘可达。

---

## MacMainWindow 组装策略（复用现有 ContentView）

### 核心原则：只换外壳，不重写内容

`ContentView`（`Sources/App/Scenes/ContentView.swift`）已完整处理 macOS 布局：`adaptiveTabView` 在 macOS 走 `adaptiveSplitView`（`AppLayoutComponents.swift:153`，三栏 `NavigationSplitView`），并已包含：

| 能力 | 位置 | 说明 |
|------|------|------|
| 登录态分派 | `mainContainer`（`AppLayoutComponents.swift:24`） | 未登录→`AuthView`，登录→主内容 |
| 三栏布局 | `adaptiveSplitView`（`:153`） | `NavigationSplitView` + `.commandPaletteSheet` |
| 全局浮层 | `globalOverlaySheets()`（`:109`） | CreateSheet/PerfDashboard/Medal/CoachMark |
| toast 提示 | `mainContent`（`:67`） | `appToast()` |
| 安全锁定层 | `ContentView.swift:86` | `LockOverlayView`（macOS 用 Touch ID） |
| 依赖注入 | `ContentView.swift:21-40` | store/themeManager/router/authService/vaultService + 10+ 环境 |
| tint/deepLink | `ScenesSharedComponents.swift:218` | `TabViewCommonModifiers` |

### MacMainWindow 定义

```swift
// Sources/Platforms/macOS/Scenes/MacMainWindow.swift
/// macOS 主窗口：复用现有 ContentView 全部能力，仅作原生外壳包装
struct MacMainWindow: View {
    var body: some View {
        ContentView()          // 完整复用：登录分派 + 三栏 + 浮层 + 锁定 + toast + 注入
            .modifier(MacEnvironmentInjection())
    }
}
```

> **Note**: `MacMainWindow` 不重复实现布局/浮层/锁定，直接包装 `ContentView`。macOS 专属差异（窗口标题/尺寸/辅助窗口入口）由 `MacSceneBuilder`/`MacMenuCommands` 承担。

### 安全锁定解锁（Touch ID）

`LockOverlayView`（`Sources/Shared/UIComponents/Overlays/LockOverlayView.swift:21`）已有 macOS 分支（`touchid` 图标），无需改动。`MacMainWindow` 包装 `ContentView` 后自动保留此能力。

### CommandPalette 增强（可选）

`showCommandPalette`（`ContentView.swift:31`）当前无触发入口（声明但未赋值）。Mac 菜单栏可新增"打开命令面板"命令（快捷键 ⌘P）触发：

```swift
// MacMenuCommands
CommandGroup(after: .toolbar) {
    Button(L10n.Search.commandPalette) { showCommandPalette.toggle() }
        .keyboardShortcut("p", modifiers: .command)
}
```

> 需将 `showCommandPalette` 从 `ContentView` 提升到共享状态（或通过通知/Router）供菜单命令访问。

### 插件安装 fileImporter 保留

`PluginCenterView`（`Sources/Features/System/Settings/View/Plugins/PluginCenterView.swift:71`）含 `fileImporter`（插件安装）。迁移到独立 `Window` scene 后，`fileImporter` 在 `Window` 内正常工作（SwiftUI `.sheet` + `.fileImporter` 支持窗口呈现），无需额外处理，但需在 UI 测试中验证。

---

## 设置页：原生 Settings scene

### 结构：保留现有 7 Section，只改布局

**决策**：不重分类，沿用现有 `SettingsView.SettingsSection`（appearance/security/data/plugins/feedback/developer/about），只把移动端列表改为 Mac 原生布局。

`MacSettingsView` 复用 `SettingsView` 的 `SettingsSection` 枚举与 `detailColumn(for:)` 内容，但用 **Sidebar + Detail 布局**（对齐 `SettingsView.swift:108` 的 `.mac` 已有分支，抽为独立 `MacSettingsView`）：

```swift
struct MacSettingsView: View {
    @State private var selectedSection: SettingsView.SettingsSection? = .appearance

    var body: some View {
        NavigationSplitView {
            List(SettingsView.SettingsSection.allCases, selection: $selectedSection) { section in
                Label(section.displayName, systemImage: section.iconName)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
            .listStyle(.sidebar)
        } detail: {
            if let section = selectedSection {
                SettingsView.detailColumn(for: section)   // 复用现有分区内容
            } else {
                Text(L10n.Common.selectSection)
            }
        }
        .frame(minWidth: 620, minHeight: 480)
    }
}
```

> **Note**: `SettingsSection` 及其 `detailColumn(for:)` 需从 `SettingsView` 内部提取为可复用类型（`private` → `internal`，或迁移到独立文件），供 `MacSettingsView` 与 `SettingsView` 共用，避免重复。

### AISettings 并入

`AISettingsView` 作为 AI 设置内容并入 Mac 设置（新增 Section 或并入 appearance/data），Mac 上不再以独立 sheet 打开。

### Pane 内容来源

各 Section 复用现有 `SettingsView` 分区（外观/安全/数据/插件/反馈/关于），依赖（`SettingsStore`/`ThemeManager`/`LLMConfig`）经环境注入保持。原有 `.mac` 分支的 sidebarColumn 逻辑迁移到 `MacSettingsView`，`SettingsView` 保留 iOS/移动端路径。

### 触发方式

- **⌘,** 菜单 → 打开原生 `Settings` scene（系统标准）。
- `UserProfileMenu` 的"设置"入口 → macOS 分支用 `SettingsLink`（iOS 保持 sheet）。
- macOS 分支废弃 `router.isShowingSettingsSheet`（iOS 保留）。

---

## 菜单栏：完整原生菜单

```swift
// Sources/Platforms/macOS/Scenes/MacMenuCommands.swift
struct MacMenuCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(L10n.Creation.newPage) { post(.createNewPage) }
                .keyboardShortcut("n", modifiers: .command)
        }
        CommandGroup(after: .toolbar) {
            Button(L10n.Sidebar.toggle) { toggleSidebar }
                .keyboardShortcut("s", modifiers: [.command, .control])
        }
        CommandGroup(after: .windowArrangement) {
            Button(L10n.Notebook.openHub) { openNotebookHub }
        }
        CommandGroup(replacing: .help) {
            Link(L10n.Common.help, destination: helpURL)
        }
    }
}
```

系统默认的"编辑"（剪切/复制/粘贴/撤销）、"应用"菜单（关于/设置/隐藏/退出）、"窗口"菜单保留。

---

## 视觉风格（原生质感 + 品牌）

| 维度 | 方案 |
|------|------|
| 窗口 | 原生 `.automatic` 样式，红绿灯/缩放/全屏 |
| 工具栏 | `NavigationSplitView` 原生工具栏，`.primaryAction` placement |
| 侧边栏 | 按平台启用宽度 Token（macOS 专属值），`.sidebar` 材质 |
| 材质 | `.ultraThinMaterial` / `.sidebar`，符合 Mac 毛玻璃惯例 |
| 品牌 | 保留 `ThemeManager.accentColor` 渐变，应用于选中态/强调元素 |
| 字体/间距 | 复用 DesignSystem Token，Mac 上微调行高/列表样式 `.inset` |

### 侧边栏宽度 Token

在 `UFPDesignSystem` 或 `DesignSystem+Sidebar` 新增 macOS 专属宽度（**仅新增**，不破坏 iOS）：

```swift
public static let macSidebarWidth: CGFloat = 260   // 新增，供 MacMainWindow 使用
```

---

## 共享层影响（最小化）

| 改动 | 位置 | 平台影响 |
|------|------|----------|
| 侧边栏宽度 Token | `DesignSystem+Sidebar` | 仅新增，iOS 不受影响 |
| 登录页 Token | `UFPDesignSystem` Metrics | 仅新增 `authHeroWidth`/`authFormWidth`，iOS 不引用 |
| `AuthView` 桌面布局 | `AuthView` 同文件 | 运行时 Trait 分派，iOS 走原布局 |
| `UserProfileMenu` Mac 化 | Shared 层单点 `#if os(macOS)` | iOS/watch 分支不动 |
| `SettingsSection`/`detailColumn` 提取 | `SettingsView` 文件 | 提取为 internal，两平台共用 |
| `MacMainWindow` | Platforms/macOS 新增 | 包装 `ContentView`，不重写内容；iOS 不受影响 |
| `ContentView` | 仅 macOS 分支移除弹窗 | iOS 路径不变 |
| 现有 `#if os(macOS)` | 保持/收敛 | 已在 Platforms/基础设施层 |
| `AppSceneBuilder`/`SceneEnvironmentInjection` | App 层新增 | 单一分发点 |

**原则**：共享层只新增 Token/类型，不修改 iOS 现有行为路径；平台差异靠 `#if os` 分发点 + Platforms 目录隔离。

---

## 实施拆分（建议任务顺序）

1. **任务 1**：`SceneEnvironmentInjection`（抽取 20+ 环境注入）+ `AppSceneBuilder` + `iOSSceneBuilder`（现有结构）
2. **任务 2**：`MacSceneBuilder` + `MacMainWindow`（包装 `ContentView`，复用三栏/浮层/锁定/注入）骨架 + 窗口级配置
3. **任务 3**：主窗口接入 `.commands` 基础菜单（⌘N、退出）
4. **任务 4**：登录页运行时 Trait 桌面化（`AuthView` 分派 + `macLoginLayout` + Auth Token）
5. **任务 5**：`Settings` scene + `MacSettingsView`（Sidebar+Detail，提取 `SettingsSection` 为可复用类型）
6. **任务 6**：`UserProfileMenu` Mac 化（`SettingsLink` + `openWindow`）+ 辅助 Window scenes（profile/plan/plugins）
7. **任务 7**：完整菜单栏（查看/窗口/帮助）+ 侧边栏宽度 Token + 辅助窗口登录态守卫
8. **任务 8**：移除 macOS 分支 6 个 `appFullScreenCover` 弹窗入口，接入原生场景；AISettings 并入设置；About 用原生面板
9. **任务 9**：视觉打磨（材质/工具栏/字体）+ CommandPalette 快捷键（可选）+ 插件 fileImporter 验证
10. **任务 10**：测试用例更新 + 文档更新（见下两节）

---

## L10n 与设计 Token 约束

- 设计中的菜单文案、设置 Section 标题、快捷键提示等全部通过 `L10n.模块.属性` 强类型访问，禁止硬编码。
- 新增 key（如 `L10n.Sidebar.toggle`、`L10n.Notebook.openHub`、辅助窗口标题 `L10n.Window.profile/plan/plugins` 等）须在 `Sources/Localization/Extensions/L10n+XXX.swift` 注册并映射到 `.xcstrings` Catalog。
- 设置 Section 标题沿用现有 `L10n.Settings.Section.*`（已存在），不新增 5 Pane 分类 key。
- 视图样式/间距/圆角一律引用 `DesignSystem` Token，禁止硬编码字面量。

---

## 测试用例更新

### 单元测试

| 测试文件 | 更新点 |
|----------|--------|
| `Tests/Unit/App/AppRootScenesAndNavigationTests.swift` | 验证 `AppSceneBuilder` 分发（macOS→MacSceneBuilder，iOS→iOSSceneBuilder）；`ZhiYuApp.body` 极简化不破坏现有导航 |
| `Tests/Unit/App/ContentViewDeepTests.swift` / `ContentViewAndCollaborationDeepTests.swift` | 确认 macOS 分支移除 6 个 `appFullScreenCover` 后 iOS 路径不变（iOS 保留），补 `ContentView` 平台分支测试 |
| `Tests/Unit/App/AppRootScenesAndSidebarDeepTests.swift` | 侧边栏宽度 Token 切换（mac 用 `macSidebarWidth`，iOS 用原值） |
| 新增 `Tests/Unit/App/AppSceneBuilderTests.swift` | `AppSceneBuilder.root` 各平台分发；`SceneEnvironmentInjection` 环境注入完整性（20+ environment 不遗漏）；`MacMainWindow` 包装 `ContentView` 保留锁定层/浮层/toast |
| 新增 `Tests/Unit/Auth/MacAuthViewLayoutTests.swift` | `AuthView` 的 `interfaceIdiom == .mac` 分派到 `macLoginLayout`；iOS 走 `mobileLoginLayout`；登录逻辑不变 |
| 新增 `Tests/Unit/App/MacWindowSceneTests.swift` | 辅助 `Window` scene（profile/plan/plugins）登录态守卫（未登录不触发 `openWindow`） |

### UI 测试

| 测试文件 | 更新点 |
|----------|--------|
| `Tests/UI/SettingsUITests.swift` | 现有 iOS Tab 栏进设置路径保留；新增 macOS 场景验证 ⌘, 打开 Settings、Sidebar+Detail 布局 |
| `Tests/UI/AISettingsTabSwitchingUITests.swift` | 路由注入打开 AI 设置 sheet 的路径，在 macOS 改为验证 AI 设置并入 Settings scene |
| 新增 `Tests/UI/MacSettingsUITests.swift` | Mac 设置导航、Section 切换、⌘, 触发（如测试环境支持 Mac UI 自动化） |
| `Tests/UI/ZhiYuUITests.swift` | 确认登录→主界面路径在 Mac 上经 `macLoginLayout` 后不变 |

### 快照测试

- 现有 iOS 快照（`Tests/SnapshotTests/`）不回归：共享层仅新增 Token/类型。
- 可选新增 Mac 快照：`MacSettingsView`（Sidebar+Detail）、`macLoginLayout`（需 SwiftUI 快照工具支持多平台）。

---

## 文档更新

| 文档 | 更新点 |
|------|--------|
| `Docs/Architecture/HIGH_LEVEL_DESIGN.md` | 场景结构：`AppSceneBuilder` 单一分发点 + `MacSceneBuilder`/`iOSSceneBuilder`；多窗口 |
| `Docs/Architecture/PLATFORM_PROTOCOL_ARCHITECTURE.md` | `AppSceneBuilder` 作为平台 scene 分发点示例；`UserProfileMenu` Mac 化模式 |
| `Docs/Guides/config-conventions.md` | 新增 `Platforms/macOS/Scenes/` 目录规范（Mac 场景/视图隔离）；`Platforms/iOS/Scenes/` |
| `Docs/Design/UI_COMPONENTS.md` | Mac 原生组件（设置 Sidebar+Detail、辅助窗口、菜单命令） |
| `Docs/Requirements/FEATURE_LIST.md` | Mac 原生特性（原生设置、多窗口、完整菜单、桌面登录）实现状态 |
| `AGENTS.md` | 场景结构、`Platforms/*/Scenes` 文件布局说明 |
| `Docs/superpowers/specs/2026-11-19-mac-native-ui-redesign-design.md` | 本文档 |

---

## 测试策略

- **构建门禁**：`make mac` 编译通过（Swift 6 严格并发）。
- **静态门禁**：`make audit`（架构分层、去魔鬼化、L10n、平台宏规范全绿）。
- **现有测试**：iOS 单测/UI 测试/快照不回归（共享层仅新增分支/Token）。
- **Mac UI 验证**：手动验证 ⌘, 打开设置、菜单栏功能、侧边栏宽度、多窗口、⌘N 新建、登录页桌面布局。
- **平台宏审计**：确认业务层（Features/Domain）无新增 `#if os()`，`#if os(macOS)` 收敛于 AppSceneBuilder + Platforms 目录 + UserProfileMenu（Shared 层单点）。

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| `SettingsSection`/`detailColumn(for:)` 从 `SettingsView` 提取改动大 | 提取为可复用类型，`SettingsView` 与 `MacSettingsView` 共用；iOS 单测守护 |
| 6 个 `appFullScreenCover` 移除影响 Router/UI 测试 | 仅移除 macOS 分支，iOS 保留；UI 测试分平台断言 |
| `UserProfileMenu`（Shared 层）Mac 化改动 | 单点 `#if os(macOS)` 内聚；iOS/watch 分支不动 |
| 辅助窗口登录态 | `openWindow` 守卫（`isLoggedIn || isGuest`） |
| 共享层改动引入 iOS 回归 | 仅新增 Token/类型 + iOS 单测 + 快照守护 |
| Swift 6 严格并发 | 新类型标注 `@MainActor` |
| 平台宏散布 | AppSceneBuilder 单一分发点 + Platforms 目录隔离 + Shared 单点 |