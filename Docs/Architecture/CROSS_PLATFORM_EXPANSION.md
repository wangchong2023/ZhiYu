# 跨平台客户端扩展设计规格

> **版本**：v1.0
> **日期**：2026-08-04
> **状态**：待审查
> **作者**：USER + CodeFree-O 协作
> **关联文档**：`PLATFORM_PROTOCOL_ARCHITECTURE.md`、`LAYERING_L0_L3.md`、`HIGH_LEVEL_DESIGN.md`

---

## 1. 背景与目标

### 1.1 背景

ZhiYu 当前是纯 Apple 原生 Swift 生态，已建立成熟的 Apple 内跨平台架构（iOS / macOS Catalyst / watchOS），通过 PlatformRegistrar 协议 + DI 容器 + PlatformModifiers + 运行时 Trait 四件套，将业务层 `#if os()` 从 46 处压缩到 10 处（-78%），并有 CI 门禁防止回退。

现需扩展到 **macOS 原生 / Windows / Android / 鸿蒙** 四个新平台，使 ZhiYu 的 AI 原生知识管理能力覆盖全平台。

### 1.2 核心目标

| 目标 | 说明 |
|------|------|
| **原生体验一致性** | 各平台使用平台原生 UI 框架，保证设计系统、动效、辅助功能与 iOS 版相当 |
| **核心逻辑复用** | RAG 管道、AI 中台、Prompt 沙箱、知识图谱等核心能力跨平台复用，避免重复实现 |
| **本地优先** | 所有平台必须能本地运行核心业务逻辑（含云端大模型调用），不依赖后端服务 |
| **团队可承接** | 1-3 人团队，有 Kotlin/Android 经验，可有限招聘补充 |

### 1.3 非目标（当前阶段）

- ❌ 后端服务化（RAG/AI 抽为独立服务端部署）—— 需要较大算力，后期再考虑
- ❌ Web 客户端 —— 暂不涉及
- ❌ visionOS —— 仅有设计文档，暂不实现

---

## 2. 约束与决策

### 2.1 关键约束

| 维度 | 约束 |
|------|------|
| 团队规模 | 1-3 人，有 Kotlin/Android 经验，仅熟悉 Swift/iOS，可有限招聘 |
| 本地优先 | 所有平台必须本地运行核心业务逻辑，后端服务化延后 |
| 原生体验 | 各平台 UI 必须使用平台官方推荐框架，非自绘、非套壳 |
| 核心逻辑复用 | 必须跨平台复用，接受一次性翻译/改造成本 |
| 节奏 | 先定架构再分阶段实施，不一次性铺开 4 个平台 |

### 2.2 关键决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 跨平台方案 | 路径 Y：Skip（iOS+Android）+ 其他平台独立重写 | 各平台风险独立，架构简单，规避 KMP iOS 限制 |
| iOS+Android 逻辑复用 | Skip.tools 转译（Swift → Kotlin） | 现有 Swift 直接转译，零学习成本，iOS 零侵入 |
| Windows 技术栈 | C# + WinUI 3 | 微软官方推荐，原生体验最佳 |
| 鸿蒙技术栈 | ArkTS + ArkUI | 华为官方推荐，原生支持分布式能力 |
| macOS 升级 | 从 Catalyst 升级为原生 macOS target | 原生窗口/菜单/拖放体验更好 |
| 仓库结构 | 核心仓库 + 平台仓库 | iOS 为主，其他平台跟随，契约集中 |
| 接口一致性 | Protobuf IDL 定义核心契约 | 语言无关，各平台生成/对齐，防止漂移 |

### 2.3 已排除方案

