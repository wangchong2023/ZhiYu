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

### Task 12: 更新 ZhiYu 仓库 CI_CD_WORKFLOW.md 文档

**Files:**
- Modify: `Docs/Architecture/CI_CD_WORKFLOW.md`（3 处）

**Interfaces:**
- Consumes: 所有 runner tag 改动已完成
- Produces: 架构文档反映最终 runner 配置

- [ ] **Step 1: 更新架构图中的 runner 名称和 tag（Line 33-34）**

用 edit 工具将：
```
│ macOS Shell Runner       │
│ tags: macos,shell,xcode  │
```
改为：
```
│ macOS Xcode Runner       │
│ tags: zhiyu-ios          │
```

- [ ] **Step 2: 更新 Runner 组件表（Line 63）**

用 edit 工具将：
```
| **GitLab Runner** | macOS launchd 原生服务 | `macos-shell-runner` | 执行 iOS/macOS/watchOS 构建与测试 |
```
改为：
```
| **GitLab Runner** | macOS launchd 原生服务 | `macos-xcode-runner`（tags: `zhiyu-ios`） | 执行 iOS/macOS/watchOS 构建与测试 |
```

- [ ] **Step 3: 更新排障指南的 tag 描述（Line 372）**

用 edit 工具将：
```
| Agent 未接管任务 | 标签不匹配 | 确认 Runner `tags: macos,shell,xcode` 与 `.gitlab-ci.yml` job `tags` 一致 |
```
改为：
```
| Agent 未接管任务 | 标签不匹配 | 确认 Runner `tags: zhiyu-ios` 与 `.gitlab-ci.yml` job `tags` 一致 |
```

- [ ] **Step 4: 验证改动**

```bash
grep -n "macos,shell,xcode\|macos-shell-runner" Docs/Architecture/CI_CD_WORKFLOW.md
```

Expected: 无输出（旧 tag 和旧名称已全部替换）。

- [ ] **Step 5: Commit**

```bash
git add Docs/Architecture/CI_CD_WORKFLOW.md
git commit -m "docs: CI_CD_WORKFLOW 更新 runner tag 为 zhiyu-ios 并修正 runner 名称"
```

---

### Task 13: 更新 ZhiYu-Backend 仓库 ci-cd.md 文档

**Files:**
- Modify: `/Users/constantine/Documents/work/code/projects/ZhiYu-Backend/docs/2-how-to/ci-cd.md`（Runner 标签匹配规则表 + 配置文件表）

**Interfaces:**
- Consumes: Task 4 已改 ZhiYu-Backend CI tag，Task 6 已改 macos-xcode-runner tag
- Produces: Backend 文档反映最终 runner 配置

- [ ] **Step 1: 更新 Runner 标签匹配规则表（Line 299-300）**

用 edit 工具将：
```
| Runner 1 (`macos-shell-runner`) | `macos, shell, xcode, arm64` | ZhiYu Swift iOS 编译与测试 |
| Runner 2 (`local-runner`) | *(无特异标签，默认)* | ZhiYu-Backend 容器化流水线 |
```
改为：
```
| Runner 1 (`macos-xcode-runner`) | `zhiyu-ios` | ZhiYu Swift iOS/macOS/watchOS 编译与测试 |
| Runner 2 (`zhiyu-docker-runner`) | `zhiyu-backend` | ZhiYu-Backend 容器化流水线 |
```

- [ ] **Step 2: 更新配置文件表（Line 306-307）**

用 edit 工具将：
```
| Runner 1 | `/Users/constantine/.gitlab-runner/config.toml` | `brew services log gitlab-runner` |
| Runner 2 | `/Users/constantine/devs/rnd-cicd/gitlab/runner-config/config.toml` | `docker logs rnd-cicd-gitlab-runner-1` |
```
改为：
```
| Runner 1 | `/Users/constantine/.gitlab-runner/config.toml` | `brew services log gitlab-runner` |
| Runner 2 | `/Users/constantine/.gitlab-runner/config.toml` | `brew services log gitlab-runner` |
```

