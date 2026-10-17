# 实施计划：Google Sign-In SDK 接入

> 关联设计：`Docs/superpowers/specs/2026-10-17-google-signin-sdk-integration-design.md`
> 日期：2026-10-17 · 模块：C 端（iOS app）

## 目标

将 iOS C 端 Google 登录由「策略代码已写但 SDK 未接入」推进到**可真实登录**：接入 GoogleSignIn SDK、补齐 Info.plist/常量/回调、测试覆盖真实分支，并在模拟器验证 idToken → 后端验签建号/绑定链路。

## 前置

- 后端 Google 多端 client id 受管配置 + 多 audience 验签已上线（`ios-client-id` 已配置）。
- 决策：方案 A（Info.plist 标准键 `GIDClientID`），聚焦 iOS。
- 本任务所有外部库改动遵循项目离线治理：克隆到 `${OPENSRC_ROOT}` + 登记 + template + `xcodegen generate`（禁止直接改生成物 `project.yml`）。

## 任务清单

### T1 依赖接入（GoogleSignIn-iOS，离线优先）
- [ ] 克隆 `https://github.com/google/GoogleSignIn-iOS` → `${OPENSRC_ROOT}/GoogleSignIn-iOS`，锁定稳定 tag。
- [ ] `Config/opensource_dependencies.yml` 登记（`integration: project_yml_path`、`license: Apache-2.0`、version=锁定 tag、purpose）。
- [ ] `Config/project.yml.template` packages 段加 `GoogleSignIn: { path: ${OPENSRC_ROOT}/GoogleSignIn-iOS }`。
- [ ] iOS app target 与 mac target 的 `dependencies` 各加 `- package: GoogleSignIn`（watchOS 不接）。
- [ ] `source Config/.env.local && xcodegen generate` 重新生成 `project.yml`。
- **验证**：`project.yml` 出现 GoogleSignIn 引用；`xcodebuild -list` 无解析错误。

### T2 常量实现（`FeatureConstants.GoogleConfig`）
- [ ] `Sources/Features/FeatureConstants+Auth.swift` 的 `extension FeatureConstants` 新增 `enum GoogleConfig`：
  - `clientIDKey = "GIDClientID"`
  - `placeholderClientID = "your-google-client-id"`
- **验证**：编译通过，消除 `GoogleAuthStrategy` 内对 `FeatureConstants.GoogleConfig.*` 的悬空引用。

### T3 GIDSignIn 回调接入
- [ ] `Sources/App/Lifecycle/AppWindowSceneDelegate.swift`：
  - `import GoogleSignIn`（置于 `#if !os(watchOS)` 内）
  - 新增 `scene(_:openURLContexts:)`，逐 URL 调 `GIDSignIn.sharedInstance.handle(url)`。
- **验证**：编译通过；模拟器登录后 app 能收到回调。

### T4 Info.plist 配置（方案 A）
- [ ] `Sources/Info.plist`：
  - 加 `<key>GIDClientID</key><string>867200253941-58jgrffss6auja38efeur36d6e96s4lv.apps.googleusercontent.com</string>`
  - `CFBundleURLTypes` 追加 `com.zhiyu.app.google` + scheme `com.googleusercontent.apps.867200253941-58jgrffss6auja38efeur36d6e96s4lv`
- **验证**：`plutil -lint Sources/Info.plist` 通过；`plutil -p` 可读到新键。

### T5 可测性改造 + 测试（以发现问题为目标）
- [ ] 新增 `GoogleSignInProviding` 协议（`@MainActor`）+ 默认实现包装 `GIDSignIn.sharedInstance`；`GoogleAuthStrategy` 构造注入。
- [ ] `Tests/Unit/Features/System/GoogleAuthStrategyTests.swift` 更新/新增用例：
  1. Info.plist 无 `GIDClientID` → 降级（Debug+测试 mock；否则 -99）
  2. `GIDClientID` = 占位值 → 视为未配置
  3. `GIDClientID` 有效 → 探针通过进入 signIn 分支
  4. mock 注入返回含 idToken → `extraInfo["idToken"]` 正确透传
  5. mock 注入返回 idToken nil → 抛 token 错误（-2）
  6. `scene(_:openURLContexts:)` 逐 URL 调 `handle`
  7. `GoogleConfig.clientIDKey == "GIDClientID"`
- **验证**：单测全绿。

### T6 文档更新
- [ ] `Docs/Architecture/AUTH_ARCHITECTURE.md`：「二、前端分层架构」补充**第三方登录客户端实现**小节：
  - Google = GoogleSignIn SDK（Info.plist `GIDClientID` + 反向 URL scheme + `scene(_:openURLContexts:)` 回调）
  - GitHub = `ASWebAuthenticationSession`（回调 URL scheme 自动处理，无需 app 级回调）
  - Apple / 微信 / 运营商分别注一句实现方式
- [ ] `AGENTS.md`（C 端）：
  - 「外部依赖」节补 `GoogleSignIn-iOS`（版本 = 锁定 tag）
  - 新增/更新一条「第三方登录实现要点」：`GIDClientID` 走 Info.plist 标准键、回调在 `AppWindowSceneDelegate`、与 GitHub 回调差异
- **验证**：文档与真实实现一致（无「待接入」残留表述）。

### T7 模拟器验证（真实链路）
- [ ] 用 `make` 或 `xcodebuild` 在 iPhone 17 Pro 模拟器构建运行。
- [ ] 点 Google 登录 → SDK 拉起授权 → 返回 idToken → 后端验签 → 建号/绑定成功。
- **验证**：登录成功进入主界面；后端用户表新增 google 身份。

## 验收标准

1. `xcodegen generate` 无告警，`project.yml` 含 GoogleSignIn。
2. 编译通过，`GoogleConfig` 悬空引用消除。
3. 单测全绿（含 T5 的 7 类用例）。
4. 模拟器真实 Google 登录成功，后端验签通过。
5. `AUTH_ARCHITECTURE.md` / `AGENTS.md` 已更新，无「待接入」残留。
6. 全库质量门禁（swiftlint / periphery / sonar / 依赖注册审计 `check-arch-dependency-registry.py`）通过。

## 风险与回滚

- **SDK 版本 API 差异**：`signIn(withPresenting:)` 为 7.x+ 新 API，若锁定 tag 签名不符 → 以编译为准适配。克隆后先确认 tag。
- **单例 mock**：已通过 `GoogleSignInProviding` 注入规避。
- **macOS**：本计划仅 iOS；mac target 的 client id 已在后端配置，SDK 接入为后续项。
- **回滚**：各 T 独立提交；依赖接入（T1）改动集中在 template/yml/生成物，`git checkout` 可整体还原。

## 提交规范

按 C 端 AGENTS.md 约定（`feat:`/`fix:`/`docs:`/`refactor:`），各任务原子提交；scope 参考现有 `feat(auth)` / `docs(arch)` 风格。