| 方案 | 排除理由 |
|------|---------|
| KMP 全平台 | iOS 端 async/actor 映射实验性、GRDB 无法跨平台、双构建系统复杂度高 |
| Flutter | 自绘引擎，违背"原生体验一致性"核心目标 |
| Qt | 自绘非原生，移动端体验差，团队无 C++ 经验，AI 生态弱 |
| 核心服务端化 | 违背"本地优先"约束，需大算力，后期才考虑 |
| Compose Multiplatform (iOS) | iOS 端自绘 Skia，非原生 SwiftUI，体积膨胀 14.6x |
| React Native | JS 桥接性能瓶颈，非原生体验，Meta 自身都不用（Threads） |

---

## 3. 架构设计

### 3.1 总体架构

```
┌─────────────────────────────────────────────────────────────┐
│  平台 UI 层（各平台原生，不共享）                             │
├──────────┬──────────┬──────────┬──────────┬─────────────────┤
│  iOS     │ Android  │ macOS    │ Windows  │ 鸿蒙            │
│  SwiftUI │ Compose  │ SwiftUI  │ WinUI 3  │ ArkUI           │
│  (现有)  │ (Skip转译)│ (原生升级)│ (C#)    │ (ArkTS)         │
├──────────┴──────────┴──────────┴──────────┴─────────────────┤
│  核心逻辑契约层（IDL 定义，各平台生成/对齐）                  │
│  Docs/Contracts/*.proto → Swift / Kotlin / C# / ArkTS       │
├─────────────────────────────────────────────────────────────┤
│  平台核心逻辑实现层                                          │
├─────────────────────────────────────────────────────────────┤
│  iOS + Android（源码级复用）                                 │
│  - Swift 核心逻辑（现有）→ Skip 转译为 Kotlin                │
│  - 本地 RAG 闭环、AI 中台、Prompt 沙箱                       │
│  - 存储：GRDB（iOS）/ Room（Android）                        │
├─────────────────────────────────────────────────────────────┤
│  macOS（直接复用 iOS Swift）                                 │
│  - 现有 Swift 核心逻辑直接使用                               │
│  - 存储：GRDB                                                │
├─────────────────────────────────────────────────────────────┤
│  Windows（独立重写，对齐 IDL 契约）                          │
│  - C# 实现 RAG/AI/Prompt 沙箱核心逻辑                        │
│  - 存储：SQLite.NET                                           │
├─────────────────────────────────────────────────────────────┤
│  鸿蒙（独立重写，对齐 IDL 契约）                             │
│  - ArkTS 实现 RAG/AI/Prompt 沙箱核心逻辑                     │
│  - 存储：RDB（关系型数据库）                                  │
├─────────────────────────────────────────────────────────────┤
│  云端大模型调用层（所有平台共享 API 契约）                    │
│  - OpenAI / Anthropic / 国产大模型 API                       │
│  - 各平台本地逻辑通过 HTTP 调用                              │
└─────────────────────────────────────────────────────────────┘
```

### 3.2 各平台技术栈

| 平台 | UI 框架 | 核心逻辑语言 | 存储层 | 与 iOS 逻辑复用方式 |
|------|---------|------------|--------|------------------|
| iOS | SwiftUI（现有） | Swift（现有） | GRDB（现有） | — |
| Android | Jetpack Compose | Kotlin（Skip 转译） | Room / SQLDelight | 源码级转译复用 |
| macOS | SwiftUI（原生升级） | Swift（现有） | GRDB（现有） | 直接复用 |
| Windows | WinUI 3 | C# | SQLite.NET | 独立重写（对齐 IDL） |
| 鸿蒙 | ArkUI | ArkTS | RDB | 独立重写（对齐 IDL） |

### 3.3 核心逻辑复用矩阵

