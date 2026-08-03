# 智宇 (ZhiYu) 详细设计文档 (Detailed Design)

本文件深入解析 智宇 (ZhiYu) 核心引擎的内部实现细节。

## 1. 混合检索引擎 (Hybrid Search Engine)

### 1.1 数据流向与 RAG 模块化管道 (Modular Ingest Pipeline)

智宇 (ZhiYu) 实现了端到端的 RAG 摄入管道，通过 `KnowledgeIngestPipeline` (位于 `Domain/RAG`) 进行编排：

1. **Parser (解析器)**: 抽取纯文本，支持 Markdown, PDF, OCR 图像识别。
2. **Chunker (分块器)**: 基于语义长度（Semantic Splitting）将长文划分为分块。
3. **Embedding (向量化)**: 异步调用 LLM 生成向量，由 `EmbeddingProvider` (位于 `Core/Base/Protocols`) 定义契约，基础设施层 `EmbeddingManager` 实现同步至向量数据库。
4. **Linker (关联器)**: 自动发现页面间的 Wiki-Link，构建知识图谱 (Graph)。

### 1.2 检索策略 (Retrieval Strategy)

系统采用 **FTS5 (全文搜索)** + **Vector Search (向量检索)** 的混合模式：

- **关键词匹配**: 用于精确查找特定术语。
- **语义相似度**: 用于模糊意图识别，支持跨语境关联。
- **Reranking (重排序)**: 召回后的结果由 AI 进一步根据 Query 语义进行权重重排，确保最相关的知识排在首位。

## 2. 存储与状态引擎 (Storage & State Engine)

### 2.1 物理存储与 Repository 模式 (DIP 实现)

智宇 (ZhiYu) 采用基于 **GRDB.swift** 的 Repository 模式，并严格遵循 **依赖倒置原则 (DIP)**：

- **契约下沉**: 所有的仓储协议（如 `KnowledgeRepository`, `VectorRepository`）物理位置位于 `Sources/Domain/Protocols/`，由领域层定义业务契约。
- **解耦实现**: 具体的 SQL 实现类（如 `KnowledgePageRepository`）位于 `Sources/Infrastructure/` 层，通过 DI 容器注入到领域服务中。这种模式确保了核心业务逻辑不直接依赖于 GRDB 或任何特定的持久化框架。

### 2.2 全局状态 Facade (AppStore 治理)

`AppStore` 作为全应用的状态入口，通过 `@Observable` 驱动 UI 刷新。为了符合 **单向数据流 (UDF)** 原则，系统执行了重构：

- **核心聚合**: `AppStore` 仅负责页面元数据同步、全局路由协调与基础操作封装。
- **显式调度**: 移除了子 Store (Search, Settings, Workflow) 对 EventBus 的被动监听。所有的重置与全局同步动作由 `AppStore` 通过方法调用显式驱动。这种设计确立了严谨的父子 Store 调用链路，极大降低了复杂业务流下的调试难度。
- **业务下沉**: 垂直领域特有的复杂状态已下沉至领域专有的 `Store`（如 `IngestStore`, `AIWorkflowStore`），通过环境对象 (`.environment()`) 按需注入视图。

## 3. 插件系统架构与加固 (Plugin System & Hardening)

### 3.1 扩展点设计 (Extension Points)

智宇参考 Obsidian 架构，为插件开放了深度 UI 扩展点：

- **Command Palette**: 插件可注册全局指令至 `Cmd+K` 中枢。
- **Ribbon & Sidebar**: 插件可在侧边栏注册图标入口或独立的自定义视图。
- **Lifecycle Events**: 插件可监听 `onFileOpen`, `onPageSave` 等系统级事件。

### 3.2 Watchdog 2.0 性能监控

为了防止僵尸插件拖慢宿主 App，`PluginRegistry` 集成了 Watchdog 2.0 机制：

- **执行竞速**: 每个插件拦截 Hook 的执行上限为 **500ms**。
- **物理封禁**: 超时插件会被立即卸载、物理回收 `JSContext` 内存，并将其 ID 写入 `UserDefaults` 黑名单。重启 App 后封禁依然有效，彻底杜绝循环性能崩溃。
- **资源监控**: 系统实时统计每个插件的调用次数与平均耗时，并在“系统监控”面板中提供可视化排行。

