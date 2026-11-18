# 实施计划：Google 认证统一为 AppAuth（iOS + macOS）

> 关联设计：`Docs/Architecture/CROSS_PLATFORM_EXPANSION.md` §6.3 任务 0（统一 A 全平台 AppAuth）
> 日期：2026-11-18 · 模块：C 端（iOS + macOS）

## 目标

将 Google 登录由「GIDSignIn SDK（仅支持 iOS/macCatalyst/tvOS）」统一迁移到 **AppAuth-iOS**（`OIDAuthorizationService` + PKCE），使 iOS 与 macOS 共享一套实现，消除原生 macOS 认证阻塞项。**上层 `GoogleSignInProviding` 协议与后端 idToken 契约完全不变**。

## 背景与决策

- GoogleSignIn-iOS xcframework 不支持原生 macOS（AppKit）；`GoogleAuthStrategy.signIn(presenting: UIViewController)` 依赖 UIKit，原生 macOS 无 `UIViewController`。
- 本地 opensrc 已克隆 **AppAuth-iOS v3.0.0**（`platforms` 含 `.macOS(.v12)`，原生支持 AppKit），是 Google 官方文档推荐的 iOS/macOS OIDC 客户端。
- 后端契约：客户端只产出 `idToken`，验签由后端完成（多 audience 校验）。AppAuth 通过 authorization code + PKCE 交换同样产出 `idToken`，**与 GIDSignIn 输出一致**，后端零改动。
- 决策：统一 A——iOS/macOS 全平台 AppAuth，随后从 `project.yml` 移除 `GoogleSignIn` 及其传递依赖。

## 前置

- 后端 Google 多端 client id 受管配置 + 多 audience 验签已上线（`ios-client-id` 已配置，含 iOS、macOS 桌面顺序）。
- 本任务所有外部库改动遵循项目离线治理：克隆到 `${OPENSRC_ROOT}` + 登记 + template + `xcodegen generate`（禁止直接改生成物 `project.yml`）。
- AppAuth-iOS v3.0.0 已在 `${OPENSRC_ROOT}/AppAuth-iOS`（当前为 GoogleSignIn 传递依赖），需升级为直接依赖并在 `Config/opensource_dependencies.yml` 更新 purpose。

## 技术要点

- **AppAuth 核心流程**：`OIDAuthState` + `OIDAuthorizationService`。构造 `OIDAuthorizationRequest`（`configuration` 由 `OIDServiceConfiguration(authorizationEndpoint:tokenEndpoint:)` 或 `OIDAuthorizationService.discoverServiceConfiguration(forIssuer:)` 提供），`OIDAuthorizationService.performAuthorizationRequest(...)` 会拉起 `ASWebAuthenticationSession`，回调后交换 `idToken`（`OIDTokenResponse.idToken`）。
- **回调接线**：AppAuth 在 iOS 通过 `OIDAuthState.authStateByPresentingAuthorizationRequest` 回调 `URL`，由 `AppWindowSceneDelegate.scene(_:openURLContexts:)` 转发给 `OIDAuthState` 状态管理器的回调。原生 macOS 用 `ASWebAuthenticationPresentationContextProviding` 提供 `NSWindow` 作为锚点（项目 `GitHubAuthStrategy` 已有 `PlatformPresentationAnchor` 参考）。
- **平台锚点**：iOS 用 `UIWindow`，macOS 用 `NSWindow`。复用现有 `CrossPlatform.swift` 的 `PlatformPresentationAnchor`。
- **clientID 解析**：沿用现有 `resolveConfiguredClientID`（Info.plist `GIDClientID` 键）探针逻辑；AppAuth 需要 `clientID` + `redirectURL`（反向 scheme `com.googleusercontent.apps.<client-id>`）。Google 授权服务器的 `authorizationEndpoint`/`tokenEndpoint` 可写死为 Google 官方端点或走 discovery。
- **状态持久化**：GIDSignIn 自动保存登录态；AppAuth 用 `OIDAuthState` + 持久化 `authStateByPresentingAuthorizationRequest` 的 refresh token，可暂不实现 token 刷新（当前后端依赖 `idToken` 每次登录换取，登出清理）。

## 任务清单

### T1 依赖改造（AppAuth 升级为直接依赖）
- [x] 确认 `${OPENSRC_ROOT}/AppAuth-iOS` 版本为 v3.0.0，`Package.swift` platforms 含 `.macOS(.v12)`。
- [x] `Config/opensource_dependencies.yml` 中 AppAuth-iOS 的 `purpose` 由「GoogleSignIn 传递依赖」更新为「Google 认证直接依赖（iOS/macOS 统一）」；确认其本地 path 补丁仅含路径引入、无 GoogleSignIn 专属排除。
- [x] `Config/project.yml.template` 的 `packages` 中显式声明 `AppAuth`（`path: ${OPENSRC_ROOT}/AppAuth-iOS`），并在 `BaseAppTemplate.dependencies` 以 `- package: AppAuth` + `product: AppAuth` 引入。
- [x] `xcodegen generate` 重新生成 `project.yml`，`make gen` 验证（AppAuth-iOS 依赖解析成功）。

