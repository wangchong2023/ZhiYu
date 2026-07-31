# 智宇 (ZhiYu) 订阅套餐配额与能力门禁规范 (Subscription & Quota Specification)

本文档权威记录智宇 (ZhiYu) 应用中 **Lite 基础版** 与 **Pro 专业版** 的订阅套餐功能划分、物理配额限制以及底层门禁控制编码。

> **说明**：本规范仅收录当前版本已 100% 物理连通、已上线并可供用户使用的能力。规划中或打桩阶段的功能已移至 [ROADMAP.md](../Requirements/ROADMAP.md) 规划文档。

---

## 1. 概述与设计原则

- **集中式门禁管理者 (`FeatureGateManager`)**：位于 L1.5 领域层，负责在全局范围内管理套餐能力与配额。
- **纯离线保底策略 (Cold-Start Baseline)**：新装机未联网或未登录时，默认兜底使用 Lite 配额 (`PlanQuotasVo.createLiteDefault`)。
- **协议契约**：所有配额字段在 JSON 协议、后端数据库 `quotas_json` 及 Swift 模型 `PlanQuotasVo` 中 100% 保持命名对齐。

---

## 2. Lite 与 Pro 套餐在线功能对照大盘

### 2.1 物理控制项与在线配额指标 (Active Physical Quotas)

| 领域 / 功能模块 | 控制功能项 (Control Feature) | 控制项编码 (Control Code) | Lite 基础版 (Free Baseline) | Pro 专业版 (Pro Plan) | 说明 / 物理打卡逻辑 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **存储容量** | **最大知识页数** | `max_knowledge_pages` | **1,000 页** | **50,000 页** | 超限拦截文档保存，弹出收银台模态框 |
| | **独立笔记本数** | `max_vaults_count` | **2 个** | **100 个** | 超限阻止创建新笔记本 |
| | **单文件附件大小上限** | `max_file_size_mb` | **10 MB** | **50 MB** | 导入超限时弹出提示框并中断解析 |
| **AI 智脑** | **每日云端 AI 消息上限** | `daily_ai_messages` | **0 条** (仅离线/端侧) | **无限制 (-1)** | 决定是否允许向云端 API 发送消息 |
| | **高阶云端大模型** | `cloud_llm_models_enabled` | ❌ 隐藏 (无 GPT-4o / Claude) | ✅ 开通 (GPT-4o, Claude 3.5, Qwen) | 控制模型选择下拉菜单中的高阶云端模型 |
| **Retrieval (RAG)**| **向量语义混合检索** | `vector_search_enabled` | ❌ 关 (仅 SQLite FTS5 全文检索) | ✅ 开 (FTS5 文本 + Vector 语义双路召回) | 控制是否在内存中加载向量 Embedding 引擎 |
| **知识图谱** | **基础 3D/2D 节点图谱** | - (通用功能) | ✅ 支持 (3D/2D 力导向关系网) | ✅ 支持 (3D/2D 力导向关系网) | 基础 3D/2D 关联节点呈现，全员可用 |
| **同步与导出** | **大附件 iCloud 云同步** | `large_attachment_sync` | ❌ 仅同步纯 Markdown 文本 | ✅ 支持音视频、PDF 及二进制附件全量同步 | 控制 iCloud Sync Engine 的附件推拉流 |
| | **高级格式导出** | `advanced_export_enabled` | ❌ 仅支持 .md / .txt 导出 | ✅ 支持 Word (.docx)、PPTX 高级排版导出 | 控制导出菜单中高级格式的加锁状态 |
| **平台扩展** | **macOS Spotlight 深度索引** | `spotlight_indexing_enabled`| ❌ 不支持 | ✅ 支持 macOS 系统级 Spotlight 深度全文检索 | 控制 CoreSpotlight 索引构建任务 |
| | **Pro 专属插件市场** | `pro_plugins_enabled` | ❌ 仅基础公开插件 | ✅ 解禁 Pro 专属开发者插件安装与加载 | 控制 Plugin Marketplace 鉴权与隔离 |
| **基础体验** | **纯净无广告与硬件加速** | `ad_free_enabled` | ✅ 支持 | ✅ 支持 | 保持无广告体验与 Metal 硬件加速 |