### 3.3 插件存储加密

每个插件拥有独立的持久化空间：

- **AES-GCM 加密**: 存储文件（`.json`）在写入磁盘前均通过 AES-256-GCM 进行全盘加密，密钥派生自系统 Keychain。
- **双向绑定**: 插件的声明式 UI 组件与加密存储实现了自动双向绑定，开发者无需编写 IO 代码即可实现配置记忆。

### 3.4 JS 沙箱安全硬化 (JS Sandbox Hardening)

为了防止恶意插件通过动态执行代码绕过智宇的 API 访问白名单，系统在执行插件脚本前会强制注入硬化逻辑：

```mermaid
sequenceDiagram
    participant P as JavaScriptPlugin
    participant Pool as PluginEnginePool
    participant CTX as JSContext (Sandbox)
    
    P->>Pool: borrowContext() 租借上下文
    Pool-->>CTX: 返回干净的 JSContext 实例
    
    Note over P, CTX: 核心硬化阶段 (@SR-04)
    P->>CTX: evaluateScript(HardeningScript)
    Note right of CTX: 物理禁用 eval 和 Function 构造器
    Note right of CTX: 锁定 Object.freeze 禁止篡改
    
    P->>CTX: setupAPI(in:) 装配宿主接口
    P->>CTX: evaluateScript(PluginScript) 加载三方插件脚本
    
    P->>CTX: 调用 onLoad() / preProcess()
    CTX-->>P: 返回受限执行结果
    
    P->>Pool: returnContext(ctx) 归还并重置
```

- **物理禁用**: 显式将 `eval` 和 `Function` 赋值为抛出错误的闭包，防止插件利用字符串模板动态生成不受监管的代码。
- **环境锁定**: 利用 `Object.freeze` 冻结禁用逻辑，防止插件通过原型链操作等方式反向破解沙箱限制。

### 3.5 插件沙箱并发池化与 Watchdog 熔断时序 (Concurrency Pooling & Watchdog)

为了防止僵尸插件拖慢宿主 App 并保障高性能的多任务并行，`PluginEnginePool` 对 JSContext 进行了高水准的池化隔离保护（默认 Max 并发为 4）。以下展示了租借、重置硬化、执行、Watchdog 0.5s 限时竞速与物理黑名单封禁的并发安全时序：

```mermaid
sequenceDiagram
    autonumber
    participant App as 主应用线程 / JavaScriptPlugin
    participant Pool as PluginEnginePool (Max=4)
    participant Lock as ConcurrentLock (并发锁)
    participant CTX as JSContext (物理沙箱)
    participant WD as WatchdogTimer (0.5s)

    App->>Pool: borrowContext() 租借沙箱上下文
    Pool->>Lock: acquire() 获取并发独占锁
    Lock-->>Pool: lock acquired
    
    alt 池中有空闲可用 JSContext
        Pool->>Pool: 从空闲队列 (idleQueue) 弹出实例
    else 池已满且无空闲 (并发 > 4)
        Pool->>Pool: 阻塞等待 / 触发降级 LIFO 强行回收
    end
    
    Pool->>CTX: reset() 状态重置与硬化 (物理禁用 eval/Function)
    Pool-->>App: 返回已就绪的 JSContext
    
    par 并发执行与 Watchdog 竞速
        App->>CTX: executeScript(PluginScript) 执行三方插件代码
    and
        App->>WD: start(0.5s) 启动硬熔断定时器
    end

    alt 执行在 0.5s 内正常完成
        CTX-->>App: 返回受限执行结果
        App->>WD: cancel() 取消定时器
        App->>Pool: returnContext(ctx) 归还上下文
        Pool->>Pool: 执行深度垃圾回收后压回空闲队列
    else 执行超时 (> 0.5s 熔断)
        WD->>App: 触发 Timeout 信号 / 抛出 SandboxError
        App->>Pool: terminate(ctx) 强行注销上下文
        Pool->>CTX: 物理销毁并释放 JSContext 内存
        Pool->>Pool: 标记插件 ID 并写入 UserDefaults 黑名单限制重启加载
    end
```

