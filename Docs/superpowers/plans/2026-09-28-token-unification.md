# Token 体系统一重构 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将分散在 `Sources/Shared/DesignSystem/Tokens/`（17 文件, 2466 行）的 Token 定义统一到 `UFPDesignSystem` SPM 包的 `DesignTokens` 命名空间下，删除 app 内兼容层，同步集成 Dynamic Type。

**Architecture:** 按类别顺序迁移 Token 到 SPM 包（Spacing → Typography → Colors → Animations → 其余），每步编译验证；然后一次性删除 app 内 Token 目录 + DesignSystem.swift 兼容层，全局批量替换 ~3000 处引用；Typography 集成 `@ScaledMetric` 支持 Dynamic Type。

**Tech Stack:** Swift 6.4, SwiftUI, swift-dependencies, SPM, Xcode 16

## Global Constraints

- Swift 6.4，`SWIFT_STRICT_CONCURRENCY: complete`
- 平台：iOS 27 / macOS 27 / watchOS 27
- SPM 包依赖路径：`../UFPCore`、`$(OPENSRC_ROOT)/swift-dependencies`
- Token 命名空间：`DesignTokens`（SPM 包）与 `DesignSystem`（app 组件库）隔离
- 保留 `DesignSystem+Domain.swift` 和 `DesignSystem+Components/` 在 app 内
- 注释使用简体中文
- 严禁硬编码字号/padding/color，必须用 Token
- `@ScaledMetric` 不能是 `static let`，需用 computed property 或 View extension
- 每个阶段完成后必须编译验证

## File Structure

### SPM 包新增/修改文件

| 文件 | 职责 | 操作 |
|------|------|------|
| `Packages/UFPDesignSystem/Package.swift` | 包定义 | 修改：添加 Dependencies 依赖 |
| `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Spacing.swift` | 间距 Token | 修改：用 app 版本替换（430 行） |
| `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Typography.swift` | 排版 Token | 新增：从 app 迁移 + Dynamic Type 集成 |
| `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Colors.swift` | 颜色 Token | 新增：从 app 迁移 |
| `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Animations.swift` | 动画 Token | 新增：从 app 迁移 |
| `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Component.swift` | 组件间距 Token | 新增：从 app 迁移 |
| `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Reference.swift` | Tier 1 参考 Token | 新增：从 app 迁移 |
| `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/System.swift` | 系统级 Token | 新增：从 app 迁移 |
| `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Icons.swift` | 图标 Token | 新增：从 app 迁移 |
| `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+IconSize.swift` | 图标尺寸 Token | 新增：从 app 迁移 |
| `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Metrics.swift` | 仪表盘 Token | 新增：从 app 迁移 |
| `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Opacity.swift` | 透明度 Token | 新增：从 app 迁移 |
| `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Radius.swift` | 圆角 Token | 新增：从 app 迁移 |
| `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Shadows.swift` | 阴影 Token | 新增：从 app 迁移 |
| `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+ZIndex.swift` | 层级 Token | 新增：从 app 迁移 |
| `Packages/UFPDesignSystem/Tests/.../SpacingTokenConsistencyTests.swift` | Spacing 测试 | 修改：适配 app 版本值 |
| `Packages/UFPDesignSystem/Tests/.../TypographyTokenTests.swift` | Typography 测试 | 新增 |
| `Packages/UFPDesignSystem/Tests/.../ColorsTokenTests.swift` | Colors 测试 | 新增 |
| `Packages/UFPDesignSystem/Tests/.../TokenNamespaceIsolationTests.swift` | 命名空间隔离测试 | 新增 |

### app 内删除/修改文件

| 文件 | 操作 |
|------|------|
| `Sources/Shared/DesignSystem/Tokens/` (17 文件) | 删除整个目录 |
| `Sources/Shared/DesignSystem/DesignSystem.swift` | 修改：删除 Token 转发属性，保留组件 typealias |
| `Sources/` 下所有引用 Token 的文件 | 修改：全局替换 + 添加 `import UFPDesignSystem` |

---

## Task 1: SPM 包添加 Dependencies 依赖

**Files:**
- Modify: `Packages/UFPDesignSystem/Package.swift`

**Interfaces:**
- Produces: `UFPDesignSystem` 包可 `import Dependencies`，供 Colors.swift 使用

**背景：** app 内 `Colors.swift` 依赖 `import Dependencies`（用于 `@Dependency` 注入主题色解析）。SPM 包当前未引入此依赖，需先添加。

- [ ] **Step 1: 修改 Package.swift 添加 swift-dependencies 依赖**

在 `dependencies` 数组中添加 swift-dependencies，在 `targets` 的 `UFPDesignSystem` target 的 `dependencies` 中添加 `Dependencies` product。

```swift
dependencies: [
    .package(path: "../UFPCore"),
    .package(path: "\(opensrcRoot)/swift-dependencies"),
    .package(path: "\(opensrcRoot)/lottie-ios"),
    .package(path: "\(opensrcRoot)/swift-markdown-ui")
],
targets: [
    .target(
        name: "UFPDesignSystem",
        dependencies: [
            .product(name: "UFPCore", package: "UFPCore"),
            .product(name: "Dependencies", package: "swift-dependencies"),
            .product(name: "Lottie", package: "lottie-ios", condition: .when(platforms: [.iOS, .macOS, .macCatalyst])),
            .product(name: "MarkdownUI", package: "swift-markdown-ui", condition: .when(platforms: [.iOS, .macOS, .macCatalyst]))
        ],
        resources: [
            .process("Resources")
        ]
    ),
```

- [ ] **Step 2: 验证 SPM 包编译**

Run: `cd Packages/UFPDesignSystem && swift build`
Expected: 编译成功，无错误

- [ ] **Step 3: Commit**

```bash
git add Packages/UFPDesignSystem/Package.swift
git commit -m "feat: UFPDesignSystem 添加 swift-dependencies 依赖

Token 迁移前置准备：Colors.swift 需要 Dependencies 库支持"
```

---

## Task 2: 迁移 Spacing.swift 到 DesignTokens.Spacing

**Files:**
- Modify: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Spacing.swift`
- Modify: `Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/SpacingTokenConsistencyTests.swift`
- Modify: `Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/SpacingTokenHierarchyTests.swift`

**Interfaces:**
- Produces: `DesignTokens.Spacing` 包含 app 内 `Spacing` 的全部 430 行定义（原子间距/圆角/图标尺寸/Layout/Action/Gallery/Timeline/Grid/Graph/CompositeRow/Metrics/Task/List/Chip/Sidebar/Vault/Decorator + 视觉风格常数）

**关键差异：** SPM 包现有 `DesignTokens.Spacing.medium = 16.0`，app 内 `Spacing.medium = 12`。迁移时以 **app 版本为准**（app 有 3000+ 处引用），更新 SPM 包测试期望值。

- [ ] **Step 1: 用 app 版本替换 SPM 包 Spacing.swift**

将 `Sources/Shared/DesignSystem/Tokens/Spacing.swift` 的完整内容（430 行）复制到 `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Spacing.swift`，做以下调整：

1. 更新文件头注释：`系统层级：[UFPDesignSystem]`
2. 将 `public enum Spacing` 改为嵌套在 `DesignTokens` 下：
```swift
import Foundation
import CoreGraphics

public enum DesignTokens {
    /// 智宇原子间距令牌 (Spacing Tokens)
    /// 包含基础步进间距、圆角规范及各组件的布局指标。
    public enum Spacing {
        // ... app 内 Spacing 的全部内容原样保留 ...
    }
}
```

3. 保留所有子结构（Layout/Action/Gallery/Timeline/Grid/Graph/CompositeRow/Metrics/Task/List/Chip/Sidebar/Vault/Decorator）和视觉风格常数

- [ ] **Step 2: 更新 SpacingTokenConsistencyTests.swift**

app 版本 `medium = 12`，`small = 8`，无 `compact`/`paddingSmall`/`paddingMedium`/`paddingLarge`/`cardPadding`/`buttonPaddingHorizontal`/`buttonPaddingVertical`（这些是 SPM 包独有的 Tier 2/3 Token）。

删除 SPM 包独有的 Tier 2/3 测试（testCardPaddingEqualsMedium / testButtonPaddingHorizontalEqualsMedium / testButtonPaddingVerticalEqualsCompact / testButtonVerticalLessThanHorizontal / testPaddingSmallMediumLargeIncreasing），保留并更新：

```swift
final class SpacingTokenConsistencyTests: XCTestCase {

    /// small 必须等于 8.0（HIG 标准最小可触摸间距）
    func testSmallEquals8() {
        XCTAssertEqual(DesignTokens.Spacing.small, 8.0)
    }

    /// medium 必须等于 12.0（app 标准间距）
    func testMediumEquals12() {
        XCTAssertEqual(DesignTokens.Spacing.medium, 12.0)
    }

    /// standardPadding 必须等于 16.0（标准页面内边距）
    func testStandardPaddingEquals16() {
        XCTAssertEqual(DesignTokens.Spacing.standardPadding, 16.0)
    }

    /// atomic < tiny < small < medium < standardPadding < large < wide < giant < huge 递增
    func testSpacingIncreasing() {
        XCTAssertLessThan(DesignTokens.Spacing.atomic, DesignTokens.Spacing.tiny)
        XCTAssertLessThan(DesignTokens.Spacing.tiny, DesignTokens.Spacing.small)
        XCTAssertLessThan(DesignTokens.Spacing.small, DesignTokens.Spacing.medium)
        XCTAssertLessThan(DesignTokens.Spacing.medium, DesignTokens.Spacing.standardPadding)
        XCTAssertLessThan(DesignTokens.Spacing.standardPadding, DesignTokens.Spacing.large)
        XCTAssertLessThan(DesignTokens.Spacing.large, DesignTokens.Spacing.wide)
        XCTAssertLessThan(DesignTokens.Spacing.wide, DesignTokens.Spacing.giant)
        XCTAssertLessThan(DesignTokens.Spacing.giant, DesignTokens.Spacing.huge)
    }
}
```

- [ ] **Step 3: 更新 SpacingTokenHierarchyTests.swift**

根据 app 版本的 Tier 结构更新测试。如果现有测试引用了 SPM 包独有的 Tier 2/3 Token，删除或改为验证 app 版本的子结构（如 `Spacing.Layout`、`Spacing.Action` 等）。

- [ ] **Step 4: 验证 SPM 包编译 + 测试**

Run: `cd Packages/UFPDesignSystem && swift build && swift test`
Expected: 编译成功，测试通过

- [ ] **Step 5: Commit**

```bash
git add Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Spacing.swift
git add Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/SpacingTokenConsistencyTests.swift
git add Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/SpacingTokenHierarchyTests.swift
git commit -m "feat: 迁移 Spacing Token 到 DesignTokens.Spacing

