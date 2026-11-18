# Skip POC 静态评估报告（Phase 0，收缩版）

> **日期**：2026-11-18
> **范围**：因当前开发机缺 Android SDK（adb）、JAVA_HOME 失效，`skip build android` 无法实跑转译。按 USER 决策，本次 **Skip POC 收缩为静态评估**，不安装 Android 环境、不做实际转译，仅评估 Skip.tools 1.9.21 对 ZhiYu 的适用性。真实转译数据留待后续具备 Android 环境的机器补做。

## 1. 环境实测证据

| 项 | 值 | 状态 |
|----|-----|------|
| Skip 版本 | 1.9.21（brew skiptools/skip tap） | ✅ 已装 |
| Swift 版本 | 6.4.2（swift-driver 1.168.6） | ✅ |
| macOS | 27.2.1（ARM） | ✅ |
| Xcode | 27.2 | ✅ |
| Homebrew | 7.0.14 | ✅ |
| swiftly | 1.2.0 已装，但 `~/.swiftly/config.json` 未初始化 | ⚠️ doctor 报错 |
| gradle | /opt/homebrew/bin/gradle 存在，但 JAVA_HOME 指向无效目录 | ⚠️ |
| java | openjdk 21.0.13.1 实际可用，JAVA_HOME 环境变量失效 | ⚠️ |
| Android SDK / adb | **缺失**（无 ~/Library/Android/sdk，无 adb） | ❌ 阻塞实跑 |

`skip doctor` 结论：4 项失败（swiftly / gradle / java / adb），`skip build android` 当前**无法执行**。

## 2. Skip 转译机制概述

Skip.tools 的核心是 **Swift→Kotlin 源到源转译**（transcompiler），将 Swift 源码翻译为 Kotlin，再由 Gradle 构建为 Android APK。它支持：
- Swift 5.9+ 语法（本机 6.4.2 满足）
- SwiftUI 视图转译为 Android Compose
- 依赖的纯 Swift 包（无 UIKit/AppKit）可直接转译

## 3. 对 ZhiYu 的适用性静态评估

### 3.1 正向因素
- **Swift 6.4.2 高于 Skip 最低要求（5.9.0）**，语言层面兼容。
- 项目已有 `ZhiYuDomain` 等**纯逻辑 SPM 包**（Protocols/Models/RAG），这部分不含 UI，是 Skip 转译的理想候选。
- IDL 契约层（Proto）本意是语言无关，与 Skip 转译不冲突。

### 3.2 阻塞因素（高置信）
| 阻塞 | 影响 | 说明 |
|------|------|------|
| **GRDB (SQLite)** | ❌ 高 | Skip 不转译第三方依赖的 C 桥接/SQLite；GRDB 的 Swift 层可转但底层 SQLite 需 Android 端替换方案（Room/SQLDelight） |
| **AppAuth-iOS** | ❌ 高 | OIDC 依赖 AppAuth-iOS 的 Objective-C/AppKit/UIKit 实现，无 Android 对应；Android 需换 GMS 或自研 OIDC |
| **UIKit/AppKit 残留** | ⚠️ 中 | Features/Shared 层有 `import UIKit`（前核实：Shared 3 文件、Features 8 文件），需先跨平台抽象化 |
| **L10n 多语言 .xcstrings** | ⚠️ 中 | Skip 对 .xcstrings 的转译支持需验证 |
| **SwiftUI 复杂组件** | ⚠️ 中 | 图谱/富文本编辑器等重度 SwiftUI 组件转译 Compose 质量待评估 |
| **watchOS/Widget 专属代码** | ✅ 低 | 天然平台隔离，不参与 Android 转译 |

### 3.3 结论
Skip.tools **不适合作为 ZhiYu 全面 Android 方案的唯一工具**：
1. **GRDB + AppAuth 两个核心基础设施无法转译**，需 Android 侧分别替换（存储引擎、OIDC 客户端），这本身就是跨平台重写，Skip 的"一份代码转多平台"收益被抵消。
2. Skip 转译适合**纯 Swift 逻辑**，而 ZhiYu 的垂直业务与 UI 深度耦合 UIKit/SwiftUI，转译成本高于重写。

**建议**：Phase 2（Android）不采用 Skip 全面转译。优先采用 **KMP/手写重写 + 复用 IDL 契约层** 方案——即契约层（Proto）作为语言无关的接口基准，Android 端按契约独立实现，而非源转译。Skip 可作为**纯逻辑模块**（如 ZhiYuDomain 无 UI 子集）的辅助验证工具，但不作为主路线。

## 4. 决策门结论

**Skip 是否全面采用**：❌ 不采用（记 ADR-015 决策）。
**替代路线**：KMP/手写重写 + IDL 契约层复用。

## 5. 遗留

- Skip 环境可修（JAVA_HOME 对齐 + swiftly init + `skip android home` 装 SDK），但即使修好，受 GRDB/AppAuth 转译限制，Skip 仍非主路线。如未来聚焦纯逻辑模块转译，可补齐环境补做真实 POC。