# 智宇 (ZhiYu) 持续集成与交付 (CI/CD) 规范

> 最后更新: 2026-08-02 (v6.0 — GitLab CE v18.1.0 架构重构 + .gitlab-ci.yml 规范)

---

## 1. CI 架构概览

智宇客户端与 `ZhiYu-Backend` 统一采用 **GitLab CE v18.1.0 + GitLab Runner** 持续集成架构：

```
┌──────────────┐    push / MR     ┌──────────────────────┐    Job Queue   ┌──────────────────────────┐
│  GitLab CE   │ ───────────────→ │ GitLab CI/CD Engine  │ ─────────────→ │ macOS Shell Runner       │
│  :8480 (Web) │                  │ (.gitlab-ci.yml)     │                │ tags: macos,shell,xcode  │
└──────────────┘                  └──────────────────────┘                └────────────┬─────────────┘
                                                                                       │
                                                                                       ▼
                                                                          ┌──────────────────────────┐
                                                                          │ XcodeGen + Gatekeeper    │
                                                                          │ xcodebuild + xcrun       │
                                                                          └──────────────────────────┘
```

## 1.1 SPM 极速单测矩阵与本地包验证 (Fast Package Matrix)

在 Xcode 全量编译前，CI 流水线首先并行触发各 SPM 本地包的毫秒级纯 Swift 单测：

```bash
# 1. 验证通用底座与存储包
swift test --package-path Packages/UFPCore
swift test --package-path Packages/UFPStorage
swift test --package-path Packages/UFPDesignSystem

# 2. 验证智宇业务大脑与 AI 中台包
swift test --package-path Packages/ZhiYuDomain
swift test --package-path Packages/ZhiYuAICore
swift test --package-path Packages/ZhiYuFeatures
```

| 组件 | 运行环境 | 访问/标识 | 职责 |
|------|------|------|------|
| **GitLab CE** | Docker Compose | `http://127.0.0.1:8480` | 代码托管、MR 管理、CI 控制台 |
| **GitLab Runner** | macOS launchd 原生服务 | `macos-shell-runner` | 执行 iOS/macOS/watchOS 构建与测试 |

---

## 2. 主 CI 流水线 (`.gitlab-ci.yml`)

流水线包含 4 个核心阶段 (Stages)：`analyze` → `prepare` → `build` → `test`

| 阶段 (Stage) | 任务 (Job) | 触发条件 | 执行内容 |
|---|---|---|---|
| **analyze** | `static-analysis` | 所有 push / MR | 运行 21 项 Gatekeeper 静态合规审计 |
| **prepare** | `build-prepare` | `main` / `develop` / `release/*` push | `xccodegen generate` + 解析 SPM 依赖 + 注入版本号 |
| **build** | `build-ios` | `main` / `develop` / `release/*` push | 构建 iOS 模拟器目标 (`ZhiYu`) |
| | `build-macos` | `main` / `develop` / `release/*` push | 构建 macOS Catalyst 目标 (`ZhiYuMac`) |
| | `build-watchos` | `main` / `develop` / `release/*` push | 构建 watchOS 模拟器目标 (`ZhiYuWatch`) |
| **test** | `test-and-coverage` | `main` / `develop` / `release/*` push | 运行全量单元测试与覆盖率熔断门禁（必须大于 85%） |

---

## 3. 分支策略与 MR 合流强卡控 (Git Branching & Branch Protection Rules)

智宇客户端与 `ZhiYu-Backend` 全面统一 Git 分支生命周期与 MR 合入规则。

### 3.1 分支命名与生命周期规范

