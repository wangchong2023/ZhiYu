# P0-1 Token 体系统一重构设计

**日期：** 2026-09-28
**状态：** 已批准
**关联：** P0-1（统一 Token 体系架构）+ P0-2（Dynamic Type 支持，合并执行）

## 1. 目标与范围

### 目标

将分散在 `Sources/Shared/DesignSystem/Tokens/`（17 文件, 2466 行）和 `UFPDesignSystem` SPM 包内的 Token 定义统一到 SPM 包的 `DesignTokens` 命名空间下，删除 app 内兼容层，同步集成 Dynamic Type（P0-2 合并）。

### 范围

**包含：**
- 迁移 17 个 Token 文件到 `Packages/UFPDesignSystem/Sources/UFPDesignSystem/Tokens/`
- 删除 `Sources/Shared/DesignSystem/Tokens/` 目录
- 删除 `DesignSystem.swift` 中的 Token 转发属性（保留组件 typealias）
- 全局替换 ~2000 处引用（`DesignSystem.*` / `Spacing.*` / `Typography.*` / `Colors.*` / `Animations.*`）
- Typography 集成 `@ScaledMetric` 支持 Dynamic Type
- 更新 SPM 包 `Package.swift` 依赖（添加 `Dependencies`）
- 更新 SPM 包测试

**不包含：**
- `DesignSystem+Domain.swift`（Domain 专用常量，非通用 Token，保留 app 内）
- `DesignSystem+Components/`（组件实现，保留 app 内）
- `Sources/Shared/UIComponents/`（UI 组件库，保留 app 内）

## 2. 命名空间架构

### 迁移后的 Token 命名空间结构

```
UFPDesignSystem SPM 包
└── DesignTokens (enum)
    ├── Spacing (enum)          — 间距/圆角/图标尺寸 + Layout/Action/Gallery 等子结构
    ├── Typography (enum)       — 字号/字体 + HeadingLevel + @ScaledMetric 集成
    ├── Colors (enum)           — 颜色/透明度/主题色 + Opacity 子结构
    ├── Animations (enum)       — 弹簧/时长/交互动画
    ├── Icons (enum)            — SF Symbol 名称常量
    ├── Metrics (enum)          — 仪表盘/图表/布局指标
    ├── Opacity (enum)          — 透明度常量
    ├── Radius (enum)           — 圆角常量
    ├── Shadows (enum)          — 阴影常量
    ├── ZIndex (enum)           — 层级常量
    ├── Component (enum)        — 组件级 Token
    ├── Reference (enum)        — Tier 1 基础参考值
    └── System (enum)           — 系统级常量
```

### 引用路径变化

| 迁移前 | 迁移后 |
|--------|--------|
| `DesignSystem.medium` | `DesignTokens.Spacing.medium` |
| `DesignSystem.standardPadding` | `DesignTokens.Spacing.standardPadding` |
| `DesignSystem.titleFontSize` | `DesignTokens.Typography.titleFontSize` |
| `DesignSystem.titleFont` | `DesignTokens.Typography.titleFont` |
| `Spacing.medium` | `DesignTokens.Spacing.medium` |
| `Typography.bodyFont` | `DesignTokens.Typography.bodyFont` |
| `Colors.Opacity.shadowColor` | `DesignTokens.Colors.Opacity.shadowColor` |
| `Animations.Interaction.standardAnimation` | `DesignTokens.Animations.Interaction.standardAnimation` |

### app 内保留的 `DesignSystem` enum

只保留组件 typealias（`AppSection`/`Card`/`PrimaryButton` 等），删除所有 Token 转发属性。

## 3. Dynamic Type 集成（P0-2 合并）

### 当前问题

`Typography` 的字号是静态 `CGFloat`，不响应辅助功能的 Dynamic Type。

### 集成方案

在 `DesignTokens.Typography` 中提供两种访问方式：

```swift
public enum Typography {
    // 静态值（供非 SwiftUI 上下文使用）
    public static let bodyFontSize: CGFloat = 17
    
    // Dynamic Type 字体（SwiftUI 中使用，自动响应辅助功能）
    @ScaledMetric(relativeTo: .body) public static var bodyFont: Font
    
    // HeadingLevel 枚举（带 Dynamic Type）
    public enum HeadingLevel {
        case h1, h2, h3
        public var font: Font {
            switch self {
            case .h1: return .system(.largeTitle, design: .rounded)
            case .h2: return .system(.title, design: .rounded)
            case .h3: return .system(.title2, design: .rounded)
            }
        }
    }
}
```

