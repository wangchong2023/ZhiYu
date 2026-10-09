# 智宇 (ZhiYu) 规范治理矩阵 (Standards Governance Matrix)

> **适用场景**：Code Agent 驱动开发（AI 编程助手生成/修改代码）+ 人工评审 + CI 自动化门禁。
> **核心目标**：建立「**事前 Agent 可遵循 → 事后 CI 可检查 → 失败 Agent 可自愈**」的闭环治理体系。
> **定位**：本文是 5 大规范领域（架构/界面/开发/API/测试）与 CI 检查体系的**权威映射总表**，解决「规范写了但落不了地」「CI 报了但不知道改哪」「Agent 写代码不知道遵守什么」三大痛点。

---

## 背景与动机

### 痛点量化

智宇项目经过持续建设，已积累 **31 个规范文档、共 8691 行**，覆盖架构分层、界面设计、编码风格、API 接口、测试用例 5 大领域。CI 检查体系已建成 **41 项静态分析 + 17 项 pre-push 门禁 + 6 项测试结构度量**。然而，规范落地仍存在显著痛点：

| 痛点 | 量化数据 | 影响 |
|------|----------|------|
| **规范体量过大，Agent 无法全量加载** | 31 个文档 / 8691 行 | Agent 上下文窗口有限，全量加载严重稀释注意力，90% 内容与当前任务无关 |
| **事前遵循极弱** | 事前遵循落地率仅 **17%**（仅 AGENTS.md 红线 1 项） | Agent 写代码时缺乏可执行指引，生成代码大量违规，靠 CI 事后拦截返工 |
| **事后检查覆盖不均** | 事后检查落地率 **80%**（62/77 项） | 整体较好，但 API 规范 CI 落地率 **0%**、测试规范 CI 落地率 **44%**，存在盲区 |
| **CI 报错缺乏修复指引** | 多数脚本仅输出 `file:line: error` | Agent 无法据报错自动修复，需人工排查规范条款和修复方式 |
| **规范与 CI 脱节** | 20 项缺口（事前 5 项 + 事后 15 项） | 规范写了但无 CI 检查，或 CI 检查了但无规范文档对应 |

### 范式转变：从「事后拦截」到「事前遵循」

传统治理模式依赖 CI 事后拦截：

```
Agent 生成代码（无规范指引）→ CI 拦截违规 → 人工/Agent 排查 → 修复 → 重新提交
                                    ↑                                    │
                                    └────────────────────────────────────┘
                                         多轮返工，效率低下
```

本治理矩阵推动范式转变，让 Agent **生成即合规**：

```
Agent 读取速查卡 → 按需加载规范 → 基于模板生成 → 生成即合规 → CI 兜底验证
                                                      │              │
                                                      └──────┬───────┘
                                                             │
                                                        偶尔失败时
                                                             │
                                                             ▼
                                                    CI 报错含修复指引
                                                             │
                                                     Agent 自动修复
                                                             │
                                                         重新提交
```

**核心转变**：将治理重心从「CI 拦截」前移至「Agent 生成阶段」，CI 从"第一道防线"降级为"最后兜底"。

### 治理目标

| 目标维度 | 现状 | 目标 | 衡量方式 |
|----------|------|------|----------|
| 事前遵循落地率 | 17% | **≥ 80%** | AGENTS.md 速查卡覆盖的规范条款数 / 总规范条款数 |
| 事后检查落地率 | 80% | **≥ 95%** | 有 CI 检查的规范条款数 / 总规范条款数 |
| API 规范 CI 覆盖 | 0% | **100%** | API 规范 CI 检查项数 / API 规范条款数 |
| 测试规范 CI 覆盖 | 44% | **≥ 80%** | 测试规范 CI 检查项数 / 测试规范条款数 |
| Agent 上下文消耗 | 8691 行（全量） | **~424 行**（减少 95%） | 单次任务加载的规范行数 |
| CI 失败自愈率 | 未度量 | **≥ 90%** | Agent 据 CI 报错自动修复成功数 / CI 失败总数 |
| 缺口总数 | 20 项 | **≤ 5 项** | 未落地的规范条款数 |

---

## 治理整体架构

### 四层架构总览

```
┌─────────────────────────────────────────────────────────────────────┐
│                     规范治理四层架构                                   │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  Layer 1: 规范层 (Standards Layer)                              │ │
│  │  ───────────────────────────────────────────────────────────── │ │
│  │  31 个规范文档 / 8691 行 / 5 大领域                              │ │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────┐ │ │
│  │  │ 架构规范  │ │ 界面规范  │ │ 开发规范  │ │ API 规范  │ │测试  │ │ │
│  │  │ 5 个文档  │ │ 3 个文档  │ │ 4 个文档  │ │ 1 个文档  │ │规范  │ │ │
│  │  └──────────┘ └──────────┘ └──────────┘ └──────────┘ └──────┘ │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              │                                      │
│                              │ Agent 按需读取                       │
│                              ▼                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  Layer 2: 事前遵循层 (Pre-compliance Layer)                     │ │
│  │  ───────────────────────────────────────────────────────────── │ │
│  │  让 Agent 生成代码时即合规，而非靠 CI 事后拦截                     │ │
│  │                                                                 │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │ │
│  │  │ AGENTS.md    │  │ 渐进式披露   │  │ 代码模板库   │            │ │
│  │  │ 速查决策表    │  │ 三层加载机制  │  │ 5 类模板     │            │ │
│  │  │ 场景化加载    │  │ L0/L1/L2    │  │ View/VM/    │            │ │
│  │  │ 工作流检查点  │  │ 424 行/任务  │  │ Service/    │            │ │
│  │  │              │  │              │  │ Test        │            │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘            │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              │                                      │
│                              │ Agent 生成代码                       │
│                              ▼                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  Layer 3: 事后检查层 (Post-check Layer)                         │ │
│  │  ───────────────────────────────────────────────────────────── │ │
│  │  CI 门禁兜底，拦截事前未遵循的违规                                 │ │
│  │                                                                 │ │
│  │  ┌───────────┐   ┌───────────┐   ┌───────────────────────┐    │ │
│  │  │pre-commit  │   │ pre-push   │   │ CI 流水线              │    │ │
│  │  │1 项（密钥） │   │17 项+编译  │   │41 项静态分析+测试+覆盖率│    │ │
│  │  │→ 增强 4 项  │   │            │   │                       │    │ │
│  │  └───────────┘   └───────────┘   └───────────────────────┘    │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              │                                      │
│                              │ 检查失败时                           │
│                              ▼                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  Layer 4: 自愈层 (Self-healing Layer)                           │ │
│  │  ───────────────────────────────────────────────────────────── │ │
│  │  Agent 据 CI 报错自动修复，而非人工排查                            │ │
│  │                                                                 │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐            │ │
│  │  │ 统一报错格式  │  │ 规范条款引用  │  │ 修复建议     │            │ │
│  │  │gatekeeper   │  │ 📋 @Doc#章节 │  │ 🔧 具体示例  │            │ │
│  │  │_reporter.py │  │              │  │ ✅ 修复代码  │            │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘            │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### 各层职责与核心组件

| 层级 | 职责 | 核心组件 | 交付物 | 状态 |
|------|------|----------|--------|------|
| **Layer 1: 规范层** | 定义"什么是对的" | 31 个规范文档（5 大领域） | 规范条款全集 | ✅ 已建成 |
| **Layer 2: 事前遵循层** | 让 Agent "生成即合规" | AGENTS.md 速查卡 + 渐进式披露 + 代码模板 | Agent 可执行指引 | ⚠️ 建设中（17%→80%） |
| **Layer 3: 事后检查层** | 拦截"不对的" | pre-commit + pre-push + CI 流水线 | 64 项自动化检查 | ✅ 已建成（80%→95%） |
| **Layer 4: 自愈层** | Agent "自动修复" | 统一报错格式 + 规范引用 + 修复建议 | Agent 可解析的报错 | ⚠️ 规划中 |

### 治理数据流

```
                    ┌─────────────────┐
                    │  Layer 1: 规范层  │
                    │  31 个规范文档    │
                    └────────┬────────┘
                             │
                    Agent 按需读取（渐进式披露）
                             │
                             ▼
                    ┌─────────────────┐
                    │ Layer 2: 事前遵循 │
                    │ 速查卡 → 模板    │
                    │ → 生成合规代码    │
                    └────────┬────────┘
                             │
                    Agent 提交代码
                             │
                             ▼
              ┌──────────────────────────┐
              │   Layer 3: 事后检查       │
              │  pre-commit → pre-push   │
              │  → CI 流水线              │
              └──────────┬───────────────┘
                         │
                    ┌────┴────┐
                    │         │
                 ✅ 通过    ❌ 失败
                    │         │
                    │         ▼
                    │  ┌──────────────┐
                    │  │ Layer 4: 自愈 │
                    │  │ 解析报错      │
                    │  │ → 读取规范    │
                    │  │ → 生成修复    │
                    │  └──────┬───────┘
                    │         │
                    │         │ 修复后重新提交
                    │         │
                    └─────────┘
                         │
                    合并至主分支
```

### 治理架构设计原则

| 原则 | 说明 | 落地体现 |
|------|------|----------|
| **规范即上下文** | 规范文档必须可被 Agent 直接读取，而非仅供人阅读 | AGENTS.md 索引 31 个文档 + 渐进式披露按需加载 |
| **事前优于事后** | 让 Agent 生成即合规，优于靠 CI 事后拦截返工 | 速查卡 + 代码模板 + 场景化加载（Layer 2） |
| **报错即指引** | CI 报错必须包含规范引用 + 修复建议，Agent 据此自愈 | gatekeeper_reporter.py 统一报错格式（Layer 4） |
| **模板即合规** | 代码模板预置合规结构，Agent 基于模板生成即满足规范 | 5 类代码模板（View/VM/Service/Test/Header） |
| **门禁即边界** | CI 门禁是最后防线，Agent 在门禁内自由生成，越界即被拦截 | 64 项自动化检查（Layer 3） |
| **渐进式披露** | 按需加载规范，避免全量加载超出上下文窗口 | 三层架构（L0 常驻/L1 摘要/L2 精准全文） |

### 本文档与四层架构的映射

| 本文章节 | 对应架构层 | 作用 |
|----------|-----------|------|
| 背景与动机 | — | 阐明痛点、范式转变、可量化目标 |
| 治理整体架构 | 全局 | 四层架构总览、数据流、设计原则 |
| 第 0 节 治理闭环模型 | Layer 2→3→4 | 事前→事后→自愈的闭环流程 |
| 第 1-5 节 治理矩阵 | Layer 1↔3 | 5 大领域规范条款 × CI 检查 × Agent 指引映射 |
| 第 6-7 节 门禁与报错 | Layer 3→4 | pre-commit 增强 + CI 报错统一格式 |
| 第 8 节 事前遵循机制 | Layer 2 | 决策树 + 场景化加载 + 模板 + CI 映射 + 工作流 |
| 第 8.8 节 渐进式披露 | Layer 2 | 三层加载机制，上下文消耗减少 95% |
| 第 9 节 代码模板库 | Layer 2 | 5 类模板，Agent 生成代码的起点 |
| 第 10 节 缺口汇总 | Layer 1↔2↔3 | 20 项缺口（事前 5 + 事后 15） |
| 第 11 节 改进路线图 | 全局 | 4 阶段 Phase，从 17% 到 80% |
| 第 12 节 Agent 最佳实践 | Layer 2→3→4 | Agent 开发全流程 + 自检清单 |
| 第 13 节 落地操作指南 | Layer 2 | 3 步操作 + 端到端 Demo + 验证清单 |

---

## 0. 治理闭环模型

```
┌─────────────────────────────────────────────────────────────────┐
│                    Code Agent 驱动开发闭环                        │
│                                                                 │
│  ① 事前遵循（Agent 写代码时）                                     │
│     AGENTS.md 红线 → 规范文档可读 → 代码模板 → 生成即合规           │
│                          │                                      │
│                          ▼                                      │
│  ② 事后检查（CI / pre-push）                                      │
│     41 项静态分析 + 测试门禁 + 编译告警 + 覆盖率                    │
│                          │                                      │
│                    ┌─────┴─────┐                                │
│                    ▼           ▼                                │
│                 ✅ 通过      ❌ 失败                              │
│                    │           │                                │
│                    │           ▼                                │
│                    │    ③ 失败自愈（Agent 修复）                   │
│                    │     CI 报错 → 规范条款引用 → 修复建议          │
│                    │     → Agent 读取规范 → 生成修复 → 重提         │
│                    │           │                                │
│                    └───────────┘                                │
│                       回到 ②                                    │
└─────────────────────────────────────────────────────────────────┘
```

### 0.1 三层防护与 Agent 角色

| 防护层 | 触发时机 | 检查项数 | Agent 角色 | 现状 |
|--------|----------|----------|-----------|------|
| **pre-commit** | `git commit` | 1 项（密钥） | Agent 提交前自检 | ⚠️ 极弱 |
| **pre-push** | `git push` | 17 项 + 编译 | Agent 推送前修复 | ✅ 较强 |
| **CI 流水线** | 分支推送 | 41 项 + 测试 + 覆盖率 | Agent 收到报错后自愈 | ✅ 最强 |

### 0.2 Agent 驱动开发的关键设计原则

1. **规范即上下文**：规范文档必须可被 Agent 直接读取（AGENTS.md 已索引），Agent 写代码前应先读规范。
2. **报错即指引**：CI 脚本报错必须包含「规范条款引用 + 修复建议」，Agent 据此自愈，而非人工排查。
3. **模板即合规**：代码模板预置合规结构，Agent 基于模板生成即满足规范。
4. **门禁即边界**：CI 门禁是最后防线，Agent 在门禁内自由生成，越界即被拦截并指引修复。

---

## 1. 架构设计规范治理矩阵

> **规范文档**：`LAYERING_L0_L3.md`、`ARCHITECTURE_4PLUS1.md`、`ADR.md`、`PLATFORM_PROTOCOL_ARCHITECTURE.md`、`HIGH_LEVEL_DESIGN.md`

### 1.1 规范条款 × CI 检查 × Agent 指引

| 规范条款 | CI 检查脚本 | 触发阶段 | 失败提示 | Agent 事前遵循指引 | Agent 事后修复指引 | 状态 |
|----------|------------|----------|----------|-------------------|-------------------|------|
| **L1.5 领域层禁止导入 UIKit/AppKit/SwiftUI** | `audit-arch-domain-purity.py` | CI + pre-push | `file:line: error: [Domain Purity Violation] 违规导入平台相关依赖包 'UIKit'。L1.5 领域层必须保持绝对的平台无关性。` | Agent 写 `Sources/Domain/` 代码时，仅 `import Foundation`，禁止 `import UIKit/AppKit/SwiftUI/ActivityKit/WatchKit` | 删除违规 import，如需平台能力则定义协议在 `Domain/Protocols/`，实现在 `Platforms/` | ✅ 已落地 |
| **L1.5 领域层禁止 #if os()** | `audit-arch-domain-purity.py` | CI + pre-push | `file:line: error: [Domain Purity Violation] 禁止在领域层直接使用 #if os 进行平台特化分支。` | Agent 写 Domain 层时，平台差异通过协议定义，不写条件编译 | 移除 `#if os()`，改为协议抽象 + `Platforms/` 实现 | ✅ 已落地 |
| **L0-L3 单向依赖（禁止反向导入）** | `audit-arch-dependency.py` | CI + pre-push | 输出违规依赖链 | Agent 写代码时遵循：L3→L2→L1.5→L1→L0，绝不反向 | 检查 import 链，将反向依赖改为协议抽象 + DI 注入 | ✅ 已落地 |
| **L2 禁止直接依赖 L1 物理实现** | `audit-arch-dependency.py` | CI + pre-push | 输出违规依赖 | Agent 写 Features 层时，通过 `@Dependency` 注入协议，不直接 import `SQLiteStore` | 改为 `@Dependency(\.pageStore)` 协议注入 | ✅ 已落地 |
| **DI 双注册（协议 + 具体类型）** | `check-arch-di-registration.py` | CI + pre-push | 输出未双注册的服务 | Agent 注册服务时，同时注册协议类型和具体类型 | 补充 `container.register(service, for: Protocol.self)` + `container.register(service, for: ConcreteType.self)` | ✅ 已落地 |
| **@Dependency testValue 必须注册** | `audit-dependency-key-test-value.py` | CI | 输出缺失 testValue 的 DependencyKey | Agent 新增 DependencyKey 时，必须提供 `testValue` | 补充 `testValue` 实现（NoOp 或 Mock） | ✅ 已落地 |
| **SPM 包依赖完整性** | `audit-arch-spm-deps.py` + `check-arch-spm-integrity.sh` | CI | 输出违规 SPM 依赖 | Agent 修改 `Package.swift` 时遵循分层依赖规则 | 修正 Package.swift dependencies | ✅ 已落地 |
| **UFPCore 纯净化（不泄漏业务层）** | `audit-arch-ufpcore-purity.py` | CI + pre-push | 输出 UFPCore 中的业务泄漏 | Agent 写 UFPCore 时，仅放通用底座，不放业务逻辑 | 将业务代码移至 Domain/Features | ✅ 已落地 |
| **平台宏仅限 ModuleRegistrar** | `check-code-platform-macros.py` | CI | 输出违规 `#if os()` 位置 | Agent 写平台差异时，`#if os()` 仅在 `ModuleRegistrar.swift` 和 `Platforms/` | 将 `#if os()` 移至 `Platforms/` 或 `ModuleRegistrar` | ✅ 已落地 |
| **开源适配器放置规范** | `check-arch-opensource-adapters.py` + `check-arch-opensource-placement.py` | CI | 输出违规放置的开源适配器 | Agent 写开源适配器时，放在 `Packages/` 对应 SPM 包 | 移至正确 SPM 包路径 | ✅ 已落地 |
| **开源库内部依赖本地化** | `check-arch-opensource-internal-deps.py` | CI + pre-push | 输出引用远端 URL 的 Package.swift | Agent 修改开源库 Package.swift 时，不引用远端 URL | 改为本地路径依赖 | ✅ 已落地 |
| **单例冻结（禁止新增 static let shared）** | `audit-singleton-frozen.py` | CI + pre-push | 输出新增的 `static let shared` | Agent 写单例时，用 `@Dependency` 替代 `static let shared` | 改为 `@Dependency` 注入 | ✅ 已落地 |
| **@EnvironmentObject 冻结** | `audit-environment-object.py` | CI + pre-push | 输出新增的 `@EnvironmentObject` | Agent 写 View 时，用 `@Environment` 替代 `@EnvironmentObject` | 改为 `@Environment` + `@Observable` | ✅ 已落地 |
| **@Inject 废弃（新代码用 @Dependency）** | `audit-inject-deprecated.py` | CI + pre-push | 输出 `Sources/` 中新增的 `@Inject` | Agent 写新代码时，用 `@Dependency` 不用 `@Inject` | 改为 `@Dependency(\.xxx)` | ✅ 已落地 |
| **视图重复检测** | `audit-arch-view-duplication.py` | CI | 输出重复视图结构 | Agent 写 View 时，复用现有组件 | 提取公共组件 | ✅ 已落地 |
| **层标记注释** | `check-arch-layer-markers.sh` | CI | 输出缺失层标记的文件 | Agent 写文件时，按 `file-header-template.md` 添加层标记 | 补充文件头层标记 | ✅ 已落地 |

### 1.2 架构规范缺口

| 缺口 | 影响 | 优先级 | 建议方案 |
|------|------|--------|----------|
| CI 报错未引用 `LAYERING_L0_L3.md` 具体条款编号 | Agent 无法自动定位规范条款 | 中 | **落地步骤**：修改 `audit-arch-domain-purity.py` 第 67/75 行报错消息，追加 `@Docs/Architecture/LAYERING_L0_L3.md#红线1` |
| ADR 决策无 CI 检查 | 架构决策可能被违反 | 低 | 难以自动化，依赖人工评审 |

### 1.3 Agent 事前遵循：架构规范上下文注入

Agent 在编写涉及架构分层的代码前，应读取以下上下文：

```
必读上下文（Agent 写代码前加载）：
  1. AGENTS.md → 「架构：L0–L3 严格分层」章节 → 获取依赖规则
  2. LAYERING_L0_L3.md → 第 2 节「跨层依赖禁用矩阵」→ 获取依赖方向
  3. PLATFORM_PROTOCOL_ARCHITECTURE.md → 获取 #if os() 协议化模式

Agent 决策树（写 import 时）：
  当前文件在 Sources/Domain/ → 仅允许 import Foundation
  当前文件在 Sources/Features/ → 禁止 import Infrastructure/*，用 @Dependency
  当前文件在 Packages/UFPCore/ → 禁止 import 任何上层模块
  需要 #if os() → 仅在 ModuleRegistrar.swift 或 Platforms/ 中写
```

---

## 2. 界面规范治理矩阵

> **规范文档**：`UI_COMPONENTS.md`、`VISUAL_SYSTEM.md`、`WATCHOS_DESIGN_GUIDELINES.md`

### 2.1 规范条款 × CI 检查 × Agent 指引