---

### 2.2 核心业务场景功能细分 (Business Scenario Breakdown)

| 场景模块 | 具体功能点 | Lite 基础版 | Pro 专业版 | 模型/引擎调度差异 |
| :--- | :--- | :--- | :--- | :--- |
| **AI 合成实验室** | **AI 核心总结 & 问答** | ✅ 支持 (依赖端侧轻量 SLM) | ✅ 支持 (云端 GPT-4o / Claude 深度理解) | Lite 依赖端侧 SLM，Pro 解禁顶级云端大模型 |
| | **思维导图生成 (.mindmap)** | ✅ 支持 | ✅ 支持 | 支持结构化 Mermaid / JSON 脑图节点生成 |
| | **Quiz 智能测验生成** | ✅ 支持 | ✅ 支持 | 自动基于文档生成单选、多选与填空自测题 |
| | **Slides 幻灯片生成** | ✅ 支持 | ✅ 支持 | 自动提炼 Markdown 转化为演示文稿 |
| | **深度研报生成** | ✅ 支持 (端侧轻量) | ✅ 支持 (云端长上下文合成) | Pro 可一次性摄取数万字长上下文生成研报 |
| **文档摄取 (Ingest)** | **Markdown / TXT 摄取** | ✅ 支持 | ✅ 支持 | 支持 frontmatter 与标签提取 |
| | **PDF 解析与 OCR 识别** | ✅ 支持 (<= 10MB) | ✅ 支持 (<= 50MB) | 支持提取图片内的文本及结构化表格 |
| | **网页 URL 批量抓取** | ✅ 支持 (<= 10 条/次) | ✅ 支持 (无限制) | 抓取网页转换为干净 Markdown |
| | **语音速记实时转文字** | ✅ 支持 (<= 15 分钟) | ✅ 支持 (无限制长语音) | 支持端侧 Whisper 语音转写 |
| **知识洞察 (Insight)** | **知识库 Lint 诊断** | ✅ 支持 | ✅ 支持 | 全盘扫描孤立页面、死链及未标签文档 |
| | **成就勋章墙与大盘** | ✅ 支持 | ✅ Supported | 记录连续创作天数与知识积累指标 |

---

## 3. 计费周期与定价标准 (Pricing & Billing Cycles)

智宇 (ZhiYu) Pro 专业版提供灵活的订阅计费周期，支持通过 App Store StoreKit 2 进行自动续费订阅：

| 订阅类型 | 定价标准 | 折合单价 | 优惠幅度 | 适用场景 |
| :--- | :--- | :--- | :--- | :--- |
| **Lite 基础版** | **¥0 / 永久免费** | ¥0 / 月 | - | 个人离线笔记、本地隐私存储用户 |
| **Pro 连续包月** | **¥15 / 月** | ¥15.0 / 月 | 基准价 | 灵活短期试用、临时长文档/云端 AI 摄取需求 |
| **Pro 连续包年** | **¥120 / 年** | **¥10.0 / 月** | **省 33%** | 深度知识管理、全平台无缝同步的个人/专业用户 |

### 定价补充说明：
1. **包年立省优惠**：连续包年方案下调至 **¥120 / 年**，相当于每月仅需 **¥10**，相比连续包月方案单月直降 33%。
2. **多端共享特权**：一次订阅，即可通过 Apple ID 的 App Store 凭据在 iOS (iPhone/iPad)、macOS (Catalyst) 及 watchOS 端同步解锁全部 Pro 权益。
3. **退款与降级安全**：若订阅到期未续费或退款，系统自动将配额平滑回退至 Lite 基础版，已保存的离线文档不会物理丢失，超出 1,000 页的部分支持只读与导出。

---

## 4. 代码物理映射关系

- **数据模型**：`Sources/Domain/Subscription/PlanQuotasVo.swift`
- **门禁服务**：`Sources/Domain/Subscription/FeatureGateManager.swift`
- **UI 页面组件**：`Sources/Features/System/Auth/View/SubscriptionPlanView.swift`
- **本地化词条**：`Sources/Localization/Catalogs/System.xcstrings` (`auth.priceMonthlyPro`, `auth.priceYearlyPro`, `auth.feature.*`)
