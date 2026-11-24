# 智宇 (ZhiYu) 系统集成测试策略与防线规范

## 1. 测试体系总览 (Testing Architecture)

为确保智宇 (ZhiYu) 的 **RAG 语义检索管线**、**多 Vault 专属物理库热切换**、**跨设备数据同步** 以及 **插件沙盒系统** 能够万无一失地协同运行，本系统建设了以“纯净隔离性”为首要原则的三级测试防线：

```
                    +--------------------------------+
                    |      UI UI 级自动化快照测试    |  <-- SnapshotTesting 库 (Features/UI)
                    +--------------------------------+
                                    |
                    +--------------------------------+
                    |  🧪 L1.5-L3 跨层模块集成测试   |  <-- XCTest 集成测试 (Domain/Storage/Sync)
                    +--------------------------------+
                                    |
                    +--------------------------------+
                    |  🧪 单元隔离测试与 Mock 校验    |  <-- L0/L1 底层单体测试
                    +--------------------------------+
```

---

## 2. 核心隔离机制：单测分流沙盒与干净 DI 容器

集成测试极易因为“静态全局单例”或“后台线程未停机任务”相互污染。智宇对此实施了**两重绝对隔离锁**：

### 2.1 启动期物理宿主隔离 (`ProductionAppLauncher` / `UnitTestHostApp` 机制)
在测试运行期，单测由独立的 `UnitTestHostApp` 空壳宿主承载，与正式应用入口 `ProductionAppLauncher` 物理分离，**彻底禁止真实主应用 `ZhiYuApp` 和 `AppEnvironment` 的自动实例化**。这阻断了任何后台 CloudKit 轮询、大模型静态解析或生产库数据库的连接。

### 2.2 用例级依赖容器重置
在每个集成测试用例执行前后，强制调用 `ServiceContainer.shared.reset()` 重置依赖注入容器，保证每个用例的 `@Inject` 解析出来的都是绝对独立的 Mock 服务或纯净物理数据库连接，杜绝用例间数据污染。

---

## 3. 关键集成测试策略与核心方法

### 3.1 物理存储与 WAL 事务集成测试
* **核心内容**：测试专属物理 Vault 热切换时，多库 WAL (Write-Ahead Logging) 开关对稳定性的影响。
* **测试方法**：
  1. 实例化真实的 `DatabaseManager` 并加载临时物理路径；
  2. 触发 `VaultService.shared.switchToVault(...)`；
  3. 开启多线程高并发读写，验证 GRDB `DatabasePool` 是否产生锁等待，是否完美广播并刷新 `aiInsightStore`。

### 3.2 LLM / RAG 管线流式集成测试
* **核心内容**：在脱离真实 OpenAI / Anthropic 网络环境下，模拟整套 RAG（召回+改写+重排+流式生成）的无缝集成。
* **测试方法**：
  1. 注册 `MockLLMClient` 进容器以接管底层 HTTP 流量；
  2. 灌入特定 Mock 语料（含有明确的金沙箱恶意注入文本）；
  3. 执行 `llmService.chatStream(...)`，捕获异步文本迭代流，验证 `PromptSanitizer` 的 DLP 消毒过滤是否触发，验证 RAG 吞吐的时序完整性。

### 3.3 LWW (Last-Write-Wins) 多终端同步冲突解决测试
* **核心内容**：当多台 iOS/macOS 终端在 iCloud 断开期间对同一知识页面进行了不同修改，重新连线时如何依据时钟与版本解决冲突。
* **测试方法**：
  1. 实例化 A、B 两个独立的物理 PageStore 实例；
  2. 对同一 UUID 页面修改不同的内容与更新时间戳（T1, T2，其中 T2 > T1）；
  3. 触发 `DataCoordinator.resolveConflict(...)`；
  4. 验证 LWW 规则是否判定 T2 的修改获胜并合并至本地，验证是否有防覆盖日志日志正常写入。

### 3.4 插件安全边界与 Watchdog 熔断集成测试
* **核心内容**：验证死循环 JS 脚本能被熔断守护线程强行切除。
* **测试方法**：
  1. 载入包含死循环代码（如 `while(true){}`）的 JavaScript 插件；
  2. 调用 `PluginRegistry.shared.execute(...)`，触发后台 Watchdog 计时；
  3. 验证 Watchdog 在毫秒级监控检测到超时（默认 `0.5s`，对应 `PluginConstants.Sandbox.jsExecutionTimeLimitSeconds`）后是否能成功强行注销 `JSContext`，释放主线程。

---

## 4. Golden Set RAG 语义评估自动化测试

为了杜绝在后续业务修改中破坏召回率精度，本项目特别引入了 **RAG 语义 Golden Set 评估管线**。

### 4.1 评估集构成
评估集（包含 50+ 组核心业务场景）由以下三个维度组成：
* **用户原始 Query**（例如：“如何配置 SQLite WAL 多库切换性能？”）
* **金准真值上下文片段 (Ground Truth Context)**（即系统中应该被 100% 召回的知识块）
* **期望引用的真值页面 (Expected Document Link)**

### 4.2 自动化校验红线
```swift
// 位于 Tests/Unit/Domain/RAGEvaluationServiceTests.swift
func testRAGGoldenSetPerformance() async throws {
    let evaluator = GoldenSetEvaluator()
    let results = await evaluator.runEvaluation(set: RAGGoldenSet.standard)
    
    // 📊 评估召回率 (Recall) 和检索精度 (Precision)
    print("📊 Golden Set 召回率: \(results.recallRate)%")
    print("📊 Golden Set 检索精度: \(results.precision)%")
    
    // 🛡️ 熔断红线：任何合并入主干的代码必须通过此校验，混合检索精度不低于 90%
    XCTAssertGreaterThanOrEqual(results.recallRate, 90.0, "❌ RAG 语义召回精度低于安全红线 90%！请优化 Embedding 权重或 FTS5 权重分词参数。")
}
```

### 4.3 运行评估集成命令
在本地开发或 CI 中，通过以下命令触发整体 RAG 质量度量熔断校验：
```bash
xcodebuild test -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:ZhiYuTests/RAGEvaluationServiceTests > build/rag_evaluation.log 2>&1
```
可在 `build/rag_evaluation.log` 中查看每一条 Query 的召回命中率诊断，防止算法退化。