| 规范条款 | CI 检查脚本 | 触发阶段 | 失败提示 | Agent 事前遵循指引 | Agent 事后修复指引 | 状态 |
|----------|------------|----------|----------|-------------------|-------------------|------|
| **禁止硬编码 UI 尺寸（padding/frame/font size）** | `audit-design-token-magic-numbers.py` | CI + pre-push | `file:line: error: 魔鬼数字 N，应使用 DesignSystem Token` | Agent 写 SwiftUI 视图时，间距用 `DesignSystem.standardPadding`，字号用 `DesignSystem.titleFontSize`，圆角用 `DesignSystem.cornerRadius` | 将 `.padding(12)` 改为 `.padding(DesignSystem.standardPadding)`，将 `.font(.system(size: 16))` 改为 `DesignSystem.titleFont` | ✅ 已落地 |
| **禁止硬编码颜色（.red/.blue/hex）** | `audit-code-magic-strings.py` | CI + pre-push | 输出硬编码颜色违规 | Agent 用 `Color.theme.*` 或 `DesignSystem.Colors.*` | 将 `.foregroundColor(.red)` 改为 `.foregroundColor(Color.theme.error)` | ✅ 已落地 |
| **DesignSystem Token 分层（Token 不跨层引用）** | `audit-design-token-layering.py` | CI | 输出跨层引用的 Token | Agent 写 Token 时，`Spacing.swift` 不引用 `Typography.swift` | 解除跨层引用 | ✅ 已落地 |
| **DesignSystem Token 命名算术** | `audit-design-token-arithmetic.py` | CI | 输出非标准 Token 命名 | Agent 写 Token 时，遵循 `<语义>.<尺寸>` 命名 | 重命名 Token | ✅ 已落地 |
| **DesignSystem Token 预算（Token 数量上限）** | `audit-design-token-budget.py` | CI | 输出超预算 Token | Agent 新增 Token 前检查是否可复用现有 Token | 合并冗余 Token | ✅ 已落地 |
| **快照测试统一环境注入** | `check-code-snapshot-environment.py --strict` | CI + pre-push | 输出手动 `.environment()` 违规 | Agent 写快照测试时，用 `.snapshotEnvironment()` 一次性注入 | 将手动 `.environment(xxx)` 替换为 `.snapshotEnvironment()` | ✅ 已落地 |
| **HIG 合规（Apple Human Interface Guidelines）** | `check-design-hig.py` | CI | 输出 HIG 违规项 | Agent 写 UI 时遵循 Apple HIG（导航栏/标签栏/手势规范） | 按 HIG 建议调整 | ✅ 已落地 |
| **布局规范（Layout 模板复用）** | `check-design-layout.py` | CI | 输出布局违规 | Agent 写布局时，复用 `Layouts/` 下的模板 | 提取布局至 `Layouts/` | ✅ 已落地 |

### 2.2 界面规范缺口

| 缺口 | 影响 | 优先级 | 落地方案 |
|------|------|--------|----------|
| `audit-design-token-magic-numbers.py` 报错未给出具体 Token 名 | Agent 不知道该用哪个 Token | 高 | **落地步骤**：修改脚本 `check_swift_line()` 函数，在报错消息中追加建议 Token 映射表（如 `12 → DesignSystem.standardPadding`），映射表维护在脚本顶部 `TOKEN_SUGGESTIONS` 字典 |
| `VISUAL_SYSTEM.md` 无对应 CI 检查 | 视觉系统规范可能被违反 | 中 | **落地步骤**：评估 `check-design-hig.py` 是否已覆盖 `VISUAL_SYSTEM.md` 的核心条款，未覆盖的条款补充至现有脚本 |
| `WATCHOS_DESIGN_GUIDELINES.md` 无专项 CI 检查 | watchOS 界面规范依赖人工评审 | 低 | **落地步骤**：watchOS 视图文件较少，暂依赖快照测试 + 人工评审，后续视规模决定是否新增脚本 |

### 2.3 Agent 事前遵循：界面规范上下文注入

```
必读上下文（Agent 写 SwiftUI 视图前加载）：
  1. AGENTS.md → 「四大强制质量红线」第 3 条 → DesignSystem Token 强约束
  2. UI_COMPONENTS.md → 第 1 节 DesignSystem → 获取 Token 清单
  3. development-standards.md → 「DesignSystem Token」条目 → 获取使用规范

Agent 决策树（写 SwiftUI 修饰符时）：
  .padding(N) → 改为 .padding(DesignSystem.<语义>Padding)
  .font(.system(size: N)) → 改为 DesignSystem.<语义>Font
  .cornerRadius(N) → 改为 DesignSystem.<语义>CornerRadius
  .foregroundColor(.red/.blue) → 改为 Color.theme.<语义>
  .frame(width: N, height: N) → 改为 DesignSystem.Metrics.<语义>
  写快照测试 → 用 .snapshotEnvironment()，不手动 .environment()
```

---

## 3. 开发规范治理矩阵

> **规范文档**：`swift-coding-style.md`、`development-standards.md`、`implementation-patterns.md`、`srp-file-organization.md`、`config-conventions.md`、`file-header-template.md`

### 3.1 规范条款 × CI 检查 × Agent 指引

| 规范条款 | CI 检查脚本 | 触发阶段 | 失败提示 | Agent 事前遵循指引 | Agent 事后修复指引 | 状态 |
|----------|------------|----------|----------|-------------------|-------------------|------|
| **圈复杂度 ≤ 15** | `check-code-complexity.py` | CI | 输出超阈值函数及复杂度值 | Agent 写函数时，分支不超过 15 个，超限则拆分 | 拆分函数为多个小函数 | ✅ 已落地 |
| **函数 NBNC ≤ 100 行** | SwiftLint `function_body_length` | CI + pre-push | SwiftLint 报错 | Agent 写函数时，超过 100 行则拆分 | 拆分为多个职责单一的函数 | ✅ 已落地 |
| **禁止硬编码中文字符串** | `check-code-localization.py` | CI + pre-push + 编译期 | 输出硬编码中文位置 | Agent 写 UI 文本时，用 `L10n.模块.属性` | 将中文字符串注册到 `L10n+XXX.swift` + `.xcstrings` | ✅ 已落地 |
| **禁止直接调用 .tr()** | `check-code-localization.py` | CI + pre-push + 编译期 | 输出直接 `.tr()` 调用 | Agent 写 UI 文本时，用 `L10n.模块.属性`，不直接 `.tr()` | 在 `L10n+XXX.swift` 定义强类型属性 | ✅ 已落地 |
| **禁止硬编码 UserDefaults key** | `audit-code-magic-strings.py` | CI + pre-push | 输出硬编码 forKey 字符串 | Agent 用 `AppConstants.Keys.Storage.*` | 将 `forKey: "xxx"` 改为 `forKey: AppConstants.Keys.Storage.xxx` | ✅ 已落地 |
| **禁止硬编码 URL** | `audit-code-magic-strings.py` | CI + pre-push | 输出硬编码 URL | Agent 用 `AppConstants.URLs.*` | 将 `"https://..."` 改为 `AppConstants.URLs.xxx` | ✅ 已落地 |
| **禁止魔鬼数字（业务逻辑层）** | `audit-code-business-magic-numbers.py --strict` | CI + pre-push | 输出业务逻辑中的魔鬼数字 | Agent 写业务逻辑时，阈值/限制抽取为常量枚举 | 将 `3`、`5`、`15` 抽取为 `FeatureConstants.*` 或 `DomainConstants.*` | ✅ 已落地 |
| **禁止魔鬼数字（UI 层）** | `audit-design-token-magic-numbers.py` | CI + pre-push | 输出 UI 魔鬼数字 | Agent 写 UI 时，用 DesignSystem Token | 将数字改为 DesignSystem Token | ✅ 已落地 |
| **禁止强制解包 (!)** | `audit-code-force-unwrap.py` | CI | 输出强制解包位置 | Agent 用 `guard let` / `if let` / `as?` | 将 `foo!` 改为 `guard let foo` 或 `foo ?? defaultValue` | ✅ 已落地 |
| **禁止强制类型转换 (as!)** | `audit-code-force-unwrap.py` | CI | 输出强制转换位置 | Agent 用 `as?` + `??` | 将 `obj as! Type` 改为 `obj as? Type ?? defaultValue` | ✅ 已落地 |
| **禁止 UserDefaults.standard** | `audit-userdefaults-standard.py` | CI + pre-push | 输出新增 `UserDefaults.standard` | Agent 用 `@AppStorage` + `AppConstants.Keys.Storage.*` | 改为 `@AppStorage(AppConstants.Keys.Storage.xxx)` | ✅ 已落地 |
| **文件头注释规范** | `check-code-file-headers.py` | CI | 输出缺失/不规范文件头 | Agent 写新文件时，按 `file-header-template.md` 添加文件头 | 补充 `系统层级` + `核心职责` 标注 | ✅ 已落地 |
| **Swift 编译告警即错误** | `check-code-swift-warnings.sh` | CI | 编译告警阻断 | Agent 写代码时消除所有 warning | 修复编译告警 | ✅ 已落地 |
| **SwiftLint 严格模式** | `swiftlint --strict` | CI + pre-push | SwiftLint 报错 | Agent 遵循 SwiftLint 规则 | 修复 SwiftLint 违规 | ✅ 已落地 |
| **代码重复率 < 3%** | `assert-code-duplication.py` | CI + pre-push | 输出重复代码块 | Agent 写代码时复用现有函数，不复制粘贴 | 提取公共函数 | ✅ 已落地 |
| **死代码检测** | `audit-code-dead-code.py` | CI | 输出未使用的代码 | Agent 不写无用代码 | 删除死代码 | ✅ 已落地 |
| **文件大小限制** | `audit-code-file-size.py` | CI | 输出超大文件 | Agent 写文件时，超限则按 SRP 拆分 | 按 `srp-file-organization.md` 拆分 | ✅ 已落地 |
| **MainActor 安全** | `check-code-mainactor-safety.py` | CI | 输出缺失 @MainActor 的 UI 代码 | Agent 写 ViewModel/View 时标注 `@MainActor` | 补充 `@MainActor` | ✅ 已落地 |
| **绝对路径禁止** | `check-code-absolute-paths.py` | CI + pre-push | 输出硬编码绝对路径 | Agent 用相对路径或 `Bundle.module` | 改为相对路径 | ✅ 已落地 |
| **Unsafe String.Index** | `check-code-unsafe-string-index.py` | CI | 输出不安全的 String.Index 使用 | Agent 用 `String.Index` 时确保在范围内 | 添加范围检查 | ✅ 已落地 |
| **DI 崩溃风险** | `check-code-di-crash-risk.py` | CI | 输出可能崩溃的 DI 解析 | Agent 用 `resolveOptional` 替代 `resolve` | 将 `resolve` 改为 `resolveOptional ?? fallback` | ✅ 已落地 |
| **Inject 安全** | `check-code-inject-safety.py --strict` | CI + pre-push | 输出不安全的 @Inject 使用 | Agent 新代码用 `@Dependency` | 改为 `@Dependency` | ✅ 已落地 |
| **存储常量规范** | `check-code-storage-constants.py` | CI | 输出硬编码存储常量 | Agent 用 `StorageConstants.*` | 抽取为 `StorageConstants` | ✅ 已落地 |
| **Prompt 治理** | `check-code-prompt-governance.py` | CI | 输出未治理的 Prompt | Agent 写 Prompt 时注册到 `PromptRegistry` | 将 Prompt 注册到 `PromptRegistry` | ✅ 已落地 |
| **插件校验** | `check-code-plugin-validation.py` | CI | 输出插件校验违规 | Agent 写插件时遵循 `PLUGIN_SDK.md` | 修复插件校验 | ✅ 已落地 |
| **工具脚本质量** | `audit-quality-scripts.py` | CI + pre-push | 输出脚本质量问题 | Agent 写脚本时遵循脚本规范 | 修复脚本质量 | ✅ 已落地 |
| **文档漂移检测** | `check-doc-drift.py --strict` | CI | 输出文档与代码不一致的引用 | Agent 修改类/协议/方法时同步更新文档 | 更新文档引用 | ✅ 已落地 |
| **免白名单过期检测** | `exemption_registry.py check-stale --strict` | CI + pre-push | 输出过期白名单项 | Agent 新增豁免时登记 `expiry_check` | 清理过期白名单 | ✅ 已落地 |
| **硬编码密钥扫描** | `assert-release-hardcoded-secrets.py` | pre-commit + CI + pre-push | 输出疑似密钥 | Agent 不在代码中写密钥/Token | 移至 Keychain 或环境变量 | ✅ 已落地 |
| **Release 编译校验** | `assert-release-compile.py` | CI | 输出 Release 模式编译错误 | Agent 确保代码在 Release 模式下编译通过 | 修复 Release 编译错误 | ✅ 已落地 |
| **SBOM 生成** | `generate-arch-sbom-*.py` | CI | SBOM 生成失败 | Agent 修改依赖时确保 SBOM 可生成 | 修复 SBOM 生成 | ✅ 已落地 |

### 3.2 开发规范缺口

| 缺口 | 影响 | 优先级 | 落地方案 |
|------|------|--------|----------|
| `check-code-complexity.py` 阈值 10 与 `swift-coding-style.md` 阈值 15 不一致 | Agent 遵循规范但 CI 仍报错 | 高 | **落地步骤**：确认权威阈值。若以 `swift-coding-style.md` 为准，修改 `check-code-complexity.py` 第 25 行 `COMPLEXITY_THRESHOLD = 10` 改为 `15`；若以 CI 为准，修改 `swift-coding-style.md` 第 7 行改为 `10`。建议统一为 `15`（对齐 SwiftLint 默认值） |
| `audit-code-force-unwrap.py` 未集成至 `run-code-static-analysis.sh` | 强制解包仅在 `make audit` 检查，CI 静态分析阶段未检查 | 高 | **落地步骤**：在 `run-code-static-analysis.sh` 第 103 行后新增一行 `run_parallel_task "Force Unwrap Audit" "force_unwrap" "python3 Tools/ios/audit-code-force-unwrap.py" & pid42=$!`，并在末尾 `wait $pid42 || EXIT_CODE=1` |
| `audit-code-dead-code.py` 未集成至 `run-code-static-analysis.sh` | 死代码仅在 `make audit` 检查 | 中 | **落地步骤**：同上模式，在 `run-code-static-analysis.sh` 新增 `run_parallel_task` 行 |
| `audit-code-file-size.py` 未集成至 `run-code-static-analysis.sh` | 文件大小仅在 `make audit` 检查 | 中 | **落地步骤**：同上模式 |
| `check-code-mainactor-safety.py` 未集成至 `run-code-static-analysis.sh` | MainActor 安全仅在 `make audit` 检查 | 中 | **落地步骤**：同上模式 |
| `check-code-di-crash-risk.py` 未集成至 `run-code-static-analysis.sh` | DI 崩溃风险仅在 `make audit` 检查 | 中 | **落地步骤**：同上模式 |
| `check-code-storage-constants.py` 未集成至 `run-code-static-analysis.sh` | 存储常量仅在 `make audit` 检查 | 中 | **落地步骤**：同上模式 |
| `check-code-prompt-governance.py` 未集成至 `run-code-static-analysis.sh` | Prompt 治理仅在 `make audit` 检查 | 中 | **落地步骤**：同上模式 |
| `check-code-unsafe-string-index.py` 已集成但报错无修复示例 | Agent 不知道如何修复 | 中 | **落地步骤**：修改脚本报错消息，追加 `建议：使用 string.index(string.startIndex, offsetBy: n) 前先检查 string.count > n` |
| `check-code-absolute-paths.py` 报错无规范引用 | Agent 不知道规范在哪 | 低 | **落地步骤**：报错消息追加 `@Docs/Guides/development-standards.md` |

### 3.3 Agent 事前遵循：开发规范上下文注入

```
必读上下文（Agent 写 Swift 代码前加载）：
  1. AGENTS.md → 「四大强制质量红线」→ 获取 L10n/DesignSystem/分层/去魔鬼化红线
  2. swift-coding-style.md → 获取命名/注释/复杂度/类型后缀/Protocol 命名
  3. development-standards.md → 获取 DI/L10n/去魔鬼化/DesignSystem 速查
  4. file-header-template.md → 获取文件头模板

Agent 决策树（写 Swift 代码时）：
  写 UI 文本 → L10n.模块.属性，不硬编码中文，不直接 .tr()
  写 UI 尺寸 → DesignSystem Token，不硬编码数字
  写业务阈值 → FeatureConstants/DomainConstants，不内联数字
  写依赖注入 → @Dependency(\.xxx)，不用 @Inject，不用 ServiceContainer.shared.resolve
  写错误处理 → guard let / if let / as?，不用 ! / as!
  写存储 key → AppConstants.Keys.Storage.*，不硬编码字符串
  写 URL → AppConstants.URLs.*，不硬编码字符串
  写单例 → @Dependency 注入，不新增 static let shared
  写文件头 → 按 file-header-template.md 添加「系统层级」+「核心职责」
  函数超 100 行 → 按 SRP 拆分
  圈复杂度超 15 → 拆分分支逻辑
```

---

## 4. API 规范治理矩阵

> **规范文档**：`EXTERNAL_API_SPECIFICATION.md`
> **现状**：❌ **完全无 CI 落地** — 这是 5 大规范领域中最大的缺口。

### 4.1 规范条款 × CI 检查 × Agent 指引

| 规范条款 | CI 检查脚本 | 触发阶段 | 失败提示 | Agent 事前遵循指引 | Agent 事后修复指引 | 状态 |
|----------|------------|----------|----------|-------------------|-------------------|------|
| **HTTP 状态码去魔鬼化（200→HTTPStatusCode.ok）** | ❌ 无 | — | — | Agent 写网络层时，用 `HTTPStatusCode.ok` 等枚举 | 将 `200` 改为 `HTTPStatusCode.ok.rawValue` | ❌ **缺口** |
| **业务错误码去魔鬼化（40101→AppError.Auth.tokenInvalid）** | ❌ 无 | — | — | Agent 写错误处理时，用 `AppError.xxx()` | 将裸数字错误码改为 `AppError` 工厂 | ❌ **缺口** |
| **统一响应格式（code/message/data/timestamp）** | ❌ 无 | — | — | Agent 写 API 响应模型时，遵循 `APIResponse<T>` 泛型 | 统一为 `APIResponse<T>` | ❌ **缺口** |
| **Bearer Token 鉴权** | ❌ 无 | — | — | Agent 写 API 请求时，Header 加 `Authorization: Bearer <token>` | 补充鉴权 Header | ❌ **缺口** |
| **Content-Type 规范** | ❌ 无 | — | — | Agent 写请求时，JSON 用 `application/json`，上传用 `multipart/form-data` | 修正 Content-Type | ❌ **缺口** |
| **API 路径规范（/api/v1/xxx）** | ❌ 无 | — | — | Agent 写 API 路径时，遵循 `/api/v1/<resource>` | 修正路径格式 | ❌ **缺口** |

### 4.2 API 规范缺口 — 落地方案

#### 缺口 1：HTTP 状态码去魔鬼化（优先级：高）

**问题**：`EXTERNAL_API_SPECIFICATION.md` 1.5 节定义了状态码映射，但网络层代码中硬编码 `200`、`401`、`429` 无任何 CI 检查。AGENTS.md 红线 4 要求「HTTP 状态码（`200`→`HTTPStatusCode.ok`）」但无脚本执行。

**落地步骤**：

1. **确认常量定义位置**：检查 `Sources/Core/Base/` 或 `Sources/Infrastructure/` 是否已有 `HTTPStatusCode` 枚举。若无，新建 `Sources/Core/Base/Constants/HTTPStatusCode.swift`：

```swift
/// HTTP 状态码强类型枚举
public enum HTTPStatusCode: Int {
    case ok = 200
    case badRequest = 400
    case unauthorized = 401
    case forbidden = 403
    case notFound = 404
    case tooManyRequests = 429
    case internalError = 500
}
```

2. **新建 CI 脚本** `Tools/ios/check-code-api-conventions.py`：

```python
# 核心检查逻辑：
# 1. 扫描 Sources/Infrastructure/ 和 Sources/Features/ 中的 .swift 文件
# 2. 检测 HTTP 状态码硬编码模式：statusCode == 200 / response.code == 401 等
# 3. 检测裸数字错误码：errorCode = 40101 等
# 4. 排除已使用 HTTPStatusCode.xxx / AppError.xxx 的行
# 5. 排除注释行和白名单文件
# 报错格式：
#   file:line: error: [API Convention] 硬编码 HTTP 状态码 200，
#   应使用 HTTPStatusCode.ok。@Docs/Design/EXTERNAL_API_SPECIFICATION.md#1.5
```

3. **集成至 CI**：在 `run-code-static-analysis.sh` 新增：
```bash
run_parallel_task "API Conventions" "api_conventions" "python3 Tools/ios/check-code-api-conventions.py" & pid43=$!
# 末尾追加
wait $pid43 || EXIT_CODE=1
```

4. **集成至 pre-push**：在 `assert-code-pre-push.sh` Phase 1 新增：
```bash
run_check "API 规范审计" \
    "python3 Tools/ios/check-code-api-conventions.py" \
    || exit 1
```

5. **登记豁免**：存量违规通过 `Config/exemptions/manual_whitelist.yml` 的 `business_magic_exempt` 分类登记，逐步清理。

#### 缺口 2：统一响应格式校验（优先级：中）

**问题**：`EXTERNAL_API_SPECIFICATION.md` 1.4 节定义了统一响应格式 `{code, message, data, timestamp}`，但无 CI 检查确保 API 响应模型遵循。

**落地步骤**：

1. 确认 `APIResponse<T>` 泛型是否已存在于 `Sources/Infrastructure/`。
2. 在 `check-code-api-conventions.py` 中增加检查：扫描 `*Response*.swift` 文件，验证是否继承/遵循 `APIResponse` 协议。
3. 报错格式：`file:line: error: [API Convention] 响应模型未遵循统一格式 APIResponse<T>。@Docs/Design/EXTERNAL_API_SPECIFICATION.md#1.4`

#### 缺口 3：鉴权 Header 检查（优先级：低）

**问题**：需要 Bearer Token 的接口可能遗漏鉴权 Header。

**落地步骤**：暂不自动化（误报率高），依赖 `check-security-owasp-masvs.py` 覆盖安全维度 + 人工评审。

### 4.3 Agent 事前遵循：API 规范上下文注入

```
必读上下文（Agent 写网络层/API 代码前加载）：
  1. EXTERNAL_API_SPECIFICATION.md → 第 1 节通用约定 → 获取状态码/鉴权/响应格式
  2. AGENTS.md → 红线 4 → 获取 HTTP 状态码去魔鬼化要求
  3. development-standards.md → AppError 工厂 → 获取错误处理规范

Agent 决策树（写 API 相关代码时）：
  写 HTTP 状态码判断 → HTTPStatusCode.ok / .unauthorized，不硬编码 200/401
  写业务错误码 → AppError.Auth.tokenInvalid，不硬编码 40101
  写 API 响应模型 → 遵循 APIResponse<T> 统一格式
  写 API 请求 → Header 加 Authorization: Bearer <token>
  写 Content-Type → JSON 用 application/json，上传用 multipart/form-data
  写 API 路径 → /api/v1/<resource>，遵循版本化路径
```

---

## 5. 测试规范治理矩阵

> **规范文档**：`TEST_CASE_STANDARDS.md`（新）、`UNIT_TEST_GUIDE.md`、`TEST_CASES.md`、`INTEGRATION_TEST_STRATEGY.md`、`SYSTEM_TEST_PLAN.md`、`TEST_DRIVEN_FINDINGS.md`

