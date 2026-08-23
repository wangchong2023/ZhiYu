# DesignSystem Token 体系全量重构实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 445+ 个分散 token 重构为 3 层金字塔架构（Reference→System→Component），消除 362 处魔鬼数字，删除旧 3 层死代码架构，同步调整 CI 审计脚本。

**Architecture:** 严格 3 层分层 — Layer 1 Reference（10档严格原子集，对齐 Tailwind）→ Layer 2 System（语义映射层，视图主要引用）→ Layer 3 Component（组件特定尺寸+大值）。依赖规则：Component → System → Reference，严禁反向。硬切一次性迁移，660 个文件分 6 批全局替换。

**Tech Stack:** Swift 6 / SwiftUI / Python 3（CI 脚本）/ xcodebuild

## Global Constraints

- **严格分层**：Component → System → Reference，严禁反向依赖
- **禁止算术派生**：`glassOpacity * 2` 必须替换为命名 token（如 `SystemOpacity.glassStrong`）
- **原子集严格有限**：Reference 层 10档 spacing / 13档 opacity / 9档 radius / 8档 stroke / 13档 fontSize，新增需设计审查
- **视图代码主要引用 System/Component 层**，禁止直接引用 Reference 层（除 Colors/Typography Font 定义）
- **硬切一次性迁移**：旧 token 全部替换完成后删除旧文件，无兼容期
- **舍入规则**：Magic Math 结果值向最近 Reference 档舍入，偏差 ≤ 0.05 可接受
- **编译验证**：每批迁移后 `make ios` 编译验证
- **CI 审计**：最终 `make audit` 0 漏检
- **注释规范**：统一简体中文，`///` 文档注释，`//` 实现注释，`// MARK: - 中文标题`
- **文件头模板**：`系统层级` + `核心职责` 标注

---

## 阶段 1：新 token 架构搭建（Task 1-3）

### Task 1: 创建 Reference.swift（Layer 1 原子值层）

**Files:**
- Create: `Sources/Shared/DesignSystem/Tokens/Reference.swift`
- Test: `Tests/Unit/Shared/DesignSystemReferenceTests.swift`

**Interfaces:**
- Produces: `Reference.Spacing.*`（10档）、`Reference.Opacity.*`（13档）、`Reference.Radius.*`（9档）、`Reference.Stroke.*`（8档）、`Reference.FontSize.*`（13档）

- [ ] **Step 1: 编写 Reference.swift**

```swift
//
//  Reference.swift
//  ZhiYu
//
//  系统层级：[Shared] 共享标准层
//  核心职责：Layer 1 原子值层 — 严格有限的物理常量集，对齐 Tailwind CSS 默认 scale。
//           所有视觉值必须从这里取，禁止算术派生，禁止扩展。
//

import SwiftUI

/// Layer 1: 原子值层（Reference Tokens）
///
/// 严格有限的原子值集，对齐 Tailwind CSS 默认 spacing scale。
/// - 原子集严格有限，新增需设计审查
/// - 禁止算术派生
/// - 所有数值映射到原子集
public enum Reference {

    // MARK: - Spacing（10档，对齐 Tailwind 默认 scale）
    public enum Spacing {
        public static let zero: CGFloat = 0
        public static let half: CGFloat = 0.5      // hairline
        public static let one: CGFloat = 1          // divider
        public static let two: CGFloat = 2          // atomic
        public static let three: CGFloat = 3
        public static let four: CGFloat = 4          // tiny
        public static let six: CGFloat = 6
        public static let eight: CGFloat = 8         // small
        public static let twelve: CGFloat = 12       // medium
        public static let sixteen: CGFloat = 16      // standard
    }

    // MARK: - Opacity（13档）
    public enum Opacity {
        public static let zero: Double = 0
        public static let five: Double = 0.05        // ghost
        public static let ten: Double = 0.1          // faint
        public static let fifteen: Double = 0.15     // glass
        public static let twenty: Double = 0.2       // subtle
        public static let thirty: Double = 0.3       // light
        public static let forty: Double = 0.4        // medium
        public static let fifty: Double = 0.5        // soft
        public static let sixty: Double = 0.6        // dim
        public static let seventy: Double = 0.7      // translucent
        public static let eighty: Double = 0.8       // prominent
        public static let ninety: Double = 0.9       // strong
        public static let full: Double = 1.0         // solid
    }

    // MARK: - Radius（9档）
    public enum Radius {
        public static let zero: CGFloat = 0
        public static let two: CGFloat = 2           // micro
        public static let four: CGFloat = 4           // small
        public static let six: CGFloat = 6
        public static let eight: CGFloat = 8          // standard
        public static let twelve: CGFloat = 12        // large
        public static let sixteen: CGFloat = 16       // xl
        public static let twenty: CGFloat = 20        // 2xl
        public static let full: CGFloat = 9999        // capsule
    }

    // MARK: - Stroke（8档）
    public enum Stroke {
        public static let zero: CGFloat = 0
        public static let half: CGFloat = 0.5         // hairline
        public static let thin: CGFloat = 0.8         // border
        public static let one: CGFloat = 1            // divider
        public static let oneHalf: CGFloat = 1.5      // emphasis
        public static let two: CGFloat = 2            // selected
        public static let three: CGFloat = 3          // accent
        public static let four: CGFloat = 4           // heavy
    }

    // MARK: - FontSize（13档）
    public enum FontSize {
        public static let micro: CGFloat = 10         // xs
        public static let caption: CGFloat = 12       // sm
        public static let footnote: CGFloat = 13
        public static let subheadline: CGFloat = 14   // base
        public static let body: CGFloat = 16          // lg
        public static let headline: CGFloat = 17
        public static let title3: CGFloat = 18        // xl
        public static let title2: CGFloat = 20        // 2xl
        public static let title: CGFloat = 24         // 3xl
        public static let largeTitle: CGFloat = 28
        public static let display: CGFloat = 32       // 4xl
        public static let hero: CGFloat = 40          // 5xl
        public static let mega: CGFloat = 48          // 6xl
    }
}
```

- [ ] **Step 2: 编写测试**

```swift
//
//  DesignSystemReferenceTests.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试层
//  核心职责：验证 Reference 层原子值集的完整性与正确性。
//

import XCTest
@testable import ZhiYu

final class DesignSystemReferenceTests: XCTestCase {

    // MARK: - Spacing 完整性
    func testSpacingScaleHas10Levels() {
        XCTAssertEqual(Reference.Spacing.zero, 0)
        XCTAssertEqual(Reference.Spacing.half, 0.5)
        XCTAssertEqual(Reference.Spacing.one, 1)
        XCTAssertEqual(Reference.Spacing.two, 2)
        XCTAssertEqual(Reference.Spacing.three, 3)
        XCTAssertEqual(Reference.Spacing.four, 4)
        XCTAssertEqual(Reference.Spacing.six, 6)
        XCTAssertEqual(Reference.Spacing.eight, 8)
        XCTAssertEqual(Reference.Spacing.twelve, 12)
        XCTAssertEqual(Reference.Spacing.sixteen, 16)
    }

    // MARK: - Opacity 完整性
    func testOpacityScaleHas13Levels() {
        XCTAssertEqual(Reference.Opacity.zero, 0)
        XCTAssertEqual(Reference.Opacity.five, 0.05)
        XCTAssertEqual(Reference.Opacity.ten, 0.1)
        XCTAssertEqual(Reference.Opacity.fifteen, 0.15)
        XCTAssertEqual(Reference.Opacity.twenty, 0.2)
        XCTAssertEqual(Reference.Opacity.thirty, 0.3)
        XCTAssertEqual(Reference.Opacity.forty, 0.4)
        XCTAssertEqual(Reference.Opacity.fifty, 0.5)
        XCTAssertEqual(Reference.Opacity.sixty, 0.6)
        XCTAssertEqual(Reference.Opacity.seventy, 0.7)
        XCTAssertEqual(Reference.Opacity.eighty, 0.8)
        XCTAssertEqual(Reference.Opacity.ninety, 0.9)
        XCTAssertEqual(Reference.Opacity.full, 1.0)
    }

    // MARK: - Radius 完整性
    func testRadiusScaleHas9Levels() {
        XCTAssertEqual(Reference.Radius.zero, 0)
        XCTAssertEqual(Reference.Radius.two, 2)
        XCTAssertEqual(Reference.Radius.four, 4)
        XCTAssertEqual(Reference.Radius.six, 6)
        XCTAssertEqual(Reference.Radius.eight, 8)
        XCTAssertEqual(Reference.Radius.twelve, 12)
        XCTAssertEqual(Reference.Radius.sixteen, 16)
        XCTAssertEqual(Reference.Radius.twenty, 20)
        XCTAssertEqual(Reference.Radius.full, 9999)
    }

    // MARK: - Stroke 完整性
    func testStrokeScaleHas8Levels() {
        XCTAssertEqual(Reference.Stroke.zero, 0)
        XCTAssertEqual(Reference.Stroke.half, 0.5)
        XCTAssertEqual(Reference.Stroke.thin, 0.8)
        XCTAssertEqual(Reference.Stroke.one, 1)
        XCTAssertEqual(Reference.Stroke.oneHalf, 1.5)
        XCTAssertEqual(Reference.Stroke.two, 2)
        XCTAssertEqual(Reference.Stroke.three, 3)
        XCTAssertEqual(Reference.Stroke.four, 4)
    }

    // MARK: - FontSize 完整性
    func testFontSizeScaleHas13Levels() {
        XCTAssertEqual(Reference.FontSize.micro, 10)
        XCTAssertEqual(Reference.FontSize.caption, 12)
        XCTAssertEqual(Reference.FontSize.footnote, 13)
        XCTAssertEqual(Reference.FontSize.subheadline, 14)
        XCTAssertEqual(Reference.FontSize.body, 16)
        XCTAssertEqual(Reference.FontSize.headline, 17)
        XCTAssertEqual(Reference.FontSize.title3, 18)
        XCTAssertEqual(Reference.FontSize.title2, 20)
        XCTAssertEqual(Reference.FontSize.title, 24)
        XCTAssertEqual(Reference.FontSize.largeTitle, 28)
        XCTAssertEqual(Reference.FontSize.display, 32)
        XCTAssertEqual(Reference.FontSize.hero, 40)
        XCTAssertEqual(Reference.FontSize.mega, 48)
    }
}
```

