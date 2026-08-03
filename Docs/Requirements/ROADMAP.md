# 智宇 (ZhiYu) 产品演进路线图 (Roadmap)

## 📌 版本发布战略总览 (Release Strategy)

智宇 (ZhiYu) 作为一款 AI 原生的三端知识管理应用，其核心演进遵循 **“稳固内核 → 业务瘦身解耦 → 质量安全熔断 → 开放生态变现”** 的进阶发布路径。

```mermaid
gantt
    title 智宇 (ZhiYu) 版本演进时间线
    dateFormat  YYYY-MM
    axisFormat  %m月
    section 阶段一 (MVP)
    验证基本闭环           :done, a1, 2026-01, 2026-02
    section 阶段二 (v1.0)
    严格并发与多端发布      :active, a2, 2026-03, 2026-04
    section 阶段三 (v1.5)
    架构拆分与质量防防线    :a3, 2026-05, 2026-06
    section 阶段四 (v2.0)
    同步插件生态与端侧AI     :a4, 2026-07, 2026-09
```

---

## 🗺️ 阶段演进详图

### 🎯 阶段一：MVP (Minimum Viable Product) — 验证基本闭环 (已完成)
* **核心焦点**：实现本地语义分块与混合检索的基本业务闭环。
* **主要特性**：
  * **混合存储**：引入 SQLite (GRDB.swift) 作为核心持久化引擎，支持 SQLite 原生的全文检索 (FTS5)。
  * **语义向量化**：支持将 Markdown 内容进行粗粒度物理分块，并通过本地/远程大模型提取语义嵌入 (Embeddings) 实现向量化匹配。
  * **AI 实验室**：提供基于 OpenAI / Ollama 网关的直接一问一答文本生成页面，搭建极简 Chat 面板。
  * **智能图谱**：初步实现 2D 语义缩放图谱，为双向链接提供可视化交互。

---

### 🚀 阶段二：v1.0 — 开启严格并发与多平台发布 (当前版本)
* **核心焦点**：消灭冷启动闪退，支持 iOS / macOS Catalyst / watchOS 三端独立编译，引入高阶安全与本地化。
* **主要特性**：
  * **Swift 6 Concurrency 完全适配**：开启 `SWIFT_STRICT_CONCURRENCY: complete` 严格并发编译选项，全线消除 Data Race 隐患。
  * **依赖倒置与 DIP**：实现轻量级 DI 容器 `ServiceContainer` 和 `@Inject` 包装器，全面阻断 UI Feature 跨层依赖基础设施具体类。
  * **SPM 模块化架构演进 (v1.5 Milestone)**：采用 `UFP` (通用平台) + `ZhiYu` (业务大脑) 本地多 SPM Package (`UFPCore`, `UFPStorage`, `UFPDesignSystem`, `ZhiYuDomain`, `ZhiYuAICore`, `ZhiYuFeatures`) 架构，实现编译期硬隔离与毫秒级独立单元测试。
  * **多 Target 优化**：定制 `project.yml`。对 watchOS 客户端进行重型视图和后台数据流物理裁剪，保障轻量级载荷；支持 macOS Catalyst 桌面端多窗口运行与 Mac 键盘快捷键。
  * **底层安全防线**：集成 SQLCipher 对本地数据库进行全盘硬件级物理加密；引入 HMAC-SHA256 对敏感知识库文件进行防篡改指纹签名，并借助 `signatureRepository` 持久化，保护用户数据资产。
  * **多语言强类型本地化**：通过 `L10n` 和 `.xcstrings` 收口，静态审查工具一键拦截裸露字面量。
  * **空间计算适配**：实装 `VisionProSpatialView`，提供 Vision Pro 基础空间视觉与交互展示。

---

### 🧱 阶段三：v1.5 — 架构微服务化拆分与质量防线建设 (当前重构焦点)
* **核心焦点**：消除 `LLMService` 神类、给 `AppStore` 瘦身，补齐全体系单测覆盖率红线，拦截质量劣化。
* **主要特性**：
  * **AI 基础设施拆分**：将 `LLMService` 彻底剥离并解耦为 `ChatLLMService` (对话编排)、`IngestLLMService` (摄入/拆分/折叠) 与 `RerankService` (同义扩展与重排)，由门面类透传，降低代码文件复杂度。
  * **AppStore Facade 物理减脂**：创建全新的 `MediaStore` 统一整合 OCR、PDF 元数据存取与 Snapshot 截图加载；完成 `SearchStore` 的物理完全切除，各 Store 独立挂载并统一注册至 DI 容器，实现状态单一源。
  * **代码覆盖率 85% 自动熔断**：通过 `assert-test-coverage.py` 流水线脚本，对核心领域层 (`Sources/Domain`) 强加 85% 单元测试覆盖率红线，低于此红线 CI 自动拒绝合并（剔除了旧有后缀豁免）。
  * **Golden Set 质量度量**：集成 50+ 组核心场景的召回率自动化检验，低于 90% 准确性要求时强行报错。
  * **ZhiYuTests.swift (37KB) 物理拆解**：打碎超长测试文件为 4 个职责分明的高内聚测试模块。
  * **三端 UX 质感升华**：统一实现四大模块的 `Empty States` 空白视图、通用 `AppErrorView` 错误面板、以及优雅滑入的 `Loading Skeleton` 骨架屏组件。

