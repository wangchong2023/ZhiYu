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
Sources/Platforms/macOS/Scenes/MacSceneBuilder.swift         # macOS 场景根
Sources/Platforms/macOS/Scenes/MacMainWindow.swift           # 主窗口三栏外壳
Sources/Platforms/macOS/Scenes/MacMenuCommands.swift         # 完整菜单栏
Sources/Platforms/macOS/Scenes/Settings/MacSettingsView.swift
Sources/Platforms/macOS/Scenes/Settings/GeneralSettingsPane.swift
Sources/Platforms/macOS/Scenes/Settings/AISettingsPane.swift
Sources/Platforms/macOS/Scenes/Settings/AccountSettingsPane.swift
Sources/Platforms/macOS/Scenes/Settings/SecuritySettingsPane.swift
Sources/Platforms/macOS/Scenes/Settings/AboutPane.swift
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

## 设置页：原生 Settings scene

### 系统偏好设置风格（TabView 5 Pane）

```swift
struct MacSettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsPane()
                .tabItem { Label(L10n.Settings.general, systemImage: "gearshape") }
            AISettingsPane()
                .tabItem { Label(L10n.Settings.ai, systemImage: "brain.head.profile") }
            AccountSettingsPane()
                .tabItem { Label(L10n.Settings.account, systemImage: "person.crop.circle") }
            SecuritySettingsPane()
                .tabItem { Label(L10n.Settings.security, systemImage: "lock.shield") }
            AboutPane()
                .tabItem { Label(L10n.Settings.about, systemImage: "info.circle") }
        }
        .frame(width: 620, height: 480)
    }
}
```

### Pane 内容来源

各 Pane 复用现有 `SettingsView.swift` 的既有分区（外观/语言/主题 → 通用；模型/API → AI；登录/订阅/同步 → 账户；隐私/生物识别 → 安全；关于 → 关于），拆解到对应 Pane。依赖（`SettingsStore`/`ThemeManager`/`LLMConfig`）经环境注入保持。

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
| `ContentView` | 不动 | macOS 走 `MacMainWindow` |
| 现有 25 处 `#if os(macOS)` | 保持/收敛 | 已在 Platforms/基础设施层 |
| `AppSceneBuilder`/`SceneEnvironmentInjection` | App 层新增 | 单一分发点 |

**原则**：共享层只新增 Token/类型，不修改 iOS 现有行为路径；平台差异靠 `#if os` 分发点 + Platforms 目录隔离。

---

## 实施拆分（建议任务顺序）

1. **任务 1**：`SceneEnvironmentInjection`（抽取 20+ 环境注入）+ `AppSceneBuilder` + `iOSSceneBuilder`（现有结构）
2. **任务 2**：`MacSceneBuilder` + `MacMainWindow` 骨架（三栏复用现有 `adaptiveSplitView`）
3. **任务 3**：主窗口接入 `.commands` 基础菜单（⌘N、退出）
4. **任务 4**：登录页运行时 Trait 桌面化（`AuthView` 分派 + `macLoginLayout` + Auth Token）
5. **任务 5**：`Settings` scene + `MacSettingsView` TabView 外壳
6. **任务 6**：拆分设置 Pane（通用/AI/账户/安全/关于）
7. **任务 7**：完整菜单栏（查看/窗口/帮助）+ 侧边栏宽度 Token
8. **任务 8**：辅助 `Window` scene（笔记本中心）
9. **任务 9**：移除 macOS 分支 fullScreenCover 设置入口，接入 `SettingsLink`；视觉打磨

---

## L10n 与设计 Token 约束

- 设计中的菜单文案、设置 Pane 标题、快捷键提示等全部通过 `L10n.模块.属性` 强类型访问，禁止硬编码。
- 新增 key（如 `L10n.Settings.general/ai/account/security/about`、`L10n.Sidebar.toggle`、`L10n.Notebook.openHub` 等）须在 `Sources/Localization/Extensions/L10n+XXX.swift` 注册并映射到 `.xcstrings` Catalog。
- 视图样式/间距/圆角一律引用 `DesignSystem` Token，禁止硬编码字面量。

---

## 测试策略

- **构建门禁**：`make mac` 编译通过（Swift 6 严格并发）。
- **静态门禁**：`make audit`（架构分层、去魔鬼化、L10n、平台宏规范全绿）。
- **现有测试**：iOS 单测不受影响（共享层仅新增分支/Token）。
- **Mac UI 验证**：手动验证 ⌘, 打开设置、菜单栏功能、侧边栏宽度、多窗口、⌘N 新建。
- **平台宏审计**：确认业务层（Features/Domain）无新增 `#if os()`，`#if os(macOS)` 收敛于 AppSceneBuilder + Platforms 目录。
- **快照测试**：现有 iOS 快照不回归；Mac 界面可选新增快照。

---

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| SettingsView 拆分 Pane 改动大 | 分任务推进，每个 Pane 独立提交 |
| fullScreenCover → Settings 迁移影响 Router 状态 | 保留 iOS 路径，macOS 分支单独处理 |
| 共享层改动引入 iOS 回归 | 仅新增 Token/类型 + iOS 单测 + 快照守护 |
| Swift 6 严格并发 | 新类型标注 `@MainActor` |
| 平台宏散布 | AppSceneBuilder 单一分发点 + Platforms 目录隔离 |