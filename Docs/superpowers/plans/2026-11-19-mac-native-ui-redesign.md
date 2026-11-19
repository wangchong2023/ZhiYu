# Mac 界面全面原生化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 ZhiYuMac 从"iOS 风格 UI 套桌面窗口"升级为符合 macOS 平台规范的全面原生体验（原生场景结构、原生 Settings、完整菜单栏、独立辅助窗口、桌面登录页），并严格遵循项目平台宏内聚架构规范与既有 `ContentView` 复用原则。

**Architecture:** 只换外壳不重写内容——`MacMainWindow` 直接包装现有 `ContentView`（已完整处理 macOS 三栏布局、登录分派、浮层、安全锁定、注入）。新增 `AppSceneBuilder` 作为唯一 `#if os` 三平台场景分发点（接收 `ZhiYuApp` 的 `@State` 状态，经 `@SceneBuilder` 组合多 scene）；`MacSceneBuilder` 提供主窗口 + Settings + 辅助窗口；`MacSettingsView` 复用 `SettingsView` 的 `.mac` 分支。平台宏新增收敛于 AppSceneBuilder 分发点 + Platforms/macOS 目录隔离 + UserProfileMenu 单点。

**Tech Stack:** Swift 6、SwiftUI（SceneBuilder/WindowGroup/Settings/Window/openWindow）、AppKit、xcodegen；平台版本 macOS 27.0。

## Global Constraints

- **分层红线**：Features/Domain 层禁用 `#if os()`；业务层平台差异用运行时 Trait（`@Environment(\.interfaceIdiom)`）分支。宏仅允许 Shared/Platforms/Core/Infrastructure/App 层，且收敛到分发点。
- **ContentView 复用**：`MacMainWindow` 包装 `ContentView`，不重写布局/浮层/锁定/注入；macOS 专属差异由 `MacSceneBuilder`/`MacMenuCommands` 承担。
- **SettingsView 复用**：`MacSettingsView` 复用 `SettingsView` 的 `.mac` 分支（`SettingsView.swift:108-125`），仅移除 doneButton；不提取 private 成员。
- **去魔鬼化**：禁止硬编码魔法数字/字符串；UI 尺寸用 `DesignSystem` token（新增 token 放 UFPDesignSystem 包）。
- **L10n 强约束**：新增菜单/窗口标题/文案走 `L10n.模块.属性`，禁硬编码；新增 key 注册到 `.xcstrings`。
- **测试质量红线**：语句覆盖率 ≥95%、分支覆盖率 ≥90%（本方案新增代码需配套测试）。
- **并发**：Swift 6 严格并发；UI 代码 `@MainActor`；`@Observable` 类 `@Dependency` 加 `@ObservationIgnored`。
- **构建验证**：`make ios && make mac && make watch && make test-unit && make audit` 全过。
- **构建副产物**：`AppConstants.swift`/`Info.plist`/`InfoPlist.xcstrings`/`Widgets/Info.plist`/`ZhiYuWatch.xcscheme`/`project.yml` 若被构建污染需 checkout 还原，禁止提交。
- **注释**：简体中文；文档注释 `///` 解释"为什么"，实现注释 `//` 解释"怎么做"。

---

## 任务清单

### 任务 1：场景分发点 + 环境注入内聚

**Files:**
- Create: `Sources/App/Scenes/AppSceneBuilder.swift`
- Create: `Sources/App/Scenes/SceneEnvironmentInjection.swift`
- Create: `Sources/Platforms/iOS/Scenes/iOSSceneBuilder.swift`
- Modify: `Sources/App/Core/ZhiYuApp.swift`（body 极简化，抽出注入）

**Interfaces:**
- Consumes: `AppEnvironment`（`AppEnvironment.shared`）、`ZhiYuAppModel`（`Sources/App/AppModel.swift`）、`DependencyContainer`（`Sources/Core/Base/DependencyContainer.swift`）、`ThemeManager`、`OnboardingService`、`AuthService`、`MedalService`、`AppStore`、`Localized`。
- Produces: `AppSceneBuilder.root(appEnv:appModel:dependencies:themeManager:onboardingService:hasSeenSplash:) -> some Scene`（@SceneBuilder，`#if os(macOS)` → MacSceneBuilder 三组，否则 iOSSceneBuilder.main）。`SceneEnvironmentInjection`（ViewModifier，含 20+ 注入）。

- [ ] **Step 1: 创建 `SceneEnvironmentInjection.swift`**

把 `ZhiYuApp.body`（`ZhiYuApp.swift:83-104`）的注入链抽为公共 modifier：

