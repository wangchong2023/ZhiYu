# DesignSystem Token 体系全量重构设计

> **日期**：2026-08-23
> **状态**：已批准，待编写实现计划
> **决策**：全量重构 + Tailwind 严格 10 档 + Magic Math 全部命名 token 化 + 硬切一次性迁移

## 1. 背景与问题

### 1.1 现状

当前 DesignSystem token 体系存在 **445+ 个 token**，分布在 7 个文件中：

| 文件 | token 数量 | 职责 |
|------|-----------|------|
| `Spacing.swift` | 220 | 间距、圆角、图标尺寸、布局模式、组件尺寸 |
| `DesignSystem+Metrics.swift` | 95 | 仪表盘指标、快照尺寸、组件尺寸 |
| `Colors.swift` | 36 (Opacity) | 透明度、颜色 |
| `DesignSystem+Opacity.swift` | 15 | 透明度（与 Colors 重复） |
| `DesignSystem.swift` | 63 (别名) | 旧命名兼容别名 |
| `Typography.swift` | ~20 | 字号、字重 |
| 其他 | ~15 | 动画、阴影、图标 |

### 1.2 根本问题

| 问题 | 证据 | 影响 |
|------|------|------|
| **token 三处重复定义** | `glassOpacity` 在 `Colors`/`DesignSystem+Opacity`/`DesignSystem.swift` 各定义一次 | 维护负担，修改需同步 3 处 |
| **原子与语义混层** | `Spacing.atomic=2`（原子）和 `Spacing.Metrics.heroValueSize=32`（组件级）在同一 enum | 无法区分哪些是基础值，哪些是组件特定值 |
| **Magic Math 暴露粒度缺口** | `glassOpacity * 2`(10次)、`atomic / 2.0`(4次) | 说明现有原子 token 粒度不够，但无限扩展会爆炸 |
| **hardcoded spacing 集中在 2/4/8/10/12** | 90 处 container spacing 中 58 处是 2/4/8 — 已有 token 但没用 | token 命名不够直观，开发者倾向硬编码 |

### 1.3 CI 审计结果

修复 `audit-design-magic-numbers.py` 6 大类漏检漏洞后，检出 **362 处魔鬼数字**：

| 类别 | 数量 | 示例 |
|------|------|------|
| Magic Math token 算术表达式 | 120 | `glassOpacity * 2`、`atomic / 2.0` |
| hardcoded padding (labeled) | 99 | `.padding(.vertical, 4)` |
| hardcoded container spacing | 90 | `HStack(spacing: 8)` |
| hardcoded lineWidth | 29 | `.stroke(lineWidth: 1)` |
| Magic Math View 算术表达式 | 15 | `Spacing.Action.buttonHeight * 2.0 + Spacing.atomic` |
| hardcoded kerning/tracking | 4 | `.kerning(1)` |
| hardcoded shadow radius | 3 | `.shadow(radius: 8)` |
| hardcoded shadow offset | 2 | `.shadow(y: 4)` |

**按目录分布**：Features/System 158、Shared/UIComponents 55、Features/Insight 54、Features/Knowledge 50、Features/AI 33、App 8、Platforms 4。

## 2. 业界标杆对比

| 维度 | Tailwind CSS | Material 3 | Apple HIG | **重构方案** | 对齐度 |
|------|-------------|------------|-----------|------------|--------|
| 分层架构 | 2层（Reference→System） | 3层（Reference→System→Component） | 隐式2层 | 3层 | ✅ 对齐 Material 3 |
| Spacing 档位 | 10档（0/0.5/1/2/3/4/6/8/12/16） | 13档（0-200dp） | 无固定 | 10档 | ✅ 对齐 Tailwind |
| Opacity 档位 | 11档（0-100） | 12档（0-1.0） | 无固定 | 13档 | ✅ 对齐 |
| Radius 档位 | 8档 | 6档 | 无固定 | 9档 | ✅ 对齐 Tailwind |
| FontSize 档位 | 9档 | 15档 | 11档 | 13档 | ✅ 对齐 |
| 禁止算术派生 | ✅ 严格 | ✅ 严格 | N/A | ✅ 严格 | ✅ 对齐 |
| 统一尺度复用 | ✅ 一套尺度多处复用 | ✅ | N/A | ✅ | ✅ 对齐 Tailwind |