注意：两个 runner 现在都在同一个 config.toml 中（zhiyu-docker-runner 是 docker executor，但配置文件与 macos-xcode-runner 同路径）。

- [ ] **Step 3: 验证改动**

```bash
grep -n "macos-shell-runner\|local-runner" /Users/constantine/Documents/work/code/projects/ZhiYu-Backend/docs/2-how-to/ci-cd.md
```

Expected: 无输出（旧 runner 名称已全部替换）。

- [ ] **Step 4: Commit 并推送**

```bash
git -C /Users/constantine/Documents/work/code/projects/ZhiYu-Backend add docs/2-how-to/ci-cd.md
git -C /Users/constantine/Documents/work/code/projects/ZhiYu-Backend commit -m "docs: ci-cd 更新 runner 标签匹配规则为项目专属 tag"
git -C /Users/constantine/Documents/work/code/projects/ZhiYu-Backend push
```

---

### Task 14: 更新 rnd-cicd 仓库 README 和 Runner 注册脚本/模板

**Files:**
- Modify: `/Users/constantine/Documents/work/rnd-env/rnd-cicd/README.md`（Runner 注册章节 + 新增 tag 命名规范）
- Modify: `/Users/constantine/Documents/work/rnd-env/rnd-cicd/.env.example`（Runner tag 默认值）
- Modify: `/Users/constantine/Documents/work/rnd-env/rnd-cicd/tools/register-runners.sh`（默认 tag + 移除 ucp 注册函数）
- Modify: `/Users/constantine/Documents/work/rnd-env/rnd-cicd/gitlab/runner-config/config.toml.template`（concurrent + tag 注释 + 移除 ucp-shell-runner 块）

**Interfaces:**
- Consumes: 所有 runner tag 改动已完成（Task 2-9）
- Produces: rnd-cicd 基础设施仓库反映最终 runner 配置 + tag 命名规范文档

**为什么这一步**：rnd-cicd 是 CI/CD 基础设施的 SSOT 仓库，`register-runners.sh` 和 `config.toml.template` 是重建 runner 时的源头。如果不同步更新，未来重建基础设施会用旧 tag 重新注册 runner，导致回退。

- [ ] **Step 1: 更新 .env.example 的 Runner tag 默认值**

用 edit 工具将：
```
ZHIYU_RUNNER_TAGS="docker,zhiyu"
```
改为：
```
ZHIYU_RUNNER_TAGS="zhiyu-backend,ucp,utp"
```

将：
```
UCP_RUNNER_TAGS="shell,ucp"
```
整段删除（ucp-shell-runner 已删除，不再需要此变量）。

同时删除 `UCP_RUNNER_REGISTRATION_TOKEN` 行（如果存在）。

- [ ] **Step 2: 更新 register-runners.sh — 移除 ucp 注册函数**

用 edit 工具：
1. 移除 `register_ucp_runner()` 整个函数定义
2. 移除主流程中对 ucp 的调用（`register_ucp_runner` 调用行 + `case "ucp"` 分支）
3. 更新脚本头部注释：`注册 zhiyu-docker-runner 和 ucp-shell-runner` → `注册 zhiyu-docker-runner`，移除 ucp 相关用法示例
4. 更新 `register_zhiyu_runner()` 中的默认 tag：`local runner_tags="${ZHIYU_RUNNER_TAGS:-docker,zhiyu}"` → `local runner_tags="${ZHIYU_RUNNER_TAGS:-zhiyu-backend,ucp,utp}"`

- [ ] **Step 3: 更新 config.toml.template**

用 edit 工具：
1. `concurrent = 2` → `concurrent = 1`
2. 更新 zhiyu-docker-runner 块的注释：`tags: [docker, zhiyu]` → `tags: [zhiyu-backend, ucp, utp]`
3. 移除 ucp-shell-runner 的整个 `[[runners]]` 块（如果模板中存在）