| 核心能力 | iOS | Android | macOS | Windows | 鸿蒙 |
|---------|-----|---------|-------|---------|------|
| RAG Pipeline | Swift（源） | Skip 转译 | Swift 复用 | C# 重写 | ArkTS 重写 |
| AI 中台（LLM 调用） | Swift（源） | Skip 转译 | Swift 复用 | C# 重写 | ArkTS 重写 |
| Prompt 沙箱 | Swift（源） | Skip 转译 | Swift 复用 | C# 重写 | ArkTS 重写 |
| 知识图谱 | Swift（源） | Skip 转译 | Swift 复用 | C# 重写 | ArkTS 重写 |
| 向量索引 | Swift（源） | Skip 转译 | Swift 复用 | C# 重写 | ArkTS 重写 |
| Embedding | Swift（源） | Skip 转译 | Swift 复用 | C# 重写 | ArkTS 重写 |
| Markdown 编辑 | Swift（源） | Skip 转译 | Swift 复用 | C# 重写 | ArkTS 重写 |
| 本地存储（FTS5+向量） | GRDB | Room | GRDB | SQLite.NET | RDB |

---

## 4. IDL 契约层设计

### 4.1 契约层定位

**目的**：用语言无关的 IDL 定义核心逻辑接口，各平台从 IDL 生成/对齐接口，防止跨平台实现漂移。

**范围**：只定义**接口契约**和**数据模型**，不定义实现。

### 4.2 IDL 工具选择

**选择 Protobuf**（Protocol Buffers）

| 理由 | 说明 |
|------|------|
| 生态成熟 | Swift/Kotlin/C# 都有官方生成器 |
| 类型安全 | 强类型 schema，编译时检查 |
| 版本管理 | proto 文件支持版本演进 |
| 社区广泛 | gRPC、Google API 标准选择 |

**ArkTS 特殊处理**：鸿蒙无官方 proto 生成器，采用**手写对齐**方式（接口定义而已，维护成本低）。

### 4.3 契约文件组织

```
Docs/Contracts/
├── models.proto                    # 共享数据模型
├── knowledge_repository.proto      # 知识仓储接口
├── rag_pipeline.proto              # RAG 管道接口
├── ai_synthesis.proto              # AI 合成接口
├── prompt_sandbox.proto            # Prompt 沙箱接口
├── vector_index.proto              # 向量索引接口
├── embedding_service.proto         # Embedding 服务接口
├── llm_client.proto                # LLM 客户端接口
├── knowledge_graph.proto           # 知识图谱接口
└── markdown_editor.proto           # Markdown 编辑器接口
```

### 4.4 契约示例

#### 4.4.1 数据模型（models.proto）

```protobuf
syntax = "proto3";
package zhiyu.models;

message KnowledgePage {
  string id = 1;           // UUID
  string title = 2;
  string content = 3;      // Markdown
  int64 created_at = 4;    // Unix timestamp (ms)
  int64 updated_at = 5;
  repeated string tags = 6;
  repeated PageLink links = 7;
  PageMetadata metadata = 8;
}

message PageLink {
  string source_id = 1;
  string target_id = 2;
  string link_type = 3;  // reference / mention / embed
}

message PageMetadata {
  int32 word_count = 1;
  int32 chunk_count = 2;
  bool is_indexed = 3;
  string embedding_model = 4;
}

message Chunk {
  string id = 1;
  string page_id = 2;
  string content = 3;
  int32 position = 4;
  repeated float embedding = 5;  // 向量
}

message SynthesisResult {
  string id = 1;
  string content = 2;
  repeated Citation citations = 3;
  int64 created_at = 4;
}

message Citation {
  string page_id = 1;
  string chunk_id = 2;
  string quote = 3;
  int32 start_pos = 4;
  int32 end_pos = 5;
}
```

#### 4.4.2 知识仓储接口（knowledge_repository.proto）