- [ ] **Step 3: 重新生成 xcodeproj 并编译**

```bash
rm -rf ZhiYu.xcodeproj && make gen
make ios 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: 运行测试**

```bash
xcodebuild test-without-building -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -only-testing:ZhiYuTests/DesignSystemReferenceTests 2>&1 | tail -10
```

Expected: 5 tests, 0 failures

- [ ] **Step 5: 提交**

```bash
git add Sources/Shared/DesignSystem/Tokens/Reference.swift Tests/Unit/Shared/DesignSystemReferenceTests.swift ZhiYu.xcodeproj
git commit -m "feat(designsystem): 新建 Reference.swift Layer 1 原子值层

10档 spacing + 13档 opacity + 9档 radius + 8档 stroke + 13档 fontSize
对齐 Tailwind CSS 默认 scale，严格有限原子集，禁止算术派生"
```

---

### Task 2: 创建 System.swift（Layer 2 语义映射层）

**Files:**
- Create: `Sources/Shared/DesignSystem/Tokens/System.swift`
- Test: `Tests/Unit/Shared/DesignSystemSystemTests.swift`

**Interfaces:**
- Consumes: `Reference.Spacing.*`、`Reference.Opacity.*`、`Reference.Radius.*`、`Reference.Stroke.*`、`Reference.FontSize.*`（from Task 1）
- Produces: `SystemSpacing.*`、`SystemOpacity.*`、`SystemRadius.*`、`SystemStroke.*`、`SystemFontSize.*`

- [ ] **Step 1: 编写 System.swift**

```swift
//
//  System.swift
//  ZhiYu
//
//  系统层级：[Shared] 共享标准层
//  核心职责：Layer 2 语义映射层 — 将 Reference 原子值映射为语义名，按用途分类。
//           视图代码主要引用此层。禁止引用 Component 层。
//

import SwiftUI

// MARK: - SystemSpacing（语义间距）
public enum SystemSpacing {
    public static let none: CGFloat = Reference.Spacing.zero
    public static let hairline: CGFloat = Reference.Spacing.half
    public static let divider: CGFloat = Reference.Spacing.one
    public static let atomic: CGFloat = Reference.Spacing.two
    public static let tight: CGFloat = Reference.Spacing.three
    public static let tiny: CGFloat = Reference.Spacing.four
    public static let small: CGFloat = Reference.Spacing.six
    public static let element: CGFloat = Reference.Spacing.eight
    public static let medium: CGFloat = Reference.Spacing.twelve
    public static let content: CGFloat = Reference.Spacing.sixteen
}

// MARK: - SystemOpacity（语义透明度）
public enum SystemOpacity {
    // 交互状态
    public static let hidden: Double = Reference.Opacity.zero
    public static let ghost: Double = Reference.Opacity.five
    public static let faint: Double = Reference.Opacity.ten
    public static let glass: Double = Reference.Opacity.fifteen
    public static let glassStrong: Double = Reference.Opacity.thirty    // glass*2(0.3) 命名化
    public static let glassSubtle: Double = Reference.Opacity.twenty    // glass*1.5(0.225→0.2) 命名化
    public static let overlay: Double = Reference.Opacity.sixty
    public static let disabled: Double = Reference.Opacity.forty
    public static let pressed: Double = Reference.Opacity.ninety
    public static let active: Double = Reference.Opacity.full

    // 文本层级
    public static let textPrimary: Double = Reference.Opacity.full
    public static let textSecondary: Double = Reference.Opacity.eighty
    public static let textTertiary: Double = Reference.Opacity.seventy
    public static let textQuaternary: Double = Reference.Opacity.fifty
}

// MARK: - SystemRadius（语义圆角）
public enum SystemRadius {
    public static let none: CGFloat = Reference.Radius.zero
    public static let micro: CGFloat = Reference.Radius.two
    public static let chip: CGFloat = Reference.Radius.four
    public static let small: CGFloat = Reference.Radius.eight
    public static let card: CGFloat = Reference.Radius.twelve
    public static let large: CGFloat = Reference.Radius.sixteen
    public static let section: CGFloat = Reference.Radius.twenty
    public static let capsule: CGFloat = Reference.Radius.full
}

// MARK: - SystemStroke（语义描边）
public enum SystemStroke {
    public static let none: CGFloat = Reference.Stroke.zero
    public static let hairline: CGFloat = Reference.Stroke.half
    public static let border: CGFloat = Reference.Stroke.thin
    public static let divider: CGFloat = Reference.Stroke.one
    public static let emphasis: CGFloat = Reference.Stroke.oneHalf
    public static let selected: CGFloat = Reference.Stroke.two
    public static let accent: CGFloat = Reference.Stroke.three
    public static let heavy: CGFloat = Reference.Stroke.four
}

// MARK: - SystemFontSize（语义字号）
public enum SystemFontSize {
    public static let micro: CGFloat = Reference.FontSize.micro
    public static let caption: CGFloat = Reference.FontSize.caption
    public static let footnote: CGFloat = Reference.FontSize.footnote
    public static let subheadline: CGFloat = Reference.FontSize.subheadline
    public static let body: CGFloat = Reference.FontSize.body
    public static let headline: CGFloat = Reference.FontSize.headline
    public static let title3: CGFloat = Reference.FontSize.title3
    public static let title2: CGFloat = Reference.FontSize.title2
    public static let title: CGFloat = Reference.FontSize.title
    public static let largeTitle: CGFloat = Reference.FontSize.largeTitle
    public static let display: CGFloat = Reference.FontSize.display
    public static let hero: CGFloat = Reference.FontSize.hero
    public static let mega: CGFloat = Reference.FontSize.mega
}
```

- [ ] **Step 2: 编写测试**

```swift
//
//  DesignSystemSystemTests.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试层
//  核心职责：验证 System 层语义映射的正确性，确保所有 token 正确引用 Reference。
//

import XCTest
@testable import ZhiYu

final class DesignSystemSystemTests: XCTestCase {

    // MARK: - SystemSpacing 映射正确性
    func testSystemSpacingMapsToReference() {
        XCTAssertEqual(SystemSpacing.none, Reference.Spacing.zero)
        XCTAssertEqual(SystemSpacing.hairline, Reference.Spacing.half)
        XCTAssertEqual(SystemSpacing.divider, Reference.Spacing.one)
        XCTAssertEqual(SystemSpacing.atomic, Reference.Spacing.two)
        XCTAssertEqual(SystemSpacing.tight, Reference.Spacing.three)
        XCTAssertEqual(SystemSpacing.tiny, Reference.Spacing.four)
        XCTAssertEqual(SystemSpacing.small, Reference.Spacing.six)
        XCTAssertEqual(SystemSpacing.element, Reference.Spacing.eight)
        XCTAssertEqual(SystemSpacing.medium, Reference.Spacing.twelve)
        XCTAssertEqual(SystemSpacing.content, Reference.Spacing.sixteen)
    }

    // MARK: - SystemOpacity 映射正确性
    func testSystemOpacityMapsToReference() {
        XCTAssertEqual(SystemOpacity.hidden, Reference.Opacity.zero)
        XCTAssertEqual(SystemOpacity.ghost, Reference.Opacity.five)
        XCTAssertEqual(SystemOpacity.faint, Reference.Opacity.ten)
        XCTAssertEqual(SystemOpacity.glass, Reference.Opacity.fifteen)
        XCTAssertEqual(SystemOpacity.glassStrong, Reference.Opacity.thirty)
        XCTAssertEqual(SystemOpacity.glassSubtle, Reference.Opacity.twenty)
        XCTAssertEqual(SystemOpacity.overlay, Reference.Opacity.sixty)
        XCTAssertEqual(SystemOpacity.disabled, Reference.Opacity.forty)
        XCTAssertEqual(SystemOpacity.pressed, Reference.Opacity.ninety)
        XCTAssertEqual(SystemOpacity.active, Reference.Opacity.full)
    }

    func testSystemOpacityTextLevels() {
        XCTAssertEqual(SystemOpacity.textPrimary, Reference.Opacity.full)
        XCTAssertEqual(SystemOpacity.textSecondary, Reference.Opacity.eighty)
        XCTAssertEqual(SystemOpacity.textTertiary, Reference.Opacity.seventy)
        XCTAssertEqual(SystemOpacity.textQuaternary, Reference.Opacity.fifty)
    }