| 分支类型 | 前缀格式 | 适用场景 | 对应 Git 提交前缀 | CI 触发策略 |
|:---|:---|:---|:---|:---|
| **主分支** | `main` | 绝对稳定且随时可编译发布的生产基线 | - | 触发全平台 build + test + artifact |
| **特性分支** | `feature/<name>` | 新功能组件开发 (例: `feature/voice-note`) | `feat:` | 触发静态扫描 + 极速 SPM 单测 |
| **修复分支** | `fix/<issue-id>` | 缺陷及 Crash 修复 (例: `fix/concurrency-warning`) | `fix:` | 触发静态扫描 + 极速 SPM 单测 |
| **重构分支** | `refactor/<name>` | 架构/模板重构 (例: `refactor/project-template`) | `refactor:` | 触发静态扫描 + 极速 SPM 单测 |
| **文档分支** | `docs/<name>` | 纯文档及注释更新 (例: `docs/l10n-guide`) | `docs:` | 触发文档关联审计 |
| **测试分支** | `test/<name>` | 测试用例或 CI 门禁调试 (例: `test/gatekeeper`) | `test:` | 触发静态扫描 |
| **紧急修复** | `hotfix/<issue-id>` | 生产紧急 Hotfix | `fix:` / `hotfix:` | 触发全量测试 |
| **发布分支** | `release/v<ver>` | 版本发布筹备 (例: `release/v2.3.0`) | `chore:` | 触发全平台发布 |

### 3.2 MR 合流标准与四重硬卡控

```
┌───────────────────────┐         git push          ┌───────────────────────┐
│ 开发者在特性分支开发  │ ───────────────────────→  │ 发起 Merge Request    │
│ feature/voice-note    │                           │ (MR → main)           │
└───────────────────────┘                           └───────────┬───────────┘
                                                                │
                                                                ▼
                                                    ┌───────────────────────┐
                                                    │ GitLab CI 流水线校验  │
                                                    │ - Gatekeeper 21 项    │
                                                    │ - 单元测试全绿        │
                                                    │ - 覆盖率 > 85%        │
                                                    └───────────┬───────────┘
                                                                │ (流水线全绿)
                                                                ▼
                                                    ┌───────────────────────┐
                                                    │ Maintainer 审查与批准│
                                                    └───────────┬───────────┘
                                                                │ (Approve)
                                                                ▼
                                                    ┌───────────────────────┐
                                                    │ 合入 main 主分支      │
                                                    └───────────────────────┘
```

1. **🚫 禁止直接 Push `main` (`push_access_level: 0 / No one`)**：主分支禁用 `git push main`，任何修改必须通过 MR 流程。
2. **🚦 流水线全绿方可合并 (`only_allow_merge_if_pipeline_succeeds: true`)**：未通过静态检查或单元测试，Merge 按钮置灰封锁。
3. **👥 Maintainer 审核制 (`merge_access_level: 40 / Maintainers`)**：仅 Maintainer 角色允许点击 Merge 按钮。
4. **🔒 禁用 Force Push (`allow_force_push: false`)**：分支历史禁止强覆盖。

### 3.3 分支保护自动化部署 (API 指引)

```bash
# 1. 配置 MR 流水线强卡控 (GitLab CE)
curl -X PUT "http://127.0.0.1:8480/api/v4/projects/constantine%2FZhiYu" \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"only_allow_merge_if_pipeline_succeeds": true}'

# 2. 配置 main 主分支保护
curl -X POST "http://127.0.0.1:8480/api/v4/projects/constantine%2FZhiYu/protected_branches" \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "main",
    "push_access_level": 0,
    "merge_access_level": 40,
    "allow_force_push": false
  }'
```

---

## 4. 四层纵深防御矩阵 (Defense-in-Depth)