### T2 新增 AppAuth 实现（`GoogleAuthStrategy` AppAuth 分支）
- [x] 新建 `Sources/Features/System/Auth/Strategy/AppAuthGoogleProvider.swift`：实现 `GoogleSignInProviding`，用 `OIDAuthState.authState(byPresenting:)` + PKCE(S256) 产出 `GoogleSignInCredentialData(idToken:...)`，iOS 取 `UIWindow.rootViewController`、macOS 用 `NSWindow` 呈现。
- [x] `GoogleAuthStrategy.acquireCredentials()` 保留 `resolveConfiguredClientID` 探针；协议签名改为跨平台锚点 `ASPresentationAnchor`，不再依赖 `UIViewController`，同一策略可编译于 iOS + macOS。
- [x] 新增 `FeatureConstants.GoogleConfig` 常量：`authorizationEndpoint`、`tokenEndpoint`、`redirectSchemePrefix`、`redirectPathSuffix`、`oidcScopes`（遵循去魔鬼化，不硬编码 URL 字面量）。
- [x] 复用 `PlatformPresentationAnchor`（`CrossPlatform.swift`）解析 iOS `UIWindow` / macOS `NSWindow` 锚点（新增 AppKit 分支）。

### T3 回调接线改造
- [x] `AppWindowSceneDelegate.scene(_:openURLContexts:)` 移除 `GIDSignIn.sharedInstance.handle(url:)` 转发（AppAuth 经 `ASWebAuthenticationSession` 自动处理授权回跳，无需手动 URL 转发）。
- [x] 确认 Info.plist URL Types 含 Google 反向 scheme（`com.googleusercontent.apps.<client-id>`），iOS/macOS 各自配置。

### T4 移除 GIDSignIn 依赖
- [x] `GoogleAuthStrategy` / `GoogleSignInProviding` 中的 `import GoogleSignIn` 与 `GIDSignInProvider` 删除，改由 `AppAuthGoogleProvider` 满足 `GoogleSignInProviding`。
- [x] `Config/project.yml.template` 移除 `GoogleSignIn` package 依赖及 `Config/opensource_dependencies.yml` 中 GoogleSignIn-iOS 条目及其专属传递依赖（`GTMAppAuth`/`GoogleUtilities`/`gtm-session-fetcher`/`interop-ios-for-google-sdks`/`ocmock`/`promises`/`app-check`）。
- [x] `xcodegen generate` + `make ios && make mac && make watch` 编译通过。

### T5 测试
- [x] 更新单元测试：`GoogleAuthStrategyTests` 的 `MockGoogleSignInProvider` 签名改 `ASPresentationAnchor`，构造参数 `rootViewControllerProvider` → `anchorProvider`，覆盖各错误分支。
- [x] 保留现有 `GoogleAuthStrategy` 探针纯函数测试（`resolveConfiguredClientID` 各分支）。
- [x] GoogleAuthStrategyTests 10 项单测全绿（iOS 模拟器）。真实 Google 账号端到端登录留待真机回归（AC-1/AC-2）。

### T6 文档与验收
- [x] 更新 `Docs/Architecture/AUTH_ARCHITECTURE.md` §2.4（GoogleSignIn → AppAuth，回调接线、clientID 配置、平台锚点）。
- [x] 更新 `Docs/Architecture/CROSS_PLATFORM_EXPANSION.md` §6.3 任务 0 状态（完成 AppAuth 迁移）。
- [x] 记录 ADR-014：Google 认证统一 AppAuth（替代 GIDSignIn，理由：原生 macOS 支持、iOS/macOS 单实现）。
- [x] `make ios && make mac && make watch` 三平台编译通过 + GoogleAuthStrategyTests 单测通过。

## 验收标准（AC）

1. iOS Google 登录可用真实 Google 账号完成，idToken 可被后端验签。
2. macOS（原生 target）Google 登录可用，无 `UIViewController` 依赖崩溃。
3. `GoogleSignInProviding` 协议签名不变；上层 `GoogleAuthStrategy` 调用方零改动。
4. `project.yml` / `opensource_dependencies.yml` 无 `GoogleSignIn` 残留（除非被 watch 等其它模块引用，需逐一确认）。
5. 三平台编译 + 单测通过。

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| AppAuth 的 PKCE + token 交换实现复杂、错误分支多 | 对照官方示例 `OIDAuthorizationService.performAuthorizationRequest`，用 `OIDAuthState` 状态机管理回调；错误映射复用现有 `AppError.auth` |
| iOS 生产端 GIDSignIn 替换引入回归 | T5 增加 iOS 模拟器真实登录集成测试 + `GoogleAuthStrategy` 全分支单测；iOS 与 macOS 改动合并为一个 MR，重点回归 |
| AppAuth 本地补丁含 GoogleSignIn 专属排除 | T1 先审 `Package.swift` 补丁，确认与传递依赖场景解耦，必要时改补丁 |
| macOS 原生 `ASWebAuthenticationSession` 锚点差异 | 复用 `PlatformPresentationAnchor`，T2 明确 iOS `UIWindow` / macOS `NSWindow` 分支 |