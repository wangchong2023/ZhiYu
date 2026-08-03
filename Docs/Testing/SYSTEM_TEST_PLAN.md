# 智宇 (ZhiYu) 系统测试计划 & 验收标准

本文件定义了智宇在发布前的质量检查红线与验收准则 (Acceptance Criteria)。

---

## 1. 测试范围 (Test Scope)
覆盖 iPhone、iPad 和 Mac 三个平台的以下核心模块：
*   知识库 (AppStore & SQLite)
*   3D 知识图谱 (Graph Engine)
*   AI 智能层 (RAG & LLM Adapter)
*   插件系统 (Plugin Sandbox)
*   安全金库 (Vault & Biometrics)

---

## 2. 功能验收标准 (Functional Acceptance Criteria)

| 模块 | 验收项 | 通过标准 | 优先级 |
| :--- | :--- | :--- | :--- |
| **RAG 管道** | 端到端检索生成 | 搜索词召回准确度 > 90%，AI 总结包含引用链接。 | P0 |
| **导入模块** | 大文件导入稳定性 | 支持 10MB 以上 Markdown 文件一次性导入，不卡顿。 | P1 |
| **插件沙箱** | 权限隔离验证 | 非法脚本尝试读写库外文件必须被系统拦截。 | P0 |
| **同步一致性** | 向量库对齐 | 修改页面内容后，向量索引必须在 5s 内完成静默更新。 | P1 |

---

## 3. 非功能性指标 (Non-Functional Benchmarks)

### 3.1 性能红线
*   **启动速度**：冷启动至首页出现时间 < 1.5s (iPhone 13+)。
*   **图谱性能**：10,000 节点缩放流畅度 > 55 FPS。
*   **内存占用**：正常运行期间内存抖动 < 50MB。

### 3.2 兼容性矩阵
*   **iOS**: 适配 iOS 17 - iOS 18，完美支持动态字体 (Dynamic Type)。
*   **macOS**: 支持 macOS 14 (Sonoma) 及以上版本，适配”台前调度 (Stage Manager)”。

---

## 4. 压力测试场景 (Stress Testing)
*   **极限导入**：连续导入 1000 个 10KB 级别的碎知识点，检查 `IngestQueue` 的背压机制。
*   **极限链接**：创建一个拥有 500 个 `[[链接]]` 的超长页面，验证 Markdown 渲染性能。

## 4.5 混沌测试 (Chaos Testing)
模拟极端环境以验证系统的事务一致性与恢复能力：

| 场景 ID | 动作 | 预期结果 | 验证重点 |
| :--- | :--- | :--- | :--- |
| **CH-01** | 在 AI 摄入写入数据库瞬间断电/强制退出 | 重启后数据库无损，未完成任务自动重试 | SQLite 事务原子性 |
| **CH-02** | 在向量化计算中途断开网络连接 | 系统进入等待状态，重连后从断点续传 | IngestQueue 弹性 |
| **CH-03** | 模拟物理文件系统权限被外部意外撤销 | App 弹出明确权限提示，且不发生闪退 | Security-Scoped Bookmarks |
| **CH-04** | 注入 50,000+ 极短页面进行压力搜索 | UI 响应延迟控制在 500ms 内 | 索引性能红线 |
| **CH-05** | 利用 MockDatabaseWriter 在写入事务中途抛出 SIGKILL 中断 | 重启后冷启动触发 ACID 事务恢复，自动检测 WAL 并依靠 LWW 指纹一致性回滚修复，无数据损坏 | 本地容灾完整性 |
| **CH-06** | 注入高频外置 CLI/App Intent 写入请求 (并发频率 > 10Hz) | 自动触发 10Hz 限流拦截器，确保前台 UI 图谱渲染稳恒 55+ FPS，系统不崩溃且无死锁 | 自动化总线防御 |

---

## 4.6 UI 自动化 Flaky 测试自愈防御机制 (UI Automation Flaky Defense)

针对在多 Target、大并发自动化跑测中暴露的模拟器环境偶发抖动 (Flaky Test) 痛点，系统制定以下自动化容错自愈规范：

### 1. 跨金库测试 Seeding 跳过隐患 (UserDefaults 隔离)
*   **问题背景**：在 `testVaultSwitchingAndSeedingFlow` 切换金库测试中，如果前一次测试已经在 `UserDefaults` 写入了 `seeded_vault_<UUID> = true`，而测试进程与主 App 进程间沙盒 UserDefaults 未能擦除隔离，会导致新金库创建后被跳过数据播种，进而使列表空置、用例超时报错。
*   **自愈设计**：UI 测试在 `setUp` 阶段为 `XCUIApplication` 传递统一的启动参数（如 `-ResetUserDefaults`）。主 App 引导入口（如 `ZhiYuApp.swift`）捕获此参数后，同步清空 `seeded_vault_` 前缀的所有旧播种键，确保每一轮 UI 跑测都能 100% 幂等重新触发 Seeding！

### 2. 模拟器屏幕旋转崩溃隐患 (SpringBoard Connection Timeout)
*   **问题背景**：高负载 CPU 环境下，`ResponsiveLayoutTests` 触发屏幕旋转与 SizeClass 切换时，容易产生 SpringBoard 与 UI 测试驱动进程的通信连接超时，引起 `Failed to get matching snapshot: Application is not running` 偶发报错。
*   **自愈设计**：在旋转操作前强制插入 `sleep(1)` 等缓冲，为渲染管道和系统旋转动画预留充足时间；在 snapshot 通信失败时，由自愈防御器（Self-Healing Handler）拦截错误并自动调用 `XCUIApplication().launch()` 物理重启驱动对齐。

---

## 5. 验收签名 (Sign-off)
测试完成并发布需通过以下门禁：
1. [ ] 100% 的 P0 核心验收用例全部通过。
2. [ ] 核心领域层 (Domain) 汇总覆盖率 > 85%（以 `Tools/ci/assert-test-coverage.py` 熔断红线为准，拒绝低于红线的代码合并）。
3. [ ] 单元与集成测试套件大回归 100% 绿通（0 Unexpected Failures）。
4. [ ] 内存泄漏 (Instruments) 扫描结果为零，无任何 Blocked Thread。
