# Phase 0：IDL 契约层 + Skip POC 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立 Protobuf IDL 契约层，将 iOS 现有 8 个核心仓储协议对齐 IDL 并重命名为 `*Contract`，搭建 Skip.tools 转译 POC 验证 Android 可行性，为 Phase 1 Android 全面落地铺路。

**Architecture:** 在 `Docs/Contracts/` 用 Protobuf 定义数据模型与 service 接口，通过 `protoc-gen-swift` 生成 Swift message 作为参考，手写对齐 8 个 `*Contract` 协议到 `Sources/Domain/Contracts/`，现有 `Sources/Domain/Protocols/` 中的 8 个协议改为 typealias 指向 Contract（实现层零改动）。Skip POC 拿 `ZhiYuDomain` 包试转译，评估覆盖率与质量，产出 POC 报告作为 Phase 1 决策门。

**Tech Stack:** Protobuf 3 (`libprotoc 35.1` 已装) / `protoc-gen-swift` (需安装) / Swift 6 / Skip.tools (`skip` CLI) / Python 3 (契约校验脚本) / Makefile

## Global Constraints

- 部署目标：iOS 17.0 / macOS 14.0 / watchOS 10.0（不变）
- 严格分层不变：`Sources/Domain/Contracts/` 属于 L1.5 领域层，禁止导入 UIKit/AppKit/SwiftUI
- 注释统一简体中文；文件头标注 `系统层级` + `核心职责`
- 禁止硬编码字符串（用 `L10n.模块.属性`）；禁止硬编码数字（用常量枚举）
- 三平台必须编译通过：`make ios && make mac && make watch`
- 单元测试必须通过：`make test`
- CI 静态分析必须全过：`bash Tools/CI/run-code-static-analysis.sh`
- IDL 改造原则：**只改接口定义层，不改实现层**——现有 `SQLite*Repository` 实现保持不变
- Protobuf 字段编号一旦发布不可变更（向后兼容契约）
- `service` 定义按 gRPC 规范写（即使当前生成本地接口），为未来服务化零成本切换铺路

---

## File Structure

### 新建文件

| 文件 | 职责 |
|------|------|
| `Docs/Contracts/models.proto` | 共享数据模型 IDL |
| `Docs/Contracts/knowledge_repository.proto` | 知识仓储 service 契约 |
| `Docs/Contracts/vector_repository.proto` | 向量分块仓储 service 契约 |
| `Docs/Contracts/vault_repository.proto` | 笔记本元数据仓储 service 契约 |
| `Docs/Contracts/plugin_repository.proto` | 插件仓储 service 契约 |
| `Docs/Contracts/feedback_repository.proto` | 用户反馈仓储 service 契约 |
| `Docs/Contracts/import_record_repository.proto` | 导入记录仓储 service 契约 |
| `Docs/Contracts/file_signature_repository.proto` | 文件签名仓储 service 契约 |
| `Docs/Contracts/rag_governance_repository.proto` | RAG 治理仓储 service 契约 |
| `Tools/contracts/gen-swift.sh` | 调用 protoc 生成 Swift message 参考 |
| `Tools/contracts/verify-contracts.py` | 校验 Swift 协议与 IDL 一致 |
| `Tools/contracts/skip-poc.sh` | Skip POC 转译脚本 |
| `Sources/Domain/Contracts/Contracts.swift` | IDL 对齐的 8 个 Swift Contract 协议 |
| `Tests/Unit/Contracts/ContractBridgeTests.swift` | 协议桥接单元测试 |
| `Docs/Architecture/SKIP_POC_REPORT.md` | Skip POC 验证报告 |

### 修改文件

| 文件 | 改动 |
|------|------|
| `Sources/Domain/Protocols/KnowledgeRepository.swift` | `typealias KnowledgeRepository = KnowledgeRepositoryContract` |
| `Sources/Domain/Protocols/VectorRepository.swift` | `typealias VectorRepository = VectorRepositoryContract` |
| `Sources/Domain/Protocols/VaultRepository.swift` | `typealias VaultRepository = VaultRepositoryContract` |
| `Sources/Domain/Protocols/PluginRepository.swift` | `typealias PluginRepository = PluginRepositoryContract` |
| `Sources/Domain/Protocols/FeedbackRepository.swift` | `typealias FeedbackRepository = FeedbackRepositoryContract` |
| `Sources/Domain/Protocols/ImportRecordRepository.swift` | `typealias ImportRecordRepository = ImportRecordRepositoryContract` |
| `Sources/Domain/Protocols/FileSignatureRepository.swift` | `typealias FileSignatureRepository = FileSignatureRepositoryContract` |
| `Sources/Domain/Protocols/RAGGovernanceRepository.swift` | `typealias RAGGovernanceRepository = RAGGovernanceRepositoryContract`（附属 struct 保留） |
| `Makefile` | 新增 `contracts-tools` / `contracts` / `verify-contracts` / `skip-poc` 四个 target |

---

## Task 1: 安装 protoc-gen-swift 并验证工具链

**Files:**
- Modify: `Makefile`

**Interfaces:**
- Consumes: 系统已装 `protoc 35.1`
- Produces: `protoc-gen-swift` 可执行，`make contracts-tools` 可验证

- [ ] **Step 1: 安装 protoc-gen-swift**

```bash
brew install swift-protobuf
```

- [ ] **Step 2: 验证工具链**

Run:
```bash
protoc --version
which protoc-gen-swift
protoc-gen-swift --version
```
Expected: `libprotoc 35.1` + `protoc-gen-swift 1.x` 路径与版本输出

- [ ] **Step 3: 新增 Makefile target**

在 `Makefile` 的 `.PHONY` 行追加 `contracts contracts-tools verify-contracts skip-poc`，并在文件末尾追加：

```makefile
contracts-tools:
	@echo "🔧 验证 Protobuf 工具链..."
	@protoc --version
	@which protoc-gen-swift || (echo "❌ 未安装 protoc-gen-swift，请运行: brew install swift-protobuf" && exit 1)
	@protoc-gen-swift --version
	@echo "✅ Protobuf 工具链就绪"
```

- [ ] **Step 4: 验证 Makefile target**

Run: `make contracts-tools`
Expected: 输出工具链版本，退出码 0

- [ ] **Step 5: Commit**

```bash
git add Makefile
git commit -m "feat: 新增 contracts-tools Makefile target 验证 Protobuf 工具链"
```

---

## Task 2: 定义数据模型 IDL（models.proto）

**Files:**
- Create: `Docs/Contracts/models.proto`

**Interfaces:**
- Consumes: 无
- Produces: `zhiyu.models.KnowledgePage` / `PageChunk` / `PageEmbedding` / `Vault` / `PluginRecord` / `FeedbackEntry` / `ImportRecord` / `RAGEvaluation` / `RetrievalSnapshot` / `RelevanceJudgment` / `LLMCallLog` 等 message

- [ ] **Step 1: 创建 Contracts 目录**

Run: `mkdir -p Docs/Contracts`

- [ ] **Step 2: 编写 models.proto**

Create `Docs/Contracts/models.proto`:

```protobuf
syntax = "proto3";
package zhiyu.models;

import "google/protobuf/timestamp.proto";

// ========== 枚举 ==========

enum PageType {
  PAGE_TYPE_UNSPECIFIED = 0;
  PAGE_TYPE_CONCEPT = 1;
  PAGE_TYPE_ENTITY = 2;
  PAGE_TYPE_SOURCE = 3;
  PAGE_TYPE_NOTE = 4;
}

enum PageStatus {
  PAGE_STATUS_UNSPECIFIED = 0;
  PAGE_STATUS_DRAFT = 1;
  PAGE_STATUS_ACTIVE = 2;
  PAGE_STATUS_ARCHIVED = 3;
}

enum FeedbackStatus {
  FEEDBACK_STATUS_UNSPECIFIED = 0;
  FEEDBACK_STATUS_PENDING = 1;
  FEEDBACK_STATUS_RESOLVED = 2;
  FEEDBACK_STATUS_REJECTED = 3;
}

// ========== 核心知识模型 ==========

message KnowledgePage {
  string id = 1;              // UUID 字符串
  string title = 2;
  PageType page_type = 3;
  string custom_icon = 4;     // 可空
  string content = 5;         // Markdown
  repeated string aliases = 6;
  repeated string tags = 7;
  PageStatus status = 8;
  double confidence = 9;
  repeated string sources = 10;
  repeated string related_page_ids = 11;  // UUID 字符串列表
  bool is_pinned = 12;
  string content_hash = 13;   // 可空
  google.protobuf.Timestamp created_at = 14;
  google.protobuf.Timestamp updated_at = 15;
  int64 lamport_timestamp = 16;
  string source_url = 17;     // 可空
  string raw_text_snippet = 18;  // 可空
  int64 file_size = 19;
  string source_type = 20;    // 可空
}

message PageChunk {
  string id = 1;              // 格式: pageID_index
  string page_id = 2;         // UUID 字符串
  string parent_id = 3;       // 可空
  string chunk_type = 4;      // "regular" / "summary" / "qa_pair"
  string content = 5;
  string anchor_path = 6;     // 可空
  int32 chunk_index = 7;
  int32 start_index = 8;
  bytes embedding = 9;        // 序列化向量数据，可空
  google.protobuf.Timestamp created_at = 10;
  google.protobuf.Timestamp updated_at = 11;
}

message PageEmbedding {
  string id = 1;              // UUID 字符串，对应 KnowledgePage.id
  repeated float vector = 2;
  string model_name = 3;
}

message PageLink {
  string source_id = 1;
  string target_id = 2;
  string link_type = 3;       // reference / mention / embed
}

// ========== 笔记本 ==========

message Vault {
  string id = 1;              // UUID 字符串
  string name = 2;
  string icon = 3;            // 可空
  string description = 4;     // 可空
  int32 page_count = 5;
  google.protobuf.Timestamp created_at = 6;
  google.protobuf.Timestamp last_accessed_at = 7;
}

// ========== 插件 ==========

message PluginRecord {
  string id = 1;
  string name = 2;
  string author = 3;
  string version = 4;
  string description = 5;
  bool is_installed = 6;
  bool is_enabled = 7;
  string status = 8;
  double load_duration = 9;
  double unload_duration = 10;
  double total_execution_time = 11;
  int32 call_count = 12;
  google.protobuf.Timestamp installed_at = 13;
}

// ========== 反馈 ==========

message FeedbackEntry {
  string id = 1;
  string user_id = 2;         // 可空
  string content = 3;
  int32 rating = 4;           // 1-5
  FeedbackStatus status = 5;
  google.protobuf.Timestamp created_at = 6;
}

// ========== 导入记录 ==========

message ImportRecord {
  string id = 1;
  string category = 2;
  string original_filename = 3;
  string stored_path = 4;
  string status = 5;
  string page_id = 6;         // UUID 字符串，可空
  string raw_text = 7;        // 可空
  string tags = 8;            // JSON 字符串，可空
  int64 file_size = 9;
  google.protobuf.Timestamp created_at = 10;
  google.protobuf.Timestamp completed_at = 11;  // 可空
}

// ========== RAG 治理 ==========

message RAGEvaluation {
  int64 id = 1;
  string query = 2;
  string answer = 3;
  repeated string context_page_ids = 4;
  double faithfulness = 5;
  double relevance = 6;
  double precision = 7;
  double hallucination_rate = 8;
  double citation_accuracy = 9;
  double answer_correctness = 10;
  double context_sufficiency = 11;
  int32 user_rating = 12;     // 0=未评, 1=差评, 2=好评
  google.protobuf.Timestamp created_at = 13;
}

message RetrievalSnapshot {
  int64 id = 1;
  int64 evaluation_id = 2;
  string chunk_id = 3;
  string page_id = 4;
  string content = 5;
  double score = 6;
  int32 rank = 7;
}

message RelevanceJudgment {
  int64 id = 1;
  int64 evaluation_id = 2;
  string chunk_id = 3;
  int32 relevance_level = 4;  // 0-3
}

message LLMCallLog {
  int64 id = 1;
  string model = 2;
  int32 prompt_tokens = 3;
  int32 completion_tokens = 4;
  int32 latency_ms = 5;
  string status = 6;
  google.protobuf.Timestamp created_at = 7;
}

// ========== 统计聚合模型 ==========

message TokenStats {
  int32 prompt = 1;
  int32 completion = 2;
  int32 total = 3;
}

message DailyAIStat {
  string date = 1;
  int32 tokens = 2;
  int32 requests = 3;
}

message AverageRAGScores {
  double faithfulness = 1;
  double relevance = 2;
  double precision = 3;
  double hallucination_rate = 4;
  double citation_accuracy = 5;
  double answer_correctness = 6;
  double context_sufficiency = 7;
}

message LatencyPercentiles {
  int32 p50 = 1;
  int32 p95 = 2;
  int32 p99 = 3;
  int32 sample_count = 4;
}

message TokenEfficiency {
  int32 total_tokens = 1;
  int32 query_count = 2;
  double avg_tokens_per_query = 3;
  double estimated_cost_usd = 4;
}
```

- [ ] **Step 3: 验证 proto 语法**

Run: `protoc --proto_path=Docs/Contracts --python_out=/tmp/proto-test Docs/Contracts/models.proto`
Expected: 无错误，`/tmp/proto-test/models_pb2.py` 生成

- [ ] **Step 4: Commit**

```bash
git add Docs/Contracts/models.proto
git commit -m "feat: 新增 models.proto 定义跨平台共享数据模型 IDL"
```

---

## Task 3: 定义知识仓储 service 契约（knowledge_repository.proto）

**Files:**
- Create: `Docs/Contracts/knowledge_repository.proto`

**Interfaces:**
- Consumes: `zhiyu.models.KnowledgePage`（来自 Task 2）
- Produces: `service KnowledgeRepository` 含 9 个 rpc 方法

- [ ] **Step 1: 编写 knowledge_repository.proto**

Create `Docs/Contracts/knowledge_repository.proto`:

```protobuf
syntax = "proto3";
package zhiyu.domain;

import "models.proto";

service KnowledgeRepository {
  rpc FetchAll(FetchAllRequest) returns (FetchAllResponse);
  rpc Fetch(FetchRequest) returns (FetchResponse);
  rpc Save(SaveRequest) returns (SaveResponse);
  rpc Delete(DeleteRequest) returns (DeleteResponse);
  rpc Search(SearchRequest) returns (SearchResponse);
  rpc FetchBacklinks(FetchBacklinksRequest) returns (FetchBacklinksResponse);
  rpc RenameTag(RenameTagRequest) returns (RenameTagResponse);
  rpc DeleteTag(DeleteTagRequest) returns (DeleteTagResponse);
  rpc Count(CountRequest) returns (CountResponse);
}

message FetchAllRequest {}
message FetchAllResponse { repeated zhiyu.models.KnowledgePage pages = 1; }

message FetchRequest { string page_id = 1; }
message FetchResponse { zhiyu.models.KnowledgePage page = 1; }

message SaveRequest { zhiyu.models.KnowledgePage page = 1; }
message SaveResponse { bool success = 1; }

message DeleteRequest { string page_id = 1; }
message DeleteResponse { bool success = 1; }

message SearchRequest { string query = 1; }
message SearchResponse { repeated zhiyu.models.KnowledgePage pages = 1; }

message FetchBacklinksRequest { string page_id = 1; }
message FetchBacklinksResponse { repeated string backlink_page_ids = 1; }

message RenameTagRequest { string old_tag = 1; string new_tag = 2; }
message RenameTagResponse { bool success = 1; }

message DeleteTagRequest { string tag = 1; }
message DeleteTagResponse { bool success = 1; }

message CountRequest {}
message CountResponse { int32 count = 1; }
```

- [ ] **Step 2: 验证 proto 语法**

Run: `protoc --proto_path=Docs/Contracts --python_out=/tmp/proto-test Docs/Contracts/knowledge_repository.proto`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add Docs/Contracts/knowledge_repository.proto
git commit -m "feat: 新增 knowledge_repository.proto 知识仓储 service 契约"
```

---

## Task 4: 定义向量仓储 service 契约（vector_repository.proto）

**Files:**
- Create: `Docs/Contracts/vector_repository.proto`

**Interfaces:**
- Consumes: `zhiyu.models.PageChunk`（来自 Task 2）
- Produces: `service VectorRepository` 含 7 个 rpc 方法

- [ ] **Step 1: 编写 vector_repository.proto**

Create `Docs/Contracts/vector_repository.proto`:

```protobuf
syntax = "proto3";
package zhiyu.domain;

import "models.proto";

service VectorRepository {
  rpc SaveChunks(SaveChunksRequest) returns (SaveChunksResponse);
  rpc FetchChunks(FetchChunksRequest) returns (FetchChunksResponse);
  rpc FetchAllChunksWithEmbeddings(FetchAllChunksRequest) returns (FetchAllChunksResponse);
  rpc DeleteChunks(DeleteChunksRequest) returns (DeleteChunksResponse);
  rpc CleanupOrphanedChunks(CleanupRequest) returns (CleanupResponse);
  rpc SaveEmbedding(SaveEmbeddingRequest) returns (SaveEmbeddingResponse);
  rpc FetchAllEmbeddings(FetchAllEmbeddingsRequest) returns (FetchAllEmbeddingsResponse);
}

message SaveChunksRequest {
  string page_id = 1;
  repeated zhiyu.models.PageChunk chunks = 2;
}
message SaveChunksResponse { bool success = 1; }

message FetchChunksRequest { string page_id = 1; }
message FetchChunksResponse { repeated zhiyu.models.PageChunk chunks = 1; }

message FetchAllChunksRequest {}
message FetchAllChunksResponse { repeated zhiyu.models.PageChunk chunks = 1; }

message DeleteChunksRequest { string page_id = 1; }
message DeleteChunksResponse { bool success = 1; }

message CleanupRequest {}
message CleanupResponse { int32 deleted_count = 1; }

message SaveEmbeddingRequest {
  string id = 1;
  repeated float vector = 2;
  string model_name = 3;
}
message SaveEmbeddingResponse { bool success = 1; }

