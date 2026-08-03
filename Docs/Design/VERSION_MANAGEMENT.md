# 智宇 (ZhiYu) 版本管理规范

> 最后更新: 2026-06-27 (v2.0 — fastlane 薄封装 + Swift 常量防抵赖方案)

---

## 1. 版本号体系

### 1.1 版本字段

| 字段 | 来源 | 写入位置 | 示例 | 说明 |
|------|------|---------|------|------|
| `semVer` | `AppConstants.Version.semVer`（手动维护） | AppConstants.swift → inject → Info.plist | `1.0.0` | 语义化版本号，唯一来源，落代码防抵赖 |
| `CFBundleVersion` | `git rev-list --count HEAD` | Info.plist | `840` | 构建号，提交总数，单调递增 |
| `GIT_SHORT_HASH` | `git rev-parse --short HEAD` | Info.plist + AppConstants.swift | `abc1234` | 短提交哈希，精确追溯 |
| `BUILD_TIMESTAMP` | `date -u` | Info.plist + AppConstants.swift | `2026-06-27T10:44:08Z` | ISO 8601 UTC 构建时间 |

### 1.2 版本展示格式

**关于页面**：`VersionInfoFormatter` 从 `Bundle.main.infoDictionary` 读取，格式：`1.0.0 (840 · abc1234) 2026-06-27T10:44:08Z`

**CI 构建/测试日志**：每次构建和测试首尾打印 `📦 版本: 1.0.0 (build 840) | commit: abc1234 | 构建时间: 2026-06-27T10:44:08Z`

**App Store Connect**：`CFBundleShortVersionString` = `1.0.0`，`CFBundleVersion` = `840`

---

## 2. 架构概览

```
AppConstants.Version.semVer              ← 唯一版本来源（已提交，防抵赖）
        │
        ├── ci-build-pipeline-version-inject.sh            ← CI / fastlane 调用
        │       ├── 读取 semVer
        │       ├── 校验 git tag 一致性（有 tag 时告警）
        │       ├── 写 Info.plist（CFBundleShortVersionString / CFBundleVersion / hash / timestamp）
        │       └── 回写 AppConstants.Version（gitShortHash / buildTimestamp）
        │
        ├── VersionInfoFormatter          ← AboutView 展示
        ├── CI 构建/测试脚本              ← 构建首尾打印
        └── fastlane bump_version         ← 开发便捷工具
```

---

## 3. 日常开发工作流

### 3.1 指定/修改版本号

```bash
fastlane bump_version version:1.1.0
```

等价于手动编辑 `Sources/Core/Base/Constants/AppConstants.swift` 第 381 行的 `semVer`，然后提交。

### 3.2 同步构建信息

```bash
fastlane sync_version
# 或直接调用：
bash Tools/ci/build-pipeline-version-inject.sh Sources/Info.plist
```

此命令将当前版本号、构建号、hash、时间戳写入 Info.plist 和 AppConstants.swift。

### 3.3 版本号管理原则

- **日常开发**：不打 tag，仅通过 `AppConstants.Version.semVer` 指定版本号
- **正式发布**：修改 semVer → 提交 → `git tag -a v1.0.0` → `fastlane sync_version` → 构建
- **一致性校验**：`build-pipeline-version-inject.sh` 在检测到 git tag 时自动校验 tag 与 semVer 一致，不一致则打印 WARNING 但仍以 semVer 为准

---

## 4. 版本注入脚本

### 4.1 脚本路径

`Tools/ci/build-pipeline-version-inject.sh`

### 4.2 用法

```bash
Tools/ci/build-pipeline-version-inject.sh <info_plist_path>
# 典型调用:
bash Tools/ci/build-pipeline-version-inject.sh Sources/Info.plist
```

### 4.3 核心逻辑

1. 从 `Sources/Core/Base/Constants/AppConstants.swift` 提取 `semVer`
2. 校验 git tag 与 semVer 一致性（有 tag 时）
3. `git rev-list --count HEAD` → 构建号
4. `git rev-parse --short HEAD` → 短哈希
5. `date -u` → 构建时间
6. 写入 Info.plist：`CFBundleShortVersionString` / `CFBundleVersion` / `GIT_SHORT_HASH` / `BUILD_TIMESTAMP`
7. 回写 AppConstants.swift：`gitShortHash` / `buildTimestamp`

### 4.4 设计决策

| 决策 | 理由 |
|------|------|
| semVer 源为 Swift 常量 | 防抵赖：版本号落代码，Git 提交可审计；避免 tag 删除/移动导致版本丢失 |
| `PlistBuddy` 而非 `agvtool` | macOS 原生自带，零依赖 |
| Hash 和时间戳双向写入（Info.plist + Swift） | Info.plist 供运行时 `Bundle.main.infoDictionary` 读取；Swift 常量供编译时引用 |
| 构建号用 `git rev-list --count HEAD` | 单调递增，不依赖特定 CI 系统 |
| 无 tag 时不报错 | 日常开发不打 tag 是常态，以 semVer 为准 |

---

## 5. fastlane 版本管理

### 5.1 bump_version

```bash
fastlane bump_version version:1.1.0
```

更新 `AppConstants.Version.semVer`，自动校验格式（纯数字点分）。改完后需手动提交。

### 5.2 sync_version

```bash
fastlane sync_version
```

调用 `build-pipeline-version-inject.sh` 执行完整的版本信息同步。

### 5.3 canary（已有，未改动）