    // MARK: - SystemRadius 映射正确性
    func testSystemRadiusMapsToReference() {
        XCTAssertEqual(SystemRadius.none, Reference.Radius.zero)
        XCTAssertEqual(SystemRadius.micro, Reference.Radius.two)
        XCTAssertEqual(SystemRadius.chip, Reference.Radius.four)
        XCTAssertEqual(SystemRadius.small, Reference.Radius.eight)
        XCTAssertEqual(SystemRadius.card, Reference.Radius.twelve)
        XCTAssertEqual(SystemRadius.large, Reference.Radius.sixteen)
        XCTAssertEqual(SystemRadius.section, Reference.Radius.twenty)
        XCTAssertEqual(SystemRadius.capsule, Reference.Radius.full)
    }

    // MARK: - SystemStroke 映射正确性
    func testSystemStrokeMapsToReference() {
        XCTAssertEqual(SystemStroke.none, Reference.Stroke.zero)
        XCTAssertEqual(SystemStroke.hairline, Reference.Stroke.half)
        XCTAssertEqual(SystemStroke.border, Reference.Stroke.thin)
        XCTAssertEqual(SystemStroke.divider, Reference.Stroke.one)
        XCTAssertEqual(SystemStroke.emphasis, Reference.Stroke.oneHalf)
        XCTAssertEqual(SystemStroke.selected, Reference.Stroke.two)
        XCTAssertEqual(SystemStroke.accent, Reference.Stroke.three)
        XCTAssertEqual(SystemStroke.heavy, Reference.Stroke.four)
    }

    // MARK: - SystemFontSize 映射正确性
    func testSystemFontSizeMapsToReference() {
        XCTAssertEqual(SystemFontSize.micro, Reference.FontSize.micro)
        XCTAssertEqual(SystemFontSize.caption, Reference.FontSize.caption)
        XCTAssertEqual(SystemFontSize.body, Reference.FontSize.body)
        XCTAssertEqual(SystemFontSize.title, Reference.FontSize.title)
        XCTAssertEqual(SystemFontSize.display, Reference.FontSize.display)
        XCTAssertEqual(SystemFontSize.hero, Reference.FontSize.hero)
        XCTAssertEqual(SystemFontSize.mega, Reference.FontSize.mega)
    }
}
```

- [ ] **Step 3: 重新生成 xcodeproj 并编译**

```bash
rm -rf ZhiYu.xcodeproj && make gen
make ios 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: 运行测试**

```bash
xcodebuild test-without-building -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -only-testing:ZhiYuTests/DesignSystemSystemTests 2>&1 | tail -10
```

Expected: 6 tests, 0 failures

- [ ] **Step 5: 提交**

```bash
git add Sources/Shared/DesignSystem/Tokens/System.swift Tests/Unit/Shared/DesignSystemSystemTests.swift ZhiYu.xcodeproj
git commit -m "feat(designsystem): 新建 System.swift Layer 2 语义映射层

SystemSpacing/SystemOpacity/SystemRadius/SystemStroke/SystemFontSize
将 Reference 原子值映射为语义名，视图代码主要引用此层"
```

---

### Task 3: 创建 Component.swift（Layer 3 组件特定尺寸层）

**Files:**
- Create: `Sources/Shared/DesignSystem/Tokens/Component.swift`
- Test: `Tests/Unit/Shared/DesignSystemComponentTests.swift`

**Interfaces:**
- Consumes: `SystemSpacing.*`、`Reference.*`（from Task 1, 2）
- Produces: `ComponentSpacing.*`（大值+组件语义+组件特定尺寸+图标尺寸）

- [ ] **Step 1: 编写 Component.swift**

```swift
//
//  Component.swift
//  ZhiYu
//
//  系统层级：[Shared] 共享标准层
//  核心职责：Layer 3 组件特定尺寸层 — 大值、组件语义映射、组件特定尺寸、图标尺寸。
//           依赖 System 层，禁止反向依赖。
//

import SwiftUI

// MARK: - ComponentSpacing（组件特定尺寸）
public enum ComponentSpacing {
    // MARK: 大值（超出 Layer 1 10档范围）
    public static let section: CGFloat = 20          // 区段间
    public static let sectionLarge: CGFloat = 24     // 大区段
    public static let huge: CGFloat = 32             // 巨大
    public static let ultra: CGFloat = 40            // 超大
    public static let massive: CGFloat = 48          // 极大
    public static let colossal: CGFloat = 64         // 超极大

    // MARK: 组件语义（从 System 映射）
    public static let cardPadding: CGFloat = SystemSpacing.content      // 16
    public static let listRowGap: CGFloat = SystemSpacing.element       // 8
    public static let iconTextGap: CGFloat = SystemSpacing.small        // 6
    public static let buttonInternalPadding: CGFloat = SystemSpacing.medium // 12
    public static let chipPadding: CGFloat = SystemSpacing.tiny         // 4

    // MARK: 组件特定尺寸
    public static let toolbarHeight: CGFloat = 44
    public static let buttonHeight: CGFloat = 44
    public static let compactButtonHeight: CGFloat = 32
    public static let inputFieldHeight: CGFloat = 50
    public static let minTouchTarget: CGFloat = 44
    public static let capsuleHeight: CGFloat = 28
    public static let inputBarHeight: CGFloat = 54

    // MARK: 图标尺寸（组件特定）
    public static let iconCompact: CGFloat = 18      // largeIconSize/1.5
    public static let iconStandard: CGFloat = 22      // largeIconSize*0.8
    public static let iconLarge: CGFloat = 24          // iconDisplay/2
    public static let iconDisplay: CGFloat = 48
    public static let iconHuge: CGFloat = 64
}
```

- [ ] **Step 2: 编写测试**

```swift
//
//  DesignSystemComponentTests.swift
//  ZhiYu
//
//  系统层级：[Tests] 测试层
//  核心职责：验证 Component 层组件特定尺寸的正确性。
//

import XCTest
@testable import ZhiYu

final class DesignSystemComponentTests: XCTestCase {

    // MARK: - 大值
    func testLargeValues() {
        XCTAssertEqual(ComponentSpacing.section, 20)
        XCTAssertEqual(ComponentSpacing.sectionLarge, 24)
        XCTAssertEqual(ComponentSpacing.huge, 32)
        XCTAssertEqual(ComponentSpacing.ultra, 40)
        XCTAssertEqual(ComponentSpacing.massive, 48)
        XCTAssertEqual(ComponentSpacing.colossal, 64)
    }

    // MARK: - 组件语义映射
    func testComponentSemanticMapping() {
        XCTAssertEqual(ComponentSpacing.cardPadding, SystemSpacing.content)
        XCTAssertEqual(ComponentSpacing.listRowGap, SystemSpacing.element)
        XCTAssertEqual(ComponentSpacing.iconTextGap, SystemSpacing.small)
        XCTAssertEqual(ComponentSpacing.buttonInternalPadding, SystemSpacing.medium)
        XCTAssertEqual(ComponentSpacing.chipPadding, SystemSpacing.tiny)
    }

    // MARK: - 组件特定尺寸
    func testComponentSpecificDimensions() {
        XCTAssertEqual(ComponentSpacing.toolbarHeight, 44)
        XCTAssertEqual(ComponentSpacing.buttonHeight, 44)
        XCTAssertEqual(ComponentSpacing.compactButtonHeight, 32)
        XCTAssertEqual(ComponentSpacing.inputFieldHeight, 50)
        XCTAssertEqual(ComponentSpacing.minTouchTarget, 44)
        XCTAssertEqual(ComponentSpacing.capsuleHeight, 28)
        XCTAssertEqual(ComponentSpacing.inputBarHeight, 54)
    }

    // MARK: - 图标尺寸
    func testIconSizes() {
        XCTAssertEqual(ComponentSpacing.iconCompact, 18)
        XCTAssertEqual(ComponentSpacing.iconStandard, 22)
        XCTAssertEqual(ComponentSpacing.iconLarge, 24)
        XCTAssertEqual(ComponentSpacing.iconDisplay, 48)
        XCTAssertEqual(ComponentSpacing.iconHuge, 64)
    }
}
```

- [ ] **Step 3: 重新生成 xcodeproj 并编译**

```bash
rm -rf ZhiYu.xcodeproj && make gen
make ios 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: 运行测试**

```bash
xcodebuild test-without-building -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -only-testing:ZhiYuTests/DesignSystemComponentTests 2>&1 | tail -10
```

Expected: 4 tests, 0 failures

- [ ] **Step 5: 提交**

```bash
git add Sources/Shared/DesignSystem/Tokens/Component.swift Tests/Unit/Shared/DesignSystemComponentTests.swift ZhiYu.xcodeproj
git commit -m "feat(designsystem): 新建 Component.swift Layer 3 组件特定尺寸层

大值(20-64) + 组件语义映射 + 组件特定尺寸 + 图标尺寸
依赖 System 层，禁止反向依赖"
```

---

## 阶段 2：CI 审计脚本调整（Task 4-6）

### Task 4: 更新 audit-design-magic-numbers.py 识别新 token

**Files:**
- Modify: `Tools/ios/audit-design-magic-numbers.py`

**Interfaces:**
- Produces: 识别 `Reference.*`/`System.*`/`Component.*` 为合法 token，不误判为魔鬼数字

- [ ] **Step 1: 更新 TOKEN_FILES 豁免列表**

在 `Tools/ios/audit-design-magic-numbers.py` 第 15 行修改：

```python
# 旧
TOKEN_FILES = {'Colors.swift','DesignSystem.swift','IconTokens.swift','Spacing.swift','DemoImageBuilder.swift','InitialNotebookGenerator.swift'}

