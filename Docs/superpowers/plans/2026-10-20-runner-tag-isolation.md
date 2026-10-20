# GitLab Runner Tag 隔离与配置优化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 消除 runner 资源争抢与 tag 冲突，按项目隔离 GitLab CI runner 调度。

**Architecture:** 分阶段过渡——先在 runner 上加新 tag（保留旧 tag），再改项目 CI 指向新 tag，最后清理 runner 旧 tag 和 config.toml。每阶段可独立验证，不会导致 job pending。

**Tech Stack:** GitLab CE 19.5.0 API、gitlab-runner shell/docker executor、TOML 配置、YAML CI 配置。

## Global Constraints

- GitLab API base: `http://localhost:8480`（API 调用用 `127.0.0.1:8480`）
- GitLab API token: `glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk`
- config.toml 路径: `~/.gitlab-runner/config.toml`
- gitlab-runner 服务重启需要 sudo: `sudo gitlab-runner restart`
- 执行顺序铁律：**先加新 tag → 改项目 CI → 再去旧 tag**，避免 job pending
- 4 个项目仓库本地路径：
  - ZhiYu: `/Users/constantine/Documents/work/code/projects/ZhiYu`
  - ZhiYu-Backend: `/Users/constantine/Documents/work/code/projects/ZhiYu-Backend`
  - UTP: `/Users/constantine/Documents/work/code/projects/Uniform-ThirdParty-Platform`
  - UCP: 仅通过 GitLab API 操作（本地无仓库）

---

### Task 1: 备份 config.toml 并确认 runner 现状

**Files:**
- Create: `~/.gitlab-runner/config.toml.bak-20261020`

**Interfaces:**
- Produces: config.toml 备份文件，用于回滚

- [ ] **Step 1: 备份 config.toml**

```bash
cp ~/.gitlab-runner/config.toml ~/.gitlab-runner/config.toml.bak-20261020
```

- [ ] **Step 2: 确认 3 个 runner 的 GitLab API id 和当前 tag**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
for id in 2 3 5; do
  curl -s --header "PRIVATE-TOKEN: $TOKEN" "http://127.0.0.1:8480/api/v4/runners/$id" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"id={d['id']} name={d['description']} tags={d['tag_list']} active={d['active']}\")"
done
```

Expected output:
```
id=2 name=ucp-shell-runner tags=['shell'] active=True
id=3 name=macos-xcode-runner tags=['macos', 'shell', 'xcode', 'arm64', 'zhiyu-ios'] active=True
id=5 name=zhiyu-docker-runner tags=['docker', 'zhiyu', 'ucp'] active=True
```

- [ ] **Step 3: 确认 ZhiYu-Backend 和 UTP 仓库可访问**

```bash
git -C /Users/constantine/Documents/work/code/projects/ZhiYu-Backend remote -v
git -C /Users/constantine/Documents/work/code/projects/Uniform-ThirdParty-Platform remote -v
```

Expected: 两个仓库都显示 origin remote 指向 GitLab。

---

### Task 2: zhiyu-docker-runner 加新 tag（过渡阶段，保留旧 tag）

**Files:**
- 无文件改动，仅 GitLab API 操作

**Interfaces:**
- Produces: zhiyu-docker-runner tag 变为 `[docker, zhiyu, ucp, zhiyu-backend, utp]`（加 2 个新 tag，保留 3 个旧 tag）

**为什么这一步**：先加 `zhiyu-backend` 和 `utp` 新 tag，让 runner 同时匹配新旧 tag 声明。这样后续改项目 CI 时，新 tag 已就绪可匹配；而未改的项目仍用旧 tag 也能匹配。零 pending 风险。

- [ ] **Step 1: 更新 zhiyu-docker-runner tag（加 zhiyu-backend + utp，保留旧 tag）**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
curl -s --request PUT --header "PRIVATE-TOKEN: $TOKEN" \
  "http://127.0.0.1:8480/api/v4/runners/5" \
  --data-urlencode "tag_list=docker,zhiyu,ucp,zhiyu-backend,utp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"tags={d['tag_list']}\")"
```

Expected: `tags=['docker', 'zhiyu', 'ucp', 'zhiyu-backend', 'utp']`

