# 智宇 (ZhiYu) 主分支保护与卡控规范

> 配置日期: 2026-06-14 | 适用环境: GitHub Web UI & GitLab CE REST API

---

## 1. GitHub 主分支 (main) 保护配置

在 `https://github.com/wangchong2023/ZhiYu/settings/branches` 中配置如下规则：

### 匹配分支名称
`main`

### 保护匹配分支策略
- [x] **合并前必须提交 Pull Request (MR/PR)**
  - [x] **必须至少 1 人审核通过 (Require approvals: 1)**
  - [x] **当有新提交推送时自动撤销旧的审核通过状态**
- [x] **合并前必须通过所有状态检查 (Status Checks)**
  - [x] **合并前分支必须保持最新**
  - **必选卡控流水线：**
    - `ci / lint-and-audit` (静态检查与 Gatekeeper 审计)
    - `ci / test` (单元测试与覆盖率熔断)
    - `ci / multi-platform (iOS/macOS/watchOS)` (全平台编译)
- [x] **合并前必须解决所有代码讨论/评论 (Conversation Resolution)**
- [x] **严禁任何人绕过上述卡控设置 (包含管理员权限)**

---

## 2. GitLab CE 等效分支保护配置 (REST API)

通过 GitLab REST API 对 `main` 主分支部署自动化强卡控：

```bash
# 1. 开启流水线全绿方可合并 (only_allow_merge_if_pipeline_succeeds)
curl -X PUT "http://127.0.0.1:8480/api/v4/projects/constantine%2FZhiYu" \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "only_allow_merge_if_pipeline_succeeds": true
  }'

# 2. 配置 main 分支保护 (禁止直接 Push、强制走 MR、禁止 Force Push)
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

## 3. 分支保护规则验证命令

```bash
# 校验 GitHub 保护状态
gh api repos/wangchong2023/ZhiYu/branches/main/protection

# 校验 GitLab CE 保护状态
curl -H "PRIVATE-TOKEN: $GITLAB_TOKEN" http://127.0.0.1:8480/api/v4/projects/constantine%2FZhiYu/protected_branches
```