---

### 🛡️ 阶段 3.5：v2.3 — 全量开源库物理隔离与 AI 合成实验室加固 (已完成 · 2026-08)
* **核心焦点**：实现全量 8 大开源库的物理隔离、彻底消除源码直引依赖，构建离线优先管理体系与 AI 合成实验室全链路容错。
* **主要特性**：
  * **全量开源库物理隔离与单点重导出**：
    - `GRDB.swift` 物理收敛至 `UFPStorage` SPM 包，通过 `GRDBReexport` 唯一导出，`Sources/` 层 33 个文件 `import GRDB` 全量替换为 `import UFPStorage`；`StorageConstants` 剥离所有业务表名。
    - `ZIPFoundation` 完全解耦，封装为 `ZIPFoundationArchiver` 适配器（内置 VULN-014 路径穿越防护），`PluginLoader` 改为依赖注入 `FileArchiverProtocol`。
    - `lottie-ios` 与 `swift-markdown-ui` 封装于 `UFPDesignSystem` SPM 包。
    - `SwiftJSONSanitizer` 与 `PartialJSON` 封装于 `ZhiYuAICore` SPM 包。
  * **离线优先与自动化依赖审计门禁**：
    - 建立 `Config/opensource_dependencies.yml` 开源注册表 SSOT。
    - 所有 Package.swift 统一为 `path: opensrcRoot/名称` 本地路径依赖，零 GitHub URL 网络依赖。
    - 扩展 Gatekeeper CI 门禁（`check-arch-opensource-adapters.py` 与 `check-arch-dependency-registry.py`），实现 4/4 项自动化硬卡。
  * **AI 合成实验室全链路容错与加固**：
    - **双层 JSON 自愈**：`JSONRepairProcessor` 兼具语法修复与流式截断补全。
    - **JSON Schema 源头约束**：`PromptConstants.Schemas.quizJSONSchema` 强类型 schema 在 Prompt 尾部强制注入。
    - **Mermaid 前置安全拦截**：`SynthesisProcessor.safeMermaidSyntax` 拦截冒号/问号/括号等危险字符并双引号转义，防止渲染崩溃。
    - **[[WikiLink]] 双向联动**：修复 Markdown 转义，实现 `SynthesisReportView` 到 `Router` 页面推栈的导航联动。

---

### 🌌 阶段四：v2.0 — iCloud 自动同步、开放插件 SDK 与变现生态 (展望)
* **核心焦点**：打通多终端无缝同步，开放第三方 JS 沙盒插件市场，建立商业化变现平台。
* **主要特性**：
  * **多 Vault LWW (Last-Write-Wins) iCloud 自动融合**：集成 CloudKit 增量同步，在多终端网络断开恢复后，基于修改时间戳和版本指纹自动解决数据合并冲突。
  * **JavaScript 插件 CLI 与调试工具 SDK**：为社区生态开发者提供命令行 CLI 脚手架，支持局域网无线连接真机进行插件实时热重载 (Hot Reload) 与脚本调试。
  * **插件市场支付变现**：推出变现模块 `MonetizationInfo`，集成 Apple StoreKit 2 代内购订阅，使能插件作者变现，开启智宇生态系统。
  * **离线 Edge AI 与 Ollama 本地网络全连通**：完善 `OllamaAdapter` 本地 API 请求与响应处理，基于 `custom_local_llm_enabled` 控制项支持连接私有端侧 Ollama / LM Studio 节点；同时在 iOS Simulator / iPhone 17 上集成本地 CoreML 编译器。
  * **高阶 3D 拓扑图谱演化与社区聚类**：解禁 `graph_advanced_enabled` 控制项，引入时间轴演化回放动画与 Louvain 图聚类算法，自动划分知识大类。
  * **双人 TTS 播客音轨 (Audio Overview)**：解禁 `audio_overview_enabled` 控制项，支持基于文档自动合成双人对话播客音轨。
  * **加密知识分片**：允许用户导出“思维切片”分享给他人，支持端到端加密传输。