| 检查项 | 脚本/工具 | Layer 1: Pre-commit | Layer 2: Build Phase | Layer 3: Woodpecker CI | Layer 4: GitHub Actions |
|--------|-----------|:---:|:---:|:---:|:---:|
| 硬编码密钥扫描 | `check_hardcoded_secrets.py` | ✅ | ✅ | ✅ | ✅ |
| 本地化合规 | `check_localization.py` | ✅(仅报告) | ✅ | ❌ | ✅ |
| SwiftLint 严格模式 | `swiftlint lint --strict` | ❌ | ✅ | ✅ | ✅ |
| 架构依赖 (L0-L3 分层) | `check_architecture_dependency.py` | ❌ | ✅ | ✅ | ✅ |
| 领域纯净度 | `check_domain_purity.py` | ❌ | ✅ | ✅ | ❌ |
| 魔鬼数字/字符串 | `check_magic_numbers_v2.py` | ❌ | ✅ | ✅ | ✅ |
| 根目录卫生 (临时文件+结构) | `check_root_hygiene.py` | ❌ | ❌ | ✅ | ✅ |
| Storage 常量 | `check_storage_constants.py` | ❌ | ✅ | ❌ | ❌ |
| HIG 合规 | `check_hig_compliance.py` | ❌ | ✅ | ❌ | ❌ |
| App Store 就绪 | `check_appstore_readiness.py` | ❌ | ✅ | ❌ | ❌ |
| DI 测试设置审计 | `check_test_di_setup.py` | ❌ | ❌ | ✅ | ✅ |
| 文档与配置完整性 | `check_docs_and_configs.py` | ❌ | ❌ | ✅ | ❌ |
| Swift 注释与函数长度 | `check_swift_quality.py` | ❌ | ❌ | ✅ | ❌ |
| Tools 脚本质量 (Python/Shell) | `check_scripts_quality.py` | ❌ | ✅ | ✅ | ❌ |
| ShellCheck (条件性¹) | 内嵌于 `check_scripts_quality.py` | ❌ | ❌ | ✅ | ❌ |
| 分层标记审计 | `lint_layer_markers.sh` | ❌ | ❌ | ✅ | ❌ |
| Unsafe String.Index 扫描 | `scan_unsafe_string_index.py` | ❌ | ❌ | ✅ | ❌ |
| SPM 完整性 | `verify_spm_integrity.sh` | ❌ | ❌ | ✅ | ✅ |
| SPM 依赖漏洞审计 | `audit_spm_dependencies.py` | ❌ | ❌ | ❌ | ✅ |
| SBOM 生成 (SPDX+CycloneDX) | `generate_sbom.py` / `merge_sbom.py` | ❌ | ❌ | ✅ | ✅ |
| 代码覆盖率红线 (85%) | `check_coverage.py` | ❌ | ❌ | ✅ | ✅ |

> **¹ ShellCheck 条件性**：`check_scripts_quality.py` 在运行时 `shutil.which("shellcheck")` 动态探测，仅当 Agent/runner 已安装 shellcheck 才合流校验，否则静默跳过。GitHub-hosted macos-15 runner 预装 shellcheck；自托管 Woodpecker iOS Agent 需自行 `brew install shellcheck`。

**分层原则：**
- **Layer 1 (Pre-commit)**: 最快，只阻断密钥泄露，其余仅报告
- **Layer 2 (Build Phase)**: 每次本地构建运行，覆盖代码质量 + 魔鬼数字 + 架构分层 + SwiftLint `--strict`（与 CI 同口径，杜绝本地绕过）
- **Layer 3 (Woodpecker)**: 自托管 CI，`run_static_analysis.sh` 并发 19 项 + 三平台编译 + 测试覆盖率
- **Layer 4 (GitHub Actions)**: 独立验证 + 产物上传 + 多平台矩阵 + SPM 漏洞审计

---

## 3. Build Phase 编译门禁 (Gatekeeper)

Xcode Build Phases 中为每个 target 配置的 `preBuildScripts`（定义于 `project.yml`）。所有脚本均设 `basedOnDependencyAnalysis: false`，即每次构建必跑。任一脚本非零退出即阻断编译。

### 各 target 门禁配置

| Gatekeeper 脚本 | ZhiYu (iOS) | ZhiYuMac | ZhiYuWatch | ZhiYuWidgets | ZhiYuTests |
|------|:---:|:---:|:---:|:---:|:---:|
| `swiftlint lint --strict` | ✅ | ✅ | ❌ | ❌ | ❌ |
| `check_domain_purity.py` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `check_localization.py` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `check_storage_constants.py` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `check_magic_numbers_v2.py` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `check_hardcoded_secrets.py` | ✅ | ❌ | ❌ | ❌ | ❌ |
| `check_hig_compliance.py` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `check_appstore_readiness.py` | ✅ | ✅ | ❌ | ❌ | ❌ |
| `check_architecture_dependency.py` | ✅ | ✅ | ✅ | ❌ | ❌ |
| `check_scripts_quality.py` | ✅ | ✅ | ✅ | ❌ | ❌ |
| **合计** | **10** | **8** | **6** | **0** | **0** |

### 各脚本职责

