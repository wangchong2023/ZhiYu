# 智宇 (ZhiYu) Git 分支管理与 MR 合入合规规范

> 版本: v1.0.0 | 生效日期: 2026-08-02 | 参照标准: `ZhiYu-Backend` 统一工程合规标准

---

## 1. 概述与核心原则

为保证智宇 iOS/macOS/watchOS 客户端与 `ZhiYu-Backend` 服务端在协作开发中的高质量交付与生命周期受控，全仓库强制实施统一的 **Git 分支管理与 Merge Request (MR) 强卡控合规规范**。

### 四大核心原则
1. **主分支绝对受控 (Main Branch SSOT)**：`main` 分支为唯一的生产受控分支，禁止任何人直接 `git push main`。
2. **分支职责规范化 (Structured Naming)**：所有开发、修复、重构均在独立的前缀特性分支中进行。
3. **卡控流水线强依赖 (Gated Integration)**：合入 `main` 前必须跑通全部 18+ 项 Gatekeeper 审计门禁与单元测试。
4. **评审责任留痕 (Traceable Code Review)**：MR 须经至少 1 位 Maintainer 审查认可，并清理全部 Discussion 之后方可合入。

---

## 2. 分支命名与生命周期规范

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

---

## 3. MR (Merge Request) 合流卡控标准

针对所有向 `main` 发起的 MR / PR，系统将在 GitLab CE / GitHub 平台侧执行以下强制约束：

```
                          ┌────────────────────────┐
                          │ 开发者在特性分支开发   │
                          │ feature/voice-note     │
                          └───────────┬────────────┘
                                      │
                                      ▼ git push
                          ┌────────────────────────┐
                          │ 发起 Merge Request (MR)│
                          └───────────┬────────────┘
                                      │
           ┌──────────────────────────┴──────────────────────────┐
           ▼                                                     ▼
┌───────────────────────┐                             ┌───────────────────────┐
│  GitLab CI 流水线     │                             │  Maintainer Review    │
│  - SPM 极速单测      │                             │  - 检查架构单向依赖   │
│  - Gatekeeper 18 项   │                             │  - 检查 L10n/Token 规约│
│  - xcodebuild test    │                             │  - 解决全部 inline    │
│  - 覆盖率 > 85% 门禁  │                             │    comment            │
└──────────┬────────────┘                             └───────────┬───────────┘
           │                                                     │
           │ (流水线全绿)                                         │ (Approve)
           └──────────────────────────┬──────────────────────────┘
                                      │
                                      ▼
                        ┌───────────────────────────┐
                        │  Maintainer 点击 [Merge]  │
                        │  合入 main 主分支         │
                        └───────────────────────────┘
```

### 3.1 四重硬卡控配置 (Hard Gates)
1. **`push_access_level: No one`**：全员禁止直接 `git push` 到 `main`。
2. **`only_allow_merge_if_pipeline_succeeds: true`**：流水线未 100% 绿通前，MR 合并按钮强制锁定禁用。
3. **`merge_access_level: Maintainers`**：仅 Maintainer 角色拥有点击合并页面权限。
4. **`allow_force_push: false`**：强行覆盖分支历史 (`git push -f`) 被平台底层直接拦截拒绝。

---

## 4. 平台分支保护自动化部署 (API 指引)

仓库维护者可使用以下 API 脚本对 GitHub / GitLab CE 部署一致的分支卡控：

### GitLab CE (REST API)
```bash
# 1. 部署项目级 MR 卡控
curl -X PUT "http://127.0.0.1:8480/api/v4/projects/constantine%2FZhiYu" \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"only_allow_merge_if_pipeline_succeeds": true}'

# 2. 部署 main 保护规则
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

## 5. 相关文档与关联规范

* 表现层与领域层分层规范：[`Docs/Architecture/LAYERING_L0_L3.md`](file:///Users/constantine/Documents/work/code/projects/ZhiYu/Docs/Architecture/LAYERING_L0_L3.md)
* 持续集成与交付流程：[`Docs/Architecture/CI_CD_WORKFLOW.md`](file:///Users/constantine/Documents/work/code/projects/ZhiYu/Docs/Architecture/CI_CD_WORKFLOW.md)
* 开发者贡献与自检指南：[`Docs/Guides/CONTRIBUTING.md`](file:///Users/constantine/Documents/work/code/projects/ZhiYu/Docs/Guides/CONTRIBUTING.md)
* 主分支卡控细则：[`Docs/CI/branch-protection.md`](file:///Users/constantine/Documents/work/code/projects/ZhiYu/Docs/CI/branch-protection.md)
