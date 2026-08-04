# 智宇 (ZhiYu) 全量特性与技术规格清单

> 本文档从 PRODUCT_REQUIREMENTS.md 中拆分，集中列出所有产品特性与技术规格。
> **状态标注图例**：✅ 已上线 · 🚧 开发中（有代码，待完善/验证）· 📋 规划中（有设计文档，待实现）

---

## 1. 核心 AI 特性 (AI Core)

| 特性 | 状态 | 说明 |
| :--- | :--- | :--- |
| **多模型适配 (Adapter Pattern)** | ✅ 已上线 | 支持 OpenAI, DeepSeek, SiliconFlow 及本地 Ollama，通过 `LLMService` 统一协议适配 |
| **智能编译 (Smart Ingest)** | ✅ 已上线 | 自动提取标签、摘要并重构 Markdown 内容，`IngestService` 完整实现 |
| **混合检索 (Hybrid RAG)** | ✅ 已上线 | FTS5+向量 RRF 融合，`RAGOrchestrator` + `EmbeddingManager` 全链路就绪 |
| **离线处理队列 (Ingest Queue)** | ✅ 已上线 | 后台异步处理大文件导入，`IngestQueue` 实现 |
| **端侧模型推理 (On-Device LLM)** | 🚧 开发中 | `OnDeviceLLMSettingsView` 就绪，端侧推理通道需端到端验证 |

## 2. 知识可视化 (Visualization)

| 特性 | 状态 | 说明 |
| :--- | :--- | :--- |
| **3D 动力学图谱** | ✅ 已上线 | `KnowledgeGraphView` + `GraphViewModel` 支持万级节点力导向渲染 |
| **LOD 渲染优化** | ✅ 已上线 | 基于缩放级别自动调整节点细节，`GraphView` 内置 LOD 逻辑 |
| **语义聚类视图** | 🚧 开发中 | 基础图谱功能完整，自动"领域星云"聚类算法待 AI 接入完善 |
| **3D 图谱洞察面板** | ✅ 已上线 | `toggle-insights` 按钮与洞察内容面板已实现并通过 UI 测试 |

## 3. 跨端深度集成 (Platform Integration)

| 特性 | 平台 | 状态 | 说明 |
| :--- | :--- | :--- | :--- |
| **实时活动 (Live Activity)** | iOS/iPadOS | 🚧 开发中 | ActivityKit 框架桥接已规划，需深度集成验证 |
| **Apple Pencil 双击切换** | iPadOS | 🚧 开发中 | `PlatformCapabilities` 中有协议定义，实现待验证 |
| **Siri Shortcuts 快速记录** | iOS/iPadOS | ✅ 已上线 | 已接入 `L10n.Shortcuts`，支持 Capture、Search、Stats 意图及后台执行 |
| **Spotlight 全局搜索集成** | macOS | 🚧 开发中 | `Core/System/SpotlightService.swift` 存在，集成完整度待验证 |
| **watchOS 语音笔记** | watchOS | ✅ 已上线 | 平台降级 Stub 与跨端 WCSession 离线同步队列已单元测试全面覆盖 (TC-WAT-01, TC-WAT-03) |
| **表盘 Complications** | watchOS | ✅ 已上线 | 快捷点击载荷编解码与 50+ 最热卡片微缩缓存同步已单元测试覆盖 (TC-WAT-02) |
| **桌面静态小组件 (Static Widget)** | iOS/iPadOS | ✅ 已上线 | 支持 Small, Medium, Large 尺寸，展示知识总量与新增量，全面打通 `zhiyu://create` 快捷新建与 `zhiyu://search` 容灾 Deep Link (TC-WID-01 ~ TC-WID-03) |

## 4. 安全与隐私 (Security)

| 特性 | 状态 | 说明 |
| :--- | :--- | :--- |
| **生物识别金库 (FaceID/TouchID)** | ✅ 已上线 | `VaultStorageSecurityService` + `KeychainService` 完整实现 |
| **隐私模式（高斯模糊）** | ✅ 已上线 | `#private` 标签触发模糊处理，`PrivacyManager` 实现 |
| **纯本地优先存储** | ✅ 已上线 | SQLite + `SQLiteStore` Actor，无强制云同步 |
| **数据库静态加密** | 📋 规划中 | SQLCipher 方案尚未集成（见安全审计高风险项） |
| **端到端加密 CloudKit 同步** | 📋 规划中 | CKRecord 加密策略文档和实现均缺失 |

## 5. 协作与生产力生态 (Collaboration & Ecosystem)

| 特性 | 状态 | 说明 |
| :--- | :--- | :--- |
| **实时协作 (CollaborationService)** | 🚧 开发中 | `CollaborationService` 存在，UI 仅为示意占位。需落地 MultipeerConnectivity 的 LWW 冲突收敛引擎 |
| **插件市场 (Plugin Market)** | 📋 规划中 | 架构组已输出 `PLUGIN_MARKET_HLD.md`，核心 UI 与 JavaScriptCore 沙盒网关待实现 |
| **命令面板 (Cmd+K)** | ✅ 已上线 | `CommandPaletteView` 全局快捷键已集成 |
| **撤销/重做** | ✅ 已上线 | `UndoManager` 全库操作历史支持多级回退 |

## 6. 知识维护与质量 (Maintenance & Quality)

| 特性 | 状态 | 说明 |
| :--- | :--- | :--- |
| **健康检查 (Lint)** | ✅ 已上线 | 断链/孤岛/循环引用检测，`HealthCheckService` 完整实现 |
| **勋章/游戏化系统** | 📋 规划中 | `MedalService.swift` 仅骨架占位，需补充触发逻辑和奖励 UI 面板 |
| **操作日志 (Activity Log)** | ✅ 已上线 | `ActivityLogService` 记录全类型操作，`operationLog` 按钮可访问 |

## 7. 多模态采集 (Multi-Modal Ingest)

| 特性 | 状态 | 说明 |
| :--- | :--- | :--- |
| **OCR 扫描** | ✅ 已上线 | Vision 框架 OCR，`ingest.ocr` 按钮就绪，通过 UI 测试 |
| **语音笔记** | ✅ 已上线 | 10+ 语言实时转写，`SpeechServiceProtocol` 实现 |
| **PDF 解析** | ✅ 已上线 | 原生 PDF 读取与结构化提取，`PDFProcessorProxy` 完整实现 |
| **手动录入 (Manual Entry)** | ✅ 已上线 | `ingest.manual` 按钮与表单完整，通过 UI 测试 |
| **高级导出 (PPTX/Word)** | 📋 规划中 | 将基于 Markdown AST 结构化树生成，尚未集成导出库 |

## 8. 空间计算 (Spatial Computing)

| 特性 | 状态 | 说明 |
| :--- | :--- | :--- |
| **Vision Pro 空间视图** | 🚧 开发中 | `VisionOSView.swift` 仅提供降级 2D 占位，需引入 RealityKit 落地 3D 图谱空间交互 |

## 9. 软件规格 (Specifications)

*   **存储引擎**：SQLite 3.35.0+（WAL 模式）。
*   **向量引擎**：基于 Accelerate 框架的余弦相似度计算（`VectorStore`）。
*   **UI 框架**：SwiftUI 100% 原生（iOS 17+ API 优先）。
*   **最低支持**：iOS 17.0+, macOS 14.0+ (Catalyst), watchOS 10.0+。
*   **AI 并发模型**：Swift 6 严格并发，`@MainActor` + `actor` 全链路。

---
*本文档状态标注基于 2026-05-20 全量代码扫描，随版本迭代持续更新。*