### 5.1 规范条款 × CI 检查 × Agent 指引

| 规范条款 | CI 检查脚本 | 触发阶段 | 失败提示 | Agent 事前遵循指引 | Agent 事后修复指引 | 状态 |
|----------|------------|----------|----------|-------------------|-------------------|------|
| **测试函数英文命名（禁止中文）** | `audit-test-naming-chinese.py` | CI (`make audit`) | 输出中文函数名 + ❌/✅ 示例对比 | Agent 写测试时，`test<单元>_<条件>_<预期>` 纯英文驼峰 | 重命名为英文驼峰 | ✅ 已落地 |
| **测试结构 6 项指标** | `audit-test-structure.py` | CI (`make audit`) | 输出不达标指标及阈值 | Agent 写测试时，遵循目录对齐/文件大小/SPM 覆盖率 | 调整测试目录/拆分超大文件/补充 SPM 测试 | ✅ 已落地 |
| **测试耦合反模式（生产代码无测试分支）** | `check-code-test-coupling.py --strict` | CI | 输出违规 + 业界做法 + 3 步修复建议 | Agent 写生产代码时，不在视图/服务层写 `if isUITesting` | 将 launch argument 解析移至 `@main` 入口 | ✅ 已落地 |
| **快照测试统一环境注入** | `check-code-snapshot-environment.py --strict` | CI + pre-push | 输出手动 `.environment()` 违规 | Agent 写快照测试时，用 `.snapshotEnvironment()` | 替换为 `.snapshotEnvironment()` | ✅ 已落地 |
| **DI 测试设置** | `check-arch-test-di-setup.py` | CI | 输出测试中 DI 配置问题 | Agent 写测试时，用独立 `ServiceContainer()` 或 `setupFullMockEnvironment` | 修正 DI 测试配置 | ✅ 已落地 |
| **测试反模式检测** | `audit-test-anti-patterns.py` | CI | 输出测试反模式 | Agent 写测试时，遵循 `UNIT_TEST_GUIDE.md` Anti-Patterns | 修复反模式 | ✅ 已落地 |
| **覆盖率门禁** | `assert-test-coverage.py` + `check_xccov_coverage.py` | CI | 输出覆盖率不达标 | Agent 写代码时同步写测试 | 补充测试用例 | ⚠️ 暂时 `--report-only` |
| **SPM 包覆盖率** | `coverage-spm.py` | 手动 (`make coverage-spm`) | 输出 SPM 包覆盖率 | Agent 写 SPM 包代码时同步写测试 | 补充 SPM 测试 | ⚠️ 手动触发 |
| **Flaky 测试报告** | `run-test-flaky-report.sh` | 手动 | 输出 Flaky 用例 | Agent 写测试时确保确定性 | 修复 Flaky 用例 | ⚠️ 手动触发 |
| **FIRST 原则** | ❌ 无 | — | — | Agent 写测试时遵循 FIRST 五原则 | 依赖人工评审 | ❌ **缺口** |
| **AAA 结构** | ❌ 无 | — | — | Agent 写测试时用 Given/When/Then 三段式 | 依赖人工评审 | ❌ **缺口** |
| **断言规范（禁止零断言）** | ❌ 无 | — | — | Agent 写测试时每个用例至少 1 个断言 | 依赖人工评审 | ❌ **缺口** |
| **Fixture 确定性（禁止 Date()）** | ❌ 无 | — | — | Agent 写测试时用固定时间戳，不用 `Date()` | 依赖人工评审 | ❌ **缺口** |
| **setUp/tearDown 全局 reset 禁止** | ❌ 无 | — | — | Agent 写测试时禁止 `tearDown` 调 `ServiceContainer.shared.reset()` | 依赖人工评审 | ❌ **缺口** |
| **边界值覆盖** | ❌ 无 | — | — | Agent 写测试时覆盖空/零/越界/极值 | 依赖人工评审 | ❌ **缺口** |

### 5.2 测试规范缺口 — 落地方案

#### 缺口 1：零断言检测（优先级：高）

**问题**：`TEST_CASE_STANDARDS.md` 第 8.3 节要求「每个用例至少 1 个断言」，但无 CI 检查。Agent 可能生成「只调用不断言」的绿色安慰剂测试。

**落地步骤**：

1. **新建 CI 脚本** `Tools/ios/audit-test-no-assertion.py`：

```python
# 核心检查逻辑：
# 1. 扫描 Tests/ 目录下所有 .swift 文件
# 2. 提取每个 func testXXX() 方法体
# 3. 检查方法体内是否包含 XCTAssert / XCTAssertEqual / XCTAssertNotNil /
#    XCTAssertThrowsError / assertSnapshot 等断言调用
# 4. 若无任何断言，报错
# 报错格式：
#   file:line: error: [Test Standard] 测试用例 'testXXX' 无断言，
#   每个用例必须至少 1 个断言。
#   @Docs/Testing/TEST_CASE_STANDARDS.md#8.3
# 修复建议：
#   添加 XCTAssert 断言验证预期结果，或删除此无效用例。
```

2. **集成至 CI**：在 `run-code-static-analysis.sh` 新增 `run_parallel_task`。
3. **集成至 `make audit`**：在 Makefile `audit` target 新增脚本调用。

#### 缺口 2：Fixture 确定性检测（优先级：高）

**问题**：`TEST_CASE_STANDARDS.md` 第 9.1 节要求「禁止 `Date()` 作为预期值」（对齐 `TEST_DRIVEN_FINDINGS.md` #60），但无 CI 检查。

**落地步骤**：

1. **新建 CI 脚本** `Tools/ios/audit-test-determinism.py`：

```python
# 核心检查逻辑：
# 1. 扫描 Tests/ 目录下所有 .swift 文件
# 2. 检测测试方法体内的非确定性模式：
#    - Date() 作为预期值或断言参数
#    - UUID().uuidString 作为预期值
#    - TimeZone.current 作为预期值
#    - ProcessInfo.processInfo.hostName 作为预期值
# 3. 排除注释行和白名单（如性能测试允许 Date() 计时）
# 报错格式：
#   file:line: error: [Test Standard] 测试用例中使用非确定性 Date()，
#   请用固定时间戳 Date(timeIntervalSince1970:)。
#   @Docs/Testing/TEST_CASE_STANDARDS.md#9.1
#   @Docs/Testing/TEST_DRIVEN_FINDINGS.md#60
```

2. **集成至 CI** 和 `make audit`。

#### 缺口 3：tearDown 全局 reset 检测（优先级：高）

**问题**：`TEST_CASE_STANDARDS.md` 第 10.2 节要求「禁止 `tearDown` 调 `ServiceContainer.shared.reset()`」（对齐 `TEST_DRIVEN_FINDINGS.md` #42/#61），但无 CI 检查。

**落地步骤**：

1. **新建 CI 脚本** `Tools/ios/audit-test-teardown-reset.py`：

```python
# 核心检查逻辑：
# 1. 扫描 Tests/ 目录下所有 .swift 文件
# 2. 检测 tearDown 方法体内的违规调用：
#    - ServiceContainer.shared.reset()
#    - DatabaseManager.shared.reset()
#    - UserDefaults.standard.removePersistentDomain
# 3. 报错并引用台账编号
# 报错格式：
#   file:line: error: [Test Standard] tearDown 中调用全局 reset()，
#   会导致后续用例依赖链破坏。请用 setupFullMockEnvironment 幂等覆盖。
#   @Docs/Testing/TEST_CASE_STANDARDS.md#10.2
#   @Docs/Testing/TEST_DRIVEN_FINDINGS.md#42
```

2. **集成至 CI** 和 `make audit`。

#### 缺口 4：AAA 结构检测（优先级：中）

**问题**：`TEST_CASE_STANDARDS.md` 第 7 节要求 AAA 结构，但无 CI 检查。

**落地步骤**：

1. **新建 CI 脚本** `Tools/ios/audit-test-aaa-structure.py`：

```python
# 核心检查逻辑：
# 1. 扫描 Tests/ 目录下所有 .swift 文件
# 2. 提取每个 func testXXX() 方法体
# 3. 检查是否包含 // Given / // When / // Then 注释标记
#    （或 // Arrange / // Act / // Assert）
# 4. 若缺失任一段，输出 WARNING（非阻断，逐步推进）
# 报错格式：
#   file:line: warning: [Test Standard] 测试用例 'testXXX' 缺少 AAA 结构注释，
#   请用 // Given / // When / // Then 标注三段。
#   @Docs/Testing/TEST_CASE_STANDARDS.md#7
```

2. **集成至 CI**（初期 WARNING，后续视情况升级为 error）。

#### 缺口 5：测试函数命名格式检测（优先级：中）

**问题**：`audit-test-naming-chinese.py` 仅检测中文命名，但不检测三段式格式（`test<单元>_<条件>_<预期>`）。Agent 可能写出 `testCreatePage`（缺条件与预期）。

**落地步骤**：

1. **扩展 `audit-test-naming-chinese.py`** 或新建 `Tools/ios/audit-test-naming-format.py`：

```python
# 核心检查逻辑：
# 1. 提取测试函数名
# 2. 检查是否包含至少 1 个下划线分隔（三段式）
# 3. 检查是否包含 Should/ShouldThrow/ShouldNot 等预期关键词
# 4. 若不符合，输出 WARNING
# 报错格式：
#   file:line: warning: [Test Standard] 测试函数 'testCreatePage' 不符合三段式命名，
#   建议格式: test<单元>_<条件>_<预期>，如 testCreatePage_WithValidTitle_ShouldReturnNewPage。
#   @Docs/Testing/TEST_CASE_STANDARDS.md#6.1
```

### 5.3 Agent 事前遵循：测试规范上下文注入

```
必读上下文（Agent 写测试代码前加载）：
  1. TEST_CASE_STANDARDS.md → 全文 → 获取设计方法论与编写准则
  2. UNIT_TEST_GUIDE.md → 第 2-8 节 → 获取 Mock 注入/目录/覆盖率/Anti-Patterns
  3. TEST_DRIVEN_FINDINGS.md → 高频错误模式清单 → 获取错误猜测输入
  4. AGENTS.md → 四大红线 → 获取测试代码同等质量要求

Agent 决策树（写测试代码时）：
  命名 → test<单元>_<条件>_<预期>，纯英文驼峰，含 Should/ShouldThrow
  结构 → // Given / // When / // Then 三段式注释
  断言 → 每用例至少 1 个断言，带失败消息，优先强断言
  数据 → 固定时间戳/UUID，不用 Date()/UUID() 作为预期值
  替身 → 单元用 Stub/Spy，集成可用 Fake，Mock 标记 Sendable
  生命周期 → setUp 重建实例，tearDown 置 nil，禁止全局 reset()
  边界 → 覆盖空/零/越界/极值，对照 TEST_DRIVEN_FINDINGS 高频错误清单
  快照 → .snapshotEnvironment() 统一注入，不手动 .environment()
  目录 → Tests/Unit/<架构层或功能域>/，与 Sources/ 对齐
  DI → 独立 ServiceContainer() 或 setupFullMockEnvironment，不污染 .shared
```

---

## 6. 事前遵循增强：pre-commit 门禁强化

> **现状**：`pre-commit` 仅做 1 项密钥扫描，Agent 提交时无规范反馈。
> **目标**：增加轻量规范检查（< 5 秒），让 Agent 在提交阶段即获反馈，缩短修复链。

### 6.1 pre-commit 增强方案

**落地步骤**：修改 `Tools/Hooks/pre-commit`，在密钥扫描后增加 3 项轻量检查：

```bash
#!/bin/bash
echo "🔒 [Git Hook] 启动 Git Pre-commit 静态扫描..."

# 1. 硬编码密钥扫描（安全红线）
python3 Tools/ios/assert-release-hardcoded-secrets.py || { echo "❌ 硬编码密钥扫描失败"; exit 1; }

# 2. 变更文件列表
CHANGED_SWIFT=$(git diff --name-only --cached | grep '\.swift$' || true)

if [ -n "$CHANGED_SWIFT" ]; then
    # 3. 本地化合规（仅扫变更文件，< 2 秒）
    python3 Tools/ios/check-code-localization.py --files $CHANGED_SWIFT 2>/dev/null || {
        echo "❌ 本地化合规失败，请用 L10n.模块.属性 替代硬编码文本"
        exit 1
    }

    # 4. 强制解包检测（仅扫变更文件，< 1 秒）
    python3 Tools/ios/audit-code-force-unwrap.py --files $CHANGED_SWIFT 2>/dev/null || {
        echo "❌ 检测到强制解包 (!) 或强制转换 (as!)，请用 guard let / as? 替代"
        exit 1
    }

    # 5. SwiftLint 变更文件（< 2 秒）
    swiftlint lint --strict $CHANGED_SWIFT 2>/dev/null || {
        echo "❌ SwiftLint 检查失败"
        exit 1
    }
fi

echo "✅ [Git Hook] 静态校验全部通过，准予提交！"
exit 0
```

**前提条件**：`check-code-localization.py` 和 `audit-code-force-unwrap.py` 需增加 `--files` 参数支持，仅扫描指定文件而非全量扫描。

### 6.2 pre-commit 检查项清单

| 检查项 | 脚本 | 耗时 | 阻断 | 说明 |
|--------|------|------|------|------|
| 硬编码密钥 | `assert-release-hardcoded-secrets.py` | < 1s | ✅ | 已有 |
| 本地化合规 | `check-code-localization.py --files` | < 2s | ✅ | 新增 |
| 强制解包 | `audit-code-force-unwrap.py --files` | < 1s | ✅ | 新增 |
| SwiftLint | `swiftlint lint --strict` | < 2s | ✅ | 新增 |
| **总计** | — | **< 6s** | — | — |

---

## 7. 事后检查增强：CI 报错统一格式规范

> **现状**：CI 脚本报错格式参差不齐，部分有修复建议，部分仅输出 `file:line: error: ...`。
> **目标**：统一报错格式，让 Agent 能自动解析并修复。

### 7.1 统一报错格式

所有 CI 检查脚本的报错必须遵循以下格式：

```
{file}:{line}: {severity}: [{CheckName}] {问题描述}
  📋 规范: @Docs/{path}#{section}
  🔧 建议: {具体修复建议}
  ✅ 示例: {正确代码示例}
```

**示例**：

```
Sources/Domain/Models/KnowledgePage.swift:15: error: [Domain Purity] 违规导入平台相关依赖包 'UIKit'。L1.5 领域层必须保持绝对的平台无关性。
  📋 规范: @Docs/Architecture/LAYERING_L0_L3.md#红线1
  🔧 建议: 删除 import UIKit，如需平台能力则定义协议在 Domain/Protocols/，实现在 Platforms/
  ✅ 示例: import Foundation  // ✅ 领域层仅允许 Foundation
```

### 7.2 报错格式落地步骤

**方案**：新建 `Tools/CI/gatekeeper_reporter.py` 统一报错格式化工具，各脚本调用它输出报错。

```python
# gatekeeper_reporter.py 核心接口
class GatekeeperReporter:
    @staticmethod
    def report(file, line, severity, check_name, message, doc_ref, fix_suggestion, example):
        """输出统一格式的报错信息"""
        print(f"{file}:{line}: {severity}: [{check_name}] {message}")
        print(f"  📋 规范: @{doc_ref}")
        print(f"  🔧 建议: {fix_suggestion}")
        print(f"  ✅ 示例: {example}")
```

**分批改造**：按优先级分批改造现有脚本，优先改造 Agent 高频遇到的检查：

| 批次 | 脚本 | 优先级 | 改造内容 |
|------|------|--------|----------|
| 第 1 批 | `audit-arch-domain-purity.py` | 高 | 追加 `@Docs` 引用 + 修复示例 |
| 第 1 批 | `audit-code-force-unwrap.py` | 高 | 追加 `@Docs` 引用 + 具体修复示例 |
| 第 1 批 | `audit-design-token-magic-numbers.py` | 高 | 追加 Token 映射建议表 |
| 第 1 批 | `check-code-localization.py` | 高 | 追加 `@Docs` 引用 + L10n 注册示例 |
| 第 2 批 | `audit-arch-dependency.py` | 中 | 追加 `@Docs` 引用 + DI 注入示例 |
| 第 2 批 | `audit-code-magic-strings.py` | 中 | 追加 `@Docs` 引用 + 常量定义示例 |
| 第 2 批 | `audit-code-business-magic-numbers.py` | 中 | 追加 `@Docs` 引用 + 常量抽取示例 |
| 第 3 批 | 其余脚本 | 低 | 逐步追加 `@Docs` 引用 |

### 7.3 Agent 报错自愈流程

```
Agent 收到 CI 报错 →
  解析报错格式：
    1. 提取 file:line → 定位违规代码
    2. 提取 [CheckName] → 识别检查类型
    3. 提取 📋 规范 → 读取规范文档对应章节
    4. 提取 🔧 建议 → 获取修复方向
    5. 提取 ✅ 示例 → 获取正确代码模板
  →
  Agent 执行修复：
    1. 读取违规文件 file:line
    2. 按修复建议 + 示例生成修复代码
    3. 写入修复
    4. 重新提交
```

---

## 8. 事前遵循：Agent 开发全流程规范内化机制

> **核心理念**：规范不能只靠 git hook 事后拦截，必须嵌入 Agent 的**设计→编码→测试**全流程，让 Agent 生成即合规。
> **设计原则**：将规范从「人读的条文」转化为「Agent 可执行的决策树 + 代码模板 + 上下文加载指令」。

### 8.1 现状问题分析

| 问题 | 根因 | 影响 |
|------|------|------|
| AGENTS.md 是规范条文堆叠 | 缺少可执行决策树 | Agent 读完红线后仍需自行推理如何遵守 |
| 规范文档分散在 20+ 文件 | Agent 不知道何时该读哪个 | Agent 遗漏规范，生成违规代码 |
| 无代码模板 | Agent 从零生成，风格不统一 | 文件头/MARK/结构不符合规范 |
| 规范与 CI 脚本无双向引用 | Agent 不知道哪条规则会被自动检查 | Agent 优先级判断失误 |
| 无场景化加载指令 | Agent 不会按场景主动加载规范 | 写 Domain 代码时不读分层规范，写 UI 时不读 DesignSystem |

### 8.2 事前遵循五层机制设计

```
┌─────────────────────────────────────────────────────────────┐
│              Agent 事前遵循五层机制                           │
│                                                             │
│  Layer 1: AGENTS.md 规范入口（Agent 必读上下文）              │
│           → 四大红线 + 决策树 + 场景化加载指令                 │
│                                                             │
│  Layer 2: 场景化规范上下文（Agent 按场景加载）                 │
│           → 架构/界面/开发/API/测试 各场景的决策树              │
│                                                             │
│  Layer 3: 代码模板（Agent 生成代码的起点）                    │
│           → 文件头/View/Service/Store/Test 模板               │
│                                                             │
│  Layer 4: 规范-CI 映射表（Agent 知道什么会被检查）             │
│           → 每条规范标注对应 CI 脚本名                         │
│                                                             │
│  Layer 5: 工作流嵌入（Agent 在设计/编码/测试各环节检查）       │
│           → brainstorming → spec → plan → implement → test   │
└─────────────────────────────────────────────────────────────┘
```

### 8.3 Layer 1：AGENTS.md 规范入口增强

**现状**：AGENTS.md 已有四大红线，但缺少「Agent 如何执行」的可操作指令。

**落地方案**：在 AGENTS.md 四大红线后追加「Agent 执行决策树」章节：

```markdown
## Agent 编码执行决策树 (Agent Coding Decision Tree)

> 所有 Agent 在编写 Swift 代码时，必须在生成每行代码前对照以下决策树。

### 架构决策树（写 import 时）
- 当前文件在 Sources/Domain/ → 仅 `import Foundation`，禁止 UIKit/SwiftUI
- 当前文件在 Sources/Features/ → 禁止 import Infrastructure/*，用 @Dependency
- 当前文件在 Packages/UFPCore/ → 禁止 import 任何上层模块
- 需要 #if os() → 仅在 ModuleRegistrar.swift 或 Platforms/ 中

### 界面决策树（写 SwiftUI 修饰符时）
- .padding(N) → 改为 .padding(DesignSystem.<语义>Padding)
- .font(.system(size: N)) → 改为 DesignSystem.<语义>Font
- .cornerRadius(N) → 改为 DesignSystem.<语义>CornerRadius
- .foregroundColor(.red/.blue) → 改为 Color.theme.<语义>
- 写快照测试 → 用 .snapshotEnvironment()

### 开发决策树（写 Swift 代码时）
- 写 UI 文本 → L10n.模块.属性，不硬编码中文，不直接 .tr()
- 写业务阈值 → FeatureConstants/DomainConstants，不内联数字
- 写依赖注入 → @Dependency(\.xxx)，不用 @Inject
- 写错误处理 → guard let / if let / as?，不用 ! / as!
- 写存储 key → AppConstants.Keys.Storage.*，不硬编码字符串
- 写单例 → @Dependency 注入，不新增 static let shared

### API 决策树（写网络层代码时）
- 写 HTTP 状态码 → HTTPStatusCode.ok / .unauthorized，不硬编码 200/401
- 写业务错误码 → AppError.Auth.tokenInvalid，不硬编码 40101
- 写 API 响应 → 遵循 APIResponse<T> 统一格式
- 写 API 请求 → Header 加 Authorization: Bearer <token>

### 测试决策树（写测试代码时）
- 命名 → test<单元>_<条件>_<预期>，纯英文驼峰
- 结构 → // Given / // When / // Then 三段式
- 断言 → 每用例至少 1 个断言，带失败消息
- 数据 → 固定时间戳，不用 Date() 作为预期值
- 生命周期 → setUp 重建实例，tearDown 禁止全局 reset()
```

**落地步骤**：在 `AGENTS.md` 第 99 行（四大红线末尾）后追加上述章节。

### 8.4 Layer 2：场景化规范上下文加载指令

**问题**：Agent 不会主动按场景加载规范文档。

**落地方案**：在 AGENTS.md 追加「场景化规范加载指令」，Agent 根据当前任务类型自动加载对应规范：