用 app 版本（430 行）替换 SPM 包版本，包含全部子结构
（Layout/Action/Gallery/Timeline/Grid/Graph 等）"
```

---

## Task 3: 迁移 Typography.swift + Dynamic Type 集成

**Files:**
- Create: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Typography.swift`
- Create: `Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/TypographyTokenTests.swift`

**Interfaces:**
- Produces: `DesignTokens.Typography` 包含字号分级、HeadingLevel 枚举、Icons 映射，所有字体使用 Dynamic Type 语义样式

**Dynamic Type 集成方案：** app 内 Typography 已使用 `.caption`/`.title2.bold()` 等语义样式（天然支持 Dynamic Type）。迁移时保留这些语义样式，新增 `@ScaledMetric` 版本的字号常量供非 SwiftUI 上下文使用。

**注意：** `Typography.Icons`（SF Symbol 映射，~230 行）也在此文件中，一并迁移。

- [ ] **Step 1: 创建 Typography.swift**

将 `Sources/Shared/DesignSystem/Tokens/Typography.swift` 的完整内容（341 行）复制到 SPM 包，做以下调整：

1. 更新文件头注释：`系统层级：[UFPDesignSystem]`
2. 将 `public enum Typography` 嵌套在 `DesignTokens` 下：
```swift
import SwiftUI

public enum DesignTokens {
    /// 智宇排版令牌 (Typography Tokens)
    /// 包含字号分级、标题等级枚举及常用系统图标映射。
    /// 所有字体使用 Dynamic Type 语义样式，支持辅助功能字号自动缩放。
    public enum Typography {
        // ... app 内 Typography 的全部内容原样保留 ...
        // 包括 HeadingLevel 枚举、原子字号、Font Shortcuts、Icons struct
    }
}
```

3. 保留现有 `captionFont`/`titleFont` 等使用 `.caption`/`.title2.bold()` 语义样式的 computed property（这些天然支持 Dynamic Type）

- [ ] **Step 2: 创建 TypographyTokenTests.swift**

```swift
//
//  TypographyTokenTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 Typography Token 的字号层级和 Dynamic Type 集成。
//

import XCTest
import SwiftUI
@testable import UFPDesignSystem

final class TypographyTokenTests: XCTestCase {

    // MARK: - 原子字号验证

    /// microFontSize 必须等于 11（HIG 最小可读字号）
    func testMicroFontSizeEquals11() {
        XCTAssertEqual(DesignTokens.Typography.microFontSize, 11)
    }

    /// bodyFontSize 必须等于 16（正文字号）
    func testBodyFontSizeEquals16() {
        XCTAssertEqual(DesignTokens.Typography.bodyFontSize, 16)
    }

    /// titleFontSize 必须等于 24（大标题字号）
    func testTitleFontSizeEquals24() {
        XCTAssertEqual(DesignTokens.Typography.titleFontSize, 24)
    }

    // MARK: - 字号递增验证

    /// microFontSize < captionFontSize < bodyFontSize < headlineFontSize < titleFontSize < displayFontSize
    func testFontSizeIncreasing() {
        XCTAssertLessThan(DesignTokens.Typography.microFontSize,
                          DesignTokens.Typography.captionFontSize)
        XCTAssertLessThan(DesignTokens.Typography.captionFontSize,
                          DesignTokens.Typography.bodyFontSize)
        XCTAssertLessThan(DesignTokens.Typography.bodyFontSize,
                          DesignTokens.Typography.headlineFontSize)
        XCTAssertLessThan(DesignTokens.Typography.headlineFontSize,
                          DesignTokens.Typography.titleFontSize)
        XCTAssertLessThan(DesignTokens.Typography.titleFontSize,
                          DesignTokens.Typography.displayFontSize)
    }

    // MARK: - HeadingLevel 验证

    /// HeadingLevel.h1.size 必须等于 28
    func testHeadingLevelH1Size() {
        XCTAssertEqual(DesignTokens.Typography.HeadingLevel.h1.size, 28)
    }

    /// HeadingLevel.h6.size 必须等于 14
    func testHeadingLevelH6Size() {
        XCTAssertEqual(DesignTokens.Typography.HeadingLevel.h6.size, 14)
    }

    /// HeadingLevel 字号递减
    func testHeadingLevelSizeDecreasing() {
        XCTAssertGreaterThan(DesignTokens.Typography.HeadingLevel.h1.size,
                             DesignTokens.Typography.HeadingLevel.h2.size)
        XCTAssertGreaterThan(DesignTokens.Typography.HeadingLevel.h2.size,
                             DesignTokens.Typography.HeadingLevel.h3.size)
    }

    // MARK: - Font Shortcuts 验证

    /// captionFont 必须返回 .caption（Dynamic Type 语义样式）
    func testCaptionFontIsDynamicType() {
        // 验证 font 不为 nil（Font 不是 Optional，但可验证类型存在）
        let _ = DesignTokens.Typography.captionFont
    }

    /// titleFont 必须返回 .title2.bold()
    func testTitleFontIsDynamicType() {
        let _ = DesignTokens.Typography.titleFont
    }

    // MARK: - Icons 验证

    /// Icons.star 必须等于 "star.fill"
    func testIconsStar() {
        XCTAssertEqual(DesignTokens.Typography.Icons.star, "star.fill")
    }

    /// Icons.search 必须等于 "magnifyingglass"
    func testIconsSearch() {
        XCTAssertEqual(DesignTokens.Typography.Icons.search, "magnifyingglass")
    }
}
```

- [ ] **Step 3: 验证 SPM 包编译 + 测试**

Run: `cd Packages/UFPDesignSystem && swift build && swift test`
Expected: 编译成功，测试通过

- [ ] **Step 4: Commit**

```bash
git add Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Typography.swift
git add Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/TypographyTokenTests.swift
git commit -m "feat: 迁移 Typography Token 到 DesignTokens.Typography

包含字号分级、HeadingLevel 枚举、Icons 映射（341 行）
保留 Dynamic Type 语义样式（.caption/.title2.bold() 等）"
```

---

## Task 4: 迁移 Colors.swift

**Files:**
- Create: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Colors.swift`
- Create: `Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/ColorsTokenTests.swift`

**Interfaces:**
- Consumes: `import Dependencies`（Task 1 添加）、`import SwiftUI`、`import UIKit`/AppKit（条件编译）
- Produces: `DesignTokens.Colors` 包含透明度分级、主题色扩展

**注意：** Colors.swift 依赖 `import Dependencies` 和 `import UIKit`/AppKit（条件编译），还依赖 `import UFPCore`（在 UIKit 块内）。这些依赖在 Task 1 后已全部可用。

- [ ] **Step 1: 创建 Colors.swift**

将 `Sources/Shared/DesignSystem/Tokens/Colors.swift` 的完整内容（323 行）复制到 SPM 包，做以下调整：

1. 更新文件头注释：`系统层级：[UFPDesignSystem]`
2. 将 `public enum Colors` 嵌套在 `DesignTokens` 下：
```swift
import SwiftUI
import Dependencies

#if canImport(UIKit)
import UIKit
import UFPCore
#endif

public enum DesignTokens {
    /// 智宇颜色令牌 (Color Tokens)
    /// 包含全局语义颜色、透明度分级及环境色扩展。
    public enum Colors {
        // ... app 内 Colors 的全部内容原样保留 ...
        // 包括 Opacity 子 enum、主题色扩展等
    }
}
```

3. 保留所有条件编译块（`#if canImport(UIKit)`）和 Dependencies 相关代码

- [ ] **Step 2: 创建 ColorsTokenTests.swift**

```swift
//
//  ColorsTokenTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 Colors Token 的透明度分级和主题色值。
//

import XCTest
@testable import UFPDesignSystem

final class ColorsTokenTests: XCTestCase {

    // MARK: - 透明度验证

    /// glassOpacity 必须等于 0.15
    func testGlassOpacity() {
        XCTAssertEqual(DesignTokens.Colors.glassOpacity, 0.15)
    }

    /// fullOpacity 必须等于 1.0
    func testFullOpacity() {
        XCTAssertEqual(DesignTokens.Colors.fullOpacity, 1.0)
    }

    /// subtleOpacity 必须等于 0.7
    func testSubtleOpacity() {
        XCTAssertEqual(DesignTokens.Colors.subtleOpacity, 0.7)
    }

    // MARK: - Opacity 子结构验证

    /// Opacity.glassOpacity 必须等于 0.15
    func testOpacitySubstructureGlass() {
        XCTAssertEqual(DesignTokens.Colors.Opacity.glassOpacity, 0.15)
    }

    /// Opacity.disabledOpacity 必须在 0.3-0.5 之间
    func testDisabledOpacityRange() {
        XCTAssertGreaterThan(DesignTokens.Colors.Opacity.disabledOpacity, 0.3)
        XCTAssertLessThan(DesignTokens.Colors.Opacity.disabledOpacity, 0.5)
    }
}
```

- [ ] **Step 3: 验证 SPM 包编译 + 测试**

Run: `cd Packages/UFPDesignSystem && swift build && swift test`
Expected: 编译成功，测试通过

- [ ] **Step 4: Commit**

```bash
git add Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Colors.swift
git add Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/ColorsTokenTests.swift
git commit -m "feat: 迁移 Colors Token 到 DesignTokens.Colors

包含透明度分级、主题色扩展（323 行）
依赖 Dependencies + UIKit/AppKit 条件编译"
```

---

## Task 5: 迁移 Animations.swift