```swift
//
//  SceneEnvironmentInjection.swift
//  ZhiYu
//
//  系统层级：[L3] 应用层
//  核心职责：抽取 ZhiYuApp.body 的 20+ 环境注入为公共 ViewModifier，供 iOS/macOS 场景共用。
//
import SwiftUI
import UFPDesignSystem

/// 公共环境注入 modifier：对齐 ZhiYuApp.body 的注入链，两平台共用
struct SceneEnvironmentInjection: ViewModifier {
    let appEnv: AppEnvironment
    let appModel: ZhiYuAppModel
    let dependencies: DependencyContainer
    let themeManager: ThemeManager
    let onboardingService: OnboardingService

    func body(content: Content) -> some View {
        content
            .environment(appEnv)
            .environment(AuthService.shared)
            .environment(VaultService.shared)
            .environment(appEnv.store)
            .environment(appEnv.store.aiWorkflowStore)
            .environment(appEnv.store.aiInsightStore)
            .environment(appEnv.store.searchStore)
            .environment(appEnv.store.tagStore)
            .environment(appEnv.store.knowledgeStore)
            .environment(appEnv.store.settingsStore)
            .environment(appEnv.llmConfig)
            .environment(appEnv.router)
            .environment(appEnv.ingestStore)
            .environment(appEnv.synthesisStore)
            .environment(appModel)
            .environment(dependencies)
            .environment(themeManager)
            .environmentObject(ServiceContainer.shared.resolve(LLMService.self) as LLMService)
            .environmentObject(onboardingService)
            .environmentObject(MedalService.shared)
            .environment(\.locale, Localized.currentLocale)
    }
}
```

> 注：逐项对齐 `ZhiYuApp.swift:83-104` 的注入链，不得遗漏。

- [ ] **Step 2: 创建 `iOSSceneBuilder.swift`**

```swift
//
//  iOSSceneBuilder.swift
//  ZhiYu
//
//  系统层级：[L3] 应用层
//  核心职责：iOS/watchOS 场景根，对齐现有 ZhiYuApp.body 的 WindowGroup。
//
import SwiftUI

/// iOS/watchOS 场景构建器
@MainActor
enum iOSSceneBuilder {
    /// 主窗口（含闪屏）
    @SceneBuilder
    static func main(
        appEnv: AppEnvironment,
        appModel: ZhiYuAppModel,
        dependencies: DependencyContainer,
        themeManager: ThemeManager,
        onboardingService: OnboardingService,
        hasSeenSplash: Bool
    ) -> some Scene {
        WindowGroup {
            ContentView()
                .modifier(SceneEnvironmentInjection(
                    appEnv: appEnv, appModel: appModel, dependencies: dependencies,
                    themeManager: themeManager, onboardingService: onboardingService
                ))
            // 闪屏逻辑保持：hasSeenSplash 由外部传入，此处仅标注
        }
    }
}
```

- [ ] **Step 3: 创建 `AppSceneBuilder.swift`**

```swift
//
//  AppSceneBuilder.swift
//  ZhiYu
//
//  系统层级：[L3] 应用层
//  核心职责：唯一 #if os 三平台场景分发点，收敛平台 scene 差异。
//
import SwiftUI

/// 场景根分发：平台差异在此收敛，业务层无宏
@MainActor
enum AppSceneBuilder {
    /// 各平台场景根（@SceneBuilder 组合多 scene）
    @SceneBuilder
    static func root(
        appEnv: AppEnvironment,
        appModel: ZhiYuAppModel,
        dependencies: DependencyContainer,
        themeManager: ThemeManager,
        onboardingService: OnboardingService,
        hasSeenSplash: Bool
    ) -> some Scene {
        #if os(macOS)
        MacSceneBuilder.main(
            appEnv: appEnv, appModel: appModel, dependencies: dependencies,
            themeManager: themeManager, onboardingService: onboardingService
        )
        MacSceneBuilder.settings()
        MacSceneBuilder.windows()
        #else
        iOSSceneBuilder.main(
            appEnv: appEnv, appModel: appModel, dependencies: dependencies,
            themeManager: themeManager, onboardingService: onboardingService,
            hasSeenSplash: hasSeenSplash
        )
        #endif
    }
}
```

> 注：`MacSceneBuilder` 在任务 2 创建。此文件编译前需先创建 MacSceneBuilder 骨架（见任务 2 Step 1）或暂以注释占位。建议本任务先实现 iOSSceneBuilder + SceneEnvironmentInjection，MacSceneBuilder 骨架在任务 2 落地后补全 AppSceneBuilder 的 macOS 分支。

- [ ] **Step 4: 修改 `ZhiYuApp.body` 极简化**

`ZhiYuApp.swift:78-149` 的 `body` 替换为调用 `AppSceneBuilder.root(...)`，并把 `.environment` 注入链移除（移入 `SceneEnvironmentInjection`）。闪屏 `SplashView` 逻辑保留在 iOS 分支内（本任务先保留在 body 中，任务 2 后再决定归属）。

- [ ] **Step 5: 构建验证**

Run: `make ios`
Expected: BUILD SUCCEEDED（iOS target 编译通过，注入不遗漏不崩溃）

- [ ] **Step 6: 单测**

新增 `Tests/Unit/App/AppSceneBuilderTests.swift`：断言 `AppSceneBuilder.root` 在 iOS/watchOS 编译分支下 `iOSSceneBuilder.main` 被调用（无法在单测直接实例化 Scene，改为断言类型存在 + `SceneEnvironmentInjection` 注入链包含关键 key，用 Mirror 或环境断言）。

- [ ] **Step 7: Commit**