message FetchAllEmbeddingsRequest {}
message FetchAllEmbeddingsResponse {
  map<string, EmbeddingEntry> embeddings = 1;
}
message EmbeddingEntry { repeated float vector = 1; }
```

- [ ] **Step 2: 验证 proto 语法**

Run: `protoc --proto_path=Docs/Contracts --python_out=/tmp/proto-test Docs/Contracts/vector_repository.proto`
Expected: 无错误

- [ ] **Step 3: Commit**

```bash
git add Docs/Contracts/vector_repository.proto
git commit -m "feat: 新增 vector_repository.proto 向量仓储 service 契约"
```

---

## Task 5: 定义剩余 6 个仓储 service 契约

**Files:**
- Create: `Docs/Contracts/vault_repository.proto`
- Create: `Docs/Contracts/plugin_repository.proto`
- Create: `Docs/Contracts/feedback_repository.proto`
- Create: `Docs/Contracts/import_record_repository.proto`
- Create: `Docs/Contracts/file_signature_repository.proto`
- Create: `Docs/Contracts/rag_governance_repository.proto`

**Interfaces:**
- Consumes: Task 2 的数据模型
- Produces: 6 个 service 定义，方法签名与现有 Swift 协议一一对应

- [ ] **Step 1: 编写 vault_repository.proto**

Create `Docs/Contracts/vault_repository.proto`:

```protobuf
syntax = "proto3";
package zhiyu.domain;

import "models.proto";

service VaultRepository {
  rpc FetchAllVaults(FetchAllVaultsRequest) returns (FetchAllVaultsResponse);
  rpc SaveVault(SaveVaultRequest) returns (SaveVaultResponse);
  rpc UpdateLastAccessed(UpdateLastAccessedRequest) returns (UpdateLastAccessedResponse);
  rpc DeleteVault(DeleteVaultRequest) returns (DeleteVaultResponse);
  rpc SaveSetting(SaveSettingRequest) returns (SaveSettingResponse);
}

message FetchAllVaultsRequest {}
message FetchAllVaultsResponse { repeated zhiyu.models.Vault vaults = 1; }

message SaveVaultRequest { zhiyu.models.Vault vault = 1; }
message SaveVaultResponse { bool success = 1; }

message UpdateLastAccessedRequest { string vault_id = 1; }
message UpdateLastAccessedResponse { bool success = 1; }

message DeleteVaultRequest { string vault_id = 1; }
message DeleteVaultResponse { bool success = 1; }

message SaveSettingRequest { string key = 1; string value = 2; }
message SaveSettingResponse { bool success = 1; }
```

- [ ] **Step 2: 编写 plugin_repository.proto**

Create `Docs/Contracts/plugin_repository.proto`:

```protobuf
syntax = "proto3";
package zhiyu.domain;

import "models.proto";

service PluginRepository {
  rpc FetchAllInstalled(FetchAllInstalledRequest) returns (FetchAllInstalledResponse);
  rpc Fetch(FetchPluginRequest) returns (FetchPluginResponse);
  rpc Save(SavePluginRequest) returns (SavePluginResponse);
  rpc Delete(DeletePluginRequest) returns (DeletePluginResponse);
  rpc Search(SearchPluginsRequest) returns (SearchPluginsResponse);
  rpc UpdateStats(UpdateStatsRequest) returns (UpdateStatsResponse);
  rpc DeleteAll(DeleteAllRequest) returns (DeleteAllResponse);
}

message FetchAllInstalledRequest {}
message FetchAllInstalledResponse { repeated zhiyu.models.PluginRecord plugins = 1; }

message FetchPluginRequest { string id = 1; }
message FetchPluginResponse { zhiyu.models.PluginRecord plugin = 1; }

message SavePluginRequest { zhiyu.models.PluginRecord plugin = 1; }
message SavePluginResponse { bool success = 1; }

message DeletePluginRequest { string id = 1; }
message DeletePluginResponse { bool success = 1; }

message SearchPluginsRequest { string query = 1; }
message SearchPluginsResponse { repeated zhiyu.models.PluginRecord plugins = 1; }

message UpdateStatsRequest {
  string id = 1;
  optional double load_duration = 2;
  optional double unload_duration = 3;
  optional double total_execution_time = 4;
  optional int32 call_count = 5;
  optional string status = 6;
}
message UpdateStatsResponse { bool success = 1; }

message DeleteAllRequest {}
message DeleteAllResponse { bool success = 1; }
```

- [ ] **Step 3: 编写 feedback_repository.proto**

Create `Docs/Contracts/feedback_repository.proto`:

```protobuf
syntax = "proto3";
package zhiyu.domain;

import "models.proto";

service FeedbackRepository {
  rpc Save(SaveFeedbackRequest) returns (SaveFeedbackResponse);
  rpc FetchAll(FetchAllFeedbackRequest) returns (FetchAllFeedbackResponse);
  rpc FetchByID(FetchFeedbackByIDRequest) returns (FetchFeedbackByIDResponse);
  rpc UpdateStatus(UpdateFeedbackStatusRequest) returns (UpdateFeedbackStatusResponse);
}

message SaveFeedbackRequest { zhiyu.models.FeedbackEntry entry = 1; }
message SaveFeedbackResponse { bool success = 1; }

message FetchAllFeedbackRequest { int32 limit = 1; }
message FetchAllFeedbackResponse { repeated zhiyu.models.FeedbackEntry entries = 1; }

message FetchFeedbackByIDRequest { string id = 1; }
message FetchFeedbackByIDResponse { zhiyu.models.FeedbackEntry entry = 1; }

message UpdateFeedbackStatusRequest {
  string id = 1;
  zhiyu.models.FeedbackStatus status = 2;
}
message UpdateFeedbackStatusResponse { bool success = 1; }
```

- [ ] **Step 4: 编写 import_record_repository.proto**

Create `Docs/Contracts/import_record_repository.proto`:

```protobuf
syntax = "proto3";
package zhiyu.domain;

import "models.proto";

service ImportRecordRepository {
  rpc Save(SaveImportRecordRequest) returns (SaveImportRecordResponse);
  rpc FetchAll(FetchAllImportRecordsRequest) returns (FetchAllImportRecordsResponse);
  rpc FetchByID(FetchImportRecordByIDRequest) returns (FetchImportRecordByIDResponse);
  rpc UpdateStatus(UpdateImportStatusRequest) returns (UpdateImportStatusResponse);
  rpc UpdatePageID(UpdateImportPageIDRequest) returns (UpdateImportPageIDResponse);
  rpc UpdateRawText(UpdateImportRawTextRequest) returns (UpdateImportRawTextResponse);
  rpc UpdateTags(UpdateImportTagsRequest) returns (UpdateImportTagsResponse);
  rpc FetchInProgress(FetchInProgressRequest) returns (FetchInProgressResponse);
  rpc TotalStorageSize(TotalStorageSizeRequest) returns (TotalStorageSizeResponse);
}

message SaveImportRecordRequest { zhiyu.models.ImportRecord record = 1; }
message SaveImportRecordResponse { bool success = 1; }

message FetchAllImportRecordsRequest {
  optional string category = 1;
  int32 limit = 2;
}
message FetchAllImportRecordsResponse { repeated zhiyu.models.ImportRecord records = 1; }

message FetchImportRecordByIDRequest { string id = 1; }
message FetchImportRecordByIDResponse { zhiyu.models.ImportRecord record = 1; }

message UpdateImportStatusRequest {
  string id = 1;
  string status = 2;
  optional google.protobuf.Timestamp completed_at = 3;
}
message UpdateImportStatusResponse { bool success = 1; }

message UpdateImportPageIDRequest { string id = 1; string page_id = 2; }
message UpdateImportPageIDResponse { bool success = 1; }

message UpdateImportRawTextRequest { string id = 1; string raw_text = 2; }
message UpdateImportRawTextResponse { bool success = 1; }

message UpdateImportTagsRequest { string id = 1; string tags = 2; }
message UpdateImportTagsResponse { bool success = 1; }

message FetchInProgressRequest {}
message FetchInProgressResponse { repeated zhiyu.models.ImportRecord records = 1; }

message TotalStorageSizeRequest {}
message TotalStorageSizeResponse { int64 total_bytes = 1; }
```

- [ ] **Step 5: 编写 file_signature_repository.proto**

Create `Docs/Contracts/file_signature_repository.proto`:

```protobuf
syntax = "proto3";
package zhiyu.domain;

service FileSignatureRepository {
  rpc FetchSignatureCount(FetchSignatureCountRequest) returns (FetchSignatureCountResponse);
  rpc SaveSignature(SaveSignatureRequest) returns (SaveSignatureResponse);
  rpc FetchSignature(FetchSignatureRequest) returns (FetchSignatureResponse);
}

message FetchSignatureCountRequest {}
message FetchSignatureCountResponse { int32 count = 1; }

message SaveSignatureRequest {
  string signature = 1;
  string file_path = 2;
  string salt = 3;
}
message SaveSignatureResponse { bool success = 1; }