```markdown
## Agent 场景化规范加载指令 (Context Loading by Scenario)

> Agent 在开始任务前，根据任务类型用 read 工具加载对应规范文档。

| 任务类型 | 必读规范文档 | 优先级 |
|----------|-------------|--------|
| 设计新功能/架构 | AGENTS.md + LAYERING_L0_L3.md + ARCHITECTURE_4PLUS1.md | 必读 |
| 写 SwiftUI 视图 | AGENTS.md + UI_COMPONENTS.md + development-standards.md | 必读 |
| 写 Swift 业务逻辑 | AGENTS.md + swift-coding-style.md + implementation-patterns.md | 必读 |
| 写网络/API 代码 | AGENTS.md + EXTERNAL_API_SPECIFICATION.md | 必读 |
| 写测试代码 | AGENTS.md + TEST_CASE_STANDARDS.md + UNIT_TEST_GUIDE.md | 必读 |
| 写插件 | AGENTS.md + PLUGIN_SDK.md | 必读 |
| 重构代码 | AGENTS.md + srp-file-organization.md + swift-coding-style.md | 必读 |
| 修改 CI/脚本 | AGENTS.md + CI_CD_WORKFLOW.md | 必读 |
| 修改数据库 | AGENTS.md + DATABASE_SCHEMA.md | 必读 |
```

**落地步骤**：在 AGENTS.md 场景化加载指令章节追加此表。

### 8.5 Layer 3：代码模板（Agent 生成代码的起点）

**问题**：Agent 从零生成代码，文件头/MARK/结构不符合规范，导致 CI 报错返工。

**落地方案**：创建 `Docs/Guides/code-templates.md`，提供各类型文件的代码模板，Agent 生成代码时以此为起点。

**落地步骤**：新建 `Docs/Guides/code-templates.md`，包含以下模板（详见第 9 节）。

### 8.6 Layer 4：规范-CI 映射表

**问题**：Agent 不知道哪条规范会被 CI 自动检查，无法判断优先级。

**落地方案**：在 AGENTS.md 四大红线中，每条红线标注对应 CI 脚本名：

```markdown
1. L10n 强约束 → CI 检查: check-code-localization.py（编译期阻断 + CI + pre-push）
2. DesignSystem Token → CI 检查: audit-design-token-magic-numbers.py（CI + pre-push）
3. 架构分层 → CI 检查: audit-arch-domain-purity.py + audit-arch-dependency.py（CI + pre-push）
4. 去魔鬼化 → CI 检查: audit-code-business-magic-numbers.py + audit-code-magic-strings.py（CI + pre-push）
```

**落地步骤**：修改 AGENTS.md 第 77-99 行，每条红线末尾追加 `→ CI 检查: <脚本名>`。

### 8.7 Layer 5：工作流嵌入

**问题**：Agent 在 brainstorming/spec/plan/implement/test 各环节都可能遗漏规范。

**落地方案**：在 AGENTS.md 追加「Agent 工作流规范检查点」，每个环节标注必检项：

```markdown
## Agent 工作流规范检查点 (Workflow Checkpoints)

### 设计阶段 (brainstorming/spec)
- [ ] 架构分层是否遵循 L0-L3 单向依赖？
- [ ] 是否需要跨层协议？协议定义在哪个层级？
- [ ] 是否涉及平台差异？是否需要协议抽象？
- [ ] 开源选型：是否有成熟开源库可用？

### 编码阶段 (implement)
- [ ] 文件头：系统层级 + 核心职责标注？
- [ ] import：是否遵循架构决策树？
- [ ] UI 文本：是否用 L10n.模块.属性？
- [ ] UI 尺寸：是否用 DesignSystem Token？
- [ ] 业务阈值：是否抽取为常量？
- [ ] 依赖注入：是否用 @Dependency？
- [ ] 错误处理：是否用 guard let / as?？
- [ ] 并发：是否标注 @MainActor / Sendable？

### 测试阶段 (test)
- [ ] 命名：test<单元>_<条件>_<预期> 英文驼峰？
- [ ] 结构：// Given / // When / // Then？
- [ ] 断言：每用例至少 1 个断言？
- [ ] 数据：固定时间戳，无 Date()？
- [ ] 替身：Stub/Spy/Fake 正确使用？
- [ ] 生命周期：setUp 重建，tearDown 无全局 reset？
- [ ] 边界：空/零/越界/极值覆盖？

### 提交前自检 (pre-submit)
- [ ] make audit 通过？
- [ ] make ios 编译通过？
- [ ] make test-unit 通过？
```

**落地步骤**：在 AGENTS.md 末尾追加此章节。

---

## 8.8 渐进式披露机制（Progressive Disclosure）

> **核心约束**：31 个规范文档共 8691 行，Agent 上下文窗口有限，**严禁一次性全量加载**。
> **设计目标**：按需加载、分层摘要、精准引用，让 Agent 在有限上下文内获取「刚好够用」的规范信息。

### 8.8.1 问题量化

| 维度 | 数据 | 影响 |
|------|------|------|
| 规范文档总数 | 31 个 | 一次性加载严重稀释注意力 |
| 规范总行数 | 8691 行 | 超出多数模型有效注意力范围 |
| 最大单文件 | `TEST_CASE_STANDARDS.md` 817 行 | 单文件加载即占用大量上下文 |
| AGENTS.md（Agent 必读） | 324 行 | 已占用基线上下文 |
| Agent 实际需要的规范 | 当前任务的 2-3 个文档 | 90% 的加载内容与当前任务无关 |

### 8.8.2 三层渐进式披露架构

```
┌──────────────────────────────────────────────────────────┐
│              渐进式披露三层架构                            │
│                                                          │
│  Layer 0: 常驻上下文（始终在 Agent 上下文中）              │
│           AGENTS.md（324 行）                             │
│           → 四大红线 + 决策树 + 场景加载表 + 检查清单      │
│           → Agent 任何时候都能看到                        │
│                                                          │
│  Layer 1: 按需摘要（Agent 按场景加载摘要）                 │
│           Docs/Architecture/STANDARDS_GOVERNANCE_MATRIX.md│
│           → 本文档的治理矩阵表格（第 1-5 节）              │
│           → Agent 快速扫描「哪条规范有 CI 检查」           │
│           → 约 200 行表格，非全文                         │
│                                                          │
│  Layer 2: 精准全文（Agent 仅在需要时加载特定章节）         │
│           具体规范文档的特定章节                           │
│           → Agent 遇到具体问题时用 read offset/limit 加载  │
│           → 例如：写 Domain 代码 → read LAYERING_L0_L3.md │
│             的第 2 节「跨层依赖禁用矩阵」（20 行）         │
└──────────────────────────────────────────────────────────┘
```

### 8.8.3 Layer 0：常驻上下文设计（AGENTS.md 精简增强）

**原则**：AGENTS.md 是 Agent 唯一常驻上下文，必须**自包含**核心决策规则，不依赖外部文档即可指导 80% 的日常编码。

**现状问题**：AGENTS.md 324 行，但四大红线是「条文」而非「可执行指令」，Agent 仍需读外部文档才知道怎么做。

**落地方案**：在 AGENTS.md 追加「Agent 编码速查卡」（约 80 行），将 5 大决策树压缩为**速查格式**：

```markdown
## Agent 编码速查卡 (Agent Coding Quick Reference)

> 本速查卡是四大红线的可执行摘要，Agent 生成每行代码前对照此卡。
> 详细规范按「场景化规范加载指令」按需读取。

### 速查决策表

| 我要写... | 必须做 | 禁止做 | CI 检查脚本 |
|-----------|--------|--------|------------|
| import 语句 | Domain 层仅 import Foundation | Domain 层 import UIKit/SwiftUI | audit-arch-domain-purity.py |
| UI 文本 | L10n.模块.属性 | 硬编码中文/英文、直接 .tr() | check-code-localization.py |
| UI 尺寸 | DesignSystem Token | .padding(12)、.font(.system(size: 16)) | audit-design-token-magic-numbers.py |
| 业务阈值 | FeatureConstants.* | 内联数字 3/5/15 | audit-code-business-magic-numbers.py |
| 依赖注入 | @Dependency(\.xxx) | @Inject、ServiceContainer.shared.resolve | audit-inject-deprecated.py |
| 错误处理 | guard let / as? | 强制解包 !、强制转换 as! | audit-code-force-unwrap.py |
| 存储键 | AppConstants.Keys.Storage.* | 硬编码 forKey: "xxx" | audit-code-magic-strings.py |
| HTTP 状态码 | HTTPStatusCode.ok | 硬编码 200/401 | (待新建) check-code-api-conventions.py |
| 单例 | @Dependency 注入 | 新增 static let shared | audit-singleton-frozen.py |
| 测试命名 | test<单元>_<条件>_<预期> | 中文函数名 | audit-test-naming-chinese.py |
| 测试断言 | 每用例 ≥ 1 个断言 | 零断言 | (待新建) audit-test-no-assertion.py |
| 测试数据 | 固定时间戳 | Date() 作为预期值 | (待新建) audit-test-determinism.py |
| tearDown | sut = nil | ServiceContainer.shared.reset() | (待新建) audit-test-teardown-reset.py |
| 快照测试 | .snapshotEnvironment() | 手动 .environment() | check-code-snapshot-environment.py |
| 文件头 | 系统层级 + 核心职责 | 无文件头 | check-code-file-headers.py |
```

**落地步骤**：在 AGENTS.md 四大红线后追加此速查卡（约 30 行表格）。

### 8.8.4 Layer 1：按需摘要设计（治理矩阵精准引用）

**原则**：Agent 不读治理矩阵全文（1151 行），仅按需引用特定章节的表格。

**落地方案**：在 AGENTS.md 速查卡中，每行标注「详细规范见 `STANDARDS_GOVERNANCE_MATRIX.md#<章节号>`」，Agent 遇到具体问题时用 `read offset/limit` 加载对应表格（约 20-30 行）。

**示例**：
- Agent 写 Domain 层代码遇到 import 问题 → `read STANDARDS_GOVERNANCE_MATRIX.md offset=45 limit=30`（第 1.1 节架构矩阵）
- Agent 写测试遇到命名问题 → `read STANDARDS_GOVERNANCE_MATRIX.md offset=500 limit=40`（第 5.1 节测试矩阵）

### 8.8.5 Layer 2：精准全文设计（规范文档章节级加载）

**原则**：Agent 仅在需要深入理解某条规范时，用 `read offset/limit` 加载规范文档的**特定章节**，而非全文。

**落地方案**：为每个规范文档建立「章节索引」，标注行号范围，Agent 按需精准加载：

| 规范文档 | 总行数 | 高频章节 | 行号范围 | 加载指令 |
|----------|--------|----------|----------|----------|
| `LAYERING_L0_L3.md` | 373 | 第 2 节 跨层依赖禁用矩阵 | ~22-41 | `read offset=22 limit=20` |
| `LAYERING_L0_L3.md` | 373 | 第 3 节 反向依赖红线 | ~44-59 | `read offset=44 limit=16` |
| `swift-coding-style.md` | 160 | 第 1 节 复杂度指标 | ~5-10 | `read offset=5 limit=6` |
| `swift-coding-style.md` | 160 | 第 2 节 注释规范 | ~12-19 | `read offset=12 limit=8` |
| `TEST_CASE_STANDARDS.md` | 817 | 第 3 节 FIRST 原则 | ~96-108 | `read offset=96 limit=13` |
| `TEST_CASE_STANDARDS.md` | 817 | 第 7 节 AAA 结构 | ~230-250 | `read offset=230 limit=21` |
| `TEST_CASE_STANDARDS.md` | 817 | 第 8 节 断言规范 | ~252-290 | `read offset=252 limit=39` |
| `EXTERNAL_API_SPECIFICATION.md` | 694 | 第 1.5 节 状态码 | ~37-48 | `read offset=37 limit=12` |
| `UI_COMPONENTS.md` | 92 | 第 1 节 DesignSystem | ~5-13 | `read offset=5 limit=9` |
| `file-header-template.md` | 143 | 标准模板 | ~11-22 | `read offset=11 limit=12` |

> **落地步骤**：在 AGENTS.md 场景化规范加载指令中，为每个场景标注「高频章节 + 行号范围」，Agent 按需精准加载。

### 8.8.6 渐进式披露工作流

```
Agent 接收任务
  │
  ├─ Step 1: 读取常驻上下文（Layer 0）
  │   → AGENTS.md 已在上下文中（324 行 + 速查卡 30 行 = 354 行）
  │   → 对照「速查决策表」判断当前任务涉及哪些规范
  │
  ├─ Step 2: 按需加载摘要（Layer 1）
  │   → 若速查卡不够用，read 治理矩阵对应章节表格（20-30 行）
  │   → 了解「哪条规范有 CI 检查、失败提示是什么、怎么修」
  │
  ├─ Step 3: 精准加载全文（Layer 2，仅在需要时）
  │   → 若摘要仍不够用，read 具体规范文档的特定章节（10-40 行）
  │   → 深入理解规范条款的完整定义
  │
  └─ Step 4: 生成代码
      → 基于速查卡 + 摘要 + 全文，生成合规代码
      → 上下文消耗：354 + 30 + 40 = ~424 行（而非 8691 行）
```

### 8.8.7 上下文预算管理

| 层级 | 内容 | 行数 | 占总规范比 | 加载时机 |
|------|------|------|-----------|----------|
| Layer 0 | AGENTS.md + 速查卡 | ~354 | 4% | 常驻 |
| Layer 1 | 治理矩阵章节表格 | ~30 | 0.3% | 按场景 |
| Layer 2 | 规范文档特定章节 | ~40 | 0.5% | 按需 |
| **单次任务总消耗** | — | **~424** | **4.9%** | — |
| 对比：全量加载 | 31 个文档 | 8691 | 100% | ❌ 禁止 |

> **关键指标**：渐进式披露将单次任务的规范上下文消耗从 8691 行降至 ~424 行，**减少 95%**，确保 Agent 注意力集中在代码生成而非规范阅读。

### 8.8.8 规范文档结构要求（支持渐进式披露）

为支持章节级精准加载，规范文档必须遵循以下结构要求：

| 要求 | 说明 | 落地 |
|------|------|------|
| **章节编号** | 每个章节必须有数字编号（如 `## 3. FIRST 原则`） | 已有，检查一致性 |
| **章节自包含** | 每个章节应尽可能自包含，不依赖其他章节上下文 | 评估现有文档，补充缺失上下文 |
| **表格优先** | 规则用表格而非段落，Agent 可快速扫描 | 新增规范用表格格式 |
| **行号稳定** | 规范文档修改时尽量不改变高频章节的行号范围 | 重大修改后更新章节索引 |
| **TOC 索引** | 每个规范文档顶部应有目录索引 | 评估是否需要补充 |

**落地步骤**：
1. 为 5 大规范领域的高频章节建立「章节索引表」（含行号范围），维护在 AGENTS.md 场景化加载指令中。
2. 规范文档修改后，更新章节索引表的行号范围。
3. 新增规范文档时，同步建立章节索引。

---

## 9. 代码模板库（Agent 生成代码的起点）

> **定位**：Agent 生成新文件时，以此为模板起点，预置合规结构，减少 CI 返工。
> **落地步骤**：新建 `Docs/Guides/code-templates.md`，内容如下。

### 9.1 SwiftUI View 模板

```swift
//
//  <FileName>.swift
//  ZhiYu
//
//  Created by <Author> on <Date>.
//  Copyright © <Year> WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：<一句话描述本视图的唯一职责>
//

import SwiftUI
import UFPDesignSystem

/// <视图用途简述>
struct <Name>View: View {

    // MARK: - Properties
    @Dependency(\.<service>) private var <service>: <Service>Protocol

    // MARK: - Body
    var body: some View {
        VStack(spacing: DesignSystem.standardSpacing) {
            // 视图内容
        }
        .padding(DesignSystem.standardPadding)
    }
}

// MARK: - Preview
#Preview {
    <Name>View()
        .snapshotEnvironment()
}
```

### 9.2 ViewModel 模板

```swift
//
//  <FileName>.swift
//  ZhiYu
//
//  Created by <Author> on <Date>.
//  Copyright © <Year> WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：<一句话描述本 ViewModel 的唯一职责>
//

import Observation

@MainActor
@Observable
final class <Name>ViewModel {

    // MARK: - Dependencies
    @ObservationIgnored
    @Dependency(\.<service>) private var <service>: <Service>Protocol

    // MARK: - State
    var <state>: <Type> = .initial

    // MARK: - Initialization
    init() {}

    // MARK: - Actions
    func <action>() async throws {
        // 业务逻辑
    }
}
```

### 9.3 Service 模板

```swift
//
//  <FileName>.swift
//  ZhiYu
//
//  Created by <Author> on <Date>.
//  Copyright © <Year> WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：<一句话描述本服务的唯一职责>
//

import Foundation

/// <服务用途简述>
public protocol <Name>ServiceProtocol: Sendable {
    func <method>(<params>) async throws -> <Result>
}

/// <服务用途简述>
public final class <Name>Service: <Name>ServiceProtocol, @unchecked Sendable {

    // MARK: - Dependencies
    @ObservationIgnored
    @Dependency(\.<repo>) private var <repo>: <Repo>Protocol

    // MARK: - Public Methods
    public func <method>(<params>) async throws -> <Result> {
        // 业务逻辑
    }
}
```

### 9.4 单元测试模板

```swift
//
//  <FileName>Tests.swift
//  ZhiYu
//
//  Created by <Author> on <Date>.
//  Copyright © <Year> WangChong. All rights reserved.
//
//  系统层级：[Test] 单元测试
//  核心职责：<被测类的名称>的单元测试
//

import XCTest
@testable import <Module>

final class <Name>Tests: XCTestCase {

    // MARK: - Properties
    var mock<Dependency>: Mock<Dependency>!
    var sut: <SystemUnderTest>!

    // MARK: - Setup
    override func setUp() async throws {
        try await super.setUp()
        mock<Dependency> = Mock<Dependency>()
        sut = <SystemUnderTest>(<dependency>: mock<Dependency>)
    }

    // MARK: - Teardown
    override func tearDown() async throws {
        sut = nil
        mock<Dependency> = nil
        try await super.tearDown()
    }

    // MARK: - Tests
    func test<Method>_<Condition>_Should<Expected>() async throws {
        // Given
        let input = "<fixture>"

        // When
        let result = try await sut.<method>(input)

        // Then
        XCTAssertEqual(result, <expected>, "预期 <描述>，实际: \(result)")
    }
}
```

### 9.5 文件头快速参考

| 文件类型 | 系统层级 | import 规则 |
|----------|----------|------------|
| SwiftUI View | `[L3]` 表现层 | `import SwiftUI` + `import UFPDesignSystem` |
| ViewModel | `[L2]` 业务功能层 | `import Observation`，禁止 `import SwiftUI` |
| Service | `[L1.5]` 领域层 | `import Foundation`，禁止 `import UIKit/SwiftUI` |
| Store/Repository | `[L1]` 基础设施层 | `import Foundation` + `import GRDB` |
| Domain Model | `[L1.5]` 领域层 | `import Foundation`，禁止 UI 框架 |
| 单元测试 | `[Test]` | `import XCTest` + `@testable import <Module>` |

---

## 10. 缺口汇总与优先级

### 10.1 全量缺口清单

| 编号 | 缺口 | 规范领域 | 优先级 | 落地工作量 | 类型 |
|------|------|----------|--------|-----------|------|
| G-01 | API 规范完全无 CI 检查 | API | **P0** | 新建 1 脚本 + 集成 CI | 事后检查 |
| G-02 | 测试零断言无 CI 检查 | 测试 | **P0** | 新建 1 脚本 + 集成 CI | 事后检查 |
| G-03 | 测试 Fixture 确定性无 CI 检查 | 测试 | **P0** | 新建 1 脚本 + 集成 CI | 事后检查 |
| G-04 | tearDown 全局 reset 无 CI 检查 | 测试 | **P0** | 新建 1 脚本 + 集成 CI | 事后检查 |
| G-05 | AGENTS.md 缺少 Agent 执行决策树 | 全局 | **P0** | 修改 AGENTS.md | 事前遵循 |
| G-06 | AGENTS.md 缺少场景化规范加载指令 | 全局 | **P0** | 修改 AGENTS.md | 事前遵循 |
| G-07 | 无代码模板库 | 全局 | **P0** | 新建 code-templates.md | 事前遵循 |
| G-08 | AGENTS.md 红线未标注对应 CI 脚本名 | 全局 | **P1** | 修改 AGENTS.md | 事前遵循 |
| G-09 | AGENTS.md 缺少工作流规范检查点 | 全局 | **P1** | 修改 AGENTS.md | 事前遵循 |
| G-10 | `audit-code-force-unwrap.py` 未集成至 CI | 开发 | **P1** | 修改 1 脚本 | 事后检查 |
| G-11 | 圈复杂度阈值不一致（CI=10 vs 规范=15） | 开发 | **P1** | 修改 1 脚本或 1 文档 | 事后检查 |
| G-12 | pre-commit 门禁极弱（仅 1 项） | 全局 | **P1** | 修改 1 脚本 | 事后检查 |
| G-13 | CI 报错格式不统一 | 全局 | **P1** | 新建格式化工具 + 分批改造 | 事后检查 |
| G-14 | 6 个已有脚本未集成至 CI 静态分析 | 开发 | **P2** | 修改 run-code-static-analysis.sh | 事后检查 |
| G-15 | 测试 AAA 结构无 CI 检查 | 测试 | **P2** | 新建 1 脚本 + 集成 CI | 事后检查 |
| G-16 | 测试命名格式（三段式）无 CI 检查 | 测试 | **P2** | 新建 1 脚本 + 集成 CI | 事后检查 |
| G-17 | `audit-design-token-magic-numbers.py` 报错无具体 Token 名 | 界面 | **P2** | 修改 1 脚本 | 事后检查 |
| G-18 | 覆盖率门禁暂时关闭 | 测试 | **P2** | 恢复硬阻断 | 事后检查 |
| G-19 | `VISUAL_SYSTEM.md` 部分条款无 CI 检查 | 界面 | **P3** | 评估现有脚本覆盖度 | 事后检查 |
| G-20 | `WATCHOS_DESIGN_GUIDELINES.md` 无专项 CI | 界面 | **P3** | 暂依赖快照测试 | 事后检查 |

### 10.2 缺口统计