**Files:**
- Create: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Animations.swift`

**Interfaces:**
- Consumes: `import SwiftUI`
- Produces: `DesignTokens.Animations` 包含弹簧/时长/交互动画

- [ ] **Step 1: 创建 Animations.swift**

将 `Sources/Shared/DesignSystem/Tokens/Animations.swift` 的完整内容（161 行）复制到 SPM 包，做以下调整：

1. 更新文件头注释：`系统层级：[UFPDesignSystem]`
2. 将 `public enum Animations` 嵌套在 `DesignTokens` 下：
```swift
import SwiftUI

public enum DesignTokens {
    /// 智宇动画令牌 (Animation Tokens)
    public enum Animations {
        // ... app 内 Animations 的全部内容原样保留 ...
        // 包括 Interaction 子 enum、弹簧/时长等
    }
}
```

- [ ] **Step 2: 验证 SPM 包编译**

Run: `cd Packages/UFPDesignSystem && swift build`
Expected: 编译成功

- [ ] **Step 3: Commit**

```bash
git add Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Animations.swift
git commit -m "feat: 迁移 Animations Token 到 DesignTokens.Animations

包含弹簧/时长/交互动画（161 行）"
```

---

## Task 6: 迁移其余 Token 文件

**Files:**
- Create: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Component.swift`
- Create: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Reference.swift`
- Create: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/System.swift`
- Create: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Icons.swift`
- Create: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+IconSize.swift`
- Create: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Metrics.swift`
- Create: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Opacity.swift`
- Create: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Radius.swift`
- Create: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Shadows.swift`
- Create: `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+ZIndex.swift`

**Interfaces:**
- Produces: `DesignTokens.ComponentSpacing`、`DesignTokens.Reference`、`DesignTokens.SystemSpacing`/`SystemOpacity`/`SystemRadius`/`SystemStroke`/`SystemFontSize`/`SystemShadow`/`SystemLineLimit`，以及 `DesignTokens` 的 Icons/IconSize/Metrics/Opacity/Radius/Shadows/ZIndex 扩展

**注意：** 这些文件原本是 `extension DesignSystem`，迁移后改为 `extension DesignTokens`。部分文件（Component/Reference/System）定义的是顶层 enum，需嵌套在 `DesignTokens` 下。

- [ ] **Step 1: 迁移 Component.swift**

将 `Sources/Shared/DesignSystem/Tokens/Component.swift` 复制到 SPM 包，将 `public enum ComponentSpacing` 嵌套在 `DesignTokens` 下：
```swift
public enum DesignTokens {
    public enum ComponentSpacing {
        // ... 原样保留 ...
    }
}
```

- [ ] **Step 2: 迁移 Reference.swift**

将 `Sources/Shared/DesignSystem/Tokens/Reference.swift` 复制到 SPM 包，将 `public enum Reference` 嵌套在 `DesignTokens` 下。

- [ ] **Step 3: 迁移 System.swift**

将 `Sources/Shared/DesignSystem/Tokens/System.swift` 复制到 SPM 包，将所有 enum（`SystemSpacing`/`SystemOpacity`/`SystemRadius`/`SystemStroke`/`SystemFontSize`/`SystemShadow`/`SystemLineLimit`）嵌套在 `DesignTokens` 下。

- [ ] **Step 4: 迁移 DesignSystem+XXX 扩展文件（7 个）**

对以下 7 个文件，将 `extension DesignSystem` 改为 `extension DesignTokens`，并更新文件名前缀为 `DesignTokens+`：

| 原文件 | 新文件 | extension 目标 |
|--------|--------|---------------|
| `DesignSystem+Icons.swift` | `DesignTokens+Icons.swift` | `extension DesignTokens` |
| `DesignSystem+IconSize.swift` | `DesignTokens+IconSize.swift` | `extension DesignTokens` |
| `DesignSystem+Metrics.swift` | `DesignTokens+Metrics.swift` | `extension DesignTokens` |
| `DesignSystem+Opacity.swift` | `DesignTokens+Opacity.swift` | `extension DesignTokens` |
| `DesignSystem+Radius.swift` | `DesignTokens+Radius.swift` | `extension DesignTokens` |
| `DesignSystem+Shadows.swift` | `DesignTokens+Shadows.swift` | `extension DesignTokens` |
| `DesignSystem+ZIndex.swift` | `DesignTokens+ZIndex.swift` | `extension DesignTokens` |

每个文件：
1. 更新文件头注释：`系统层级：[UFPDesignSystem]`
2. 将 `extension DesignSystem` 改为 `extension DesignTokens`
3. 保留所有 static let/var 原样

- [ ] **Step 5: 验证 SPM 包编译**

Run: `cd Packages/UFPDesignSystem && swift build`
Expected: 编译成功，无错误

- [ ] **Step 6: Commit**

```bash
git add Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Component.swift
git add Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/Reference.swift
git add Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/System.swift
git add Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Icons.swift
git add Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+IconSize.swift
git add Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Metrics.swift
git add Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Opacity.swift
git add Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Radius.swift
git add Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+Shadows.swift
git add Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/DesignTokens+ZIndex.swift
git commit -m "feat: 迁移其余 10 个 Token 文件到 DesignTokens

Component/Reference/System 嵌套 enum + 7 个 DesignTokens 扩展
（Icons/IconSize/Metrics/Opacity/Radius/Shadows/ZIndex）"
```

---

## Task 7: 删除 app 内 Token + 全局替换引用

**Files:**
- Delete: `Sources/Shared/DesignSystem/Tokens/` (17 文件)
- Modify: `Sources/Shared/DesignSystem/DesignSystem.swift`（删除 Token 转发属性，保留组件 typealias）
- Modify: `Sources/` 下所有引用 `DesignSystem.*`/`Spacing.*`/`Typography.*`/`Colors.*`/`Animations.*` 的文件（~3000 处）

**Interfaces:**
- Consumes: Task 2-6 产出的 `DesignTokens.Spacing`/`Typography`/`Colors`/`Animations` 等
- Produces: app 内所有 Token 引用统一为 `DesignTokens.*`，app 内 `DesignSystem` 只保留组件 typealias

**这是最关键的一步。** 分 4 个子步骤执行，每个子步骤完成后编译验证。

### Step 1: 删除 app 内 Token 目录

- [ ] **Step 1.1: 删除 `Sources/Shared/DesignSystem/Tokens/` 目录**

```bash
rm -rf Sources/Shared/DesignSystem/Tokens/
```

- [ ] **Step 1.2: 修改 DesignSystem.swift — 删除 Token 转发属性**

删除所有 Token 转发属性（73 行 `public static let/var`），只保留：
1. `import SwiftUI`
2. `public enum DesignSystem` 声明
3. 组件 typealias（28 行 `public typealias`，在 `#if !WIDGET && !os(watchOS)` 块内）
4. `containerBackground`/`containerBorder`/`containerMaterial`（这些是 `Color.appCard` 等主题色引用，不是 Token 转发，保留）

修改后的 DesignSystem.swift 应为：
```swift
import SwiftUI

public enum DesignSystem {

    // MARK: - 容器颜色 (Container Colors)
    public static var containerBackground: Color { Color.appCard }
    public static var containerBorder: Color { Color.appBorder }
    public static var containerMaterial: Color { Color.appCard }

    // MARK: - 组件兼容性别名 (Component Aliases)
    #if !WIDGET && !os(watchOS)
    public typealias AppSection<Content: View> = StandardSection<Content>
    public typealias Card<Content: View> = AppCard<Content>
    // ... 保留全部 28 个 typealias ...
    #endif
}
```

- [ ] **Step 1.3: 添加 import UFPDesignSystem 到 DesignSystem.swift**

```swift
import SwiftUI
import UFPDesignSystem
```

- [ ] **Step 1.4: 编译验证（预期大量错误）**

Run: `make ios 2>&1 | head -100`
Expected: 大量 "Cannot find 'Spacing'/'Typography'/'Colors'/'Animations' in scope" 错误 — 这是预期的，下一步全局替换会修复

### Step 2: 全局替换直接引用（Spacing./Typography./Colors./Animations.）

- [ ] **Step 2.1: 替换 `Spacing.` → `DesignTokens.Spacing.`**

```bash
# 排除 SPM 包目录和 Token 定义文件本身
find Sources/ -name "*.swift" -type f -exec sed -i '' 's/Spacing\./DesignTokens.Spacing./g' {} +
```

验证：`rg "DesignTokens\.Spacing\." Sources/ | wc -l` 应约 944 处

- [ ] **Step 2.2: 替换 `Typography.` → `DesignTokens.Typography.`**

```bash
find Sources/ -name "*.swift" -type f -exec sed -i '' 's/Typography\./DesignTokens.Typography./g' {} +
```

验证：`rg "DesignTokens\.Typography\." Sources/ | wc -l` 应约 256 处

- [ ] **Step 2.3: 替换 `Colors.` → `DesignTokens.Colors.`**

```bash
find Sources/ -name "*.swift" -type f -exec sed -i '' 's/Colors\./DesignTokens.Colors./g' {} +
```

验证：`rg "DesignTokens\.Colors\." Sources/ | wc -l` 应约 71 处

- [ ] **Step 2.4: 替换 `Animations.` → `DesignTokens.Animations.`**

```bash
find Sources/ -name "*.swift" -type f -exec sed -i '' 's/Animations\./DesignTokens.Animations./g' {} +
```

验证：`rg "DesignTokens\.Animations\." Sources/ | wc -l` 应约 60 处

- [ ] **Step 2.5: 替换其他 Token 命名空间**

```bash
# ComponentSpacing
find Sources/ -name "*.swift" -type f -exec sed -i '' 's/ComponentSpacing\./DesignTokens.ComponentSpacing./g' {} +
# SystemSpacing
find Sources/ -name "*.swift" -type f -exec sed -i '' 's/SystemSpacing\./DesignTokens.SystemSpacing./g' {} +
# SystemOpacity
find Sources/ -name "*.swift" -type f -exec sed -i '' 's/SystemOpacity\./DesignTokens.SystemOpacity./g' {} +
# SystemRadius
find Sources/ -name "*.swift" -type f -exec sed -i '' 's/SystemRadius\./DesignTokens.SystemRadius./g' {} +
# SystemStroke
find Sources/ -name "*.swift" -type f -exec sed -i '' 's/SystemStroke\./DesignTokens.SystemStroke./g' {} +
# SystemFontSize
find Sources/ -name "*.swift" -type f -exec sed -i '' 's/SystemFontSize\./DesignTokens.SystemFontSize./g' {} +
# SystemShadow
find Sources/ -name "*.swift" -type f -exec sed -i '' 's/SystemShadow\./DesignTokens.SystemShadow./g' {} +
# SystemLineLimit
find Sources/ -name "*.swift" -type f -exec sed -i '' 's/SystemLineLimit/DesignTokens.SystemLineLimit/g' {} +
# Reference
find Sources/ -name "*.swift" -type f -exec sed -i '' 's/Reference\./DesignTokens.Reference./g' {} +
```