message FetchSignatureRequest { string file_path = 1; }
message FetchSignatureResponse { string signature = 1; }
```

- [ ] **Step 6: 编写 rag_governance_repository.proto**

Create `Docs/Contracts/rag_governance_repository.proto`:

```protobuf
syntax = "proto3";
package zhiyu.domain;

import "models.proto";

service RAGGovernanceRepository {
  // Token 计费
  rpc LogTokenUsage(LogTokenUsageRequest) returns (LogTokenUsageResponse);
  rpc FetchTokenStats(FetchTokenStatsRequest) returns (zhiyu.models.TokenStats);
  rpc FetchDailyAIStats(FetchDailyAIStatsRequest) returns (FetchDailyAIStatsResponse);
  rpc FetchMonthlyTokenStats(FetchMonthlyTokenStatsRequest) returns (FetchMonthlyTokenStatsResponse);

  // 调用日志
  rpc LogCall(LogCallRequest) returns (LogCallResponse);
  rpc FetchRecentLogs(FetchRecentLogsRequest) returns (FetchRecentLogsResponse);

  // RAG 评估
  rpc SaveRAGEvaluation(SaveRAGEvaluationRequest) returns (SaveRAGEvaluationResponse);
  rpc FetchRAGEvaluations(FetchRAGEvaluationsRequest) returns (FetchRAGEvaluationsResponse);
  rpc CalculateAverageRAGScores(CalculateAverageRAGScoresRequest) returns (zhiyu.models.AverageRAGScores);

  // 检索快照
  rpc SaveRetrievalSnapshots(SaveRetrievalSnapshotsRequest) returns (SaveRetrievalSnapshotsResponse);
  rpc FetchRetrievalSnapshots(FetchRetrievalSnapshotsRequest) returns (FetchRetrievalSnapshotsResponse);

  // 相关性标注
  rpc SaveRelevanceJudgments(SaveRelevanceJudgmentsRequest) returns (SaveRelevanceJudgmentsResponse);

  // 检索质量指标
  rpc CalculateHitRate(CalculateMetricRequest) returns (CalculateMetricResponse);
  rpc CalculateMRR(CalculateMetricRequest) returns (CalculateMetricResponse);
  rpc CalculateNDCG(CalculateMetricRequest) returns (CalculateMetricResponse);
  rpc CalculateRecall(CalculateMetricRequest) returns (CalculateMetricResponse);
  rpc CalculateF1Score(CalculateMetricRequest) returns (CalculateMetricResponse);
  rpc CalculateMAP(CalculateMetricRequest) returns (CalculateMetricResponse);

  // 性能延迟
  rpc CalculateRetrievalLatency(CalculateLatencyRequest) returns (zhiyu.models.LatencyPercentiles);

  // Token 效率
  rpc CalculateTokenEfficiency(CalculateTokenEfficiencyRequest) returns (zhiyu.models.TokenEfficiency);

  // 用户反馈
  rpc UpdateUserRating(UpdateUserRatingRequest) returns (UpdateUserRatingResponse);
}

// === Token 计费 ===
message LogTokenUsageRequest {
  string model = 1;
  int32 prompt_tokens = 2;
  int32 completion_tokens = 3;
}
message LogTokenUsageResponse { bool success = 1; }

message FetchTokenStatsRequest { int32 days = 1; }

message FetchDailyAIStatsRequest { int32 days = 1; }
message FetchDailyAIStatsResponse { repeated zhiyu.models.DailyAIStat stats = 1; }

message FetchMonthlyTokenStatsRequest {}
message MonthlyTokenStat { string month = 1; int32 total = 2; }
message FetchMonthlyTokenStatsResponse { repeated MonthlyTokenStat stats = 1; }

// === 调用日志 ===
message LogCallRequest {
  string model = 1;
  int32 prompt_tokens = 2;
  int32 completion_tokens = 3;
  int32 latency_ms = 4;
  string status = 5;
}
message LogCallResponse { bool success = 1; }

message FetchRecentLogsRequest { int32 limit = 1; }
message FetchRecentLogsResponse { repeated zhiyu.models.LLMCallLog logs = 1; }

// === RAG 评估 ===
message SaveRAGEvaluationRequest { zhiyu.models.RAGEvaluation evaluation = 1; }
message SaveRAGEvaluationResponse { bool success = 1; }

message FetchRAGEvaluationsRequest { int32 limit = 1; }
message FetchRAGEvaluationsResponse { repeated zhiyu.models.RAGEvaluation evaluations = 1; }

message CalculateAverageRAGScoresRequest { int32 days = 1; }

// === 检索快照 ===
message SaveRetrievalSnapshotsRequest { repeated zhiyu.models.RetrievalSnapshot snapshots = 1; }
message SaveRetrievalSnapshotsResponse { bool success = 1; }

message FetchRetrievalSnapshotsRequest { int64 evaluation_id = 1; }
message FetchRetrievalSnapshotsResponse { repeated zhiyu.models.RetrievalSnapshot snapshots = 1; }

// === 相关性标注 ===
message SaveRelevanceJudgmentsRequest { repeated zhiyu.models.RelevanceJudgment judgments = 1; }
message SaveRelevanceJudgmentsResponse { bool success = 1; }

// === 检索质量指标 ===
message CalculateMetricRequest { int32 days = 1; optional int32 k = 2; }
message CalculateMetricResponse { double value = 1; }

// === 性能延迟 ===
message CalculateLatencyRequest { int32 days = 1; }

// === Token 效率 ===
message CalculateTokenEfficiencyRequest { int32 days = 1; }