| 脚本 | 功能 | 阻断级别 |
|------|------|---------|
| `swiftlint lint --strict` | 圈复杂度 (<10) / 函数长度 (NBNC<50) / 编码规范硬熔断 | ERROR |
| `check_domain_purity.py` | 领域层纯净度（禁止跨域直接依赖） | ERROR |
| `check_localization.py` | 硬编码中文 + 违规 `.tr()` 调用 + 翻译占位符 | ERROR |
| `check_storage_constants.py` | 数据库物理表名/字段名硬编码 | ERROR |
| `check_magic_numbers_v2.py` | UI 与业务逻辑魔鬼数字检测 | ERROR |
| `check_hardcoded_secrets.py` | 密钥/Token/内网 IP 扫描 | ERROR |
| `check_hig_compliance.py` | Apple HIG 人机交互指南合规性 | ERROR |
| `check_appstore_readiness.py` | App Store 提审前上架就绪度 | ERROR |
| `check_architecture_dependency.py` | L0–L3 分层依赖方向审计 | ERROR |
| `check_scripts_quality.py` | Tools 目录 Python/Shell 脚本质量（含 ShellCheck） | ERROR |

> **设计说明**：`ZhiYuWidgets` 与 `ZhiYuTests` 不配 Gatekeeper，因为 Widget 扩展只依赖设计令牌与少量模型、测试 target 不发布。SwiftLint 未在 `ZhiYuWatch` 的 Build Phase 单独配置，watchOS 代码规范由主 target 的 lint 覆盖（`Sources/` 全局扫描）。

---

## 4. 提交前本地审计 (Pre-commit Hook)

`.git/hooks/pre-commit` 在 `git commit` 时自动执行：

| 检查项 | 工具 | 阻断条件 |
|--------|------|---------|
| 硬编码密钥扫描 | `Tools/Gatekeeper/check_hardcoded_secrets.py` | 命中即阻断 |
| 本地化合规 | `Tools/Gatekeeper/check_localization.py` | 仅报告，不阻断（编译时强制） |

---

## 5. 本地化强制网关

编译时通过 Build Phase 脚本执行：

| 检查项 | 级别 |
|--------|------|
| 硬编码中文字符串 | ERROR — 阻断编译 |
| 直接调用 `.tr("key")` 而非 `L10n.模块.属性` | ERROR |
| 翻译值等于 key（未翻译占位符） | ERROR |
| 跨文件 key 值不一致 | ERROR |

---

## 6. 代码覆盖率熔断

| 指标 | 阈值 |
|------|------|
| 覆盖率统计 | `xcrun xccov view --report` 解析 .xcresult |
| CI 检查 | `Tools/CI/check_coverage.py` |

---

## 7. 工具目录结构

