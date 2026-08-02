# 文件头注释模板规范

> **生效日期**：2026-06-22  
> **适用范围**：`Sources/` 下所有 `.swift` 文件  
> **审计依据**：全量代码审计发现 100 个 View 文件层级标注错误、11 个文件职责描述模板化

---

## 标准模板

```swift
//
//  <文件名>.swift
//  ZhiYu
//
//  Created by <作者> on <日期>.
//  Copyright © <年份> WangChong. All rights reserved.
//
//  系统层级：[<层级>] <层级名称>
//  核心职责：<一句话描述本文件的唯一核心职责>
//
```

## 层级与 SPM 物理包标注规范

| 层级 / SPM 包 | 标注 | 适用文件类型 | 典型物理路径 |
|------|------|-------------|---------|
| **UFPCore** | `系统层级：[UFPCore]` | 通用底座、DI 容器、系统 Logger、基础协议 | `Packages/UFPCore/` |
| **UFPStorage** | `系统层级：[UFPStorage]` | 通用 SQLite/GRDB 存储算子、DB 迁移脚本 | `Packages/UFPStorage/` |
| **UFPDesignSystem** | `系统层级：[UFPDesignSystem]` | 通用 UI Token (Spacing, Colors) 与 Bundle.module 资源 | `Packages/UFPDesignSystem/` |
| **ZhiYuDomain** | `系统层级：[ZhiYuDomain]` | 知识库领域大脑、`KnowledgePage` 模型、Memory 契约协议 | `Packages/ZhiYuDomain/` |
| **ZhiYuAICore** | `系统层级：[ZhiYuAICore]` | Prompt 沙箱、ContextReranker 降噪重排、Native/Swarm 适配器 | `Packages/ZhiYuAICore/` |
| **ZhiYuFeatures** | `系统层级：[ZhiYuFeaturesAI]` | 垂直业务功能界面 (Chat, Synthesis, Vault, Graph) | `Packages/ZhiYuFeatures/` |

### ⚠️ 关键区分规则

| 如果文件包含... | 标注为 |
|----------------|--------|
| `import SwiftUI` 且定义 `struct Xxx: View` | **`[L3]`** |
| `import SwiftUI` 但定义 `@Observable class XxxViewModel` | **`[L2]`** |
| `import Observation` 或无 UI 框架 import | **`[L2]`** 或更低 |
| `import Foundation` + 纯数据模型 (`struct`/`enum`) | **`[L1.5]`** (Domain) 或 **`[L1]`** (Infra) |

## 核心职责描述规范

### ✅ 正确示例

```swift
//  系统层级：[L3] 表现层
//  核心职责：AI 对话的气泡视图，支持用户/AI 消息的差异化渲染和引用展开。

//  系统层级：[L1.5] 领域层
//  核心职责：知识页面 (KnowledgePage) 的核心领域模型，包含标题、内容、元数据和关联图谱。

//  系统层级：[L2] 业务功能层
//  核心职责：Vault 模块的核心业务逻辑服务，管理多笔记本的创建、切换、删除与持久化。
```

### ❌ 错误示例

```swift
// ❌ View 文件标注为 L2
//  系统层级：[L2] 业务功能层  ← 错误！View 应为 [L3]

// ❌ 模板化复制粘贴
//  系统层级：[L1.5] 领域层
//  核心职责：核心领域模型定义（KnowledgePage、PageLink、PluginRecord 等）。  ← 太泛化！

// ❌ 描述与文件内容不符
//  系统层级：[L2] 业务功能层
//  核心职责：Model。提供智宇模块化垂直业务功能切片，
//          包括各功能域的界面 UI 视图定义...  ← 纯 Domain Model 文件不应描述 UI
```

## 函数/方法注释规范

```swift
/// 一句话描述函数职责
/// - Parameter paramName: 参数说明
/// - Returns: 返回值说明
/// - Throws: 可能抛出的错误
/// - Note: 补充说明（性能、副作用等）
public func doSomething(paramName: String) async throws -> Result {
    // 实现...
}

// MARK: - 分组标题（英文或中文，保持文件内一致）

/// 简短的描述
private func helperFunction() { ... }
```

### 要求

| 可见性 | 注释要求 |
|--------|---------|
| `public` / `open` | **必须**有 `///` 文档注释 |
| `internal` | **建议**有 `///` 文档注释 |
| `private` | **建议**有简要注释（非强制） |

## 枚举/结构体注释规范

```swift
/// 认证策略枚举
/// 定义应用支持的第三方登录方式
public enum AuthStrategy {
    /// Apple ID 登录
    case apple
    /// 微信登录
    case wechat
    /// GitHub OAuth 登录
    case github
}

/// 知识图谱节点数据结构
/// 表示图谱中的一个知识页面节点，包含位置、连接和元数据
public struct GraphNode: Identifiable, Codable {
    /// 唯一标识，对应 KnowledgePage.id
    public let id: UUID
    /// 在 3D 空间中的位置
    public var position: SIMD3<Float>
    /// 连接到此节点的其他节点 ID 列表
    public var connections: [UUID]
}
```

## 检查清单

在提交代码前，确认：

- [ ] 文件头注释包含正确的 `系统层级` 标注
- [ ] `核心职责` 描述是**本文件独有的**，非模板复制
- [ ] View 文件标注为 `[L3]`，非 View 的 UI 无关文件标注为 `[L2]`
- [ ] 所有 `public` 函数/属性有 `///` 文档注释
- [ ] 私有函数的关键流程有简要注释
- [ ] `// MARK: -` 用于逻辑分段

---

## 相关参考

- [`LAYERING_L0_L3.md`](../Architecture/LAYERING_L0_L3.md) — 严格分层架构定义
- [`ZhiYu_Codebase_Audit_2026-06-22.md`](../../Tools/Audit/ZhiYu_Codebase_Audit_2026-06-22.md) — 最新全量审计报告