```bash
git add Sources/App/Scenes/AppSceneBuilder.swift Sources/App/Scenes/SceneEnvironmentInjection.swift Sources/Platforms/iOS/Scenes/iOSSceneBuilder.swift Sources/App/Core/ZhiYuApp.swift Tests/Unit/App/AppSceneBuilderTests.swift
git commit -m "feat(mac): 场景分发点 AppSceneBuilder + 环境注入内聚 SceneEnvironmentInjection"
```

---

### 任务 2：MacSceneBuilder + MacMainWindow 骨架

**Files:**
- Create: `Sources/Platforms/macOS/Scenes/MacSceneBuilder.swift`
- Create: `Sources/Platforms/macOS/Scenes/MacMainWindow.swift`

**Interfaces:**
- Consumes: 任务 1 的 `SceneEnvironmentInjection`；`MacMainWindow`（包装 `ContentView`）。
- Produces: `MacSceneBuilder.main/settings/windows`（@SceneBuilder 方法）；`MacMainWindow`（View）。`AppSceneBuilder` 的 macOS 分支依赖此。

- [ ] **Step 1: 创建 `MacMainWindow.swift`**

```swift
//
//  MacMainWindow.swift
//  ZhiYu
//
//  系统层级：[L3] 应用层
//  核心职责：macOS 主窗口外壳，复用现有 ContentView 全部能力（登录分派/三栏/浮层/锁定/注入）。
//
import SwiftUI

/// macOS 主窗口：仅作原生外壳包装，不重写内容
struct MacMainWindow: View {
    var body: some View {
        ContentView()   // 复用：登录分派 + 三栏 + 浮层 + 锁定 + toast + 依赖注入
    }
}
```

- [ ] **Step 2: 创建 `MacSceneBuilder.swift`**

```swift
//
//  MacSceneBuilder.swift
//  ZhiYu
//
//  系统层级：[L3] 应用层
//  核心职责：macOS 场景根：主窗口 + Settings + 辅助窗口。
//
import SwiftUI

/// macOS 场景构建器
@MainActor
enum MacSceneBuilder {
    /// 主窗口（WindowGroup + commands）
    @SceneBuilder
    static func main(
        appEnv: AppEnvironment,
        appModel: ZhiYuAppModel,
        dependencies: DependencyContainer,
        themeManager: ThemeManager,
        onboardingService: OnboardingService
    ) -> some Scene {
        WindowGroup("智宇", id: "main") {
            MacMainWindow()
                .modifier(SceneEnvironmentInjection(
                    appEnv: appEnv, appModel: appModel, dependencies: dependencies,
                    themeManager: themeManager, onboardingService: onboardingService
                ))
        }
        .defaultSize(width: 1200, height: 800)
        .windowResizability(.contentSize)
        .commands {
            MacMenuCommands()   // 任务 3 创建，先以空 Commands 占位
        }
    }

    /// 设置 scene（原生 Settings）
    static func settings() -> some Scene {
        Settings { MacSettingsView() }   // 任务 5 创建，先以占位视图
    }

    /// 辅助窗口（多窗口）
    @SceneBuilder
    static func windows() -> some Scene {
        Window("个人资料", id: "profile") { UserProfileView() }
        Window("订阅计划", id: "plan") { SubscriptionPlanView() }
        Window("插件中心", id: "plugins") { PluginCenterView() }
        Window("笔记本中心", id: "notebook-hub") { NotebookHubView() }
    }
}
```

> 注：`MacMenuCommands`（任务 3）、`MacSettingsView`（任务 5）未创建前，先以空类型占位或暂时注释对应行，保证本任务可编译。

- [ ] **Step 3: 构建验证**

Run: `make mac`
Expected: BUILD SUCCEEDED（macOS 场景结构编译通过）

- [ ] **Step 4: 单测**

新增 `Tests/Unit/App/MacSceneBuilderTests.swift`：断言 `MacSceneBuilder.windows()` 包含 profile/plan/plugins/notebook-hub 四个 `Window` id（用类型/字符串断言辅助）。验证 `MacMainWindow` 包装 `ContentView`（编译期）。

- [ ] **Step 5: Commit**

```bash
git add Sources/Platforms/macOS/Scenes/MacSceneBuilder.swift Sources/Platforms/macOS/Scenes/MacMainWindow.swift Tests/Unit/App/MacSceneBuilderTests.swift Sources/App/Scenes/AppSceneBuilder.swift
git commit -m "feat(mac): MacSceneBuilder 场景根 + MacMainWindow 外壳（复用 ContentView）"
```

---

### 任务 3：主窗口基础菜单（⌘N、退出）

**Files:**
- Create: `Sources/Platforms/macOS/Scenes/MacMenuCommands.swift`
- Modify: `Sources/App/Core/ZhiYuApp.swift:16-22`（macOS 的 `.createNewPage` 通知保留）

**Interfaces:**
- Consumes: `Notification.Name.createNewPage`（`ZhiYuApp.swift:16-22`）；`authSession`。
- Produces: `MacMenuCommands`（`Commands`，含 ⌘N 新建、退出守卫）。