```bash
fastlane canary
```

xcodegen generate → 构建 → 上传 TestFlight Internal。CI 发布流水线使用。

---

## 6. CI 集成

### 6.1 Woodpecker 流水线

```
clone-repo → static-analysis
clone-repo → build-prepare → build-ios → build-macos → build-watchos → test
                 ├─ xcodegen generate
                 ├─ SPM resolve
                 └─ ci-build-pipeline-version-inject.sh     ← 版本注入合并在此步骤
```

测试步骤 (`test-and-verify-coverage`) 首尾打印版本信息。

### 6.2 GitHub Actions

| Stage | inject_version | 说明 |
|-------|:---:|------|
| lint-and-audit | ❌ | 纯静态检查，无需版本信息 |
| test | ✅ | 单元测试前后打印版本 |
| ui-test / ipad-ui-test / mac-catalyst-ui-test | ✅ | UI 测试前后打印版本 |
| multi-platform | ✅ | 多平台编译的 Inject Version step |

### 6.3 本地 pre-push 门禁

已集成 Woodpecker YAML 格式校验（`woodpecker-cli lint`）。版本号不在此处校验。

---

## 7. 发布流程

### 7.1 完整发布步骤

```
1. fastlane bump_version version:1.1.0    # 更新 semVer
2. git add . && git commit                 # 提交版本号变更
3. git tag -a v1.1.0 -m "Release v1.1.0"  # 打 tag（与 semVer 一致）
4. git push --tags                         # 推送 tag
5. CI 自动触发                             # ci-build-pipeline-version-inject.sh 校验通过，构建
6. fastlane canary                         # 上传 TestFlight（CI 自动执行）
7. App Store Connect                       # 提交审核
```

### 7.2 与 ROADMAP 的对应关系

| 阶段 | 版本 | 标签 | 说明 |
|------|------|------|------|
| MVP | 0.x | `v0.x.0` | 内部验证 |
| 阶段一 (当前) | 1.0.x | `v1.0.x` | Swift 6 并发 + 三端 |
| 阶段二 | 1.5.x | `v1.5.x` | 架构拆分 + 85% 覆盖熔断 |
| 阶段三 | 2.0.x | `v2.0.x` | iCloud 同步 + 插件生态 |

---

## 8. 代码层关联

### 8.1 AppConstants.Version

`Sources/Core/Base/Constants/AppConstants.swift` 第 378-386 行：

- `semVer` — 手动维护，发布时与 git tag 同步
- `gitShortHash` — 构建时由 `build-pipeline-version-inject.sh` 自动注入
- `buildTimestamp` — 构建时由 `build-pipeline-version-inject.sh` 自动注入

### 8.2 VersionInfoFormatter

`Sources/Core/Base/VersionInfoFormatter.swift` — 从 `Bundle.main.infoDictionary` 读取 `CFBundleShortVersionString`、`GIT_SHORT_HASH`、`BUILD_TIMESTAMP`，格式化为 AboutView 展示文本。

### 8.3 现有消费者

| 文件 | 读取字段 | 用途 |
|------|---------|------|
| `AboutView.swift` | `CFBundleShortVersionString` + `GIT_SHORT_HASH` + `BUILD_TIMESTAMP` | 关于页面版本展示 |
| `FeedbackView.swift` | `CFBundleShortVersionString` | 反馈表单附带版本号 |
| `iOSAppEnvironment.swift` | `CFBundleShortVersionString` | 环境初始化日志 |
| `MacAppEnvironment.swift` | `CFBundleShortVersionString` | 环境初始化日志 |
| `WatchAppEnvironment.swift` | `CFBundleShortVersionString` | 环境初始化日志 |

---

## 9. 测试

### 9.1 ci-build-pipeline-version-inject.sh 单元测试

`Tools/ci/run-test-version-inject-unit.sh`

| 测试场景 | 输入 | 预期输出 |
|---------|------|---------|
| Swift 常量读取 | semVer = `1.2.3` | `CFBundleShortVersionString=1.2.3` |
| swift 文件不存在 | 删除 AppConstants.swift | `CFBundleShortVersionString=0.0.0` |
| 构建号递增 | 两次注入 | `CFBundleVersion` 单调递增 |
| 短哈希格式 | 正常仓库 | 7 字符 hex |
| tag 一致性校验 | `v1.2.3` vs semVer `1.2.3` | 通过，无 WARNING |
| tag 不一致 | `v2.0.0` vs semVer `1.2.3` | WARNING，以 semVer 为准 |

### 9.2 集成测试

`Tools/ci/run-test-version-inject-integration.sh` — 在真实项目仓库中验证 inject → plist → 读取 全链路。

### 9.3 AboutView 快照测试

`Tests/SnapshotTests/ComponentSnapshots/testAboutView.1.png` — 基准快照已生成，版本信息变更后重新录制。

### 9.4 App Store 合规门禁

`ios-check-release-appstore.py` 自动校验 `CFBundleShortVersionString` 格式（纯数字点分），注入脚本输出通过此门禁自然验证。

---

## 10. 参考

- [CI/CD 工作流规范](../Architecture/CI_CD_WORKFLOW.md) — 双引擎 CI 架构与纵深防御矩阵
- [Apple TN2420](https://developer.apple.com/documentation/technotes/tn2420-version-numbers-and-build-numbers) — 版本号与构建号官方指南
- [Semantic Versioning 2.0.0](https://semver.org/) — SemVer 规范