## 3. 设计：3 层金字塔架构

### 3.1 架构总览

```
┌─────────────────────────────────────────────┐
│  Layer 3: Component（组件特定尺寸）           │
│  - 大值（20/24/32/40/48/64）                  │
│  - 组件语义（cardPadding/listRowGap）         │
│  - 组件特定尺寸（toolbarHeight/buttonHeight） │
├─────────────────────────────────────────────┤
│  Layer 2: System（语义映射层）                │
│  - 交互状态（glass/disabled/pressed）         │
│  - 文本层级（textPrimary/textSecondary）      │
│  - 布局语义（atomic/tiny/element/content）    │
│  - 视图代码主要引用此层                       │
├─────────────────────────────────────────────┤
│  Layer 1: Reference（原子值层，严格有限）      │
│  - Spacing: 10档（对齐 Tailwind）             │
│  - Opacity: 13档                              │
│  - Radius: 9档                                │
│  - Stroke: 8档                                │
│  - FontSize: 13档                             │
│  - 禁止扩展，禁止算术派生                      │
└─────────────────────────────────────────────┘
```

**依赖规则**：Component → System → Reference，严禁反向依赖。

### 3.2 Layer 1 — Reference（原子值层）

严格有限的原子值集，**不允许扩展**。所有视觉值必须从这里取。

```swift
// Sources/Shared/DesignSystem/Tokens/Reference.swift
public enum Reference {
    // MARK: - Spacing (10档，对齐 Tailwind 默认 scale)
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

    // MARK: - Opacity (13档)
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

    // MARK: - Radius (9档)
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

    // MARK: - Stroke (8档)
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

    // MARK: - FontSize (13档)
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

**关键规则**：
- 原子集**严格有限**，新增需设计审查
- **禁止算术派生** — `glassOpacity * 2` 必须替换为命名 token
- 所有数值映射到原子集，Magic Math 结果值向最近档舍入（偏差 ≤ 0.05 可接受）

### 3.3 Layer 2 — System（语义映射层）

将原子值映射为语义名，按用途分类。**视图代码主要引用此层**。

```swift
// Sources/Shared/DesignSystem/Tokens/System.swift
public enum SystemSpacing {
    // 直接映射 Reference，一套尺度多处复用
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
    // 无 cardPadding/listRowGap — 这些是 Component 层职责
}

public enum SystemOpacity {
    // 交互状态
    public static let hidden: Double = Reference.Opacity.zero
    public static let ghost: Double = Reference.Opacity.five
    public static let faint: Double = Reference.Opacity.ten
    public static let glass: Double = Reference.Opacity.fifteen
    public static let glassStrong: Double = Reference.Opacity.thirty    // glass*2(0.3) 命名化
    public static let glassSubtle: Double = Reference.Opacity.twenty    // glass/1.5*2(0.2) 命名化
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
    public static let display: CGFloat = Reference.FontSize.display
    public static let hero: CGFloat = Reference.FontSize.hero
}
```

### 3.4 Layer 3 — Component（组件特定尺寸层）

大值 + 组件特定尺寸 + 组件语义映射。

```swift
// Sources/Shared/DesignSystem/Tokens/Component.swift
public enum ComponentSpacing {
    // 大值（超出 Layer 1 10档范围）
    public static let section: CGFloat = 20          // 区段间
    public static let sectionLarge: CGFloat = 24     // 大区段
    public static let huge: CGFloat = 32             // 巨大
    public static let ultra: CGFloat = 40            // 超大
    public static let massive: CGFloat = 48          // 极大
    public static let colossal: CGFloat = 64         // 超极大

