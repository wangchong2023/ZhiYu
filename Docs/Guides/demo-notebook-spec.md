# 智宇 (ZhiYu) - 内置演示笔记本数据与物理文件国际化规范 (demo-notebook-spec.md)

本指南旨在规范“智宇”项目中默认挂载的两个内置笔记本（“知识图谱”与“项目调研”）的演示笔记设计、多元来源分配以及关联物理导入文件在不同 Locale 语言环境下的物理文件名与降级写入（Fallback）内容，以确保冷启动注入的数据质量达到极高标准的本地化要求。

---

## 1. 概述与核心原则

在应用初次冷启动或用户手动重置数据时，系统会自动生成两个内置笔记本：
1. **笔记本 A：知识图谱** （默认笔记本，英文名：`Knowledge Graph`）
2. **笔记本 B：项目调研** （英文名：`Project Research`）

为了在向用户科普个人外脑概念的同时，又保留最自然、流畅的极简体验，所有演示笔记和关联文件必须严格遵守以下原则：
* **大白话科普**：全案彻底屏蔽“RAG”、“Markdown”、“LLM Wiki 方法论”等极客技术黑话，以最通俗、人人皆懂的中英文进行图谱优势解释。
* **极度精炼**：每个内置笔记本的演示笔记数量**强制限制为 5 篇**。
* **物理来源多元化**：2 个笔记本的 5 篇笔记需均匀分散在 5 种笔记分类（主题、词条、对比、来源）以及 5 种不同的导入源（Markdown、PDF、OCR 扫描、语音录入、网页链接）上，真实地在沙盒中物理写入对应的导入文件。
* **字数硬限**：各笔记本的核心物理导入源文件，其正文文字内容**强制要求不能低于 1000 字**，并具备规范的篇章结构（含标题、分级段落与列表）。
* **物理文件名国际化**：所有拷贝至沙盒 `Imports` 文件夹的物理源文件，其文件名本身也必须根据系统的语言环境进行相应的本地化翻译（如中文下为“个人知识图谱指南.md”，英文下为“personal_knowledge_graph_guide.md”），防止文件名出现非本地化的乱码。

---

## 2. 演示笔记本精简结构与多元来源分布

### 2.1 笔记本 A：知识图谱 (5 篇)

| 笔记标识 | 类型 (PageType) | 来源类型 (SourceType) | 关联物理文件名 (en / zh-Hans) | 演示内容要点 |
| :--- | :--- | :--- | :--- | :--- |
| **A-1** | 🔵 主题 (`.concept`) | 文件导入 (`Markdown`) | `personal_knowledge_graph_guide.md`<br>`个人知识图谱指南.md` | 1000字以上规范 Markdown，系统阐述如何利用主题、词条与链接构建个人网状外脑的核心原理。 |
| **A-2** | 🟡 词条 (`.entity`) | 图片扫描 (`OCR`) | `ocr_folder_scan.png`<br>`ocr_文件夹扫描.png` | 解释“词条”专注于具体的定义、名词与事实，并以“神经元”为例进行展示。 |
| **A-3** | 🔵 主题 (`.concept`) | 网页链接 (`Link`) | — | 解释“跨领域笔记枢纽”的桥梁概念，阐述连通两个不同知识领域对于创新涌现的核心价值。 |
| **A-4** | 🟢 来源 (`.source`) | 语音录入 (`Voice`) | `voice_note_forgetting_curve.mp3`<br>`语音_遗忘曲线_速记.mp3` | 随手记录的未关联灵感草稿，物理文件保存为 `.mp3` 音频，引导用户如何帮它建立链接。 |
| **A-5** | 🟣 对比 (`.comparison`) | 文件导入 (`PDF`) | `pkm_workflow_analysis.pdf`<br>`图谱工作流分析.pdf` | 对比分析传统的单向分类记笔记与智宇网状图谱的效率差异，介绍渐进式总结。 |

### 2.2 笔记本 B：项目调研 (5 篇)

| 笔记标识 | 类型 (PageType) | 来源类型 (SourceType) | 关联物理文件名 (en / zh-Hans) | 演示内容要点 |
| :--- | :--- | :--- | :--- | :--- |
| **B-1** | 🟣 对比 (`.comparison`) | 文件导入 (`PDF`) | `luckin_market_report.pdf`<br>`瑞幸与星巴克商业对比报告.pdf` | 1000字以上规范 PDF，对比分析新零售咖啡品牌的成本结构与商业策略。 |
| **B-2** | 🟡 词条 (`.entity`) | 图片扫描 (`OCR`) | `ocr_store_manual.png`<br>`ocr_门店运营手册.png` | 解释具体的定义，以咖啡烘焙度风味变化为例进行展现。 |
| **B-3** | 🔵 主题 (`.concept`) | 网页链接 (`Link`) | — | 咖啡选址规划的方法论，评估客流、租金模型及人群画像。 |
| **B-4** | 🟢 来源 (`.source`) | 语音录入 (`Voice`) | `voice_note_procurement.mp3`<br>`语音_设备采购清单.mp3` | 语音速记口述的采购清单和预算，保存为 `.mp3` 后缀。 |
| **B-5** | 🔵 主题 (`.concept`) | 文件导入 (`Markdown`) | `store_operation_handbook.md`<br>`咖啡门店运营手册.md` | 咖啡店店面日常标准化运营的流程和卫生指南。 |

