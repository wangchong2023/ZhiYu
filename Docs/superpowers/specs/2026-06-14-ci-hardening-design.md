# CI 纵深加固设计方案

> 版本: 1.0 | 日期: 2026-06-14 | 状态: 待评审

## 一、动机与目标

ZhiYu 已建立四层纵深防御（Pre-commit → Build Phase → Woodpecker → GitHub Actions），覆盖代码质量、架构分层、安全审计。本轮加固面向**业界标准的 CI 成熟度模型**，按优先级分四阶段推进，补齐质量门禁、供应链安全、性能防护、运维韧性四个维度的缺口。

### 现状基线

| 维度 | 已就绪 | 缺口 |
|------|--------|------|
| 质量门禁 | 四层防御 + 112+ 测试套件 | 分支保护、CODEOWNERS、不稳定测试自动管理、测试影响分析 |
| 供应链安全 | SPM 审计 + 密钥扫描 | SBOM、Dependabot、签名提交验证 |
| 性能防护 | 4 文件 7 个性能测试 | 基线回归检测、构建缓存优化、增量编译 |
| 运维韧性 | Woodpecker + GHA 双 CI | 确定性构建、CI 自身监控告警、Canary 部署 |

---

## 二、第一阶段：护栏与可观测性（Week 1–2）

低投入，立即可见的防护提升。

### 2.1 GitHub / Gitea 分支保护规则

**目标**：阻止直接 push main，强制 PR + CI 通过 + Code Review。

**GitHub 分支保护配置：**

```
✅ Require a pull request before merging
    ✅ Require approvals (≥1)
    ✅ Dismiss stale reviews when new commits are pushed
✅ Require status checks to pass before merging
    ✅ ci / lint-and-audit
    ✅ ci / test
    ✅ ci / multi-platform (iOS)
✅ Require conversation resolution before merging
✅ Do not allow bypassing the above settings (include administrators)
```

**Gitea**：通过 API `/repos/{owner}/{repo}/branch_protections` 同步配置。

> ⚠️ 分支保护规则通过 GitHub/Gitea Web UI 或 API 配置，无代码文件。配置完成后截图留存至 `Docs/CI/`。

### 2.2 CODEOWNERS + PR 模板

**新建 `.github/CODEOWNERS`**：按领域指定 owner。

**新建 `.github/pull_request_template.md`**：包含类型选择（feat/fix/refactor/test/ci/docs）、变更说明、测试计划 checklist、CI 检查清单。

### 2.3 不稳定测试自动标记

**问题**：当前不稳定测试硬编码在 `SKIP_TESTS` 数组，手动维护。

**方案**：源码注释标记 → 脚本自动收集 → CI 跳过列表。

```swift
// @flaky: CI中偶现失败，原因见 issue #123
func testWildMonkeyClickTraversal() { ... }
```

**新建 `Tools/ci/run-test-flaky-report.sh`**：`grep -rn "@flaky:" Tests/` → 生成 `build/.flaky_tests`，CI 脚本从文件读取跳过列表。

### 2.4 CI 自身可观测性

**方案**：Woodpecker 末尾写死信文件 + 飞书 Webhook 通知（第四阶段完善）。

**文件**：
- `build/.ci_health` — 流水线失败记录
- `Tools/ci/run-pipeline-feishu.sh` — 飞书告警（第四阶段实现）

---

## 三、第二阶段：供应链加固（Week 2–4）

### 3.1 Dependabot 自动依赖更新

**新建 `.github/dependabot.yml`**：

```yaml
version: 2
updates:
  - package-ecosystem: "swift"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
      timezone: "Asia/Shanghai"
    open-pull-requests-limit: 5
    labels: ["dependencies", "swiftpm"]
    reviewers: ["wangchong2023"]

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    labels: ["dependencies", "ci"]
```

**配套规则**：
- Dependabot PR 必须通过全部 CI 检查方可合并
- `CVE-` 前缀安全更新自动提升优先级

### 3.2 SBOM 生成（方案 A+C 混合）

**推荐方案**：自解析 `Package.resolved`（精确版本信息）+ Syft（License 检测）→ 合并输出 SPDX 2.3 + CycloneDX 双格式。