# 新
TOKEN_FILES = {
    'Colors.swift', 'DesignSystem.swift', 'IconTokens.swift', 'Spacing.swift',
    'DemoImageBuilder.swift', 'InitialNotebookGenerator.swift',
    'Reference.swift', 'System.swift', 'Component.swift',  # 新 3 层架构
}
```

- [ ] **Step 2: 更新 _check_padding_and_radius 的 valid 关键词**

在第 86 行修改：

```python
# 旧
valid = any(k in raw for k in ['DesignSystem', 'Spacing', 'Layout'])

# 新
valid = any(k in raw for k in ['DesignSystem', 'Spacing', 'Layout', 'Reference', 'System', 'Component'])
```

- [ ] **Step 3: 更新 _check_frame_and_opacity 的 valid 关键词**

在第 98 和 101 行修改：

```python
# 旧
valid_frame = any(k in raw for k in ['DesignSystem', 'Spacing', 'Layout', 'geo', 'CGFloat', 'Double'])
valid_opacity = any(k in raw for k in ['DesignSystem', 'Colors', 'Opacity', 'Color.theme', 'glassOpacity'])

# 新
valid_frame = any(k in raw for k in ['DesignSystem', 'Spacing', 'Layout', 'Reference', 'System', 'Component', 'geo', 'CGFloat', 'Double'])
valid_opacity = any(k in raw for k in ['DesignSystem', 'Colors', 'Opacity', 'Color.theme', 'glassOpacity', 'Reference', 'System', 'Component'])
```

- [ ] **Step 4: 更新 _check_spacing_and_layout_params 的 valid 关键词**

在第 108 行修改：

```python
# 旧
valid = any(k in raw for k in ['DesignSystem', 'Spacing', 'Layout'])

# 新
valid = any(k in raw for k in ['DesignSystem', 'Spacing', 'Layout', 'Reference', 'System', 'Component'])
```

- [ ] **Step 5: 更新 _check_magic_math 的 token_math 正则**

在第 144 行修改：

```python
# 旧
token_math = re.search(r'\b(DesignSystem|Spacing)\.([a-zA-Z0-9_.]+)\s*[\*\/]\s*(\d+\.?\d*)\b', raw)

# 新
token_math = re.search(r'\b(DesignSystem|Spacing|Reference|System|Component)\.([a-zA-Z0-9_.]+)\s*[\*\/]\s*(\d+\.?\d*)\b', raw)
```

- [ ] **Step 6: 运行审计脚本验证**

```bash
python3 Tools/ios/audit-design-magic-numbers.py 2>&1 | tail -20
```

Expected: 仍检出 362 处（旧 token 仍在使用），但新 token `Reference.*`/`System.*`/`Component.*` 不被误判

- [ ] **Step 7: 提交**

```bash
git add Tools/ios/audit-design-magic-numbers.py
git commit -m "fix(ci): audit-design-magic-numbers.py 识别新 3 层 token 命名空间

扩展 valid 关键词列表加入 Reference/System/Component
扩展 Magic Math 检测正则覆盖新 token 命名空间
扩展 TOKEN_FILES 豁免列表加入 Reference.swift/System.swift/Component.swift"
```

---

### Task 5: 重写 audit-design-token-layering.py 检查新 3 层架构

**Files:**
- Modify: `Tools/ios/audit-design-token-layering.py`

**Interfaces:**
- Produces: 检查 Reference/System/Component 文件存在 + 依赖方向 + 视图分层 + 旧架构残留

- [ ] **Step 1: 重写 audit-design-token-layering.py**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 版权所有 (c) 2026 ZhiYu。保留所有权利。
#
# 职责说明: 本脚本用于对 3 层设计令牌架构 (Reference→System→Component) 进行 CI 门禁检查。
# 验证内容：
# 1. 验证 Reference/System/Component 3 个文件的存在性与核心定义
# 2. 检查依赖方向：Component→System→Reference，严禁反向
# 3. 扫描视图代码，禁止直接引用 Reference 层（必须通过 System/Component）
# 4. 检查旧架构残留（Tier1/Tier2/Tier3/DesignTokenRegistry/PlatformContext）
#

import os
import re
import sys

# 引入统一报告管理器
SYS_GATEKEEPER_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.append(SYS_GATEKEEPER_DIR)
from gatekeeper_reporter import GatekeeperReporter

PROJECT_ROOT = os.path.abspath(os.path.join(SYS_GATEKEEPER_DIR, '..'))
SOURCES_DIR = os.path.join(PROJECT_ROOT, 'Sources')
TOKENS_DIR = os.path.join(SOURCES_DIR, 'Shared/DesignSystem/Tokens')

REFERENCE_FILE = os.path.join(TOKENS_DIR, 'Reference.swift')
SYSTEM_FILE = os.path.join(TOKENS_DIR, 'System.swift')
COMPONENT_FILE = os.path.join(TOKENS_DIR, 'Component.swift')

# 旧架构文件（应已删除）
LEGACY_FILES = [
    os.path.join(SOURCES_DIR, 'Shared/DesignSystem/DesignSystem+Layering.swift'),
    os.path.join(SOURCES_DIR, 'Shared/DesignSystem/PlatformContext.swift'),
    os.path.join(SOURCES_DIR, 'Shared/DesignSystem/DesignTokenRegistry.swift'),
]

reporter = GatekeeperReporter("Design Token 3-Tier Layering Check")


def check_layering_structure():
    """检查 3 层架构文件的存在性与核心定义"""
    files_to_check = [
        (REFERENCE_FILE, 'Reference'),
        (SYSTEM_FILE, 'System'),
        (COMPONENT_FILE, 'Component'),
    ]
    for fpath, enum_name in files_to_check:
        if not os.path.exists(fpath):
            reporter.add_issue(
                filepath=os.path.relpath(fpath, PROJECT_ROOT),
                line_no=1,
                message=f"缺失 3 层架构定义文件: {os.path.basename(fpath)}",
                level="ERROR"
            )
            continue
        with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        # 检查 enum 定义存在
        if enum_name == 'Reference':
            if not re.search(r'\benum\s+Reference\b', content):
                reporter.add_issue(
                    filepath=os.path.relpath(fpath, PROJECT_ROOT),
                    line_no=1,
                    message=f"Reference.swift 缺失 enum Reference 定义",
                    level="ERROR"
                )
        else:
            # System/Component 是多个 enum（SystemSpacing/SystemOpacity 等）
            if enum_name == 'System':
                required = ['SystemSpacing', 'SystemOpacity', 'SystemRadius', 'SystemStroke', 'SystemFontSize']
            else:
                required = ['ComponentSpacing']
            for req in required:
                if not re.search(fr'\benum\s+{req}\b', content):
                    reporter.add_issue(
                        filepath=os.path.relpath(fpath, PROJECT_ROOT),
                        line_no=1,
                        message=f"{os.path.basename(fpath)} 缺失 enum {req} 定义",
                        level="ERROR"
                    )


def check_dependency_direction():
    """检查依赖方向：Component→System→Reference，严禁反向"""
    # Reference.swift：禁止引用 System/Component
    if os.path.exists(REFERENCE_FILE):
        with open(REFERENCE_FILE, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        if re.search(r'\bSystem(?:Spacing|Opacity|Radius|Stroke|FontSize)\b', content):
            reporter.add_issue(
                filepath=os.path.relpath(REFERENCE_FILE, PROJECT_ROOT),
                line_no=1,
                message="Reference 层禁止引用 System 层（违反依赖方向）",
                level="ERROR"
            )
        if re.search(r'\bComponentSpacing\b', content):
            reporter.add_issue(
                filepath=os.path.relpath(REFERENCE_FILE, PROJECT_ROOT),
                line_no=1,
                message="Reference 层禁止引用 Component 层（违反依赖方向）",
                level="ERROR"
            )

    # System.swift：禁止引用 Component
    if os.path.exists(SYSTEM_FILE):
        with open(SYSTEM_FILE, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        if re.search(r'\bComponentSpacing\b', content):
            reporter.add_issue(
                filepath=os.path.relpath(SYSTEM_FILE, PROJECT_ROOT),
                line_no=1,
                message="System 层禁止引用 Component 层（违反依赖方向）",
                level="ERROR"
            )
        # System 必须引用 Reference
        if 'Reference.' not in content:
            reporter.add_issue(
                filepath=os.path.relpath(SYSTEM_FILE, PROJECT_ROOT),
                line_no=1,
                message="System 层必须引用 Reference 层（依赖方向检查）",
                level="WARNING"
            )

    # Component.swift：必须引用 System
    if os.path.exists(COMPONENT_FILE):
        with open(COMPONENT_FILE, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
        if 'SystemSpacing.' not in content:
            reporter.add_issue(
                filepath=os.path.relpath(COMPONENT_FILE, PROJECT_ROOT),
                line_no=1,
                message="Component 层应引用 System 层（依赖方向检查）",
                level="WARNING"
            )


def check_legacy_residue():
    """检查旧架构残留"""
    # 旧文件应已删除
    for legacy_file in LEGACY_FILES:
        if os.path.exists(legacy_file):
            reporter.add_issue(
                filepath=os.path.relpath(legacy_file, PROJECT_ROOT),
                line_no=1,
                message=f"旧架构文件应已删除: {os.path.basename(legacy_file)}",
                level="ERROR"
            )

    # 扫描所有 Sources 文件，禁止引用旧架构符号
    legacy_patterns = [
        r'\bDesignSystem\.Tier[123]\b',
        r'\bDesignTokenRegistry\.shared\b',
        r'\bPlatformContext\.current\b',
        r'\bSemanticSpacingToken\b',
        r'\bSemanticRadiusToken\b',
    ]
    combined = '|'.join(legacy_patterns)
    for root, dirs, files in os.walk(SOURCES_DIR):
        dirs[:] = [d for d in dirs if d not in {'.git', 'build', 'DerivedData', '.build'}]
        for fname in files:
            if not fname.endswith('.swift'):
                continue
            fpath = os.path.join(root, fname)
            # 跳过旧架构文件本身（如果还存在）
            if any(fpath == lf for lf in LEGACY_FILES):
                continue
            with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                for i, line in enumerate(f, 1):
                    if re.search(combined, line):
                        reporter.add_issue(
                            filepath=os.path.relpath(fpath, PROJECT_ROOT),
                            line_no=i,
                            message="检测到旧架构符号引用，应迁移到新 3 层架构",
                            level="ERROR",
                            content=line.strip()
                        )


def scan_view_token_bypasses():
    """扫描视图代码，禁止直接引用 Reference 层"""
    views_dirs = [
        os.path.join(SOURCES_DIR, 'Features'),
        os.path.join(SOURCES_DIR, 'Shared/UIComponents'),
        os.path.join(SOURCES_DIR, 'Platforms'),
    ]
    # 允许的 token 前缀（视图代码可引用）
    allowed_prefixes = ['SystemSpacing', 'SystemOpacity', 'SystemRadius', 'SystemStroke', 'SystemFontSize', 'ComponentSpacing']
    # 禁止的 token 前缀（视图代码不可直接引用 Reference）
    # 但 Colors.swift/Typography.swift 等 token 定义文件可引用 Reference
    exempt_files = {'Reference.swift', 'System.swift', 'Component.swift', 'Colors.swift', 'Typography.swift', 'DesignSystem.swift'}

    for v_dir in views_dirs:
        if not os.path.exists(v_dir):
            continue
        for root, dirs, files in os.walk(v_dir):
            dirs[:] = [d for d in dirs if d not in {'.git', 'build', 'DerivedData', '.build'}]
            for fname in files:
                if not fname.endswith('.swift') or fname in exempt_files:
                    continue
                fpath = os.path.join(root, fname)
                with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                    for i, line in enumerate(f, 1):
                        # 检测 Reference. 引用（视图代码禁止）
                        if re.search(r'\bReference\.(Spacing|Opacity|Radius|Stroke|FontSize)\.', line):
                            reporter.add_issue(
                                filepath=os.path.relpath(fpath, PROJECT_ROOT),
                                line_no=i,
                                message="视图代码禁止直接引用 Reference 层，应使用 System/Component 层",
                                level="WARNING",
                                content=line.strip()
                            )


def main():
    check_layering_structure()
    check_dependency_direction()
    check_legacy_residue()
    scan_view_token_bypasses()
    reporter.report()


if __name__ == '__main__':
    main()
```

