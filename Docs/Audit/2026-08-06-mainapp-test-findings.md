# 主 App 测试驱动问题发现记录

> **起始日期**：2026-08-06
> **关联规格**：`Docs/superpowers/specs/2026-08-06-mainapp-coverage-design.md`
> **关联计划**：`docs/superpowers/plans/2026-08-06-mainapp-coverage.md`

## 严重程度定义

- 🔴 **P0**：数据损坏/丢失、崩溃、安全漏洞、资金损失（订阅/支付）
- 🟡 **P1**：逻辑错误、行为不一致、边界处理缺陷、错误处理缺失
- 🟢 **P2**：健壮性不足、维护负担、死代码、命名/注释问题

## 问题清单

| 序号 | 严重程度 | 文件:行号 | 问题类型 | 问题描述 | 黑盒影响 | 修改方案 | 处理状态 | 批次 |
|------|---------|----------|---------|---------|---------|---------|---------|------|
| 1 | 🟢 P2 | `Sources/Core/Base/Constants/LogAction.swift:23,35-36,40-41` | 契约不一致 | `export="action.export"`、`aiscanFailed/aiscanSkipped="log.action.aiscan.*"`、`error="ERROR"`、`unknown="unknown"` 不符合 `logAction.*` 前缀契约 | 日志分析时按 `logAction.` 前缀过滤会遗漏这些动作 | 统一改为 `logAction.export`/`logAction.aiscan.failed`/`logAction.aiscan.skipped`/`logAction.error`/`logAction.unknown` | 待确认 | 批次1 |
| 2 | 🟡 P1 | `Sources/Localization/Catalogs/Ingest.xcstrings` (`error.internalError`) | 本地化缺陷 | `error.internalError` 的值是固定 `"内部错误"`，无 `%@` 格式化占位符，导致 `ExportError.internalError(msg)` 的关联值 `msg` 被丢弃 | 用户看到"内部错误"但无法知道具体错误详情，不利于排查问题 | 在 `error.internalError` 的各语言值中添加 `%@` 占位符（如 `"内部错误：%@"`），使 `trf` 能正确注入关联值 | 待确认 | 批次1 |

## 处理状态说明

- **待确认**：测试发现，待用户确认
- **已确认 → 已修复**：用户确认后已修复
- **已确认 → 预期行为不修**：用户确认是预期行为，不修