- [ ] **Step 4: 更新 README.md — Runner 注册章节**

用 edit 工具更新以下内容：

**4a. 前置条件的 .env 示例（Line 202-209）**：
将：
```bash
# ZhiYu-Backend 项目（docker executor）
ZHIYU_RUNNER_REGISTRATION_TOKEN=glrtr-xxxxxxxxxxxxxxxxxxxx
ZHIYU_RUNNER_TAGS="docker,zhiyu"
ZHIYU_RUNNER_IMAGE="10.211.55.2:5001/ufp-ci-build:1.0.0-683866d"

# Uniform-Common-Platform 项目（shell executor）
UCP_RUNNER_REGISTRATION_TOKEN=glrtr-xxxxxxxxxxxxxxxxxxxx
UCP_RUNNER_TAGS="shell,ucp"
```
改为：
```bash
# ZhiYu-Backend / UCP / UTP 项目（docker executor，按项目专属 tag 调度）
ZHIYU_RUNNER_REGISTRATION_TOKEN=glrtr-xxxxxxxxxxxxxxxxxxxx
ZHIYU_RUNNER_TAGS="zhiyu-backend,ucp,utp"
ZHIYU_RUNNER_IMAGE="10.211.55.2:5001/ufp-ci-build:1.0.0-683866d"
```

**4b. 注册命令示例（Line 225-232）**：
将：
```bash
# 注册全部 Runner（zhiyu-docker + ucp-shell）
./tools/register-runners.sh

# 仅注册 zhiyu-docker-runner
./tools/register-runners.sh zhiyu

# 仅注册 ucp-shell-runner
./tools/register-runners.sh ucp
```
改为：
```bash
# 注册全部 Runner（zhiyu-docker）
./tools/register-runners.sh

# 仅注册 zhiyu-docker-runner
./tools/register-runners.sh zhiyu
```

**4c. Runner 架构表（Line 243-246）**：
将：
```
| Runner | Executor | 镜像 | Tags | 用途 |
|--------|----------|------|------|------|
| `zhiyu-docker-runner` | docker | `ufp-ci-build:1.0.0-683866d` | `docker,zhiyu` | ZhiYu-Backend CI（JDK 21） |
| `ucp-shell-runner` | shell | — | `shell,ucp` | Uniform-Common-Platform CI（Docker-in-Shell） |
```
改为：
```
| Runner | Executor | 镜像 | Tags | 用途 |
|--------|----------|------|------|------|
| `zhiyu-docker-runner` | docker | `ufp-ci-build:1.0.0-683866d` | `zhiyu-backend,ucp,utp` | ZhiYu-Backend + UCP + UTP CI（按项目专属 tag 调度） |
| `macos-xcode-runner` | shell | — | `zhiyu-ios` | ZhiYu iOS/macOS/watchOS 编译（宿主机 launchd 原生部署，非容器化） |

> **ucp-shell-runner 已删除**：原 UCP shell executor 闲置，UCP/UTP 已改用 zhiyu-docker-runner（docker executor）。
```

- [ ] **Step 5: 在 README.md 新增「Runner Tag 命名规范」小节**

在「Runner 架构」表之后（helper_image 说明之前），用 edit 工具插入新小节：