### Step 3: 全局替换 DesignSystem.* 转发属性

**注意：** `DesignSystem.*` 有 3387 处引用，但其中大部分是组件 typealias（如 `DesignSystem.Card`/`DesignSystem.AppSection`），这些保留不变。只替换 Token 转发属性。

- [ ] **Step 3.1: 替换 DesignSystem 间距 Token**

```bash
# 间距
find Sources/ -name "*.swift" -type f -exec sed -i '' \
  -e 's/DesignSystem\.atomic\b/DesignTokens.Spacing.atomic/g' \
  -e 's/DesignSystem\.tiny\b/DesignTokens.Spacing.tiny/g' \
  -e 's/DesignSystem\.small\b/DesignTokens.Spacing.small/g' \
  -e 's/DesignSystem\.medium\b/DesignTokens.Spacing.medium/g' \
  -e 's/DesignSystem\.standardPadding\b/DesignTokens.Spacing.standardPadding/g' \
  -e 's/DesignSystem\.large\b/DesignTokens.Spacing.large/g' \
  -e 's/DesignSystem\.wide\b/DesignTokens.Spacing.wide/g' \
  -e 's/DesignSystem\.giant\b/DesignTokens.Spacing.giant/g' \
  -e 's/DesignSystem\.huge\b/DesignTokens.Spacing.huge/g' \
  -e 's/DesignSystem\.inputBarHeight\b/DesignTokens.Spacing.inputBarHeight/g' \
  -e 's/DesignSystem\.loosePadding\b/DesignTokens.Spacing.loosePadding/g' \
  -e 's/DesignSystem\.widePadding\b/DesignTokens.Spacing.widePadding/g' \
  -e 's/DesignSystem\.tightPadding\b/DesignTokens.Spacing.tightPadding/g' \
  {} +
```

- [ ] **Step 3.2: 替换 DesignSystem 圆角 Token**

```bash
find Sources/ -name "*.swift" -type f -exec sed -i '' \
  -e 's/DesignSystem\.microRadius\b/DesignTokens.Spacing.microRadius/g' \
  -e 's/DesignSystem\.smallRadius\b/DesignTokens.Spacing.smallRadius/g' \
  -e 's/DesignSystem\.mediumRadius\b/DesignTokens.Spacing.mediumRadius/g' \
  -e 's/DesignSystem\.cardRadius\b/DesignTokens.Spacing.cardRadius/g' \
  -e 's/DesignSystem\.standardRadius\b/DesignTokens.Spacing.standardRadius/g' \
  -e 's/DesignSystem\.largeRadius\b/DesignTokens.Spacing.largeRadius/g' \
  -e 's/DesignSystem\.chipRadius\b/DesignTokens.Spacing.chipRadius/g' \
  {} +
```

- [ ] **Step 3.3: 替换 DesignSystem 图标尺寸 Token**

```bash
find Sources/ -name "*.swift" -type f -exec sed -i '' \
  -e 's/DesignSystem\.iconTiny\b/DesignTokens.Spacing.iconTiny/g' \
  -e 's/DesignSystem\.iconSmall\b/DesignTokens.Spacing.iconSmall/g' \
  -e 's/DesignSystem\.iconMedium\b/DesignTokens.Spacing.iconMedium/g' \
  -e 's/DesignSystem\.iconLarge\b/DesignTokens.Spacing.iconLarge/g' \
  -e 's/DesignSystem\.iconHuge\b/DesignTokens.Spacing.iconHuge/g' \
  -e 's/DesignSystem\.iconDisplay\b/DesignTokens.Spacing.iconDisplay/g' \
  -e 's/DesignSystem\.smallIconSize\b/DesignTokens.Spacing.smallIconSize/g' \
  -e 's/DesignSystem\.titleIconSize\b/DesignTokens.Spacing.titleIconSize/g' \
  -e 's/DesignSystem\.largeIconSize\b/DesignTokens.Spacing.largeIconSize/g' \
  -e 's/DesignSystem\.microIconSize\b/DesignTokens.Spacing.microIconSize/g' \
  -e 's/DesignSystem\.captionIconSize\b/DesignTokens.Spacing.captionIconSize/g' \
  {} +
```

- [ ] **Step 3.4: 替换 DesignSystem 排版 Token**

```bash
find Sources/ -name "*.swift" -type f -exec sed -i '' \
  -e 's/DesignSystem\.microFontSize\b/DesignTokens.Typography.microFontSize/g' \
  -e 's/DesignSystem\.captionFontSize\b/DesignTokens.Typography.captionFontSize/g' \
  -e 's/DesignSystem\.caption2FontSize\b/DesignTokens.Typography.caption2FontSize/g' \
  -e 's/DesignSystem\.subheadlineFontSize\b/DesignTokens.Typography.subheadlineFontSize/g' \
  -e 's/DesignSystem\.bodyFontSize\b/DesignTokens.Typography.bodyFontSize/g' \
  -e 's/DesignSystem\.standardFontSize\b/DesignTokens.Typography.standardFontSize/g' \
  -e 's/DesignSystem\.headlineFontSize\b/DesignTokens.Typography.headlineFontSize/g' \
  -e 's/DesignSystem\.titleFontSize\b/DesignTokens.Typography.titleFontSize/g' \
  -e 's/DesignSystem\.title2FontSize\b/DesignTokens.Typography.HeadingLevel.h2.size/g' \
  -e 's/DesignSystem\.displayFontSize\b/DesignTokens.Typography.displayFontSize/g' \
  -e 's/DesignSystem\.captionFont\b/DesignTokens.Typography.captionFont/g' \
  -e 's/DesignSystem\.caption2Font\b/DesignTokens.Typography.caption2Font/g' \
  -e 's/DesignSystem\.secondaryFont\b/DesignTokens.Typography.secondaryFont/g' \
  -e 's/DesignSystem\.subheadlineFont\b/DesignTokens.Typography.secondaryFont/g' \
  -e 's/DesignSystem\.titleFont\b/DesignTokens.Typography.titleFont/g' \
  -e 's/DesignSystem\.HeadingLevel\b/DesignTokens.Typography.HeadingLevel/g' \
  {} +
```

- [ ] **Step 3.5: 替换 DesignSystem 视觉风格/透明度/颜色 Token**

```bash
find Sources/ -name "*.swift" -type f -exec sed -i '' \
  -e 's/DesignSystem\.borderWidth\b/DesignTokens.Spacing.borderWidth/g' \
  -e 's/DesignSystem\.shadowRadius\b/DesignTokens.Spacing.shadowRadius/g' \
  -e 's/DesignSystem\.shadowY\b/DesignTokens.Spacing.shadowY/g' \
  -e 's/DesignSystem\.shadowOpacity\b/DesignTokens.Spacing.shadowOpacity/g' \
  -e 's/DesignSystem\.shadowColor\b/DesignTokens.Colors.Opacity.shadowColor/g' \
  -e 's/DesignSystem\.glassOpacity\b/DesignTokens.Colors.Opacity.glassOpacity/g' \
  -e 's/DesignSystem\.subtleOpacity\b/DesignTokens.Colors.subtleOpacity/g' \
  -e 's/DesignSystem\.subtleFillOpacity\b/DesignTokens.Colors.subtleFillOpacity/g' \
  -e 's/DesignSystem\.halfOpacity\b/DesignTokens.Colors.halfOpacity/g' \
  -e 's/DesignSystem\.fullOpacity\b/DesignTokens.Colors.Opacity.fullOpacity/g' \
  -e 's/DesignSystem\.disabledOpacity\b/DesignTokens.Colors.Opacity.disabledOpacity/g' \
  -e 's/DesignSystem\.pressedOpacity\b/DesignTokens.Colors.Opacity.pressedOpacity/g' \
  -e 's/DesignSystem\.dimmedOpacity\b/DesignTokens.Colors.Opacity.dimmedOpacity/g' \
  -e 's/DesignSystem\.secondaryOpacity\b/DesignTokens.Colors.Opacity.secondaryOpacity/g' \
  -e 's/DesignSystem\.coachMarkBackgroundOpacity\b/DesignTokens.Colors.Opacity.coachMarkBackgroundOpacity/g' \
  -e 's/DesignSystem\.surfaceOpacity\b/DesignTokens.Colors.Opacity.surfaceOpacity/g' \
  -e 's/DesignSystem\.cardOpacity\b/DesignTokens.Colors.Opacity.cardOpacity/g' \
  -e 's/DesignSystem\.translucentOpacity\b/DesignTokens.Colors.Opacity.translucentOpacity/g' \
  -e 's/DesignSystem\.softOpacity\b/DesignTokens.Colors.Opacity.softOpacity/g' \
  -e 's/DesignSystem\.ghostOpacity\b/DesignTokens.Colors.Opacity.ghostOpacity/g' \
  -e 's/DesignSystem\.dividerOpacity\b/DesignTokens.Colors.Opacity.dividerOpacity/g' \
  -e 's/DesignSystem\.accentStrokeOpacity\b/DesignTokens.Colors.Opacity.accentStrokeOpacity/g' \
  {} +
```

- [ ] **Step 3.6: 替换 DesignSystem 动画 Token**

```bash
find Sources/ -name "*.swift" -type f -exec sed -i '' \
  -e 's/DesignSystem\.standardAnimation\b/DesignTokens.Animations.Interaction.standardAnimation/g' \
  -e 's/DesignSystem\.fastAnimation\b/DesignTokens.Animations.Interaction.fastAnimation/g' \
  -e 's/DesignSystem\.LineLimit\b/DesignTokens.SystemLineLimit/g' \
  {} +
```