## 4. 多平台适配与能力隔离 (Platform Adaptation)

### 4.1 跨平台协议抽象

为了实现“业务代码零宏”的目标，系统在 `Sources/Core/Base/Protocols/` 定义了一系列能力协议：

- **PlatformCapabilities**: 抽象触感反馈、状态栏高度、底部安全区等 UI 差异。
- **LiveActivityProtocol**: 抽象灵动岛 (Dynamic Island) 实时活动。在 iOS 下由 `ActivityService` 实现，在非支持平台由 `DummyActivityService` 提供空操作。
- **OCRServiceProtocol**: 抽象文字识别。

### 4.2 系统级解耦

所有的平台具体实现均被物理隔离在 `Sources/Platforms/` 目录下。主 App 仅通过 `ModuleRegistrar` 完成各平台的 DI 注册。

## 5. 视觉算法：力导向图谱布局 (Force-Directed Graph)

### 5.1 核心算法

图谱视图 (`GraphView`) 采用力导向布局 (Force-Directed Layout)，通过模拟物理作用力计算节点坐标：

- **排斥力 (Repulsion)**: 防止节点重叠。
- **吸引力 (Attraction)**: 将具备双向链接的节点拉近。
- **摩擦力 (Damping)**: 随迭代次数增加逐渐降低动能，使布局趋于平稳。

### 5.2 空间分布 (Spatial Distribution)

针对 3D 图谱，采用 **Fibonacci Sphere (斐波那契球)** 分布算法：

- **动态半径**: 球体半径 $R = \max(40, \min(150, \sqrt{N} \times 12))$。该公式确保节点间的平均弧长在不同节点规模 ($N$) 下保持视觉舒适。
- **层级深度**: 选中节点及其一阶邻居会通过 `SCNTransaction` 进行平滑的“向前推移”，利用 Z 轴深度突出展示上下文。

## 6. 生物认证与安全隐私 (Biometric Authentication & Security)

### 6.1 FaceID/TouchID 本地生物认证逻辑与密钥保护

智宇 (ZhiYu) 引入了行业标准的本地安全防线，确保绝密资产防窃听、防物理提取：

- **LAContext 状态机隔离**: 认证流程通过 `BiometricAuthenticator` (位于 `Sources/Core/System/`) 进行封装。`LAContext` 在单次认证事务中进行生命周期销毁，避免上下文状态缓存泄露；在主线程 (`@MainActor`) 调用以保障 UI 交互线程安全性。
- **Secure Enclave 与 Keychain 硬件级保护**:
  - 本地局部保险箱 (Vault) 的物理加密密钥不存储于常规沙盒。系统将派生出的 **DEK (Database Encryption Key)** 存入 iOS/macOS 的 **Keychain** 中。
  - 创建该 Keychain 节点时，强制附加 `SecAccessControl` 配置，将访问权限限定为 `kSecAccessControlBiometryAny` (即必须通过 FaceID 或 TouchID 活体检测)。
  - 当且仅当生物识别校验通过，Keychain 才会向内存安全空间短暂释放 DEK，用于 GRDB 驱动的 SQLCipher 引擎执行全盘流解密。
- **三层密钥派生架构 (Key Derivation)**:
  1. **MEK (Master Encryption Key)**: 位于 Secure Enclave 内部，通过硬件级别保护。
  2. **KEK (Key Encryption Key)**: 由用户的 PIN 码或口令通过 `PBKDF2-HMAC-SHA256` 算法派生得出。
  3. **DEK (Database Encryption Key)**: 利用 MEK 和 KEK 双向异或派生，用作数据库流式加密的核心种子。

### 6.2 敏感数据内存隔离与模糊背景挂起保护 (App Switcher Privacy)

- **模糊背景挂起机制**:
  - 系统全局监听 `UIApplication.willResignActiveNotification`。当检测到 App 将被切入后台或进入任务切换器 (App Switcher) 时，`PrivacyCoverManager` 立即在最顶层 `UIWindow` 上覆盖一层搭载 `UIBlurEffect` 的私密毛玻璃视图 (`PrivacyBlurOverlayView`)，防止敏感笔记与资产内容在系统截屏中泄露。