```
Tools/
├── Gatekeeper/                          # 编译门禁 (project.yml preBuildScripts)
│   ├── check_domain_purity.py           # 领域层纯净度
│   ├── check_localization.py            # 硬编码中文 + 违规 tr() 调用
│   ├── check_storage_constants.py       # 数据库物理字段硬编码
│   ├── check_magic_numbers_v2.py        # 魔鬼数字检测
│   ├── check_hardcoded_secrets.py       # 密钥/Token/IP 扫描
│   ├── check_hig_compliance.py          # Apple HIG 合规性
│   ├── check_appstore_readiness.py      # App Store 上架就绪度
│   ├── check_architecture_dependency.py # L0-L3 分层依赖审计
│   ├── check_root_hygiene.py            # 根目录卫生 (临时文件+结构)
│   ├── check_scripts_quality.py         # Tools 脚本质量 (Python/Shell + ShellCheck)
│   ├── check_swift_quality.py           # Swift 函数长度与注释完备性
│   ├── check_test_di_setup.py           # 测试环境 DI 完整性
│   ├── check_docs_and_configs.py        # 文档完整性 + 死链 + 配置一致性
│   └── check_coverage.py                # 覆盖率红线 (Domain 层, 85%)
├── CI/                                  # CI 流水线脚本
│   ├── run_static_analysis.sh           # 并发调度 19 项静态分析
│   ├── prepare_build_environment.sh     # xcodegen generate 等构建前准备
│   ├── inject_version.sh                # 版本号注入（git tag → Info.plist）
│   ├── build_platform.sh                # 单平台 xcodebuild 构建封装
│   ├── build_multi_platform.sh          # 多平台矩阵构建封装
│   ├── run_tests_and_coverage.sh        # xcodebuild test + 覆盖率红线
│   ├── run_unit_tests.sh                # 单元测试 (CI 侧)
│   ├── run_ui_tests.sh                  # UI 测试 (跳过 Monkey)
│   ├── check_coverage.py                # 覆盖率红线 (与 Gatekeeper 版不同, 见 §8)
│   ├── check_perf_regression.py         # 性能回归分析
│   ├── update_perf_baseline.sh          # 性能基线更新
│   ├── collect_flaky_tests.sh           # Flaky 测试收集
│   ├── ci-test-progress.sh              # 测试用例数统计
│   ├── audit_spm_dependencies.py        # SPM 依赖漏洞审计
│   ├── verify_spm_integrity.sh          # SPM 包完整性校验
│   ├── verify_commit_signature.sh       # GPG 提交签名校验
│   ├── verify_reproducible_build.sh     # 确定性构建验证
│   ├── generate_sbom.py                 # SPDX 2.3 SBOM 生成
│   ├── merge_sbom.py                    # SPDX + CycloneDX SBOM 合并
│   └── notify_feishu.sh                 # 飞鱼 CI 通知
├── Lint/                                # 手动代码质量检查
│   ├── audit_l10n.py                    # 本地化深度审计
│   ├── lint_layer_markers.sh            # 分层标记审计
│   └── scan_unsafe_string_index.py      # Unsafe String.Index 越界扫描
├── Mock/                                # Mock 服务器 + E2E 测试
│   ├── mock_plugin_market.py
│   ├── test_plugin_e2e.py
│   └── MockServer/
├── Plugins/                             # 插件 SDK + 源文件 + 测试
│   ├── copy_plugins_to_sim.sh
│   ├── validate_plugin.py
│   ├── test_plugin_and_model_features.sh
│   └── Local/ Remote/ community/ smart-cleaner/
├── Utils/                               # 辅助脚本
│   ├── run_tests.sh
│   ├── sync_sql.py
│   └── update_snapshots.sh
└── README.md
```

> **注意**：`Tools/CI/check_coverage.py` 与 `Tools/Gatekeeper/check_coverage.py` 同名但实现不同（CI 版用于 Woodpecker/GitHub 流水线，Gatekeeper 版预留 Build Phase 调用）。修改时注意区分，建议未来重命名消除歧义。

---

## 8. GitHub Actions（辅助 CI）

`.github/workflows/ci.yml` 和 `security-scan.yml` 作为 GitHub 侧的辅助流水线。

### ci.yml (v3.0 — 2026-06-14)

| 阶段 | Job | 运行器 | 内容 |
|------|-----|--------|------|
| Stage 1 | `lint-and-audit` | `macos-15` | SPM 审计 → SwiftLint → 密钥扫描 → L10n 检查 |
| Stage 2 | `test` | `macos-15` | 构建 → 单元测试 → 覆盖率红线 → 失败时上传 .xcresult |
| Stage 3 | `ui-test` | `macos-15` | UI 测试（跳过 Monkey）→ 失败时上传日志 |
| Stage 4 | `multi-platform` | `macos-15` + 矩阵 | iOS / macOS / watchOS 三平台并行编译 |

**v3.0 增强项：**
- Xcode `15.4` → `latest-stable`，macOS runner `macos-14` → `macos-15`
- 多平台构建改为 `strategy.matrix` 并行，缩短约 40% 耗时
- 测试失败时自动上传 `.xcresult` + 原始日志（`actions/upload-artifact@v4`）
- Monkey 测试（`testWildMonkeyClickTraversal`）在 CI 中显式跳过

### security-scan.yml (v3.0)

- `macos-latest` → `macos-15`
- 每周一凌晨 2:00 定时运行 + push/PR 触发

---

## 9. 流水线故障排查

| 症状 | 可能原因 | 检查方式 |
|------|----------|---------|
| 推送未触发流水线 | Gitea Webhook 失效 | `curl localhost:3000/api/v1/repos/constantine/ZhiYu/hooks` |
| Agent 未接管任务 | 标签不匹配 | 确认 Agent plist `WOODPECKER_LABELS` 与 `.woodpecker.yml` `labels` 一致 |
| 端口冲突 | healthcheck 端口被占 | `lsof -i :3001` / `lsof -i :3002` |
| Woodpecker Server 无响应 | 容器未运行 | `docker ps \| grep woodpecker-server` |