### 关键设计决策

- `@ScaledMetric` 属性必须是实例属性或 `@State`，不能是 `static let` — 使用 `@ScaledMetric` 的 computed property 或在 View 内使用
- 提供 `static let` 静态值（向后兼容）+ View extension 提供 Dynamic Type 字体
- 所有 `DesignTokens.Typography.xxxFont` 在 SwiftUI View 中使用时自动响应 Dynamic Type

### 影响

所有使用 `DesignSystem.titleFont` / `Typography.bodyFont` 的视图将自动获得 Dynamic Type 支持。

## 4. 迁移执行步骤

### 阶段 1：SPM 包准备（已完成 DesignSystem → DesignTokens 重命名）

1. 更新 `Package.swift` 添加 `Dependencies` 依赖
2. 创建 `Tokens/` 目录结构

### 阶段 2：按类别迁移 Token

1. 迁移 `Spacing.swift`（430 行）→ `DesignTokens.Spacing`
2. 迁移 `Typography.swift`（341 行）→ `DesignTokens.Typography`（集成 Dynamic Type）
3. 迁移 `Colors.swift`（323 行）→ `DesignTokens.Colors`
4. 迁移 `Animations.swift`（161 行）→ `DesignTokens.Animations`
5. 迁移其余 13 个 Token 文件（Icons/Metrics/Opacity/Radius/Shadows/ZIndex/Component/Reference/System 等）

### 阶段 3：删除 app 内 Token + 全局替换

1. 删除 `Sources/Shared/DesignSystem/Tokens/` 目录
2. 删除 `DesignSystem.swift` 中的 Token 转发属性（保留组件 typealias）
3. 全局批量替换：
   - `DesignSystem.medium` → `DesignTokens.Spacing.medium`
   - `DesignSystem.standardPadding` → `DesignTokens.Spacing.standardPadding`
   - `DesignSystem.titleFont` → `DesignTokens.Typography.titleFont`
   - `Spacing.xxx` → `DesignTokens.Spacing.xxx`
   - `Typography.xxx` → `DesignTokens.Typography.xxx`
   - `Colors.xxx` → `DesignTokens.Colors.xxx`
   - `Animations.xxx` → `DesignTokens.Animations.xxx`
4. 添加 `import UFPDesignSystem` 到所有引用 Token 的文件

### 阶段 4：验证

1. SPM 包独立编译：`make test-spm PKG=UFPDesignSystem`
2. app 编译：`make ios`
3. lint：`make lint`
4. audit：`make audit`
5. SPM 包测试更新

### 风险控制

- 每个阶段完成后立即编译验证
- 全局替换使用 `sed` 批量 + 人工检查关键文件
- 保留 `DesignSystem+Domain.swift` 和 `DesignSystem+Components/` 不迁移

## 5. 测试策略

### SPM 包测试（`UFPDesignSystemTests/`）

- 更新现有 `SpacingTokenConsistencyTests` / `SpacingTokenHierarchyTests`：`DesignTokens.Spacing` 三层不变量验证
- 新增 `TypographyTokenTests`：字号层级、Dynamic Type 集成验证
- 新增 `ColorsTokenTests`：颜色值、透明度、主题色验证
- 新增 `AnimationsTokenTests`：弹簧系数、时长验证
- 新增 `TokenNamespaceIsolationTests`：验证 `DesignTokens` 与 app 内 `DesignSystem` 无命名冲突

### app 测试

- 现有快照测试自动验证 UI 无回归（字号/间距/颜色变化会触发快照差异）
- 编译通过即证明引用替换正确

### 验证检查点

1. 阶段 2 每个类别迁移后：`swift build --target UFPDesignSystem`
2. 阶段 3 全局替换后：`make ios`（完整 app 编译）
3. 阶段 4 最终验证：`make test-spm PKG=UFPDesignSystem` + `make lint` + `make audit`

## 6. 业界参考

本设计遵循业界标准实践：

- **W3C Design Tokens 规范**：三层 Token 架构（Reference / System / Component）
- **Pointfree / Uber Base UI 模式**：Token 定义在独立 SPM 包，单一来源（SSOT）
- **Apple HIG 原生模式**：`@ScaledMetric` + `Font.custom(relativeTo:)` 支持 Dynamic Type
- **命名空间隔离**：`DesignTokens`（Token）与 `DesignSystem`（组件）分离，避免冲突