```protobuf
syntax = "proto3";
package zhiyu.domain;

import "models.proto";

service KnowledgeRepository {
  rpc FetchPage(FetchPageRequest) returns (FetchPageResponse);
  rpc SearchPages(SearchPagesRequest) returns (SearchPagesResponse);
  rpc SavePage(SavePageRequest) returns (SavePageResponse);
  rpc DeletePage(DeletePageRequest) returns (DeletePageResponse);
  rpc ListPages(ListPagesRequest) returns (ListPagesResponse);
}

message FetchPageRequest {
  string page_id = 1;
}

message FetchPageResponse {
  zhiyu.models.KnowledgePage page = 1;  // null 表示未找到
}

message SearchPagesRequest {
  string query = 1;
  int32 limit = 2;
  SearchMode mode = 3;
}

enum SearchMode {
  SEARCH_MODE_UNSPECIFIED = 0;
  SEARCH_MODE_FTS = 1;
  SEARCH_MODE_VECTOR = 2;
  SEARCH_MODE_HYBRID = 3;
}

message SearchPagesResponse {
  repeated SearchResult results = 1;
}

message SearchResult {
  zhiyu.models.KnowledgePage page = 1;
  float score = 2;
  repeated string highlights = 3;
}

message SavePageRequest {
  zhiyu.models.KnowledgePage page = 1;
}

message SavePageResponse {
  bool success = 1;
}

message DeletePageRequest {
  string page_id = 1;
}

message DeletePageResponse {
  bool success = 1;
}

message ListPagesRequest {
  int32 offset = 1;
  int32 limit = 2;
  string sort_by = 3;  // created_at / updated_at / title
  bool ascending = 4;
}

message ListPagesResponse {
  repeated zhiyu.models.KnowledgePage pages = 1;
  int32 total = 2;
}
```

### 4.5 各平台生成产物

#### iOS Swift（生成或手写对齐）

```swift
// Sources/Domain/Contracts/KnowledgeRepositoryContract.swift
protocol KnowledgeRepositoryContract: Sendable {
    func fetchPage(id: UUID) async throws -> KnowledgePage?
    func searchPages(query: String, limit: Int, mode: SearchMode) async throws -> [SearchResult]
    func savePage(_ page: KnowledgePage) async throws
    func deletePage(id: UUID) async throws
    func listPages(offset: Int, limit: Int, sortBy: String, ascending: Bool) async throws -> (pages: [KnowledgePage], total: Int)
}
```

#### Android Kotlin（生成）

```kotlin
// contracts/KnowledgeRepositoryContract.kt
interface KnowledgeRepositoryContract {
    suspend fun fetchPage(id: String): KnowledgePage?
    suspend fun searchPages(query: String, limit: Int, mode: SearchMode): List<SearchResult>
    suspend fun savePage(page: KnowledgePage)
    suspend fun deletePage(id: String)
    suspend fun listPages(offset: Int, limit: Int, sortBy: String, ascending: Boolean): Pair<List<KnowledgePage>, Int>
}
```

#### Windows C#（生成）

```csharp
// Contracts/IKnowledgeRepositoryContract.cs
public interface IKnowledgeRepositoryContract {
    Task<KnowledgePage?> FetchPageAsync(Guid id);
    Task<IReadOnlyList<SearchResult>> SearchPagesAsync(string query, int limit, SearchMode mode);
    Task SavePageAsync(KnowledgePage page);
    Task DeletePageAsync(Guid id);
    Task<(IReadOnlyList<KnowledgePage> Pages, int Total)> ListPagesAsync(int offset, int limit, string sortBy, bool ascending);
}
```

#### 鸿蒙 ArkTS（手写对齐）

```typescript
// contracts/KnowledgeRepositoryContract.ets
export interface KnowledgeRepositoryContract {
  fetchPage(id: string): Promise<KnowledgePage | null>
  searchPages(query: string, limit: number, mode: SearchMode): Promise<SearchResult[]>
  savePage(page: KnowledgePage): Promise<void>
  deletePage(id: string): Promise<void>
  listPages(offset: number, limit: number, sortBy: string, ascending: boolean): Promise<{ pages: KnowledgePage[], total: number }>
}
```

### 4.6 iOS 改造范围

| 现有 Swift | 改造动作 | 工作量 |
|-----------|---------|--------|
| `Sources/Domain/Protocols/*.swift`（40+ 协议） | 提取为 IDL，Swift 协议对齐 IDL（重命名为 `*Contract`） | 2-3 周 |
| `Sources/Domain/Models/*.swift` | 数据模型提取为 IDL，Swift struct 对齐 | 1 周 |
| 现有协议实现（如 `SQLiteKnowledgeRepository`） | 改协议名，实现不变 | 1 周 |
| **总计** | | **4-5 周** |

