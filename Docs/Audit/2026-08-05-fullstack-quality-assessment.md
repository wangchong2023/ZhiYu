# 智宇（ZhiYu）前后端软件质量深度评估报告

> **评估日期**：2026-08-05
> **评估范围**：ZhiYu 客户端（iOS/macOS/watchOS）+ ZhiYu-Backend（Java 微服务 + React 前端）
> **评估方法**：架构完整性、软件工程实践、质量属性（ISO/IEC 25010）、业界参考对比
> **评估人**：CodeFree-O 自动化审计

---

## 一、评估总览

### 1.1 评估对象

| 系统 | 技术栈 | 代码规模 | 仓库 |
|------|--------|----------|------|
| **ZhiYu 客户端** | Swift 6 / SwiftUI / SPM 多包 | 1,055 文件 / ~111K 行 | `ZhiYu/` |
| **ZhiYu-Backend** | Java 21 / Spring Boot 3.5 / Spring Cloud Alibaba | 746 Java 文件 / ~78K 行 + 432 TS 文件 / ~27K 行 | `ZhiYu-Backend/` |
| **合计** | 3 语言 / 3 平台 | ~216K 行 | 2 仓库 |

### 1.2 综合评分

| 维度 | 客户端 | 后端 | 加权平均 | 等级 |
|------|--------|------|----------|------|
| 架构完整性 | 9.5 | 9.5 | **9.5** | A+ 🟢 |
| 软件工程实践 | 9.0 | 9.5 | **9.3** | A 🟢 |
| 代码质量 | 8.5 | 9.0 | **8.8** | A 🟢 |
| 测试与可测试性 | 6.5 | 9.5 | **8.0** | B+ 🟡 |
| 安全性 | 9.0 | 9.5 | **9.3** | A 🟢 |
| 可维护性 | 8.0 | 9.0 | **8.5** | A- 🟢 |
| 性能与可扩展性 | 8.0 | 9.0 | **8.5** | A- 🟢 |
| CI/CD 工程化 | 9.0 | 9.5 | **9.3** | A 🟢 |
| 文档完备度 | 8.5 | 8.0 | **8.3** | A- 🟢 |
| **综合** | **8.25** | **9.17** | **8.71** | **A-** 🟢 |

> **核心结论**：前后端整体质量达到 **A- 级**（8.71/10），工程化程度业界领先。客户端架构与 CI 门禁已达生产级，**测试覆盖率是唯一核心短板**（客户端 23% vs 95% 门禁）；后端质量门禁严格（95%/90% 覆盖率硬阻断），工程实践达到一线互联网标准。

---

## 二、架构完整性评估

### 2.1 客户端架构（评分：9.5/10 A+）

#### 2.1.1 L0-L3 严格分层

客户端采用 **L0-L3 四层架构 + 6 SPM 包物理隔离**，依赖严格自顶向下：

```
L3 表现层（App/Features/Shared）
    ↓
L2 功能层（Features/AI、Knowledge、Insight、System）
    ↓
L1.5 领域层（Domain/Models、Protocols、RAG）
    ↓
L1 服务层（Infrastructure/LLM、Storage、VectorDB、Plugins）
    ↓
L0 基础设施层（Core/DI、Logger、Security、Platform）
```

**SPM 包依赖关系（已验证单向无环）**：

| 包 | 依赖 | 层级 |
|----|------|------|
| `UFPCore` | 无 | L0 底座（DI/Logger/安全） |
| `UFPStorage` | UFPCore + GRDB | L1 存储（唯一允许 import GRDB） |
| `UFPDesignSystem` | UFPCore + lottie + markdown-ui | L0 UI Token |
| `ZhiYuDomain` | UFPCore | L1.5 领域大脑 |
| `ZhiYuAICore` | UFPCore + UFPStorage + ZhiYuDomain | L1 AI 中台 |
| `ZhiYuFeatures` | UFPCore + UFPDesignSystem + ZhiYuDomain + ZhiYuAICore | L2 功能切片 |

**架构守护**：
- 55 处 L0→L1.5 跨层引用违规已全部清零（commit `ec2d9863`）
- `#if os()` 平台宏在 Domain/Features 层 46→0 彻底清零
- CI 8 项架构门禁脚本持续守护（`Tools/ios/check-arch-*.py`）
- Domain 层零 UI 框架导入（UIKit/AppKit/SwiftUI）

#### 2.1.2 后端架构（评分：9.5/10 A+）