| 类型 | 已落地 | 缺口数 | 落地率 |
|------|--------|--------|--------|
| 事前遵循（Agent 内化） | 1（AGENTS.md 红线） | 5 | 17% |
| 事后检查（CI 门禁） | 62 | 15 | 80% |
| **合计** | **63** | **20** | **76%** |

> **关键发现**：事后检查落地率 80%（较好），但事前遵循落地率仅 17%（极弱）。**改进重心应放在事前遵循**，让 Agent 生成即合规，减少返工。

---

## 11. 改进路线图

### Phase 1：事前遵循闭环（建议 1 周）

> **目标**：让 Agent 在设计→编码→测试全流程内化规范，生成即合规。

| 任务 | 产出 | 落地步骤 | 验收标准 |
|------|------|----------|----------|
| AGENTS.md 追加 Agent 执行决策树 | 5 大决策树（架构/界面/开发/API/测试） | 在 AGENTS.md 第 99 行后追加第 8.3 节内容 | Agent 读取 AGENTS.md 后能按决策树生成合规代码 |
| AGENTS.md 追加场景化规范加载指令 | 10 个场景的规范加载表 | 在 AGENTS.md 追加第 8.4 节内容 | Agent 按任务类型自动加载对应规范 |
| 新建 `Docs/Guides/code-templates.md` | 5 类代码模板 | 新建文件，内容见第 9 节 | Agent 生成新文件时以模板为起点 |
| AGENTS.md 红线标注 CI 脚本名 | 4 条红线标注对应脚本 | 修改 AGENTS.md 第 77-99 行 | Agent 知道哪条规则会被自动检查 |
| AGENTS.md 追加工作流规范检查点 | 4 阶段检查清单 | 在 AGENTS.md 末尾追加第 8.7 节内容 | Agent 在各环节自检 |

### Phase 2：P0 事后检查闭环（建议 1-2 周）

| 任务 | 产出 | 落地步骤 | 验收标准 |
|------|------|----------|----------|
| 新建 `check-code-api-conventions.py` | API 规范 CI 检查 | 新建脚本 + 集成 CI + 集成 make audit | CI 能检测 HTTP 状态码/错误码硬编码 |
| 新建 `audit-test-no-assertion.py` | 零断言检测 | 新建脚本 + 集成 CI + 集成 make audit | CI 能检测无断言测试用例 |
| 新建 `audit-test-determinism.py` | Fixture 确定性检测 | 新建脚本 + 集成 CI + 集成 make audit | CI 能检测 Date() 非确定性用法 |
| 新建 `audit-test-teardown-reset.py` | tearDown reset 检测 | 新建脚本 + 集成 CI + 集成 make audit | CI 能检测全局 reset 违规 |

### Phase 3：P1 事后检查闭环（建议 2-4 周）

| 任务 | 产出 | 落地步骤 | 验收标准 |
|------|------|----------|----------|
| 集成 `audit-code-force-unwrap.py` 至 CI | 强制解包 CI 检查 | 修改 run-code-static-analysis.sh | CI 静态分析阶段检测强制解包 |
| 统一圈复杂度阈值 | CI 与规范一致 | 修改 check-code-complexity.py 或 swift-coding-style.md | 阈值统一为 15 |
| 增强 pre-commit 门禁 | pre-commit 4 项检查 | 修改 Tools/Hooks/pre-commit | git commit 时执行 4 项轻量检查 |
| 新建 `gatekeeper_reporter.py` | 统一报错格式化工具 | 新建脚本 | 工具可被各脚本调用 |
| 改造第 1 批脚本报错格式 | 4 个脚本报错含规范引用+修复建议 | 修改 4 个脚本 | Agent 可解析报错并自愈 |

### Phase 4：P2-P3 闭环（长期）

| 任务 | 产出 | 落地步骤 | 验收标准 |
|------|------|----------|----------|
| 集成 6 个已有脚本至 CI | CI 静态分析覆盖完整 | 修改 run-code-static-analysis.sh | 所有 Tools/ios/ 脚本在 CI 执行 |
| 新建 AAA 结构/命名格式检测 | 2 个测试规范脚本 | 新建脚本 + 集成 CI | CI 能检测 AAA/命名格式问题 |
| 恢复覆盖率硬阻断 | 覆盖率门禁生效 | 修改 CI 配置 | 覆盖率不达标时阻断合并 |
| 改造第 2-3 批脚本报错格式 | 全部脚本报错统一 | 分批修改脚本 | 全部报错含规范引用+修复建议 |

---

## 12. Agent 驱动开发最佳实践

### 12.1 Agent 开发全流程

```
Agent 接收任务
  │
  ├─ ① 设计阶段
  │   → read AGENTS.md（四大红线 + 决策树）
  │   → read LAYERING_L0_L3.md（分层规则）
  │   → 对照「工作流规范检查点 - 设计阶段」自检
  │   → 输出设计方案
  │
  ├─ ② 编码阶段
  │   → read 对应场景规范（按场景化加载指令）
  │   → read code-templates.md（代码模板）
  │   → 以模板为起点生成代码
  │   → 对照「Agent 编码执行决策树」逐行检查
  │   → 对照「工作流规范检查点 - 编码阶段」自检
  │
  ├─ ③ 测试阶段
  │   → read TEST_CASE_STANDARDS.md（测试规范）
  │   → read UNIT_TEST_GUIDE.md（工程规范）
  │   → 以测试模板为起点生成测试
  │   → 对照「测试决策树」检查
  │   → 对照「工作流规范检查点 - 测试阶段」自检
  │
  ├─ ④ 提交前自检
  │   → make audit（架构+测试结构审计）
  │   → make ios（编译验证）
  │   → make test-unit（单元测试）
  │   → 对照「工作流规范检查点 - 提交前自检」
  │
  └─ ⑤ CI 失败自愈（如发生）
      → 解析 CI 报错（file:line + [CheckName] + 规范引用 + 修复建议）
      → read 对应规范文档
      → 生成修复代码
      → 重新提交
```

### 12.2 Agent 规范遵循自检清单

Agent 在提交 PR 前，对照以下清单自检：

- [ ] 架构：import 方向遵循 L0→L3 单向依赖？
- [ ] 架构：Domain 层无 UIKit/SwiftUI/#if os()？
- [ ] 界面：UI 尺寸/颜色用 DesignSystem Token？
- [ ] 开发：UI 文本用 L10n.模块.属性？
- [ ] 开发：无魔鬼数字/字符串？
- [ ] 开发：无强制解包/强制转换？
- [ ] 开发：新代码用 @Dependency 不用 @Inject？
- [ ] API：HTTP 状态码用 HTTPStatusCode 枚举？
- [ ] 测试：函数名三段式英文驼峰？
- [ ] 测试：AAA 结构 + 至少 1 个断言？
- [ ] 测试：无 Date() 非确定性数据？
- [ ] 测试：tearDown 无全局 reset()？
- [ ] 文件头：系统层级 + 核心职责标注？

---

## 13. 落地操作指南与 Demo 示例

> 本节给出 **Phase 1 事前遵循**的完整落地操作指南，包含具体修改步骤、修改内容、和端到端 Demo。

### 13.1 落地操作 Step 1：AGENTS.md 追加「Agent 编码速查卡」

**目标**：在 AGENTS.md 四大红线后追加速查卡，让 Agent 无需读外部文档即可指导 80% 日常编码。

**操作步骤**：

1. 打开 `AGENTS.md`
2. 在第 99 行（四大红线末尾「豁免统一走 ExemptionRegistry...」）之后、第 101 行（「## 项目概览」）之前，插入以下内容：

```markdown
## Agent 编码速查卡 (Agent Coding Quick Reference)

> 本速查卡是四大红线的可执行摘要，Agent 生成每行代码前对照此卡。
> 详细规范按「场景化规范加载指令」按需读取，严禁一次性全量加载 31 个规范文档（共 8691 行）。

### 速查决策表

| 我要写... | 必须做 | 禁止做 | CI 检查脚本 |
|-----------|--------|--------|------------|
| import 语句 | Domain 层仅 `import Foundation` | Domain 层 import UIKit/SwiftUI | `audit-arch-domain-purity.py` |
| UI 文本 | `L10n.模块.属性` | 硬编码中文/英文、直接 `.tr()` | `check-code-localization.py` |
| UI 尺寸 | `DesignSystem` Token | `.padding(12)`、`.font(.system(size: 16))` | `audit-design-token-magic-numbers.py` |
| 业务阈值 | `FeatureConstants.*` | 内联数字 3/5/15 | `audit-code-business-magic-numbers.py` |
| 依赖注入 | `@Dependency(\.xxx)` | `@Inject`、`ServiceContainer.shared.resolve` | `audit-inject-deprecated.py` |
| 错误处理 | `guard let` / `as?` | 强制解包 `!`、强制转换 `as!` | `audit-code-force-unwrap.py` |
| 存储键 | `AppConstants.Keys.Storage.*` | 硬编码 `forKey: "xxx"` | `audit-code-magic-strings.py` |
| HTTP 状态码 | `HTTPStatusCode.ok` | 硬编码 200/401 | *(待新建)* `check-code-api-conventions.py` |
| 单例 | `@Dependency` 注入 | 新增 `static let shared` | `audit-singleton-frozen.py` |
| 测试命名 | `test<单元>_<条件>_<预期>` | 中文函数名 | `audit-test-naming-chinese.py` |
| 测试断言 | 每用例 ≥ 1 个断言 | 零断言 | *(待新建)* `audit-test-no-assertion.py` |
| 测试数据 | 固定时间戳 | `Date()` 作为预期值 | *(待新建)* `audit-test-determinism.py` |
| tearDown | `sut = nil` | `ServiceContainer.shared.reset()` | *(待新建)* `audit-test-teardown-reset.py` |
| 快照测试 | `.snapshotEnvironment()` | 手动 `.environment()` | `check-code-snapshot-environment.py` |
| 文件头 | 系统层级 + 核心职责 | 无文件头 | `check-code-file-headers.py` |

### 场景化规范加载指令（渐进式披露）

> Agent 根据任务类型，用 `read` 工具加载对应规范文档的**特定章节**（非全文）。

| 任务类型 | 需加载的规范文档 | 加载指令（精准章节） |
|----------|-----------------|---------------------|
| 设计新功能/架构 | `LAYERING_L0_L3.md` 第 2 节 | `read Docs/Architecture/LAYERING_L0_L3.md offset=22 limit=20` |
| 写 SwiftUI 视图 | `UI_COMPONENTS.md` 第 1 节 | `read Docs/Design/UI_COMPONENTS.md offset=5 limit=9` |
| 写 Swift 业务逻辑 | `swift-coding-style.md` 第 1-2 节 | `read Docs/Guides/swift-coding-style.md offset=5 limit=15` |
| 写网络/API 代码 | `EXTERNAL_API_SPECIFICATION.md` 第 1.5 节 | `read Docs/Design/EXTERNAL_API_SPECIFICATION.md offset=37 limit=12` |
| 写测试代码 | `TEST_CASE_STANDARDS.md` 第 3/7/8 节 | `read Docs/Testing/TEST_CASE_STANDARDS.md offset=96 limit=200` |
| 写文件头 | `file-header-template.md` 标准模板 | `read Docs/Guides/file-header-template.md offset=11 limit=12` |
| 写代码模板 | `code-templates.md`（待新建） | `read Docs/Guides/code-templates.md` |

### Agent 工作流规范检查点

**设计阶段**：
- [ ] 架构分层是否遵循 L0-L3 单向依赖？
- [ ] 是否需要跨层协议？协议定义在哪个层级？
- [ ] 开源选型：是否有成熟开源库可用？

**编码阶段**：
- [ ] 文件头：系统层级 + 核心职责标注？
- [ ] import：是否遵循速查决策表？
- [ ] UI 文本/尺寸/业务阈值：是否遵循速查决策表？
- [ ] 依赖注入/错误处理：是否遵循速查决策表？

**测试阶段**：
- [ ] 命名/结构/断言/数据/生命周期：是否遵循速查决策表？
- [ ] 边界：空/零/越界/极值覆盖？

**提交前自检**：
- [ ] `make audit` 通过？
- [ ] `make ios` 编译通过？
- [ ] `make test-unit` 通过？
```

**验证**：修改后 AGENTS.md 应在四大红线后、项目概览前包含速查卡章节。

### 13.2 落地操作 Step 2：新建代码模板库

**目标**：创建 `Docs/Guides/code-templates.md`，Agent 生成新文件时以此为起点。

**操作步骤**：

1. 新建文件 `Docs/Guides/code-templates.md`
2. 内容见本文第 9 节（代码模板库），包含 5 类模板：
   - 9.1 SwiftUI View 模板
   - 9.2 ViewModel 模板
   - 9.3 Service 模板
   - 9.4 单元测试模板
   - 9.5 文件头快速参考表

**验证**：`ls Docs/Guides/code-templates.md` 存在，且包含 5 个模板章节。

### 13.3 落地操作 Step 3：AGENTS.md 文档索引登记

**目标**：在 AGENTS.md 文档索引中登记新建的 `code-templates.md`。

**操作步骤**：

1. 打开 `AGENTS.md`
2. 在文档索引表中（第 12 行 `file-header-template.md` 行之后）追加一行：

```markdown
| [code-templates.md](Docs/Guides/code-templates.md) | 🆕 代码模板库（View/ViewModel/Service/Test 模板，Agent 生成代码的起点） |
```

**验证**：AGENTS.md 文档索引包含 `code-templates.md` 条目。

### 13.4 端到端 Demo：Agent 开发一个新功能

**场景**：用户要求 Agent 开发一个「知识页面收藏」功能，需要写 Service + View + Test。

#### Demo Step 1：Agent 接收任务，读取常驻上下文

```
用户: 帮我开发一个知识页面收藏功能，用户可以收藏/取消收藏页面，并在收藏列表中查看。

Agent 内部流程:
  1. AGENTS.md 已在上下文中（常驻 Layer 0）
  2. Agent 扫描「速查决策表」，识别本次任务涉及的规范:
     - 写 Service → import 规范、依赖注入规范、错误处理规范
     - 写 View → UI 文本规范、UI 尺寸规范
     - 写 Test → 测试命名/结构/断言/数据规范
  3. Agent 扫描「场景化规范加载指令」，识别需加载的规范:
     - 写 SwiftUI 视图 → read UI_COMPONENTS.md 第 1 节（9 行）
     - 写 Swift 业务逻辑 → read swift-coding-style.md 第 1-2 节（15 行）
     - 写测试代码 → read TEST_CASE_STANDARDS.md 第 3/7/8 节（200 行）
  4. 上下文消耗: AGENTS.md(354) + 9 + 15 + 200 = ~578 行（而非 8691 行）
```

#### Demo Step 2：Agent 设计阶段

```
Agent 输出设计方案:
  ┌─ 收藏功能设计 ─────────────────────────────────┐
  │ 层级: L1.5 领域层（FavoriteService）            │
  │ 协议: FavoriteServiceProtocol（定义在 Domain）   │
  │ 实现: FavoriteService（定义在 Features）         │
  │ 存储: 通过 @Dependency(\.pageStore) 注入         │
  │ UI: FavoriteListView（L3）+ FavoriteListViewModel（L2）│
  │ 测试: FavoriteServiceTests + FavoriteListViewTests │
  └────────────────────────────────────────────────┘

  Agent 对照「工作流规范检查点 - 设计阶段」自检:
    ✅ 架构分层: Service 在 L1.5，View 在 L3，ViewModel 在 L2
    ✅ 跨层协议: FavoriteServiceProtocol 定义在 Domain/Protocols/
    ✅ 开源选型: 收藏功能简单，无需开源库
```

#### Demo Step 3：Agent 编码阶段 — 生成 Service

```
Agent 加载代码模板:
  → read Docs/Guides/code-templates.md（第 9.3 节 Service 模板）

Agent 生成 FavoriteServiceProtocol（Domain 层）:
```

```swift
//
//  FavoriteService.swift
//  ZhiYu
//
//  Created by CodeFree-O on 2026-10-09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：知识页面收藏/取消收藏的领域服务契约与状态管理。
//

import Foundation

/// 知识页面收藏服务契约
public protocol FavoriteServiceProtocol: Sendable {
    /// 收藏指定页面
    func favorite(pageID: UUID) async throws
    /// 取消收藏
    func unfavorite(pageID: UUID) async throws
    /// 查询收藏列表
    func fetchFavorites() async throws -> [UUID]
    /// 查询是否已收藏
    func isFavorited(pageID: UUID) async throws -> Bool
}
```

```
Agent 对照「速查决策表」逐行检查:
  ✅ import: 仅 import Foundation（Domain 层禁止 UIKit/SwiftUI）
  ✅ 文件头: 系统层级 [L1.5] + 核心职责
  ✅ 协议: Sendable（Swift 6 并发安全）
  ✅ 无魔鬼数字/字符串
  ✅ 无强制解包
```

#### Demo Step 4：Agent 编码阶段 — 生成 View

```
Agent 加载代码模板:
  → read Docs/Guides/code-templates.md（第 9.1 节 View 模板）

Agent 生成 FavoriteListView:
```

```swift
//
//  FavoriteListView.swift
//  ZhiYu
//
//  Created by CodeFree-O on 2026-10-09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：收藏页面列表视图，展示用户收藏的知识页面并支持取消收藏。
//

import SwiftUI
import UFPDesignSystem

struct FavoriteListView: View {

    // MARK: - Properties
    @State private var viewModel = FavoriteListViewModel()

    // MARK: - Body
    var body: some View {
        List(viewModel.favorites) { page in
            FavoriteRowView(page: page) {
                Task { await viewModel.unfavorite(page) }
            }
        }
        .navigationTitle(L10n.Favorite.listTitle)
        .padding(DesignSystem.standardPadding)
    }
}

// MARK: - Preview
#Preview {
    FavoriteListView()
        .snapshotEnvironment()
}
```

```
Agent 对照「速查决策表」逐行检查:
  ✅ import: import SwiftUI + import UFPDesignSystem（L3 允许）
  ✅ 文件头: 系统层级 [L3] + 核心职责
  ✅ UI 文本: L10n.Favorite.listTitle（非硬编码）
  ✅ UI 尺寸: DesignSystem.standardPadding（非硬编码 12）
  ✅ 快照测试: .snapshotEnvironment()（非手动 .environment()）
  ✅ 依赖注入: @State private var viewModel（ViewModel 内部用 @Dependency）
  ✅ 无魔鬼数字/字符串
  ✅ 无强制解包
```

#### Demo Step 5：Agent 测试阶段 — 生成单元测试

```
Agent 加载代码模板:
  → read Docs/Guides/code-templates.md（第 9.4 节 单元测试模板）

Agent 生成 FavoriteServiceTests:
```

```swift
//
//  FavoriteServiceTests.swift
//  ZhiYu
//
//  Created by CodeFree-O on 2026-10-09.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Test] 单元测试
//  核心职责：FavoriteService 的单元测试，验证收藏/取消收藏/查询逻辑。
//

import XCTest
@testable import ZhiYu

final class FavoriteServiceTests: XCTestCase {

    // MARK: - Properties
    var mockPageStore: MockPageStore!
    var sut: FavoriteService!

    // MARK: - Setup
    override func setUp() async throws {
        try await super.setUp()
        mockPageStore = MockPageStore()
        sut = FavoriteService(pageStore: mockPageStore)
    }

    // MARK: - Teardown
    override func tearDown() async throws {
        sut = nil
        mockPageStore = nil
        try await super.tearDown()
    }

    // MARK: - Tests
    func testFavorite_WithValidPageID_ShouldAddToFavorites() async throws {
        // Given
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

        // When
        try await sut.favorite(pageID: pageID)

        // Then
        let favorites = try await sut.fetchFavorites()
        XCTAssertTrue(favorites.contains(pageID), "收藏后应包含该页面 ID")
    }

    func testUnfavorite_WithExistingPageID_ShouldRemoveFromFavorites() async throws {
        // Given
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        try await sut.favorite(pageID: pageID)

        // When
        try await sut.unfavorite(pageID: pageID)

        // Then
        let favorites = try await sut.fetchFavorites()
        XCTAssertFalse(favorites.contains(pageID), "取消收藏后不应包含该页面 ID")
    }

    func testIsFavorited_WithFavoritedPage_ShouldReturnTrue() async throws {
        // Given
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        try await sut.favorite(pageID: pageID)

        // When
        let result = try await sut.isFavorited(pageID: pageID)

        // Then
        XCTAssertTrue(result, "已收藏页面应返回 true")
    }

    func testIsFavorited_WithUnfavoritedPage_ShouldReturnFalse() async throws {
        // Given
        let pageID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!

        // When
        let result = try await sut.isFavorited(pageID: pageID)

        // Then
        XCTAssertFalse(result, "未收藏页面应返回 false")
    }

    func testFetchFavorites_WhenEmpty_ShouldReturnEmptyArray() async throws {
        // Given — 无收藏

        // When
        let favorites = try await sut.fetchFavorites()

        // Then
        XCTAssertTrue(favorites.isEmpty, "无收藏时应返回空数组")
    }
}
```

```
Agent 对照「速查决策表」逐行检查:
  ✅ 命名: test<Method>_<Condition>_Should<Expected>（三段式英文驼峰）
  ✅ 结构: // Given / // When / // Then（AAA 三段式）
  ✅ 断言: 每用例 ≥ 1 个断言，带失败消息
  ✅ 数据: UUID(uuidString: "00000000-...")（固定 UUID，非 UUID()）
  ✅ 生命周期: setUp 重建实例，tearDown 置 nil（无全局 reset）
  ✅ 边界: testFetchFavorites_WhenEmpty 覆盖空集合
  ✅ 文件头: 系统层级 [Test] + 核心职责
  ✅ 无 Date() 非确定性数据
  ✅ 无强制解包（UUID(uuidString:)! 在 Given 段是安全 fixture，非可选解包）
```

#### Demo Step 6：Agent 提交前自检

```
Agent 执行提交前自检:
  $ make audit
  ✅ Architecture Dependency — 通过
  ✅ Domain Purity — 通过
  ✅ Test Naming — 通过
  ✅ Test Structure — 通过

  $ make ios
  ✅ 编译通过

  $ make test-unit
  ✅ FavoriteServiceTests — 5 个用例全部通过

Agent 对照「工作流规范检查点 - 提交前自检」:
  ✅ make audit 通过
  ✅ make ios 编译通过
  ✅ make test-unit 通过
```

#### Demo Step 7：CI 失败自愈（假设发生）

