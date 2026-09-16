# 重复代码全量清理设计

> **日期**：2026-09-13
> **状态**：已批准
> **范围**：Sources/ 目录下所有 Swift 源文件

## 1. 背景与目标

### 1.1 背景

CI 流水线 `static-analysis` 阶段的重复代码检测脚本 `assert-code-duplication.py` 存在缺陷：PMD-CPD 分支只打印结果不判定阈值，导致 3059 处重复代码块未阻断 CI。

修复脚本后（`--minimum-tokens 20` + `MAX_DUPLICATE_BLOCKS=0`），CI 正确阻断。现需全量清理 3059 处重复代码块，使 CI 通过。

### 1.2 目标

- **零容忍**：清理全部 3059 处重复代码块，`pmd cpd --minimum-tokens 20` 零重复
- **一次性全量清理**：不分阶段交付，一次性清理完毕后提交
- **CI 门禁保持**：`MAX_DUPLICATE_BLOCKS=0` + `--minimum-tokens 20` 零容忍策略

### 1.3 约束

- 遵守 L0-L3 严格分层架构
- 遵守 DesignSystem Token 强约束（无硬编码字号/边距/圆角）
- 遵守 L10n 强约束（无硬编码字符串）
- 遵守 SRP 文件拆分原则
- 平台差异不新增 `#if os()`，通过现有 PlatformProtocol 模式统一
- 抽取的 ViewModifier 不改变视觉行为（快照测试验证）
- GRDB 查询重构不改变 SQL 语义（Repository 单测验证）

## 2. 重复代码分类

3059 处重复块按模式分为 5 类：

| 类别 | 数量 | 典型模式 | 消除策略 |
|------|------|---------|---------|
| SwiftUI 修饰符链重复 | 1228 | `.padding` + `.background` + `.clipShape` 等链 | 抽取 `ViewModifier` / `View` extension |
| 业务逻辑重复 | 1462 | guard 校验、状态计算、相同方法体 | 抽取共享辅助函数/协议默认实现 |
| 平台差异重复 | 154 | iOS/watchOS/macOS 的 Capabilities/Registrar | 通过现有 PlatformProtocol 模式统一，共享逻辑下沉协议默认实现/`Platforms/Shared/`，不新增 `#if os()` |
| Shared/UIComponents 重复 | 150 | 同文件内 ViewModifier 条件分支重复 | 合并条件分支、抽取共享修饰符 |
| GRDB/SQL 查询重复 | 65 | `Row.fetchAll` + 手动解析 | 抽取 Repository 辅助方法/泛型查询 |

## 3. 抽取目标位置

| 类别 | 抽取产物 | 目标位置 | 理由 |
|------|---------|---------|------|
| GRDB/SQL | 泛型查询辅助方法 | `Sources/Infrastructure/Storage/Helpers/` | L1 基础设施层，Repository 同层复用 |
| 平台差异 | 协议默认实现扩展 | `Sources/Platforms/Shared/` | 已有跨平台共享目录，不新增 `#if os()` |
| UIComponents | 共享 ViewModifier | `Sources/Shared/UIComponents/Modifiers/` | 已有修饰符目录，直接扩展 |
| SwiftUI 修饰符链 | DesignSystem View extension | `Sources/Shared/DesignSystem/ViewModifiers/` | L3 共享层，全平台可引用 |
| 业务逻辑 | 按功能域辅助函数 | 各 `Features/<域>/Helpers/` 或协议默认实现 | 就近放置，不跨域依赖 |

## 4. 执行流程

一次性全量清理，按 5 类顺序执行，每类完成后验证编译：

```
阶段 1: GRDB/SQL 查询重复（65 处）
  └─ 抽取 Repository 辅助方法/泛型查询构造器
  └─ 验证: 3 端编译 + pmd cpd 复扫该类归零

阶段 2: 平台差异重复（154 处）
  └─ 共享逻辑下沉 PlatformProtocol 默认实现 / Platforms/Shared/
  └─ 验证: 3 端编译 + pmd cpd 复扫该类归零

阶段 3: Shared/UIComponents 重复（150 处）
  └─ 合并条件分支、抽取共享 ViewModifier
  └─ 验证: 3 端编译 + pmd cpd 复扫该类归零

阶段 4: SwiftUI 修饰符链重复（1228 处）
  └─ 抽取 ViewModifier / View extension 到 Shared/DesignSystem
  └─ 验证: 3 端编译 + pmd cpd 复扫该类归零

阶段 5: 业务逻辑重复（1462 处）
  └─ 抽取共享辅助函数/协议默认实现
  └─ 验证: 3 端编译 + pmd cpd 全量归零

最终验证: pre-push 全量门禁 + pmd cpd --minimum-tokens 20 零重复
```