- **事务静默与内存物理擦除**:
  - 挂起瞬间，系统触发 `VaultSecureCoordinator.suspendActiveTransactions()`，静默所有正在运行合作的 FTS5 和向量写入事务，防止挂起状态下的写写冲突与文件损坏。
  - 内存中持有的临时明文密码或分块内存切片，使用 `memset_s` 进行显式物理置零物理擦除，防范冷启动内存转储 (Cold Boot Dump) 攻击。

### 6.3 HMAC 离线完整性校验 (Offline Integrity Verification)

为了防止用户在离线状态下，其知识库文件（`.sqlite` 或附件）被外部程序恶意篡改，智宇引入了基于硬件 Salt 的 HMAC-SHA256 签名体系：

```mermaid
graph TD
    A[数据文件变更] --> B{是否处于 Debug?}
    B -- 是 --> C[计算 HMAC + 随机 Salt]
    C --> D[保存至 UserDefaults 调试区]
    
    B -- 否 --> E[从 Keychain 读取硬件 Salt]
    E --> F[计算 HMAC-SHA256 签名]
    F --> G[持久化至 global.sqlite 签名库]
    
    H[冷启动加载文件] --> I[重新计算当前 HMAC]
    I --> J{比对持久化签名}
    J -- 匹配 --> K[正常打开金库]
    J -- 冲突 --> L[标记为不可信/触发二次验证]
```

- **硬件盐值 (Hardware Salt)**: 签名密钥派生自存储在 Keychain 中的随机 UUID，该 UUID 在首次初始化金库时生成，并受 Secure Enclave 保护，不可导出。
- **物理隔离**: 生产环境下，签名持久化失败将视为严重安全故障，系统将中断加载逻辑而非静默降级，确保“未经验证的数据绝不加载”。

### 6.4 离线 WAL 释放期 HMAC 计算与冷启动自愈时序

为了确保离线环境下数据库内容不被非法外部应用物理篡改，系统建立了一套基于硬件 Salt 与 HMAC-SHA256 的全生命周期防篡改方案。以下详细展示了在关闭数据库释放 WAL 连接时的指纹重写、冷启动时的完整性校验、以及在 Debug 与 Release 模式下的差异化自愈隔离表现：

```mermaid
sequenceDiagram
    autonumber
    participant App as 主应用/DatabaseManager
    participant SQLCipher as SQLite / SQLCipher (WAL)
    participant Sec as Secure Enclave / Keychain (UUID Salt)

    Note over App, SQLCipher: 阶段一：金库释放与 HMAC 指纹动态更新
    App->>SQLCipher: close() 关闭数据库连接并释放 WAL 共享连接
    App->>SQLCipher: select count(*), group_concat(id) from pages... (读取核心内容特征摘要)
    SQLCipher-->>App: 返回特征指纹载荷
    App->>Sec: 读取受硬件 Secure Enclave 保护的 Hardware Salt (Keychain)
    Sec-->>App: 返回唯一硬件盐值 (UUID)
    App->>App: 基于盐值使用 HMAC-SHA256 计算新数据指纹 (Hash)
    App->>SQLCipher: update local_signatures set signature = Hash (写入 DB 签名库)
    App->>SQLCipher: checkpoint & physical close (确保 WAL 日志完全合入并安全落盘)

    Note over App, SQLCipher: 阶段二：冷启动挂载与防篡改指纹强校验
    App->>SQLCipher: open() 挂载并打开加密金库
    App->>SQLCipher: read local_signatures (提取已保存的 HMAC Hash)
    SQLCipher-->>App: 返回保存的 HMAC Hash
    App->>App: 重新读取当前数据，以硬件盐值计算实时 HMAC-SHA256
    
    alt 实时 HMAC == 保存的 HMAC (数据指纹匹配，未被物理修改)
        App-->>App: 正常加载金库 (Read-Write 读写模式)
    else HMAC 校验不匹配 (指纹冲突/发生篡改/沙盒目录漂移)
        alt 处于 #if DEBUG (开发环境高容错自愈)
            App->>App: 在主控制台输出本地调试警告 (Console Log)
            App->>App: 自动重签名对齐 (重新将当前 HMAC 写入 DB)
            App-->>App: 放行并允许正常打开进行开发调试
        else 处于 RELEASE (生产环境高等级防御)
            App->>App: 阻断加载进程，抛出 SignatureMismatchException
            App->>App: 降级为 403 Read-Only 只读模式，强行拉起生物认证二次校验
        end
    end
```

