# 代码重复清理专项（C 系列）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 PMD-CPD 检测到的代码重复块从 393 处降到 ≤250 阈值以下，恢复 `make ios` Gatekeeper [14/22] 通过。

**Architecture:** 按投入产出比优先处理高频重复簇：簇 2（StoreCapabilities 协议样板，低风险）+ 簇 1（ModelManager 沙盒面板，最大收益）。重复集中在协议↔NoOp 双写、DependencyKey 模板、相似搜索/输入面板结构骨架。

**Tech Stack:** Swift 6、SwiftUI、GRDB、swift-dependencies。

## Global Constraints

- **测试质量红线**：语句覆盖率 ≥95%、分支覆盖率 ≥90%。
- **分层红线**：领域层不依赖 UI 框架；去重不得引入反向依赖。
- **去魔鬼化**：新常量走强类型枚举/DesignSystem token。
- **L10n 强约束**：新 UI 文案走 `L10n.模块.属性`。
- **行为等价**：去重是结构重构，严禁改变任何运行时行为。
- **验证**：`make test-spm-all` + `make ios` 全过；PMD-CPD 重复 ≤250。
- **无占位符**：每步产出可编译代码。

---

## 任务 1：StoreCapabilities 协议样板去重（簇 2，低风险）

**Files:**
- Modify: `Sources/Domain/Protocols/StoreCapabilities.swift`

**Interfaces:**
- Consumes: 无
- Produces: 消除 addLog 重复声明、DependencyKey 样板

- [ ] **Step 1: 让 AnyPageStore 继承 MonitorableStore，删除重复 addLog**

将 `StoreCapabilities.swift:38` 的 `public protocol AnyPageStore: Sendable {` 改为继承 `MonitorableStore`：

```swift
public protocol AnyPageStore: MonitorableStore, Sendable {
```

删除 `:191` 的 `func addLog(...)` 声明（与 `MonitorableStore` 重复）。其余协议方法保留。

- [ ] **Step 2: 验证编译**

```bash
make ios
```

预期：编译通过（AnyPageStore 实现者已提供 addLog，继承后无破坏）。

- [ ] **Step 3: 运行重复检测确认下降**

```bash
python3 Tools/ios/assert-code-duplication.py 2>&1 | tail -2
```

预期：重复块数较 393 下降（消除 addLog 声明重复）。

- [ ] **Step 4: Commit**

```bash
git add Sources/Domain/Protocols/StoreCapabilities.swift
git commit -m "refactor: AnyPageStore 继承 MonitorableStore 消除 addLog 重复声明"
```

---

## 任务 2：ModelManager 沙盒面板去重（簇 1，最大收益）

**Files:**
- Modify: `Sources/Features/System/ModelManager/View/Sections/InstantMediaSearchPanel.swift`
- Modify: `Sources/Features/System/ModelManager/View/Sections/VideoMomentSearchPanel.swift`
- Modify: `Sources/Features/System/ModelManager/View/Sections/ModelLabInputsPanel.swift`
- Modify: `Sources/Features/System/ModelManager/View/Sections/ModelLabMobileActionsPanel.swift`
- Modify: `Sources/Features/System/ModelManager/View/Sections/ModelBenchmarkPanel.swift`
- Create: `Sources/Features/System/ModelManager/View/Components/SearchPanelSection.swift`
- Create: `Sources/Features/System/ModelManager/View/Components/SampleChipBar.swift`
- Create: `Sources/Features/System/ModelManager/View/Components/LabSandboxContentContainer.swift`

**Interfaces:**
- Consumes: 任务 1
- Produces: 通用搜索面板/样例胶囊/沙盒容器组件，消除约 90 块重复

- [ ] **Step 1: 创建 SearchPanelSection 通用组件**

抽取 `InstantMediaSearch.swift:204-316` 与 `VideoMomentSearch.swift:287-349` 共有的搜索输入栏为 `SearchPanelSection`，参数化 accent 色、query 绑定、onSearch/onClear/onSend 回调、可选阈值 Slider。

- [ ] **Step 2: 创建 SampleChipBar 通用组件**

抽取 `InstantMediaSearch:187-192`、`ModelLabInputs:45-86/251-292`、`ModelLabMobileActions:87-94` 共有的样例胶囊栏 + 胶囊样式为 `SampleChipBar` + `CapsuleChipStyle` ViewModifier。

- [ ] **Step 3: 创建 LabSandboxContentContainer**

抽取 5 个面板共有的 `ScrollView + VStack + modelAndConfigControlBar` 骨架为容器，接收各 section 闭包。

- [ ] **Step 4: 替换 5 个面板使用通用组件**

将各面板的重复内联代码替换为通用组件调用，保持行为等价。

- [ ] **Step 5: 编译 + 快照回归**

```bash
make ios && make test-ui 2>/dev/null || make test
```

预期：编译通过，ModelManager 相关快照测试通过。

- [ ] **Step 6: 运行重复检测确认 <250**

```bash
python3 Tools/ios/assert-code-duplication.py 2>&1 | tail -2
```

预期：重复块 ≤250。

- [ ] **Step 7: Commit**

```bash
git add Sources/Features/System/ModelManager/
git commit -m "refactor: ModelManager 沙盒面板抽取通用组件消除重复"
```

---

## 验收标准（AC）

1. PMD-CPD 重复块 ≤250。
2. `make ios` Gatekeeper 22 项全过（含 [14/22] 代码重复率）。
3. `make test-spm-all` 全绿。
4. 行为等价：无任何运行时行为改变，测试覆盖去重代码。
5. 无新增去魔鬼化/L10n/分层违规。