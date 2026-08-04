# 智宇 (ZhiYu) watchOS 微端设计系统规范

> **适用范围**：ZhiYuWatch（watchOS 10.0+）独立微端 UI 设计与开发规范。
> **平台**：Apple Watch Series 4 (40mm) — Ultra 2 (49mm)，覆盖全尺寸谱系。
> **设计哲学**：**极简、即时、可及**——用户在抬腕的 2 秒内完成最核心的操作。

---

## 1. 屏幕适配规范

### 1.1 尺寸谱系

| 设备 | 屏幕宽 | 屏幕高 | 设计基准尺寸 | 适配策略 |
| :--- | :---: | :---: | :---: | :--- |
| Series 4 (40mm) | 162 pt | 197 pt | 160×190 | 极简布局，最少元素 |
| Series 4 (44mm) | 184 pt | 224 pt | 180×220 | 标准布局 |
| Series 7/8/9 (41mm) | 176 pt | 215 pt | 175×210 | 同 Series 4 (40mm) |
| Series 7/8/9 (45mm) | 198 pt | 242 pt | 195×235 | 宽松布局，可额外显示 1 行 |
| Ultra / Ultra 2 (49mm) | 205 pt | 251 pt | 200×245 | 最大布局，可展示更多摘要 |

### 1.2 内容安全区原则
- **上下边距**：最小 `8pt`（自动适配 WKInterfaceController 的圆角遮罩区域）。
- **左右边距**：最小 `10pt`，SwiftUI 中使用 `.scenePadding(.horizontal)` 自动适配全尺寸。
- **禁止全屏文字**：文字内容宽度不超过屏幕宽的 90%（防止被圆角裁切）。

### 1.3 响应式布局要求

```swift
/// 根据屏幕宽度自适应字号
var adaptiveTitleFont: Font {
    // 小屏：Series 4/7 41mm 及以下
    WKInterfaceDevice.current().screenBounds.width < 180
        ? .system(size: 14, weight: .semibold)
        : .system(size: 16, weight: .semibold)
}
```

---

## 2. 表盘 Complication 设计规范

### 2.1 支持的 Complication 系列

| Complication 系列 | 触发动作 | 设计要求 |
| :--- | :--- | :--- |
| `accessoryCircular` | 点击打开采集界面 | 仅 SF Symbol 图标（`brain.head.profile`），无文字 |
| `accessoryRectangular` | 展示最后一条笔记标题 | 最多 2 行，每行 ≤ 20 个汉字 |
| `accessoryCorner` | 同 Circular | SF Symbol + 小号数字（未读知识条数）|

### 2.2 快速启动规范
- Complication 触发到首个可交互界面的冷启动时间：**< 1.5 秒**。
- 使用 `WKExtension.shared().openSystemURL(_:)` 直接跳转至采集界面，禁止多层导航。
- Complication 数据更新频率：利用 `CLKComplicationDataSource` 每 15 分钟刷新一次最新笔记摘要。

---

## 3. 抬腕即记（语音笔记）UI 规范

### 3.1 界面状态机

```
[空闲态] ──点击麦克风──► [录音态] ──抬手停止──► [处理态] ──► [完成态]
   ▲                                                              │
   └──────────────────────── 自动返回（3s） ◄────────────────────┘
```

### 3.2 各状态设计规范

**空闲态**
- 居中显示 SF Symbol `mic.circle.fill`（大号，`48pt`），颜色 `accentColor`。
- 下方文字："点击开始记录"（12pt，灰色）。
- 最多展示 3 条最近笔记缩略（`accessoryRectangular` 风格，10pt 字号）。

**录音态**（活跃采集）
- 麦克风图标变为 `mic.fill`，搭配脉冲动画（缩放 1.0→1.2，时长 0.8s，无限循环）。
- 颜色：`red`（高对比度，通知用户正在录制）。
- 显示实时转写文字（滚动 `Text`，最多 3 行，超出省略）。
- **关键**：使用 `.accessibilityLabel("正在录音")` 确保 VoiceOver 可描述状态。

**处理态**（AI 分析中）
- 显示 `ProgressView()`（环形），文字："AI 分析中..."（10pt）。
- 超时保护：处理超过 10 秒自动 fallback 为纯文本保存。

**完成态**
- 显示 SF Symbol `checkmark.circle.fill`（绿色），文字："已保存至知识库"。
- 3 秒后自动 dismiss 或返回空闲态。

### 3.3 代码规范示例

```swift
/// 语音记录卡片视图（watchOS 专用）
/// 遵守 watchOS 3s 之内可见内容的设计原则
struct VoiceRecordCardView: View {
    @ObservedObject var viewModel: WatchVoiceViewModel

    var body: some View {
        VStack(spacing: 8) {
            // 状态图标（带动画）
            recordingIcon
                .foregroundStyle(viewModel.isRecording ? .red : .accentColor)
                .scaleEffect(viewModel.isRecording ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(), value: viewModel.isRecording)

            // 实时转写文字（限 3 行）
            if !viewModel.transcribedText.isEmpty {
                Text(viewModel.transcribedText)
                    .font(.system(size: 12))
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
        }
        .scenePadding()  // 自动处理全尺寸安全区适配
    }

    @ViewBuilder
    private var recordingIcon: some View {
        Image(systemName: viewModel.isRecording ? "mic.fill" : "mic.circle.fill")
            .font(.system(size: 48))
    }
}
```

