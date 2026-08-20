# 覆盖率提升测试驱动发现问题清单

> **起始日期**：2026-08-20
> **来源**：批次 A-D 覆盖率提升过程中测试驱动发现的问题
> **格式**：序号 / 问题描述 / 严重程度 / 修改方案 / 是否解决

---

## 批次 A — Core/Domain/Infrastructure

### Task 1：DemoImageBuilder / DemoAudioBuilder / PerformanceBenchmarker

| 序号 | 问题描述 | 严重程度 | 修改方案 | 是否解决 |
|------|---------|---------|---------|---------|
| A-1 | `PerformanceBenchmarker.swift:26` `for i in 1...count` 当 `count=0` 时触发 `fatal error: Range requires lowerBound <= upperBound`，导致应用崩溃 | P1 | 改为 `guard count > 0` 提前返回 | 是 |
| A-2 | `DemoImageBuilder.swift:27-28` `try?` 静默吞掉目录创建和文件写入错误，磁盘满或权限不足时调用方误以为持久化成功 | P2 | 改为 `do-catch` 至少记录日志，或返回错误元组 | 否 |
| A-3 | `DemoAudioBuilder.swift:19-21` 已存在文件直接返回 URL，不校验是否为有效音频文件，损坏/空文件仍返回 | P2 | 增加 `AVAudioFile(forReading:)` 校验，失败则重新合成 | 否 |
| A-4 | `PerformanceBenchmarker.swift:27` `i % stressTestProgressStep == 0`（step=5000），当 count < 5000 时进度日志分支永不执行（死代码分支） | P2 | 使用动态步长 `max(count / 10, 1)` | 是 |
| A-5 | `PerformanceBenchmarker.swift:48` `Double(count)/duration` 当 duration≈0 得到 `inf`，日志显示 `inf docs/s` | P2 | 增加 `duration > 0` 防护，否则输出 0 | 是 |
| A-6 | `DemoImageBuilder.swift:265-272` `#else`（watchOS）分支定义 `ensureDemoImagesExist(at:) -> [URL]`，但 UIKit 分支只有 `ensureImageExists(at:title:) -> UIImage?`，API 不一致 | P2 | 统一 API 签名，或在 watchOS 分支提供等价单图生成方法 | 否 |

