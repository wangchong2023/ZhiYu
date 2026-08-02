# 本地大模型管理系统 - 设计规范文档

## 1. 功能概述

### 1.1 产品定位
智宇本地大模型管理系统是一个面向隐私优先的 AI 原生知识管理应用的端侧模型控制中心，支持模型发现、下载、配置、调优和智能端云混合路由。

### 1.2 核心价值主张
- **隐私至上**：关键任务（分块、链接发现）强制本地运行
- **智能路由**：根据网络状态、模型可用性自动选择端侧/云端
- **零门槛**：硬件兼容性自动评估，防止 OOM
- **专业可控**：完整的推理参数调优能力

### 1.3 核心功能模块

| 模块 | 功能 | 优先级 |
|------|------|--------|
| 模型市场 | 浏览、搜索、下载端侧模型 | P0 |
| 我的模型 | 管理已下载模型、切换激活模型 | P0 |
| 参数调优 | 调整推理参数（温度、top-p、top-k、max tokens） | P0 |
| 服务器配置 | 管理 Mock 服务器列表、测试连接 | P1 |
| 智能路由 | 端云混合决策、网络状态监控 | P0 |
| 性能监控 | 推理速度、内存占用、Token 吞吐 | P2 |

---

## 2. 信息架构

```
本地大模型管理
├── 📦 模型市场（发现与下载）
│   ├── 市场列表（远程白名单）
│   ├── 硬件兼容性徽章
│   ├── 下载进度管理
│   └── 模型详情页
│
├── 💎 我的模型（已下载管理）
│   ├── 激活模型选择
│   ├── 本地模型列表
│   ├── 存储空间占用
│   └── 删除/重新验证
│
├── ⚙️ 参数调优（推理配置）
│   ├── 预设模板（创意/平衡/精确）
│   ├── 温度调节（0.0 - 2.0）
│   ├── Top-P 调节（0.0 - 1.0）
│   ├── Top-K 调节（1 - 100）
│   ├── Max Tokens 调节
│   └── 实时预览效果
│
├── 🌐 服务器配置（Mock 服务器）
│   ├── 服务器列表
│   ├── 添加/编辑服务器
│   ├── 连接测试
│   └── 默认服务器选择
│
└── 🧠 智能路由（端云决策）
    ├── 路由策略开关
    ├── 云端模型选择
    ├── 任务路由规则
    └── 网络状态监控
```

---

## 3. 用户流程

### 3.1 首次使用流程
```
[打开应用] → [检测设备硬件] → [显示推荐模型] → [一键下载] → [自动激活] → [完成引导]
```

### 3.2 模型发现与下载流程
```
[浏览市场] → [查看模型详情] → [评估硬件兼容性] → [开始下载] → [监控进度] → [SHA256 校验] → [自动激活]
```

### 3.3 参数调优流程
```
[选择激活模型] → [选择预设模板] → [微调参数] → [实时预览] → [保存配置] → [应用到推理]
```

### 3.4 服务器配置流程
```
[查看服务器列表] → [添加新服务器] → [测试连接] → [设为默认] → [保存配置]
```

---

## 4. 界面设计规范

### 4.1 设计原则

#### 4.1.1 视觉层次
- **三级层次**：主卡片 > 次级信息 > 辅助文本
- **色彩对比度**：遵循 WCAG AA 标准（4.5:1）
- **间距节奏**：8pt 网格系统（atomic: 4, tiny: 8, small: 12, medium: 16, large: 24）

#### 4.1.2 状态可见性
| 状态 | 视觉表现 | 图标 | 颜色 |
|------|----------|------|------|
| 支持 | 绿色勾选 | checkmark.shield.fill | .green |
| 警告 | 橙色感叹号 | exclamationmark.circle.fill | .orange |
| 限制 | 红色禁止 | exclamationmark.octagon.fill | .red |
| 下载中 | 进度条 + 百分比 | arrow.down.circle | .appAccent |
| 已完成 | 就绪标签 | checkmark.shield.fill | .green |
| 已激活 | 高亮边框 | checkmark.circle.fill | .appAccent |