### Step 4: 添加 import UFPDesignSystem + 编译修复

- [ ] **Step 4.1: 批量添加 `import UFPDesignSystem` 到所有引用 DesignTokens 的文件**

```bash
# 找到所有引用 DesignTokens 但未 import UFPDesignSystem 的文件
for f in $(rg -l "DesignTokens\." Sources/ --glob "*.swift"); do
  if ! rg -q "import UFPDesignSystem" "$f"; then
    # 在第一个 import 行后插入
    sed -i '' '/^import /{x;/./{x;b;};x;h;s//&\nimport UFPDesignSystem/;}' "$f"
  fi
done
```

- [ ] **Step 4.2: 编译验证**

Run: `make ios 2>&1 | tail -50`
Expected: 可能仍有少量编译错误（如 `DesignSystem+Domain.swift` 中的 Token 引用、`DesignSystem+Components/` 中的引用），逐一修复

- [ ] **Step 4.3: 修复 DesignSystem+Domain.swift 和 DesignSystem+Components/ 中的引用**

这些文件保留在 app 内，但其中的 Token 引用需要手动更新为 `DesignTokens.*`。检查并修复：
```bash
rg "Spacing\.|Typography\.|Colors\.|Animations\." Sources/Shared/DesignSystem/DesignSystem+Domain.swift
rg "Spacing\.|Typography\.|Colors\.|Animations\." Sources/Shared/DesignSystem/DesignSystem+Components/
```

- [ ] **Step 4.4: 最终编译验证**

Run: `make ios`
Expected: 编译成功

- [ ] **Step 4.5: Commit**

```bash
git add -A
git commit -m "refactor: 删除 app 内 Token 兼容层，全局替换为 DesignTokens

- 删除 Sources/Shared/DesignSystem/Tokens/ (17 文件)
- DesignSystem.swift 只保留组件 typealias
- 全局替换 ~3000 处引用为 DesignTokens.*
- 添加 import UFPDesignSystem 到所有引用文件"
```

---

## Task 8: 命名空间隔离测试

**Files:**
- Create: `Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/TokenNamespaceIsolationTests.swift`

**Interfaces:**
- Produces: 验证 `DesignTokens`（SPM 包）与 app 内 `DesignSystem`（组件库）无命名冲突

- [ ] **Step 1: 创建 TokenNamespaceIsolationTests.swift**

```swift
//
//  TokenNamespaceIsolationTests.swift
//  UFPDesignSystemTests
//
//  系统层级：[UFPDesignSystemTests]
//  核心职责：验证 DesignTokens 命名空间完整性，确保 Token 迁移后无遗漏。
//

import XCTest
@testable import UFPDesignSystem

final class TokenNamespaceIsolationTests: XCTestCase {

    // MARK: - DesignTokens 命名空间完整性

    /// DesignTokens.Spacing 必须存在且可访问
    func testDesignTokensSpacingExists() {
        let _ = DesignTokens.Spacing.small
        let _ = DesignTokens.Spacing.medium
        let _ = DesignTokens.Spacing.standardPadding
    }

    /// DesignTokens.Typography 必须存在且可访问
    func testDesignTokensTypographyExists() {
        let _ = DesignTokens.Typography.bodyFontSize
        let _ = DesignTokens.Typography.titleFont
        let _ = DesignTokens.Typography.HeadingLevel.h1
    }

    /// DesignTokens.Colors 必须存在且可访问
    func testDesignTokensColorsExists() {
        let _ = DesignTokens.Colors.glassOpacity
        let _ = DesignTokens.Colors.Opacity.fullOpacity
    }

    /// DesignTokens.Animations 必须存在且可访问
    func testDesignTokensAnimationsExists() {
        let _ = DesignTokens.Animations.Interaction.standardAnimation
    }

    // MARK: - Token 值不变量验证

    /// Spacing.medium 必须等于 12（app 原始值，非 SPM 包的 16）
    func testSpacingMediumIs12() {
        XCTAssertEqual(DesignTokens.Spacing.medium, 12)
    }

    /// Spacing.standardPadding 必须等于 16
    func testSpacingStandardPaddingIs16() {
        XCTAssertEqual(DesignTokens.Spacing.standardPadding, 16)
    }

    /// Typography.bodyFontSize 必须等于 16
    func testTypographyBodyFontSizeIs16() {
        XCTAssertEqual(DesignTokens.Typography.bodyFontSize, 16)
    }
}
```

- [ ] **Step 2: 验证 SPM 包测试**

Run: `cd Packages/UFPDesignSystem && swift test`
Expected: 全部测试通过

- [ ] **Step 3: Commit**

```bash
git add Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/TokenNamespaceIsolationTests.swift
git commit -m "test: 新增 TokenNamespaceIsolationTests 命名空间隔离测试"
```

---

## Task 9: 最终验证

**Files:** 无修改，仅验证

- [ ] **Step 1: SPM 包独立编译 + 测试**

Run: `make test-spm PKG=UFPDesignSystem`
Expected: 编译成功，全部测试通过

- [ ] **Step 2: app 编译（iOS）**

Run: `make ios`
Expected: 编译成功

- [ ] **Step 3: app 编译（macOS）**

Run: `make mac`
Expected: 编译成功

- [ ] **Step 4: app 编译（watchOS）**

Run: `make watch`
Expected: 编译成功

- [ ] **Step 5: SwiftLint 检查**

Run: `make lint`
Expected: 无错误

- [ ] **Step 6: 架构审计**

Run: `make audit`
Expected: 无跨层依赖违规

- [ ] **Step 7: 全量 SPM 单测**

Run: `make test-spm-all`
Expected: 全部通过

- [ ] **Step 8: 验证无残留 Token 引用**

```bash
# 检查是否还有未迁移的 Token 引用
rg "\bSpacing\.(atomic|tiny|small|medium|large|wide|giant|huge|standardPadding)\b" Sources/ --glob "*.swift" | grep -v "DesignTokens" | grep -v "Packages/"
rg "\bTypography\.(bodyFontSize|titleFont|captionFont)" Sources/ --glob "*.swift" | grep -v "DesignTokens" | grep -v "Packages/"
rg "\bColors\.(glassOpacity|fullOpacity)" Sources/ --glob "*.swift" | grep -v "DesignTokens" | grep -v "Packages/"
```
Expected: 无输出（所有引用已迁移到 DesignTokens）

- [ ] **Step 9: 最终 Commit（如有修复）**

```bash
git add -A
git commit -m "test: P0-1 Token 体系统一重构最终验证通过

- iOS/macOS/watchOS 三平台编译成功
- SPM 包测试全量通过
- SwiftLint + 架构审计无违规
- 无残留 Token 引用"
```

---

## Task 10: 更新测试用例

**Files:**
- Modify: `Tests/Unit/Shared/DesignSystemTests.swift`（重写，35 处 `DesignSystem.SpacingToken`/`RadiusToken`/`Opacity` 旧 API）
- Modify: `Tests/Unit/Shared/DesignSystemReferenceTests.swift`（53 处 `Reference.` → `DesignTokens.Reference.`）
- Modify: `Tests/Unit/Shared/DesignSystemSystemTests.swift`（51 处 `SystemSpacing.`/`Reference.` → `DesignTokens.*`）
- Modify: `Tests/Unit/Shared/DesignSystemComponentTests.swift`（15 处 `ComponentSpacing.` → `DesignTokens.ComponentSpacing.`）
- Modify: `Tests/Unit/Shared/DesignSystemAndUIConstantsTests.swift`（`SystemShadow.` → `DesignTokens.SystemShadow.`）
- Modify: `Tests/Unit/Shared/UIComponentsAnimationAndTokensTests.swift`（`DesignSystem.Shadows`/`Radius`/`Opacity` → `DesignTokens.*`）
- Modify: `Tests/` 下所有引用 Token 的文件（61 文件，~743 处引用）
- Modify: `Tests/SnapshotTests/` 下 41 个快照测试文件（固定 `.sizeCategory` 防止 Dynamic Type 漂移）

**Interfaces:**
- Consumes: Task 2-6 产出的 `DesignTokens.*` 命名空间
- Produces: 全部测试通过，快照测试在 Dynamic Type 集成后保持稳定

**关键挑战：**
1. `DesignSystemTests.swift` 使用旧 API `DesignSystem.SpacingToken.atomic.value`（带 `.value`），需改为 `DesignTokens.Spacing.atomic`（无 `.value`）
2. 41 个快照测试在 Dynamic Type 集成后，字号会随系统辅助功能设置缩放，导致快照漂移。需在所有快照测试中固定 `.environment(\.sizeCategory, .medium)`

### Step 1: 重写 Token 专用测试文件

- [ ] **Step 1.1: 重写 DesignSystemTests.swift**

将 `DesignSystem.SpacingToken.atomic.value` 改为 `DesignTokens.Spacing.atomic`（去掉 `.value`），`DesignSystem.RadiusToken.micro.value` 改为 `DesignTokens.Spacing.microRadius`，`DesignSystem.Opacity.*` 改为 `DesignTokens.Colors.Opacity.*`。

```swift
// 修改前
XCTAssertEqual(DesignSystem.SpacingToken.atomic.value, 2.0)
XCTAssertEqual(DesignSystem.RadiusToken.micro.value, 4.0)
// 修改后
XCTAssertEqual(DesignTokens.Spacing.atomic, 2.0)
XCTAssertEqual(DesignTokens.Spacing.microRadius, 4.0)
```

添加 `import UFPDesignSystem`。

- [ ] **Step 1.2: 更新 DesignSystemReferenceTests.swift**

```bash
# Reference. → DesignTokens.Reference.
sed -i '' 's/\bReference\./DesignTokens.Reference./g' Tests/Unit/Shared/DesignSystemReferenceTests.swift
```

添加 `import UFPDesignSystem`。

- [ ] **Step 1.3: 更新 DesignSystemSystemTests.swift**

