# 智宇 (ZhiYu) 国际化与本地化指南 (Localization Guide)

为了确保“智宇”能够灵活适配全球市场，同时保持大规模协作下的代码整洁，我们采用 **“领域驱动分表 + 编译时自动化合并”** 的本地化架构。

## 1. 核心架构：三层分表体系

我们将本地化词条按系统的 L0-L2 架构进行物理拆分，每个 `.xcstrings` (String Catalog) 文件对应一个独立的职责域：

### 1.1 业务特性层 (L2 Features)
对应核心业务功能，便于特性重构与解耦：
*   **`Chat.xcstrings`**：对话交互、流式响应提示。
*   **`Ingest.xcstrings`**：内容摄入、OCR 识别、格式转换文案。
*   **`Graph.xcstrings`**：2D/3D 图谱、聚类分析、节点详情。
*   **`Knowledge.xcstrings`**：知识库、页面、标签、关系相关文案。
*   **`Insight.xcstrings`**：统计指标、增长趋势、洞察报告。
*   **`Transfer.xcstrings`**：导入导出、数据传输、备份恢复。
*   **`Plugin.xcstrings`**：插件市场、插件安装与管理。
*   **`Widget.xcstrings`**：桌面/锁屏小组件。

### 1.2 领域服务层 (L1 Domain Services)
对应底层原子能力：
*   **`AI.xcstrings`**：AI 智脑、合成、问答相关文案。
*   **`ModelManager.xcstrings`**：模型下载、切换、离线管理。
*   **`Network.xcstrings`**：网络请求、同步、连接状态错误。
*   **`System.xcstrings`**：系统设置、订阅计费、鉴权相关词条。

### 1.3 基础设施层 (L0/Shared)
对应全站通用组件：
*   **`Common.xcstrings`**：通用按钮、空状态 (EmptyState)、错误/成功占位语。
*   **`Coachmark.xcstrings`**：新手引导、功能提示浮层。
*   **`Platform.xcstrings`**：跨平台通用（iOS/macOS/watchOS）文案。
*   **`InfoPlist.xcstrings`**：系统权限申请描述。

---

## 2. 工作流：开发与同步

为了解决分表在某些构建环境下（如 SwiftPM 或 Catalyst）加载不稳定的问题，我们引入了自动合并机制。

### 2.1 词条添加规范
1.  **新增词条**：根据所属功能找到对应的 `.xcstrings` 分表进行添加。
2.  **Key 命名空间**：采用 `[模块名].[功能].[描述]` 格式。
    *   示例：`ingest.error.unsupportedFormat` 或 `chat.placeholder.thinking`。
3. **类型安全访问**：严禁直接在 View 中书写 `"string_key"`。必须通过 `Sources/Core/Base/Utils/Localized.swift` 中定义的 `L10n` 结构体进行访问。
    *   示例：`Text(L10n.Chat.title)`。

### 2.2 自动化同步 (Sync Mechanism)
在每次重大功能提交或发布前，必须执行同步脚本更新 .xcstrings 词条。
*   **价值**：确保了开发时的“模块化隔离”与运行时的“单表加载性能”完美平衡。

---

## 3. 动态扩展与语言支持
*   **默认源语言**：简体中文 (zh-Hans)。
*   **目标语言**：目前支持 9 种：英文 (en)、简体中文 (zh-Hans)、繁体中文 (zh-Hant)、日语 (ja)、韩语 (ko)、西班牙语 (es)、法语 (fr)、阿拉伯语 (ar)、俄语 (ru)。
*   **Locale 绑定**：`Localized.swift` 会根据当前的语言设置同步切换日期格式、度量单位以及搜索分词算法（如 CJK 增强）。

---
*注：本地化资产是系统的一部分，任何新增的 UI 文本均需在代码中配套相应的 `// MARK: [LR-01]` 标记以确保合规性。*