## 7. iCloud 云端协同与冲突解决策略 (iCloud Sync & Conflict Resolution)

智宇在 Phase 2 执行了深度重构，将云同步职责进行了物理拆分，严格遵循 SRP (单一职责原则)：

### 7.1 三层解耦同步架构

- **CloudStorageProvider (物理驱动层)**:
  - 位于 `Sources/Infrastructure/Storage/Sync/CloudKitSyncProvider.swift`。
  - 负责与 Apple CloudKit 服务的原始网络吞吐、CKRecord 封包及分区（Zone）管理。
- **SyncConflictResolver (算法裁决层)**:
  - 位于 `Sources/Domain/Knowledge/LWWSyncConflictResolver.swift`。
  - 实现了基于物理时钟的 **Last-Writer-Wins (LWW)** 合并算法，不包含任何网络 IO。
- **iCloudSyncService (业务调度层)**:
  - 位于 `Sources/Infrastructure/Storage/Sync/AppCloudSyncService.swift`。
  - 作为 Orchestrator 编排上述两者，并向 UI 层发布 `@Published` 状态。

### 7.2 双向合并与 Last-Write-Wins (LWW) 冲突仲裁机制

- **三向合并 (3-Way Merge) 与 CRDT 设计**:
  - 当同一篇笔记在 iOS 和 macOS 两端在离线状态下同时发生修改时，采用以物理时钟 (带有网络 NTP 偏差校正) 为基础的 **Last-Write-Wins (LWW-Element-Set)** 模型进行行级合并。
  - 针对更复杂的段落修改冲突，引入了轻量级无冲突复制数据类型 (**LWW-Register-CRDT**)。如果两个端点对同一个段落执行了非同义修改，则派生出一个版本树，两段内容同时保留，并在 UI 端高亮标红，提示用户通过 `ConflictResolverView` 进行可视化冲突消解。
- **防脑裂与原子重试**:
  - 若在同步中遇到 `CKError.serverRecordChanged`，系统通过 `conflictUserInfo` 抓取服务器最新版本与本地缓存版本，比对 `changeTag`。
  - 系统使用指数退避算法 (Exponential Backoff) 执行原子级的拉取-合并-推送 (Fetch-Merge-Push) 重试事务，彻底避免多端同步脑裂。

## 8. watchOS 离线录音传输与硬件通信 (watchOS Sync & WCSession)

### 8.1 WCSession 物理硬件通信协议与状态机

在可穿戴设备边缘节点中，离线采集并同步至宿主 App 是 RAG系统非常关键的闭环：

- **硬件通信状态机模型**:

```mermaid
stateDiagram-v2
    [*] --> Disconnected : WCSession.isSupported == true
    Disconnected --> ActivationInProgress : activateSession()
    ActivationInProgress --> Active : sessionDidBecomeActive()
    Active --> Reachable : isReachable == true
    Reachable --> FileTransferPending : enqueueAudioFile()
    FileTransferPending --> Transferring : transferFile()
    Transferring --> TransferSuccess : didFinishTransfer
    Transferring --> TransferFailed : errorCallback
    TransferFailed --> FileTransferPending : retryPolicy
    TransferSuccess --> [*]
```

- **双通道隔离通信协议 (Dual-Channel Protocol)**:
  - **命令/心跳控制字通道**: 使用 `sendMessage(_:replyHandler:errorHandler:)` 承载，传输轻量级 JSON 控制信令（例如：开始/暂停/终止 watchOS 录音、握手包等）。低延时（<50ms）特性极佳。
  - **大数据/文件传输通道**: 使用 `transferFile(_:metadata:)` 承载压缩音频包。该信道由系统后台守护进程 (Daemon) 托管，即使 watchOS App 退出或屏幕熄灭，iOS 底层依然会维持可靠传输。