**改造原则**：
- 只改接口定义层，不改实现层
- 现有 Swift 实现保持不变，只改协议名对齐 IDL
- 新增 `Sources/Domain/Contracts/` 目录存放对齐后的 Swift 协议

---

## 5. 仓库结构设计

### 5.1 仓库划分

采用**核心仓库 + 平台仓库**模式：

| 仓库 | 内容 | 职责 |
|------|------|------|
| `ZhiYu`（主仓库，现有） | iOS/macOS Swift + IDL 契约 + 文档 + 工具 | 核心契约定义、iOS/macOS 实现 |
| `ZhiYu-Android` | Android Kotlin + Skip 转译产物 | Android 实现 |
| `ZhiYu-Windows` | C# + WinUI 3 | Windows 实现 |
| `ZhiYu-HarmonyOS` | ArkTS + ArkUI | 鸿蒙实现 |

### 5.2 主仓库结构

```
ZhiYu/（主仓库）
├── Sources/                        # iOS/macOS Swift（现有）
├── Packages/                       # SPM 包（现有）
├── Sources/Domain/Contracts/       # 🆕 IDL 对齐的 Swift 协议
├── Docs/
│   ├── Contracts/                  # 🆕 IDL 契约定义（proto 文件）
│   │   ├── models.proto
│   │   ├── knowledge_repository.proto
│   │   ├── rag_pipeline.proto
│   │   ├── ai_synthesis.proto
│   │   ├── prompt_sandbox.proto
│   │   ├── vector_index.proto
│   │   ├── embedding_service.proto
│   │   ├── llm_client.proto
│   │   ├── knowledge_graph.proto
│   │   └── markdown_editor.proto
│   ├── Architecture/
│   │   └── CROSS_PLATFORM_EXPANSION.md  # 本文档
│   └── ...
├── Tools/
│   └── contracts/                  # 🆕 IDL 生成脚本
│       ├── gen-swift.sh            # 生成 Swift 协议
│       ├── gen-kotlin.sh           # 生成 Kotlin 接口
│       ├── gen-csharp.sh           # 生成 C# 接口
│       ├── gen-arkts.sh            # 生成 ArkTS 接口（模板）
│       └── verify-contracts.py     # 校验各平台接口与 IDL 一致
├── Tests/
│   └── CrossPlatform/
│       └── GoldenTestCases.json    # 🆕 跨平台黄金测试数据
└── Makefile                        # 新增 contracts 相关目标
```

### 5.3 平台子仓库结构（以 Android 为例）

```
ZhiYu-Android/
├── app/                            # Android 应用主模块
│   ├── src/main/kotlin/
│   │   ├── zhiyu/
│   │   │   ├── ui/                 # Compose UI（Skip 转译 + 手写）
│   │   │   ├── domain/             # Domain 实现（Skip 转译）
│   │   │   ├── infrastructure/     # 基础设施（Room 等）
│   │   │   └── platform/           # Android 平台服务
│   │   └── ...
│   └── build.gradle.kts
├── skip-transpiled/                # Skip 转译产物（从主仓库同步）
├── contracts/                      # 从主仓库 IDL 生成的 Kotlin 接口
├── Skip/
│   └── skip.yml                    # Skip 配置
├── README.md
└── build.gradle.kts
```

### 5.4 契约同步机制

| 步骤 | 动作 |
|------|------|
| 1. 修改 IDL | 在主仓库 `Docs/Contracts/*.proto` 修改 |
| 2. 生成各平台接口 | 运行 `make gen-contracts`（调用各平台生成器） |
| 3. 提交主仓库 | 提交 proto 变更 + 生成的 Swift 协议 |
| 4. 同步子仓库 | 子仓库通过 git submodule 或脚本拉取最新 contracts |
| 5. 各平台实现 | 各平台根据新接口更新实现 |
| 6. CI 校验 | `verify-contracts.py` 校验各平台接口与 IDL 一致 |