#### 4.1.3 反馈机制
- **触觉反馈**：所有操作按钮触发 Haptic Feedback
- **动画过渡**：状态切换使用 `.animation(.smooth)`
- **加载状态**：使用 Skeleton UI 而非转圈
- **错误提示**：内联错误信息 + Alert 双重反馈

### 4.2 组件规范

#### 4.2.1 模型卡片
```
┌─────────────────────────────────────────────┐
│ [模型名称] [2B]            [✓ 就绪]          │
│ Google · 1.2 GB                             │
│                                             │
│ 高效轻量级指令微调模型，适合设备端...        │
│                                             │
│ [对话] [总结] [标注]                         │
│                                             │
│ ┌─────────────────────────────────────┐   │
│ │ ⚠️ 临界运存警告...                   │   │
│ └─────────────────────────────────────┘   │
│                                             │
│ [████████░░] 76%          [⏸ 暂停]         │
└─────────────────────────────────────────────┘
```

**状态变体**：
- **未下载**：显示 "下载" 按钮（蓝色胶囊）
- **下载中**：显示进度条 + "暂停" 按钮
- **已暂停**：显示 "继续" 按钮（绿色）+ "取消" 按钮（灰色）
- **已完成未激活**：显示 "激活" 按钮（空心蓝色边框）
- **已激活**：显示 "已激活" 标签（填充蓝色，白色文字）+ 高亮边框

#### 4.2.2 参数调节器
```
┌─────────────────────────────────────────────┐
│ 温度 (Temperature)                 [ℹ️]     │
│                                             │
│ ├─────●─────────────────────┤              │
│ 0.0                    1.5                  │
│                                             │
│ 当前值: 0.7                                  │
│ 💡 提示: 较高值产生更有创意的输出            │
└─────────────────────────────────────────────┘
```

**交互规则**：
- **拖动手柄**：实时更新数值
- **点击轨道**：跳转到该位置
- **长按信息图标**：显示详细说明气泡

#### 4.2.3 服务器卡片
```
┌─────────────────────────────────────────────┐
│ [🟢] Mock Server - Local Development        │
│                                             │
│ http://localhost:8000                       │
│ 最后测试: 2 分钟前 · 延迟 12ms               │
│                                             │
│ [测试连接]  [编辑]  [删除]      [⭐️ 默认]   │
└─────────────────────────────────────────────┘
```

---

## 5. 交互设计

### 5.1 手势规范

| 手势 | 目标 | 动作 |
|------|------|------|
| 点击 | 模型卡片 | 展开详情页 |
| 长按 | 模型卡片 | 显示快捷菜单（删除/重命名/详情） |
| 向左滑动 | 模型卡片 | 显示删除按钮 |
| 下拉刷新 | 列表 | 重新拉取远程清单 |
| 双指捏合 | 参数调节器 | 重置为默认值 |

### 5.2 动画时序

```
状态切换：300ms ease-in-out
下载进度：线性更新（无动画）
卡片展开：400ms spring (response: 0.5, dampingFraction: 0.8)
错误抖动：200ms shake animation
成功闪烁：500ms fade-in-out
```

### 5.3 空状态设计

#### 5.3.1 我的模型 - 空状态
```
         [📦]
    
    暂无已下载模型
    
    前往模型市场下载您的第一个端侧模型
    推荐从轻量级的 Gemma-2B 开始
    
    [前往市场]
```

#### 5.3.2 服务器列表 - 空状态
```
         [🌐]
    
    暂无配置的服务器
    
    添加 Mock 服务器以进行本地开发测试
    
    [+ 添加服务器]
```

---

## 6. 数据模型扩展