---

## 4. WCSession 跨端同步规范

### 4.1 数据流架构

```
[watchOS App] ──WCSession.transferUserInfo──► [iOS App (后台接收)]
                                                      │
                                                      ▼
                                               [IngestQueue]
                                                      │
                                                      ▼
                                               [SQLiteStore (持久化)]
```

### 4.2 同步数据包规范

```swift
/// WCSession 传输载荷，watchOS 侧编码
struct WatchSyncPayload: Codable {
    let id: UUID           // 防止重复处理
    let type: PayloadType  // .voiceNote | .quickCapture | .complication
    let content: String    // 转写文字或快速记录内容
    let timestamp: Date
    let metadata: [String: String]  // 扩展元数据（标签、情绪等）

    enum PayloadType: String, Codable {
        case voiceNote       // 语音笔记
        case quickCapture    // 快捷文字记录
        case complicationTap // 表盘点击触发
    }
}
```

### 4.3 离线可靠性规范
- 使用 `WCSession.transferUserInfo(_:)` 替代 `sendMessage(_:replyHandler:)`——前者具备队列保证，无网时自动重试。
- watchOS 侧本地缓存：最多保存 20 条未同步记录，超出时丢弃最旧记录（防止存储超额）。
- **错误处理**：`session(_:didFinish:error:)` 回调中，对 `WCErrorCode.deliveryFailed` 进行重试（最多 3 次，指数退避）。

---

## 5. 触觉反馈 (Haptic Feedback) 规范

| 交互场景 | 触觉类型 | 调用方式 |
| :--- | :--- | :--- |
| 录音开始 | `.start` | `WKInterfaceDevice.current().play(.start)` |
| 录音完成/保存成功 | `.success` | `WKInterfaceDevice.current().play(.success)` |
| AI 处理出错 | `.failure` | `WKInterfaceDevice.current().play(.failure)` |
| 用户点击主要按钮 | `.click` | `WKInterfaceDevice.current().play(.click)` |
| Complication 触发 | 无反馈 | — (由系统自动处理) |

> **电池优化**：每次录音周期内，触觉反馈总次数不超过 3 次。连续反馈间隔 > 300ms。

---

## 6. 电池与性能指标

| 指标 | 目标值 | 监控方法 |
| :--- | :--- | :--- |
| 单次语音记录任务 CPU 峰值 | < 25% | Xcode Instruments > Energy |
| 后台 WCSession 传输耗电 | < 0.5%/次 | Instruments > Network |
| 复杂表盘更新耗时 | < 100ms | Instruments > Time Profiler |
| App 冷启动（从 Complication 点击）| < 1.5s | Instruments > App Launch |
| 内存峰值（录音处理中） | < 50MB | Instruments > Allocations |

---

## 7. 无障碍 (Accessibility) 要求

- 所有可交互元素必须有 `.accessibilityLabel` 描述，避免仅依赖视觉图标。
- 录音态下，VoiceOver 应自动朗读"正在录音，抬手可停止"。
- 支持动态字体（`DynamicType`），但在 watchOS 上字号范围应限制为 `footnote` ~ `title3`，避免溢出。
- 支持 Reduce Motion：动画（脉冲缩放等）在用户开启"减少动态效果"时应降级为静态渐变。

---

## 8. 测试与断言规范 (Testing & Assertions)

### 8.1 降级能力 (Stubs) 测试准则
- **编译时行为**：由于 watchOS 不支持运行时模型编译等重度能力，其对应的平台代理类 (Stub Class) 应提供明确的非支持特性反馈，必须在单元测试中进行错误分支断言（如 `WatchModelCompiler.compileModel` 必须抛出指定的 `WatchModelCompiler` 错误且 `supportsCompilation` 返回 `false`）。
- **安全边界**：安全作用域存储和剪贴板在 watchOS 下的降级实现不得返回未定义行为或触发崩溃，在测试中应校验其返回默认降级值（如 `WatchSecurityScopedStorage.restoreURL` 始终返回 `nil`）。

### 8.2 数据同步与离线机制测试准则
- **离线缓存上限**：测试应当覆盖 watchOS 本地离线缓存队列（上限 20 条），验证先进先出（FIFO）的自动覆盖机制，防止因缓存数据积压导致手表端存储超额。
- **重新激活传输**：必须模拟从离线重连至激活（`WCSession.activationState == .activated`）的触发过程，验证缓存数据成功批量出队发送的完整数据流。
- **微缩缓存同步**：离线阅读缓存列表由 iPhone 侧拉取并注入手表端 `UserDefaults` 时，限制数量为 **50 条** 最热页面。单元测试中需验证数据打包体积控制及手表端反序列化的字段还原度。

---

*本文档于 2026-05-21 P1 阶段新建，于 2026-05-22 增加了测试与断言规范，用于指导 ZhiYuWatch（watchOS）微端的 UI 设计、功能实现与测试覆盖。*
*相关文档：`Docs/Design/UI_COMPONENTS.md`、`Docs/Design/VISUAL_SYSTEM.md`、`Sources/Platforms/watchOS/`。*