- [ ] **Step 1: 创建 `MacMenuCommands.swift`**

```swift
//
//  MacMenuCommands.swift
//  ZhiYu
//
//  系统层级：[L3] 应用层
//  核心职责：macOS 完整菜单栏（新建/查看/窗口/帮助）。
//
import SwiftUI

/// macOS 菜单命令
struct MacMenuCommands: Commands {
    @Environment(AuthSession.self) private var authSession

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(L10n.Creation.newPage) {
                NotificationCenter.default.post(name: .createNewPage, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }
}
```

> 注：`L10n.Creation.newPage` 需确认存在（`Sources/Localization/Extensions/L10n+Knowledge.swift` 或对应扩展），不存在则在 `L10n+Common.swift` 新增并注册 `.xcstrings`。

- [ ] **Step 2: 构建验证**

Run: `make mac`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: 手动验证**

启动 Mac 应用，验证 ⌘N 触发新建页面通知。

- [ ] **Step 4: Commit**

```bash
git add Sources/Platforms/macOS/Scenes/MacMenuCommands.swift
git commit -m "feat(mac): 主窗口基础菜单（⌘N 新建、退出）"
```

---

### 任务 4：登录页运行时 Trait 桌面化

**Files:**
- Modify: `Sources/Features/System/Auth/View/AuthView.swift`
- Modify: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Metrics.swift`（新增 auth 宽度 token）

**Interfaces:**
- Consumes: `@Environment(\.interfaceIdiom)`（`PlatformTraits.swift`）；`AuthPhonePanel`/`AuthOAuthPanel`/`AuthGuestSection`/`OverseasLoginCardView`/`heroHeader`/`topControlBar`（AuthView 内部）。
- Produces: `AuthView.macLoginLayout`（私有 computed property）；`DesignTokens.Metrics.authHeroWidth/authFormWidth`。

- [ ] **Step 1: 新增 Design Token**

在 `DesignTokens+Metrics.swift` 的 `Metrics` 枚举内追加（对齐 `settingsSidebarWidth` 风格）：

```swift
/// Mac 登录页品牌区宽度 (420pt)
public static let authHeroWidth: CGFloat = 420
/// Mac 登录页登录表单最大宽度 (420pt)
public static let authFormWidth: CGFloat = 420
```

- [ ] **Step 2: 修改 `AuthView` 增加 trait 分派**

`AuthView.swift`：
1. 加 `@Environment(\.interfaceIdiom) private var idiom`
2. `body` 改为：

```swift
var body: some View {
    if idiom == .mac {
        macLoginLayout
    } else {
        mobileLoginLayout   // 原 body 内容
    }
}
```

3. 原 `body` 重命名为 `mobileLoginLayout`（private var）。
4. 新增 `macLoginLayout`（private var，桌面居中布局）：

```swift
private var macLoginLayout: some View {
    let _ = (showPrivacySheet, showTermsSheet)
    return ZStack {
        themeManager.pageBackground().ignoresSafeArea()
        HStack(spacing: 0) {
            heroHeader
                .frame(maxWidth: DesignTokens.Metrics.authHeroWidth)
                .padding(.leading, DesignTokens.Spacing.huge)
            Divider()
                .background(Color.appBorder.opacity(DesignTokens.Opacity.shadow))
            ScrollView(showsIndicators: false) {
                VStack(spacing: DesignTokens.Spacing.large) {
                    topControlBar
                    if displayedRegion == .china {
                        AuthPhonePanel(
                            isLoading: $isLoading,
                            isAgreementChecked: $isAgreementChecked,
                            showPrivacySheet: $showPrivacySheet,
                            showTermsSheet: $showTermsSheet,
                            handleAuth: handleAuth
                        )
                    } else {
                        OverseasLoginCardView()
                            .id(Localized.currentLanguage)
                    }
                    AuthOAuthPanel(
                        isLoading: $isLoading,
                        isAgreementChecked: $isAgreementChecked,
                        errorMessage: $errorMessage,
                        handleThirdPartyLogin: handleThirdPartyLogin
                    )
                    AuthGuestSection()
                }
                .frame(maxWidth: DesignTokens.Metrics.authFormWidth)
                .padding(DesignTokens.Spacing.wide)
            }
            .frame(maxWidth: .infinity)
        }
    }
    .policySheet(isPresented: $showPrivacySheet, title: L10n.Auth.privacyPolicyTitle, content: L10n.Auth.privacyPolicyContent)
    .policySheet(isPresented: $showTermsSheet, title: L10n.Auth.termsOfServiceTitle, content: L10n.Auth.termsOfServiceContent)
}
```

> 注：`mobileLoginLayout` 保留原 `body` 的 `.policySheet` 链。两布局均保留政策弹窗。

- [ ] **Step 3: 构建验证**

Run: `make ios && make mac`
Expected: 双平台 BUILD SUCCEEDED

- [ ] **Step 4: 单测**

新增 `Tests/Unit/Auth/MacAuthViewLayoutTests.swift`：mock `interfaceIdiom = .mac` 时 `macLoginLayout` 分支生效（用环境注入 `\.interfaceIdiom`），iOS 分支走 `mobileLoginLayout`；登录逻辑（`handleAuth`/`performLogin`）不变。

- [ ] **Step 5: Commit**

```bash
git add Sources/Features/System/Auth/View/AuthView.swift Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Metrics.swift Tests/Unit/Auth/MacAuthViewLayoutTests.swift
git commit -m "feat(mac): AuthView 运行时 Trait 桌面化登录页布局"
```

---

### 任务 5：Settings scene + MacSettingsView

**Files:**
- Create: `Sources/Platforms/macOS/Scenes/MacSettingsView.swift`
- Modify: `Sources/Features/System/Settings/View/System/SettingsView.swift`（Mac 分支移除 doneButton）

**Interfaces:**
- Consumes: `SettingsView`（`.mac` 分支 `SettingsView.swift:108-125`）；`router`。
- Produces: `MacSettingsView`（View，复用 `SettingsView`）。

- [ ] **Step 1: 修改 `SettingsView` Mac 分支移除 doneButton**

`SettingsView.swift:273-277` 的 `detailColumn` 内嵌 doneButton。Mac 分支（`idiom == .mac`）不显示"完成"按钮，原生 Settings 由系统关闭。用条件渲染：

```swift
// detailColumn(for:router:) 内 toolbar 改为：仅非 Mac 平台显示 doneButton
.toolbar {
    if !(idiom == .mac || idiom == .macCatalyst) {
        ToolbarItem(placement: .confirmationAction) {
            doneButton(router: router)
        }
    }
}
```

> 注：需确认 `detailColumn` 方法可访问 `idiom`（同 struct 内可访问 `@Environment`）。

- [ ] **Step 2: 创建 `MacSettingsView.swift`**

```swift
//
//  MacSettingsView.swift
//  ZhiYu
//
//  系统层级：[L3] 应用层
//  核心职责：macOS 原生设置，复用 SettingsView 的 .mac 分支。
//
import SwiftUI

