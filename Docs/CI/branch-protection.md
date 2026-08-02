# GitHub 分支保护规则

> 配置日期: 2026-06-14 | 配置方式: GitHub Web UI

## main 分支保护规则

在 `https://github.com/wangchong2023/ZhiYu/settings/branches` 配置：

### Branch name pattern
`main`

### Protect matching branches
- [x] Require a pull request before merging
  - [x] Require approvals: 1
  - [x] Dismiss stale pull request approvals when new commits are pushed
- [x] Require status checks to pass before merging
  - [x] Require branches to be up to date before merging
  - Status checks:
    - `ci / lint-and-audit`
    - `ci / test`
    - `ci / multi-platform (iOS)`
- [x] Require conversation resolution before merging
- [x] Do not allow bypassing the above settings
  - [x] Include administrators

## GitLab CE 等效分支保护配置

通过 GitLab REST API 部署 `main` 强卡控：

```bash
# 1. 开启流水线全绿方可合并 (only_allow_merge_if_pipeline_succeeds)
curl -X PUT "http://127.0.0.1:8480/api/v4/projects/constantine%2FZhiYu" \
  -H "PRIVATE-TOKEN: $GITLAB_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "only_allow_merge_if_pipeline_succeeds": true
  }'

# 2. 配置 main 分支保护 (禁止直推、强制 MR、禁止 Force Push)
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

## 验证

```bash
# GitHub
gh api repos/wangchong2023/ZhiYu/branches/main/protection

# GitLab CE
curl -H "PRIVATE-TOKEN: $GITLAB_TOKEN" http://127.0.0.1:8480/api/v4/projects/constantine%2FZhiYu/protected_branches
```