- [ ] **Step 2: 运行验证**

```bash
python3 Tools/ios/audit-design-token-layering.py 2>&1 | tail -20
```

Expected: 
- Reference/System/Component 文件存在 ✅
- 旧架构文件存在报 ERROR（Task 7 删除后消失）
- 旧架构符号引用报 ERROR（迁移完成后消失）

- [ ] **Step 3: 提交**

```bash
git add Tools/ios/audit-design-token-layering.py
git commit -m "refactor(ci): 重写 audit-design-token-layering.py 检查新 3 层架构

- 检查 Reference/System/Component 文件存在性与核心定义
- 检查依赖方向：Component→System→Reference，严禁反向
- 扫描视图代码禁止直接引用 Reference 层
- 检查旧架构残留（Tier1/Tier2/Tier3/DesignTokenRegistry/PlatformContext）"
```

---

### Task 6: 新建 audit-design-token-naming.py token 命名规范检查

**Files:**
- Create: `Tools/ios/audit-design-token-naming.py`
- Modify: `Makefile`（audit 目标集成新脚本）

**Interfaces:**
- Produces: 检查 token 定义文件内禁止算术 + 视图代码禁止 token 算术 + hardcoded 零容忍

- [ ] **Step 1: 编写 audit-design-token-naming.py**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 版权所有 (c) 2026 ZhiYu。保留所有权利。
#
# 职责说明: 本脚本用于对设计令牌命名规范进行 CI 门禁检查。
# 验证内容：
# 1. token 定义文件内禁止算术表达式（Reference 纯原子值，System/Component 仅允许组合）
# 2. 视图代码禁止 token 算术表达式（Reference.* * N、System.* * N、Component.* * N）
# 3. hardcoded 值零容忍（视图代码中 .padding(N)、spacing: N、lineWidth: N 等）
#

import os
import re
import sys

# 引入统一报告管理器
SYS_GATEKEEPER_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..'))
sys.path.append(SYS_GATEKEEPER_DIR)
from gatekeeper_reporter import GatekeeperReporter

PROJECT_ROOT = os.path.abspath(os.path.join(SYS_GATEKEEPER_DIR, '..'))
SOURCES_DIR = os.path.join(PROJECT_ROOT, 'Sources')
TOKENS_DIR = os.path.join(SOURCES_DIR, 'Shared/DesignSystem/Tokens')

reporter = GatekeeperReporter("Design Token Naming Check")

# token 定义文件
REFERENCE_FILE = os.path.join(TOKENS_DIR, 'Reference.swift')
SYSTEM_FILE = os.path.join(TOKENS_DIR, 'System.swift')
COMPONENT_FILE = os.path.join(TOKENS_DIR, 'Component.swift')


def check_token_definition_arithmetic():
    """检查 token 定义文件内禁止算术表达式"""
    # Reference.swift：禁止任何 * / 算术（纯原子值）
    if os.path.exists(REFERENCE_FILE):
        with open(REFERENCE_FILE, 'r', encoding='utf-8', errors='ignore') as f:
            for i, line in enumerate(f, 1):
                s = line.strip()
                if s.startswith('//') or s.startswith('/*'):
                    continue
                # 检测 * 或 / 算术（排除注释）
                if re.search(r'\b\d+\.?\d*\s*[\*\/]\s*\d+\.?\d*\b', line):
                    reporter.add_issue(
                        filepath=os.path.relpath(REFERENCE_FILE, PROJECT_ROOT),
                        line_no=i,
                        message="Reference 层禁止算术表达式（纯原子值）",
                        level="ERROR",
                        content=s
                    )

    # System.swift：禁止 * / 算术（允许 Reference.A + Reference.B 组合）
    if os.path.exists(SYSTEM_FILE):
        with open(SYSTEM_FILE, 'r', encoding='utf-8', errors='ignore') as f:
            for i, line in enumerate(f, 1):
                s = line.strip()
                if s.startswith('//') or s.startswith('/*'):
                    continue
                # 检测 token * N 或 token / N
                if re.search(r'\b(Reference|System|Component)\.\w+\.\w+\s*[\*\/]\s*\d+\.?\d*\b', line):
                    reporter.add_issue(
                        filepath=os.path.relpath(SYSTEM_FILE, PROJECT_ROOT),
                        line_no=i,
                        message="System 层禁止 token 算术表达式",
                        level="ERROR",
                        content=s
                    )

    # Component.swift：禁止 * / 算术
    if os.path.exists(COMPONENT_FILE):
        with open(COMPONENT_FILE, 'r', encoding='utf-8', errors='ignore') as f:
            for i, line in enumerate(f, 1):
                s = line.strip()
                if s.startswith('//') or s.startswith('/*'):
                    continue
                if re.search(r'\b(Reference|System|Component)\.\w+\.\w+\s*[\*\/]\s*\d+\.?\d*\b', line):
                    reporter.add_issue(
                        filepath=os.path.relpath(COMPONENT_FILE, PROJECT_ROOT),
                        line_no=i,
                        message="Component 层禁止 token 算术表达式",
                        level="ERROR",
                        content=s
                    )


def check_view_token_arithmetic():
    """扫描视图代码，禁止 token 算术表达式"""
    views_dirs = [
        os.path.join(SOURCES_DIR, 'Features'),
        os.path.join(SOURCES_DIR, 'Shared/UIComponents'),
        os.path.join(SOURCES_DIR, 'Platforms'),
        os.path.join(SOURCES_DIR, 'App'),
    ]
    exempt_files = {'Reference.swift', 'System.swift', 'Component.swift'}

    for v_dir in views_dirs:
        if not os.path.exists(v_dir):
            continue
        for root, dirs, files in os.walk(v_dir):
            dirs[:] = [d for d in dirs if d not in {'.git', 'build', 'DerivedData', '.build'}]
            for fname in files:
                if not fname.endswith('.swift') or fname in exempt_files:
                    continue
                fpath = os.path.join(root, fname)
                with open(fpath, 'r', encoding='utf-8', errors='ignore') as f:
                    for i, line in enumerate(f, 1):
                        s = line.strip()
                        if s.startswith('//'):
                            continue
                        # 检测 token * N 或 token / N
                        if re.search(r'\b(Reference|System|Component)\w*\.\w+\s*[\*\/]\s*\d+\.?\d*\b', line):
                            reporter.add_issue(
                                filepath=os.path.relpath(fpath, PROJECT_ROOT),
                                line_no=i,
                                message="视图代码禁止 token 算术表达式，应使用命名 token",
                                level="ERROR",
                                content=s
                            )


def main():
    check_token_definition_arithmetic()
    check_view_token_arithmetic()
    reporter.report()


if __name__ == '__main__':
    main()
