# 开发编码规范

> 本文档为编码规范速查表，详细规范见 [swift-coding-style.md](../Guides/swift-coding-style.md)。

## 核心规范

- **仅构造器注入 / @Dependency** — 禁止直接 `ServiceContainer.shared.resolve` 在 View 层；`@Inject` 为遗留状态，新代码必须使用 `@Dependency`（swift-dependencies）
- **View 薄层** — 禁止在 View 中注入 Repository，禁止编写业务逻辑
- **Entity → DTO** — 通过 Converter 转换，禁止直接暴露 Entity
- **不可变数据** — 创建新对象，禁止修改已有对象
- **中文注释** — 文件头、公开 API、复杂逻辑处必须中文注释
- **L10n 强制** — 所有用户可见文本必须通过 `L10n.模块.属性` 访问，禁止直接调用 `.tr()`
- **AppError 工厂** — 统一使用 `AppError.xxx()` 而非裸 `NSError`
- **去魔鬼化** — 禁止内联魔鬼数字/字符串/正则，必须抽取为强类型常量枚举或 `L10n` 扩展
- **DesignSystem Token** — 禁止硬编码 UI 尺寸，必须引用 `DesignSystem` 令牌

## 参考

- [swift-coding-style.md](../Guides/swift-coding-style.md) — 命名、Protocol、Localization key、CodingKeys 等详细约定
- [config-conventions.md](../Guides/config-conventions.md) — project.yml、AppConfig.json、Asset Catalog、.xcstrings 规范
- [implementation-patterns.md](../Guides/implementation-patterns.md) — Swift 6 变通方案、图谱模式、合成文档、缓存策略等
- [srp-file-organization.md](../Guides/srp-file-organization.md) — SRP 文件拆分原则、View/Service 拆分模式