/// macOS 原生设置：复用 SettingsView
struct MacSettingsView: View {
    var body: some View {
        SettingsView()
    }
}
```

- [ ] **Step 3: 补全 `MacSceneBuilder.settings()`**

`MacSceneBuilder.swift` 的 `settings()` 已引用 `MacSettingsView()`，此刻可编译。

- [ ] **Step 4: 构建验证**

Run: `make mac`
Expected: BUILD SUCCEEDED；⌘, 打开原生 Settings。

- [ ] **Step 5: 手动验证**

启动 Mac 应用，⌘, 打开设置，确认 7 Section（外观/安全/数据/插件/反馈/关于）侧边栏布局，无"完成"按钮，关闭走系统。

- [ ] **Step 6: Commit**

```bash
git add Sources/Platforms/macOS/Scenes/MacSettingsView.swift Sources/Features/System/Settings/View/System/SettingsView.swift
git commit -m "feat(mac): 原生 Settings scene + MacSettingsView 复用 SettingsView"
```

---

### 任务 6：UserProfileMenu Mac 化 + 辅助窗口入口

**Files:**
- Modify: `Sources/Shared/UIComponents/Menus/UserProfileMenu.swift`

**Interfaces:**
- Consumes: `@Environment(\.openWindow)`；`authSession`；`SettingsLink`。
- Produces: `UserProfileMenu` 的 macOS 分支（SettingsLink + openWindow）。

- [ ] **Step 1: UserProfileMenu 增加 macOS 分支**

`UserProfileMenu.swift:43-123` 现有 `#if os(watchOS)`/`#else` 分支。增加 macOS 分支：

```swift
#if os(macOS)
// macOS：设置走原生 SettingsLink，其余走 openWindow 辅助窗口
@Environment(\.openWindow) private var openWindow

// body 内
#if os(macOS)
Menu {
    Button {
        HapticFeedback.shared.trigger(.selection)
        openWindow(id: "profile")
    } label: {
        Label(authService.currentUser?.name ?? L10n.Auth.profileAndQuota, systemImage: "person.crop.circle.fill")
    }
    Divider()
    SettingsLink {
        Label(L10n.Common.settings, systemImage: "gearshape.fill")
    }
    .accessibilityIdentifier("settingsMenuButton")
    Button {
        openWindow(id: "plan")
    } label: {
        Label(L10n.Auth.subscription, systemImage: "creditcard.fill")
    }
    Button {
        openWindow(id: "plugins")
    } label: {
        Label(L10n.Plugin.title, systemImage: "puzzlepiece.extension.fill")
    }
    Divider()
    Button(role: .destructive) {
        authService.logout()
    } label: {
        Label(L10n.Common.logout, systemImage: DesignTokens.Icons.logout)
    }
    .accessibilityIdentifier("logoutButton")
} label: {
    profileLabel
}
.buttonStyle(.plain)
.accessibilityIdentifier("userProfileMenuButton")
#else
// 现有 iOS Menu
#endif
```

> 注：`UserProfileMenu` 属 Shared 层，允许单点 `#if os(macOS)`（符合规范）。`profile`/`plan`/`plugins` 窗口 id 须与 `MacSceneBuilder.windows()` 一致。