### 8.2 边缘节点离线缓存落盘机制与分片续传

- **高效录音落盘压缩**:
  - watchOS 端利用 `AVAudioRecorder` 捕获麦克风输入。默认配置为 `AAC-LC` 编码、单声道、`16,000Hz` 采样率、`32kbps` 码率，这是一种极致优化人声频率且兼顾 watchOS 极其紧张的闪存空间的参数配置。
  - 录音生成的文件在手表端沙盒 `Library/Caches/OfflineAudio/` 下建立随机 UUID 命名的 `.m4a` 文件，并实时同步更新本地 SQLite 极简日志。
- **分片与物理擦除防护**:
  - 当录音文件超过 5MB 时，watchOS 的 `AudioSplitter` 会自动执行 1MB 级的分片，以防止大体积文件传输中途因网络不稳定或设备断开而导致重头开始传输。
  - 当 iOS 宿主端调用 `WCSessionDelegate.session(_:didFinish:)` 回调，并携带成功元数据后，watchOS 端认为该段录音已被宿主完整接收。
  - **物理擦除 (Secure Erase)**: 为了防止手表硬件丢失或被窃取后闪存数据被转储，watchOS 采用三遍写零覆盖算法 (Zero-Fill Protocol) 物理覆写该音频文件块，最后调用 `FileManager.removeItem` 从表盘操作系统中物理清空，保障极致隐私。

## 9. 桌面静态小组件设计 (WidgetKit Timeline & AppGroup Sync)

为了实现极速的信息直达，智宇实装了 iOS 主屏幕静态小组件（Home Screen Widget），提供 Small, Medium, Large 三大尺寸以动态展示库内知识节点总量与近期活跃增量：

### 9.1 数据流向与 AppGroup 物理沙盒共享
*   **物理文件墙屏障**：主 App 与 Widget 插件处于完全独立的进程沙盒内。Widget Target `ZhiYuWidgets` 物理禁止直接连接主 App 的 SQLite 数据库，防范锁死和多进程并发损坏。
*   **AppGroup 中转数据缓存**：主 App 每次写入/删除页面时，在后台 Detached 任务中动态计算当前的 `KnowledgeStats` (知识元数据，包含总量与活跃增量)，将其以 JSON 字符串形式编码并写入 AppGroup 共享目录：`AppGroup/zhiyu_shared_stats.json`。
*   **小组件极速渲染**：`KnowledgeStatsWidget` 刷新时，不触发任何数据库连接或复杂的 RAG 检索，直接从 AppGroup 读取该极简 JSON 缓存并快速渲染，内存常驻极低 (<15MB，远低于系统 30MB 门限)。

### 9.2 物理多 Vault 切换瞬间的防竞争与防死锁退避
在用户执行物理金库切换（switchDatabase）瞬间，系统开启 AppGroup 状态锁进行优雅隔离退避，状态转移图如下：

```mermaid
stateDiagram-v2
    [*] --> ReadSharedStats : Widget 触发 Timeline 刷新
    ReadSharedStats --> CheckActiveLock : 检查 AppGroup 状态字
    CheckActiveLock --> Retrying : App 挂载锁 = true (主App正在执行热切)
    Retrying --> ReadSharedStats : 避让 100ms 并回退重试
    CheckActiveLock --> LoadCache : App 挂载锁 = false (安全状态)
    LoadCache --> BuildEntry : 解析 JSON 并构建 WidgetEntry
    BuildEntry --> UpdateTimeline : 返回 Timeline (.atEnd 策略)
    UpdateTimeline --> [*]
```

---

## 10. Siri 快捷指令与 App Intents 调度 (Siri Shortcuts & App Intents)

智宇全面支持 Apple 新一代 `App Intents` 框架，为 Siri 与快捷指令提供免主 App 唤醒的纯后台交互编排：