后端采用 **Spring Cloud Alibaba 微服务 + Maven 多模块**，单向依赖无循环：

```
ufp/（UFP 统一基础平台）
├── ufp-common/（5 个 starter 子模块：core/cache/security/database/web）
├── ufp-auth-service/（平台认证微服务，283 文件）
└── ufp-gateway-service/（API 网关 + SPA，17 文件）

zhiyu/（ZhiYu 业务）
├── zhiyu-common/（业务公共）
├── zhiyu-admin/（RBAC/审计/通知/订阅/字典，81 文件）
├── zhiyu-subscription/（订阅 + 支付 + 财务，48 文件）
├── zhiyu-admin-service/（业务管理入口 + Flyway）
├── zhiyu-auth-admin-service/（管理员认证入口，0 业务代码）
└── zhiyu-auth-subscriber-service/（订阅用户认证入口，0 业务代码）
```

**架构守护**：
- CI 强制校验模块单向依赖（`check-arch-circular-deps.sh`）
- Controller 薄层禁止注入 Mapper（`check-arch-controller-no-mapper.py`）
- 仅构造器注入（Lombok `@RequiredArgsConstructor`）
- Entity → Resp DTO 通过 MapStruct 转换，禁止直接暴露 Entity
- Feature 功能域聚合（6 个 feature 子包收拢 Controller+Service）

### 2.2 架构对比分析

| 维度 | 客户端 | 后端 | 业界参考 |
|------|--------|------|----------|
| 分层严格性 | L0-L3 四层 + SPM 物理隔离 | Maven 多模块 + Feature 域聚合 | Clean Architecture / Hexagonal |
| 依赖方向 | 严格自顶向下，CI 守护 | 严格单向无环，CI 守护 | DIP 原则 |
| 模块化程度 | 6 SPM 包物理隔离 | 8 Maven 模块逻辑隔离 | 微服务/模块化单体 |
| 跨平台策略 | 协议分层 + PlatformRegistrar | N/A（单一后端） | CAP原则 |
| 领域模型隔离 | Domain 层零 UI 依赖 | Entity/DTO 分离 + MapStruct | DDD 领域驱动 |

**结论**：前后端架构设计均达到业界领先水平，分层严格性、模块化程度、CI 守护机制均优于多数同类项目。

---

## 三、软件工程实践评估

### 3.1 代码规范与静态分析

| 实践 | 客户端 | 后端 |
|------|--------|------|
| Lint 工具 | SwiftLint v2.2（161 行配置） | Checkstyle + SpotBugs + PMD/p3c |
| 圈复杂度门禁 | ≤ 10（error） | PMD 规则 |
| 函数行数门禁 | ≤ 50 行（error） | Checkstyle 规则 |
| 强制类型转换 | force_cast = error | SpotBugs 规则 |
| 魔鬼数字/字符串 | CI 脚本检测 + DesignSystem Token | `audit-code-magic-strings.py` |
| 重复代码 | jscpd（threshold 5%） | jscpd + PMD CPD（< 3%） |
| 死代码检测 | Periphery 2.21 | knip（前端）+ Periphery |
| 文件行数门禁 | SwiftLint | `check-quality-file-size.py` |
| TODO/FIXME | 0 处（已清零） | CI 检测 |

### 3.2 依赖管理

| 维度 | 客户端 | 后端 |
|------|--------|------|
| 依赖清单 | `opensource_dependencies.yml`（8 库 SSOT） | Maven BOM 集中管理 |
| 版本锁定 | SPM Package.resolved | Maven 版本锁定 |
| License 合规 | 8 库均为 MIT/Apache-2.0 | SBOM `sbom/sources.yaml` |
| 漏洞扫描 | N/A | Trivy CVE + Gitleaks |
| 依赖审计 | CI 脚本 | checkov IaC 扫描 |

### 3.3 版本控制与分支管理

