# 智宇 (ZhiYu) 持续集成与交付 (CI/CD) 规范

> 最后更新: 2026-06-27 (v5.1 — 版本注入步骤 + 构建号管理)

---

## 1. CI 架构概览

```
┌──────────┐    push/webhook     ┌──────────────────┐    gRPC     ┌──────────────────────────┐
│  Gitea   │ ──────────────────→ │ Woodpecker Server │ ←───────── │ Woodpecker Agent (macOS) │
│ :3000    │                     │ :8000 (Web UI)    │            │ darwin/arm64 backend=local│
└──────────┘                     │ :9000 (gRPC)      │            │ healthcheck :3001         │
                                 └──────────────────┘            └──────────────────────────┘
                                           │                                 │
                                           │ gRPC                            │ 直接执行
                                           ↓                                 ↓
                                 ┌──────────────────┐            ┌──────────────────────────┐
                                 │ Woodpecker Agent │            │ xcodebuild + Gatekeeper  │
                                 │ (Docker 容器)    │            │ 脚本 (preBuildScripts)   │
                                 │ linux/arm64      │            └──────────────────────────┘
                                 │ backend=docker   │
                                 │ healthcheck :3002│
                                 └──────────────────┘
                                           │
                                           ↓
                                    ZhiYu-Backend 构建
```

## 1.1 SPM 极速单测矩阵与本地包验证 (Fast Package Matrix)

在 Xcode 全量构建前，CI 流水线首先并行触发各 SPM 本地包的毫秒级纯 Swift 单测：

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

| 组件 | 位置 | 端口 | 职责 |
|------|------|------|------|
| Gitea | `bin-gitea-1` (Docker) | `3000` (Web), `2222` (SSH) | 代码托管 + Webhook |
| Woodpecker Server | `bin-woodpecker-server-1` (Docker) | `8000` (Web), `9000` (gRPC) | 流水线调度 |
| iOS Agent | `launchd` 原生进程 | `3001` (健康检查) | ZhiYu iOS 构建 (backend=local) |
| Backend Agent | `launchd` 原生进程 | `3002` (健康检查) | ZhiYu-Backend 构建 (backend=docker) |

### Agent 配置

**iOS Agent** (`~/Library/LaunchAgents/com.zhiyu.woodpecker-agent.plist`):

| 环境变量 | 值 |
|----------|-----|
| `WOODPECKER_SERVER` | `localhost:9000` |
| `WOODPECKER_BACKEND` | `local` |
| `WOODPECKER_LABELS` | `platform=darwin/arm64,backend=local` |
| `WOODPECKER_HEALTHCHECK_ADDR` | `:3001` |

**Backend Agent** (`~/Library/LaunchAgents/com.zhiyu.woodpecker-agent-backend.plist`):

| 环境变量 | 值 |
|----------|-----|
| `WOODPECKER_SERVER` | `localhost:9000` |
| `WOODPECKER_BACKEND` | `docker` |
| `WOODPECKER_LABELS` | `platform=linux/arm64,backend=docker` |
| `WOODPECKER_HEALTHCHECK_ADDR` | `:3002` |

---

## 2. 主 CI 流水线 (`.woodpecker.yml`)

每次 push 到 `main` 分支通过 Gitea Webhook 自动触发，**8 步执行**（步骤间通过 `depends_on` 声明依赖，可并行处自动并行）：

| # | 步骤 | depends_on | 说明 |
|---|------|------------|------|
| 1 | `clone-repo` | — | 用 `$CI_NETRC_*` 凭据写 `~/.netrc`，`git fetch origin $CI_COMMIT_SHA` 精确拉取提交 |
| 2 | `static-analysis` | clone-repo | 并发执行 **19 项**静态分析（见 `Tools/CI/run_static_analysis.sh`） |
| 3 | `prepare-dependencies` | clone-repo | `xcodegen generate` + SPM 依赖解析 |
| 4 | `inject-version` | prepare-dependencies | `inject_version.sh` 从 git tag 提取 SemVer + `git rev-list --count` 构建号 + 短哈希，写入 Info.plist（详见 [版本管理规范](../../Docs/Design/VERSION_MANAGEMENT.md)） |
| 5 | `build-ios` | inject-version | `build_platform.sh ZhiYu iOS` |
| 6 | `build-macos` | build-ios | `build_platform.sh ZhiYuMac macOS` |
| 7 | `build-watchos` | build-macos | `build_platform.sh ZhiYuWatch watchOS` |
| 8 | `test-and-verify-coverage` | build-watchos | `xcodebuild test` + 覆盖率红线校验（`run_tests_and_coverage.sh`） |

**依赖拓扑：**

```
clone-repo ──┬─→ static-analysis (19 项并行)
             └─→ prepare-dependencies ──→ inject-version ──→ build-ios ──→ build-macos ──→ build-watchos ──→ test-and-verify-coverage
```

> **运行环境前置**：`swiftlint`、`swift`、`xcodebuild` 依赖 iOS Agent（macOS launchd 原生进程）预装；`radon`（Python 圈复杂度工具）在 `static-analysis` step 内 `pip3 install`。

流水线标签：`backend: local`（仅匹配 iOS Agent）

---

## 2.5. 四层纵深防御矩阵 (Defense-in-Depth)

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
