# Google Sign-In SDK 接入方案

> 日期：2026-10-17
> 模块：C 端（iOS app）
> 依赖：后端 Google OAuth 多端 client id 受管配置 + 多 audience 验签（已上线）

## 一、背景与目标

C 端 iOS 需支持 Google 账号登录：拉起 GoogleSignIn SDK 获取 idToken → 交给后端验签（后端已支持逗号分隔多 audience，命中 iOS 或 macOS 桌面任一 client id 即通过）→ 建号/绑定。

**方案 A（已决策）**：Info.plist 配标准键 `GIDClientID`，SDK 自动读取；不依赖 AppConfig。无需自定义键名（`GIDClientID` 即 SDK 默认标准键，`clientIDKey` 为 SDK 内部 UFPCore 私有符号，应用不可引用，故用标准键即可）。

**目标**：
1. 通过 SPM 接入 `GoogleSignIn-iOS`（离线优先，遵循本项目开源库治理规范）。
2. 补齐 `GIDClientID` 与 Google 反向 URL scheme。
3. 实现缺失常量 `FeatureConstants.GoogleConfig`。
4. 接入 `GIDSignIn` 回调处理。
5. 补齐/更新测试（以发现问题为目标），并在模拟器验证真实登录链路。

## 二、现状分析

### 已就绪
| 项 | 位置 | 状态 |
|---|---|---|
| Google 认证策略主流程 | `Sources/Features/System/Auth/Strategy/GoogleAuthStrategy.swift` | 已实现 `GIDSignIn.sharedInstance.signIn(withPresenting:)`，因 SDK 未接入 `canImport(GoogleSignIn)=false`，该分支当前**不编译** |
| Mock 常量 | `Sources/Features/FeatureConstants+Common.swift` | `MockData.mockGoogleCode`、`MockData.googleMockUser`、`ModuleName.googleAuthStrategy` 均已定义 |
| 现有单元测试 | `Tests/Unit/Features/System/GoogleAuthStrategyTests.swift` | 基于 DEBUG mock 降级，未覆盖 SDK 真实分支 |
| 后端验签 | 后端服务 | 多 audience 校验已上线，`ios-client-id` 已受管配置 |

### 缺失/需改动
| 项 | 现状 | 需做 |
|---|---|---|
| SDK 依赖 | `project.yml.template`/`opensource_dependencies.yml` 无 GoogleSignIn；`${OPENSRC_ROOT}` 下未克隆 | 克隆 + 登记 + template 声明 + xcodegen 重新生成 |
| Info.plist | `Sources/Info.plist` 仅有 `zhiyu` scheme，无 `GIDClientID` | 加 `GIDClientID` + Google 反向 scheme |
| 常量 | `FeatureConstants.GoogleConfig` **未定义**（引用在 `#if canImport` 内，SDK 未接入故未编译报错） | 实现 `clientIDKey`/`placeholderClientID` |
| 回调 | `Sources/App/Lifecycle/AppWindowSceneDelegate.swift` 无 `openURLContexts` | 加 `GIDSignIn.handle(url)` 分发 |
| 测试 | 未覆盖真实分支 | 新增可测性注入 + 用例 |

## 三、变更范围

### 3.1 SPM 接入（离线优先）
遵循项目离线治理：所有外部开源库克隆到 `${OPENSRC_ROOT}`（`/Users/constantine/Documents/work/code/opensrc/swift`），并经 `Config/opensource_dependencies.yml` 登记 + `Config/project.yml.template` 声明，最后由 `source Config/.env.local && xcodegen generate` 生成 `project.yml`。

1. **克隆**：`git clone https://github.com/google/GoogleSignIn-iOS` → `${OPENSRC_ROOT}/GoogleSignIn-iOS`，并锁定稳定 tag（`version` 字段，克隆后确认）。
2. **登记** `Config/opensource_dependencies.yml`：
   ```yaml
   - name: GoogleSignIn-iOS
     upstream: "https://github.com/google/GoogleSignIn-iOS.git"
     version: "<锁定 tag>"
     integration: project_yml_path
     license: Apache-2.0
     purpose: "Google 账号登录 SDK（GIDSignIn 拉取 idToken）"
   ```
3. **模板** `Config/project.yml.template` 外部开源库段加：
   ```yaml
   # 第三方登录
   GoogleSignIn:
     path: ${OPENSRC_ROOT}/GoogleSignIn-iOS
   ```
4. **target dependencies**：iOS app target 与 mac target 的 `dependencies` 各加 `- package: GoogleSignIn`（product 默认同名 `GoogleSignIn`）。watchOS target 不接（GoogleSignIn 不支持 watchOS）。
5. **重新生成**：`source Config/.env.local && xcodegen generate`。

> 注：`project.yml` 是生成物，禁止直接编辑；只改 `Config/project.yml.template`。

### 3.2 Info.plist（iOS `Sources/Info.plist`）
```xml
<key>GIDClientID</key>
<string>867200253941-58jgrffss6auja38efeur36d6e96s4lv.apps.googleusercontent.com</string>
```
`CFBundleURLTypes` 数组新增一项：
```xml
<dict>
    <key>CFBundleURLName</key>
    <string>com.zhiyu.app.google</string>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>com.googleusercontent.apps.867200253941-58jgrffss6auja38efeur36d6e96s4lv</string>
    </array>
</dict>
```
> 说明：`Sources/Info.plist` 由 CI 脚本注入版本字段（`BUILD_FLAVOR`/`GIT_SHORT_HASH`/版本号），注入脚本只覆盖版本相关键，**不会移除** `GIDClientID`/URL scheme，故可直接编辑该文件。client id 非敏感凭据（可明文，与 `client-id` 同性质）。

