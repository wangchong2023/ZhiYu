# GitLab Runner Tag 隔离与配置优化设计

**日期**: 2026-10-20
**状态**: 已批准
**作者**: brainstorming 流程产出

## 背景与问题

### 触发事件

ZhiYu 的 `test-and-coverage` CI job 在 93% 测试通过（7211/7212，0 失败）时被 `Terminated: 15`（SIGTERM），原因是单 Mac 上多个 runner 并发执行导致 CPU/内存争抢。同时 `build-prepare` job 因 `/etc/hosts` 丢失 `host.docker.internal` 映射而 `Empty reply from server` 失败。

### 现状盘点

3 个 Runner 服务 4 个项目，但配置存在多处问题：

| Runner | Executor | Tags | 问题 |
|--------|----------|------|------|
| `ucp-shell-runner` (id=2) | shell | `[shell]` | 闲置，无项目使用，版本旧(19.4.1) |
| `macos-xcode-runner` (id=3) | shell | `[macos, shell, xcode, arm64, zhiyu-ios]` | `shell` tag 冗余且与 ucp-shell-runner 冲突；缺 `clone_url` 依赖脆弱的 `/etc/hosts` |
| `zhiyu-docker-runner` (id=5) | docker | `[docker, zhiyu, ucp]` | `docker`/`zhiyu` tag 语义混乱；同时服务 3 个项目但 tag 未按项目区分 |

| 项目 | CI tags | 问题 |
|------|---------|------|
| ZhiYu | `[zhiyu-ios]`（MR 分支）/ `[macos, shell, xcode, arm64]`（main） | main 分支待 MR 合并；缺 `default.timeout` 兜底 |
| ZhiYu-Backend | `[docker, zhiyu]`（子文件 default） | 主文件 `default` 无 tags；`zhiyu` tag 太宽泛 |
| Uniform-Common-Platform | `[ucp]` | 正常 |
| Uniform-ThirdParty-Platform | `[ucp]` | 与 UCP 共享 tag，无法按项目区分 |

`config.toml` 的 `concurrent = 2` 允许 2 个 job 并发，在单 Mac 上导致资源争抢。

## 设计决策

| # | 决策 | 理由 |
|---|------|------|
| 1 | 删除 `ucp-shell-runner`（id=2） | 闲置，无项目使用，减少维护负担和 tag 冲突 |
| 2 | `concurrent` 2 → 1 | 单 Mac 串行执行，避免 OOM kill，稳定可靠 |
| 3 | `macos-xcode-runner` tag → `[zhiyu-ios]` | 单一专属 tag，去掉冗余的 `shell`/`macos`/`xcode`/`arm64` |
| 4 | `macos-xcode-runner` 加 `clone_url` | 绕过 `host.docker.internal` 依赖，用 `127.0.0.1:8480` 直连 |
| 5 | `zhiyu-docker-runner` tag → `[zhiyu-backend, ucp, utp]` | 按项目拆分 tag，去掉冗余的 `docker`/`zhiyu` |
| 6 | ZhiYu-Backend tag `[docker, zhiyu]` → `[zhiyu-backend]` | 项目专属 tag，语义清晰 |
| 7 | UTP tag `[ucp]` → `[utp]` | 与 UCP 区分，便于按项目追踪/限流 |
| 8 | UCP tag `[ucp]` 保持不变 | UCP 是体系本体，`[ucp]` 名副其实 |
| 9 | ZhiYu 加 `default.timeout: 1h` | 兜底防卡死，`test-and-coverage` 保持 `2h` |

## 目标状态

### Runner 配置

```
concurrent = 1

┌──────────────────┬──────────┬──────────────────────┬────────────────────┐
│  Runner          │ Executor │ Tags                 │ clone_url          │
├──────────────────┼──────────┼──────────────────────┼────────────────────┤
│  macos-xcode-    │ shell    │ [zhiyu-ios]          │ http://127.0.0.1   │
│  runner (id=3)   │          │                      │   :8480            │
├──────────────────┼──────────┼──────────────────────┼────────────────────┤
│  zhiyu-docker-   │ docker   │ [zhiyu-backend,      │ (docker executor   │
│  runner (id=5)   │          │  ucp, utp]           │  用 extra_hosts)   │
└──────────────────┴──────────┴──────────────────────┴────────────────────┘

ucp-shell-runner (id=2): 已删除
```

### 项目 CI Tag 映射

```
┌──────────────────────────┬──────────────────┬──────────────────────┐
│  项目                     │ CI tags          │ 匹配 runner           │
├──────────────────────────┼──────────────────┼──────────────────────┤
│  ZhiYu                   │ [zhiyu-ios]      │ macos-xcode-runner   │
│  ZhiYu-Backend           │ [zhiyu-backend]  │ zhiyu-docker-runner  │
│  Uniform-Common-Platform │ [ucp]            │ zhiyu-docker-runner  │
│  Uniform-ThirdParty-     │ [utp]            │ zhiyu-docker-runner  │
│  Platform                │                  │                      │
└──────────────────────────┴──────────────────┴──────────────────────┘
```