---

## 🚫 阶段准入门槛与显式 Non-Goals (Quality Gates & Non-Goals)

为了维护项目敏捷性并防止过度设计，智宇定义了明确的“非目标”与质量门禁：

### 🧱 阶段二 (v1.0) & 阶段三 (v1.5) 准入红线
1. **并发安全红线**：Swift 6 严格并发检查错误数必须物理清零，任何 Data Race 警告将被 CI 拦截。
2. **测试覆盖红线**：L1.5 领域层物理单测覆盖率必须达到 **85%** 以上，Golden Set 混合检索召回率必须稳定在 **90%** 以上。
3. **架构解耦红线**：L2 Features 层绝对禁止物理引入 L1.0 基础设施（如 SQLiteStore）具体类。

### ⚠️ 显式 Non-Goals (当前不实施)
1. **SQLite 数据库静态加密**：鉴于目前多终端（如 Apple Watch）轻量化与自动化 UI 测试的高频需求，并且出于性能调优考量，**经与用户确认，本阶段暂不实施 SQLite 静态加密功能 (SQLCipher)**。这作为非目标，防止引入无必要的密钥管理负荷。
2. **多端脑裂自动合并 (LWW)**：在阶段四打通 iCloud 同步前，不在本地强行处理多设备的实时冲突，本地仅负责生成指纹签名并保障指纹的持久化一致。

---

## ⚡ 遗留问题与微调建议 (Pending Issues & Fine-tuning Suggestions)

基于资深开发与架构审计，以及 Google NotebookLM、llm_wiki 等竞品对比，整理出系统在未来版本迭代中必须解决的技术债务与增强方向：

### 1. 架构与并发债务
- [ ] **彻底消除信号量同步阻塞**：将数据层的 `switchDatabase` 与 `setup` 方法重构为 `async throws` 异步机制，移除所有 `semaphore.wait`，消除单核或 watchOS 上的死锁隐患。
- [ ] **DI 容器全局 Actor 化**：将 `ServiceContainer` 改造为全局 Actor 或以细粒度锁保护，保证多端并发和 App Extension 桌面小组件读取时的依赖安全。
- [ ] **领域契约穿透重构**：将 L2 `KnowledgeStore` 的数据操作彻底解耦，使其仅依赖 L1.5 定义的 Repository 契约，杜绝 L2 直接拉起 L1 `SQLiteStore` 的隐式越权。

### 2. 安全与底层硬化
- [ ] **Keychain 生产降级强隔离**：通过 `#if DEBUG` 限制 `UserDefaults` 的兜底明文存储，在生产发布包中绝对禁止降级，若 Keychain 写入失败直接闪退，保证金库安全。
- [ ] **JSC 沙箱动态执行限制**：在插件的 `JSContext` 虚拟机中禁用 `eval`、`Function` 等动态代码执行，只暴露 Value Type Copy 桥接对象。
- [ ] **GRDB 连接池确定性关闭**：在 `DatabasePool` 释放前，显式调用 GRDB 的 `close()` 关闭数据库连接并写入 WAL，避免产生 SQLite 驱动警告。

### 3. UI 与体验缺陷
- [ ] **安全气泡降级 Banner 美化**：利用 Glassmorphism 半透明磨砂玻璃卡片美化降级 UI，并为重新验证的加载状态引入平滑收缩动画。
- [ ] **全景引导欢迎金库 (Welcome Vault)**：将初次启动的欢迎金库改造为拥有 15+ 节点、错落有致的“知识星团”3D 引导图谱，提升冷启动的“Aha Moment”。

### 4. 竞品启发之杀手级功能规划
- [ ] **级联式反防爬多源捕获引擎**：内置微信文章、音视频转录（端侧 Whisper）以及 6 级抓取反爬（直连、UA、代理池、Reader API、Headless、OCR）的智能导入引擎。
- [ ] **端侧双人播客 (Audio Overview Native) 生成**：通过本地 SLM 提炼 RAG 检索上下文并重写为对话剧本，利用系统 TTS 或轻量模型在本地渲染出双声道音频。
- [ ] **外置 Agent 自动化总线**：利用 App Intents 将智宇的混合检索与向量归档能力对第三方 CLI/SDK 工具链（如 Cursor/Claude Code）开放。
- [ ] **弹性混合云端代理 RAG 模式**：通过本地脱敏（匿名化敏感词）加云端中转大模型的双重架构，安全处理超大长文本综述。