### 3.3 常量：`FeatureConstants.GoogleConfig`
在 `Sources/Features/FeatureConstants+Auth.swift` 的 `extension FeatureConstants` 内新增：
```swift
// MARK: - Google SDK 配置 (Google Sign-In)
/// GoogleSignIn SDK 的 Info.plist 配置探针常量
enum GoogleConfig {
    /// Info.plist 中 Google 客户端 ID 的标准键名（SDK 默认读取，非自定义键）
    static let clientIDKey = "GIDClientID"
    /// 占位客户端 ID，用于区分「已配置」与「未替换占位」
    static let placeholderClientID = "your-google-client-id"
}
```
> 对齐现有 `GoogleAuthStrategy.swift` 的引用：`FeatureConstants.GoogleConfig.clientIDKey` / `placeholderClientID`。

### 3.4 GIDSignIn 回调
在 `Sources/App/Lifecycle/AppWindowSceneDelegate.swift` 增加：
```swift
import GoogleSignIn

func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
    for context in URLContexts {
        GIDSignIn.sharedInstance.handle(context.url)
    }
}
```
> 项目采用 scene-based 生命周期（`UIApplicationSceneManifest`），URL 回调走 `scene(_:openURLContexts:)`。GitHub 走 `ASWebAuthenticationSession` 自动回调，无需此处理；Google 的 `GIDSignIn` 需手动 `handle(url)`。

## 四、测试策略（以发现问题为目标）

> 原则：测试以暴露真实缺陷为目的，而非凑覆盖率。重点验证配置探针、降级路径、token 提取与回调分发。

### 4.1 可测性改造（方案内架构调整）
`GoogleAuthStrategy` 直接调 `GIDSignIn.sharedInstance`（全局单例），真实分支难单测。引入轻量注入协议：
```swift
@MainActor
protocol GoogleSignInProviding {
    func signIn(presenting: UIViewController) async throws -> GoogleSignInResult
}
```
- 默认实现包装 `GIDSignIn.sharedInstance`。
- `GoogleAuthStrategy` 增加 init 注入（默认用真实实现，不影响调用方）。
- 这样可 mock 返回假 token，验证 idToken 提取、credential 组装、空 token 抛错。

> 权衡：保持 API 稳定（`AuthStrategy` 协议不变），仅策略内部注入。这是低侵入改造，换取真实分支可测。

### 4.2 测试用例清单
| # | 用例 | 断言目标 | 潜在缺陷 |
|---|---|---|---|
| 1 | Info.plist 无 `GIDClientID`（模拟未配置） | 走降级：Debug+测试 → mock；否则抛 -99 | 探针读取路径正确 |
| 2 | `GIDClientID` 为占位值 `your-google-client-id` | 视为未配置，等同 nil | placeholder 检测漏判 |
| 3 | `GIDClientID` 有效值 | 探针通过，进入 signIn 分支 | 误把有效配置当未配置 |
| 4 | mock 注入 `signIn` 返回含 idToken 的结果 | credential.extraInfo["idToken"] 正确透传 | token 提取/键名错 |
| 5 | mock 注入 `signIn` 返回 idToken 为 nil | 抛 token 错误（-2），不崩溃 | 空 token 未处理 |
| 6 | `GIDSignIn.handle(url)` 回调分发 | openURLContexts 逐 URL 调用 handle | 回调未接导致登录后无响应 |
| 7 | `GoogleConfig` 常量 | `clientIDKey == "GIDClientID"`（标准键） | 键名写错 |

### 4.3 预期发现（人工复核重点）
- 若 `placeholderClientID` 与真实 client id 前缀重合 → 误判；需用不冲突占位值。
- 若 SDK 7.x/8.x `signIn(withPresenting:)` 签名与现有代码不符 → 编译期暴露，需按版本适配。
- 若 scene 回调未接 → 登录成功后 app 不回调；用例 6 兜底。

## 五、风险与决策

| 风险/决策 | 说明 | 处置 |
|---|---|---|
| SDK 版本 API 差异 | `signIn(withPresenting:)` 为 7.x+ 新 API | 克隆后按锁定 tag 核对签名；以编译为准 |
| macOS 桌面端 | 本方案聚焦 iOS（验证目标 iPhone 模拟器）。`GoogleSignIn-iOS` 对 macOS/macCatalyst 支持需在锁定版本确认 | 本次不接入 mac target 的运行时（mac target 的 client id 已在后端配置，SDK 接入作为后续项） |
| 单例 mock 难度 | 通过 `GoogleSignInProviding` 注入隔离 | 已纳入 4.1 |
| Info.plist 被 CI 覆盖 | 注入脚本只改版本键 | 不改注入脚本，直接编辑 plist 安全 |
| client id 明文 | 非敏感凭据 | 与现有 `github_oauth_client_id` 同性质，可明文 |

## 六、实施顺序

1. 克隆 `GoogleSignIn-iOS` → 确认稳定 tag → 登记 `opensource_dependencies.yml`。
2. `project.yml.template` 加 package + iOS/mac target deps → `xcodegen generate`。
3. 实现 `FeatureConstants.GoogleConfig`。
4. `AppWindowSceneDelegate` 加 `openURLContexts`。
5. `Sources/Info.plist` 加 `GIDClientID` + URL scheme。
6. 可测性注入 + 更新/新增测试。
7. `xcodebuild` 模拟器构建 → 运行验证真实登录链路。

## 七、验证

- `xcodegen generate` 无告警；`project.yml` 生成 GoogleSignIn 引用。
- 单元测试全绿（含新用例）。
- iPhone 17 Pro 模拟器构建运行，点击 Google 登录 → SDK 拉起授权 → 返回 idToken → 后端验签建号/绑定成功。
- 全库质量门禁（swiftlint / periphery / sonar / 依赖注册审计）通过。