    // 组件语义（从 System 映射）
    public static let cardPadding: CGFloat = SystemSpacing.content      // 16
    public static let listRowGap: CGFloat = SystemSpacing.element       // 8
    public static let iconTextGap: CGFloat = SystemSpacing.small        // 6
    public static let buttonInternalPadding: CGFloat = SystemSpacing.medium // 12
    public static let chipPadding: CGFloat = SystemSpacing.tiny         // 4

    // 组件特定尺寸
    public static let toolbarHeight: CGFloat = 44
    public static let buttonHeight: CGFloat = 44
    public static let compactButtonHeight: CGFloat = 32
    public static let inputFieldHeight: CGFloat = 50
    public static let minTouchTarget: CGFloat = 44
    public static let capsuleHeight: CGFloat = 28
    public static let inputBarHeight: CGFloat = 54

    // 图标尺寸（组件特定）
    public static let iconCompact: CGFloat = 18      // largeIconSize/1.5
    public static let iconStandard: CGFloat = 22      // largeIconSize*0.8
    public static let iconLarge: CGFloat = 24          // iconDisplay/2
    public static let iconDisplay: CGFloat = 48
    public static let iconHuge: CGFloat = 64
}
```

## 4. 迁移映射表

### 4.1 旧 token → 新 token

| 旧 token | 新 token | 值 |
|---------|---------|---|
| `Spacing.atomic` | `SystemSpacing.atomic` | 2 |
| `Spacing.tiny` | `SystemSpacing.tiny` | 4 |
| `Spacing.small` | `SystemSpacing.small` | 6 |
| `Spacing.medium` | `SystemSpacing.medium` | 12 |
| `Spacing.standardPadding` | `SystemSpacing.content` | 16 |
| `Spacing.large` | `SystemSpacing.content` | 16 |
| `Spacing.wide` | `ComponentSpacing.section` | 20 |
| `Spacing.giant` | `ComponentSpacing.sectionLarge` | 24 |
| `Spacing.huge` | `ComponentSpacing.huge` | 32 |
| `Spacing.borderWidth` | `SystemStroke.border` | 0.8 |
| `Spacing.microRadius` | `SystemRadius.micro` | 2 |
| `Spacing.smallRadius` | `SystemRadius.small` | 8 |
| `Spacing.cardRadius` | `SystemRadius.card` | 12 |
| `Spacing.largeRadius` | `SystemRadius.large` | 16 |
| `Spacing.chipRadius` | `SystemRadius.section` | 20 |
| `DesignSystem.glassOpacity` | `SystemOpacity.glass` | 0.15 |
| `DesignSystem.secondaryOpacity` | `SystemOpacity.textSecondary` | 0.8 |
| `DesignSystem.disabledOpacity` | `SystemOpacity.disabled` | 0.4 |
| `DesignSystem.pressedOpacity` | `SystemOpacity.pressed` | 0.9 |
| `DesignSystem.dimmedOpacity` | `SystemOpacity.overlay` | 0.6 |
| `DesignSystem.fullOpacity` | `SystemOpacity.active` | 1.0 |
| `DesignSystem.subtleOpacity` | `Reference.Opacity.seventy` | 0.7 |
| `DesignSystem.halfOpacity` | `Reference.Opacity.fifty` | 0.5 |
| `DesignSystem.shadowOpacity` | `Reference.Opacity.ten` | 0.1 |
| `DesignSystem.subtleFillOpacity` | `Reference.Opacity.ten` | 0.1 |
| `DesignSystem.surfaceOpacity` | `SystemOpacity.textSecondary` | 0.8 |
| `DesignSystem.cardOpacity` | `Reference.Opacity.seventy` | 0.7 |
| `DesignSystem.translucentOpacity` | `Reference.Opacity.seventy` | 0.7 |
| `DesignSystem.softOpacity` | `Reference.Opacity.forty` | 0.4 |
| `DesignSystem.ghostOpacity` | `Reference.Opacity.five` | 0.05 |
| `DesignSystem.coachMarkBackgroundOpacity` | `Reference.Opacity.sixty` | 0.6 |
| `DesignSystem.accentStrokeOpacity` | `Reference.Opacity.thirty` | 0.3 |
| `DesignSystem.dividerOpacity` | `Reference.Opacity.fifty` | 0.5 |
| `DesignSystem.titleFontSize` | `SystemFontSize.title` | 24 |
| `DesignSystem.bodyFontSize` | `SystemFontSize.body` | 16 |
| `DesignSystem.headlineFontSize` | `SystemFontSize.headline` | 18 |
| `DesignSystem.captionFontSize` | `SystemFontSize.caption` | 12 |
| `DesignSystem.displayFontSize` | `SystemFontSize.display` | 32 |

### 4.2 Magic Math → 新 token

| Magic Math 表达式 | 计算值 | 新 token | 舍入说明 |
|------------------|-------|---------|---------|
| `glassOpacity * 2` (10处) | 0.3 | `SystemOpacity.glassStrong` | 精确匹配 |
| `glassOpacity / 3` (7处) | 0.05 | `SystemOpacity.ghost` | 精确匹配 |
| `glassOpacity / 2` (5处) | 0.075 | `SystemOpacity.faint` (0.1) | 最近档舍入 |
| `glassOpacity / 1.5` (4处) | 0.1 | `SystemOpacity.faint` | 精确匹配 |
| `glassOpacity * 1.5` (2处) | 0.225 | `SystemOpacity.glassSubtle` (0.2) | 最近档舍入 |
| `glassOpacity * 0.8` (2处) | 0.12 | `Reference.Opacity.ten` (0.1) | 最近档舍入 |
| `glassOpacity * 0.5` (2处) | 0.075 | `SystemOpacity.faint` (0.1) | 最近档舍入 |
| `glassOpacity * 3` (1处) | 0.45 | `Reference.Opacity.forty` (0.4) | 最近档舍入 |
| `glassOpacity * 2.5` (1处) | 0.375 | `Reference.Opacity.forty` (0.4) | 最近档舍入 |
| `glassOpacity * 1.2` (1处) | 0.18 | `Reference.Opacity.twenty` (0.2) | 最近档舍入 |
| `glassOpacity / 1` (1处) | 0.15 | `SystemOpacity.glass` | 精确匹配 |
| `glassOpacity * 1` (1处) | 0.15 | `SystemOpacity.glass` | 精确匹配 |
| `borderWidth * 2` (4处) | 1.6 | `SystemStroke.oneHalf` (1.5) | 最近档舍入 |
| `borderWidth * 4` (1处) | 3.2 | `SystemStroke.three` | 最近档舍入 |
| `borderWidth * 0.8` (1处) | 0.64 | `SystemStroke.half` (0.5) | 最近档舍入 |
| `atomic / 2.0` (4处) | 1.0 | `SystemSpacing.divider` | 精确匹配 |
| `atomic * 2` (3处) | 4 | `SystemSpacing.tiny` | 精确匹配 |
| `atomic * 1.5` (2处) | 3 | `SystemSpacing.tight` | 精确匹配 |
| `tiny * 1.5` (1处) | 6 | `SystemSpacing.small` | 精确匹配 |
| `titleFontSize * 1.2` (2处) | 28.8 | `Reference.FontSize.largeTitle` (28) | 最近档舍入 |
| `displayFontSize * 1.5` (2处) | 48 | `Reference.FontSize.mega` | 精确匹配 |
| `displayFontSize * 1.3` (1处) | 41.6 | `Reference.FontSize.hero` (40) | 最近档舍入 |
| `secondaryOpacity * 0.5` (3处) | 0.4 | `SystemOpacity.disabled` | 精确匹配 |
| `shadowOpacity * 0.4` (2处) | 0.04 | `SystemOpacity.ghost` (0.05) | 最近档舍入 |
| `shadowOpacity * 1.5` (1处) | 0.15 | `SystemOpacity.glass` | 精确匹配 |
| `shadowOpacity / 2.5` (1处) | 0.04 | `SystemOpacity.ghost` (0.05) | 最近档舍入 |
| `disabledOpacity * 2` (2处) | 0.8 | `SystemOpacity.textSecondary` | 精确匹配 |
| `disabledOpacity * 1.33` (1处) | 0.532 | `Reference.Opacity.fifty` (0.5) | 最近档舍入 |
| `disabledOpacity * 0.5` (1处) | 0.2 | `Reference.Opacity.twenty` | 精确匹配 |
| `dimmedOpacity * 0.75` (1处) | 0.45 | `Reference.Opacity.forty` (0.4) | 最近档舍入 |
| `dimmedOpacity * 0.6` (1处) | 0.36 | `Reference.Opacity.forty` (0.4) | 最近档舍舍入 |
| `dimmedOpacity * 0.5` (1处) | 0.3 | `Reference.Opacity.thirty` | 精确匹配 |
| `dimmedOpacity * 0.25` (1处) | 0.15 | `SystemOpacity.glass` | 精确匹配 |
| `subtleOpacity * 1.2` (1处) | 0.84 | `Reference.Opacity.eighty` (0.8) | 最近档舍入 |
| `subtleOpacity * 0.66` (1处) | 0.462 | `Reference.Opacity.fifty` (0.5) | 最近档舍入 |
| `subtleFillOpacity * 0.8` (1处) | 0.08 | `Reference.Opacity.ten` (0.1) | 最近档舍入 |
| `fullOpacity * 0.9` (1处) | 0.9 | `SystemOpacity.pressed` | 精确匹配 |
| `fullOpacity * 0.7` (1处) | 0.7 | `Reference.Opacity.seventy` | 精确匹配 |
| `fullOpacity * 0.5` (1处) | 0.5 | `Reference.Opacity.fifty` | 精确匹配 |
| `ghostOpacity * 3` (1处) | 0.03 | `Reference.Opacity.five` (0.05) | 最近档舍入 |
| `loosePadding * 1.5` (1处) | 36 | `ComponentSpacing.huge` (32) | 最近档舍入 |
| `largeIconSize / 1.5` (1处) | 18.67 | `ComponentSpacing.iconCompact` (18) | Component 层新增图标尺寸 token |
| `largeIconSize * 0.8` (1处) | 22.4 | `ComponentSpacing.iconStandard` (22) | Component 层新增图标尺寸 token |
| `iconDisplay / 2` (1处) | 24 | `ComponentSpacing.iconLarge` (24) | Component 层新增图标尺寸 token |

### 4.3 hardcoded 值 → 新 token

| hardcoded 值 | 出现次数 | 新 token |
|-------------|---------|---------|
| `spacing: 2` | 23 | `SystemSpacing.atomic` |
| `spacing: 4` | 18 | `SystemSpacing.tiny` |
| `spacing: 8` | 17 | `SystemSpacing.element` |
| `spacing: 10` | 10 | `SystemSpacing.medium` (12) 最近档 |
| `spacing: 6` | 6 | `SystemSpacing.small` |
| `spacing: 12` | 4 | `SystemSpacing.medium` |
| `spacing: 3` | 3 | `SystemSpacing.tight` |
| `spacing: 14` | 3 | `SystemSpacing.medium` (12) 最近档 |
| `spacing: 1` | 3 | `SystemSpacing.divider` |
| `spacing: 20` | 2 | `ComponentSpacing.section` |
| `padding(.vertical, 4)` | 17 | `SystemSpacing.tiny` |
| `padding(.vertical, 2)` | 17 | `SystemSpacing.atomic` |
| `padding(.vertical, 6)` | 12 | `SystemSpacing.small` |
| `padding(.vertical, 10)` | 11 | `SystemSpacing.medium` (12) 最近档 |
| `padding(.vertical, 40)` | 10 | `ComponentSpacing.ultra` |
| `padding(.vertical, 8)` | 8 | `SystemSpacing.element` |
| `padding(.vertical, 12)` | 8 | `SystemSpacing.medium` |
| `padding(.vertical, 16)` | 4 | `SystemSpacing.content` |
| `lineWidth: 1` | 14 | `SystemStroke.divider` |
| `lineWidth: 2` | 6 | `SystemStroke.selected` |
| `lineWidth: 1.5` | 3 | `SystemStroke.emphasis` |
| `lineWidth: 3` | 1 | `SystemStroke.accent` |
| `lineWidth: 10` | 1 | `ComponentSpacing.medium` (需个案) |
| `lineWidth: 0.8` | 1 | `SystemStroke.border` |
| `lineWidth: 0.5` | 1 | `SystemStroke.hairline` |
| `shadow(radius: 8)` | 2 | `SystemSpacing.element` |
| `shadow(radius: 2)` | 1 | `SystemSpacing.atomic` |
| `shadow(y: 4)` | 2 | `SystemSpacing.tiny` |
| `kerning(1)` | 4 | `Reference.Spacing.one` |

## 5. 文件结构

### 5.1 新建文件

```
Sources/Shared/DesignSystem/Tokens/
├── Reference.swift          # Layer 1: 原子值（新建）
├── System.swift             # Layer 2: 语义映射（新建）
├── Component.swift          # Layer 3: 组件特定尺寸（新建）
├── Colors.swift             # 保留（颜色定义，Opacity 迁移到 Reference）
├── Typography.swift         # 保留（Font 定义，FontSize 迁移到 Reference）
├── Animations.swift         # 保留（动画定义）
├── DesignSystem+Icons.swift # 保留（图标定义）
└── DesignSystem.swift       # 保留（入口，重新导出新 token）
```

### 5.2 删除文件

| 文件 | 原因 |
|------|------|
| `Spacing.swift` | 220 个 token 拆分到 Reference/System/Component |
| `DesignSystem+Metrics.swift` | 95 个 token 拆分到 Component |
| `DesignSystem+Opacity.swift` | 15 个 token 迁移到 Reference/System |
| `DesignSystem+RadiusToken.swift` | 迁移到 System |
| `DesignSystem+SpacingToken.swift` | 迁移到 System |
| `DesignSystem+Shadows.swift` | 迁移到 Component |
| `DesignSystem+IconSize.swift` | 迁移到 Component |
| `DesignSystem+Stroke.swift` | 迁移到 System（新建未提交） |

### 5.3 保留文件（修改）

| 文件 | 修改内容 |
|------|---------|
| `Colors.swift` | 移除 Opacity 定义，保留颜色定义 |
| `Typography.swift` | 移除 FontSize 定义，保留 Font 定义 |
| `DesignSystem.swift` | 移除旧别名，重新导出新 token |

## 6. 旧 3 层架构清理

### 6.1 现状

项目已存在一套旧的 3 层 token 架构，但**从未被视图代码实际使用**（死代码）：

| 文件 | 内容 | 实际引用 |
|------|------|---------|
| `DesignSystem+Layering.swift` | Tier1/Tier2/Tier3 enum（121 行） | 仅被 DesignTokenRegistry.swift 内部引用 |
| `PlatformContext.swift` | 平台设备家族 + Environment 注入（85 行） | 仅被 DesignTokenRegistry.swift 内部引用 |
| `DesignTokenRegistry.swift` | 动态 token 解析注册表（109 行） | 无任何视图代码调用 `.shared.resolveSpacing` |

### 6.2 清理决策

**删除全部 3 个文件**，新架构（Reference/System/Component）取代：

1. 删除 `DesignSystem+Layering.swift` — Tier1/Tier2/Tier3 命名被 Reference/System/Component 取代
2. 删除 `PlatformContext.swift` — 平台动态解析未落地，新架构暂不需要（如未来需要跨平台动态解析，再单独设计）
3. 删除 `DesignTokenRegistry.swift` — `resolveSpacing`/`resolveRadius` 从未被调用

### 6.3 清理验证

- 全局搜索 `DesignSystem.Tier` / `DesignTokenRegistry.shared` / `PlatformContext.current` / `SemanticSpacingToken` / `SemanticRadiusToken` 应无任何引用
- 编译通过（删除零影响，因从未被使用）

## 7. CI 审计脚本全量调整

### 7.1 `audit-design-magic-numbers.py` 更新

**当前问题**：`valid` 关键词列表只识别 `DesignSystem`/`Spacing`/`Layout`/`Colors`/`Opacity`，新 token 命名空间 `Reference`/`System`/`Component` 会被误判为魔鬼数字。

**调整内容**：

1. **扩展 valid token 关键词列表**：
   ```python
   # 旧
   valid = any(k in raw for k in ['DesignSystem', 'Spacing', 'Layout'])
   # 新
   valid = any(k in raw for k in [
       'DesignSystem', 'Spacing', 'Layout',  # 兼容期（迁移完成前）
       'Reference', 'System', 'Component',   # 新 3 层架构
       'Colors', 'Opacity', 'Color.theme'    # 颜色/透明度
   ])
   ```

2. **Magic Math 检测扩展**：
   ```python
   # 旧：只检测 DesignSystem/Spacing 开头的算术
   token_math = re.search(r'\b(DesignSystem|Spacing)\.([a-zA-Z0-9_.]+)\s*[\*\/]\s*(\d+\.?\d*)\b', raw)
   # 新：增加 Reference/System/Component
   token_math = re.search(r'\b(DesignSystem|Spacing|Reference|System|Component)\.([a-zA-Z0-9_.]+)\s*[\*\/]\s*(\d+\.?\d*)\b', raw)
   ```

3. **exempt_tokens 扩展**：新架构的 token 定义文件加入豁免
   ```python
   TOKEN_FILES = {
       'Colors.swift', 'DesignSystem.swift', 'IconTokens.swift', 'Spacing.swift',
       'DemoImageBuilder.swift', 'InitialNotebookGenerator.swift',
       'Reference.swift', 'System.swift', 'Component.swift',  # 新增
   }
   ```

4. **迁移完成后**：移除 `DesignSystem`/`Spacing`/`Layout` 旧关键词（硬切完成后旧 token 不再存在）

### 7.2 `audit-design-token-layering.py` 重写

**当前问题**：检查旧的 `DesignSystem+Layering.swift`/`PlatformContext.swift`/`DesignTokenRegistry.swift` 文件和 `Tier1`/`Tier2`/`Tier3` 命名，旧架构删除后全部报错。

**重写内容**：

1. **文件存在性检查**：
   ```python
   REFERENCE_FILE = 'Sources/Shared/DesignSystem/Tokens/Reference.swift'
   SYSTEM_FILE = 'Sources/Shared/DesignSystem/Tokens/System.swift'
   COMPONENT_FILE = 'Sources/Shared/DesignSystem/Tokens/Component.swift'
   # 检查 3 个文件全部存在
   # 检查 enum Reference / enum System / enum Component 定义存在
   ```

2. **依赖方向检查**（严格分层）：
   ```python
   # Reference.swift：禁止引用 System/Component
   # System.swift：必须引用 Reference，禁止引用 Component
   # Component.swift：必须引用 System（可引用 Reference）
   ```

3. **视图代码分层检查**：
   ```python
   # 扫描 Sources/Features/ + Sources/Shared/UIComponents/
   # 禁止视图代码直接引用 Reference.*（必须通过 System/Component）
   # 允许视图代码引用 System.* / Component.*
   ```

4. **旧架构残留检查**：
   ```python
   # 禁止任何文件引用 Tier1/Tier2/Tier3/DesignTokenRegistry/PlatformContext
   # 禁止旧文件存在（DesignSystem+Layering.swift 等）
   ```

### 7.3 新增 `audit-design-token-naming.py`

**职责**：检查 token 命名规范，防止新架构引入新的 Magic Math

1. **token 定义文件内禁止算术表达式**：
   ```python
   # Reference.swift：禁止任何 * / + - 算术（纯原子值）
   # System.swift：禁止 * / 算术（允许 Reference.A + Reference.B 组合）
   # Component.swift：禁止 * / 算术（允许 System.A + System.B 组合）
   ```

2. **视图代码禁止 token 算术**：
   ```python
   # 扫描 Sources/Features/ + Sources/Shared/UIComponents/
   # 禁止 Reference.* * N、System.* * N、Component.* * N
   # 禁止 Reference.* / N、System.* / N、Component.* / N
   ```

3. **hardcoded 值零容忍**：
   ```python
   # 视图代码中 .padding(N)、.frame(width: N)、spacing: N、lineWidth: N 等
   # 必须引用 System.* 或 Component.* token
   ```

### 7.4 CI 脚本调整任务清单

| 脚本 | 操作 | 任务 |
|------|------|------|
| `audit-design-magic-numbers.py` | 修改 | 扩展 valid 关键词 + Magic Math 检测 + exempt_tokens |
| `audit-design-token-layering.py` | 重写 | 检查新 3 层架构文件 + 依赖方向 + 视图分层 + 旧架构残留 |
| `audit-design-token-naming.py` | 新建 | token 命名规范 + 算术表达式禁止 + hardcoded 零容忍 |
| `Makefile` audit 目标 | 修改 | 集成新脚本 |

## 8. 迁移策略

### 8.1 硬切一次性迁移

1. **新建 3 个文件**：Reference.swift / System.swift / Component.swift
2. **全局替换**：660 个 Swift 文件中的旧 token 引用
3. **删除旧文件**：8 个旧 token 文件 + 3 个旧 3 层架构文件
4. **更新 DesignSystem.swift**：重新导出新 token
5. **编译验证**：全量编译通过
6. **CI 审计验证**：0 处魔鬼数字

### 8.2 分批执行

按目录分 6 批：
- 第 1 批：Features/System（158 处）
- 第 2 批：Features/AI（33 处）
- 第 3 批：Features/Insight（54 处）
- 第 4 批：Features/Knowledge（50 处）
- 第 5 批：Shared/UIComponents（55 处）
- 第 6 批：App + Platforms（12 处）

每批编译验证，全部完成后全量验证。

## 9. 风险与缓解

| 风险 | 缓解措施 |
|------|---------|
| 660 个文件迁移量大 | 分 6 批执行，每批编译验证 |
| 舍入导致视觉偏差 | 偏差 ≤ 0.05 可接受，快照测试验证 |
| 旧 token 删除导致编译失败 | 全局替换完成后再删除旧文件 |
| Component 层膨胀 | 组件特定尺寸严格审查，避免随意扩展 |

## 10. 成功标准

- [ ] 3 层金字塔架构落地（Reference/System/Component）
- [ ] 旧 3 层架构文件删除（Tier1/Tier2/Tier3 + PlatformContext + DesignTokenRegistry）
- [ ] 362 处魔鬼数字全部消除
- [ ] CI 审计脚本全量调整完成（magic-numbers + token-layering 重写 + token-naming 新建）
- [ ] CI 审计脚本 0 漏检
- [ ] 全量编译通过
- [ ] 全量测试通过（7664+ 用例）
- [ ] 快照测试无回归
- [ ] 旧 token 文件全部删除
- [ ] DesignSystem.swift 重新导出新 token