**顺序理由**：先小后大——GRDB(65) 和平台(154) 数量少且模式清晰，先解决可以建立辅助基础设施；UIComponents(150) 为 SwiftUI 修饰符链(1228) 提供抽取目标；最后业务逻辑(1462) 数量最大但最分散，放最后。

## 5. 验证与门禁

### 5.1 每阶段验证

1. `pmd cpd --minimum-tokens 20 --language swift --dir Sources` — 该类重复块归零
2. 3 端编译：`make ios && make mac && make watch`
3. SwiftLint：`make lint`

### 5.2 最终验证

1. `python3 Tools/ios/assert-code-duplication.py` — 退出码 0（零重复）
2. `make test-unit` — 单元测试全通过
3. pre-push 全量门禁：18 通过 / 0 失败 / 1 跳过
4. `python3 Tools/CI/check-doc-drift.py --strict` — 文档漂移零

### 5.3 门禁保持

- `MAX_DUPLICATE_BLOCKS = 0`（零容忍）
- `--minimum-tokens 20`（保持当前灵敏度）
- CI 中 `assert-code-duplication.py` 已修复为解析 PMD 输出并按阈值阻断

### 5.4 风险控制

- 抽取 ViewModifier 时确保不改变视觉行为（快照测试验证）
- GRDB 查询重构时确保 SQL 语义不变（Repository 单测验证）
- 平台差异统一时确保 3 端行为一致（3 端编译 + 运行时验证）

## 6. 代表性样本

### 6.1 平台差异重复（154 处）

```
样本 1: 27行 78tokens
  Sources/Platforms/iOS/Registrar/iOSPlatformCapabilities.swift
  Sources/Platforms/watchOS/Services/WatchPlatformCapabilities.swift
  | var authenticationPolicy: LAPolicy { .deviceOwnerAuthenticationWithBiometrics }
  | func canEvaluatePolicy(context: LAContext) -> Bool {
```

### 6.2 SwiftUI 修饰符链重复（1228 处）

```
样本 1: 16行 137tokens
  Sources/Features/Insight/Dashboard/View/KnowledgePageListView.swift
  Sources/Features/Insight/Dashboard/View/TagCloudMainContent.swift
  | .padding(.horizontal, DesignSystem.standardPadding)
  | .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
  | .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius))
```

### 6.3 GRDB/SQL 查询重复（65 处）

```
样本 1: 15行 154tokens
  Sources/Infrastructure/Storage/Persistence/DatabaseSchemaMigrator.swift
  Sources/Infrastructure/Storage/Repositories/TagRepository.swift
  | let rows = try Row.fetchAll(db, sql: "SELECT ...")
  | for row in rows {
  |     let pageID: Data = row[KnowledgePage.Columns.id.rawValue]
```

### 6.4 业务逻辑重复（1462 处）

```
样本 1: 24行 120tokens
  Sources/Features/Knowledge/NotebookHub/View/Components/NotebookCard.swift
  Sources/Features/Knowledge/NotebookHub/View/Components/NotebookListRow.swift
  | private var defaultIcon: String {
  |     let index = abs(notebook.id.hashValue) % DesignSystem.Icons.Notebook.options.count
  |     return DesignSystem.Icons.Notebook.options[index]
```

### 6.5 Shared/UIComponents 重复（150 处）

```
样本 1: 13行 38tokens
  Sources/Shared/UIComponents/Modifiers/AppToolbarModifier.swift
  Sources/Shared/UIComponents/Modifiers/AppToolbarModifier.swift
  | ToolbarItem(placement: .topBarTrailing) {
  |     HStack(spacing: Spacing.atomic) {
```