---

## 6. 分阶段实施路线图

### 6.1 阶段总览

| 阶段 | 目标 | 平台 | 周期 | 风险 | 优先级 |
|------|------|------|------|------|--------|
| Phase 0 | IDL 契约层建立 + Skip POC | iOS 改造 + Android POC | 4-6 周 | 中 | P0 |
| Phase 1 | macOS 原生升级（独立小迭代） | macOS | 2-3 周 | 低 | P0 |
| Phase 2 | Android 上线 | Android | 8-12 周 | 中 | P0 |
| Phase 3 | Windows 客户端 | Windows | 12-16 周 | 高 | P2 |
| Phase 4 | 鸿蒙客户端 | 鸿蒙 | 12-16 周 | 高 | P2 |

> **阶段调整说明**：原 Phase 2（macOS 原生升级）提前为 **Phase 1**，作为 Phase 0 完成后的独立小迭代。原因：代码评估发现 `MacPlatformRegistrar`（20+ macOS 服务已注册）、`MacAppEnvironment`、`#if os(macOS)` 菜单栏扩展等基础设施已就位，实际工作量从原估 4-6 周下调为 2-3 周。原 Android/Windows/鸿蒙顺延为 Phase 2/3/4。

### 6.2 Phase 0：IDL 契约层 + Skip POC（4-6 周）

**目标**：
- 建立 IDL 契约层，iOS 改造完成
- 验证 Skip.tools 转译可行性

**任务**：
1. 提取 40+ Swift 协议为 Protobuf IDL（2-3 周）
2. iOS Swift 协议对齐 IDL，重命名为 `*Contract`（1 周）
3. 现有实现改协议名（1 周）
4. 搭建 Skip POC：拿 UFPCore 或一个小 Feature 模块试转译（1-2 周）
5. 评估 Skip 转译质量，决定是否全面采用

**交付物**：
- `Docs/Contracts/*.proto`（10+ 契约文件）
- `Sources/Domain/Contracts/`（Swift 对齐协议）
- `Tools/contracts/`（生成脚本）
- Skip POC 报告（转译质量、覆盖率、问题清单）

**决策门**：Phase 0 结束时评估 Skip POC 结果，决定 Phase 2 是否全面采用 Skip。

### 6.3 Phase 1：macOS 原生升级（2-3 周，独立小迭代）

**目标**：从 Mac Catalyst 升级为原生 macOS target，获得原生窗口/菜单/拖放体验。

**前置条件**：Phase 0 完成（IDL 契约层就位，避免 macOS 改动与 IDL 改造冲突）。

**代码评估依据**（2026-08-04 盘点）：
- `MacPlatformRegistrar` 已注册 20+ macOS 服务（Pasteboard/FileArchiver/Accessibility/DeviceInfo/URLOpener/ShareSheet/Haptic 等），用 `#if os(macOS)` 隔离
- `MacAppEnvironment` 已实现桌面环境（`screenClass/.expansive`、`interactionStyle/.pointer`）
- `ZhiYuApp.swift:71` 的 `.commands` 菜单栏扩展已是 `#if os(macOS)`，原生 macOS 直接生效
- 全仓 `targetEnvironment(macCatalyst)` 引用仅 ~20 处，集中在 `ContentView`/`AppWindowSceneDelegate`/`iOSPlatformRegistrar`
- CI 门禁已禁止 Features/Domain 层用 `#if os()`，Shared 层 UIKit 用法已通过 `PlatformContext`/`DesignSystem` 抽象隔离

