# 批次 C 实现计划 — Features 非View Service/ViewModel/Coordinator 补盲

## 目标

Features 非View 覆盖率从 66.24% → 85%（语句覆盖率）

## 当前状态

| 功能域 | 覆盖率 | 文件数 | 差距 85% |
|--------|--------|--------|----------|
| Knowledge | 57.65% | 14 | 672 行 |
| System | 64.16% | 24 | 514 行 |
| AI | 70.85% | 8 | 225 行 |
| Insight | 95.18% | 6 | 0 行 ✅ |
| **合计** | **66.24%** | **52** | **1239 行** |

## 执行策略

按功能域分 3 个子批次，优先补盲低覆盖率文件（<50%），再提升中等覆盖率文件（50-85%）。

### 子批次 C-Knowledge（672 行差距）

| 文件 | 覆盖率 | 差距 | 优先级 |
|------|--------|------|--------|
| IngestFileHandler.swift | 9.91% | 174 | P0 |
| IngestCoordinator.swift | 16.84% | 194 | P0 |
| VaultDataCoordinator.swift | 23.81% | 128 | P0 |
| IngestStore.swift | 33.09% | 70 | P1 |
| IngestService.swift | 46.67% | 103 | P1 |
| CollaborationService.swift | 50.58% | 59 | P2 |
| GitHubAuthStrategy.swift | 52.05% | 48 | P2 |

### 子批次 C-System（514 行差距）

| 文件 | 覆盖率 | 差距 | 优先级 |
|------|--------|------|--------|
| StoreKitService.swift | 20.66% | 77 | P0 |
| AppleAuthStrategy.swift | 20.69% | 55 | P0 |
| ChatCoordinator.swift | 26.58% | 129 | P0 |
| AuthService.swift | 36.56% | 109 | P1 |
| CarrierAuthStrategy.swift | 37.50% | 22 | P1 |
| AISynthesisService.swift | 64.44% | 46 | P2 |
| ModelLabManager.swift | 66.27% | 46 | P2 |
| GlobalModelManager.swift | 69.72% | 48 | P2 |
| SystemStatsCoordinator.swift | 72.73% | 22 | P2 |
| TokenManager.swift | 74.71% | 17 | P2 |
| SynthesisStore.swift | 74.79% | 35 | P2 |

### 子批次 C-AI（225 行差距）

| 文件 | 覆盖率 | 差距 | 优先级 |
|------|--------|------|--------|
| LabChatMessage.swift | 0.00% | 4 | P0 |
| AIWorkflowStore.swift | 77.88% | 15 | P2 |
| PhoneAuthService.swift | 75.86% | 5 | P2 |

## 任务列表

### Task 1: LabChatMessage + IngestFileHandler 补盲
- LabChatMessage.swift (5 行, 0%) — 纯数据模型，容易
- IngestFileHandler.swift (232 行, 9.91%) — 文件导入/去重/OCR 编排

### Task 2: IngestCoordinator + VaultDataCoordinator 补盲
- IngestCoordinator.swift (285 行, 16.84%) — Ingest 协调器
- VaultDataCoordinator.swift (210 行, 23.81%) — Vault 数据协调器

### Task 3: IngestStore + IngestService 补盲
- IngestStore.swift (136 行, 33.09%) — Ingest 状态存储
- IngestService.swift (270 行, 46.67%) — Ingest 服务

### Task 4: StoreKitService + AppleAuthStrategy 补盲
- StoreKitService.swift (121 行, 20.66%) — StoreKit 内购服务
- AppleAuthStrategy.swift (87 行, 20.69%) — Apple 登录策略

### Task 5: ChatCoordinator + AuthService 补盲
- ChatCoordinator.swift (222 行, 26.58%) — Chat 协调器
- AuthService.swift (227 行, 36.56%) — 认证服务

### Task 6: CarrierAuthStrategy + CollaborationService + GitHubAuthStrategy 补盲
- CarrierAuthStrategy.swift (48 行, 37.50%) — 运营商登录
- CollaborationService.swift (172 行, 50.58%) — 协作服务
- GitHubAuthStrategy.swift (146 行, 52.05%) — GitHub 登录

### Task 7: AISynthesisService + ModelLabManager + GlobalModelManager 补盲
- AISynthesisService.swift (225 行, 64.44%) — AI 合成服务
- ModelLabManager.swift (249 行, 66.27%) — 模型实验室
- GlobalModelManager.swift (317 行, 69.72%) — 全局模型管理

### Task 8: 中等覆盖率文件提升（SystemStatsCoordinator/TokenManager/SynthesisStore/AIWorkflowStore/PhoneAuthService）
- SystemStatsCoordinator.swift (187 行, 72.73%)
- TokenManager.swift (174 行, 74.71%)
- SynthesisStore.swift (349 行, 74.79%)
- AIWorkflowStore.swift (217 行, 77.88%)
- PhoneAuthService.swift (58 行, 75.86%)

### Task 9: 批次 C 全量验证 + 覆盖率报告

## 验证标准

- 全量测试 0 失败
- Features 非View 覆盖率 ≥ 85%
- 新增测试以发现问题为目的，发现的问题写入 findings 文档