// === 用户反馈 ===
message UpdateUserRatingRequest { int64 evaluation_id = 1; int32 rating = 2; }
message UpdateUserRatingResponse { bool success = 1; }
```

- [ ] **Step 7: 验证全部 proto 语法**

Run:
```bash
for f in Docs/Contracts/*.proto; do
  echo "验证 $f..."
  protoc --proto_path=Docs/Contracts --python_out=/tmp/proto-test "$f" || exit 1
done
echo "✅ 全部 proto 文件语法正确"
```
Expected: 9 个 proto 文件全部通过

- [ ] **Step 8: Commit**

```bash
git add Docs/Contracts/
git commit -m "feat: 新增 6 个仓储 service 契约 IDL (vault/plugin/feedback/import/file_sig/rag_governance)"
```

---

## Task 6: 编写 Swift 协议生成脚本

**Files:**
- Create: `Tools/contracts/gen-swift.sh`

**Interfaces:**
- Consumes: `Docs/Contracts/*.proto`
- Produces: `/tmp/proto-swift-gen/*.swift`（message 参考，service 协议手写对齐）

- [ ] **Step 1: 创建脚本目录**

Run: `mkdir -p Tools/contracts`

- [ ] **Step 2: 编写 gen-swift.sh**

Create `Tools/contracts/gen-swift.sh`:

```bash
#!/bin/bash
# 生成 Swift Protobuf message 文件（仅数据模型，service 接口手写对齐）
# 用法: bash Tools/contracts/gen-swift.sh

set -e

CONTRACTS_DIR="Docs/Contracts"
OUTPUT_DIR="/tmp/proto-swift-gen"

echo "🔧 从 IDL 生成 Swift Protobuf message..."

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

protoc \
  --proto_path="$CONTRACTS_DIR" \
  --swift_out="$OUTPUT_DIR" \
  "$CONTRACTS_DIR"/*.proto

echo "✅ Swift message 已生成到 $OUTPUT_DIR"
echo "📝 注意: service 协议需手写对齐到 Sources/Domain/Contracts/Contracts.swift"
echo "   生成的 message 文件作为字段定义参考，不直接合入项目（避免引入 swift-protobuf 运行时依赖）"
ls -la "$OUTPUT_DIR"
```

- [ ] **Step 3: 赋予执行权限**

Run: `chmod +x Tools/contracts/gen-swift.sh`

- [ ] **Step 4: 测试脚本**

Run: `bash Tools/contracts/gen-swift.sh`
Expected: `/tmp/proto-swift-gen/` 下生成 9 个 `.swift` 文件

- [ ] **Step 5: Commit**

```bash
git add Tools/contracts/gen-swift.sh
git commit -m "feat: 新增 gen-swift.sh 从 IDL 生成 Swift Protobuf message 参考"
```

---

## Task 7: 编写 IDL 对齐的 Swift Contract 协议

**Files:**
- Create: `Sources/Domain/Contracts/Contracts.swift`

**Interfaces:**
- Consumes: 现有 `KnowledgePage` / `PageChunk` / `PageEmbedding` / `Vault` / `PluginRecord` / `FeedbackEntry` / `ImportRecord` / RAG 模型（来自 `Sources/Domain/Models/`）
- Produces: 8 个 `*Contract` 协议，方法签名与 IDL service 一一对应

- [ ] **Step 1: 创建 Contracts 目录**

Run: `mkdir -p Sources/Domain/Contracts`

- [ ] **Step 2: 编写 Contracts.swift**

Create `Sources/Domain/Contracts/Contracts.swift`:

```swift
//
//  Contracts.swift
//  ZhiYu
//
//  系统层级：[L1.5] 领域层 / 契约
//  核心职责：IDL 对齐的跨平台核心仓储契约协议定义。
//           与 Docs/Contracts/*.proto 一一对应，为未来服务化零成本切换铺路。
//           现有 Sources/Domain/Protocols/*.swift 通过 typealias 桥接到此处。
//

import Foundation

// MARK: - 知识仓储契约
/// 对齐 Docs/Contracts/knowledge_repository.proto
public protocol KnowledgeRepositoryContract: Sendable {
    func fetchAll() async throws -> [KnowledgePage]
    func fetch(id: UUID) async throws -> KnowledgePage?
    func save(_ page: KnowledgePage) async throws
    func delete(id: UUID) async throws
    func search(query: String) async throws -> [KnowledgePage]
    func fetchBacklinks(for id: UUID) async throws -> [UUID]
    func renameTag(old: String, to new: String) async throws
    func deleteTag(_ tag: String) async throws
    func count() async throws -> Int
}

// MARK: - 向量分块仓储契约
/// 对齐 Docs/Contracts/vector_repository.proto
public protocol VectorRepositoryContract: Sendable {
    func saveChunks(_ chunks: [PageChunk], for pageID: UUID) async throws
    func fetchChunks(for pageID: UUID) async throws -> [PageChunk]
    func fetchAllChunksWithEmbeddings() async throws -> [PageChunk]
    func deleteChunks(for pageID: UUID) async throws
    func cleanupOrphanedChunks() async throws -> Int
    func saveEmbedding(id: UUID, vector: [Float], modelName: String) async throws
    func fetchAllEmbeddings() async throws -> [UUID: [Float]]
}

// MARK: - 笔记本元数据仓储契约
/// 对齐 Docs/Contracts/vault_repository.proto
public protocol VaultRepositoryContract: Sendable {
    func fetchAllVaults() async throws -> [Vault]
    func saveVault(_ vault: Vault) async throws
    func updateLastAccessed(id: UUID) async throws
    func deleteVault(id: UUID) async throws
    func saveSetting(key: String, value: String) async throws
}

// MARK: - 插件仓储契约
/// 对齐 Docs/Contracts/plugin_repository.proto
public protocol PluginRepositoryContract: Sendable {
    func fetchAllInstalled() async throws -> [PluginRecord]
    func fetch(id: String) async throws -> PluginRecord?
    func save(_ record: PluginRecord) async throws
    func delete(id: String) async throws
    func search(query: String) async throws -> [PluginRecord]
    func updateStats(id: String, loadDuration: Double?, unloadDuration: Double?,
                     totalExecutionTime: Double?, callCount: Int?, status: String?) async throws
    func deleteAll() async throws
}

// MARK: - 用户反馈仓储契约
/// 对齐 Docs/Contracts/feedback_repository.proto
public protocol FeedbackRepositoryContract: Sendable {
    func save(_ entry: FeedbackEntry) async throws
    func fetchAll(limit: Int) async throws -> [FeedbackEntry]
    func fetchByID(id: String) async throws -> FeedbackEntry?
    func updateStatus(id: String, status: FeedbackStatus) async throws
}

// MARK: - 导入记录仓储契约
/// 对齐 Docs/Contracts/import_record_repository.proto
public protocol ImportRecordRepositoryContract: Sendable {
    func save(_ record: ImportRecord) async throws
    func fetchAll(category: String?, limit: Int) async throws -> [ImportRecord]
    func fetchByID(_ id: String) async throws -> ImportRecord?
    func updateStatus(id: String, status: String, completedAt: Date?) async throws
    func updatePageID(id: String, pageID: String) async throws
    func updateRawText(id: String, rawText: String) async throws
    func updateTags(id: String, tags: String) async throws
    func fetchInProgress() async throws -> [ImportRecord]
    func totalStorageSize() async throws -> Int64
}

// MARK: - 文件签名仓储契约
/// 对齐 Docs/Contracts/file_signature_repository.proto
public protocol FileSignatureRepositoryContract: Sendable {
    func fetchSignatureCount() async throws -> Int
    func saveSignature(_ signature: String, forFilePath filePath: String, salt: String) async throws
    func fetchSignature(forFilePath filePath: String) async throws -> String?
}

// MARK: - RAG 治理仓储契约
/// 对齐 Docs/Contracts/rag_governance_repository.proto
public protocol RAGGovernanceRepositoryContract: Sendable {
    // Token 计费
    func logTokenUsage(model: String, promptTokens: Int, completionTokens: Int) async throws
    func fetchTokenStats(days: Int) async throws -> TokenStats
    func fetchDailyAIStats(days: Int) async throws -> [DailyAIStat]
    func fetchMonthlyTokenStats() async throws -> [(month: String, total: Int)]

    // 调用日志
    func logCall(model: String, promptTokens: Int, completionTokens: Int, latencyMS: Int, status: String) async throws
    func fetchRecentLogs(limit: Int) async throws -> [LLMCallLog]

    // RAG 评估
    func saveRAGEvaluation(_ evaluation: RAGEvaluation) async throws
    func fetchRAGEvaluations(limit: Int) async throws -> [RAGEvaluation]
    func calculateAverageRAGScores(days: Int) async throws -> AverageRAGScores

    // 检索快照
    func saveRetrievalSnapshots(_ snapshots: [RetrievalSnapshot]) async throws
    func fetchRetrievalSnapshots(evaluationID: Int64) async throws -> [RetrievalSnapshot]

    // 相关性标注
    func saveRelevanceJudgments(_ judgments: [RelevanceJudgment]) async throws

    // 检索质量指标
    func calculateHitRate(days: Int, k: Int) async throws -> Double
    func calculateMRR(days: Int) async throws -> Double
    func calculateNDCG(days: Int, k: Int) async throws -> Double
    func calculateRecall(days: Int, k: Int) async throws -> Double
    func calculateF1Score(days: Int, k: Int) async throws -> Double
    func calculateMAP(days: Int) async throws -> Double

    // 性能延迟
    func calculateRetrievalLatency(days: Int) async throws -> LatencyPercentiles

    // Token 效率
    func calculateTokenEfficiency(days: Int) async throws -> TokenEfficiency

    // 用户反馈
    func updateUserRating(evaluationID: Int64, rating: Int) async throws
}
```

- [ ] **Step 3: 验证编译**

Run: `make ios 2>&1 | tail -20`
Expected: 编译通过。若失败，检查 `FeedbackEntry` / `FeedbackStatus` / `ImportRecord` / `RAGEvaluation` / `RetrievalSnapshot` / `RelevanceJudgment` / `LLMCallLog` 是否为 public。

Run: `grep -rn "public struct FeedbackEntry\|public enum FeedbackStatus\|public struct ImportRecord\|public struct RAGEvaluation\|public struct RetrievalSnapshot\|public struct RelevanceJudgment\|public struct LLMCallLog" Sources/ --include="*.swift"`
Expected: 确认这些类型都是 public

- [ ] **Step 4: Commit**

```bash
git add Sources/Domain/Contracts/Contracts.swift
git commit -m "feat: 新增 IDL 对齐的 8 个 Contract 协议定义"
```

---

## Task 8: 桥接现有协议到 Contract（typealias）

**Files:**
- Modify: `Sources/Domain/Protocols/KnowledgeRepository.swift`
- Modify: `Sources/Domain/Protocols/VectorRepository.swift`
- Modify: `Sources/Domain/Protocols/VaultRepository.swift`
- Modify: `Sources/Domain/Protocols/PluginRepository.swift`
- Modify: `Sources/Domain/Protocols/FeedbackRepository.swift`
- Modify: `Sources/Domain/Protocols/ImportRecordRepository.swift`
- Modify: `Sources/Domain/Protocols/FileSignatureRepository.swift`
- Modify: `Sources/Domain/Protocols/RAGGovernanceRepository.swift`

**Interfaces:**
- Consumes: Task 7 的 8 个 `*Contract` 协议
- Produces: 现有协议名通过 typealias 指向 Contract，实现层零改动

- [ ] **Step 1: 改写 KnowledgeRepository.swift**

将 `Sources/Domain/Protocols/KnowledgeRepository.swift` 全文替换为：

```swift
//
//  KnowledgeRepository.swift
//  ZhiYu
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域层协议桥接（typealias 到 IDL 对齐的 Contract）。
//
import Foundation

/// [Domain] 知识库仓库协议（桥接到 IDL 契约）
/// 历史协议名保留，通过 typealias 指向 KnowledgeRepositoryContract，
/// 实现层（如 KnowledgePageRepository）无需改动。
public typealias KnowledgeRepository = KnowledgeRepositoryContract
```

- [ ] **Step 2: 改写 VectorRepository.swift**

将 `Sources/Domain/Protocols/VectorRepository.swift` 全文替换为：

```swift
//
//  VectorRepository.swift
//  ZhiYu
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域层协议桥接（typealias 到 IDL 对齐的 Contract）。
//
import Foundation

/// [Domain] 向量与分块仓储协议（桥接到 IDL 契约）
public typealias VectorRepository = VectorRepositoryContract
```

- [ ] **Step 3: 改写 VaultRepository.swift**

将 `Sources/Domain/Protocols/VaultRepository.swift` 全文替换为：

```swift
//
//  VaultRepository.swift
//  ZhiYu
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域层协议桥接（typealias 到 IDL 对齐的 Contract）。
//
import Foundation

/// [Domain] 笔记本元数据仓储协议（桥接到 IDL 契约）
public typealias VaultRepository = VaultRepositoryContract
```

- [ ] **Step 4: 改写 PluginRepository.swift**

将 `Sources/Domain/Protocols/PluginRepository.swift` 全文替换为：

```swift
//
//  PluginRepository.swift
//  ZhiYu
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域层协议桥接（typealias 到 IDL 对齐的 Contract）。
//
import Foundation

/// [Domain] 插件仓储协议（桥接到 IDL 契约）
public typealias PluginRepository = PluginRepositoryContract
```

- [ ] **Step 5: 改写 FeedbackRepository.swift**

将 `Sources/Domain/Protocols/FeedbackRepository.swift` 全文替换为：

```swift
//
//  FeedbackRepository.swift
//  ZhiYu
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域层协议桥接（typealias 到 IDL 对齐的 Contract）。
//
import Foundation

/// [Domain] 用户反馈仓储协议（桥接到 IDL 契约）
public typealias FeedbackRepository = FeedbackRepositoryContract
```

- [ ] **Step 6: 改写 ImportRecordRepository.swift**

将 `Sources/Domain/Protocols/ImportRecordRepository.swift` 全文替换为：

```swift
//
//  ImportRecordRepository.swift
//  ZhiYu
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域层协议桥接（typealias 到 IDL 对齐的 Contract）。
//
import Foundation

/// [Domain] 导入记录仓储协议（桥接到 IDL 契约）
public typealias ImportRecordRepository = ImportRecordRepositoryContract
```

- [ ] **Step 7: 改写 FileSignatureRepository.swift**

将 `Sources/Domain/Protocols/FileSignatureRepository.swift` 全文替换为：

```swift
//
//  FileSignatureRepository.swift
//  ZhiYu
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域层协议桥接（typealias 到 IDL 对齐的 Contract）。
//
import Foundation

/// [Domain] 文件签名仓储协议（桥接到 IDL 契约）
public typealias FileSignatureRepository = FileSignatureRepositoryContract
```

- [ ] **Step 8: 改写 RAGGovernanceRepository.swift**

将 `Sources/Domain/Protocols/RAGGovernanceRepository.swift` 全文替换为（保留附属 struct）：

```swift
//
//  RAGGovernanceRepository.swift
//  ZhiYu
//
//  系统层级：[L1.5] 领域层
//  核心职责：领域层协议桥接（typealias 到 IDL 对齐的 Contract）+ 附属统计模型。
//
import Foundation

/// [Domain] RAG 全链路质量治理仓储协议（桥接到 IDL 契约）
public typealias RAGGovernanceRepository = RAGGovernanceRepositoryContract

// MARK: - 附属统计模型（保留，对齐 models.proto）

/// Token 统计数据
public struct TokenStats: Sendable, Equatable {
    public let prompt: Int
    public let completion: Int
    public let total: Int

    public init(prompt: Int, completion: Int, total: Int) {
        self.prompt = prompt
        self.completion = completion
        self.total = total
    }
}

/// 每日 AI 统计
public struct DailyAIStat: Sendable, Equatable {
    public let date: String
    public let tokens: Int
    public let requests: Int

    public init(date: String, tokens: Int, requests: Int) {
        self.date = date
        self.tokens = tokens
        self.requests = requests
    }
}

/// 平均 RAG 评分（七维：含幻觉率、引用准确度、答案正确性、上下文充分性）
public struct AverageRAGScores: Sendable, Equatable {
    public let faithfulness: Double
    public let relevance: Double
    public let precision: Double
    public let hallucinationRate: Double
    public let citationAccuracy: Double
    public let answerCorrectness: Double
    public let contextSufficiency: Double

    public init(faithfulness: Double, relevance: Double, precision: Double, hallucinationRate: Double, citationAccuracy: Double, answerCorrectness: Double = 0.0, contextSufficiency: Double = 0.0) {
        self.faithfulness = faithfulness
        self.relevance = relevance
        self.precision = precision
        self.hallucinationRate = hallucinationRate
        self.citationAccuracy = citationAccuracy
        self.answerCorrectness = answerCorrectness
        self.contextSufficiency = contextSufficiency
    }
}

/// 检索延迟百分位分布
public struct LatencyPercentiles: Sendable, Equatable {
    public let p50: Int
    public let p95: Int
    public let p99: Int
    public let sampleCount: Int

    public init(p50: Int, p95: Int, p99: Int, sampleCount: Int) {
        self.p50 = p50
        self.p95 = p95
        self.p99 = p99
        self.sampleCount = sampleCount
    }
}

/// Token 效率与成本摘要
public struct TokenEfficiency: Sendable, Equatable {
    public let totalTokens: Int
    public let queryCount: Int
    public let avgTokensPerQuery: Double
    public let estimatedCostUSD: Double

    public init(totalTokens: Int, queryCount: Int, avgTokensPerQuery: Double, estimatedCostUSD: Double) {
        self.totalTokens = totalTokens
        self.queryCount = queryCount
        self.avgTokensPerQuery = avgTokensPerQuery
        self.estimatedCostUSD = estimatedCostUSD
    }
}
```

- [ ] **Step 9: 验证三平台编译**

Run:
```bash
make ios 2>&1 | tail -5
make mac 2>&1 | tail -5
make watch 2>&1 | tail -5
```
Expected: 三平台全部编译通过（typealias 不破坏现有实现层）

- [ ] **Step 10: 验证单元测试**

Run: `make test 2>&1 | tail -10`
Expected: 全部测试通过（typealias 是零行为变更）

- [ ] **Step 11: Commit**

```bash
git add Sources/Domain/Protocols/
git commit -m "refactor: 8 个仓储协议桥接到 IDL Contract (typealias，实现层零改动)"
```

---

## Task 9: 编写契约一致性校验脚本

**Files:**
- Create: `Tools/contracts/verify-contracts.py`
- Modify: `Makefile`（新增 `contracts` / `verify-contracts` target）

**Interfaces:**
- Consumes: `Docs/Contracts/*.proto` + `Sources/Domain/Contracts/Contracts.swift`
- Produces: 校验报告，不一致时退出码非 0

- [ ] **Step 1: 编写 verify-contracts.py**

Create `Tools/contracts/verify-contracts.py`:

```python
#!/usr/bin/env python3
"""
契约一致性校验脚本。
校验 Sources/Domain/Contracts/Contracts.swift 中的协议方法签名
与 Docs/Contracts/*.proto 中的 service rpc 定义一致。

校验维度：
1. 每个 proto service 在 Swift 中有对应的 *Contract 协议
2. 每个 rpc 方法在 Swift 协议中有对应方法（方法名 PascalCase→camelCase 匹配）
3. proto service 数量与 Swift Contract 协议数量一致

退出码：0=一致，1=不一致
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
CONTRACTS_DIR = REPO_ROOT / "Docs" / "Contracts"
SWIFT_CONTRACTS = REPO_ROOT / "Sources" / "Domain" / "Contracts" / "Contracts.swift"

# proto service → Swift 协议名映射
SERVICE_TO_SWIFT = {
    "KnowledgeRepository": "KnowledgeRepositoryContract",
    "VectorRepository": "VectorRepositoryContract",
    "VaultRepository": "VaultRepositoryContract",
    "PluginRepository": "PluginRepositoryContract",
    "FeedbackRepository": "FeedbackRepositoryContract",
    "ImportRecordRepository": "ImportRecordRepositoryContract",
    "FileSignatureRepository": "FileSignatureRepositoryContract",
    "RAGGovernanceRepository": "RAGGovernanceRepositoryContract",
}


def parse_proto_services(proto_path: Path) -> dict[str, list[str]]:
    """解析 proto 文件，返回 {service_name: [rpc_method_names]}"""
    content = proto_path.read_text(encoding="utf-8")
    services = {}
    for match in re.finditer(r"service\s+(\w+)\s*\{([^}]+)\}", content):
        svc_name = match.group(1)
        body = match.group(2)
        rpcs = re.findall(r"rpc\s+(\w+)\s*\(", body)
        services[svc_name] = rpcs
    return services


def parse_swift_protocols(swift_path: Path) -> dict[str, list[str]]:
    """解析 Swift 文件，返回 {protocol_name: [method_names]}"""
    content = swift_path.read_text(encoding="utf-8")
    protocols = {}
    for match in re.finditer(r"protocol\s+(\w+Contract)\s*[^{]*\{([^}]+)\}", content):
        proto_name = match.group(1)
        body = match.group(2)
        funcs = re.findall(r"func\s+(\w+)\s*\(", body)
        protocols[proto_name] = funcs
    return protocols


def main() -> int:
    if not CONTRACTS_DIR.exists():
        print(f"❌ 契约目录不存在: {CONTRACTS_DIR}", file=sys.stderr)
        return 1
    if not SWIFT_CONTRACTS.exists():
        print(f"❌ Swift 契约文件不存在: {SWIFT_CONTRACTS}", file=sys.stderr)
        return 1

    all_proto_services: dict[str, list[str]] = {}
    for proto_file in sorted(CONTRACTS_DIR.glob("*.proto")):
        services = parse_proto_services(proto_file)
        all_proto_services.update(services)

    swift_protocols = parse_swift_protocols(SWIFT_CONTRACTS)

    errors: list[str] = []

    for svc_name, rpcs in all_proto_services.items():
        swift_name = SERVICE_TO_SWIFT.get(svc_name)
        if not swift_name:
            errors.append(f"proto service '{svc_name}' 未在映射表中定义")
            continue
        if swift_name not in swift_protocols:
            errors.append(f"proto service '{svc_name}' 对应的 Swift 协议 '{swift_name}' 不存在")
            continue

        swift_funcs = swift_protocols[swift_name]
        for rpc in rpcs:
            # PascalCase → camelCase: 首字母小写
            camel = rpc[0].lower() + rpc[1:]
            if camel not in swift_funcs:
                errors.append(
                    f"proto rpc '{svc_name}.{rpc}' 在 Swift 协议 '{swift_name}' 中未找到对应方法 '{camel}'"
                )

    if len(swift_protocols) != len(all_proto_services):
        errors.append(
            f"Swift 协议数量 ({len(swift_protocols)}) 与 proto service 数量 ({len(all_proto_services)}) 不一致"
        )

    if errors:
        print(f"❌ 契约一致性校验失败，发现 {len(errors)} 个问题：", file=sys.stderr)
        for e in errors:
            print(f"  - {e}", file=sys.stderr)
        return 1

    print(f"✅ 契约一致性校验通过：{len(all_proto_services)} 个 service，{len(swift_protocols)} 个 Swift 协议")
    return 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 2: 赋予执行权限**

Run: `chmod +x Tools/contracts/verify-contracts.py`

- [ ] **Step 3: 测试校验脚本**

Run: `python3 Tools/contracts/verify-contracts.py`
Expected: `✅ 契约一致性校验通过：8 个 service，8 个 Swift 协议`

- [ ] **Step 4: 新增 Makefile target**

在 `Makefile` 末尾追加：

```makefile
contracts:
	@echo "📦 从 IDL 生成各平台契约接口..."
	@bash Tools/contracts/gen-swift.sh
	@echo "ℹ️  其他平台 (Kotlin/C#/ArkTS) 生成器将在 Phase 1+ 实现"

verify-contracts:
	@echo "🔍 校验 Swift 契约与 IDL 一致性..."
	@python3 Tools/contracts/verify-contracts.py
```

- [ ] **Step 5: 验证 Makefile target**

Run: `make verify-contracts`
Expected: 校验通过

- [ ] **Step 6: Commit**

```bash
git add Tools/contracts/verify-contracts.py Makefile
git commit -m "feat: 新增 verify-contracts.py 契约一致性校验脚本与 Makefile target"
```

---

## Task 10: 编写契约桥接单元测试

**Files:**
- Create: `Tests/Unit/Contracts/ContractBridgeTests.swift`

**Interfaces:**
- Consumes: Task 7 的 8 个 Contract 协议 + Task 8 的 typealias
- Produces: 验证 typealias 桥接正确，现有协议名仍可被实现层使用

- [ ] **Step 1: 创建测试目录**

Run: `mkdir -p Tests/Unit/Contracts`

- [ ] **Step 2: 编写测试**

Create `Tests/Unit/Contracts/ContractBridgeTests.swift`:

```swift
//
//  ContractBridgeTests.swift
//  ZhiYu
//
//  系统层级：[Test] 单元测试
//  核心职责：验证 IDL Contract 协议与历史协议名的 typealias 桥接正确性。
//

import XCTest
@testable import ZhiYu

final class ContractBridgeTests: XCTestCase {

    // MARK: - 协议桥接验证

    func testKnowledgeRepositoryBridge() {
        XCTAssertTrue(typealiasBridge<KnowledgeRepository, KnowledgeRepositoryContract>())
    }

    func testVectorRepositoryBridge() {
        XCTAssertTrue(typealiasBridge<VectorRepository, VectorRepositoryContract>())
    }

    func testVaultRepositoryBridge() {
        XCTAssertTrue(typealiasBridge<VaultRepository, VaultRepositoryContract>())
    }

    func testPluginRepositoryBridge() {
        XCTAssertTrue(typealiasBridge<PluginRepository, PluginRepositoryContract>())
    }

    func testFeedbackRepositoryBridge() {
        XCTAssertTrue(typealiasBridge<FeedbackRepository, FeedbackRepositoryContract>())
    }

    func testImportRecordRepositoryBridge() {
        XCTAssertTrue(typealiasBridge<ImportRecordRepository, ImportRecordRepositoryContract>())
    }

    func testFileSignatureRepositoryBridge() {
        XCTAssertTrue(typealiasBridge<FileSignatureRepository, FileSignatureRepositoryContract>())
    }

    func testRAGGovernanceRepositoryBridge() {
        XCTAssertTrue(typealiasBridge<RAGGovernanceRepository, RAGGovernanceRepositoryContract>())
    }

    // MARK: - 附属模型验证

    func testTokenStatsModel() {
        let stats = TokenStats(prompt: 100, completion: 50, total: 150)
        XCTAssertEqual(stats.prompt, 100)
        XCTAssertEqual(stats.completion, 50)
        XCTAssertEqual(stats.total, 150)
    }

    func testAverageRAGScoresModel() {
        let scores = AverageRAGScores(
            faithfulness: 0.9, relevance: 0.8, precision: 0.7,
            hallucinationRate: 0.1, citationAccuracy: 0.85
        )
        XCTAssertEqual(scores.faithfulness, 0.9, accuracy: 0.001)
        XCTAssertEqual(scores.answerCorrectness, 0.0, accuracy: 0.001)
    }

    func testLatencyPercentilesModel() {
        let latency = LatencyPercentiles(p50: 100, p95: 500, p99: 1000, sampleCount: 50)
        XCTAssertEqual(latency.p50, 100)
        XCTAssertEqual(latency.sampleCount, 50)
    }

    // MARK: - 辅助方法

    /// 验证两个类型是否相同（typealias 桥接验证）
    private func typealiasBridge<T, U>(_ t: T.Type = T.self, _ u: U.Type = U.self) -> Bool {
        return T.self == U.self
    }
}
```

- [ ] **Step 3: 运行测试**

Run: `make test 2>&1 | grep -E "ContractBridge|Test Suite|passed|failed" | head -20`
Expected: `ContractBridgeTests` 全部通过

- [ ] **Step 4: Commit**

```bash
git add Tests/Unit/Contracts/ContractBridgeTests.swift
git commit -m "test: 新增 Contract 桥接单元测试验证 typealias 一致性"
```

---

## Task 11: Skip.tools POC — 环境搭建与 ZhiYuDomain 转译

**Files:**
- Create: `Tools/contracts/skip-poc.sh`
- Modify: `Makefile`（新增 `skip-poc` target）

**Interfaces:**
- Consumes: `Packages/ZhiYuDomain/`（最小 SPM 包，依赖最少）
- Produces: Skip POC 转译结果日志 + 覆盖率报告

- [ ] **Step 1: 检查 Skip 环境要求**

Run:
```bash
sw_vers -productVersion
xcodebuild -version 2>&1 | head -1
which skip || echo "skip 未安装"
```
Expected: macOS 15.0+ / Xcode 16.4+（若不满足，记录到 POC 报告并跳过转译步骤，仅完成环境评估）

- [ ] **Step 2: 安装 Skip 工具链（若环境满足）**

Run:
```bash
if [ "$(sw_vers -productVersion | cut -d. -f1)" -ge 15 ]; then
  brew install skiptools/tap/skip
  skip --version
else
  echo "⚠️ macOS 版本不满足 Skip 要求（需 15.0+），POC 仅做环境评估"
fi
```
Expected: `skip` CLI 可用，或记录环境不满足

- [ ] **Step 3: 编写 skip-poc.sh 脚本**

Create `Tools/contracts/skip-poc.sh`:

```bash
#!/bin/bash
# Skip.tools POC 验证脚本
# 尝试用 Skip 转译 ZhiYuDomain 包，评估覆盖率

set -e

POC_DIR="/tmp/skip-poc"
DOMAIN_PKG="Packages/ZhiYuDomain"

echo "🔬 Skip.tools POC 验证"
echo "目标: $DOMAIN_PKG"
echo ""

# 检查环境
if ! command -v skip &> /dev/null; then
  echo "⚠️  skip CLI 未安装"
  echo "   安装: brew install skiptools/tap/skip"
  echo "   要求: macOS 15.0+ / Xcode 16.4+"
  echo "   POC 环境评估阶段完成，待环境就绪后重跑"
  exit 0
fi

# 清理旧产物
rm -rf "$POC_DIR"
mkdir -p "$POC_DIR"

echo "📦 初始化 Skip 项目用于 POC..."
cd "$POC_DIR"
skip init --app-id com.zhiyu.poc --name ZhiYuPOC

echo "📋 复制 ZhiYuDomain 源码到 POC 项目..."
mkdir -p Sources
cp -r "$OLDPWD/$DOMAIN_PKG/Sources/ZhiYuDomain" "Sources/ZhiYuDomain"

echo "🔨 执行 Skip 转译..."
skip build 2>&1 | tee skip-build.log || true

echo ""
echo "📊 转译结果分析:"
echo "   - 构建日志: $POC_DIR/skip-build.log"
echo "   - 转译产物: $POC_DIR/Build/Products/"
echo ""
echo "📝 请人工分析 skip-build.log，填写 Docs/Architecture/SKIP_POC_REPORT.md"
```

- [ ] **Step 4: 赋予执行权限**

Run: `chmod +x Tools/contracts/skip-poc.sh`

- [ ] **Step 5: 新增 Makefile target**

在 `Makefile` 末尾追加：

```makefile
skip-poc:
	@echo "🔬 Skip.tools POC 验证..."
	@echo "ℹ️  详细步骤见 Docs/Architecture/SKIP_POC_REPORT.md"
	@bash Tools/contracts/skip-poc.sh
```

- [ ] **Step 6: 执行 POC（若环境满足）**

Run: `make skip-poc`
Expected: 生成构建日志到 `/tmp/skip-poc/skip-build.log`，或提示环境不满足

- [ ] **Step 7: Commit**

```bash
git add Tools/contracts/skip-poc.sh Makefile
git commit -m "feat: 新增 skip-poc.sh 与 Makefile target 验证 Skip.tools 转译"
```

---

## Task 12: 编写 Skip POC 报告与 Phase 1 决策门

**Files:**
- Create: `Docs/Architecture/SKIP_POC_REPORT.md`

**Interfaces:**
- Consumes: Task 11 的转译日志与产物
- Produces: POC 报告 + Phase 1 决策建议

- [ ] **Step 1: 编写 POC 报告模板**

Create `Docs/Architecture/SKIP_POC_REPORT.md`:

```markdown
# Skip.tools POC 验证报告

> **版本**：v1.0
> **日期**：2026-08-XX（填入实际日期）
> **状态**：待填写
> **关联**：`CROSS_PLATFORM_EXPANSION.md` Phase 0

---

## 1. 环境信息

| 项 | 值 |
|----|----|
| macOS 版本 | （填入 `sw_vers -productVersion` 输出） |
| Xcode 版本 | （填入 `xcodebuild -version` 输出） |
| Skip 版本 | （填入 `skip --version` 输出） |
| 转译目标包 | `Packages/ZhiYuDomain` |

---

## 2. 转译覆盖率

### 2.1 源码统计

| 指标 | 值 |
|------|----|
| Swift 文件数 | （填入 `find Packages/ZhiYuDomain -name "*.swift" | wc -l`） |
| 总代码行数 | （填入 `wc -l Packages/ZhiYuDomain/Sources/**/*.swift`） |
| 协议数 | （填入） |
| 模型数 | （填入） |

### 2.2 转译结果

| 指标 | 值 |
|------|----|
| 成功转译文件数 | （填入） |
| 失败转译文件数 | （填入） |
| 转译覆盖率 | （成功数 / 总数 × 100%） |
| 生成的 Kotlin 行数 | （填入） |
| 构建错误数 | （填入） |
| 构建警告数 | （填入） |

---

## 3. 不支持的 Swift 特性清单

列出 Skip 转译过程中报告的不支持或部分支持的 Swift 特性：

| Swift 特性 | 出现位置 | 严重度 | 替代方案 |
|-----------|---------|--------|---------|
| （如 `actor`） | （文件:行号） | 高/中/低 | （手写 Kotlin 替代） |
| （如 `AsyncStream`） | （文件:行号） | 高/中/低 | （回调替代） |
| ... | ... | ... | ... |

---

## 4. 性能与产物体积

| 指标 | 值 |
|------|----|
| 转译耗时 | （秒） |
| 生成的 APK 体积 | （MB，若能构建） |
| Kotlin 源码体积 | （KB） |

---

## 5. Phase 1 决策建议

基于 POC 结果，对 Phase 1（Android 全面落地）的方案选择给出建议：

### 决策矩阵

| 方案 | 覆盖率 | 风险 | 工作量 | 推荐 |
|------|--------|------|--------|------|
| Skip.tools 全面转译 | （填入） | （填入） | （填入） | ✅/❌ |
| KMP 手动重写核心逻辑 | 100% | 中 | 高 | ✅/❌ |
| 混合方案（Skip 转译 + 手写补丁） | （填入） | （填入） | （填入） | ✅/❌ |

### 最终建议

（填入：若覆盖率 ≥ 80% 且不支持的特性有合理替代方案，推荐 Skip 全面转译；否则推荐混合方案或 KMP 手动重写）

### 决策门

- [ ] 覆盖率 ≥ 80% → 可采用 Skip 全面转译
- [ ] 覆盖率 60-80% → 采用混合方案（Skip + 手写补丁）
- [ ] 覆盖率 < 60% → 放弃 Skip，改用 KMP 手动重写

---

## 6. 后续行动项

- [ ] （填入：若采用 Skip，列出 Phase 1 需要的 Skip 配置改造）
- [ ] （填入：若采用 KMP，列出核心逻辑重写计划）
- [ ] （填入：列出需要手写 Kotlin 替代的 Swift 特性）

---

## 7. 附录：构建日志

完整的 `skip build` 日志见 `/tmp/skip-poc/skip-build.log`（或粘贴关键错误片段到此处）。
```