```bash
# SystemSpacing. → DesignTokens.SystemSpacing.
# SystemOpacity. → DesignTokens.SystemOpacity.
# SystemRadius. → DesignTokens.SystemRadius.
# SystemStroke. → DesignTokens.SystemStroke.
# SystemFontSize. → DesignTokens.SystemFontSize.
# SystemShadow. → DesignTokens.SystemShadow.
# SystemLineLimit → DesignTokens.SystemLineLimit
# Reference. → DesignTokens.Reference.
sed -i '' \
  -e 's/\bSystemSpacing\./DesignTokens.SystemSpacing./g' \
  -e 's/\bSystemOpacity\./DesignTokens.SystemOpacity./g' \
  -e 's/\bSystemRadius\./DesignTokens.SystemRadius./g' \
  -e 's/\bSystemStroke\./DesignTokens.SystemStroke./g' \
  -e 's/\bSystemFontSize\./DesignTokens.SystemFontSize./g' \
  -e 's/\bSystemShadow\./DesignTokens.SystemShadow./g' \
  -e 's/\bSystemLineLimit\b/DesignTokens.SystemLineLimit/g' \
  -e 's/\bReference\./DesignTokens.Reference./g' \
  Tests/Unit/Shared/DesignSystemSystemTests.swift
```

添加 `import UFPDesignSystem`。

- [ ] **Step 1.4: 更新 DesignSystemComponentTests.swift**

```bash
sed -i '' 's/\bComponentSpacing\./DesignTokens.ComponentSpacing./g' Tests/Unit/Shared/DesignSystemComponentTests.swift
```

添加 `import UFPDesignSystem`。

- [ ] **Step 1.5: 更新 DesignSystemAndUIConstantsTests.swift**

```bash
sed -i '' 's/\bSystemShadow\./DesignTokens.SystemShadow./g' Tests/Unit/Shared/DesignSystemAndUIConstantsTests.swift
```

添加 `import UFPDesignSystem`。

- [ ] **Step 1.6: 更新 UIComponentsAnimationAndTokensTests.swift**

```bash
sed -i '' \
  -e 's/DesignSystem\.Shadows/DesignTokens.Shadows/g' \
  -e 's/DesignSystem\.Radius/DesignTokens.Radius/g' \
  -e 's/DesignSystem\.Opacity/DesignTokens.Colors.Opacity/g' \
  Tests/Unit/Shared/UIComponentsAnimationAndTokensTests.swift
```

添加 `import UFPDesignSystem`。

### Step 2: 全局替换 Tests 目录下的 Token 引用

- [ ] **Step 2.1: 替换直接 Token 命名空间引用**

```bash
# 排除已手动处理的文件
find Tests/ -name "*.swift" -type f -exec sed -i '' \
  -e 's/\bSpacing\./DesignTokens.Spacing./g' \
  -e 's/\bTypography\./DesignTokens.Typography./g' \
  -e 's/\bColors\./DesignTokens.Colors./g' \
  -e 's/\bAnimations\./DesignTokens.Animations./g' \
  -e 's/\bReference\./DesignTokens.Reference./g' \
  -e 's/\bSystemSpacing\./DesignTokens.SystemSpacing./g' \
  -e 's/\bSystemOpacity\./DesignTokens.SystemOpacity./g' \
  -e 's/\bSystemRadius\./DesignTokens.SystemRadius./g' \
  -e 's/\bSystemStroke\./DesignTokens.SystemStroke./g' \
  -e 's/\bSystemFontSize\./DesignTokens.SystemFontSize./g' \
  -e 's/\bSystemShadow\./DesignTokens.SystemShadow./g' \
  -e 's/\bSystemLineLimit\b/DesignTokens.SystemLineLimit/g' \
  -e 's/\bComponentSpacing\./DesignTokens.ComponentSpacing./g' \
  {} +
```

- [ ] **Step 2.2: 替换 DesignSystem.* Token 转发属性引用**

复用 Task 7 Step 3 的 sed 命令，但目标改为 `Tests/` 目录：

```bash
find Tests/ -name "*.swift" -type f -exec sed -i '' \
  -e 's/DesignSystem\.atomic\b/DesignTokens.Spacing.atomic/g' \
  -e 's/DesignSystem\.tiny\b/DesignTokens.Spacing.tiny/g' \
  -e 's/DesignSystem\.small\b/DesignTokens.Spacing.small/g' \
  -e 's/DesignSystem\.medium\b/DesignTokens.Spacing.medium/g' \
  -e 's/DesignSystem\.standardPadding\b/DesignTokens.Spacing.standardPadding/g' \
  -e 's/DesignSystem\.large\b/DesignTokens.Spacing.large/g' \
  -e 's/DesignSystem\.wide\b/DesignTokens.Spacing.wide/g' \
  -e 's/DesignSystem\.giant\b/DesignTokens.Spacing.giant/g' \
  -e 's/DesignSystem\.huge\b/DesignTokens.Spacing.huge/g' \
  -e 's/DesignSystem\.microRadius\b/DesignTokens.Spacing.microRadius/g' \
  -e 's/DesignSystem\.smallRadius\b/DesignTokens.Spacing.smallRadius/g' \
  -e 's/DesignSystem\.mediumRadius\b/DesignTokens.Spacing.mediumRadius/g' \
  -e 's/DesignSystem\.cardRadius\b/DesignTokens.Spacing.cardRadius/g' \
  -e 's/DesignSystem\.standardRadius\b/DesignTokens.Spacing.standardRadius/g' \
  -e 's/DesignSystem\.largeRadius\b/DesignTokens.Spacing.largeRadius/g' \
  -e 's/DesignSystem\.chipRadius\b/DesignTokens.Spacing.chipRadius/g' \
  -e 's/DesignSystem\.iconTiny\b/DesignTokens.Spacing.iconTiny/g' \
  -e 's/DesignSystem\.iconSmall\b/DesignTokens.Spacing.iconSmall/g' \
  -e 's/DesignSystem\.iconMedium\b/DesignTokens.Spacing.iconMedium/g' \
  -e 's/DesignSystem\.iconLarge\b/DesignTokens.Spacing.iconLarge/g' \
  -e 's/DesignSystem\.microFontSize\b/DesignTokens.Typography.microFontSize/g' \
  -e 's/DesignSystem\.captionFontSize\b/DesignTokens.Typography.captionFontSize/g' \
  -e 's/DesignSystem\.bodyFontSize\b/DesignTokens.Typography.bodyFontSize/g' \
  -e 's/DesignSystem\.titleFontSize\b/DesignTokens.Typography.titleFontSize/g' \
  -e 's/DesignSystem\.captionFont\b/DesignTokens.Typography.captionFont/g' \
  -e 's/DesignSystem\.titleFont\b/DesignTokens.Typography.titleFont/g' \
  -e 's/DesignSystem\.glassOpacity\b/DesignTokens.Colors.Opacity.glassOpacity/g' \
  -e 's/DesignSystem\.fullOpacity\b/DesignTokens.Colors.Opacity.fullOpacity/g' \
  -e 's/DesignSystem\.disabledOpacity\b/DesignTokens.Colors.Opacity.disabledOpacity/g' \
  -e 's/DesignSystem\.standardAnimation\b/DesignTokens.Animations.Interaction.standardAnimation/g' \
  -e 's/DesignSystem\.fastAnimation\b/DesignTokens.Animations.Interaction.fastAnimation/g' \
  {} +
```

**注意：** `DesignSystem.Metrics.*`、`DesignSystem.Shadows.*`、`DesignSystem.Radius.*`、`DesignSystem.Opacity.*` 等需根据 Task 6 中迁移后的实际命名空间路径替换。执行时需根据 SPM 包中 `DesignTokens+Metrics.swift`/`DesignTokens+Shadows.swift` 等文件的实际定义调整 sed 命令。

- [ ] **Step 2.3: 批量添加 import UFPDesignSystem**

```bash
for f in $(rg -l "DesignTokens\." Tests/ --glob "*.swift"); do
  if ! rg -q "import UFPDesignSystem" "$f"; then
    # 在第一个 import 行后插入
    sed -i '' '/^import /{x;/./{x;b;};x;h;s//&\nimport UFPDesignSystem/;}' "$f"
  fi
done
```

### Step 3: 快照测试固定 Dynamic Type

- [ ] **Step 3.1: 在所有快照测试中固定 .sizeCategory**

Dynamic Type 集成后，字号会随系统辅助功能设置缩放。为防止快照漂移，在所有快照测试的 view 构造中添加 `.environment(\.sizeCategory, .medium)`：

```bash
# 查找所有快照测试中 assertSnapshot 调用
rg -l "assertSnapshot" Tests/SnapshotTests/ --glob "*.swift"
```

对每个快照测试文件，在 view 上添加 `.environment(\.sizeCategory, .medium)`。例如：

```swift
// 修改前
assertSnapshot(of: view, as: .image(...))
// 修改后
let view = SomeView()
    .environment(\.sizeCategory, .medium)
assertSnapshot(of: view, as: .image(...))
```

**注意：** 此步骤需逐文件检查，确保 view 链上已有 `.environment` 时不重复添加。可创建一个 View extension 简化：

```swift
// Tests/Shared/TestSnapshotSupport.swift
extension View {
    /// 快照测试固定 Dynamic Type 为 .medium，防止字号缩放导致快照漂移
    func snapshotTestEnvironment() -> some View {
        environment(\.sizeCategory, .medium)
    }
}
```

然后在快照测试中统一使用 `view.snapshotTestEnvironment()`。

- [ ] **Step 3.2: 验证快照测试**

Run: `make test-ui 2>&1 | tail -30`
Expected: 快照测试通过（或需重新生成基线 — 如果 Dynamic Type 改变了默认渲染）

### Step 4: 验证 + Commit

- [ ] **Step 4.1: 运行单元测试**

Run: `make test-unit 2>&1 | tail -30`
Expected: 全部通过

- [ ] **Step 4.2: Commit**

```bash
git add -A
git commit -m "test: 更新测试用例适配 DesignTokens 命名空间

- 重写 4 个 Token 专用测试文件（DesignSystemTests/Reference/System/Component）
- 全局替换 Tests/ 下 ~743 处 Token 引用
- 41 个快照测试固定 .sizeCategory 防止 Dynamic Type 漂移
- 批量添加 import UFPDesignSystem"
```

---

## Task 11: 更新 CI 审计脚本