- [ ] **Step 2: 验证 tag 已更新**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
curl -s --header "PRIVATE-TOKEN: $TOKEN" "http://127.0.0.1:8480/api/v4/runners/5" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"tags={d['tag_list']}\")"
```

Expected: `tags=['docker', 'zhiyu', 'ucp', 'zhiyu-backend', 'utp']`

---

### Task 3: UTP 项目 CI tag 改为 [utp]

**Files:**
- Modify: `/Users/constantine/Documents/work/code/projects/Uniform-ThirdParty-Platform/.gitlab-ci.yml`

**Interfaces:**
- Consumes: Task 2 已让 zhiyu-docker-runner 含 `utp` tag
- Produces: UTP CI 用 `[utp]` 匹配 zhiyu-docker-runner

- [ ] **Step 1: 确认 UTP 当前分支和 .gitlab-ci.yml 的 tag 声明**

```bash
git -C /Users/constantine/Documents/work/code/projects/Uniform-ThirdParty-Platform branch --show-current
grep -n "tags:" /Users/constantine/Documents/work/code/projects/Uniform-ThirdParty-Platform/.gitlab-ci.yml
```

Expected: 显示当前分支（应为 dev 或 main）和 `tags: - ucp` 声明位置。

- [ ] **Step 2: 创建功能分支**

```bash
git -C /Users/constantine/Documents/work/code/projects/Uniform-ThirdParty-Platform checkout -b feat/runner-tag-isolation
```

- [ ] **Step 3: 修改 .gitlab-ci.yml 的 tag 从 ucp 改为 utp**

用编辑工具将 `default.tags` 下的 `- ucp` 改为 `- utp`。具体操作：

```bash
# 先查看 default 块的精确内容
grep -A3 "default:" /Users/constantine/Documents/work/code/projects/Uniform-ThirdParty-Platform/.gitlab-ci.yml
```

然后用 edit 工具替换 `- ucp` 为 `- utp`（在 default.tags 上下文中）。

- [ ] **Step 4: 验证改动**

```bash
grep -A3 "default:" /Users/constantine/Documents/work/code/projects/Uniform-ThirdParty-Platform/.gitlab-ci.yml
```

Expected: `tags:` 下显示 `- utp`。

- [ ] **Step 5: Commit 并推送**

```bash
git -C /Users/constantine/Documents/work/code/projects/Uniform-ThirdParty-Platform add .gitlab-ci.yml
git -C /Users/constantine/Documents/work/code/projects/Uniform-ThirdParty-Platform commit -m "ci: UTP runner tag 从 ucp 改为 utp 实现项目隔离"
git -C /Users/constantine/Documents/work/code/projects/Uniform-ThirdParty-Platform push -u origin feat/runner-tag-isolation
```

- [ ] **Step 6: 触发 UTP pipeline 验证 job 匹配 zhiyu-docker-runner**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
# 触发 pipeline
PIPELINE=$(curl -s --request POST --header "PRIVATE-TOKEN: $TOKEN" \
  "http://127.0.0.1:8480/api/v4/projects/11/trigger/pipeline" \
  --data-urlencode "ref=feat/runner-tag-isolation" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id','FAIL'))")
echo "Pipeline ID: $PIPELINE"
```

