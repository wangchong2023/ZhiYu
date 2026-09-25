# 智宇 (ZhiYu) 数据库 Schema 设计

本文件记录了智宇 (ZhiYu) 核心数据库的结构设计及其版本演进历程。系统基于 SQLite 存储，使用 GRDB.swift 进行版本管理与对象映射。

## 0. ER 关系总览

```mermaid
erDiagram
    pages ||--o{ page_chunks : "1:N 分块"
    pages ||--o{ page_links : "双向链接"
    pages ||--o{ import_records : "导入记录"
    pages ||--o{ tag_relations : "标签关联"
    page_chunks ||--o{ page_chunks : "parent_id 层级"
    pages_fts }o--|| pages : "FTS5 同步"
    token_usage }o--|| pages : "AI 调用监控"

    pages {
        UUID id PK
        TEXT title UK
        TEXT content
        TEXT page_type
        INTEGER lamport_timestamp
        DATETIME updated_at
    }
    page_chunks {
        TEXT id PK
        UUID page_id FK
        TEXT parent_id FK
        TEXT chunk_type
        TEXT content
        BLOB embedding
    }
    token_usage {
        INTEGER id PK
        TEXT model
        INTEGER prompt_tokens
        INTEGER completion_tokens
        DATETIME created
    }
```

---

## 1. 核心表结构

### 1.1 `pages` (知识页面表)
存储所有知识条目的元数据与核心内容。

| 字段 | 类型 | 约束 | 说明 |
| :--- | :--- | :--- | :--- |
| `id` | UUID | PRIMARY KEY | 页面唯一标识符 |
| `title` | TEXT | NOT NULL, UNIQUE | 标题（V4 强制唯一索引） |
| `content` | TEXT | | Markdown 原始内容 |
| `page_type` | TEXT | NOT NULL | 页面类型 (concept, entity, source, etc.) |
| `custom_icon` | TEXT | | 用户自定义 SF Symbol 图标 |
| `file_size` | INTEGER | NOT NULL | 物理字节大小 |
| `tags` | TEXT | | 标签列表（以逗号分隔） |
| `aliases` | TEXT | | 别名列表（以逗号分隔） |
| `source_url` | TEXT | | 原始资料链接 (网页或 YouTube) |
| `raw_snippet` | TEXT | | 原始资料片段，用于校验 |
| `lamport_timestamp` | INTEGER | NOT NULL | 逻辑时钟，用于分布式冲突解决 |
| `updated_at` | DATETIME | NOT NULL | 最后更新时间 |
| `vector` | BLOB | | 页面级向量（已废弃，迁至 page_chunks） |

### 1.2 `page_chunks` (RAG 分块表)
支持高级 RAG（层级分块、问答对、摘要）的核心存储。

| 字段 | 类型 | 约束 | 说明 |
| :--- | :--- | :--- | :--- |
| `id` | TEXT | PRIMARY KEY | 分块 ID (格式: p_{uuid}_{index}) |
| `page_id` | UUID | NOT NULL, REFERENCES pages(id) | 所属页面 ID |
| `parent_id` | TEXT | INDEX | 父块 ID（V5 引入，支持 Small-to-Big） |
| `chunk_type` | TEXT | NOT NULL | 类型: `regular`, `summary`, `qa_pair` |
| `content` | TEXT | NOT NULL | 分块文本内容 |
| `embedding` | BLOB | | 向量数据 |
| `start_index` | INTEGER | NOT NULL | 在原文档中的字符偏移位置 |

### 1.3 `token_usage` (AI 资源监控表)
记录 LLM 调用的开销情况（V6 引入）。

| 字段 | 类型 | 约束 | 说明 |
| :--- | :--- | :--- | :--- |
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT | 记录 ID |
| `model` | TEXT | NOT NULL | 使用的模型 ID (e.g., gpt-4o) |
| `prompt_tokens` | INTEGER | NOT NULL | 输入消耗 Token |
| `completion_tokens` | INTEGER | NOT NULL | 输出产生 Token |
| `total_tokens` | INTEGER | NOT NULL | 总消耗 |
| `created` | DATETIME | NOT NULL, INDEX | 产生时间 |

---

## 2. 索引与搜索增强

### 2.1 全文检索 (FTS5)
系统创建了 `pages_fts` 虚拟表，并与 `pages` 表同步：
```sql
CREATE VIRTUAL TABLE pages_fts USING fts5(
    title, 
    content, 
    content='pages', 
    content_rowid='id'
);
```

### 2.2 触发器 (Triggers)
系统通过触发器确保全文检索索引与物理数据自动同步。

---

## 3. 版本迁移历史 (Migration Logs)

| 版本 | 标识 | 变更描述 |
| :--- | :--- | :--- |
| **V1** | `v1_initial` | 创建核心 `pages` 表。 |
| **V2** | `v2_fts` | 启用 SQLite FTS5 全文检索模块。 |
| **V3** | `v3_rag_chunks` | 引入初步的分块存储支持。 |
| **V4** | `v4_unique_title` | **重大变更**：清理同名页面，为 `title` 字段添加 UNIQUE 唯一约束。 |
| **V5** | `v5_upgrade_page_chunks` | **RAG 升级**：为分块表添加 `parent_id` (层级支持) 和 `chunk_type` (分类支持)。 |
| **V6** | `v6_resource_audit` | **资源治理**：创建 `token_usage` 表，支持 Token 消耗统计。 |
| **V7** | `v7_enhanced_governance` | **增强治理**：创建 `llm_call_logs` (调用日志) 和 `rag_evaluations` (质量评估) 表。 |
| **V8** | `v8_karpathy_metadata` | **模式增强**：补全 `pages` 表的物理溯源元数据 (`file_size`, `source_type`)。 |
| **V9** | `v9_distributed_sync` | **同步增强**：引入 `lamport_timestamp` 逻辑时钟，添加 `source_url` 与 `custom_icon` 字段。 |

---

## 4. 增强治理表 (V7 引入)

### 4.1 `llm_call_logs` (LLM 调用日志)
用于系统性能分析与开销审计。

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `id` | INTEGER | PRIMARY KEY |
| `model` | TEXT | 使用的模型 ID |
| `prompt_tokens` | INTEGER | 输入 Token |
| `completion_tokens` | INTEGER | 输出 Token |
| `latency_ms` | INTEGER | 请求耗时 (毫秒) |
| `status` | TEXT | success / failure |
| `created` | DATETIME | 产生时间 |

### 4.2 `rag_evaluations` (RAG 质量评估)
用于持续跟踪 AI 回答的忠实度与相关性。

| 字段 | 类型 | 说明 |
| :--- | :--- | :--- |
| `id` | INTEGER | PRIMARY KEY |
| `query` | TEXT | 用户提问 |
| `answer` | TEXT | AI 回答内容 |
| `faithfulness_score` | DOUBLE | 忠实度评分 (0-1) |
| `relevance_score` | DOUBLE | 相关性评分 (0-1) |
| `context_precision` | DOUBLE | 上下文精准度 (0-1) |
| `evaluator_model` | TEXT | 执行评估的大模型名称 |
| `created` | DATETIME | 评估时间 |