### 6.1 推理参数持久化
```swift
public struct UserInferencePreferences: Codable {
    let modelId: String
    let presetName: String // "creative" | "balanced" | "precise" | "custom"
    let temperature: Double
    let topP: Double
    let topK: Int
    let maxTokens: Int
    let updatedAt: Date
}
```

### 6.2 服务器配置
```swift
public struct MockServerConfig: Codable, Identifiable {
    let id: UUID
    let name: String
    let baseURL: String
    let apiKey: String?
    let isDefault: Bool
    let lastTestedAt: Date?
    let latencyMs: Int?
    let isHealthy: Bool
}
```

---

## 7. 技术实现要点

### 7.1 性能优化
- **LazyVStack**：模型列表使用懒加载
- **图片缓存**：模型图标本地缓存
- **状态防抖**：下载进度更新限流（每 100ms 更新一次）
- **后台下载**：使用 `URLSessionDownloadTask` + 后台模式

### 7.2 错误处理
```swift
public enum LLMManagerError: LocalizedError {
    case networkUnavailable
    case checksumMismatch(expected: String, actual: String)
    case insufficientStorage(required: Int64, available: Int64)
    case hardwareIncompatible(required: Double, available: Double)
    case downloadCancelled
    case modelNotFound(modelId: String)
    
    var errorDescription: String? {
        // 国际化错误信息
    }
}
```

### 7.3 可访问性（A11y）
- **VoiceOver 支持**：所有交互元素添加 `.accessibilityLabel()`
- **动态字体**：支持系统字体缩放
- **高对比度**：检测 `\.colorSchemeContrast` 环境值
- **减弱动画**：检测 `\.accessibilityReduceMotion`

---

## 8. 测试策略

### 8.1 单元测试覆盖
- `GlobalModelManager` 业务逻辑
- `DeviceHardwareGuard` 兼容性评估
- `InferenceParameters` 验证规则
- `MockServerConfig` CRUD 操作

### 8.2 快照测试
- 模型卡片各状态变体
- 参数调节器交互状态
- 空状态视图
- 错误提示样式

### 8.3 集成测试
- 完整下载流程（Mock 网络）
- SHA256 校验失败处理
- 磁盘空间不足场景
- 网络中断恢复续传

---

## 9. 国际化 (i18n)

### 9.1 新增词条结构
```swift
// Sources/Localization/Extensions/L10n+ModelManager.swift
extension L10n {
    enum ModelManager {
        static var storeTitle: String { tr("model_manager.store.title") }
        static var myModelsTitle: String { tr("model_manager.my_models.title") }
        static var parametersTitle: String { tr("model_manager.parameters.title") }
        static var serversTitle: String { tr("model_manager.servers.title") }
        
        enum Card {
            static func vendor(_ name: String) -> String { 
                trf("model_manager.card.vendor", name) 
            }
            static func size(_ gb: String) -> String { 
                trf("model_manager.card.size", gb) 
            }
        }
        
        enum Parameters {
            static var temperature: String { tr("model_manager.params.temperature") }
            static var topP: String { tr("model_manager.params.top_p") }
            static var topK: String { tr("model_manager.params.top_k") }
            static var maxTokens: String { tr("model_manager.params.max_tokens") }
            
            static var presetCreative: String { tr("model_manager.params.preset.creative") }
            static var presetBalanced: String { tr("model_manager.params.preset.balanced") }
            static var presetPrecise: String { tr("model_manager.params.preset.precise") }
        }
        
        enum Server {
            static var addServer: String { tr("model_manager.server.add") }
            static var testConnection: String { tr("model_manager.server.test") }
            static func latency(_ ms: Int) -> String { 
                trf("model_manager.server.latency", ms) 
            }
        }
    }
}
```

### 9.2 必需的翻译词条
- `zh-CN.json` 和 `en-US.json` 需同步添加约 60+ 新词条
- 包括：按钮文案、状态描述、错误信息、提示文本、参数说明