```
Package.resolved                     Syft 文件系统扫描
(版本+revision+仓库URL)               (LICENSE 文件检测)
        │                                    │
        ▼                                    ▼
  Tools/ci/generate-arch-sbom-single.py           syft . -o cyclonedx-json
  (自解析 ~80 行 Python)              (现成工具)
        │                                    │
        └──────────────┬─────────────────────┘
                       ▼
              Tools/ci/generate-arch-sbom-merged.py (~60 行)
              合并 → SPDX 2.3 + CycloneDX
                       │
                       ▼
              上传至 CI artifacts (保留 90 天)
```

**为什么不用 Apple 内置方案**：`swift package generate-sbom` 需要 `Package.swift`，ZhiYu 使用 `project.yml` (XcodeGen) 管理依赖，不兼容。

**为什么混合**：自解析提供精确版本/revision，Syft 补齐 License 信息。Syft 单独使用对 SPM 传递依赖检测不完整，但 License 文件扫描不受此影响。

**新建文件**：
- `Tools/ci/generate-arch-sbom-single.py` — Package.resolved 解析 + SPDX 生成
- `Tools/ci/generate-arch-sbom-merged.py` — 合并自解析结果与 Syft 输出

**依赖**：`brew install syft`（CI 环境预装）

### 3.3 签名提交验证

**方案**：渐进式推进。

1. **Week 2**：配置本地 GPG 签名（`git config commit.gpgsign true`），CI 中 `git log --show-signature` 以 warning 报告
2. **Week 4**：GitHub/Gitea 启用 "Require signed commits"

### 3.4 SPM 依赖完整性校验

**方案**：CI `lint-and-audit` 阶段增加哈希比对，校验 `Package.resolved` 记录的 revision 与检出的实际 commit 一致：

```bash
Tools/ci/check-arch-spm-integrity.sh
```

---

## 四、第三阶段：性能防护（Week 3–5）

### 4.1 性能基线 + 回归检测

**方案**：性能测试 → 基线 JSON → 每次 CI 比对 → 退化超过阈值阻断。

```
CI 运行性能测试
      │
      ▼
提取测试耗时 (xcresult → json via xcresulttool)
      │
      ▼
对比 build/.perf_baselines/<test-name>.json  ← Git 管理
      │
      ├── 退化 > 10%: ❌  阻断 + PR comment
      ├── 退化 5-10%:  ⚠️  Warning
      └── 退化 < 5%:   ✅  通过
```

**新建 `Tools/ci/check-pipeline-perf-regression.py`**：
- 解析 xcresult 提取性能指标（`xcrun xcresulttool get --format json`）
- 与基线 JSON 比对
- 超阈值时输出退化详情并返回非零

**新建 `Tools/ci/generate-pipeline-perf-baseline.sh`**：
- 手动运行，将当前 CI 性能数据写入基线文件
- 仅在确认性能提升是预期行为时使用

**基线文件格式** (`build/.perf_baselines/<ClassName>.json`)：
```json
{
  "testOneHundredThousandNodesFTSRetrievalLatency": {
    "baseline_ms": 245.0,
    "tolerance_pct": 10,
    "last_updated": "2026-06-14"
  }
}
```

### 4.2 增量编译 + 构建缓存

**已优化**：
- `-clonedSourcePackagesDirPath` SPM 缓存共享 ✅
- `build/DerivedData-ios` 固定路径 ✅

**新增**：

| 优化 | 实现 | 预期 |
|------|------|------|
| CI 持久化 DerivedData | Woodpecker `clone-repo` → `git fetch + reset --hard`，保留 `build/` | -40% 增量 |
| project.yml/Package.resolved 变更检测 | 仅此二文件变更时清空 DerivedData | 避免脏缓存 |
| SPM 缓存预热 | checkout 后并行 `swift package resolve` | -30s |

### 4.3 编译警告 → 错误（试运行）

**方案**：`security-scan.yml` 中增加 `SWIFT_TREAT_WARNINGS_AS_ERRORS=YES` 构建，先试运行并修复存量 warning，再推广到主 CI。

---

## 五、第四阶段：运维韧性（Week 4–6）

### 5.1 确定性构建 (Reproducible Builds)

