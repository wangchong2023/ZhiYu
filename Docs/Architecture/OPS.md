# 运维与可观测性 (OPS)

> 本文档描述智宇 (ZhiYu) 的本地可观测性架构。
> 作为本地优先 (Local-First) 应用，本项目不依赖 Grafana/Loki/Prometheus 等服务端运维设施，
> 可观测性通过端内日志聚合、性能度量、健康检查和开发者可视化面板实现。

## 1. 日志系统 (Logging)

| 组件 | 路径 | 职责 |
|------|------|------|
| `Logger` | `Sources/Core/System/Logger/Logger.swift` | 操作日志聚合与磁盘原子写入 |
| `LogEntry` | `Sources/Core/Base/Constants/LogEntry.swift` | 日志条目模型（`Identifiable`, `Codable`, `Sendable`） |
| `LogView` | `Sources/Features/Insight/Log/View/LogView.swift` | 开发者菜单中的日志可视化追溯 |

- **日志格式**：含动作 (`LogAction`)、目标 (`target`)、耗时、成功/失败状态
- **持久化**：磁盘原子写入，支持崩溃后恢复
- **访问入口**：开发者菜单 → 操作日志

## 2. 性能度量 (Performance Metrics)

| 组件 | 路径 | 职责 |
|------|------|------|
| `PerformanceBenchmarker` | `Sources/Infrastructure/Performance/PerformanceBenchmarker.swift` | 耗时指标计算与分析 |
| `PerformanceService` | `Sources/Core/System/Performance/PerformanceService.swift` | 性能追踪服务 |

- **核心路径监控**：向量查询、图谱布局、FTS5 搜索、RAG 链路
- **`logTimed` 高阶函数**：自动采集耗时并写入 `LogEntry`
- **性能需求基线**（见 SRS）：
  - FTS5 响应 < 100ms（10K 节点）
  - RAG 链路 < 1.5s（含向量检索与 Rerank）
  - 数据库冷启动 < 1.0s
  - UI 帧率稳恒 60 FPS

## 3. 健康检查 (Health Check / Lint)

| 组件 | 路径 | 职责 |
|------|------|------|
| `LintService` | `Sources/Features/Insight/Lint/Service/LintService.swift` | 知识库健康检查（断链、孤岛、循环引用） |

- **检测项**：断链页面、孤岛页面、循环引用、低质量页面
- **访问入口**：巡检看板（Insight Dashboard）

## 4. 事件总线 (Event Bus)

| 组件 | 路径 | 职责 |
|------|------|------|
| `AppEventBus` | `Sources/Core/System/Events/AppEventBus.swift` | 进程内松耦合事件通信 |
| `AppNotifications` | `Sources/Core/System/Notifications/AppNotifications.swift` | 数据变更通知（`Notification.Name` 扩展） |

- **发布者**：`SQLiteStore`（数据变更）、`IngestQueue`（导入进度）等
- **订阅者**：`GraphView`、`DashboardView` 等自动刷新

## 5. 本地分析 (Local Analytics)

| 组件 | 路径 | 职责 |
|------|------|------|
| `LocalAnalyticsService` | `Sources/Core/System/Analytics/LocalAnalyticsService.swift` | 本地事件追踪（不上报云端） |
| `AIAnalyticsService` | `Sources/Infrastructure/LLM/AIAnalyticsService.swift` | AI 使用统计分析 |

## 6. 触觉反馈 (Haptic Feedback)

| 组件 | 路径 | 职责 |
|------|------|------|
| `HapticFeedback` | `Sources/Core/System/Haptic/HapticFeedback.swift` | 触觉反馈协议 |
| `iOSHapticService` | `Sources/Core/System/Haptic/iOSHapticService.swift` | iOS 实现 |
| `MacHapticService` | `Sources/Core/System/Haptic/MacHapticService.swift` | macOS 实现 |
| `WatchHapticService` | `Sources/Core/System/Haptic/WatchHapticService.swift` | watchOS 实现 |

## 7. 数据库维护 (Database Maintenance)

| 组件 | 路径 | 职责 |
|------|------|------|
| `MaintenanceService` | `Sources/Infrastructure/Storage/Services/MaintenanceService.swift` | VACUUM、integrity check、WAL checkpoint |
| `DatabaseManager` | `Sources/Infrastructure/Storage/Persistence/DatabaseManager.swift` | 连接池管理、热切换 |

## 8. 开发者诊断面板

通过开发者菜单可访问以下诊断工具：
- **操作日志**（`LogView`）— 全量操作追溯
- **巡检看板**（`LintView`）— 知识库健康检查
- **性能基准**（`PerformanceBenchmarker`）— 耗时指标查看
- **AI 统计**（`AIAnalyticsService`）— LLM 调用统计

## 9. 测试可观测性

- **测试状态重置**：`TestStateResettable` 协议确保单例服务在测试间状态隔离
- **Mock 注入**：通过 `@Dependency` 的 `testValue` 实现测试环境 Mock 替换
- **覆盖率门禁**：SonarQube 全语言扫描，行覆盖 ≥ 95%、分支覆盖 ≥ 90%、重复率 < 3%