- [ ] **Step 2: 辅助窗口登录态守卫**

`MacSceneBuilder.windows()` 的辅助窗口仅在登录/游客状态可用。在 `UserProfileMenu` 的 macOS 分支按钮 action 中加守卫：

```swift
guard authSession.isLoggedIn || authSession.isGuest else { return }
```

- [ ] **Step 3: 构建验证**

Run: `make mac && make ios`
Expected: 双平台 BUILD SUCCEEDED

- [ ] **Step 4: 单测**

新增 `Tests/Unit/App/MacWindowSceneTests.swift`：验证辅助窗口登录态守卫逻辑（未登录不触发 `openWindow`）。iOS/watch 分支测试不破坏。

- [ ] **Step 5: Commit**

```bash
git add Sources/Shared/UIComponents/Menus/UserProfileMenu.swift Tests/Unit/App/MacWindowSceneTests.swift
git commit -m "feat(mac): UserProfileMenu Mac 化（SettingsLink + openWindow）+ 辅助窗口登录态守卫"
```

---

### 任务 7：完整菜单栏 + 侧边栏宽度 Token

**Files:**
- Modify: `Sources/Platforms/macOS/Scenes/MacMenuCommands.swift`
- Modify: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Metrics.swift`（新增 macSidebarWidth）

**Interfaces:**
- Consumes: `Notification.Name.toggleSidebar`；`L10n.Sidebar.toggle`；`L10n.Notebook.openHub`。
- Produces: 完整 `MacMenuCommands`（查看/窗口/帮助）；`DesignTokens.Metrics.macSidebarWidth`。

- [ ] **Step 1: 新增侧边栏宽度 Token**

`DesignTokens+Metrics.swift` 追加：

```swift
/// Mac 侧边栏宽度 (260pt)
public static let macSidebarWidth: CGFloat = 260
```

- [ ] **Step 2: 补全 MacMenuCommands**

`MacMenuCommands.swift` 增加查看（侧边栏切换）/窗口（笔记本中心）/帮助命令：

```swift
var body: some Commands {
    CommandGroup(replacing: .newItem) {
        Button(L10n.Creation.newPage) { NotificationCenter.default.post(name: .createNewPage, object: nil) }
            .keyboardShortcut("n", modifiers: .command)
    }
    CommandGroup(after: .toolbar) {
        Button(L10n.Sidebar.toggle) { NotificationCenter.default.post(name: .toggleSidebar, object: nil) }
            .keyboardShortcut("s", modifiers: [.command, .control])
    }
    CommandGroup(after: .windowArrangement) {
        Button(L10n.Notebook.openHub) { @Environment(\.openWindow) ... openWindow(id: "notebook-hub") }
    }
    CommandGroup(replacing: .help) {
        Link(L10n.Common.help, destination: URL(string: "https://izhiyu.top")!)
    }
}
```

> 注：`L10n.Sidebar.toggle`/`L10n.Notebook.openHub` 需在 `L10n+Sidebar.swift`/`L10n+Knowledge.swift` 注册并映射 `.xcstrings`。

- [ ] **Step 3: 侧边栏宽度应用到 MacMainWindow**

`MacMainWindow` 或 `AdaptiveSidebarView` 在 Mac 分支使用 `DesignTokens.Metrics.macSidebarWidth`（对齐现有 `.mac` 分支宽度逻辑，仅当现有宽度非此值时替换）。

- [ ] **Step 4: 构建验证**

Run: `make mac`
Expected: BUILD SUCCEEDED；菜单栏含查看/窗口/帮助。

- [ ] **Step 5: Commit**

```bash
git add Sources/Platforms/macOS/Scenes/MacMenuCommands.swift Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Metrics.swift Sources/Localization/Extensions/L10n+Sidebar.swift Sources/Localization/Extensions/L10n+Knowledge.swift Sources/Localization/Catalogs/Localizable.xcstrings
git commit -m "feat(mac): 完整菜单栏 + 侧边栏宽度 Token"
```

---

### 任务 8：移除 macOS 分支 6 个弹窗入口 + AISettings 并入

**Files:**
- Modify: `Sources/App/Scenes/ContentView.swift`（macOS 分支移除 6 个 `appFullScreenCover`）
- Modify: `Sources/App/Navigation/Router.swift`（macOS 分支废弃对应 sheet 状态）

**Interfaces:**
- Consumes: `router.isShowingSettingsSheet`/`isShowingAISettingsSheet`/`isShowingProfileSheet`/`isShowingPlanSheet`/`isShowingPluginsSheet`/`isShowingAboutSheet`。
- Produces: macOS 分支不再呈现 6 个弹窗；`Router` 的 macOS 分支对应状态禁用。

- [ ] **Step 1: ContentView macOS 分支移除 6 个弹窗**

`ContentView.swift:92-146` 的 6 个 `appFullScreenCover` 在 macOS 分支包裹 `#if !os(macOS)`（iOS/watch 保留）：