### Tag 命名约定

采用业界混合策略，tag 承载"项目归属"语义（非 executor 类型）：

- **项目专属 tag**：`zhiyu-ios`、`zhiyu-backend`、`ucp`、`utp` — 一项目一 tag，用于精确调度
- **不使用 executor 描述 tag**：`shell`、`docker` 是 executor 类型，已由 `config.toml` 决定，放入 tag 是冗余
- **不使用宽泛归属 tag**：`zhiyu` 太宽泛（ZhiYu 和 ZhiYu-Backend 都含"zhiyu"），用 `zhiyu-ios`/`zhiyu-backend` 区分

## 改动清单

### Runner 侧

| # | 改动项 | 位置 | 方式 |
|---|--------|------|------|
| R1 | 删除 `ucp-shell-runner`（id=2） | GitLab API + `config.toml` | API 删除 runner，移除 config.toml 的 `[[runners]]` 块 |
| R2 | `macos-xcode-runner` tag → `[zhiyu-ios]` | GitLab API | `PUT /runners/3` 更新 tag_list |
| R3 | `macos-xcode-runner` 加 `clone_url` | `config.toml` | 加 `clone_url = "http://127.0.0.1:8480"` |
| R4 | `zhiyu-docker-runner` tag → `[zhiyu-backend, ucp, utp]` | GitLab API | `PUT /runners/5` 更新 tag_list |
| R5 | `concurrent` 2 → 1 | `config.toml` | 改首行 `concurrent = 1` |
| R6 | 重启 gitlab-runner 服务 | 终端 | `gitlab-runner restart` 使 config.toml 生效 |

### 项目 CI 侧

| # | 改动项 | 仓库 | 文件 |
|---|--------|------|------|
| C1 | ZhiYu `default.tags` 确认为 `[zhiyu-ios]` | ZhiYu | `.gitlab-ci.yml`（MR 分支已改，main 待 MR 合并） |
| C2 | ZhiYu 加 `default.timeout: 1h` | ZhiYu | `.gitlab-ci.yml` |
| C3 | ZhiYu-Backend tag → `[zhiyu-backend]` | ZhiYu-Backend | `.gitlab-ci.yml`（test-browser-frontend）+ `.gitlab/ci/online-pipeline.yml` + `.gitlab/ci/offline-pipeline.yml` |
| C4 | UTP tag `[ucp]` → `[utp]` | Uniform-ThirdParty-Platform | `.gitlab-ci.yml` |
| C5 | UCP tag `[ucp]` 不变 | Uniform-Common-Platform | 无改动 |

## 风险与回滚

### 风险

1. **ZhiYu-Backend 跨仓库改动**：C3 需要访问 ZhiYu-Backend 仓库改 3 个文件。实施前先通过 `git remote -v`（在 ZhiYu-Backend 仓库目录）或 GitLab API 确认 push 权限。若无权限，`zhiyu-docker-runner` 需临时保留 `zhiyu` tag 兼容旧 `[docker, zhiyu]` 声明，此时 R4 的 tag 改为 `[zhiyu-backend, ucp, utp, zhiyu]`（多保留 `zhiyu` 做过渡），待 Backend 仓库改完再去掉 `zhiyu`。
2. **UTP 改 tag 后**：`zhiyu-docker-runner` 必须先加 `utp` tag，否则 UTP 的 `[utp]` job 无 runner 匹配会 pending。执行顺序：先改 runner tag，再改项目 CI。
3. **`concurrent=1` 降低吞吐**：ZhiYu 的 build-ios/macos/watchos 串行执行，pipeline 总时长增加。但稳定性优先。

### 回滚

- `config.toml`：改动前备份，回滚恢复备份文件 + `gitlab-runner restart`
- Runner tag：通过 GitLab API `PUT /runners/:id` 改回原 tag
- 项目 CI：git revert

## 执行顺序

```
1. 备份 config.toml
2. Runner 侧（R1-R5）：先改 runner tag 和 config.toml，重启 runner
3. 验证 runner tag 生效（API 查询）
4. 项目 CI 侧（C1-C4）：改各项目 .gitlab-ci.yml
5. 触发各项目 pipeline 验证 job 正确匹配 runner
6. 确认无 job pending（tag 不匹配）
```

## 不在范围内

- `zhiyu-docker-runner` 的 docker 镜像/volumes/extra_hosts 配置：不变
- UCP/UTP 的 CI 流程逻辑：不变
- ZhiYu-Backend 的 CI 流程逻辑：不变
- GitLab 实例配置（external_url 等）：不变
- `/etc/hosts` 维护：已修复，但 clone_url 加固后不再依赖它