等待 1 分钟后检查 job 是否匹配到 runner（非 pending）：

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
curl -s --header "PRIVATE-TOKEN: $TOKEN" "http://127.0.0.1:8480/api/v4/projects/11/pipelines/$PIPELINE/jobs" | python3 -c "
import sys,json
for j in json.load(sys.stdin):
    r=j.get('runner') or {}
    print(f\"  {j['name']:20} status={j['status']:10} runner={r.get('description','PENDING')}\")"
```

Expected: job 的 runner 显示 `zhiyu-docker-runner`，status 不是 `pending`（应为 running 或 success）。

---

### Task 4: ZhiYu-Backend CI tag 改为 [zhiyu-backend]

**Files:**
- Modify: `/Users/constantine/Documents/work/code/projects/ZhiYu-Backend/.gitlab-ci.yml`（test-browser-frontend job 的 tags）
- Modify: `/Users/constantine/Documents/work/code/projects/ZhiYu-Backend/.gitlab/ci/online-pipeline.yml`（default.tags）
- Modify: `/Users/constantine/Documents/work/code/projects/ZhiYu-Backend/.gitlab/ci/offline-pipeline.yml`（default.tags）

**Interfaces:**
- Consumes: Task 2 已让 zhiyu-docker-runner 含 `zhiyu-backend` tag
- Produces: ZhiYu-Backend 所有 job 用 `[zhiyu-backend]` 匹配 zhiyu-docker-runner

- [ ] **Step 1: 确认 ZhiYu-Backend 当前分支和 3 个文件的 tag 声明**

```bash
git -C /Users/constantine/Documents/work/code/projects/ZhiYu-Backend branch --show-current
echo "=== .gitlab-ci.yml ==="
grep -n "tags:" /Users/constantine/Documents/work/code/projects/ZhiYu-Backend/.gitlab-ci.yml
echo "=== online-pipeline.yml ==="
grep -n "tags:" /Users/constantine/Documents/work/code/projects/ZhiYu-Backend/.gitlab/ci/online-pipeline.yml
echo "=== offline-pipeline.yml ==="
grep -n "tags:" /Users/constantine/Documents/work/code/projects/ZhiYu-Backend/.gitlab/ci/offline-pipeline.yml
```

Expected: 3 个文件都显示 `tags: [docker, zhiyu]`。

- [ ] **Step 2: 创建功能分支**

```bash
git -C /Users/constantine/Documents/work/code/projects/ZhiYu-Backend checkout -b feat/runner-tag-isolation
```

- [ ] **Step 3: 修改 .gitlab/ci/online-pipeline.yml 的 default.tags**

用 edit 工具将 `tags: [docker, zhiyu]` 改为 `tags: [zhiyu-backend]`。

- [ ] **Step 4: 修改 .gitlab/ci/offline-pipeline.yml 的 default.tags**

用 edit 工具将 `tags: [docker, zhiyu]` 改为 `tags: [zhiyu-backend]`。

- [ ] **Step 5: 修改 .gitlab-ci.yml 的 test-browser-frontend job tags**

用 edit 工具将 `tags: [docker, zhiyu]` 改为 `tags: [zhiyu-backend]`。

- [ ] **Step 6: 验证 3 个文件的改动**

```bash
echo "=== .gitlab-ci.yml ==="
grep "tags:" /Users/constantine/Documents/work/code/projects/ZhiYu-Backend/.gitlab-ci.yml
echo "=== online-pipeline.yml ==="
grep "tags:" /Users/constantine/Documents/work/code/projects/ZhiYu-Backend/.gitlab/ci/online-pipeline.yml
echo "=== offline-pipeline.yml ==="
grep "tags:" /Users/constantine/Documents/work/code/projects/ZhiYu-Backend/.gitlab/ci/offline-pipeline.yml
```

Expected: 3 个文件都显示 `tags: [zhiyu-backend]`。

- [ ] **Step 7: Commit 并推送**

```bash
git -C /Users/constantine/Documents/work/code/projects/ZhiYu-Backend add .gitlab-ci.yml .gitlab/ci/online-pipeline.yml .gitlab/ci/offline-pipeline.yml
git -C /Users/constantine/Documents/work/code/projects/ZhiYu-Backend commit -m "ci: Backend runner tag 从 docker,zhiyu 改为 zhiyu-backend 实现项目隔离"
git -C /Users/constantine/Documents/work/code/projects/ZhiYu-Backend push -u origin feat/runner-tag-isolation
```

- [ ] **Step 8: 触发 ZhiYu-Backend pipeline 验证 job 匹配 zhiyu-docker-runner**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
PIPELINE=$(curl -s --request POST --header "PRIVATE-TOKEN: $TOKEN" \
  "http://127.0.0.1:8480/api/v4/projects/7/pipeline" \
  --data-urlencode "ref=feat/runner-tag-isolation" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id','FAIL'))")
echo "Pipeline ID: $PIPELINE"
```

等待 1 分钟后检查 job 是否匹配到 runner：

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
curl -s --header "PRIVATE-TOKEN: $TOKEN" "http://127.0.0.1:8480/api/v4/projects/7/pipelines/$PIPELINE/jobs?per_page=10" | python3 -c "
import sys,json
for j in json.load(sys.stdin)[:5]:
    r=j.get('runner') or {}
    print(f\"  {j['name']:25} status={j['status']:10} runner={r.get('description','PENDING')}\")"
```

Expected: job 的 runner 显示 `zhiyu-docker-runner`，status 不是 `pending`。

---

### Task 5: zhiyu-docker-runner 清理旧 tag（去掉 docker/zhiyu）

**Files:**
- 无文件改动，仅 GitLab API 操作

**Interfaces:**
- Consumes: Task 3（UTP 已用 utp）和 Task 4（Backend 已用 zhiyu-backend）完成
- Produces: zhiyu-docker-runner tag 最终为 `[zhiyu-backend, ucp, utp]`

**为什么这一步**：项目 CI 已改完，旧 tag `docker`/`zhiyu` 不再被任何项目使用，可安全移除。

- [ ] **Step 1: 更新 zhiyu-docker-runner tag 为最终值**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
curl -s --request PUT --header "PRIVATE-TOKEN: $TOKEN" \
  "http://127.0.0.1:8480/api/v4/runners/5" \
  --data-urlencode "tag_list=zhiyu-backend,ucp,utp" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"tags={d['tag_list']}\")"
```

Expected: `tags=['zhiyu-backend', 'ucp', 'utp']`

- [ ] **Step 2: 验证 tag 已更新**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
curl -s --header "PRIVATE-TOKEN: $TOKEN" "http://127.0.0.1:8480/api/v4/runners/5" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"tags={d['tag_list']}\")"
```

Expected: `tags=['zhiyu-backend', 'ucp', 'utp']`

---

### Task 6: macos-xcode-runner tag 改为 [zhiyu-ios]

**Files:**
- 无文件改动，仅 GitLab API 操作

**Interfaces:**
- Produces: macos-xcode-runner tag 为 `[zhiyu-ios]`

- [ ] **Step 1: 更新 macos-xcode-runner tag**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
curl -s --request PUT --header "PRIVATE-TOKEN: $TOKEN" \
  "http://127.0.0.1:8480/api/v4/runners/3" \
  --data-urlencode "tag_list=zhiyu-ios" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"tags={d['tag_list']}\")"
```

Expected: `tags=['zhiyu-ios']`

- [ ] **Step 2: 验证 tag 已更新**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
curl -s --header "PRIVATE-TOKEN: $TOKEN" "http://127.0.0.1:8480/api/v4/runners/3" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"tags={d['tag_list']}\")"
```

Expected: `tags=['zhiyu-ios']`

---

### Task 7: 删除 ucp-shell-runner

**Files:**
- 无文件改动，GitLab API 删除 + config.toml 移除（Task 8 一起做）

**Interfaces:**
- Produces: ucp-shell-runner 从 GitLab 注销

- [ ] **Step 1: 确认 ucp-shell-runner 无活跃 job**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
curl -s --header "PRIVATE-TOKEN: $TOKEN" "http://127.0.0.1:8480/api/v4/runners/2/jobs?per_page=5" | python3 -c "
import sys,json
arr=json.load(sys.stdin)
running=[j for j in arr if j['status'] in ('running','pending')]
if running:
    print(f'WARNING: {len(running)} 个活跃 job，暂不可删除')
    for j in running: print(f\"  {j['name']} status={j['status']}\")
else:
    print('无活跃 job，可安全删除')"
```

Expected: `无活跃 job，可安全删除`

- [ ] **Step 2: 通过 GitLab API 删除 runner**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
curl -s --request DELETE --header "PRIVATE-TOKEN: $TOKEN" "http://127.0.0.1:8480/api/v4/runners/2" -w "\nHTTP_STATUS: %{http_code}\n"
```

Expected: `HTTP_STATUS: 204`（No Content，删除成功）

- [ ] **Step 3: 验证 runner 已删除**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
curl -s --header "PRIVATE-TOKEN: $TOKEN" "http://127.0.0.1:8480/api/v4/runners/2" -w "\nHTTP_STATUS: %{http_code}\n"
```

Expected: `HTTP_STATUS: 404`（Not Found）

---

### Task 8: 修改 config.toml（concurrent + clone_url + 移除 ucp-shell-runner）

**Files:**
- Modify: `~/.gitlab-runner/config.toml`

**Interfaces:**
- Consumes: Task 7 已从 GitLab 删除 ucp-shell-runner
- Produces: config.toml 反映最终状态——concurrent=1、macos-xcode-runner 有 clone_url、无 ucp-shell-runner 块

- [ ] **Step 1: 修改 concurrent 从 2 改为 1**

用 edit 工具将 `concurrent = 2` 改为 `concurrent = 1`。

- [ ] **Step 2: 给 macos-xcode-runner 加 clone_url**

用 edit 工具在 macos-xcode-runner 的 `executor = "shell"` 行后加 `clone_url = "http://127.0.0.1:8480"`。

具体：将
```toml
  executor = "shell"
  [runners.cache]
```
改为
```toml
  executor = "shell"
  clone_url = "http://127.0.0.1:8480"
  [runners.cache]
```

注意：只改 macos-xcode-runner 的块（第二个 `[[runners]]`），不改 zhiyu-docker-runner 的。

- [ ] **Step 3: 移除 ucp-shell-runner 的整个 [[runners]] 块**

用 edit 工具删除从 `[[runners]]`（第一个，name = "ucp-shell-runner"）到下一个 `[[runners]]` 之前的所有内容。

具体：删除从
```toml
[[runners]]
  name = "ucp-shell-runner"
```
到
```toml
    [runners.cache.azure]

```
（即 zhiyu-docker-runner 块开始前）的整段。

- [ ] **Step 4: 验证 config.toml 最终内容**

```bash
cat ~/.gitlab-runner/config.toml
```

Expected:
- 首行 `concurrent = 1`
- 只有 2 个 `[[runners]]` 块：macos-xcode-runner（含 clone_url）和 zhiyu-docker-runner
- 无 ucp-shell-runner 块

- [ ] **Step 5: 验证 TOML 语法正确**

```bash
gitlab-runner verify
```

Expected: 显示 2 个 runner 配置有效，无语法错误。

---

### Task 9: 重启 gitlab-runner 服务并验证

**Files:**
- 无文件改动

**Interfaces:**
- Consumes: Task 8 config.toml 已更新
- Produces: gitlab-runner 服务以新配置运行

- [ ] **Step 1: 重启 gitlab-runner（需要 sudo）**

```bash
sudo gitlab-runner restart
```

注意：此命令需要 sudo 权限，会提示输入密码。如果非交互终端无法输入密码，需用户手动执行。

- [ ] **Step 2: 验证 runner 服务状态**

```bash
gitlab-runner status
```

Expected: `Runtime platform: ...` + 服务运行中。

- [ ] **Step 3: 验证 2 个 runner 在 GitLab 上在线**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
for id in 3 5; do
  curl -s --header "PRIVATE-TOKEN: $TOKEN" "http://127.0.0.1:8480/api/v4/runners/$id" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"id={d['id']} name={d['description']} tags={d['tag_list']} contacted={d.get('contacted_at','')[:19]}\")"
done
```

Expected: 2 个 runner 都显示最近的 contacted_at 时间（重启后应刚联系过）。

---

### Task 10: ZhiYu 加 default.timeout

**Files:**
- Modify: `/Users/constantine/Documents/work/code/projects/ZhiYu/.gitlab-ci.yml`

**Interfaces:**
- Produces: ZhiYu CI 有 `default.timeout: 1h` 兜底

- [ ] **Step 1: 确认当前 default 块内容**

```bash
grep -A5 "default:" /Users/constantine/Documents/work/code/projects/ZhiYu/.gitlab-ci.yml
```

Expected: 显示 `tags:` 下有 `- zhiyu-ios`（MR 分支已改）。

- [ ] **Step 2: 在 default 块加 timeout: 1h**

用 edit 工具在 `default:` 块的 `tags:` 后加 `timeout: 1h`。

具体：将
```yaml
default:
  tags:
    - zhiyu-ios
```
改为
```yaml
default:
  tags:
    - zhiyu-ios
  timeout: 1h
```

- [ ] **Step 3: 验证改动**

```bash
grep -A6 "default:" /Users/constantine/Documents/work/code/projects/ZhiYu/.gitlab-ci.yml
```

Expected: 显示 `timeout: 1h`。

- [ ] **Step 4: Commit**

```bash
git add .gitlab-ci.yml
git commit -m "ci: ZhiYu 加 default.timeout 1h 兜底防卡死"
```

---

### Task 11: 全量验证——触发各项目 pipeline 确认 runner 匹配

**Files:**
- 无文件改动，仅验证

**Interfaces:**
- Consumes: 所有前置 Task 完成
- Produces: 确认 4 个项目的 CI job 都正确匹配到目标 runner，无 pending

- [ ] **Step 1: 触发 ZhiYu pipeline 并验证 job 匹配 macos-xcode-runner**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
PIPELINE=$(curl -s --request POST --header "PRIVATE-TOKEN: $TOKEN" \
  "http://127.0.0.1:8480/api/v4/projects/6/pipeline" \
  --data-urlencode "ref=common-capability-extraction" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id','FAIL'))")
echo "ZhiYu Pipeline ID: $PIPELINE"
```

等待 2 分钟后检查：

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
curl -s --header "PRIVATE-TOKEN: $TOKEN" "http://127.0.0.1:8480/api/v4/projects/6/pipelines/$PIPELINE/jobs?per_page=10" | python3 -c "
import sys,json
for j in json.load(sys.stdin)[:5]:
    r=j.get('runner') or {}
    print(f\"  {j['name']:25} status={j['status']:10} runner={r.get('description','PENDING')}\")"
```

Expected: job 的 runner 显示 `macos-xcode-runner`，无 pending。

- [ ] **Step 2: 触发 UCP pipeline 并验证 job 匹配 zhiyu-docker-runner**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
PIPELINE=$(curl -s --request POST --header "PRIVATE-TOKEN: $TOKEN" \
  "http://127.0.0.1:8480/api/v4/projects/9/pipeline" \
  --data-urlencode "ref=dev" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id','FAIL'))")
echo "UCP Pipeline ID: $PIPELINE"
```

等待 1 分钟后检查：

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
curl -s --header "PRIVATE-TOKEN: $TOKEN" "http://127.0.0.1:8480/api/v4/projects/9/pipelines/$PIPELINE/jobs?per_page=10" | python3 -c "
import sys,json
for j in json.load(sys.stdin)[:5]:
    r=j.get('runner') or {}
    print(f\"  {j['name']:25} status={j['status']:10} runner={r.get('description','PENDING')}\")"
```

Expected: job 的 runner 显示 `zhiyu-docker-runner`，无 pending。

- [ ] **Step 3: 确认最终 runner 状态汇总**

```bash
TOKEN="glpat-MLshMOP3pK2iuZpcfkKkJW86MQp1OnkH.01.0w1446yxk"
echo "=== 最终 Runner 状态 ==="
for id in 3 5; do
  curl -s --header "PRIVATE-TOKEN: $TOKEN" "http://127.0.0.1:8480/api/v4/runners/$id" | python3 -c "import sys,json; d=json.load(sys.stdin); print(f\"  {d['description']:25} tags={d['tag_list']}\")"
done
echo "  ucp-shell-runner: 已删除"
echo ""
echo "=== concurrent ==="
grep "^concurrent" ~/.gitlab-runner/config.toml
```

Expected:
```
=== 最终 Runner 状态 ===
  macos-xcode-runner        tags=['zhiyu-ios']
  zhiyu-docker-runner       tags=['zhiyu-backend', 'ucp', 'utp']
  ucp-shell-runner: 已删除

=== concurrent ===
concurrent = 1
```

---

## 回滚步骤

如果任何阶段出现问题，按以下顺序回滚：

1. **config.toml 回滚**：`cp ~/.gitlab-runner/config.toml.bak-20261020 ~/.gitlab-runner/config.toml && sudo gitlab-runner restart`
2. **Runner tag 回滚**：通过 GitLab API `PUT /runners/:id` 改回原 tag
3. **项目 CI 回滚**：`git revert <commit>` 或 `git reset --hard <prev-commit>`
4. **ucp-shell-runner 恢复**：需重新注册 `gitlab-runner register`（token 已失效，需在 GitLab 创建新 runner）