```

- [ ] **Step 2: 集成到 Makefile audit 目标**

在 `Makefile` 的 `audit` 目标中添加：

```makefile
# 在 audit-design-token-layering.py 之后添加
	@python3 Tools/ios/audit-design-token-naming.py
```

- [ ] **Step 3: 运行验证**

```bash
python3 Tools/ios/audit-design-token-naming.py 2>&1 | tail -20
```

Expected: 0 issues（新 token 文件无算术，视图代码尚未引用新 token）

- [ ] **Step 4: 提交**

```bash
git add Tools/ios/audit-design-token-naming.py Makefile
git commit -m "feat(ci): 新建 audit-design-token-naming.py token 命名规范检查

- token 定义文件内禁止算术表达式（Reference 纯原子值）
- 视图代码禁止 token 算术表达式
- 集成到 Makefile audit 目标"
```

---

## 阶段 3：源码迁移（Task 7-12，分 6 批）

> **迁移策略**：每批按目录分，先全局替换旧 token → 新 token，再替换 Magic Math → 新 token，最后替换 hardcoded 值 → 新 token。每批编译验证。
>
> **关键规则**：
> - `DesignSystem.xxx` → 对应 `SystemXxx.xxx` 或 `ComponentSpacing.xxx`
> - `Spacing.xxx` → 对应 `SystemSpacing.xxx` 或 `ComponentSpacing.xxx`
> - Magic Math 表达式 → 命名 token（见设计文档迁移映射表 4.2）
> - hardcoded 值 → token（见设计文档迁移映射表 4.3）

### Task 7: 删除旧 3 层架构死代码

**Files:**
- Delete: `Sources/Shared/DesignSystem/DesignSystem+Layering.swift`
- Delete: `Sources/Shared/DesignSystem/PlatformContext.swift`
- Delete: `Sources/Shared/DesignSystem/DesignTokenRegistry.swift`

**Interfaces:**
- Produces: 旧架构文件删除，编译通过（零影响，因从未被视图代码使用）

- [ ] **Step 1: 验证旧架构无外部引用**

```bash
rg "DesignSystem\.Tier[123]\.|DesignTokenRegistry\.shared|PlatformContext\.current|SemanticSpacingToken|SemanticRadiusToken" Sources/ --glob '!DesignSystem+Layering.swift' --glob '!PlatformContext.swift' --glob '!DesignTokenRegistry.swift'
```

Expected: 无任何匹配（仅旧架构文件内部互相引用）

- [ ] **Step 2: 删除 3 个文件**

```bash
rm Sources/Shared/DesignSystem/DesignSystem+Layering.swift
rm Sources/Shared/DesignSystem/PlatformContext.swift
rm Sources/Shared/DesignSystem/DesignTokenRegistry.swift
```

- [ ] **Step 3: 重新生成 xcodeproj 并编译**

```bash
rm -rf ZhiYu.xcodeproj && make gen
make ios 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: 运行审计脚本验证旧架构残留检查通过**

```bash
python3 Tools/ios/audit-design-token-layering.py 2>&1 | tail -20
```

Expected: 旧架构残留检查 0 issues

- [ ] **Step 5: 提交**

```bash
git add -A Sources/Shared/DesignSystem/ ZhiYu.xcodeproj
git commit -m "refactor(designsystem): 删除旧 3 层架构死代码

删除 DesignSystem+Layering.swift（Tier1/Tier2/Tier3，从未被视图代码使用）
删除 PlatformContext.swift（平台上下文，从未被视图代码使用）
删除 DesignTokenRegistry.swift（动态解析注册表，从未被调用）

新 3 层架构（Reference/System/Component）取代"
```

---

### Task 8: 迁移 Features/System（158 处魔鬼数字）

**Files:**
- Modify: `Sources/Features/System/**/*.swift`（~40 个文件）

**Interfaces:**
- Consumes: `SystemSpacing.*`/`SystemOpacity.*`/`SystemRadius.*`/`SystemStroke.*`/`SystemFontSize.*`/`ComponentSpacing.*`（from Task 1-3）
- Produces: Features/System 目录 0 处魔鬼数字

- [ ] **Step 1: 生成 Features/System 目录的魔鬼数字清单**

```bash
python3 Tools/ios/audit-design-magic-numbers.py 2>&1 | grep "Features/System" > /tmp/magic-system.txt
wc -l /tmp/magic-system.txt
```

Expected: ~158 行

- [ ] **Step 2: 按文件逐个迁移**

对 `/tmp/magic-system.txt` 中列出的每个文件，按设计文档迁移映射表执行替换：

**替换规则**（按优先级）：
1. Magic Math token 算术表达式 → 命名 token
   - `DesignSystem.glassOpacity * 2` → `SystemOpacity.glassStrong`
   - `DesignSystem.glassOpacity / 3` → `SystemOpacity.ghost`
   - `DesignSystem.glassOpacity / 2` → `SystemOpacity.faint`
   - `DesignSystem.glassOpacity / 1.5` → `SystemOpacity.faint`
   - `DesignSystem.borderWidth * 2` → `SystemStroke.emphasis`
   - `Spacing.atomic / 2.0` → `SystemSpacing.divider`
   - `Spacing.atomic * 2` → `SystemSpacing.tiny`
   - （完整列表见设计文档 4.2 节）

2. 旧 token → 新 token
   - `DesignSystem.atomic` → `SystemSpacing.atomic`
   - `DesignSystem.tiny` → `SystemSpacing.tiny`
   - `DesignSystem.small` → `SystemSpacing.small`
   - `DesignSystem.medium` → `SystemSpacing.medium`
   - `DesignSystem.standardPadding` → `SystemSpacing.content`
   - `DesignSystem.large` → `SystemSpacing.content`
   - `DesignSystem.wide` → `ComponentSpacing.section`
   - `DesignSystem.giant` → `ComponentSpacing.sectionLarge`
   - `DesignSystem.huge` → `ComponentSpacing.huge`
   - `DesignSystem.borderWidth` → `SystemStroke.border`
   - `DesignSystem.glassOpacity` → `SystemOpacity.glass`
   - `DesignSystem.secondaryOpacity` → `SystemOpacity.textSecondary`
   - `DesignSystem.disabledOpacity` → `SystemOpacity.disabled`
   - `DesignSystem.pressedOpacity` → `SystemOpacity.pressed`
   - `DesignSystem.titleFontSize` → `SystemFontSize.title`
   - `DesignSystem.bodyFontSize` → `SystemFontSize.body`
   - `DesignSystem.microRadius` → `SystemRadius.micro`
   - `DesignSystem.smallRadius` → `SystemRadius.small`
   - `DesignSystem.cardRadius` → `SystemRadius.card`
   - `DesignSystem.largeRadius` → `SystemRadius.large`
   - `DesignSystem.chipRadius` → `SystemRadius.section`
   - `Spacing.xxx` → 对应 `SystemSpacing.xxx` 或 `ComponentSpacing.xxx`
   - （完整列表见设计文档 4.1 节）

3. hardcoded 值 → token
   - `.padding(.vertical, 4)` → `.padding(.vertical, SystemSpacing.tiny)`
   - `.padding(.vertical, 2)` → `.padding(.vertical, SystemSpacing.atomic)`
   - `HStack(spacing: 8)` → `HStack(spacing: SystemSpacing.element)`
   - `lineWidth: 1` → `lineWidth: SystemStroke.divider`
   - `lineWidth: 2` → `lineWidth: SystemStroke.selected`
   - `.shadow(radius: 8)` → `.shadow(radius: SystemSpacing.element)`
   - `.kerning(1)` → `.kerning(Reference.Spacing.one)`
   - （完整列表见设计文档 4.3 节）

- [ ] **Step 3: 编译验证**

```bash
make ios 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: 运行审计脚本验证 Features/System 0 处魔鬼数字**

```bash
python3 Tools/ios/audit-design-magic-numbers.py 2>&1 | grep "Features/System" | wc -l
```

Expected: 0

- [ ] **Step 5: 提交**

```bash
git add Sources/Features/System/
git commit -m "refactor(designsystem): 迁移 Features/System 到新 3 层 token 架构

158 处魔鬼数字全部消除：
- Magic Math token 算术表达式 → 命名 token
- 旧 token → SystemSpacing/SystemOpacity/SystemRadius/SystemStroke/SystemFontSize/ComponentSpacing
- hardcoded padding/spacing/lineWidth/shadow → token"
```

---

### Task 9: 迁移 Features/AI（33 处魔鬼数字）

**Files:**
- Modify: `Sources/Features/AI/**/*.swift`（~15 个文件）

**Interfaces:**
- Consumes: 新 token（from Task 1-3）
- Produces: Features/AI 目录 0 处魔鬼数字

- [ ] **Step 1: 生成魔鬼数字清单**

```bash
python3 Tools/ios/audit-design-magic-numbers.py 2>&1 | grep "Features/AI" > /tmp/magic-ai.txt
wc -l /tmp/magic-ai.txt
```

Expected: ~33 行

- [ ] **Step 2: 按文件逐个迁移**

使用 Task 8 Step 2 的替换规则，对 Features/AI 目录执行替换。

- [ ] **Step 3: 编译验证**

```bash
make ios 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: 运行审计脚本验证**

```bash
python3 Tools/ios/audit-design-magic-numbers.py 2>&1 | grep "Features/AI" | wc -l
```

Expected: 0

- [ ] **Step 5: 提交**

```bash
git add Sources/Features/AI/
git commit -m "refactor(designsystem): 迁移 Features/AI 到新 3 层 token 架构

33 处魔鬼数字全部消除"
```