**任务**：
1. **target 配置改造**（0.5 天）：`project.yml` 中 `ZhiYuMac` 的 `platform: iOS` → `macOS`；删除 `SUPPORTS_MACCATALYST`/`SDKROOT: iphoneos`/`TARGETED_DEVICE_FAMILY: 2`；deploymentTarget 对齐 macOS 14
2. **Catalyst 分支清理**（2-3 天）：`ContentView.swift`/`AppWindowSceneDelegate.swift`/`iOSPlatformRegistrar.swift` 中的 `#if targetEnvironment(macCatalyst)` 改为 `#if os(macOS)` 或删除（原生 macOS 走 `MacPlatformRegistrar`，不再需要 Catalyst 降级分支）
3. **UIKit API 替换**（3-5 天）：Catalyst 允许的 `UIKit` 在原生 macOS 需换 `AppKit` 或跨平台 API（`UIColor`→`NSColor`、`UIImage`→`NSImage`、`UIView`→`NSView`、`UIPasteboard`→`NSPasteboard`）。`MacPasteboardService` 已存在，主要检查 Shared 层残留
4. **Info.plist & Entitlements**（0.5 天）：`Sources/MacInfo.plist` 加 `LSApplicationCategoryType`；sandbox/network/entitlements 按原生 macOS 配置
5. **第三方 SDK 验证**（0.5 天）：确认 `WechatOpenSDK`/`ATAuthSDK` 的 `.xcframework` 是否含 macOS slice，必要时换 SDK 或禁用
6. **三平台编译 + 测试验证**（0.5 天）：`make ios && make mac && make watch && make test` 全过

**风险**：
- Shared/Features 层可能有 `UIKit` 残留（Catalyst 下能编译，原生 macOS 报错）——需 `make mac` 编译扫出
- 第三方 `.xcframework` 可能缺 macOS slice
- 风险等级：**低**（平台适配层已就位，无架构性改动）

**优势**：复用现有 Swift 核心逻辑与 `MacPlatformRegistrar` 基础设施，是五个阶段中风险最低的。

**交付物**：
- 原生 macOS target（`platform: macOS`）
- 清理后的 Catalyst 分支代码
- 三平台编译通过 + 单元测试通过

### 6.4 Phase 2：Android 上线（8-12 周）

**目标**：Android 客户端上线，功能与 iOS 对齐

**任务**：
1. Skip.tools 集成到主仓库构建流程（1 周）
2. 核心模块转译：ZhiYuDomain / ZhiYuAICore / UFPStorage（2-3 周）
3. Android 平台服务实现（OCR/Speech/Pasteboard 等）（2-3 周）
4. Room 数据库迁移（GRDB → Room，含 FTS5）（2 周）
5. Android UI 适配（Skip 转译 SwiftUI → Compose，对不支持的组件手写 Compose 替代）（2-3 周）
6. 跨平台黄金测试用例（1 周）
7. 上架 Google Play（1 周）

**风险**：
- Skip 转译覆盖率（部分 Swift 特性可能不支持）
- GRDB → Room 的 FTS5 + 向量索引迁移
- Android 平台服务实现工作量

### 6.5 Phase 3：Windows 客户端（12-16 周）

**目标**：Windows 客户端上线

**任务**：
1. 团队 C#/.NET 学习或招聘（2-4 周，并行）
2. WinUI 3 项目搭建（1 周）
3. 从 IDL 生成 C# 接口（1 周）
4. 核心逻辑 C# 实现（RAG/AI/Prompt 沙箱）（4-6 周）
5. SQLite.NET 存储层（含 FTS5）（2 周）
6. WinUI 3 UI 实现（4-6 周）
7. 上架 Microsoft Store（1 周）

**风险**：
- 团队无 C# 经验，学习曲线高
- 核心逻辑独立重写工作量大
- WinUI 3 生态成熟度

### 6.6 Phase 4：鸿蒙客户端（12-16 周）

**目标**：鸿蒙客户端上线

