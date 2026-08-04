# 55 处 L0→L1.5 跨层引用违规修复

**Date:** 2026-08-04
**Architecture:** 修复 audit-arch-dependency.py 检测到的 55 处 L0→L1.5 跨层引用违规，使架构分层审计 100% 通过，为 Task 4 推送扫清障碍。

## 背景

Task 4 收紧 audit-arch-dependency.py 白名单并修复路径 bug 后，审计真正生效，检测到 55 处 L0→L1.5 跨层引用违规，分布在 16 个 L0 文件中。这些违规本质是 L0 协议/实现引用了 L1.5 Domain Models（KnowledgePage/PageChunk/PageType 等）和 L1 Infrastructure Models（OnDeviceModel/LLMProvider/PDFDocumentInfo/VoiceRecording）。

## 违规分类与修复策略

| 类别 | 文件数 | 策略 |
|------|--------|------|
| A 领域契约上移 L1.5 | 8 | 迁移到 Sources/Domain/Protocols/ |
| B 通用契约误引用 | 2 | PDFServiceProtocol 上移 L1.5；DTOs.swift 上移 L1.5 |
| C L0 实现误引用 | 4 | 依赖倒置改签名（UnsupportedSearchIndexer 随 #6 自动消解） |
| D 扩展位置错误 | 1 | extension EvaluationMetric 迁移到 Localization 扩展 |

## Task 清单

### Task 1: 8 个领域协议上移 L1.5 Domain/Protocols/

**Files (move):**
- `Sources/Core/Base/Protocols/EmbeddingProvider.swift` → `Sources/Domain/Protocols/EmbeddingProvider.swift` (7 处)
- `Sources/Core/Base/Protocols/SyncProtocols.swift` → `Sources/Domain/Protocols/SyncProtocols.swift` (5 处)
- `Sources/Core/Base/Protocols/AppStoreProtocol.swift` → `Sources/Domain/Protocols/AppStoreProtocol.swift` (5 处)
- `Sources/Core/Base/Protocols/SpeechServiceProtocol.swift` → `Sources/Domain/Protocols/SpeechServiceProtocol.swift` (3 处)
- `Sources/Core/Base/Protocols/SearchIndexerProtocol.swift` → `Sources/Domain/Protocols/SearchIndexerProtocol.swift` (3 处)
- `Sources/Core/Base/Protocols/OnDeviceLLMServiceProtocol.swift` → `Sources/Domain/Protocols/OnDeviceLLMServiceProtocol.swift` (3 处)
- `Sources/Core/Base/Protocols/LLMServiceProtocol.swift` → `Sources/Domain/Protocols/LLMServiceProtocol.swift` (3 处)
- `Sources/Core/Base/Protocols/LinkServiceProtocol.swift` → `Sources/Domain/Protocols/LinkServiceProtocol.swift` (2 处)

**Steps:**
1. git mv 8 个文件到 Sources/Domain/Protocols/
2. 更新每个文件头注释层级标识 [L0] → [L1.5]
3. 更新 project.yml watchOS target 的源引用（watchOS target 用单文件引用 Domain/Protocols/）
4. make gen 重生成 xcodeproj
5. 编译验证
6. 运行 audit-arch-dependency.py 验证 31 处违规清零（8 文件 × 平均 3.875 处）

### Task 2: 2 个通用契约上移 L1.5

**Files (move):**
- `Sources/Core/Base/Protocols/PDFServiceProtocol.swift` → `Sources/Domain/Protocols/PDFServiceProtocol.swift` (2 处)
- `Sources/Core/Base/Protocols/DTOs.swift` → `Sources/Domain/Protocols/DTOs.swift` (1 处)

**Steps:**
1. git mv 2 个文件
2. 更新文件头注释
3. 更新 project.yml watchOS target
4. make gen + 编译验证
5. 运行 audit 验证 3 处违规清零

### Task 3: 3 个 L0 实现文件依赖倒置

**Files (modify):**
- `Sources/Core/System/Performance/PerformanceService.swift` (1 处) — updatePageMetrics 改接收原始标量
- `Sources/Core/System/Accessibility/AccessibilityService.swift` (1 处) — pageAnnouncement/graphNodeAnnouncement 改接收原始字段
- `Sources/Core/Base/Utils/SnapshotService.swift` (1 处) — saveSnapshot 改接收原始字段

**Steps:**
1. 修改 3 个文件的方法签名，移除 KnowledgePage/GraphNode 参数，改为原始标量
2. 更新所有调用方（grep 搜索调用位置）
3. 编译验证
4. 运行 audit 验证 3 处违规清零

### Task 4: 1 个扩展迁移

**Files (modify):**
- `Sources/Core/Base/Utils/Localized.swift` — 删除 extension EvaluationMetric 块
- `Sources/Localization/Extensions/L10n+Dashboard.swift`（或新建）— 添加 extension EvaluationMetric

**Steps:**
1. 从 Localized.swift 删除 extension EvaluationMetric（约 13 行）
2. 迁移到 Sources/Localization/Extensions/L10n+Dashboard.swift
3. 编译验证
4. 运行 audit 验证 1 处违规清零

### Task 5: UnsupportedSearchIndexer 连带违规消解

**Files (verify):**
- `Sources/Core/Base/Stubs/UnsupportedSearchIndexer.swift` (3 处)

**说明:** Task 1 完成 SearchIndexerProtocol 上移后，此文件改为依赖新位置的协议。若仍违规，需调整 import。

**Steps:**
1. Task 1 完成后运行 audit 检查此文件是否自动消解
2. 若仍违规，检查 import 语句并修复
3. 运行 audit 验证 3 处违规清零

### Task 6: 全量验证 + 提交推送

**Steps:**
1. 运行 audit-arch-dependency.py 验证 55 处违规全部清零
2. 运行 18 项 Gatekeeper 门禁
3. iOS 编译验证
4. 单元测试验证无回归
5. 提交推送（含 Task 4 的 stash 改动一并推送）

## 预期结果

- 55 处 L0→L1.5 跨层引用违规清零
- audit-arch-dependency.py 退出码 0
- pre-push hook 9 项门禁全过
- Task 4（audit 白名单收紧）可一并推送