```swift
#if !os(macOS)
.appFullScreenCover(isPresented: $router.isShowingSettingsSheet) { SettingsView() ... }
.appFullScreenCover(isPresented: $router.isShowingAISettingsSheet) { ... }
.appFullScreenCover(isPresented: $router.isShowingProfileSheet) { ... }
.appFullScreenCover(isPresented: $router.isShowingPlanSheet) { ... }
.appFullScreenCover(isPresented: $router.isShowingPluginsSheet) { ... }
.appFullScreenCover(isPresented: $router.isShowingAboutSheet) { ... }
#endif
```

> 注：保留 `globalOverlaySheets()`（CreateSheet/PerfDashboard/Medal/CoachMark）在 Mac 上。

- [ ] **Step 2: AISettings 并入 Settings**

将 `AISettingsView` 内容并入 `MacSettingsView`（新增 AI Section 或在现有 Section 内嵌入 `AISettingsView`）。具体：在 `SettingsView` 的 `SettingsSection` 增加 `.ai` case 或嵌入 `AISettingsView` 到 `dataManagementSection` 下方。选择影响最小方案：`MacSettingsView` 内 `SettingsView` 之上额外 `.tabItem`/Section 展示 `AISettingsView`。

- [ ] **Step 3: Router macOS 分支禁用 sheet 状态**

`Router.swift` 的 `isShowingSettingsSheet` 等 6 个状态在 macOS 分支不驱动弹窗（ContentView 已移除引用），无需删除（iOS 保留），仅确保 macOS 分支无残留弹窗。

- [ ] **Step 4: 构建验证**

Run: `make mac && make ios && make test-unit`
Expected: BUILD SUCCEEDED；单测通过（iOS sheet 路径不变）。

- [ ] **Step 5: UI 测试回归**

Run: `make test-ui`（确认 `SettingsUITests`/`AISettingsTabSwitchingUITests` 不回归——它们走 iOS Tab 栏，不受 Mac 分支影响）。

- [ ] **Step 6: Commit**

```bash
git add Sources/App/Scenes/ContentView.swift Sources/App/Navigation/Router.swift
git commit -m "refactor(mac): 移除 macOS 分支 6 个弹窗入口，接入原生场景"
```

---

### 任务 9：平台宏收缩审计

**Files:**
- Modify: `Tools/ios/check-code-platform-macros.py`（或新增 `Tools/ios/audit-platform-macro-distribution.py`）
- Modify: 依据审计结果收缩 Shared/App/Infrastructure 层不合理散落

**Interfaces:**
- Consumes: `PLATFORM_PROTOCOL_ARCHITECTURE.md` 规范（宏允许层级、PlatformRegistrar/PlatformModifiers/CrossPlatform 模式）。
- Produces: 宏分布审计脚本 + 收缩后的宏收敛。

- [ ] **Step 1: 审计现状基线**

```bash
grep -rn "#if os(\|#elseif os(\|#if targetEnvironment" Sources/ --include="*.swift" | sed 's/:[0-9]*:.*//' | sort | uniq -c | sort -rn
```

确认：Domain 0、Features 0（非平台宏）、Shared/App/Infrastructure 散落清单。

- [ ] **Step 2: 增强/新增审计门禁**

在 `Tools/ios/` 新增 `audit-platform-macro-distribution.py`，扫描 Shared/App/Infrastructure 层宏，标记：
- 可收敛到 `Platforms/Adaptor`（CrossPlatform/PlatformTraits）的重复平台 API 访问
- 应封装为 `PlatformModifiers` 的裸散落
- 应走 `PlatformRegistrar` 的平台服务宏

输出违规清单 + 退出码。接入 `Makefile` 的 `audit` 目标（或作为独立检查）。

- [ ] **Step 3: 收缩不合理散落**

依据审计结果，对可抽象点收敛：
- 重复 `UIScreen`/`UIApplication` 场景获取 → 收敛到 `CrossPlatform.AppScreen`
- 重复 `UIView`/`NSView` 桥接 → 收敛到 `PlatformViewBridge`
- 平台服务宏 → 走 `PlatformRegistrar`

**原则**：视图组件平台实现（`PlatformModifiers` 已语义化封装，如表 2.2 允许）不强改；仅收敛明显重复/可抽象到公共桥接的点。

- [ ] **Step 4: 验证**

Run: `make audit && make ios && make mac`
Expected: 审计通过 + 双平台编译通过。

- [ ] **Step 5: Commit**

```bash
git add Tools/ios/audit-platform-macro-distribution.py Makefile <收缩涉及的文件>
git commit -m "chore(arch): 平台宏分布审计 + 收敛不合理散落"
```

---

### 任务 10：视觉打磨 + CommandPalette 快捷键（可选）+ 插件 fileImporter 验证

**Files:**
- Modify: `Sources/Platforms/macOS/Scenes/MacMenuCommands.swift`（CommandPalette 快捷键，可选）
- 验证: `Sources/Features/System/Settings/View/Plugins/PluginCenterView.swift`

**Interfaces:**
- Consumes: `showCommandPalette`（`ContentView.swift:31`）；`PluginCenterView.fileImporter`（`:71`）。

- [ ] **Step 1: CommandPalette 快捷键（可选）**