```markdown
### Runner Tag 命名规范

Runner tag 采用**项目专属 tag** 策略，确保精确调度、无跨项目争抢：

| 规则 | 说明 | 示例 |
|------|------|------|
| **一项目一 tag** | 每个项目用专属 tag，runner 通过包含该 tag 匹配 | `zhiyu-ios`、`zhiyu-backend`、`ucp`、`utp` |
| **不使用 executor 描述 tag** | `shell`/`docker` 是 executor 类型，已由 `config.toml` 决定，放入 tag 是冗余 | ❌ `docker`、`shell` |
| **不使用宽泛归属 tag** | 避免一个 tag 匹配多个项目导致争抢 | ❌ `zhiyu`（ZhiYu 和 Backend 都含"zhiyu"） |
| **不使用架构描述 tag** | `arm64`/`x86` 由 runner 所在主机决定，非调度维度 | ❌ `arm64` |

**当前 tag 分配**：

| Tag | Runner | 项目 | 
|-----|--------|------|
| `zhiyu-ios` | `macos-xcode-runner` | ZhiYu（iOS/macOS/watchOS） |
| `zhiyu-backend` | `zhiyu-docker-runner` | ZhiYu-Backend |
| `ucp` | `zhiyu-docker-runner` | Uniform-Common-Platform |
| `utp` | `zhiyu-docker-runner` | Uniform-ThirdParty-Platform |

**concurrent 策略**：`concurrent = 1`（单 Mac 串行执行），避免多 job 并发导致 CPU/内存争抢和 OOM kill。ZhiYu 的 build-ios/macos/watchos 串行执行，pipeline 总时长增加但稳定可靠。

**新增项目/runner 时**：
1. 在项目 `.gitlab-ci.yml` 的 `default.tags` 声明项目专属 tag
2. 在目标 runner 的 tag_list 中添加该 tag（GitLab API 或 `register-runners.sh`）
3. 更新本节的「当前 tag 分配」表
```

- [ ] **Step 6: 更新 README.md 目录结构中的 register-runners.sh 注释（Line 63）**

将：
```
│   ├── register-runners.sh        ← 向 GitLab 注册 CI Runner（zhiyu-docker + ucp-shell）
```
改为：
```
│   ├── register-runners.sh        ← 向 GitLab 注册 CI Runner（zhiyu-docker）
```

- [ ] **Step 7: 验证所有改动**

```bash
echo "=== .env.example 无旧 tag ==="
grep -n "docker,zhiyu\|shell,ucp" /Users/constantine/Documents/work/rnd-env/rnd-cicd/.env.example
echo "=== register-runners.sh 无 ucp 函数 ==="
grep -n "register_ucp\|ucp-shell" /Users/constantine/Documents/work/rnd-env/rnd-cicd/tools/register-runners.sh
echo "=== config.toml.template concurrent=1 ==="
grep "^concurrent" /Users/constantine/Documents/work/rnd-env/rnd-cicd/gitlab/runner-config/config.toml.template
echo "=== README 无旧 tag ==="
grep -n "docker,zhiyu\|shell,ucp\|ucp-shell-runner" /Users/constantine/Documents/work/rnd-env/rnd-cicd/README.md
```

Expected: 前两个 grep 无输出（旧内容已删除），第三个显示 `concurrent = 1`，第四个无输出（或仅保留"已删除"说明行）。

- [ ] **Step 8: Commit 并推送**

```bash
git -C /Users/constantine/Documents/work/rnd-env add rnd-cicd/README.md rnd-cicd/.env.example rnd-cicd/tools/register-runners.sh rnd-cicd/gitlab/runner-config/config.toml.template
git -C /Users/constantine/Documents/work/rnd-env commit -m "ci: runner tag 隔离——更新注册脚本/模板/文档为项目专属 tag

- zhiyu-docker-runner tag: docker,zhiyu → zhiyu-backend,ucp,utp
- 删除 ucp-shell-runner（闲置，UCP/UTP 已改用 docker executor）
- concurrent 2→1 避免 OOM
- 新增 Runner Tag 命名规范小节"
git -C /Users/constantine/Documents/work/rnd-env push
```

---

## 回滚步骤

如果任何阶段出现问题，按以下顺序回滚：

1. **config.toml 回滚**：`cp ~/.gitlab-runner/config.toml.bak-20261020 ~/.gitlab-runner/config.toml && sudo gitlab-runner restart`
2. **Runner tag 回滚**：通过 GitLab API `PUT /runners/:id` 改回原 tag
3. **项目 CI 回滚**：`git revert <commit>` 或 `git reset --hard <prev-commit>`
4. **ucp-shell-runner 恢复**：需重新注册 `gitlab-runner register`（token 已失效，需在 GitLab 创建新 runner）