### 10.1 Siri 意图前后台调度交互链路
当用户通过 Siri 语音或 Shortcuts 点击触发 Capture (记录灵感) / Search (快速搜索) / Stats (知识统计) 意图时，系统后台服务时序图如下：

```mermaid
sequenceDiagram
    autonumber
    participant Siri as Apple Siri / Shortcuts App
    participant Intent as ZhiYuAppIntents (Background Core)
    participant L10n as L10n.Shortcuts Catalog (Dynamic L10n)
    participant Router as DeepLinkService (System Routing)
    participant LLM as LLMService (AI Engine)

    Siri->>Intent: 用户语音唤起 Siri 意图
    Intent->>L10n: 请求提取类型安全的 Siri 词条与短语
    L10n-->>Intent: 返回本地化字符串 (杜绝硬编码 CJK 字符)
    
    rect rgb(40, 45, 55)
        Note over Intent: 根据意图类别进行分流调度
        alt 触发 1.0 统计意图 StatsIntent
            Intent->>Intent: 从 AppGroup 读取共享 JSON 缓存
            Intent-->>Siri: 动态合成对话回复并呈现微缩卡片
        else 触发 2.0 搜索意图 SearchIntent
            Intent->>Router: 解析 query 唤起 zhiyu://search?q=query
            Router-->>Siri: 打开主应用并瞬间在 UI 层拉起搜索 Tab 激活
        else 触发 3.0 记录意图 CaptureIntent
            Intent->>LLM: 后台通过 generate() 执行首字节转写与去燥
            Intent->>Router: 解析 zhiyu://create?title=...&content=...
            Router-->>Siri: 成功拉起全局新建面板，用户可极速录入
        end
    end
```

### 10.2 多语言安全合规性保证
*   **移除硬编码中文字符**：所有 Shortcuts Title、Description 和 Siri 语音引导词全部移除硬编码，使用 `LocalizedStringResource` 通过 String Catalog (`.xcstrings`) 动态加载。这在 `check-code-localization.py` 静态 Gatekeeper 审计中被作为强制绿灯规则。

---

## 11. Deep Link 双端路由分发与空白搜索安全容灾

小组件点击或外部捷径拉起通过标准的 `zhiyu://` Deep Link 架构进行跳转，系统在 AppLayout 层实装了无缝的降级容灾跳转分发：

### 11.1 Deep Link 状态分发与降级状态机