- [ ] **Step 2: 填写 POC 报告（若 Task 11 已执行）**

根据 Task 11 的转译日志，填写 `SKIP_POC_REPORT.md` 中的所有占位符。

若 Task 11 因环境不满足未执行，将报告状态改为"环境不满足，待 macOS 15.0+ 升级后重跑"。

- [ ] **Step 3: Commit**

```bash
git add Docs/Architecture/SKIP_POC_REPORT.md
git commit -m "docs: 新增 Skip.tools POC 验证报告与 Phase 1 决策门"
```

---

## Self-Review

### 1. Spec 覆盖检查

对照 `CROSS_PLATFORM_EXPANSION.md` Phase 0 的任务清单：

| Spec 任务 | 对应 Plan Task | 状态 |
|-----------|---------------|------|
| 提取 40+ Swift 协议为 Protobuf IDL（2-3 周） | Task 2-5（8 个核心仓储） | ✅ 覆盖（注：本计划聚焦 8 个仓储，剩余 32+ 协议在 Phase 0 后续迭代） |
| iOS Swift 协议对齐 IDL，重命名为 `*Contract`（1 周） | Task 7 | ✅ 覆盖 |
| 现有实现改协议名（1 周） | Task 8（typealias 桥接，零改动） | ✅ 覆盖（用 typealias 替代重命名，更优） |
| 搭建 Skip POC（1-2 周） | Task 11-12 | ✅ 覆盖 |
| 评估 Skip 转译质量 | Task 12 | ✅ 覆盖 |