将 `showCommandPalette` 提升到共享状态（`Router` 或全局 @Observable），`MacMenuCommands` 加 ⌘P：

```swift
Button(L10n.Search.commandPalette) { router.showCommandPalette.toggle() }
    .keyboardShortcut("p", modifiers: .command)
```

> 注：`showCommandPalette` 当前是 `ContentView` 的 `@State`，需迁移到 `Router` 或共享 Store 才能被菜单命令访问。若迁移成本高，本任务可跳过（标注可选）。

- [ ] **Step 2: 插件 fileImporter 验证**

`PluginCenterView` 迁移到 `Window` scene 后，手动验证插件安装 fileImporter 可用（SwiftUI `.sheet`+`.fileImporter` 支持窗口呈现）。

- [ ] **Step 3: 视觉打磨**

Mac 材质（`.sidebar`/`.ultraThinMaterial`）、工具栏 `.primaryAction` placement、列表样式 `.inset`，均引用 DesignSystem Token。

- [ ] **Step 4: 构建验证**

Run: `make mac`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Sources/Platforms/macOS/Scenes/MacMenuCommands.swift Sources/App/Navigation/Router.swift
git commit -m "feat(mac): CommandPalette 快捷键 + 视觉打磨"
```

---

### 任务 11：测试用例更新 + 文档更新

**Files:**
- Modify: `Tests/UI/SettingsUITests.swift`、`Tests/UI/AISettingsTabSwitchingUITests.swift`、`Tests/UI/ZhiYuUITests.swift`（macOS 场景断言）
- Modify: 文档（见下）

**Interfaces:**
- Consumes: 任务 1-10 全部产出。

- [ ] **Step 1: 单元测试回归**

Run: `make test-unit`
Expected: 全过（任务 1/2/4/6 新增的单测 + 既有测试）。

- [ ] **Step 2: UI 测试 Mac 场景**

`Tests/UI/SettingsUITests.swift` 新增 macOS 场景：⌘, 打开 Settings、Section 切换。`AISettingsTabSwitchingUITests` 验证 AI 设置并入 Settings scene。`ZhiYuUITests` 验证登录→主界面经 `macLoginLayout` 后不变。

- [ ] **Step 3: 文档更新**

| 文档 | 更新点 |
|------|--------|
| `Docs/Architecture/HIGH_LEVEL_DESIGN.md` | `AppSceneBuilder` 场景分发点 + 多窗口 |
| `Docs/Architecture/PLATFORM_PROTOCOL_ARCHITECTURE.md` | `AppSceneBuilder` 分发示例 + `UserProfileMenu` Mac 化 |
| `Docs/Guides/config-conventions.md` | `Platforms/macOS/Scenes/` 目录规范 |
| `Docs/Design/UI_COMPONENTS.md` | Mac 原生组件（Settings/辅助窗口/菜单） |
| `Docs/Requirements/FEATURE_LIST.md` | Mac 原生特性实现状态 |
| `AGENTS.md` | 场景结构 + 文件布局 |

- [ ] **Step 4: 全量验证**

Run: `make ios && make mac && make watch && make test-unit && make audit`
Expected: 三平台编译 + 单测 + 审计全过（Gatekeeper 全绿）。

- [ ] **Step 5: Commit**

```bash
git add Tests/UI/SettingsUITests.swift Tests/UI/AISettingsTabSwitchingUITests.swift Tests/UI/ZhiYuUITests.swift Docs/Architecture/HIGH_LEVEL_DESIGN.md Docs/Architecture/PLATFORM_PROTOCOL_ARCHITECTURE.md Docs/Guides/config-conventions.md Docs/Design/UI_COMPONENTS.md Docs/Requirements/FEATURE_LIST.md AGENTS.md
git commit -m "docs: Mac 原生化测试用例与文档更新"
```

---

## Self-Review

**Spec 覆盖对照**（设计文档 `2026-11-19-mac-native-ui-redesign-design.md`）：
- 架构（AppSceneBuilder/MacSceneBuilder/iOSSceneBuilder）→ 任务 1、2
- 环境注入内聚 → 任务 1
- 登录页 trait 桌面化 → 任务 4
- MacMainWindow 组装（复用 ContentView）→ 任务 2
- 多窗口分层（Settings/Profile/Plan/Plugins/About）→ 任务 2、6、8
- Settings 7 Section → 任务 5
- 菜单栏 → 任务 3、7
- 辅助窗口登录态守卫 → 任务 6
- 无障碍/CommandPalette/fileImporter → 任务 10
- 平台宏收缩审计 → 任务 9
- 测试用例 + 文档更新 → 任务 11

**占位符**：无 TBD/TODO；每个任务含具体文件、代码、命令。CommandPalette 标注可选。

**类型一致性**：`AppSceneBuilder.root(...)`、`MacSceneBuilder.main/settings/windows()`、`SceneEnvironmentInjection`、`MacMainWindow`、`MacSettingsView`、`MacMenuCommands` 命名跨任务一致；窗口 id（profile/plan/plugins/notebook-hub）任务 2/6/7 一致。