```mermaid
stateDiagram-v2
    [*] --> ResolveURL : DeepLink 捕获 (onOpenURL)
    ResolveURL --> ParseAction : 解析 Scheme 参数
    ParseAction --> SafeCheck : 验证路由有效性
    
    state SafeCheck {
        [*] --> ParameterValidate
        ParameterValidate --> SafePass : 参数有效且安全
        ParameterValidate --> GracefulDowngrade : 参数缺失/非法空搜索
    }
    
    SafePass --> RouteToCreate : zhiyu://create (拉起 Sheet 新建)
    SafePass --> RouteToSearch : zhiyu://search?q=query (拉起搜索并填充)
    
    GracefulDowngrade --> RouteToEmptySearch : 唤起空白搜索 (宽限安全防崩)
    
    RouteToCreate --> TabActivation : 保持当前 Tab 激活状态
    RouteToSearch --> TabActivation : 强行跳转激活 .search Tab
    RouteToEmptySearch --> TabActivation : 强行跳转激活 .search Tab
    
    TabActivation --> [*] : UI 平滑无抖动渲染

---

## 12. 遗留问题与后续微调 (Pending Issues & Fine-tuning)

随着近期统一认证、iCloud 冲突解决、LLM 服务解耦、沙箱升级和竞品对比功能的演进，系统架构在以下几项设计细节上仍待进一步的补充或进行文档/时序图对齐：

### 12.1 插件沙箱池化隔离与熔断机制补充
*   **物理实现状态**：🟢 **已完成物理重构**。已新建 [PluginEnginePool](../../Sources/Infrastructure/Plugins/PluginEnginePool.swift) 对宿主 JSContext 实现最大并发为 4 的隔离保护，并向 `JavaScriptPlugin` 注入了 0.5s Watchdog 物理 CPU 熔断器及 DLP API 审计拦截网关。
*   **设计文档待办**：后续需在 [详细设计文档](DETAILED_DESIGN.md) 的第 3 章中，补充此套并发池化机制与 CPU 熔断的并发安全时序图。

### 12.2 金库防篡改指纹在调试阶段的自动签名对齐
*   **物理实现状态**：🟢 **已完成物理重构**。已在 [DatabaseManager](../../Sources/Infrastructure/Storage/Persistence/DatabaseManager.swift) 中实现：在数据库关闭释放 WAL 连接时，自动同步重写 HMAC 防篡改指纹签名；同时，在 `DEBUG` 编译宏下，若指纹由于沙盒目录漂移等非篡改因素校验不符，系统会打印调试警告并自动进行重签名对齐，在 Release 包下依然严格保留 403 阻断并降级至只读模式。
*   **设计文档待办**：后续需在 [详细设计文档](DETAILED_DESIGN.md) 的第 6 章中，补充 WAL 离线同步期间 HMAC 动态签名的详细算法流程。

### 12.3 信号量同步阻塞消除时序 (异步 `switchDatabase`/`setup`)
*   **物理实现状态**：🟢 **已完成物理重构**。`DatabaseManager.swift` 中已彻底移除所有 `semaphore.wait()` 机制。通过 Swift Structured Concurrency，`switchDatabase` 与热切换均已重构为纯 `async throws`。使用 `Task.sleep` 优雅异步排空活跃连接池事务，完全消除了主线程死锁隐患。

### 12.4 DI 容器的 Actor 隔离与并发安全
*   **物理实现状态**：🟢 **已完成物理重构**。`ServiceContainer` 已引入 `os_unfair_lock` 自旋锁防护，确保在解析（`resolve`）和注册（`register`）时的线程安全性，有效规避 ABA 竞态覆写风险。

### 12.5 领域层契约完全穿透
*   **物理实现状态**：🟢 **已完成物理重构**。通过 Phase 1 & 2 的 DIP 专项治理，`VectorIndexableStore` 及其调用者已全量切回 `any EmbeddingProvider` 协议，领域层已彻底切断对 L1 `EmbeddingManager` 具体类的物理依赖。

### 12.6 级联式多源网页捕获引擎 (CaptureCascadeEngine)
*   **物理实现状态**：🔴 **未来演进**。
*   **软件时序设计**：集成在 `Sources/Infrastructure/Network/`。
```mermaid
sequenceDiagram
    participant User as 用户分享链接
    participant Mgr as IngestManager
    participant Eng as CaptureCascadeEngine
    participant Local as 本地 OCR 提取 (端侧 Vision)

    User->>Mgr: 触发 Ingest(URL)
    Mgr->>Eng: executeCascadeGrab()
    alt 1. 直连与UA伪装抓取
        Eng->>Eng: 请求成功且无防爬
    else 2. Reader API 中转
        Eng->>Eng: 触发中转服务抓取网页正文
    else 3. Headless 浏览器渲染 (Puppeteer/Playwright-like)
        Eng->>Eng: 本地或云端 Headless 执行完整 JS 渲染后抓取
    else 4. 视觉截屏与本地 OCR
        Eng->>Local: Headless 获取截屏大图
        Local-->>Eng: 利用端侧 Vision 提取出正文 Markdown
    end
    Eng-->>Mgr: 返回清洗后的纯净 Markdown
```

### 12.7 外置 AI 代理 CLI/SDK 自动化总线设计
*   **物理实现状态**：🔴 **未来演进**。
*   **时序与通信设计**：智宇在 `AppIntents` 控制层声明可供 Siri 或 Shortcuts 呼叫的 Intent。第三方代理工具（例如 Cursor 或者是自定义 shell 脚本）通过调用系统的 `Shortcuts` CLI（如 `shortcuts run "智宇自动化摄入" -i input_file.md`）向 AppGroup 共享目录写入缓存包，智宇后台守护程序捕获变更后，在 App Intent 线程沙箱内拉起 `DatabaseManager` 完成增量 FTS5 写入与向量余弦检索。


检索。