```
假设 Agent 生成的 View 中不小心写了 .padding(12):

  CI 报错:
    Sources/Features/Knowledge/FavoriteListView.swift:28: error:
    [Design Token] 魔鬼数字 12，应使用 DesignSystem Token。
      📋 规范: @Docs/Architecture/STANDARDS_GOVERNANCE_MATRIX.md#2.1
      🔧 建议: 将 .padding(12) 改为 .padding(DesignSystem.standardPadding)
      ✅ 示例: .padding(DesignSystem.standardPadding)

Agent 自愈流程:
  1. 解析报错: FavoriteListView.swift:28，[Design Token]，魔鬼数字 12
  2. 读取规范引用: @Docs/Architecture/STANDARDS_GOVERNANCE_MATRIX.md#2.1
  3. 按修复建议生成修复: .padding(DesignSystem.standardPadding)
  4. 写入修复: edit FavoriteListView.swift
  5. 重新提交
```

### 13.5 落地验证清单

完成 Phase 1 落地后，用以下清单验证：

| 验证项 | 验证方法 | 预期结果 |
|--------|----------|----------|
| AGENTS.md 速查卡 | `grep "速查决策表" AGENTS.md` | 匹配到内容 |
| AGENTS.md 场景化加载指令 | `grep "场景化规范加载指令" AGENTS.md` | 匹配到内容 |
| AGENTS.md 工作流检查点 | `grep "工作流规范检查点" AGENTS.md` | 匹配到内容 |
| 代码模板库 | `ls Docs/Guides/code-templates.md` | 文件存在 |
| 模板库包含 5 类模板 | `grep "### 9." Docs/Guides/code-templates.md` | 匹配 5 个 |
| AGENTS.md 文档索引登记 | `grep "code-templates" AGENTS.md` | 匹配到内容 |
| Agent Demo 可执行 | 按 13.4 Demo 流程执行 | Agent 生成合规代码，CI 通过 |

---

## 15. SDLC AI Native 演进展望

> **定位**：本节阐述规范治理矩阵从当前「线性闭环」向「AI 原生 SDLC 治理平台」的演进方向。
> **读者**：架构师、平台工程团队、AI 治理负责人。
> **性质**：前瞻性设计，非立即落地，作为长期演进蓝图。

### 15.1 从规范治理到 AI Native SDLC

#### 当前治理矩阵的边界

当前治理矩阵建立了「事前遵循 → 事后检查 → 失败自愈」的线性闭环，但仍有边界：

| 维度 | 当前能力 | 边界 |
|------|----------|------|
| 治理范围 | 编码 + 测试阶段 | 未覆盖需求→设计→部署→运维全生命周期 |
| Agent 控制 | Agent 自主读取规范 + 自检 | 无强制流程编排，Agent 可跳过检查点 |
| 安全治理 | 依赖 CI 静态分析（SAST/SCA） | 无 Agent 行为审计、无 Prompt 注入防护、无权限隔离 |
| 度量反馈 | 缺口统计（静态） | 无实时度量仪表盘、无趋势分析、无 Agent 行为画像 |
| 多 Agent 协作 | 单 Agent 线性工作 | 无多 Agent 任务分派、无冲突检测、无结果聚合 |

#### AI Native SDLC 的愿景

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    AI Native SDLC 治理平台                                │
│                                                                         │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                     流程编排层 (Orchestration)                      │  │
│  │  需求分析 → 架构设计 → 编码 → 测试 → 代码审查 → 部署 → 运维         │  │
│  │  每个阶段：Agent 执行 + 规范门禁 + 人工审批 + 自动流转               │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│         │                │              │              │                │
│         ▼                ▼              ▼              ▼                │
│  ┌────────────┐  ┌────────────┐ ┌────────────┐ ┌────────────┐          │
│  │ Agent 流程  │  │ 安全机制    │ │ 度量机制    │ │ 规范治理    │          │
│  │ 控制        │  │            │ │            │ │ (本文当前   │          │
│  │            │  │            │ │            │ │  范围)      │          │
│  └────────────┘  └────────────┘ └────────────┘ └────────────┘          │
└─────────────────────────────────────────────────────────────────────────┘
```

**核心理念**：规范治理矩阵是 AI Native SDLC 的「规范治理支柱」，需与流程编排、Agent 控制、安全机制、度量机制协同，形成全生命周期 AI 原生治理。

### 15.2 四大演进支柱

#### 支柱一：流程编排（Pipeline Orchestration）

> **目标**：将 Agent 开发流程从「自主线性」升级为「编排式流水线」，每个阶段有规范门禁和自动流转。

| 维度 | 当前 | 演进后 |
|------|------|--------|
| 流程定义 | AGENTS.md 工作流检查点（建议性） | 可执行 Pipeline DSL（强制性） |
| 阶段流转 | Agent 自主决定 | 编排器按门禁结果自动流转/阻断 |
| 人工介入 | Agent 完成后人工 PR Review | 关键阶段强制人工审批门禁 |
| 多 Agent | 单 Agent | 多 Agent 任务分派 + 结果聚合 |

**演进设计**：

```
Pipeline DSL 示例（伪代码）:

pipeline "feature-development":
  stage "design":
    agent: "architect-agent"
    input: user_requirement
    gate:
      - check: architecture-layering
      - check: opensource-selection
      - human_approval: required
    output: design_doc

  stage "coding":
    agent: "coder-agent"
    input: design_doc
    pre_load:
      - AGENTS.md 速查卡
      - 场景化规范（按 design_doc 自动匹配）
      - code-templates.md
    gate:
      - check: pre-commit-hooks
      - check: make-audit
      - check: make-ios
    output: code_changes

  stage "testing":
    agent: "tester-agent"
    input: code_changes
    pre_load:
      - TEST_CASE_STANDARDS.md
      - test-templates
    gate:
      - check: test-coverage >= 95%
      - check: test-branch-coverage >= 90%
      - check: no-zero-assertion
    output: test_results

  stage "review":
    agent: "reviewer-agent"
    input: code_changes + test_results
    gate:
      - check: code-review-security
      - check: code-review-quality
      - human_approval: required
    output: review_report

  stage "deploy":
    gate:
      - check: all-previous-gates-passed
    action: auto-merge
```

**与本文的关系**：治理矩阵的「速查卡 + 场景化加载 + 代码模板 + CI 检查」成为 Pipeline DSL 中每个 stage 的 `pre_load` 和 `gate` 配置源。

#### 支柱二：Agent 流程控制（Agent Workflow Control）

> **目标**：从「Agent 自主决定流程」升级为「平台控制 Agent 执行流程」，确保不可跳过规范检查点。

| 维度 | 当前 | 演进后 |
|------|------|--------|
| 流程约束 | AGENTS.md 检查清单（Agent 可忽略） | 平台强制检查点（Agent 不可跳过） |
| 上下文管理 | Agent 自行决定加载哪些规范 | 平台按任务类型自动注入规范上下文 |
| 回滚机制 | Agent 失败后人工介入 | 平台自动回滚 + 重新分派 |
| 权限控制 | Agent 拥有完整代码写权限 | 最小权限原则，按阶段授予写权限 |

**演进设计**：

```
Agent 流程控制架构:

┌──────────────────────────────────────────────┐
│            Agent 流程控制器                    │
│                                              │
│  ┌────────────┐  ┌────────────┐             │
│  │ 上下文注入器 │  │ 检查点守卫  │             │
│  │            │  │            │             │
│  │ 按任务类型  │  │ 每个阶段    │             │
│  │ 自动注入    │  │ 强制执行    │             │
│  │ 规范上下文  │  │ 规范门禁    │             │
│  └────────────┘  └────────────┘             │
│                                              │
│  ┌────────────┐  ┌────────────┐             │
│  │ 权限管理器  │  │ 回滚管理器  │             │
│  │            │  │            │             │
│  │ 按阶段授予  │  │ 失败自动    │             │
│  │ 最小写权限  │  │ 回滚 +     │             │
│  │            │  │ 重新分派    │             │
│  └────────────┘  └────────────┘             │
└──────────────────────────────────────────────┘
```

**与本文的关系**：治理矩阵的「渐进式披露机制」成为上下文注入器的实现方案；「工作流规范检查点」成为检查点守卫的配置源。

#### 支柱三：安全机制（Security Mechanism）

> **目标**：从「CI 阶段 SAST/SCA 扫描」升级为「全生命周期 AI 安全治理」，覆盖 Agent 行为安全。

| 维度 | 当前 | 演进后 |
|------|------|--------|
| 代码安全 | CI 阶段 SAST/SCA 扫描 | 编码阶段实时安全扫描 + Agent 生成即安全 |
| Prompt 安全 | 无 | Prompt 注入防护 + 敏感信息脱敏 |
| Agent 行为审计 | 无 | Agent 操作日志 + 异常行为检测 |
| 依赖安全 | CI 阶段 SCA 扫描 | 引入依赖前实时 CVE 查询 + 自动升级 |
| 密钥管理 | pre-commit 密钥扫描 | Agent 无密钥访问权限 + 运行时密钥注入 |

**演进设计**：

```
安全机制分层:

┌──────────────────────────────────────────────────┐
│              AI Native 安全治理                    │
│                                                  │
│  Layer 1: Agent 输入安全                          │
│    - Prompt 注入检测（用户输入 → Agent）           │
│    - 敏感信息脱敏（日志/输出中不泄漏密钥）          │
│    - 规范注入完整性（规范上下文不被篡改）           │
│                                                  │
│  Layer 2: Agent 生成安全                          │
│    - 实时 SAST 扫描（Agent 生成代码即时检查）      │
│    - 依赖 CVE 实时查询（引入依赖前检查）           │
│    - 密钥泄漏检测（生成代码中无硬编码密钥）         │
│                                                  │
│  Layer 3: Agent 行为安全                          │
│    - 操作审计日志（Agent 所有文件操作可追溯）       │
│    - 异常行为检测（批量删除/越权访问告警）          │
│    - 权限隔离（Agent 仅能访问授权路径）            │
│                                                  │
│  Layer 4: CI 兜底安全                             │
│    - SAST/SCA 全量扫描（本文当前范围）             │
│    - 密钥扫描（pre-commit/pre-push）              │
│    - 许可证合规扫描                                │
└──────────────────────────────────────────────────┘
```

**与本文的关系**：治理矩阵的「事后检查层」对应安全机制 Layer 4（CI 兜底）；演进后需新增 Layer 1-3（Agent 输入/生成/行为安全）。

#### 支柱四：度量机制（Measurement Mechanism）

> **目标**：从「静态缺口统计」升级为「实时度量仪表盘 + 趋势分析 + Agent 行为画像」，持续优化治理效果。

| 维度 | 当前 | 演进后 |
|------|------|--------|
| 度量对象 | 规范条款覆盖率 | 规范覆盖率 + Agent 遵循率 + 自愈成功率 + 安全事件数 |
| 度量时机 | 人工盘点（静态） | 实时采集（动态仪表盘） |
| 度量粒度 | 规范领域级 | 规范条款级 + Agent 实例级 + 时间趋势 |
| 反馈闭环 | 无 | 度量 → 分析 → 优化规范/模板/门禁 |

**演进设计**：

```
度量机制架构:

┌──────────────────────────────────────────────────────┐
│                  度量仪表盘                            │
│                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │ 规范覆盖率   │  │ Agent 遵循率 │  │ 自愈成功率   │  │
│  │             │  │             │  │             │  │
│  │ 事前: 80%   │  │ 生成合规率  │  │ CI 失败 →   │  │
│  │ 事后: 95%   │  │ 95%         │  │ 自动修复    │  │
│  │             │  │             │  │ 成功率 90%  │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
│                                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │ 安全事件数   │  │ 返工率       │  │ 趋势分析    │  │
│  │             │  │             │  │             │  │
│  │ SAST 拦截   │  │ CI 失败 →   │  │ 周环比      │  │
│  │ Agent 违规  │  │ 返工次数    │  │ 月环比      │  │
│  │             │  │             │  │ 季度预测    │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  │
└──────────────────────────────────────────────────────┘

数据采集点:
  ① Agent 生成代码时 → 记录规范遵循/违反
  ② CI 检查时 → 记录门禁通过/失败
  ③ Agent 自愈时 → 记录修复成功/失败
  ④ 安全扫描时 → 记录安全事件
  ⑤ 人工审查时 → 记录审查结果
```

**度量指标体系**：

| 指标类别 | 指标名 | 定义 | 目标值 | 采集点 |
|----------|--------|------|--------|--------|
| **规范覆盖** | 事前遵循覆盖率 | 速查卡覆盖的规范条款数 / 总条款数 | ≥ 80% | AGENTS.md |
| **规范覆盖** | 事后检查覆盖率 | 有 CI 检查的规范条款数 / 总条款数 | ≥ 95% | CI 脚本 |
| **Agent 遵循** | 生成合规率 | Agent 首次生成即通过 CI 的比例 | ≥ 95% | CI 流水线 |
| **Agent 遵循** | 规范违反 TOP-N | 最常违反的规范条款排名 | 持续下降 | CI 报错统计 |
| **自愈能力** | CI 失败自愈率 | Agent 据 CI 报错自动修复成功数 / CI 失败总数 | ≥ 90% | CI + Agent 日志 |
| **自愈能力** | 平均自愈轮次 | 从 CI 失败到修复成功的平均迭代次数 | ≤ 2 轮 | Agent 日志 |
| **安全治理** | 安全事件数 | SAST/SCA/密钥扫描拦截的违规数 | 持续下降 | 安全扫描 |
| **安全治理** | Agent 异常行为数 | Agent 越权/批量删除等异常操作数 | 0 | Agent 审计日志 |
| **效率** | 返工率 | CI 失败导致返工的次数 / 总提交次数 | ≤ 5% | CI 流水线 |
| **效率** | 平均开发周期 | 从任务分派到合并的平均时长 | 持续下降 | Pipeline 日志 |

**与本文的关系**：治理矩阵的「缺口统计」（第 10 节）是度量机制的初始形态；演进后需建立实时采集 + 仪表盘 + 趋势分析能力。

### 15.3 演进路线图

```
Phase 1 (当前)          Phase 2                Phase 3                Phase 4                Phase 5
规范治理矩阵             流程编排集成             Agent 流程控制          安全机制集成             度量机制
┌──────────┐          ┌──────────┐           ┌──────────┐           ┌──────────┐           ┌──────────┐
│ 事前遵循  │          │ Pipeline │           │ Agent    │           │ AI 安全  │           │ 实时度量  │
│ 事后检查  │    →     │ DSL      │    →      │ 流程控制  │    →      │ 全生命周期│    →      │ 仪表盘   │
│ 失败自愈  │          │ 自动流转  │           │ 强制检查点│           │ Agent审计│           │ 趋势分析  │
│ 渐进式披露│          │ 人工审批  │           │ 权限隔离  │           │ 行为检测  │           │ 持续优化  │
└──────────┘          └──────────┘           └──────────┘           └──────────┘           └──────────┘
    │                      │                      │                      │                      │
    ▼                      ▼                      ▼                      ▼                      ▼
 事前遵循率              开发流程                Agent 行为              安全事件数             度量驱动
 17%→80%                可编排                  可控可审计              可追溯可度量            持续优化
```

| Phase | 名称 | 核心交付 | 依赖 | 预期周期 |
|-------|------|----------|------|----------|
| **Phase 1** | 规范治理矩阵（本文） | 速查卡 + 渐进式披露 + 代码模板 + CI 增强 + 自愈报错 | 无 | 1-4 周 |
| **Phase 2** | 流程编排集成 | Pipeline DSL + 阶段门禁 + 自动流转 + 人工审批门禁 | Phase 1 | 1-2 月 |
| **Phase 3** | Agent 流程控制 | 上下文注入器 + 检查点守卫 + 权限管理器 + 回滚管理器 | Phase 2 | 2-3 月 |
| **Phase 4** | 安全机制集成 | Agent 输入安全 + 生成安全 + 行为审计 + 异常检测 | Phase 3 | 2-3 月 |
| **Phase 5** | 度量机制 | 实时采集 + 仪表盘 + 趋势分析 + Agent 画像 + 持续优化 | Phase 1-4 | 1-2 月 |

### 15.4 与现有系统的关系

```
┌─────────────────────────────────────────────────────────────────────┐
│                    现有系统 → AI Native SDLC 映射                      │
│                                                                     │
│  现有系统                          AI Native SDLC 支柱               │
│  ─────────                        ──────────────────                │
│  AGENTS.md                        → 规范治理（本文）                  │
│  CI/CD 流水线 (.gitlab-ci.yml)    → 流程编排（Phase 2）              │
│  pre-commit / pre-push hooks      → Agent 流程控制（Phase 3）        │
│  SAST/SCA 扫描                    → 安全机制（Phase 4）              │
│  SonarQube 覆盖率                 → 度量机制（Phase 5）              │
│  41 项静态分析脚本                 → 规范治理 + 安全机制              │
│  gatekeeper_reporter.py (规划)    → 自愈层 + 度量机制                │
│  code-templates.md (规划)         → 规范治理（事前遵循）              │
│  渐进式披露机制                    → Agent 流程控制（上下文注入）      │
└─────────────────────────────────────────────────────────────────────┘
```

### 15.5 关键设计决策

| 决策点 | 选项 A | 选项 B | 推荐 | 理由 |
|--------|--------|--------|------|------|
| Pipeline DSL 实现 | 自研 DSL | 复用 GitLab CI / GitHub Actions | **B** | 避免重复造轮子，复用现有 CI/CD 基础设施 |
| Agent 流程控制 | Agent 内嵌 | 平台外挂 | **B** | 平台控制更强，Agent 不可绕过 |
| 安全扫描时机 | 仅 CI 阶段 | 编码实时 + CI 兜底 | **B** | 实时扫描减少返工，CI 兜底确保不漏 |
| 度量数据存储 | 文件/日志 | 时序数据库 | **B** | 趋势分析需要时序查询能力 |
| 多 Agent 协作 | 串行 | 并行 + 冲突检测 | **B** | 并行提升效率，冲突检测保证一致性 |

> **开源选型优先**：根据 AGENTS.md「开源选型优先原则」，Phase 2-5 的实现应优先评估业界开源方案（如 LangChain Agent 编排、OpenTelemetry 度量采集等），而非自研。

### 15.6 本节的定位声明

本节是**前瞻性设计蓝图**，非立即落地计划。其价值在于：

1. **确保当前治理矩阵的可扩展性**：Phase 1 的设计（速查卡/渐进式披露/代码模板/CI 增强/自愈报错）已预留与 Phase 2-5 的对接点。
2. **避免短视设计**：当前决策（如 gatekeeper_reporter.py 报错格式、渐进式披露三层架构）已考虑未来被流程编排层和度量机制复用。
3. **提供演进方向**：团队可按 Phase 逐步演进，每个 Phase 独立可交付，无需一次性重构。

---

## 16. 治理实现机制与技术演进

> **定位**：前文阐述了「治理什么」（规范矩阵）和「治理架构」（四层架构），本节回答「用什么技术机制承载治理」。
> **核心问题**：规范条款如何从「文档中的文字」变为「Agent 可执行、可校验、可检索的机器可读规则」？

### 16.1 技术机制全景图

```
┌─────────────────────────────────────────────────────────────────────────┐
│              治理实现机制与技术演进全景                                    │
│                                                                         │
│         短期（Phase 1）        中期（Phase 2-3）       长期（Phase 4-5）  │
│         ──────────────        ──────────────        ──────────────     │
│                                                                         │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐     │
│  │  Skill          │    │  RAG            │    │  MCP            │     │
│  │  规范检查技能     │    │  规范检索增强    │    │  治理工具协议    │     │
│  │  Agent 主动调用  │ →  │  向量检索规范    │ →  │  标准化交互      │     │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘     │
│                                                                         │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐     │
│  │  Rule           │    │  Vector Index   │    │  Tool Registry  │     │
│  │  结构化规则定义  │    │  规范向量化索引  │    │  治理工具注册表  │     │
│  │  机器可执行      │ →  │  语义相似度     │ →  │  Agent 可发现    │     │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘     │
│                                                                         │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐     │
│  │  Script         │    │  Embedding      │    │  Agent Gateway  │     │
│  │  CI 检查脚本     │    │  规范嵌入模型    │    │  治理网关        │     │
│  │  事后拦截        │ →  │  实时检索       │ →  │  统一入口        │     │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘     │
│                                                                         │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐     │
│  │  Asset          │    │  Knowledge Base │    │  Policy Engine  │     │
│  │  模板/文档/Fixture│   │  规范知识库     │    │  策略引擎        │     │
│  │  版本管理        │ →  │  持续更新       │ →  │  动态策略        │     │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘     │
│                                                                         │
│  ────────────────────────────────────────────────────────────────────  │
│  治理四层架构映射:                                                      │
│    Skill/Rule/Asset  → Layer 2 (事前遵循)                               │
│    Script            → Layer 3 (事后检查)                               │
│    RAG               → Layer 2 (事前遵循，智能检索)                      │
│    MCP               → Layer 2-4 (事前遵循 + 事后检查 + 自愈)            │
└─────────────────────────────────────────────────────────────────────────┘
```

### 16.2 短期机制：Skill / Rule / Script / Asset

> **定位**：Phase 1 立即可落地的技术机制，无需额外基础设施，基于现有文件系统和 CI 即可承载。

#### 16.2.1 Skill — 规范检查技能

**概念**：将规范检查封装为 Agent 可主动调用的 Skill，Agent 在编码前/编码中主动调用，而非等 CI 事后拦截。

**与当前治理矩阵的关系**：速查决策表中的每条规则可封装为 Skill。

| Skill 名称 | 触发时机 | 功能 | 实现方式 |
|------------|----------|------|----------|
| `check-arch-compliance` | 写 import 语句后 | 检查分层依赖是否合规 | 调用 `audit-arch-domain-purity.py` + `audit-arch-dependency.py` |
| `check-l10n-compliance` | 写 UI 文本后 | 检查是否硬编码、是否用 L10n | 调用 `check-code-localization.py` |
| `check-design-token` | 写 UI 尺寸后 | 检查是否用 DesignSystem Token | 调用 `audit-design-token-magic-numbers.py` |
| `check-magic-number` | 写业务逻辑后 | 检查魔鬼数字/字符串 | 调用 `audit-code-business-magic-numbers.py` |
| `check-test-quality` | 写测试代码后 | 检查命名/结构/断言/确定性 | 调用测试检查脚本组合 |
| `get-code-template` | 新建文件时 | 获取对应类型的代码模板 | 读取 `code-templates.md` 对应章节 |
| `get-spec-section` | 需要规范详情时 | 获取规范文档特定章节 | 读取规范文档 offset/limit（渐进式披露 Layer 2） |

**演进路径**：

```
当前: Agent 读 AGENTS.md 速查卡 → 人工判断是否合规
短期: Agent 调用 check-* Skill → Skill 返回合规/违规结果
中期: Skill 集成到 IDE 实时检查 → 编码即检查
```

**落地方式**：将现有 56 个 CI 脚本封装为 Skill，Agent 通过 `skill` 工具调用。无需新建基础设施。

#### 16.2.2 Rule — 结构化规则定义

**概念**：将速查决策表中的每条规则从「Markdown 表格行」升级为「机器可读的结构化 Rule」，支持自动校验和规则引擎推理。

**与当前治理矩阵的关系**：速查决策表的 15 行规则结构化为 Rule 定义。

**Rule 结构示例**（YAML 格式）：

```yaml
# Config/rules/architecture-rules.yml
rules:
  - id: ARCH-001
    name: "Domain 层禁止导入 UI 框架"
    domain: architecture
    severity: error
    pattern:
      file_path: "Sources/Domain/**/*.swift"
      forbid_import: ["UIKit", "AppKit", "SwiftUI", "WatchKit"]
    ci_script: "audit-arch-domain-purity.py"
    spec_ref: "LAYERING_L0_L3.md#2"
    fix_suggestion: "删除违规 import，如需平台能力则定义协议在 Domain/Protocols/"
    agent_guidance: "写 Sources/Domain/ 代码时，仅 import Foundation"

  - id: ARCH-002
    name: "L0-L3 单向依赖"
    domain: architecture
    severity: error
    pattern:
      dependency_direction: "top-down-only"
      layers: ["L3", "L2", "L1.5", "L1", "L0"]
    ci_script: "audit-arch-dependency.py"
    spec_ref: "LAYERING_L0_L3.md#3"
    fix_suggestion: "检查 import 链，将反向依赖改为协议抽象 + DI 注入"
    agent_guidance: "写代码时遵循 L3→L2→L1.5→L1→L0，绝不反向"

  - id: L10N-001
    name: "UI 文本必须用 L10n 强类型"
    domain: development
    severity: error
    pattern:
      file_path: "Sources/Features/**/*.swift"
      forbid: ["硬编码中文", "硬编码英文 UI 文本", ".tr() 直接调用"]
    ci_script: "check-code-localization.py"
    spec_ref: "AGENTS.md#本地化强约束"
    fix_suggestion: "将硬编码文本改为 L10n.模块.属性，在 L10n+XXX.swift 注册"
    agent_guidance: "UI 文本用 L10n.模块.属性，禁止硬编码和直接 .tr()"

  - id: TEST-001
    name: "测试用例必须有断言"
    domain: testing
    severity: error
    pattern:
      file_path: "Tests/**/*.swift"
      require: ["XCTAssert", "assert", "expect"]
      min_count: 1
    ci_script: "audit-test-no-assertion.py"  # 待新建
    spec_ref: "TEST_CASE_STANDARDS.md#8"
    fix_suggestion: "在 // Then 段添加至少 1 个断言"
    agent_guidance: "每个测试用例至少 1 个断言，带失败消息"
