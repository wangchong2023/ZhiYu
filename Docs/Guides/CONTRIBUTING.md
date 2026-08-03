# 智宇 (ZhiYu) 开发者贡献指南 (Contributing Guidelines)

本指南旨在帮助外部与内部开发者快速构建智宇应用，并遵循统一的开发、测试与代码审查流程。

---

## 1. 环境搭建 (Setup)

```bash
# 克隆仓库并进入物理路径
git clone <repo-url> && cd ZhiYu

# 安装 XcodeGen 与 SwiftLint 工具
brew install xcodegen swiftlint

# 从 project.yml 自动生成 Xcode 项目（所有配置变更后必须执行）
xcodegen generate

# 打开生成的 Xcode 工程
open ZhiYu.xcodeproj
```

**系统要求**：Xcode 16+，Swift 6 (开启严格并发检查)，macOS 14+。

---

## 2. 构建与测试 (Build & Test)

```bash
# 1. 构建 iOS 模拟器版本
xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

# 2. 构建 macOS Catalyst 版本
xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYuMac -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

# 3. 运行全部单元与集成测试套件并开启覆盖率生成
xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -enableCodeCoverage YES

# 4. 运行指定测试类 (例如 FTS 检索专项测试)
xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ZhiYuTests/KnowledgeRepositoryTests

# 5. 执行静态代码分析
swiftlint --strict
```

---

## 3. 代码规范 (Coding Standards)

*   **垂直架构与归位**：遵循智宇垂直化功能架构 (L0 ──► L3)。Views 层严禁直接依赖 Infrastructure 层的实现，必须通过 DI 依赖注入在 `Protocols/` 定义的契约接口。
*   **并发安全 (Swift 6)**：启用 `SWIFT_STRICT_CONCURRENCY: complete`。优先使用 `async/await` 和 `actor`，严禁使用传统锁 (Locks) 或信号量同步阻塞主线程。UI 逻辑强制绑定 `@MainActor`。
*   **注释与文档**：
    *   **统一使用简体中文**书写所有注释。
    *   **/// 文档注释**：解释“为什么”，用于公开 API。
    *   **// 实现注释**：解释“怎么做”，用于复杂算法过程。
    *   使用 `// MARK: - 中文标题` 进行模块逻辑分区。
*   **UI 规范**：所有 SwiftUI 组件必须完美适配 Dark Mode，支持 Dynamic Type 动态字体缩放，并在 iPad/Mac 分屏视图中完成自适应布局测试。

---

## 4. 分支管理与 Git 工作流 (Git Branching & Merge Policy)

智宇全面遵循与 `ZhiYu-Backend` 保持 100% 一致的 Git 分支合入与卡控管理办法，完整规范见 [`CI_CD_WORKFLOW.md §3`](../Architecture/CI_CD_WORKFLOW.md#3-分支策略与-mr-合流强卡控-git-branching--branch-protection-rules)：

### 4.1 分支命名规范
* `main`: **绝对受控与稳定的生产主分支（严禁直接 `git push`）**。
* `feature/<description>`: 新增功能分支（如 `feature/voice-note`）。
* `fix/<issue-id>`: 缺陷与 Crash 修复分支（如 `fix/token-expired`）。
* `refactor/<description>`: 不改变业务行为的代码重构分支（如 `refactor/project-template`）。
* `docs/<description>`: 纯文档及注释变更分支。
* `test/<description>`: 测试用例或 CI 流水线调试分支。
* `hotfix/<description>`: 生产紧急热修复分支。
* `release/v<version>`: 版本发布分支（如 `release/v2.3.0`）。

### 4.2 分支保护与 MR (Merge Request) 合入卡控
1. **禁止直推 `main` (`push_access_level: No one`)**：所有代码变更必须在特性分支提交，并向 `main` 发起 MR / PR。
2. **流水线全绿方可合并 (`only_allow_merge_if_pipeline_succeeds: true`)**：提交 MR 后自动触发 GitLab CI。必须通过 7 大 Gatekeeper 门禁和全量编译测试，Merge 按钮才允许点击。
3. **Maintainer 代码审查**：MR 必须经过至少 1 位 Maintainer 审查通过后方可合并。
4. **禁止强推 (`allow_force_push: false`)**：主分支禁用 force push，确保版本演进历史完整追溯。

---

## 5. 提交规范 (Commit Messages)

智宇强制采用 Conventional Commits 规范，所有 commit 必须使用如下前缀：
*   `feat:` 新功能的实装。
*   `fix:` 缺陷与闪退的修复。
*   `docs:` 文档及注释的变更。
*   `refactor:` 不改变业务行为的代码重构。
*   `perf:` 性能与算法瓶颈优化。
*   `test:` 测试用例的补齐与 UI 测试扩充。

---

## 6. 代码审查与合并门禁 (Code Review)

### 6.1 开发者自检清单
在提交 Pull Request (PR) 前，请开发者确保：
- [ ] 本地编译零 Error 且无任何 Static Concurrency Concurrency Conformance 警告。
- [ ] `swiftlint --strict` 零警报通过。
- [ ] 逻辑修改已补齐对应的 `XCTest` 单元测试或 `ZhiYuUITests` UI 冒烟测试。
- [ ] **流水线门禁校验**：核心领域层 (Domain) 的汇总测试覆盖率不低于 **85%**（合并前必须通过 `python3 Tools/ci/assert-test-coverage.py` 熔断脚本校验）。
- [ ] 移除所有残留的调试用 `print()`。

### 6.2 门禁防线三阶段
PR 提交后，CI/CD 系统将自动拉起三阶段防御体系：
1. **L1 静态拦截**：执行静态 SwiftLint 代码审计和项目构建合法性检查。
2. **L2 单元与集成测试**：自动跑测 FTS5 混合召回、多金库 WAL 事务隔离测试，确保 100% 绿通。
3. **L3 覆盖率熔断门禁**：自动抽取最新的 `.xcresult`，验证领域层代码覆盖率是否通过 85% 门禁大关。