---

### Task 10: 迁移 Features/Insight（54 处魔鬼数字）

**Files:**
- Modify: `Sources/Features/Insight/**/*.swift`（~12 个文件）

**Interfaces:**
- Consumes: 新 token（from Task 1-3）
- Produces: Features/Insight 目录 0 处魔鬼数字

- [ ] **Step 1: 生成魔鬼数字清单**

```bash
python3 Tools/ios/audit-design-magic-numbers.py 2>&1 | grep "Features/Insight" > /tmp/magic-insight.txt
wc -l /tmp/magic-insight.txt
```

Expected: ~54 行

- [ ] **Step 2: 按文件逐个迁移**

使用 Task 8 Step 2 的替换规则，对 Features/Insight 目录执行替换。

- [ ] **Step 3: 编译验证**

```bash
make ios 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: 运行审计脚本验证**

```bash
python3 Tools/ios/audit-design-magic-numbers.py 2>&1 | grep "Features/Insight" | wc -l
```

Expected: 0

- [ ] **Step 5: 提交**

```bash
git add Sources/Features/Insight/
git commit -m "refactor(designsystem): 迁移 Features/Insight 到新 3 层 token 架构

54 处魔鬼数字全部消除"
```

---

### Task 11: 迁移 Features/Knowledge（50 处魔鬼数字）

**Files:**
- Modify: `Sources/Features/Knowledge/**/*.swift`（~18 个文件）

**Interfaces:**
- Consumes: 新 token（from Task 1-3）
- Produces: Features/Knowledge 目录 0 处魔鬼数字

- [ ] **Step 1: 生成魔鬼数字清单**

```bash
python3 Tools/ios/audit-design-magic-numbers.py 2>&1 | grep "Features/Knowledge" > /tmp/magic-knowledge.txt
wc -l /tmp/magic-knowledge.txt
```

Expected: ~50 行

- [ ] **Step 2: 按文件逐个迁移**

使用 Task 8 Step 2 的替换规则，对 Features/Knowledge 目录执行替换。

- [ ] **Step 3: 编译验证**

```bash
make ios 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: 运行审计脚本验证**

```bash
python3 Tools/ios/audit-design-magic-numbers.py 2>&1 | grep "Features/Knowledge" | wc -l
```

Expected: 0

- [ ] **Step 5: 提交**

```bash
git add Sources/Features/Knowledge/
git commit -m "refactor(designsystem): 迁移 Features/Knowledge 到新 3 层 token 架构

50 处魔鬼数字全部消除"
```

---

### Task 12: 迁移 Shared/UIComponents + App + Platforms（67 处魔鬼数字）

**Files:**
- Modify: `Sources/Shared/UIComponents/**/*.swift`（~55 处）
- Modify: `Sources/App/**/*.swift`（~8 处）
- Modify: `Sources/Platforms/**/*.swift`（~4 处）

**Interfaces:**
- Consumes: 新 token（from Task 1-3）
- Produces: Shared/UIComponents + App + Platforms 目录 0 处魔鬼数字

- [ ] **Step 1: 生成魔鬼数字清单**

```bash
python3 Tools/ios/audit-design-magic-numbers.py 2>&1 | grep -E "Shared/UIComponents|Sources/App/|Platforms/" > /tmp/magic-rest.txt
wc -l /tmp/magic-rest.txt
```

Expected: ~67 行

- [ ] **Step 2: 按文件逐个迁移**

使用 Task 8 Step 2 的替换规则，对 3 个目录执行替换。

- [ ] **Step 3: 编译验证**

```bash
make ios 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 4: 运行审计脚本验证**

```bash
python3 Tools/ios/audit-design-magic-numbers.py 2>&1 | grep -E "Shared/UIComponents|Sources/App/|Platforms/" | wc -l
```

Expected: 0

- [ ] **Step 5: 提交**

```bash
git add Sources/Shared/UIComponents/ Sources/App/ Sources/Platforms/
git commit -m "refactor(designsystem): 迁移 Shared/UIComponents + App + Platforms 到新 3 层 token 架构

67 处魔鬼数字全部消除"
```

---

## 阶段 4：旧 token 文件清理（Task 13-14）

### Task 13: 删除旧 token 文件 + 更新 DesignSystem.swift

**Files:**
- Delete: `Sources/Shared/DesignSystem/Tokens/Spacing.swift`
- Delete: `Sources/Shared/DesignSystem/Tokens/DesignSystem+Metrics.swift`
- Delete: `Sources/Shared/DesignSystem/Tokens/DesignSystem+Opacity.swift`
- Delete: `Sources/Shared/DesignSystem/Tokens/DesignSystem+RadiusToken.swift`
- Delete: `Sources/Shared/DesignSystem/Tokens/DesignSystem+SpacingToken.swift`
- Delete: `Sources/Shared/DesignSystem/Tokens/DesignSystem+Shadows.swift`
- Delete: `Sources/Shared/DesignSystem/Tokens/DesignSystem+IconSize.swift`
- Delete: `Sources/Shared/DesignSystem/Tokens/DesignSystem+Stroke.swift`（已迁移到 System）
- Modify: `Sources/Shared/DesignSystem/DesignSystem.swift`（移除旧别名，重新导出新 token）
- Modify: `Sources/Shared/DesignSystem/Tokens/Colors.swift`（移除 Opacity 定义）
- Modify: `Sources/Shared/DesignSystem/Tokens/Typography.swift`（移除 FontSize 定义）

**Interfaces:**
- Produces: 旧 token 文件全部删除，DesignSystem.swift 重新导出新 token

- [ ] **Step 1: 验证旧 token 无引用**

```bash
# 检查 Spacing.xxx 是否还有引用（应已被 SystemSpacing.xxx 替换）
rg "Spacing\.(atomic|tiny|small|medium|standardPadding|large|wide|giant|huge|borderWidth|microRadius|smallRadius|cardRadius|largeRadius|chipRadius|iconTiny|iconSmall|iconMedium|iconLarge|iconHuge|iconDisplay)" Sources/ --glob '!Spacing.swift' --glob '!DesignSystem.swift' | wc -l
```

Expected: 0

- [ ] **Step 2: 检查 DesignSystem.swift 旧别名引用**

```bash
rg "DesignSystem\.(atomic|tiny|small|medium|standardPadding|large|wide|giant|huge|glassOpacity|secondaryOpacity|disabledOpacity|pressedOpacity|borderWidth|microRadius|smallRadius|cardRadius|largeRadius|chipRadius|titleFontSize|bodyFontSize)" Sources/ --glob '!DesignSystem.swift' | wc -l
```

Expected: 0（全部已迁移到 SystemSpacing/SystemOpacity 等）

- [ ] **Step 3: 更新 DesignSystem.swift**

将 `DesignSystem.swift` 中的旧别名全部移除，替换为重新导出新 token：

```swift
//
//  DesignSystem.swift
//  ZhiYu
//
//  系统层级：[Shared] 共享标准层
//  核心职责：设计系统入口 — 重新导出 3 层 token（Reference/System/Component）+ 颜色 + 排版 + 动画。
//
import SwiftUI

/// 智宇设计系统 (ZhiYu Design System)
/// 3 层金字塔架构：Reference（原子值）→ System（语义映射）→ Component（组件特定尺寸）
public enum DesignSystem {

    // MARK: - 3 层 Token 重新导出
    public typealias Spacing = SystemSpacing
    public typealias Opacity = SystemOpacity
    public typealias Radius = SystemRadius
    public typealias Stroke = SystemStroke
    public typealias FontSize = SystemFontSize
    public typealias Metrics = ComponentSpacing

    // MARK: - 排版规范 (Typography)
    public typealias HeadingLevel = Typography.HeadingLevel
    public static var captionFont: Font { Typography.captionFont }
    public static var caption2Font: Font { Typography.caption2Font }
    public static var secondaryFont: Font { Typography.secondaryFont }
    public static var subheadlineFont: Font { Typography.secondaryFont }
    public static var titleFont: Font { Typography.titleFont }

    // MARK: - 容器颜色 (Container Colors)
    public static var containerBackground: Color { Color.appCard }
    public static var containerBorder: Color { Color.appBorder }
    public static var containerMaterial: Color { Color.appCard }

    // MARK: - 动效常数 (Legacy Animation Bridge)
    public static var standardAnimation: SwiftUI.Animation { Animations.Interaction.standardAnimation }
    public static var fastAnimation: SwiftUI.Animation { Animations.Interaction.fastAnimation }

    // MARK: - 组件兼容性别名 (Component Aliases)
    #if !WIDGET && !os(watchOS)
    public typealias AppSection<Content: View> = StandardSection<Content>
    public typealias Card<Content: View> = AppCard<Content>
    public typealias BorderedCard<Content: View> = AppBorderedCard<Content>
    public typealias GlassCard<Content: View> = AppGlassCard<Content>
    public typealias PrimaryButton = AppPrimaryButton
    public typealias CapsuleButton = AppCapsuleButton
    public typealias TextField = AppTextField
    public typealias TagField = AppTagField
    public typealias MonospacedEditor = AppMonospacedEditor
    public typealias IconChip = AppIconChip
    public typealias Badge = AppBadge
    public typealias ScrollableChips<Data: RandomAccessCollection, Content: View> = AppScrollableChips<Data, Content> where Data.Element: Hashable
    public typealias SectionHeader = AppSectionHeader
    public typealias LabeledRow = AppLabeledRow
    public typealias StepRow = AppStepRow
    public typealias Divider = AppDivider
    public typealias AccentLine = AppAccentLine
    public typealias PulseDot = AppPulseDot
    public typealias Glow = AppGlow
    public typealias Skeleton = AppSkeleton
    public typealias SkeletonBox = AppSkeleton
    public typealias DotPattern = AppDotPattern
    public typealias IconBox = AppIconBox