```

**Rule 的价值**：

| 维度 | 当前（Markdown 表格） | 演进后（结构化 Rule） |
|------|----------------------|----------------------|
| 机器可读 | ❌ Agent 需理解自然语言 | ✅ 直接解析 YAML/JSON |
| 自动校验 | ❌ 依赖 Agent 自觉 | ✅ Rule Engine 自动校验 |
| 规则推理 | ❌ 无 | ✅ 可推理规则冲突、覆盖盲区 |
| CI 脚本绑定 | ⚠️ 手动维护映射 | ✅ Rule 中声明 ci_script |
| 修复建议 | ⚠️ 手动维护 | ✅ Rule 中声明 fix_suggestion |

**落地方式**：新建 `Config/rules/` 目录，按领域组织规则文件（`architecture-rules.yml`、`development-rules.yml`、`testing-rules.yml` 等）。

#### 16.2.3 Script — CI 检查脚本

**概念**：当前 56 个 CI 脚本是事后检查的核心载体。演进方向是让 Agent 能**实时调用**脚本，而非仅等 CI 阶段。

**与当前治理矩阵的关系**：第 1-5 节治理矩阵中的 CI 检查脚本列。

**当前状态 vs 演进方向**：

| 维度 | 当前 | 演进 |
|------|------|------|
| 调用时机 | CI 流水线 / pre-push | Agent 编码时实时调用 |
| 调用方式 | Shell 脚本批量执行 | Skill 封装 + 单文件检查 |
| 输出格式 | 纯文本 error | 结构化 JSON（含规则 ID + 修复建议） |
| 检查粒度 | 全量扫描 | 增量扫描（仅检查变更文件） |

**Script 输出格式演进**（从纯文本到结构化 JSON）：

```json
{
  "check_name": "audit-arch-domain-purity",
  "rule_id": "ARCH-001",
  "file": "Sources/Domain/Models/FavoriteService.swift",
  "line": 5,
  "severity": "error",
  "message": "违规导入平台相关依赖包 'UIKit'",
  "spec_ref": "LAYERING_L0_L3.md#2",
  "fix_suggestion": "删除违规 import，如需平台能力则定义协议在 Domain/Protocols/",
  "fix_example": "// 删除: import UIKit\n// 如需平台能力:\n// protocol PlatformAdapter { ... }"
}
```

**落地方式**：改造现有脚本，增加 `--format json` 输出选项；新增 `--incremental` 增量检查模式。

#### 16.2.4 Asset — 治理资产管理

**概念**：代码模板、规范文档、测试 Fixture、Rule 定义都是治理 Asset，需统一版本管理和分发。

**与当前治理矩阵的关系**：代码模板库（第 9 节）、规范文档（31 个）、Rule 定义（16.2.2）。

**Asset 分类与管理**：

| Asset 类型 | 存储位置 | 版本管理 | 消费者 | 更新频率 |
|------------|----------|----------|--------|----------|
| 规范文档 | `Docs/` | Git | Agent（渐进式披露） | 低（季度） |
| 代码模板 | `Docs/Guides/code-templates.md` | Git | Agent（生成代码起点） | 中（月） |
| Rule 定义 | `Config/rules/*.yml` | Git | Rule Engine + CI 脚本 | 中（月） |
| 测试 Fixture | `Tests/Shared/` | Git | Agent（生成测试） | 低（季度） |
| CI 脚本 | `Tools/ios/` | Git | CI 流水线 + Skill | 中（月） |
| 豁免白名单 | `Config/exemptions/manual_whitelist.yml` | Git | CI 脚本 | 高（周） |

**Asset 版本一致性挑战**：

```
问题: 规范文档更新后，Rule 定义、CI 脚本、代码模板可能未同步更新

解决方案:
  ┌──────────────────────────────────────────────┐
  │            Asset 一致性校验器                  │
  │                                              │
  │  规范文档 (Source of Truth)                   │
  │      │                                       │
  │      ├──→ Rule 定义 ←── 一致性校验            │
  │      ├──→ CI 脚本  ←── 一致性校验            │
  │      ├──→ 代码模板 ←── 一致性校验            │
  │      └──→ 速查卡  ←── 一致性校验            │
  │                                              │
  │  CI 门禁: check-asset-consistency.py         │
  │  规范文档修改时，自动检查关联 Asset 是否同步  │
  └──────────────────────────────────────────────┘
```

**落地方式**：新建 `check-asset-consistency.py`，在 CI 中校验规范文档与 Rule/脚本/模板的一致性。

### 16.3 中期演进：RAG（检索增强生成）

> **定位**：替代当前「手动渐进式披露」，用向量检索自动找到相关规范条款，Agent 无需手动指定 `read offset/limit`。

#### 16.3.1 当前渐进式披露的局限

| 局限 | 说明 | 影响 |
|------|------|------|
| **手动映射** | 场景→文档映射表需人工维护 | 新增规范时需手动更新映射表，易遗漏 |
| **固定章节** | `read offset=22 limit=20` 是硬编码行号 | 规范文档修改后行号变化，映射失效 |
| **无语义理解** | 按任务类型匹配，非按语义匹配 | Agent 遇到跨领域问题时无法找到所有相关规范 |
| **无排序** | 返回固定章节，不按相关性排序 | 可能返回低相关内容，浪费上下文 |

#### 16.3.2 RAG 架构设计

```
┌─────────────────────────────────────────────────────────────────────┐
│                    RAG 规范检索架构                                   │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  离线索引阶段 (Indexing)                                        │ │
│  │                                                               │ │
│  │  31 个规范文档                                                 │ │
│  │      │                                                        │ │
│  │      ▼                                                        │ │
│  │  文档分块 (Chunking)                                           │ │
│  │  ─ 按章节分块（## 标题为边界）                                  │ │
│  │  ─ 每块含元数据（文档名/章节号/行号范围/领域标签）              │ │
│  │      │                                                        │ │
│  │      ▼                                                        │ │
│  │  向量嵌入 (Embedding)                                          │ │
│  │  ─ 将每个 chunk 嵌入为向量                                     │ │
│  │  ─ 存入向量数据库                                              │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                              │                                      │
│                              │                                      │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  在线检索阶段 (Retrieval)                                      │ │
│  │                                                               │ │
│  │  Agent 任务描述 / 代码上下文                                    │ │
│  │      │                                                        │ │
│  │      ▼                                                        │ │
│  │  Query 嵌入 → 向量检索 → Top-K 相关 chunk                      │ │
│  │      │                                                        │ │
│  │      ▼                                                        │ │
│  │  上下文组装 → 注入 Agent 上下文                                 │ │
│  │  ─ 按相关性排序                                                │ │
│  │  ─ 控制总 token 数（上下文预算）                                │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

#### 16.3.3 RAG vs 手动渐进式披露对比

| 维度 | 手动渐进式披露（当前） | RAG（演进后） |
|------|----------------------|---------------|
| 检索方式 | 手动场景→文档映射表 | 语义相似度向量检索 |
| 维护成本 | 高（映射表手动维护） | 低（文档更新后自动重新索引） |
| 检索精度 | 固定章节，可能包含无关内容 | 按相关性排序，精准返回 |
| 跨领域检索 | ❌ 不支持 | ✅ 自动找到跨领域相关规范 |
| 行号依赖 | ✅ 依赖固定行号（易失效） | ❌ 不依赖行号 |
| 上下文预算 | 固定（~424 行） | 动态（按相关性 + token 预算） |
| 基础设施 | 无（纯文件读取） | 向量数据库 + Embedding 模型 |

#### 16.3.4 RAG 落地路径

```
Step 1: 规范文档分块
  ─ 将 31 个规范文档按章节分块
  ─ 每块附加元数据（文档名/章节号/领域标签/CI 脚本关联）
  ─ 产出: chunks.jsonl

Step 2: 向量嵌入
  ─ 用 Embedding 模型将每个 chunk 嵌入为向量
  ─ 存入向量数据库（如 ChromaDB / Qdrant / 本地 SQLite-vec）
  ─ 产出: vector_index

Step 3: 检索接口
  ─ 实现 retrieve_spec(query: str, top_k: int) → List[Chunk]
  ─ 封装为 Skill 或 MCP tool
  ─ 产出: retrieve-spec Skill

Step 4: Agent 集成
  ─ Agent 接收任务时，自动调用 retrieve-spec
  ─ 检索结果注入 Agent 上下文
  ─ 替代手动场景化加载指令
```

> **开源选型优先**：根据 AGENTS.md「开源选型优先原则」，RAG 实现应优先评估：
> - 向量数据库：ChromaDB（开源）、Qdrant（开源）、sqlite-vec（轻量）
> - Embedding 模型：OpenAI text-embedding-3、BGE（开源）、Cohere
> - RAG 框架：LangChain（开源）、LlamaIndex（开源）

#### 16.3.5 RAG 与智宇现有向量基础设施的复用

智宇项目本身是 RAG 闭环系统，已有向量基础设施（`UFPStorage` + `VectorIndexer` + `EmbeddingManager`）。规范检索 RAG 可复用现有基础设施：

| 现有组件 | 规范 RAG 复用方式 |
|----------|------------------|
| `EmbeddingManager` | 将规范 chunk 嵌入为向量 |
| `VectorIndexer` | 索引规范 chunk 向量 |
| `UFPStorage` (SQLite + FTS5) | 存储规范 chunk 元数据 + 全文检索 |
| `KnowledgeIngestPipeline` | 规范文档入库流程复用 |

**价值**：无需引入外部向量数据库，复用智宇自身的 RAG 基础设施，降低运维成本。

### 16.4 长期演进：MCP（Model Context Protocol）

> **定位**：将规范检查、模板获取、CI 调用、自愈修复封装为 MCP tools，Agent 通过标准化协议与治理系统交互。

#### 16.4.1 为什么需要 MCP

| 维度 | 当前（Skill/Script） | MCP 演进后 |
|------|---------------------|------------|
| 交互协议 | 各 Skill 各自定义接口 | 标准化 MCP 协议 |
| 工具发现 | Agent 需知道 Skill 名称 | MCP 自动发现可用工具 |
| 跨 Agent 兼容 | 仅限当前 Agent | 任何支持 MCP 的 Agent 均可使用 |
| 工具组合 | Agent 手动串联 | MCP 支持工具链编排 |
| 权限控制 | 无 | MCP 协议层权限管理 |

#### 16.4.2 MCP 治理工具设计

```
┌─────────────────────────────────────────────────────────────────────┐
│                  MCP 治理工具注册表 (Tool Registry)                   │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  规范检索工具 (Spec Retrieval)                                  │ │
│  │  ─ retrieve_spec(query, top_k) → 相关规范条款                   │ │
│  │  ─ get_rule(rule_id) → 结构化规则定义                           │ │
│  │  ─ list_rules(domain?) → 规则列表                               │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  合规检查工具 (Compliance Check)                                │ │
│  │  ─ check_file(file_path) → 合规/违规结果                        │ │
│  │  ─ check_diff(diff_content) → 变更合规检查                      │ │
│  │  ─ check_project(scope) → 项目级合规扫描                        │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  模板获取工具 (Template Retrieval)                              │ │
│  │  ─ get_template(type) → 代码模板（View/VM/Service/Test）       │ │
│  │  ─ get_fixture(type) → 测试 Fixture                            │ │
│  │  ─ get_header(layer) → 文件头模板                               │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  自愈修复工具 (Self-healing)                                    │ │
│  │  ─ parse_ci_error(error_output) → 结构化错误                    │ │
│  │  ─ get_fix_suggestion(rule_id, context) → 修复建议              │ │
│  │  ─ apply_fix(file_path, fix) → 自动修复                         │ │
│  └───────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │  度量查询工具 (Measurement Query)                               │ │
│  │  ─ get_compliance_rate(time_range) → 合规率                    │ │
│  │  ─ get_violation_topn(n) → 违规 TOP-N                          │ │
│  │  ─ get_agent_performance(agent_id) → Agent 画像                │ │
│  └───────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

#### 16.4.3 MCP 工具与治理四层架构的映射

| MCP 工具类别 | 治理架构层 | 作用 |
|-------------|-----------|------|
| 规范检索工具 | Layer 2（事前遵循） | Agent 编码前检索相关规范 |
| 合规检查工具 | Layer 2 + Layer 3 | 编码时实时检查 + CI 事后检查 |
| 模板获取工具 | Layer 2（事前遵循） | Agent 生成代码时获取模板 |
| 自愈修复工具 | Layer 4（自愈层） | CI 失败后 Agent 自动修复 |
| 度量查询工具 | 跨层（度量机制） | 治理效果度量与持续优化 |

#### 16.4.4 MCP 落地路径

```
Step 1: 定义 MCP 工具接口
  ─ 按上述 5 类工具定义 MCP tool schema
  ─ 产出: tools/schema.json

Step 2: 实现工具后端
  ─ 规范检索 → 复用 RAG 基础设施
  ─ 合规检查 → 封装现有 56 个 CI 脚本
  ─ 模板获取 → 读取 code-templates.md
  ─ 自愈修复 → 封装 gatekeeper_reporter.py 逻辑
  ─ 度量查询 → 读取度量数据库

Step 3: 注册 MCP Server
  ─ 启动 MCP Server，注册所有工具
  ─ Agent 通过 MCP 协议发现并调用工具

Step 4: Agent 集成
  ─ Agent 连接 MCP Server
  ─ 编码前自动调用规范检索 + 合规检查
  ─ CI 失败后自动调用自愈修复
```

> **开源选型优先**：MCP 实现应优先评估：
> - MCP SDK：Anthropic MCP SDK（开源）、ModelScope MCP（开源）
> - Agent 框架：LangChain MCP Adapter（开源）、Claude Code MCP（开源）

### 16.5 技术演进路线图

```
Phase 1 (当前)            Phase 2                Phase 3                Phase 4
Skill/Rule/Script/Asset   RAG 检索增强            MCP 工具协议            全链路集成
┌──────────────┐        ┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│ Skill:       │        │ RAG:         │       │ MCP:         │       │ 全链路:       │
│ 7 个检查技能  │   →    │ 规范向量检索  │  →   │ 5 类治理工具  │  →   │ Pipeline +   │
│              │        │ 替代手动映射  │       │ 标准化协议    │       │ RAG + MCP +  │
│ Rule:        │        │              │       │              │       │ 安全 + 度量  │
│ YAML 规则定义 │        │ Vector:      │       │ Registry:    │       │              │
│              │        │ 复用 UFP     │       │ 工具自动发现  │       │ Agent 全自动 │
│ Script:      │        │ Storage      │       │              │       │ 开发全流程   │
│ JSON 输出     │        │              │       │              │       │              │
│              │        │              │       │              │       │              │
│ Asset:       │        │              │       │              │       │              │
│ 一致性校验    │        │              │       │              │       │              │
└──────────────┘        └──────────────┘       └──────────────┘       └──────────────┘
    │                       │                       │                       │
    ▼                       ▼                       ▼                       ▼
手动调用 Skill          自动检索规范            标准化工具交互          全自动治理
```

| Phase | 技术机制 | 核心交付 | 依赖 | 预期周期 |
|-------|----------|----------|------|----------|
| **Phase 1** | Skill / Rule / Script / Asset | 7 个检查 Skill + YAML 规则定义 + JSON 输出 + Asset 一致性校验 | 无 | 2-4 周 |
| **Phase 2** | RAG | 规范向量索引 + 语义检索 + 复用 UFPStorage | Phase 1 | 1-2 月 |
| **Phase 3** | MCP | 5 类治理工具 + MCP Server + 工具自动发现 | Phase 2 | 1-2 月 |
| **Phase 4** | 全链路集成 | Pipeline + RAG + MCP + 安全 + 度量 一体化 | Phase 1-3 + 第 15 节 Phase 2-5 | 2-3 月 |

### 16.6 技术机制与第 15 节 SDLC 演进的关系

| 第 15 节 SDLC 支柱 | 本节技术机制支撑 |
|-------------------|-----------------|
| 流程编排（Pipeline） | MCP 工具作为 Pipeline stage 的 gate 实现 |
| Agent 流程控制 | MCP 工具 + Rule Engine 作为检查点守卫 |
| 安全机制 | 合规检查 MCP 工具 + Script 实时扫描 |
| 度量机制 | 度量查询 MCP 工具 + Script 结构化输出 |
| 规范治理（本文核心） | Skill + Rule + Script + Asset + RAG + MCP 全链路 |

### 16.7 开源选型参考

> 根据 AGENTS.md「开源选型优先原则」，本节涉及的技术机制应优先评估开源方案：

| 技术领域 | 开源候选 | 选型考量 |
|----------|----------|----------|
| 向量数据库 | ChromaDB / Qdrant / sqlite-vec | 智宇已有 UFPStorage + VectorIndexer，优先复用 |
| Embedding 模型 | BGE / OpenAI text-embedding-3 / Cohere | 中文支持 + 本地部署能力 |
| RAG 框架 | LangChain / LlamaIndex | 与现有 Swift 生态的集成度 |
| MCP SDK | Anthropic MCP SDK / ModelScope MCP | 协议兼容性 + 语言支持 |
| Rule Engine | json-rules-engine / Drools / 自研 | 规则复杂度 + Swift 兼容性 |
| Agent 编排 | LangChain / AutoGen / CrewAI | 多 Agent 协作 + MCP 集成 |

> **重要**：选型决策需提交 USER 确认后方可落地，严禁直接造轮子自研。

---

## 17. 发布治理 (Release Governance)

> **定位**：规范治理如何介入软件版本发布流程——从发布前合规门禁、发布分支治理、热修复治理到发布后审计。
> **关联文档**：`VERSION_MANAGEMENT.md`（版本号体系）、`CI_CD_WORKFLOW.md`（CI/CD 流水线与分支策略）。
> **核心问题**：开发阶段的 CI 门禁与发布阶段的合规门禁有何不同？Agent 在发布流程中能做什么、不能做什么？

### 17.1 发布治理概览

#### 现有发布机制

智宇项目已有完整的版本管理和 CI/CD 流水线：

| 现有文档 | 覆盖范围 | 缺口 |
|----------|----------|------|
| `VERSION_MANAGEMENT.md` | 版本号体系（semVer/构建号/hash/时间戳）、版本注入脚本、fastlane 工具、发布步骤（7 步） | ❌ 未定义发布前合规门禁标准 |
| `CI_CD_WORKFLOW.md` | CI 流水线（4 阶段）、分支策略（8 类分支）、MR 四重卡控、四层纵深防御矩阵 | ❌ 未区分开发门禁与发布门禁 |
| `ROADMAP.md` | 版本路线图（MVP→阶段一→阶段二→阶段三） | ❌ 未定义版本发布合规检查清单 |

#### 发布治理要解决的核心问题

```
开发阶段门禁（当前已有）:
  feature 分支 → CI 静态分析 → 单元测试 → MR 合并 → main
  ✅ 已覆盖：41 项静态分析 + 17 项 pre-push + 覆盖率门禁

发布阶段门禁（本文补充）:
  main → release/v* 分支 → 发布前合规审计 → 三平台构建 → TestFlight → App Store
  ❌ 缺失：发布前合规门禁、发布分支额外规则、热修复治理、发布后审计
```

**核心区别**：开发阶段门禁关注「代码质量」（架构/编码/测试），发布阶段门禁在此基础上增加「发布就绪度」（版本号一致性、App Store 合规、安全扫描、性能基准、回滚预案）。

### 17.2 发布门禁矩阵 (Release Gate Matrix)

> **定义**：发布门禁 = 开发门禁（已有）+ 发布就绪门禁（本文新增）。

#### 17.2.1 开发门禁 vs 发布门禁

| 门禁类别 | 触发时机 | 检查项 | 阻断级别 | 现有覆盖 |
|----------|----------|--------|----------|----------|
| **开发门禁** | feature/fix/refactor 分支 push + MR | 41 项静态分析 + 单元测试 + 覆盖率 | MR 阻断 | ✅ 已覆盖 |
| **发布门禁** | release/v* 分支创建 + push | 开发门禁全部 + 发布就绪门禁（12 项） | 发布阻断 | ❌ 缺失 |
| **热修复门禁** | hotfix/* 分支 push | 发布门禁子集（精简但保留安全关键项） | 发布阻断 | ❌ 缺失 |

#### 17.2.2 发布就绪门禁（12 项）

| 编号 | 检查项 | 检查脚本/工具 | 阻断条件 | 现有状态 |
|------|--------|-------------|----------|----------|
| **R-01** | 版本号一致性（semVer == git tag） | `ci-build-pipeline-version-inject.sh` | tag 与 semVer 不一致 → WARNING（不阻断） | ✅ 已有 |
| **R-02** | 版本号格式合规（纯数字点分） | `ios-check-release-appstore.py` | 格式不合规 → 阻断 | ✅ 已有 |
| **R-03** | App Store 就绪度（Info.plist/权限/隐私清单） | `ios-check-release-appstore.py` | 任一项不合规 → 阻断 | ✅ 已有 |
| **R-04** | 三平台编译通过（iOS/macOS/watchOS） | `ci-build-pipeline-multi-platform.sh` | 任一平台编译失败 → 阻断 | ✅ 已有 |
| **R-05** | 全量单元测试通过 | `ci-run-test-with-coverage.sh` | 任一测试失败 → 阻断 | ✅ 已有 |
| **R-06** | 覆盖率门禁（语句 ≥ 95%，分支 ≥ 90%） | `assert-test-coverage.py` | 覆盖率不达标 → 阻断 | ✅ 已有 |
| **R-07** | 密钥/Token 扫描（零容忍） | `assert-release-hardcoded-secrets.py` | 命中 → 阻断 | ✅ 已有 |
| **R-08** | SPM 依赖漏洞审计 | `ci-audit-spm-dependencies.py` | 高危漏洞 → 阻断 | ✅ 已有 |
| **R-09** | SBOM 生成（SPDX + CycloneDX） | `generate-arch-sbom-*.py` | 生成失败 → 阻断 | ✅ 已有 |
| **R-10** | **CHANGELOG 更新检查** | *(待新建)* `check-release-changelog.py` | release 分支无 CHANGELOG 变更 → 阻断 | ❌ 缺失 |
| **R-11** | **ROADMAP 版本对齐检查** | *(待新建)* `check-release-roadmap-align.py` | semVer 不在 ROADMAP 规划版本中 → WARNING | ❌ 缺失 |
| **R-12** | **发布说明完整性检查** | *(待新建)* `check-release-notes.py` | 缺少功能列表/已知问题/迁移指南 → 阻断 | ❌ 缺失 |

#### 17.2.3 发布门禁执行流程

```
                    main 分支（已通过开发门禁）
                         │
                         │  创建 release/v* 分支
                         ▼
              ┌──────────────────────┐
              │  发布门禁检查（12 项） │
              │                      │
              │  R-01~R-09: 已有     │
              │  R-10~R-12: 待新建   │
              └──────────┬───────────┘
                         │
                    ┌────┴────┐
                    │         │
                 ✅ 全通过   ❌ 失败
                    │         │
                    │         ▼
                    │    ┌──────────────┐
                    │    │ Agent 自愈    │
                    │    │ 或人工修复    │
                    │    └──────┬───────┘
                    │           │
                    │           │ 修复后重新检查
                    │           │
                    └───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  三平台构建 + TestFlight│
              │  fastlane canary      │
              └──────────┬───────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │  App Store 提审       │
              └──────────────────────┘
```

### 17.3 发布分支治理 (Release Branch Governance)

#### 17.3.1 发布分支生命周期

```
release/v1.1.0 分支生命周期:

  创建 ──────────────────── 冻结 ──────────────────── 合并 ──────────────────── 归档
    │                        │                        │                        │
    │ 从 main 切出           │ 仅允许 bugfix          │ 合并回 main             │
    │ 触发发布门禁           │ 禁止新功能             │ 打 tag v1.1.0           │
    │                        │ 每次 push 触发门禁     │ 删除 release 分支       │
    │                        │                        │ 保留 tag                │
    ▼                        ▼                        ▼                        ▼
  门禁检查                  冻结期门禁               发布完成                 历史追溯
```

#### 17.3.2 发布分支额外规则

| 规则 | 开发分支（feature/*） | 发布分支（release/*） | 热修复分支（hotfix/*） |
|------|----------------------|----------------------|----------------------|
| 允许的提交类型 | feat/fix/refactor/docs/test | **仅 fix + docs** | **仅 fix** |
| 新功能提交 | ✅ 允许 | ❌ 禁止 | ❌ 禁止 |
| 重构提交 | ✅ 允许 | ❌ 禁止 | ❌ 禁止 |
| CI 门禁 | 开发门禁（41 项） | **发布门禁（41 + 12 项）** | **热修复门禁（子集）** |
| MR 审批 | Maintainer 1 人 | **Maintainer 2 人** | **Maintainer 1 人 + 紧急通道** |
| 合并目标 | main | main（合并回） | main + release/*（双合并） |
| 分支存活 | 功能完成后删除 | 发布完成后删除 | 修复后删除 |
| CHANGELOG | 不要求 | **必须更新** | **必须更新** |

#### 17.3.3 发布分支 Agent 行为约束

| Agent 行为 | 开发分支 | 发布分支 | 热修复分支 |
|-----------|----------|----------|-----------|
| 生成新功能代码 | ✅ 允许 | ❌ **禁止** | ❌ **禁止** |
| 生成 bugfix 代码 | ✅ 允许 | ✅ 允许 | ✅ 允许 |
| 生成重构代码 | ✅ 允许 | ❌ **禁止** | ❌ **禁止** |
| 修改 CI 脚本 | ✅ 允许 | ❌ **禁止**（仅紧急安全修复） | ❌ **禁止** |
| 修改规范文档 | ✅ 允许 | ❌ **禁止** | ❌ **禁止** |
| 修改依赖版本 | ✅ 允许 | ⚠️ **仅安全补丁** | ⚠️ **仅安全补丁** |
| 直接 push main | ❌ 禁止 | ❌ 禁止 | ❌ 禁止 |
| 创建 tag | ❌ 禁止 | ❌ **禁止**（仅 Maintainer） | ❌ **禁止** |

> **Agent 速查**：Agent 在 `release/*` 或 `hotfix/*` 分支工作时，**仅允许 bugfix**，禁止新功能/重构/CI 变更/规范变更。

### 17.4 热修复治理 (Hotfix Governance)

#### 17.4.1 热修复流程

```
生产环境发现紧急 Bug
         │
         ▼
┌────────────────────┐
│ 紧急评估            │
│ ─ 严重程度: P0/P1?  │
│ ─ 影响范围: 全量用户?│
│ ─ 是否需要热修复?   │
└────────┬───────────┘
         │  确认需要热修复
         ▼
┌────────────────────┐
│ 创建 hotfix 分支    │
│ hotfix/<issue-id>  │
│ 从 main 切出        │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ 热修复门禁（精简）   │
│ ─ 密钥扫描 ✅       │
│ ─ 编译通过 ✅       │
│ ─ 单元测试 ✅       │
│ ─ App Store 就绪 ✅ │
│ ─ 覆盖率: 降级阈值  │
│ ─ CHANGELOG ✅      │
│ ─ 安全扫描 ✅       │
│ ─ 性能基准: 跳过    │
│ ─ SBOM: 跳过        │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ 双合并              │
│ ─ 合并回 main       │
│ ─ 合并到当前 release│
│ ─ 打 tag v1.1.1    │
└────────┬───────────┘
         │
         ▼
┌────────────────────┐
│ 紧急发布            │
│ ─ fastlane canary  │
│ ─ App Store 紧急审核│
└────────────────────┘
```

#### 17.4.2 热修复门禁 vs 正常发布门禁

| 门禁项 | 正常发布 | 热修复 | 说明 |
|--------|----------|--------|------|
| R-01 版本号一致性 | ✅ 必须 | ✅ 必须 | 热修复版本号递增 patch |
| R-02 版本号格式 | ✅ 必须 | ✅ 必须 | |
| R-03 App Store 就绪 | ✅ 必须 | ✅ 必须 | |
| R-04 三平台编译 | ✅ 必须 | ⚠️ **仅受影响平台** | 热修复可能仅影响 iOS |
| R-05 单元测试 | ✅ 必须 | ✅ 必须 | |
| R-06 覆盖率门禁 | ✅ 95%/90% | ⚠️ **降级 85%** | 热修复不追求覆盖率提升 |
| R-07 密钥扫描 | ✅ 必须 | ✅ 必须 | 安全不可降级 |
| R-08 SPM 漏洞审计 | ✅ 必须 | ⚠️ **仅检查变更依赖** | 热修复通常不改依赖 |
| R-09 SBOM 生成 | ✅ 必须 | ⚠️ **跳过** | 热修复后补生成 |
| R-10 CHANGELOG | ✅ 必须 | ✅ 必须 | 记录热修复内容 |
| R-11 ROADMAP 对齐 | ✅ 必须 | ❌ **跳过** | 热修复不在 ROADMAP 规划中 |
| R-12 发布说明 | ✅ 必须 | ⚠️ **精简版** | 仅描述修复内容 |
| **R-13 性能基准** | ✅ 必须 | ⚠️ **跳过** | 热修复不追求性能改进 |
| **R-14 回滚预案** | ✅ 必须 | ✅ 必须 | 热修复必须有回滚方案 |

> **原则**：热修复门禁可降级覆盖率/性能/SBOM，但**安全扫描和 App Store 就绪度不可降级**。

### 17.5 发布后治理 (Post-Release Governance)

#### 17.5.1 发布后检查清单

| 检查项 | 执行时机 | 负责人 | 验证方法 |
|--------|----------|--------|----------|
| TestFlight 内部测试通过 | 发布后 24h 内 | QA | TestFlight 反馈无 P0 问题 |
| App Store 审核通过 | 提审后 48h 内 | Maintainer | App Store Connect 状态 |
| 生产环境监控 | 发布后 7 天 | Ops | Crash 率 < 0.1%、ANR 率 < 0.5% |
| 用户反馈收集 | 发布后 14 天 | Product | App Store 评价 + 反馈表单 |
| 发布后审计 | 发布后 30 天 | Maintainer | 对照发布门禁检查实际结果 |
| 回滚预案验证 | 发布前 | Maintainer | 确认回滚步骤可执行 |

#### 17.5.2 回滚机制

| 场景 | 回滚方式 | 执行步骤 |
|------|----------|----------|
| TestFlight 发现 P0 | 不提交 App Store | 修复后重新 TestFlight |
| App Store 审核被拒 | 修复审核问题 | 重新提审 |
| 已发布发现 P0 | **版本回滚** | 1. 通知用户 2. 创建 hotfix 3. 紧急发布 4. 或下架当前版本 |
| 已发布发现 P1/P2 | **下个版本修复** | 纳入下个 release 计划 |

#### 17.5.3 发布后审计

```
发布后 30 天审计:
  ┌──────────────────────────────────────────────┐
  │  审计项                                       │
  │                                              │
  │  1. 发布门禁实际效果                          │
  │     ─ 12 项门禁是否有遗漏的合规问题？          │
  │     ─ 门禁通过但发布后发现问题的情况？          │
  │                                              │
  │  2. Agent 参与度                              │
  │     ─ release 分支中 Agent 生成的代码占比？    │
  │     ─ Agent 生成的 bugfix 质量如何？           │
  │     ─ Agent 是否违反了发布分支行为约束？        │
  │                                              │
  │  3. 度量数据                                  │
  │     ─ 发布门禁通过率（首次/多次）              │
  │     ─ 发布周期（从 release 分支到 App Store）  │
  │     ─ 热修复次数                              │
  │     ─ 发布后 P0/P1 问题数                     │
  │                                              │
  │  4. 改进建议                                  │
  │     ─ 门禁是否需要增减？                       │
  │     ─ Agent 行为约束是否需要调整？              │
  │     ─ 热修复流程是否需要优化？                  │
  └──────────────────────────────────────────────┘
```

### 17.6 Agent 在发布流程中的角色

#### 17.6.1 Agent 能力矩阵

| 发布阶段 | Agent 能做 | Agent 不能做 | 人工必须做 |
|----------|-----------|-------------|-----------|
| **发布准备** | 生成 CHANGELOG 草稿、生成发布说明草稿、执行发布门禁检查、修复门禁失败项 | 决定是否发布、决定发布时机 | 审批发布决定 |
| **发布分支** | 生成 bugfix 代码、执行门禁检查、修复失败项 | 生成新功能/重构代码、修改 CI 脚本/规范、创建 tag | 审批 MR、创建 tag |
| **热修复** | 生成紧急 bugfix、执行热修复门禁、生成热修复说明 | 决定是否热修复、降级安全门禁 | 审批热修复决定、创建 tag |
| **发布后** | 收集度量数据、生成审计报告草稿、分析门禁效果 | 决定回滚、通知用户 | 决定回滚、通知用户 |

#### 17.6.2 Agent 发布工作流

```
Agent 接收发布任务
  │
  ├─ ① 发布准备阶段
  │   → 读取 VERSION_MANAGEMENT.md（版本号规范）
  │   → 读取 ROADMAP.md（确认版本对齐）
  │   → 生成 CHANGELOG 草稿（从 git log 提取）
  │   → 生成发布说明草稿
  │   → 执行发布门禁检查（R-01~R-12）
  │   → 门禁失败时自愈修复
  │   → 对照「发布分支 Agent 行为约束」自检
  │
  ├─ ② 发布分支阶段（release/v*）
  │   → 仅生成 bugfix 代码（禁止新功能/重构）
  │   → 每次提交触发发布门禁
  │   → 更新 CHANGELOG
  │   → 等待 Maintainer 审批 + 创建 tag
  │
  ├─ ③ 热修复阶段（如发生）
  │   → 读取热修复门禁清单
  │   → 仅生成紧急 bugfix
  │   → 生成精简发布说明
  │   → 等待 Maintainer 紧急审批
  │
  └─ ④ 发布后阶段
      → 收集度量数据（门禁通过率/发布周期/热修复次数）
      → 生成发布后审计报告草稿
      → 分析门禁效果，提出改进建议
```

### 17.7 发布治理与治理四层架构的映射

| 治理架构层 | 发布治理体现 |
|-----------|-------------|
| **Layer 1: 规范层** | `VERSION_MANAGEMENT.md` + `CI_CD_WORKFLOW.md` + `ROADMAP.md` + 本节发布门禁定义 |
| **Layer 2: 事前遵循层** | AGENTS.md 速查卡追加发布分支行为约束 + 发布门禁检查清单 |
| **Layer 3: 事后检查层** | 发布门禁 12 项（R-01~R-12）+ 热修复门禁子集 |
| **Layer 4: 自愈层** | 发布门禁失败时 Agent 自愈（复用 gatekeeper_reporter.py 报错格式） |

### 17.8 发布治理缺口与改进

| 编号 | 缺口 | 优先级 | 落地方案 |
|------|------|--------|----------|
| **RG-01** | 缺少 CHANGELOG 更新检查脚本 | P1 | 新建 `check-release-changelog.py`，检查 release 分支是否有 CHANGELOG 变更 |
| **RG-02** | 缺少 ROADMAP 版本对齐检查脚本 | P2 | 新建 `check-release-roadmap-align.py`，检查 semVer 是否在 ROADMAP 中 |
| **RG-03** | 缺少发布说明完整性检查脚本 | P1 | 新建 `check-release-notes.py`，检查功能列表/已知问题/迁移指南 |
| **RG-04** | 缺少性能基准发布门禁 | P2 | 新建 `check-release-performance.py`，对比性能基线 |
| **RG-05** | 缺少回滚预案检查 | P1 | 新建 `check-release-rollback-plan.py`，检查回滚步骤文档 |
| **RG-06** | AGENTS.md 未包含发布分支行为约束 | P0 | 在 AGENTS.md 速查卡追加发布分支行为约束表 |
| **RG-07** | 发布门禁未集成至 CI 流水线 | P1 | 修改 `.gitlab-ci.yml`，release/* 分支触发发布门禁 |
| **RG-08** | 热修复门禁未定义降级规则 | P1 | 在 CI 流水线中为 hotfix/* 分支配置降级门禁 |
| **RG-09** | 缺少发布后审计流程 | P2 | 新建 `Docs/Testing/POST_RELEASE_AUDIT_TEMPLATE.md` |
| **RG-10** | 缺少发布度量采集 | P2 | 在 CI 流水线中采集发布门禁通过率/发布周期数据 |

### 17.9 发布治理落地路线

| Phase | 任务 | 交付物 | 预期周期 |
|-------|------|--------|----------|
| **Phase 1** | AGENTS.md 追加发布分支行为约束 | 速查卡追加发布约束表 | 1 天 |
| **Phase 1** | 新建 R-10/R-12 检查脚本 | `check-release-changelog.py` + `check-release-notes.py` | 3 天 |
| **Phase 2** | 集成发布门禁至 CI 流水线 | 修改 `.gitlab-ci.yml`，release/* 触发 12 项门禁 | 1 周 |
| **Phase 2** | 定义热修复门禁降级规则 | 修改 CI 配置，hotfix/* 使用降级门禁 | 3 天 |
| **Phase 3** | 新建 R-11/R-14 检查脚本 | `check-release-roadmap-align.py` + `check-release-rollback-plan.py` | 1 周 |
| **Phase 3** | 新建发布后审计模板 | `POST_RELEASE_AUDIT_TEMPLATE.md` | 3 天 |
| **Phase 4** | 发布度量采集 + 仪表盘 | CI 采集发布度量数据 | 2 周 |

### 17.10 建议新建独立发布治理文档

> 本节是治理矩阵中的发布治理章节，建议后续将其独立为 `Docs/Architecture/RELEASE_GOVERNANCE.md`，原因：
>
> 1. 发布治理涉及版本管理、CI/CD、安全、性能、回滚等多个领域，独立文档更便于维护
> 2. `VERSION_MANAGEMENT.md` 侧重版本号机制，`CI_CD_WORKFLOW.md` 侧重流水线配置，发布治理是两者的上层编排
> 3. 独立文档可在 AGENTS.md 文档索引中登记，Agent 按需加载（渐进式披露）
>
> **落地步骤**：将本节内容提取为 `Docs/Architecture/RELEASE_GOVERNANCE.md`，在 AGENTS.md 文档索引中登记。

---

## 14. 修订记录

| 版本 | 日期 | 变更内容 | 作者 |
|------|------|----------|------|
| v1.0 | 2026-10-09 | 初始版本：建立 5 大规范领域治理矩阵，盘点 63 项已落地检查 + 20 项缺口，设计事前遵循五层机制（AGENTS.md 决策树 + 场景化加载 + 代码模板 + CI 映射 + 工作流嵌入）+ 事后检查增强，制定 4 阶段改进路线图 | CodeFree-O |
| v1.1 | 2026-10-09 | 追加第 8.8 节「渐进式披露机制」：三层架构（常驻上下文/按需摘要/精准全文），上下文消耗从 8691 行降至 ~424 行（减少 95%）；追加第 13 节「落地操作指南与 Demo 示例」：3 步落地操作 + 端到端 Demo（收藏功能 Service/View/Test 全流程）+ 落地验证清单 | CodeFree-O |
| v1.2 | 2026-10-09 | 追加「背景与动机」章节：痛点量化（5 项数据）、范式转变（事后拦截→事前遵循）、可量化目标（7 项指标）；追加「治理整体架构」章节：四层架构总览（规范层/事前遵循层/事后检查层/自愈层）、数据流、6 条设计原则、本文档与四层架构的映射表 | CodeFree-O |
| v1.3 | 2026-10-09 | 追加第 15 节「SDLC AI Native 演进展望」：四大演进支柱（流程编排/Agent 流程控制/安全机制/度量机制）、5 阶段演进路线图、与现有系统的关系映射、5 项关键设计决策 | CodeFree-O |
| v1.4 | 2026-10-09 | 追加第 16 节「治理实现机制与技术演进」：短期机制（Skill/Rule/Script/Asset）、中期演进（RAG 规范检索增强，复用 UFPStorage 向量基础设施）、长期演进（MCP 治理工具协议，5 类工具设计）、4 阶段技术演进路线图、开源选型参考 | CodeFree-O |
| v1.5 | 2026-10-09 | 追加第 17 节「发布治理」：发布门禁矩阵 12 项（R-01~R-12）、发布分支治理（生命周期/额外规则/Agent 行为约束）、热修复治理（流程/门禁降级规则/紧急通道）、发布后治理（检查清单/回滚机制/审计）、Agent 发布角色与工作流、10 项缺口与落地路线；独立文档 `RELEASE_GOVERNANCE.md` 已创建并在 AGENTS.md 文档索引登记 | CodeFree-O |

---

*相关文档：*
- *`LAYERING_L0_L3.md` — 架构分层规范*
- *`UI_COMPONENTS.md` — 界面组件规范*
- *`swift-coding-style.md` — Swift 编码风格*
- *`EXTERNAL_API_SPECIFICATION.md` — API 接口规范*
- *`TEST_CASE_STANDARDS.md` — 测试用例编写规范*
- *`development-standards.md` — 开发标准速查*
- *`CI_CD_WORKFLOW.md` — CI/CD 流水线规范*
- *`file-header-template.md` — 文件头注释模板*