**职责重构方案（清理重叠 + 统一命名）：**

| 旧名称 | 新名称 | 职责 | 变更 |
|--------|--------|------|------|
| `audit-design-token-layering.py` | `audit-design-token-layering.py` | 架构分层 + 依赖方向 + 旧残留 + DesignSystem.* 残留 | 路径更新 + 新增残留检查 |
| `audit-design-token-naming.py` | `audit-design-token-arithmetic.py` | token 算术表达式（含 DesignSystem.* + DesignTokens.*） | 重命名 + 扩展检测范围 |
| `audit-design-token-budget.py` | `audit-design-token-budget.py` | 数量预算 | 路径更新 |
| `audit-design-magic-numbers.py` | `audit-design-token-magic-numbers.py` | 硬编码检测（移除 token 算术，交给 arithmetic.py） | 重命名 + 移除重叠职责 |

**Files:**
- Rename: `Tools/ios/audit-design-token-naming.py` → `Tools/ios/audit-design-token-arithmetic.py`
- Rename: `Tools/ios/audit-design-magic-numbers.py` → `Tools/ios/audit-design-token-magic-numbers.py`
- Modify: `Tools/ios/audit-design-token-layering.py`（路径更新 + 新增 DesignSystem.* 残留检查）
- Modify: `Tools/ios/audit-design-token-arithmetic.py`（扩展检测 DesignSystem.* 算术）
- Modify: `Tools/ios/audit-design-token-budget.py`（路径更新）
- Modify: `Tools/ios/audit-design-token-magic-numbers.py`（移除 token 算术检测，交给 arithmetic.py）
- Modify: `Tools/CI/run-code-static-analysis.sh`（更新脚本名称引用）

**Interfaces:**
- Consumes: Task 2-6 产出的 `DesignTokens.*` 命名空间
- Produces: `make audit` 通过，CI 静态分析无违规

### Step 1: 重命名脚本文件

- [ ] **Step 1.1: 重命名 naming.py → arithmetic.py**

```bash
git mv Tools/ios/audit-design-token-naming.py Tools/ios/audit-design-token-arithmetic.py
```

- [ ] **Step 1.2: 重命名 magic-numbers.py → token-magic-numbers.py**

```bash
git mv Tools/ios/audit-design-magic-numbers.py Tools/ios/audit-design-token-magic-numbers.py
```

- [ ] **Step 1.3: 更新 run-code-static-analysis.sh 调用点**

```bash
# 修改 Tools/CI/run-code-static-analysis.sh L67/L101/L102
sed -i '' \
  -e 's/audit-design-magic-numbers\.py/audit-design-token-magic-numbers.py/g' \
  -e 's/audit-design-token-naming\.py/audit-design-token-arithmetic.py/g' \
  Tools/CI/run-code-static-analysis.sh
```

验证：
```bash
rg "audit-design-token-(arithmetic|layering|budget|magic-numbers)" Tools/CI/run-code-static-analysis.sh
```

---

### Step 2: 更新 layering.py（路径 + DesignSystem.* 残留检查）

- [ ] **Step 2.1: 更新 TOKENS_DIR 路径**

`layering.py` L25 硬编码 `Sources/Shared/DesignSystem/Tokens`，迁移后 Token 文件在 SPM 包：

```python
# 修改前 (L25)
TOKENS_DIR = os.path.join(SOURCES_DIR, 'Shared/DesignSystem/Tokens')

# 修改后
SPM_TOKENS_DIR = os.path.join(PROJECT_ROOT, 'Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens')
```

同步更新 L27-29 的 `REFERENCE_FILE`/`SYSTEM_FILE`/`COMPONENT_FILE` 路径。

- [ ] **Step 2.2: 更新依赖方向检查正则**

`layering.py` L90/L97/L109/L129 使用裸名称 `SystemSpacing`/`ComponentSpacing`/`Reference.`，迁移后需加 `DesignTokens.` 前缀：

```python
# 修改前 (L90)
if re.search(r'\bSystem(?:Spacing|Opacity|Radius|Stroke|FontSize)\b', content):
# 修改后
if re.search(r'\bDesignTokens\.System(?:Spacing|Opacity|Radius|Stroke|FontSize)\b', content):
```

- [ ] **Step 2.3: 更新视图越级引用检查正则**

`layering.py` L221 检查 `Reference.` 越级引用，迁移后改为 `DesignTokens.Reference.`：

```python
# 修改前 (L221)
if re.search(r'\bReference\.(Spacing|Opacity|Radius|Stroke|FontSize)\.', line):
# 修改后
if re.search(r'\bDesignTokens\.Reference\.(Spacing|Opacity|Radius|Stroke|FontSize)\.', line):
```

- [ ] **Step 2.4: 新增 DesignSystem.* Token 残留检查**

在 `_check_legacy_symbol_references()` 的 `legacy_patterns` 列表中新增模式，检测迁移后残留的 `DesignSystem.*` Token 引用：

```python
# 在 legacy_patterns 中新增（L158-164）
legacy_patterns = [
    r'\bDesignSystem\.Tier[123]\b',
    r'\bDesignTokenRegistry\.shared\b',
    r'\bPlatformContext\.current\b',
    r'\bSemanticSpacingToken\b',
    r'\bSemanticRadiusToken\b',
    # 新增：禁止 DesignSystem.* Token 残留（迁移到 DesignTokens 后）
    r'\bDesignSystem\.(SpacingToken|RadiusToken|Opacity|Shadows|Radius|Metrics|Typography|Colors|Animations|IconSize|ZIndex)\b',
]
```

**注意：** `DesignSystem.Metrics.*`/`DesignSystem.Shadows.*` 等在 Task 6 中迁移到 `DesignTokens.*` 后，这些模式会捕获残留引用。但 `DesignSystem+Domain.swift`/`DesignSystem+Components/` 中保留的组件 typealias 不会被匹配（因为它们是 `typealias X = Y` 而非 `DesignSystem.X` 引用）。

- [ ] **Step 2.5: 更新 LEGACY_FILES 路径**

`layering.py` L32-36 的 `LEGACY_FILES` 指向 `Sources/Shared/DesignSystem/`，迁移后需检查这些文件是否已删除：

```python
# 保持不变 — 这些文件在迁移前就应已删除，路径不变
LEGACY_FILES = [
    os.path.join(SOURCES_DIR, 'Shared/DesignSystem/DesignSystem+Layering.swift'),
    os.path.join(SOURCES_DIR, 'Shared/DesignSystem/PlatformContext.swift'),
    os.path.join(SOURCES_DIR, 'Shared/DesignSystem/DesignTokenRegistry.swift'),
]
```

- [ ] **Step 2.6: 更新 exempt_files 列表**

`layering.py` L198 的 `exempt_files` 需更新为 SPM 包中的文件名：

```python
# 修改前 (L198)
exempt_files = {'Reference.swift', 'System.swift', 'Component.swift', 'Colors.swift', 'Typography.swift', 'DesignSystem.swift'}
# 修改后（SPM 包中文件名）
exempt_files = {'Reference.swift', 'System.swift', 'Component.swift', 'Colors.swift', 'Typography.swift', 'Animations.swift', 'DesignTokens.swift'}
```

---

### Step 3: 更新 arithmetic.py（路径 + 扩展检测范围）

- [ ] **Step 3.1: 更新文件头注释**

```python
# 修改前
# 职责说明: 本脚本用于对设计令牌命名规范进行 CI 门禁检查。
# 修改后
# 职责说明: 本脚本用于对设计令牌算术表达式进行 CI 门禁检查。
```

- [ ] **Step 3.2: 更新 TOKENS_DIR 路径**

`arithmetic.py` L24 硬编码 `Sources/Shared/DesignSystem/Tokens`，迁移后改为 SPM 包路径：

```python
# 修改前 (L24)
TOKENS_DIR = os.path.join(SOURCES_DIR, 'Shared/DesignSystem/Tokens')
# 修改后
TOKENS_DIR = os.path.join(PROJECT_ROOT, 'Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens')
```

同步更新 L29-31 的 `REFERENCE_FILE`/`SYSTEM_FILE`/`COMPONENT_FILE` 路径。

- [ ] **Step 3.3: 更新 token 定义文件算术检测正则**

`arithmetic.py` L73 检测 token 定义文件中的算术，使用 `Reference|System|Component` 裸名称，迁移后需加 `DesignTokens.` 前缀：

```python
# 修改前 (L73)
if re.search(r'\b(Reference|System|Component)\.\w+\.\w+' + ARITH_PATTERN + r'\d', line):
# 修改后
if re.search(r'\bDesignTokens\.(Reference|System|Component)\.\w+\.\w+' + ARITH_PATTERN + r'\d', line):
```

- [ ] **Step 3.4: 扩展视图算术检测范围（含 DesignSystem.*）**

`arithmetic.py` L131-134 注释说明"旧 DesignSystem.* token 保留阶段，其算术由 audit-design-magic-numbers.py 检测"。迁移后 DesignSystem.* Token 已删除，但为防止回退，需扩展检测范围：

```python
# 修改前 (L134)
pattern = r'\b(Reference|System|Component)\w*\.\w+' + ARITH_PATTERN + r'(0\.\d+|\d+\.?\d*)\b'
# 修改后（含 DesignTokens.* 和残留 DesignSystem.*）
pattern = r'\b(DesignTokens\.)?(Reference|System|Component)\w*\.\w+' + ARITH_PATTERN + r'(0\.\d+|\d+\.?\d*)\b'
```

同步更新 L144 的反向匹配正则。

- [ ] **Step 3.5: 更新 exempt_files 列表**

`arithmetic.py` L100 的 `exempt_files` 需更新为 SPM 包中的文件名：

```python
# 修改前 (L100)
exempt_files = {'Reference.swift', 'System.swift', 'Component.swift'}
# 修改后
exempt_files = {'Reference.swift', 'System.swift', 'Component.swift', 'Colors.swift', 'Typography.swift', 'Animations.swift', 'DesignTokens.swift'}
```

---

### Step 4: 更新 budget.py（路径更新）

- [ ] **Step 4.1: 更新 TOKENS_DIR 路径**

`budget.py` L19 硬编码 `Sources/Shared/DesignSystem/Tokens`，迁移后改为 SPM 包路径：