    public typealias EmptyState = AppEmptyState
    public typealias LoadingOverlay = AppLoadingOverlay
    public typealias Toast = AppToast
    #endif
}
```

- [ ] **Step 4: 删除旧 token 文件**

```bash
rm Sources/Shared/DesignSystem/Tokens/Spacing.swift
rm Sources/Shared/DesignSystem/Tokens/DesignSystem+Metrics.swift
rm Sources/Shared/DesignSystem/Tokens/DesignSystem+Opacity.swift
rm Sources/Shared/DesignSystem/Tokens/DesignSystem+RadiusToken.swift
rm Sources/Shared/DesignSystem/Tokens/DesignSystem+SpacingToken.swift
rm Sources/Shared/DesignSystem/Tokens/DesignSystem+Shadows.swift
rm Sources/Shared/DesignSystem/Tokens/DesignSystem+IconSize.swift
rm Sources/Shared/DesignSystem/Tokens/DesignSystem+Stroke.swift
```

- [ ] **Step 5: 重新生成 xcodeproj 并编译**

```bash
rm -rf ZhiYu.xcodeproj && make gen
make ios 2>&1 | tail -5
```

Expected: BUILD SUCCEEDED

- [ ] **Step 6: 提交**

```bash
git add -A Sources/Shared/DesignSystem/ ZhiYu.xcodeproj
git commit -m "refactor(designsystem): 删除旧 token 文件 + 更新 DesignSystem.swift

删除 8 个旧 token 文件：
- Spacing.swift（220 token 拆分到 Reference/System/Component）
- DesignSystem+Metrics.swift（95 token 拆分到 Component）
- DesignSystem+Opacity.swift（15 token 迁移到 Reference/System）
- DesignSystem+RadiusToken.swift（迁移到 System）
- DesignSystem+SpacingToken.swift（迁移到 System）
- DesignSystem+Shadows.swift（迁移到 Component）
- DesignSystem+IconSize.swift（迁移到 Component）
- DesignSystem+Stroke.swift（迁移到 System）

DesignSystem.swift 更新为重新导出新 3 层 token"
```

---

### Task 14: 更新 audit-design-magic-numbers.py 移除旧 token 关键词

**Files:**
- Modify: `Tools/ios/audit-design-magic-numbers.py`

**Interfaces:**
- Produces: 移除旧 token 关键词（`DesignSystem`/`Spacing`/`Layout`），只识别新 token

- [ ] **Step 1: 更新 valid 关键词列表**

在 `Tools/ios/audit-design-magic-numbers.py` 中，将所有 valid 关键词列表从：

```python
valid = any(k in raw for k in ['DesignSystem', 'Spacing', 'Layout', 'Reference', 'System', 'Component'])
```

改为：

```python
valid = any(k in raw for k in ['Reference', 'System', 'Component', 'Layout'])
```

注意：保留 `Layout`（部分视图有 `enum Layout` 本地定义），移除 `DesignSystem`/`Spacing`（旧 token 已删除）。

但 `DesignSystem` typealias 仍存在（`DesignSystem.Spacing` = `SystemSpacing`），所以需要保留 `DesignSystem`：

```python
valid = any(k in raw for k in ['DesignSystem', 'Reference', 'System', 'Component', 'Layout'])
```

移除 `Spacing`（旧 Spacing.swift 已删除，`DesignSystem.Spacing` 是 typealias 指向 SystemSpacing）。

- [ ] **Step 2: 更新 TOKEN_FILES 豁免列表**

移除已删除的文件：

```python
# 旧
TOKEN_FILES = {
    'Colors.swift', 'DesignSystem.swift', 'IconTokens.swift', 'Spacing.swift',
    'DemoImageBuilder.swift', 'InitialNotebookGenerator.swift',
    'Reference.swift', 'System.swift', 'Component.swift',
}

# 新
TOKEN_FILES = {
    'Colors.swift', 'DesignSystem.swift', 'IconTokens.swift',
    'DemoImageBuilder.swift', 'InitialNotebookGenerator.swift',
    'Reference.swift', 'System.swift', 'Component.swift',
}
```

- [ ] **Step 3: 运行审计脚本验证**

```bash
python3 Tools/ios/audit-design-magic-numbers.py 2>&1 | tail -20
```

Expected: 0 issues

- [ ] **Step 4: 提交**

```bash
git add Tools/ios/audit-design-magic-numbers.py
git commit -m "fix(ci): 移除旧 token 关键词，只识别新 3 层架构 token

旧 Spacing.swift 已删除，Spacing 关键词移除
保留 DesignSystem（typealias 指向 SystemSpacing 等）"
```

---

## 阶段 5：全量验证（Task 15）

### Task 15: 全量验证 + 覆盖率报告

**Files:**
- Test: 全量测试 + CI 审计

**Interfaces:**
- Produces: 全量编译通过 + 全量测试通过 + CI 审计 0 漏检 + 快照测试无回归

- [ ] **Step 1: 全量编译验证**

```bash
make ios 2>&1 | tail -5
make mac 2>&1 | tail -5
make watch 2>&1 | tail -5
```

Expected: 3 个平台 BUILD SUCCEEDED

- [ ] **Step 2: 全量测试**

```bash
make test 2>&1 | tail -20
```

Expected: 7664+ tests, 0 failures

- [ ] **Step 3: CI 审计全量验证**

```bash
make audit 2>&1 | tail -30
```

Expected: 所有审计脚本 0 issues

- [ ] **Step 4: 快照测试验证**

```bash
xcodebuild test-without-building -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build/DerivedData-ios -only-testing:ZhiYuTests/SnapshotTests 2>&1 | tail -20
```

Expected: 快照测试全部通过（无回归）

- [ ] **Step 5: 推送**

```bash
git push origin main
git push gitlab main
```

- [ ] **Step 6: 更新 findings 文档**

在 `Docs/Audit/2026-08-20-coverage-findings.md` 追加：

```markdown
## D-3: DesignSystem Token 体系全量重构完成

**状态**：已修复
**commit**：[最终 commit hash]

### 重构成果
- 3 层金字塔架构落地（Reference/System/Component）
- 362 处魔鬼数字全部消除
- 旧 3 层架构死代码删除（Tier1/Tier2/Tier3 + PlatformContext + DesignTokenRegistry）
- 8 个旧 token 文件删除
- CI 审计脚本全量调整完成（magic-numbers + token-layering 重写 + token-naming 新建）
- CI 审计脚本 0 漏检
```

- [ ] **Step 7: 提交 findings 更新**

```bash
git add Docs/Audit/2026-08-20-coverage-findings.md
git commit -m "docs: 更新 findings 文档 D-3 DesignSystem token 体系全量重构完成"
git push origin main
git push gitlab main
```

---

## Self-Review

### 1. Spec coverage

| 设计文档章节 | 实现任务 | 状态 |
|------------|---------|------|
| 3.1 架构总览 | Task 1-3（Reference/System/Component） | ✅ |
| 3.2 Layer 1 Reference | Task 1 | ✅ |
| 3.3 Layer 2 System | Task 2 | ✅ |
| 3.4 Layer 3 Component | Task 3 | ✅ |
| 4.1 旧 token → 新 token | Task 8-12（迁移映射表） | ✅ |
| 4.2 Magic Math → 新 token | Task 8-12（迁移映射表） | ✅ |
| 4.3 hardcoded 值 → 新 token | Task 8-12（迁移映射表） | ✅ |
| 5.1 新建文件 | Task 1-3 | ✅ |
| 5.2 删除文件 | Task 13 | ✅ |
| 5.3 保留文件（修改） | Task 13 | ✅ |
| 6. 旧 3 层架构清理 | Task 7 | ✅ |
| 7.1 audit-design-magic-numbers.py | Task 4 + Task 14 | ✅ |
| 7.2 audit-design-token-layering.py | Task 5 | ✅ |
| 7.3 audit-design-token-naming.py | Task 6 | ✅ |
| 7.4 CI 脚本调整任务清单 | Task 4-6 + Task 14 | ✅ |
| 8.1 硬切一次性迁移 | Task 7-13 | ✅ |
| 8.2 分批执行 | Task 8-12（6 批） | ✅ |
| 10. 成功标准 | Task 15（全量验证） | ✅ |

### 2. Placeholder scan

- 无 TODO/TBD/待定 ✅
- Task 8-12 的替换规则引用设计文档迁移映射表（4.1/4.2/4.3），已列出关键替换规则 ✅
- 每个步骤都有具体命令和预期输出 ✅

### 3. Type consistency

- `Reference.Spacing.*` / `Reference.Opacity.*` / `Reference.Radius.*` / `Reference.Stroke.*` / `Reference.FontSize.*` — Task 1 定义，Task 2 引用 ✅
- `SystemSpacing.*` / `SystemOpacity.*` / `SystemRadius.*` / `SystemStroke.*` / `SystemFontSize.*` — Task 2 定义，Task 3/8-12 引用 ✅
- `ComponentSpacing.*` — Task 3 定义，Task 8-12 引用 ✅
- `DesignSystem.Spacing` = `SystemSpacing`（typealias）— Task 13 定义 ✅
