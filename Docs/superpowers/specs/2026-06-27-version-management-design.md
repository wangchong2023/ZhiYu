# 版本号管理方案 — 设计规格

> 创建日期: 2026-06-27
> 状态: 设计完成，等待实现
> 关联文档: [版本管理规范](../../Design/VERSION_MANAGEMENT.md), [CI/CD 工作流](../../Architecture/CI_CD_WORKFLOW.md)

---

## 问题

关于页面版本号硬编码为 `"1.0.0 (20260512)"`，Info.plist 中 `CFBundleShortVersionString = "1.0"` 陈旧且无人维护。缺乏完整的版本管理体系，版本号不能自动反映真实构建状态。

## 方案概要

Git Tag 驱动 + CI 注入 + 运行时从 Bundle 读取。

### 版本号来源

| 字段 | 来源 | 示例 |
|------|------|------|
| SemVer | `git describe --tags --abbrev=0` → 去掉前缀 v | `1.2.3` |
| 构建号 | `git rev-list --count HEAD` | `342` |
| 短哈希 | `git rev-parse --short HEAD` | `abc1234` |

### 数据流

```
git tag v1.2.3 → CI (Woodpecker/GHA) → ci-build-pipeline-version-inject.sh → Info.plist → Bundle.main → AboutView
```

### 改动清单

| 改动 | 类型 | 路径 |
|------|------|------|
| 新增 `build-pipeline-version-inject.sh` | 新文件 | `Tools/ci/build-pipeline-version-inject.sh` |
| 修复 AboutView 版本显示 | 修改 | `Sources/App/Scenes/AboutView.swift:52` |
| 新增 VERSION_MANAGEMENT.md | 新文件 | `Docs/Design/VERSION_MANAGEMENT.md` |
| 更新 CI/CD 文档 | 修改 | `Docs/Architecture/CI_CD_WORKFLOW.md` |
| 更新 CI 配置 | 修改 | `.woodpecker.yml`（新增 inject-version 步骤） |
| 更新 CI 配置 | 修改 | `.github/workflows/ci.yml`（版本注入 step） |
| project.yml 版本占位 | 修改 | `project.yml`（MARKETING_VERSION / CURRENT_PROJECT_VERSION） |

### 测试

| 测试 | 类型 | 覆盖 |
|------|------|------|
| `ci-run-test-version-inject-unit.sh` | 单元 | 正常 tag / 无 tag fallback / 构建号递增 / 短哈希格式 |
| AboutView 快照 | 快照 | 验证版本展示格式 `1.2.3 (342 · abc1234)` |
| 已有 `ios-check-release-appstore.py` | 门禁 | 自动校验版本号格式合规 |