---

## 3. 1000字以上规范物理文件大纲规范

当应用 Bundle 中不存在物理模板文件时，系统会在沙盒中自动写入以下降级（Fallback）文本内容。这两个文本在 `Common.xcstrings` 中被定义为本地化 Key，且包含高质量的中英文翻译。

### 3.1 物理文件 1：`pkm_methodology.md` (Markdown 格式)
* **大纲结构**：
  1. **标题**：`# 个人知识图谱构建与成长指南`
  2. **第一章：为什么我们需要个人知识图谱**（详细说明碎片化时代传统文件夹分类记笔记的局限性，引出人脑网状外脑的必要性）。
  3. **第二章：知识图谱的核心构建元素**（分段细致科普“主题”、“词条”、“链接”的概念，说明如何用 `[[双链]]` 来建立节点关联）。
  4. **第三章：零门槛的知识积累步骤**（具体步骤包括：捕获灵感、提炼整理、主动关联，介绍如何让未关联笔记融入图谱）。
  5. **第四章：图谱带给你的长期价值**（介绍知识领域合并、跨领域关联对打破知识盲区和激发创造力的长期作用）。
* **字数硬限**：中文和英文正文均必须在 **1000 字以上**，格式排版优雅，完全使用大白话说明。

### 3.2 物理文件 2：`luckin_market_report.pdf` (PDF 格式)
* **大纲结构**：
  1. **标题**：`# 新零售咖啡商业调研与规划报告`
  2. **第一章：行业概况与核心品牌对比**（细致分析当前国内连锁咖啡市场规模，对比瑞幸快取模式与星巴克第三空间模式在运营成本上的差异）。
  3. **第二章：空间定位与选址策略**（分析客区“一桌一插座”、Wi-Fi 6 覆盖对数字游民的留存价值，列举核心商圈与写字楼的选址考量）。
  4. **第三章：财务预算与合伙人规划**（详细计算第一阶段 70 万的财务预算分配，包括门店租金 25 万、软硬装改造 18 万、核心设备采购 12 万、流动资金 15 万，指出目前项目存在 30 万资金缺口，规划合伙人招募）。
  5. **第四章：后续行动路线图**（安排店面装修、供应链物料采购、员工培训的具体时间节点）。
* **字数硬限**：中文和英文正文均必须在 **1000 字以上**，篇章结构规范整齐。

---

## 4. 本地化 XCStrings 映射约定

为了使得系统支持物理文件名的完美国际化，在 `Common.xcstrings` 中必须添加以下配置项：

```json
{
  "demo.filename.methodology": {
    "localizations": {
      "zh-Hans": { "value": "个人知识图谱指南.md" },
      "en": { "value": "personal_knowledge_graph_guide.md" }
    }
  },
  "demo.filename.workflow": {
    "localizations": {
      "zh-Hans": { "value": "图谱工作流分析.pdf" },
      "en": { "value": "pkm_workflow_analysis.pdf" }
    }
  },
  "demo.filename.luckin": {
    "localizations": {
      "zh-Hans": { "value": "瑞幸与星巴克商业对比报告.pdf" },
      "en": { "value": "luckin_market_report.pdf" }
    }
  },
  "demo.filename.survey": {
    "localizations": {
      "zh-Hans": { "value": "咖啡门店运营手册.md" },
      "en": { "value": "store_operation_handbook.md" }
    }
  },
  "demo.filename.ocrFolderScan": {
    "localizations": {
      "zh-Hans": { "value": "ocr_文件夹扫描.png" },
      "en": { "value": "ocr_folder_scan.png" }
    }
  },
  "demo.filename.voiceNoteForget": {
    "localizations": {
      "zh-Hans": { "value": "语音_遗忘曲线_速记.mp3" },
      "en": { "value": "voice_note_forgetting_curve.mp3" }
    }
  },
  "demo.filename.ocrStoreManual": {
    "localizations": {
      "zh-Hans": { "value": "ocr_门店运营手册.png" },
      "en": { "value": "ocr_store_manual.png" }
    }
  },
  "demo.filename.voiceNoteProcure": {
    "localizations": {
      "zh-Hans": { "value": "语音_设备采购清单.mp3" },
      "en": { "value": "voice_note_procurement.mp3" }
    }
  }
}
```

* **强制网关检查**：文件名后缀必须与 `PageSeed` 中声明的 `sourceType` 物理严格匹配（`.md` 对应 `markdown`，`.pdf` 对应 `pdf`，`.mp3` 对应 `voice`，`.png` 对应 `ocr`）。任何后缀与类型不符的情况，在通过 `InitialNotebookGenerator` 初始化写入时都会触发断言报错。