**任务**：
1. 团队 ArkTS 学习或招聘（2-4 周，并行）
2. DevEco Studio 项目搭建（1 周）
3. 手写对齐 IDL 的 ArkTS 接口（1 周）
4. 核心逻辑 ArkTS 实现（4-6 周）
5. RDB 存储层（2 周）
6. ArkUI UI 实现（4-6 周）
7. 上架华为应用市场（1 周）

**风险**：
- 鸿蒙生态成熟度
- ArkTS 学习曲线
- 核心逻辑独立重写工作量大

---

## 7. 跨平台一致性保证

### 7.1 IDL 契约校验

**机制**：CI 自动校验各平台接口与 IDL 一致

```bash
# Tools/contracts/verify-contracts.py
# 1. 从 proto 生成各平台接口
# 2. 比对各平台实际接口文件
# 3. 不一致则 CI 失败
```

### 7.2 黄金测试用例

**机制**：定义一套跨平台测试数据，各平台跑同一套用例

```
Tests/CrossPlatform/GoldenTestCases.json
{
  "rag_pipeline": [
    {
      "id": "rag_001",
      "input": { "document": "...", "chunk_size": 512 },
      "expected": { "chunk_count": 5, "first_chunk": "..." }
    }
  ],
  "ai_synthesis": [
    {
      "id": "syn_001",
      "input": { "query": "...", "context_pages": ["..."] },
      "expected": { "citations_count": 3, "contains_quote": true }
    }
  ]
}
```

各平台 CI 跑黄金测试，结果上传到主仓库的测试报告系统。

### 7.3 接口契约评审流程

**任何 IDL 变更必须经过**：
1. 修改 `Docs/Contracts/*.proto`
2. 运行 `make gen-contracts` 生成各平台接口
3. 提交 MR，触发 CI 校验
4. 评审通过后合入
5. 通知各平台仓库同步

---

## 8. 风险与缓解

| 风险 | 严重度 | 缓解措施 |
|------|--------|---------|
| Skip.tools 转译覆盖率不足 | 高 | Phase 0 POC 验证，不达标则 Android 改用 KMP 手动重写 |
| GRDB → Room FTS5 迁移复杂 | 高 | 保留 GRDB on iOS，Android 用 Room + 平台 actual 实现 FTS5 |
| Windows/鸿蒙核心逻辑重写成本高 | 高 | 分阶段实施，先 Android/macOS 上线再启动 |
| 团队技能不足（C#/ArkTS） | 中 | 招聘补充 + 培训，Phase 3/4 并行准备 |
| IDL 契约漂移 | 中 | CI 自动校验 + 评审流程 |
| Skip 项目规模小（3.1k star） | 中 | SkipZero 模式可随时弹出，iOS 不受影响 |
| 鸿蒙生态成熟度 | 中 | Phase 4 启动前重新评估 |

---

## 9. 开放问题（待后续决策）

| 问题 | 说明 | 决策时机 |
|------|------|---------|
| 后端服务化 | RAG/AI 抽为独立服务端部署，需要大算力 | Phase 1-2 完成后评估 |
| Web 客户端 | 是否需要 Web 版 | 视用户需求 |
| visionOS | 现有设计文档是否实现 | 视 Vision Pro 市场表现 |
| Compose Multiplatform for Windows | Phase 3 是否改用 CMP 替代 WinUI 3 | Phase 3 启动前评估 |
| 鸿蒙 KMP-Native | Phase 4 是否考虑 KMP 替代纯 ArkTS | Phase 4 启动前评估 |

---

## 10. 参考资料

- [Skip.tools 官方文档](https://skip.tools/docs/)
- [Kotlin Multiplatform 官方文档](https://kotlinlang.org/docs/multiplatform.html)
- [Kotlin/Native Swift 互操作](https://kotlinlang.org/docs/native-objc-interop.html)
- [Protobuf 官方文档](https://protobuf.dev/)
- ZhiYu `PLATFORM_PROTOCOL_ARCHITECTURE.md` — 现有跨平台协议分层
- ZhiYu `LAYERING_L0_L3.md` — 严格分层规范
