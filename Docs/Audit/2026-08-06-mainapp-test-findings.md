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
| 3 | 🔴 P0 | `Sources/Core/Base/Utils/ZipUtility.swift:35,44-46,61` | 崩溃（对齐违规） | `UnsafeRawPointer.load(fromByteOffset:as:)` 用于读取 ZIP 头的 UInt16/UInt32 字段（偏移 8/18/28/30 均非对齐），在 ARM64 上触发 `EXC_BREAKPOINT` 崩溃 | 任何调用 `readZipArchive` 解析真实 ZIP 文件的场景都会崩溃（如导入 ZIP 备份） | 改用逐字节手动拼装（`UInt16(byte0) \| (UInt16(byte1) << 8)`）或 `withUnsafeBytes` + `loadUnaligned(fromByteOffset:as:)`（iOS 15+） | 待确认 | 批次1 |
| 4 | 🟢 P2 | `Sources/Core/System/Security/JailbreakDetector.swift:22` | 可测试性 | `private init` 阻止测试构造独立实例，只能用 shared 单例无法隔离状态 | 测试无法独立构造实例验证 init 逻辑 | `private init` → `init`（internal） | 已修复 | 批次1 |
| 5 | 🟡 P1 | `Sources/Core/System/Security/JailbreakDetector.swift:50-61` | 逻辑错误（模拟器误报） | `checkCommonJailbreakFiles()` 检测 `/bin/bash`、`/usr/sbin/sshd`、`/usr/bin/ssh` 等路径，但这些在 macOS 系统自带存在。iOS 模拟器运行在 macOS 上，导致 `isJailbroken()` 在模拟器上永远返回 true | 越狱检测在模拟器/开发环境下完全失效，开发者无法信任检测结果；可能影响依赖此检测的安全逻辑 | 1) 移除 macOS 自带的路径（`/bin/bash`、`/usr/sbin/sshd`、`/usr/bin/ssh`）；或 2) 用 `#if targetEnvironment(simulator)` 在模拟器下直接返回 false；或 3) 改用 iOS 专属路径（如 `/Applications/Cydia.app`、`/Library/MobileSubstrate/`） | 待确认 | 批次1 |

## 处理状态说明

- **待确认**：测试发现，待用户确认
- **已确认 → 已修复**：用户确认后已修复
- **已确认 → 预期行为不修**：用户确认是预期行为，不修
