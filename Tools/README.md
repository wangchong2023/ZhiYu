# ZhiYu 开发者工具箱 (Developer Tools)

本目录包含用于 ZhiYu 开发、测试、质量保障以及持续集成的辅助脚本与工具。为了维护项目的长期健康，所有脚本均已按功能职责完成分类归档。

## 目录结构

```
Tools/
├── Gatekeeper/     # 编译门禁与静态合规守卫（Xcode Build Phases 引用）
│   ├── Architecture/  # 系统架构纯净度与依赖守卫
│   ├── Compliance/    # 编码规范、本地化、魔鬼数字及 HIG 守卫
│   ├── Release/       # App Store 提审与隐私漏洞守卫
│   └── Sanity/        # 工程结构卫生与代码健康扫描
├── CI/             # CI 流水线相关脚本（GitHub Actions & Woodpecker 引用）
│   ├── Build/         # 编译环境与跨平台构建脚本
│   ├── Test/          # 跑测执行、覆盖率及不稳定测试过滤
│   ├── Analyze/       # 静态分析、SPM 依赖安全及 SBOM 归档
│   ├── Perf/          # 性能比对与性能基线更新
│   └── Notify/        # 飞书等即时通讯工具告警通知
├── Mock/           # 插件市场 Mock 服务器与端到端测试
├── Plugins/        # 插件 SDK 示例与测试工具
├── Utils/          # 快照录制等通用辅助工具
└── README.md
```

- **新增脚本**：必须按上述职责放入对应子目录，严禁在 `CI/` 或 `Gatekeeper/` 根下堆积。
- **文档同步**：新增、移动或删除脚本后，必须同步更新本 `README.md`。

---

## Gatekeeper — 本地编译门禁

在 Xcode Build Phases 中通过 `python3 Tools/scripts/<Category>/<script>.py` 调用。

### Architecture (架构守卫)
| 脚本 | 功能说明 |
|------|------|
| `ios-audit-arch-dependency.py` | 严格审计 L0-L3 跨层依赖，禁止反向依赖 |
| `ios-audit-arch-domain-purity.py` | 验证领域层 (Domain) 平台无关性，严禁导入 UIKit/AppKit |
| `ios-check-arch-test-di-setup.py` | 检查单元测试 DI 容器（ServiceContainer）的双注册合法性 |
| `ios-check-arch-layer-markers.sh` | 检查 Swift 文件头部是否标注合法架构层级标记（如 `[L1]`） |
| `ios-audit-arch-view-duplication.py` | 基于 AST 结构树与修饰符链启发式检测跨 Feature 域 View 相似度并提示沉淀 |
| `ios-check-arch-opensource-adapters.py` | 审计 Sources/ 层开源库直接 import 行为，强约束通过适配层间接调用 |
| `ios-check-arch-dependency-registry.py` | 校验 `opensource_dependencies.yml` 与 Package.swift/project.yml 三层一致性 |
| `ios-check-arch-opensource-internal-deps.py` | 审计开源库自身 Package.swift 内部依赖是否已全部本地化（禁止远端 URL，必须 path: ../<name> 且已注册） |
| `ios-check-arch-opensource-placement.py` | 审计开源适配层在 SPM 包中的物理归位与残留清理状态 |

### Compliance (规范守卫)
| 脚本 | 功能说明 |
|------|------|
| `ios-check-code-localization.py` | 拦截硬编码中文及直接调用 `.tr()` 行为，强制类型安全本地化 |
| `ios-check-code-storage-constants.py` | 拦截数据库物理表名和物理字段的硬编码 SQL 插值 |
| `ios-audit-design-magic-numbers.py` | 自动扫描代码中的魔鬼数字（颜色、尺寸及硬编码常数） |
| `ios-check-design-hig.py` | 校验 Apple HIG 无障碍规范（字号限制、hint 等） |
| `ios-audit-design-token-layering.py` | 校验 3 级设计令牌分层 (3-Tier Tokens) 与平台上下文动态解耦规范 |

### Release (安全与发布就绪)
| 脚本 | 功能说明 |
|------|------|
| `ios-check-release-appstore.py` | 校验提审就绪度（Info.plist 字段、 fatalError 拦截等） |
| `ios-assert-security-hardcoded-secrets.py` | 阻断硬编码密钥、私钥、Token、敏感 IP 或测试域名提审 |

### Sanity (工程健康)
| 脚本 | 功能说明 |
|------|------|
| `ios-check-code-absolute-paths.py` | 阻断代码、配置及脚本中出现的硬编码绝对路径 |
| `scripts-audit-quality-scripts.py` | 校验 Tools/ 脚本圈复杂度 (<=10)、Docstring 函数头及规范性 |
|------|------|
| `scripts-check-dev-root-hygiene.py` | 拦截临时文件及根目录非标结构，维护工作区整洁 |
| `ios-check-design-layout.py` | 检测冲突约束、负 Spacing 及跨平台布局不兼容项 |
| `ios-audit-code-swift-quality.py` | 扫描 Swift 强类型、隐式隐患等代码质量缺陷 |
| `ios-check-code-unsafe-string-index.py` | 扫描 Swift 源码中不安全的 String.Index 偏移调用 |


---

## CI — 持续集成与跑测

### Build (编译构建)
- `ci-build-pipeline-env-prepare.sh`：拉取构建依赖与 SPM 缓存。
- `ci-build-pipeline-platform.sh`：独立构建指定平台的 target 和 scheme。
- `ci-build-pipeline-multi-platform.sh`：本地一键构建 iOS/macOS/watchOS 多平台并收集编译错误。

### Test (自动化测试)
- `ci-run-test-unit.sh`：执行单元测试，自动过滤标记有 `@flaky` 的不稳定用例。
- `ci-run-test-ui.sh`：执行 UI 自动化测试，跳过不稳定用例。
- `ci-run-test-with-coverage.sh`：汇总跑测并触发生命周期门禁。
- `ci-assert-test-coverage.py`：解析 `.xcresult` 报文，强制执行核心 Domain 覆盖率门禁。
- `ci-run-test-progress.sh`：解析 xcodebuild 管道输出，实时格式化当前跑测进度。

### Analyze (静态分析)
- `ci-run-code-static-analysis.sh`：并发执行架构、规范、卫生等 12 项检查。
- `ci-audit-spm-dependencies.py`：审计 Swift Package Manager 依赖库版本安全。
- `ci-check-spm-integrity.sh`：基于哈希校验 SPM 依赖链完整性。
- `ci-generate-spm-sbom-single.py` / `ci-generate-spm-sbom-merged.py`：解析依赖树并生成与 Syft 合并的标准 SBOM。
- `ci-check-security-commit-signature.sh`：校验最近提交的 GPG 签名。
- `ci-check-pipeline-reproducible.sh`：确定性编译输出校验。

### Perf (性能基准)
- `ci-check-perf-regression.py`：将本次测试执行的时间、CPU 等指标同基线进行比对。
- `ci-generate-perf-baseline.sh`：在性能主动优化后，更新本地性能参考基线。

### Notify (告警通知)
- `ci-run-notify-feishu.sh`：向飞书群机器人推送流水线通关/阻断卡片。

---

## 注意事项

- **Python 环境**：运行环境为 `./env/venv/bin/python3`。
- **可执行权限**：所有的 `.sh` 脚本和部分 python 文件需要具备可执行权限（`chmod +x`）。
- **门禁熔断**：任何 Gatekeeper 门禁脚本或 CI 分析脚本在校验失败时，均应以退出状态码 `1` 阻断后续流程。