**方案**：L1 + L2，不追求完整 L3。

| 级别 | 措施 | 实现 |
|------|------|------|
| **L1** | `SWIFT_COMPILATION_MODE=wholemodule` + 固定 `SOURCE_DATE_EPOCH` | `project.yml` 增加编译设置 |
| **L2** | CI 构建两次 → 比对二进制 hash → 不一致则告警 | Woodpecker + GHA 各加一个 step |

```bash
# L2 验证步骤
xcodebuild archive ... -archivePath build/app1.xcarchive
xcodebuild archive ... -archivePath build/app2.xcarchive
diff <(xxd build/app1.xcarchive/.../ZhiYu) <(xxd build/app2.xcarchive/.../ZhiYu)
```

### 5.2 飞书 CI 告警

**方案**：Woodpecker Webhook → 飞书自定义机器人 → 失败/恢复时推送消息卡片。

**新建 `Tools/ci/run-pipeline-feishu.sh`**：
- 读取 Woodpecker 环境变量（`CI_PIPELINE_STATUS` 等）
- 仅在 **失败** 或 **恢复** 时发送
- Webhook URL 通过 CI secret 注入
- 消息卡片包含：commit SHA、失败步骤、耗时、日志链接

### 5.3 Canary 部署管道

**方案**：先建 TestFlight Internal 自动上传，后续扩展。

```
main push → CI 全绿 → Release 构建 → TestFlight Internal 上传 → 24h 观察
```

**工具链**：
- `fastlane pilot` — TestFlight 上传 + 内部测试组管理
- `xcrun altool` — 公证 + 上传
- 后续：扩展 Logger 系统为轻量崩溃统计

**依赖**：`brew install fastlane`（CI 环境预装）

**新建 `fastlane/Fastfile`**（最小化）：
```ruby
default_platform(:ios)
platform :ios do
  lane :canary do
    build_app(scheme: "ZhiYu", configuration: "Release")
    upload_to_testflight(skip_waiting_for_build_processing: true)
  end
end
```

### 5.4 定期故障演练

**方案**：每月第一个周一手动触发，记录在 `Docs/CI/drill-log.md`。

| 场景 | 操作 | 验证 |
|------|------|------|
| 依赖不可用 | 删除 SPM 缓存 | CI 优雅失败 + 告警 |
| 磁盘满 | 填充 build 目录 | 超时机制生效 |
| Agent 宕机 | `launchctl unload` Woodpecker agent | Webhook 重试正常 |

---

## 六、新建文件清单

| 阶段 | 文件 | 职责 |
|------|------|------|
| 1 | `.github/CODEOWNERS` | 代码所有权分配 |
| 1 | `.github/pull_request_template.md` | PR 提交流程标准化 |
| 1 | `Tools/ci/run-test-flaky-report.sh` | @flaky 注释 → 跳过列表 |
| 2 | `.github/dependabot.yml` | 自动依赖更新 |
| 2 | `Tools/ci/generate-arch-sbom-single.py` | Package.resolved → SPDX JSON |
| 2 | `Tools/ci/generate-arch-sbom-merged.py` | 自解析 + Syft → 合并 SBOM |
| 2 | `Tools/ci/check-arch-spm-integrity.sh` | SPM 依赖哈希校验 |
| 3 | `Tools/ci/check-pipeline-perf-regression.py` | 性能基线比对 |
| 3 | `Tools/ci/generate-pipeline-perf-baseline.sh` | 手动更新性能基线 |
| 4 | `Tools/ci/run-pipeline-feishu.sh` | 飞书 CI 告警 |
| 4 | `fastlane/Fastfile` | Canary 部署管道 |

## 七、风险与依赖

| 风险 | 缓解 |
|------|------|
| Dependabot PR 过多 | `open-pull-requests-limit: 5` |
| 性能基线首次校准不准确 | 取最近 5 次 CI 成功运行的中位数作为初始基线 |
| 飞书 Webhook 泄露 | CI secret 注入，不硬编码 URL |
| Syft License 检测不完整 | 自解析补充 GitHub API 查询 LICENSE 文件（fallback） |
| 确定性构建 L1 不充分 | L2 比对快速暴露问题，再升级至 L3 |