---

## 10. 里程碑规划

### Phase 1: 视觉重构 (Week 1)
- [ ] 优化模型卡片设计
- [ ] 修复硬编码中文字符串
- [ ] 添加 Skeleton 加载态
- [ ] 完善空状态视图

### Phase 2: 参数调优 (Week 2)
- [ ] 实现参数调节器组件
- [ ] 添加预设模板
- [ ] 实时预览效果
- [ ] 持久化用户配置

### Phase 3: 服务器配置 (Week 3)
- [ ] 服务器列表 CRUD
- [ ] 连接测试功能
- [ ] 延迟监控
- [ ] 健康检查

### Phase 4: 打磨与测试 (Week 4)
- [ ] 完整 A11y 审查
- [ ] 快照测试覆盖
- [ ] 性能优化
- [ ] 用户验收测试

---

## 附录 A：设计 Tokens

```swift
// 模型管理专用设计令牌
extension DesignSystem {
    enum ModelManager {
        // 卡片尺寸
        static let cardMinHeight: CGFloat = 180
        static let cardMaxWidth: CGFloat = 500
        static let cardCornerRadius: CGFloat = 16
        
        // 徽章尺寸
        static let badgeHeight: CGFloat = 24
        static let badgeCornerRadius: CGFloat = 12
        
        // 进度条
        static let progressBarHeight: CGFloat = 6
        static let progressBarCornerRadius: CGFloat = 3
        
        // 参数调节器
        static let sliderHeight: CGFloat = 44
        static let sliderThumbSize: CGFloat = 28
        
        // 动画时长
        static let cardExpandDuration: TimeInterval = 0.4
        static let stateChangeDuration: TimeInterval = 0.3
    }
}
```

---

## 附录 B：原型图规范 (Wireframes)

### B.1 模型市场主界面原型

```
┌─────────────────────────────────────────────┐
│  < 返回          AI 模型            [⚙️]     │
├─────────────────────────────────────────────┤
│  ┌─────────────────────────────────────┐   │
│  │  [💻] 设备运存: 8.0 GB              │   │
│  │  满足大部分轻量级模型运行需求        │   │
│  └─────────────────────────────────────┘   │
│  ┌────────────┬────────────┐               │
│  │  我的模型   │  模型市场  │  ← 分段器      │
│  │  ══════    │            │               │
│  └────────────┴────────────┘               │
│  ┌─────────────────────────────────────┐   │
│  │  [Gemma-2B] [2B]      [✓ 就绪]      │   │
│  │  Google · 1.2 GB                    │   │
│  │  [对话] [总结] [标注]                │   │
│  │                      [✓ 已激活]     │   │
│  └─────────────────────────────────────┘   │
└─────────────────────────────────────────────┘
```

### B.2 参数调优与服务器配置原型

```
┌─────────────────────────────────────────────┐
│  < 返回       参数调优          [保存]       │
├─────────────────────────────────────────────┤
│  预设模板: [创意] [平衡(已选)] [精确]        │
│  温度 (Temperature): [──●──] 0.7            │
│  Top-P (核采样):     [───●─] 0.9            │
│  Top-K (候选数):     [──●──] 40             │
│  Max Tokens:        [───●─] 2048           │
└─────────────────────────────────────────────┘
```

---

## 附录 C：实施总结 (Implementation Summary)

### C.1 核心视图归位
- `LocalModelManagerView.swift`: 统一入口视图（Tab 切换架构）
- `InferenceParametersView.swift`: 推理参数调优界面
- `ServerConfigView.swift`: Mock 服务器配置管理
- `SmartRoutingView.swift`: 智能路由配置界面
- `L10n+ModelManager.swift`: 国际化词条强类型扩展

---

**文档版本**: v2.0  
**最后更新**: 2026-08-02  
**负责人**: Constantine  
**审阅状态**: 整合合流完成 (SSOT)