**范围说明**：本计划聚焦 8 个核心仓储协议的 IDL 化。剩余 32+ 协议（AuthServiceProtocol / VaultServiceProtocol / AISynthesisServiceProtocol / ChatServiceProtocol / TaskCenterProtocol / MemoryEngineProtocol / ModelDownloadCapabilities / PromptTemplateEngineCapabilities / RemoteConfigCapabilities / KnowledgeStoreProtocol / PluginEventBus / SyncCoordinatorDelegate / ImportFileStore / KnowledgePageProcessor / AuthStrategy / TagStoreProtocol 等）涉及 UI 框架耦合或 @MainActor 隔离，需在后续迭代中单独处理（它们不属于"纯数据仓储"，IDL 化复杂度更高）。

### 2. 占位符扫描

- ✅ 无 TODO/TBD/"implement later"
- ✅ 所有代码步骤都有完整代码
- ✅ 所有命令都有预期输出
- ⚠️ Task 12 的 POC 报告模板含"（填入）"占位符——这是模板性质，需人工根据 POC 结果填写，不是计划缺陷

### 3. 类型一致性检查

- ✅ `KnowledgeRepositoryContract` 在 Task 7 定义，Task 8 typealias 引用，Task 10 测试验证——名称一致
- ✅ 8 个 Contract 协议名在 Task 7 / Task 8 / Task 9 / Task 10 中一致
- ✅ proto service 名与 Swift 协议名映射在 Task 9 的 `SERVICE_TO_SWIFT` 字典中一致
- ✅ Task 7 的 Swift 方法签名与 Task 3-5 的 proto rpc 一一对应（PascalCase → camelCase）

### 4. 风险点

| 风险 | 缓解 |
|------|------|
| Task 7 编译失败（模型非 public） | Step 3 已包含 grep 检查 |
| Task 8 typealias 不被 DI 容器接受 | typealias 是零行为变更，DI 注册的是 `any Protocol`，typealias 后协议不变 |
| Skip 环境不满足 | Task 11 已处理降级路径，Task 12 报告可标记"环境不满足" |
| 剩余 32+ 协议未 IDL 化 | 已在 Self-Review 说明，属于 Phase 0 后续迭代 |

---

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-08-04-cross-platform-phase0-idl-skip-poc.md`. Two execution options:

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