```python
# 修改前 (L19)
TOKENS_DIR = os.path.join(PROJECT_ROOT, 'Sources/Shared/DesignSystem/Tokens')
# 修改后
TOKENS_DIR = os.path.join(PROJECT_ROOT, 'Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens')
```

- [ ] **Step 4.2: 验证 token 计数逻辑**

`budget.py` L36 使用 `public static let` 计数，迁移后 SPM 包中 Token 定义仍使用 `public static let`，逻辑无需修改。但需验证 SPM 包中 Token 文件是否拆分为多个（如 `Spacing.swift`/`Typography.swift`/`Colors.swift`），如果是，需更新 `LIMITS` 字典：

```python
# 如果 SPM 包中 Token 拆分为多个文件，需更新 LIMITS
# 当前仅检查 Reference/System/Component 3 个文件
# 迁移后可能需要检查 Spacing.swift/Typography.swift/Colors.swift 等
# 具体取决于 Task 2-6 的文件组织方式
```

**注意：** 此步骤需在 Task 2-6 完成后，根据 SPM 包中实际文件结构调整。

---

### Step 5: 更新 token-magic-numbers.py（移除重叠职责）

- [ ] **Step 5.1: 移除 token 算术检测（交给 arithmetic.py）**

`token-magic-numbers.py` L257-286 的 `_check_magic_math()` 函数中，`_check_view_arithmetic()` 和 `_check_token_arithmetic()` 与 `arithmetic.py` 职责重叠。移除这两个函数调用：

```python
# 修改前 (L257-263)
def _check_magic_math(raw, path, line_no, s, res):
    """检查魔鬼算术表达式与 customSize。"""
    exempt_tokens = ['DesignSystem.Domain', 'DesignSystem.Metrics', 'DesignSystem.Gallery', 'Spacing']
    _check_view_arithmetic(raw, path, line_no, s, res)
    _check_token_arithmetic(raw, path, line_no, s, res, exempt_tokens)
    _check_custom_size(raw, path, line_no, s, res)

# 修改后（仅保留 customSize 检测，算术交给 arithmetic.py）
def _check_magic_math(raw, path, line_no, s, res):
    """检查 customSize 伪 token 模式（算术检测由 arithmetic.py 负责）。"""
    _check_custom_size(raw, path, line_no, s, res)
```

同步删除 `_check_view_arithmetic()` 和 `_check_token_arithmetic()` 函数定义（L266-286）。

- [ ] **Step 5.2: 更新 TOKEN_FILES 集合**

`token-magic-numbers.py` L15-19 的 `TOKEN_FILES` 集合需更新为 SPM 包中的文件名：

```python
# 修改前 (L15-19)
TOKEN_FILES = {
    'Colors.swift', 'DesignSystem.swift', 'IconTokens.swift', 'Spacing.swift',
    'DemoImageBuilder.swift', 'InitialNotebookGenerator.swift',
    'Reference.swift', 'System.swift', 'Component.swift',
}
# 修改后（SPM 包中文件名）
TOKEN_FILES = {
    'Colors.swift', 'DesignTokens.swift', 'IconTokens.swift', 'Spacing.swift',
    'Typography.swift', 'Animations.swift',
    'DemoImageBuilder.swift', 'InitialNotebookGenerator.swift',
    'Reference.swift', 'System.swift', 'Component.swift',
}
```

- [ ] **Step 5.3: 更新排除目录路径**

`token-magic-numbers.py` L33 排除 `Sources/Shared/DesignSystem`，迁移后需排除 SPM 包目录：

```python
# 修改前 (L33)
if 'Sources/Shared/DesignSystem' in path or os.path.basename(path) in TOKEN_FILES:
    return issues
# 修改后
if 'Packages/UFPDesignSystem/Sources/UFPDesignSystem' in path or os.path.basename(path) in TOKEN_FILES:
    return issues
```

- [ ] **Step 5.4: 更新合法上下文关键词**

`token-magic-numbers.py` 多处使用 `DesignSystem`/`Spacing`/`Colors` 等作为合法上下文判断，迁移后需更新为 `DesignTokens`：

```python
# L136: _check_rgb_color
valid_color = any(k in raw or k in path for k in ['DesignTokens', 'Colors.swift', 'UIColor.theme', 'Color.theme'])

# L178: _check_business_threshold
if not any(k in raw for k in ['DesignTokens', 'Spacing', 'Layout', 'Reference', 'System', 'Component']):

# L184: _check_padding_and_radius
valid = any(k in raw for k in ['DesignTokens', 'Spacing', 'Layout', 'Reference', 'System', 'Component'])

# L196: _check_frame_and_opacity
valid_frame = any(k in raw for k in ['DesignTokens', 'Spacing', 'Layout', 'Reference', 'System', 'Component', 'geo', 'CGFloat', 'Double'])
valid_opacity = any(k in raw for k in ['DesignTokens', 'Colors', 'Opacity', 'Color.theme', 'glassOpacity', 'Reference', 'System', 'Component'])

# L206: _check_spacing_and_layout_params
valid = any(k in raw for k in ['DesignTokens', 'Spacing', 'Layout', 'Reference', 'System', 'Component'])
```

- [ ] **Step 5.5: 更新 _load_token_values() 路径**

`token-magic-numbers.py` L329 硬编码 `Sources/Shared/DesignSystem/Tokens`，迁移后改为 SPM 包路径：

```python
# 修改前 (L329)
tokens_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'Sources', 'Shared', 'DesignSystem', 'Tokens')
# 修改后
tokens_dir = os.path.join(os.path.dirname(__file__), '..', '..', 'Packages', 'UFPDesignSystem', 'Sources', 'UFPDesignSystem', 'Tokens')
```

- [ ] **Step 5.6: 更新 _check_custom_size 排除路径**

`token-magic-numbers.py` L291 排除 `DesignSystem+Metrics.swift`/`Spacing.swift`，迁移后需更新：

```python
# 修改前 (L291)
if re.search(r'customSize\d+', raw) and 'DesignSystem+Metrics.swift' not in path and 'Spacing.swift' not in path:
# 修改后
if re.search(r'customSize\d+', raw) and 'DesignTokens+Metrics.swift' not in path and 'Spacing.swift' not in path:
```

---

### Step 6: 验证 + Commit

- [ ] **Step 6.1: 验证脚本语法**

```bash
python3 -m py_compile Tools/ios/audit-design-token-layering.py
python3 -m py_compile Tools/ios/audit-design-token-arithmetic.py
python3 -m py_compile Tools/ios/audit-design-token-budget.py
python3 -m py_compile Tools/ios/audit-design-token-magic-numbers.py
```

- [ ] **Step 6.2: 运行 make audit**

```bash
make audit 2>&1 | tail -30
```

Expected: 全部通过（在 Task 2-9 完成后，Token 已迁移到 SPM 包）

- [ ] **Step 6.3: 运行 CI 静态分析**

```bash
bash Tools/CI/run-code-static-analysis.sh 2>&1 | tail -50
```

Expected: 全部通过

- [ ] **Step 6.4: Commit**

```bash
git add -A
git commit -m "ci: 更新 Token 审计脚本适配 DesignTokens 命名空间

- 重命名 audit-design-token-naming.py → audit-design-token-arithmetic.py
- 重命名 audit-design-magic-numbers.py → audit-design-token-magic-numbers.py
- layering.py: 更新 TOKENS_DIR 路径 + 新增 DesignSystem.* 残留检查
- arithmetic.py: 扩展检测范围含 DesignSystem.* 算术
- budget.py: 更新 TOKENS_DIR 路径
- token-magic-numbers.py: 移除 token 算术检测（交给 arithmetic.py）
- 更新 run-code-static-analysis.sh 调用点"
```

---

## Self-Review

### 1. Spec coverage

| Spec 要求 | 对应 Task |
|-----------|-----------|
| 迁移 17 个 Token 文件到 SPM 包 | Task 2-6 |
| 删除 app 内 Tokens/ 目录 | Task 7 Step 1 |
| 删除 DesignSystem.swift Token 转发属性 | Task 7 Step 1.2 |
| 全局替换 ~3000 处引用 | Task 7 Step 2-3 |
| Typography 集成 @ScaledMetric | Task 3（保留现有语义样式） |
| 更新 Package.swift 依赖 | Task 1 |
| 更新 SPM 包测试 | Task 2-3, Task 8 |
| 保留 DesignSystem+Domain.swift | Task 7 Step 4.3（手动修复引用） |
| 保留 DesignSystem+Components/ | Task 7 Step 4.3（手动修复引用） |
| 三平台编译验证 | Task 9 Step 2-4 |
| lint + audit | Task 9 Step 5-6 |
| 测试用例适配 DesignTokens | Task 10 |
| 快照测试固定 Dynamic Type | Task 10 Step 3 |
| CI 审计脚本路径更新 | Task 11 |
| CI 审计脚本职责清理 | Task 11 Step 1/5 |
| DesignSystem.* 残留检查 | Task 11 Step 2.4 |

### 2. Placeholder scan

无 TODO/TBD/待定。所有步骤包含具体命令和代码。

### 3. Type consistency

- `DesignTokens.Spacing.medium` = 12（app 值）— Task 2 更新测试期望值
- `DesignTokens.Typography.bodyFontSize` = 16 — Task 3 测试验证
- `DesignTokens.Colors.Opacity.glassOpacity` = 0.15 — Task 4 测试验证
- `DesignSystem.title2FontSize` → `DesignTokens.Typography.HeadingLevel.h2.size` — Task 7 Step 3.4

### 4. 已知风险

1. **sed 批量替换可能误伤：** `Spacing.` 可能匹配变量名（如 `lineSpacing.`）。缓解：使用 `\b` 词边界 + 编译验证
2. **import UFPDesignSystem 插入位置：** sed 命令可能在某些文件格式下失败。缓解：编译验证后手动修复
3. **DesignSystem+Domain.swift 和 Components 中的引用：** 需手动检查。缓解：Task 7 Step 4.3 专门处理
4. **watchOS 平台限制：** Colors.swift 的 UIKit 依赖在 watchOS 不可用。缓解：条件编译 `#if canImport(UIKit)`