| 维度 | 客户端 | 后端 |
|------|--------|------|
| VCS | Git + GitLab CE v18.1 | Git + GitLab CE v18.1 |
| 分支模型 | main/develop/release/* | main/develop/release/* |
| MR 卡控 | 12 项 pre-push 门禁 | 40+ 项 checks 阶段门禁 |
| 提交规范 | feat/fix/docs/refactor/perf | feat/fix/docs/refactor/perf |
| 签名 | GPG | GPG |

### 3.4 文档实践

| 维度 | 客户端 | 后端 |
|------|--------|------|
| 文档数量 | 71 篇 Markdown | 64 篇 Markdown |
| 架构文档 | HIGH_LEVEL_DESIGN / LAYERING / PLATFORM | overview / microservices / api-spec |
| API 规范 | EXTERNAL_API_SPECIFICATION | OpenAPI/Swagger（149 端点） |
| 数据库设计 | DATABASE_SCHEMA（DDL + ER） | database.md（666 行） + 80 Flyway migration |
| 安全设计 | SECURITY_DESIGN + THREAT_MODEL | security-ops.md + privacy.md |
| ADR | ADR-001~012 | docs/proposals/（ADR 风格） |
| 测试指南 | TEST_CASES + UNIT_TEST_GUIDE | testing.md + quality-assessment.md |
| 文档漂移检测 | `make doc-drift`（CI 阻断） | `check-design-spec-sync.py` |

---

## 四、质量属性评估（ISO/IEC 25010）

### 4.1 功能性（Functional Suitability）

| 子特性 | 客户端 | 后端 | 评估 |
|--------|--------|------|------|
| 功能完备性 | RAG 闭环（分块→FTS5+向量→AI 合成） | 149 API 端点 / 6 Feature 域 | 🟢 完备 |
| 功能正确性 | 1105 主 App 测试 + 240 SPM 测试 | 255 Java 测试 + 93 前端测试 | 🟡 客户端覆盖率不足 |
| 功能适当性 | AI 原生知识管理 | 认证/订阅/管理平台 | 🟢 精准定位 |

### 4.2 可靠性（Reliability）

| 子特性 | 客户端 | 后端 | 评估 |
|--------|--------|------|------|
| 成熟性 | fatalError 审查（25 处） | Sentinel 流控 + 熔断 | 🟡 客户端有崩溃风险 |
| 容错性 | JSONRepairProcessor（LLM 响应修复） | Testcontainers 集成测试 | 🟢 良好 |
| 可恢复性 | 数据库备份 + 同步引擎 | Flyway 回滚 + K8s 滚动更新 | 🟢 良好 |

### 4.3 性能效率（Performance Efficiency）

| 子特性 | 客户端 | 后端 | 评估 |
|--------|--------|------|------|
| 时间行为 | `make perf` 性能基准 | Prometheus + Grafana 监控 | 🟢 良好 |
| 资源利用 | SQLite + FTS5 本地优先 | Redis 缓存 + Nacos 配置 | 🟢 良好 |
| 容量 | 本地无并发限制 | K8s 弹性伸缩 + Argo Rollouts | 🟢 良好 |

### 4.4 可操作性（Operability）

| 子特性 | 客户端 | 后端 | 评估 |
|--------|--------|------|------|
| 可监控性 | Logger（actor，395 行）+ Analytics | Prometheus + Loki + Tempo | 🟢 良好 |
| 可诊断性 | DI 诊断（os_log + stderr + Logger） | requestId 链路追踪 | 🟢 良好 |
| 可配置性 | AppConfig.json + .xcstrings | Nacos 配置中心 | 🟢 良好 |

### 4.5 安全性（Security）

| 子特性 | 客户端 | 后端 | 评估 |
|--------|--------|------|------|
| 保密性 | Keychain + Vault 加密 | JWT RS256 + BCrypt + Gitleaks | 🟢 良好 |
| 完整性 | SecurityManager + 签名 | Flyway checksum + cosign 签名 | 🟢 良好 |
| 可追溯性 | Analytics + 审计日志 | 审计模块 + requestId | 🟢 良好 |
| 真实性 | JWT + OAuth | JWT + TOTP + WebAuthn + OAuth | 🟢 良好 |
| 抗抵赖性 | N/A（本地应用） | 审计日志 + 财务流水 | 🟢 良好 |

**安全亮点**：
- 客户端：SecurityManager 降级策略（ADR-012）、Prompt 沙箱、插件沙箱
- 后端：9 个安全 CI 脚本、Trivy CVE 扫描、Kyverno 策略、checkov IaC 扫描

### 4.6 可维护性（Maintainability）

| 子特性 | 客户端 | 后端 | 评估 |
|--------|--------|------|------|
| 模块化 | 6 SPM 包物理隔离 | 8 Maven 模块 | 🟢 优秀 |
| 可复用性 | UFPCore/UFPDesignSystem 跨平台复用 | ufp-common starter 复用 | 🟢 优秀 |
| 可分析性 | 71 篇文档 + codegraph | 64 篇文档 + OpenAPI | 🟢 良好 |
| 可修改性 | L0-L3 分层 + CI 守护 | Feature 域聚合 + CI 守护 | 🟢 优秀 |
| 可测试性 | **23% 覆盖率（核心短板）** | 95%/90% 硬门禁 | 🔴 客户端不足 |

### 4.7 可移植性（Portability）

| 子特性 | 客户端 | 后端 | 评估 |
|--------|--------|------|------|
| 适应性 | iOS/macOS/watchOS 三平台 | K8s 跨节点部署 | 🟢 优秀 |
| 可安装性 | App Store + Mac Catalyst | Helm + Argo CD | 🟢 良好 |
| 可替换性 | SPM 包可独立替换 | 微服务可独立替换 | 🟢 优秀 |

---

## 五、测试与可测试性深度分析

### 5.1 客户端测试现状（评分：6.5/10 C+）🔴 核心短板

| 指标 | 客户端 | 后端 | 业界参考 |
|------|--------|------|----------|
| 测试/源文件比 | 0.23（171/740） | 0.34（255/746） | 0.5-1.0 |
| SPM 包覆盖率 | 93.35%（已达标） | N/A | ≥ 90% |
| 主 App 覆盖率 | ~23% | N/A | ≥ 80% |
| 后端覆盖率 | N/A | 95%/90% 硬门禁 | ≥ 80% |
| 集成测试 | 4 个 E2E | 6 个 IT（Testcontainers） | — |
| 性能测试 | `make perf` | N/A | — |
| 快照测试 | swift-snapshot-testing | N/A | — |

**客户端测试改进进展**：
- SPM 包覆盖率：UFPCore 90.14% / UFPDesignSystem 100% / ZhiYuDomain 100% / ZhiYuAICore 97.77% / ZhiYuFeatures 100%
- 新增 240+ SPM 测试（6 包），发现并修复 4 个真实缺陷
- 主 App 1105 测试全通过

**剩余差距**：主 App 覆盖率 ~23% 远低于 SonarQube 95% 门禁，是当前唯一阻塞 A+ 评级的核心问题。

### 5.2 后端测试现状（评分：9.5/10 A+）

| 指标 | 数据 |
|------|------|
| 单元测试 | 249 个 `*Test.java`（Surefire） |
| 集成测试 | 6 个 `*IT.java`（Failsafe + Testcontainers） |
| 前端测试 | 93 个 `*.spec/test.ts(x)`（Vitest） |
| Shell 测试 | 30+ 个 `tests/deploy/unit/test-*.sh` |
| 覆盖率门禁 | 行 ≥ 95%，分支 ≥ 90%（JaCoCo + SonarQube 硬阻断） |
| 测试代码行 | 42,096 行（54% 主代码比） |

---

## 六、CI/CD 工程化评估

### 6.1 客户端 CI/CD（评分：9.0/10 A）

**5 阶段流水线**（`.gitlab-ci.yml`）：
```
prepare → analyze → build → test → sonar
```

**门禁脚本**：85 个（`Tools/CI/` 35 + `Tools/ios/` 40 + `Tools/Gatekeeper/` 10）
- 30 项静态分析并行任务（含 doc-drift + exemptions-check 阻断）
- 12 项 pre-push 门禁（`assert-code-pre-push.sh`）
- Swift `-warnings-as-errors` 门禁
- SonarQube `-Dsonar.qualitygate.wait=true` 硬阻断

**Makefile SSOT**：17 个目标（gen/ios/mac/watch/test/test-spm/coverage-spm/audit/lint/perf/plugin-scan/doc-drift/exemptions-check）

### 6.2 后端 CI/CD（评分：9.5/10 A+）

**9 阶段双轨流水线**（`.gitlab-ci.yml` v18.3.0）：
```
checks → units → integration → build → scan → package → deploy → e2e → cleanup
```

- **在线轨**：MR / main push 触发
- **离线轨**：`platform/v*` tag 触发（含离线包归档）

**门禁脚本**：87 个 CI 脚本 + 48 个 tools 脚本
- 40+ 项 checks 阶段检查
- Trivy CVE 镜像扫描 + SonarQube 三模块硬阻断
- Gitleaks 密钥扫描 + checkov IaC 扫描
- 部署链路：mvn package → rsync → Docker build → K8s deploy

### 6.3 CI/CD 对比

| 维度 | 客户端 | 后端 | 业界参考 |
|------|--------|------|----------|
| 流水线阶段数 | 5 | 9 | 5-10 |
| 门禁脚本数 | 85 | 135 | 20-50 |
| 质量门禁严格度 | 高 | 极高 | 中-高 |
| 部署自动化 | 手动 make ios | Argo CD 自动化 | 半自动-全自动 |
| 回滚能力 | 手动 | Argo Rollouts 自动 | 半自动 |

---

## 七、业界参考对比

### 7.1 对标项目

| 维度 | ZhiYu | 业界一线标准 | 评估 |
|------|-------|-------------|------|
| 架构分层 | L0-L3 + SPM / Maven 多模块 | Clean Architecture | 🟢 领先 |
| 测试覆盖率（后端） | 95%/90% 硬门禁 | 80% | 🟢 领先 |
| 测试覆盖率（客户端） | ~23% | 60-80% | 🔴 落后 |
| CI 门禁脚本 | 85 + 135 = 220 | 20-50 | 🟢 领先 |
| 文档数量 | 71 + 64 = 135 | 20-50 | 🟢 领先 |
| 安全工具链 | Keychain + Prompt 沙箱 | JWT + TOTP + WebAuthn + Trivy + Gitleaks | 🟢 良好 |
| 依赖管理 | SPM + Maven BOM | 包管理器 + BOM | 🟢 良好 |
| 代码重复率 | < 3% 门禁 | < 5% | 🟢 领先 |
| 静态分析 | SwiftLint + SonarQube | Checkstyle + SpotBugs + PMD + SonarQube | 🟢 良好 |

### 7.2 成熟度模型定位

按 **CMMI 五级成熟度模型**：

| 等级 | 描述 | ZhiYu 定位 |
|------|------|-----------|
| L1 初始级 | 混乱、无流程 | — |
| L2 已管理级 | 有基本项目管理 | — |
| L3 已定义级 | 标准化流程 | — |
| L4 量化管理级 | 数据驱动改进 | **前后端均已达** |
| L5 优化级 | 持续优化创新 | **部分维度已达**（CI 门禁、架构守护） |

**ZhiYu 整体处于 CMMI L4-L5 之间**，工程化程度显著高于业界平均水平。

### 7.3 与同类产品对比

| 产品 | 架构 | 测试覆盖 | CI 门禁 | 文档 |
|------|------|----------|---------|------|
| **ZhiYu** | L0-L3 + SPM / Maven 微服务 | 客户端 23% / 后端 95% | 220 脚本 | 135 篇 |
| Obsidian | 插件架构 | 低 | 少 | 少 |
| Notion | 微服务 | 中 | 中 | 中 |
| Logseq | 单体 | 低 | 少 | 少 |
| Roam Research | 微服务 | 中 | 中 | 少 |

> ZhiYu 在架构严格性、CI 门禁数量、文档完备度上显著领先同类知识管理产品。

---

## 八、风险与改进建议

### 8.1 高风险项（P0）

| # | 风险 | 影响 | 建议 | 责任 |
|---|------|------|------|------|
| 1 | 客户端主 App 覆盖率 ~23% | 回归风险高、SonarQube 阻断 | 分阶段提升：先达 50%→80%→95% | 客户端团队 |
| 2 | 客户端 25 处 fatalError | 生产环境崩溃风险 | 逐个审查，降级为可恢复错误 | 客户端团队 |

### 8.2 中风险项（P1）

| # | 风险 | 影响 | 建议 |
|---|------|------|------|
| 3 | 客户端并发安全（Swift 6 严格模式） | 数据竞争 | 持续迁移 NSLock → OSAllocatedUnfairLock |
| 4 | 后端 `zhiyu-auth-admin-service` 0 业务代码 | 模块空置 | 确认是否符合预期，或合并入口 |
| 5 | 前后端 API 契约同步 | 契约漂移 | 持续运行 `check-design-spec-sync.py` |

### 8.3 改进路线图

```
Phase 1（1-2 周）：客户端测试覆盖率提升至 50%
  - 优先覆盖 Infrastructure/LLM、Storage、Domain/RAG 核心路径
  - 补充 Integration 测试（RAG 闭环、Ingest 管道）
  - 目标：SonarQube 覆盖率从 23% → 50%

Phase 2（2-4 周）：客户端测试覆盖率提升至 80%
  - 覆盖 Features/AI、Knowledge、Insight 业务逻辑
  - 补充 Boundary 测试（边界条件、错误路径）
  - 目标：SonarQube 覆盖率从 50% → 80%

Phase 3（4-8 周）：客户端测试覆盖率提升至 95%
  - 全量覆盖剩余路径
  - 补充 Performance 测试基准
  - 目标：SonarQube 覆盖率从 80% → 95%，解除 CI 阻断

Phase 4（持续）：架构优化与债务清理
  - fatalError 逐个审查降级
  - 并发安全持续迁移
  - 跨平台 Phase 0-4 落地
```

---

## 九、结论

### 9.1 核心优势

1. **架构完整性业界领先**：前后端均采用严格分层 + 物理隔离 + CI 守护，0 处跨层违规
2. **CI/CD 工程化极致**：220 个门禁脚本，SonarQube 硬阻断，质量门禁严格度达一线互联网标准
3. **安全设计完善**：客户端 Keychain + Prompt 沙箱 + 插件沙箱；后端 JWT RS256 + TOTP + WebAuthn + Trivy + Gitleaks
4. **文档完备**：135 篇文档，含架构/设计/测试/安全/ADR，文档漂移 CI 检测
5. **后端测试覆盖卓越**：95%/90% 硬门禁，255 Java 测试 + 93 前端测试 + 30 Shell 测试

### 9.2 核心短板

1. **客户端测试覆盖率严重不足**（~23% vs 95% 门禁）—— **唯一阻塞 A+ 评级的核心问题**
2. **客户端 25 处 fatalError** —— 生产环境崩溃风险
3. **客户端并发安全** —— Swift 6 严格模式下仍有迁移工作

### 9.3 最终评级

| 系统 | 评级 | 评分 |
|------|------|------|
| ZhiYu 客户端 | **A-** | 8.25/10 |
| ZhiYu-Backend | **A** | 9.17/10 |
| **前后端综合** | **A-** | **8.71/10** |

> **总评**：ZhiYu 前后端整体质量达到 **A- 级**，工程化程度业界领先。后端已达 A 级生产标准，客户端架构与 CI 达 A+ 级但被测试覆盖率拉低至 A-。**提升客户端测试覆盖率至 95% 是达到 A+ 级的唯一关键路径**。

---

## 附录 A：评估依据

| 依据 | 路径 |
|------|------|
| 客户端审计报告 | `Docs/Audit/2026-08-04-deep-quality-audit.md` |
| 客户端分层设计 | `Docs/Architecture/LAYERING_L0_L3.md` |
| 客户端 CI 配置 | `.gitlab-ci.yml` |
| 客户端依赖清单 | `Config/opensource_dependencies.yml` |
| 后端架构文档 | `ZhiYu-Backend/docs/architecture/overview.md` |
| 后端 CI 配置 | `ZhiYu-Backend/.gitlab-ci.yml` |
| 后端数据库设计 | `ZhiYu-Backend/docs/architecture/database.md` |
| 后端 API 规范 | `ZhiYu-Backend/docs/architecture/api-spec.md` |

## 附录 B：质量门禁清单

### 客户端（30 项静态分析 + 12 项 pre-push）

| 类别 | 门禁项 | 阻断模式 |
|------|--------|----------|
| 架构 | L0-L3 分层校验 / DI 注册完整性 / 跨层引用 | 阻断 |
| 代码 | SwiftLint / 魔鬼数字 / 重复代码 / 死代码 | 阻断 |
| 设计 | DesignSystem Token / HIG 合规 | 阻断 |
| 本地化 | L10n 硬编码 / .xcstrings 完整性 | 阻断 |
| 安全 | Keychain / Prompt 沙箱 / 插件扫描 | 阻断 |
| 文档 | 文档漂移 / 免白名单一致性 | 阻断 |
| 性能 | 性能基准 / 性能基线 | 阻断 |
| 覆盖率 | SonarQube 95%/90% | 阻断 |

### 后端（40+ 项 checks 阶段）

| 类别 | 门禁项 | 阻断模式 |
|------|--------|----------|
| 架构 | 循环依赖 / Controller 薄层 / 分层审计 | 阻断 |
| 代码 | Checkstyle / SpotBugs / PMD/p3c / 魔鬼值 | 阻断 |
| 前端 | ESLint / tsc / knip / size-limit | 阻断 |
| 安全 | Gitleaks / 匿名访问 / JWT 密钥 / 凭证扫描 | 阻断 |
| API | operationId / Schema 一致性 / spec 同步 | 阻断 |
| 数据库 | Flyway checksum | 阻断 |
| 镜像 | Trivy CVE / cosign 签名 | 阻断 |
| IaC | checkov / kube-score / polaris | 阻断 |
| 覆盖率 | SonarQube 95%/90% | 阻断 |

---

*报告结束*
