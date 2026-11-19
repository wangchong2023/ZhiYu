# Phase 0：IDL 契约层 + Skip POC 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 建立语言无关的 Protobuf IDL 契约层，将 Domain 层 Swift 协议对齐为 `*Contract`，并验证 Skip.tools 对现有 Swift 代码的转译可行性，为后续 Android/Windows/鸿蒙多平台提供契约基准。

**Architecture:** 以 Protobuf IDL 为单一事实源定义领域契约，经 swift-protobuf 生成 Swift 代码，对齐现有 `Sources/Domain/Protocols/`（33 个文件）为 `*Contract`；并行搭建 Skip POC 评估 Android 转译质量，用结果决策是否全面采用 Skip。

**Tech Stack:** Protobuf 3 / swift-protobuf（`protoc-gen-swift`）、Skip.tools（Android 转译 POC）、Swift 6、GRDB 不变。

## Global Constraints

- **分层红线**：Domain（L1.5）层协议不得依赖 UI 框架（UIKit/AppKit/SwiftUI）；IDL 契约层产物不得引入反向依赖。
- **开源选型优先**：Skip.tools 与 swift-protobuf 均为新增开源依赖，落地前须按 AGENTS.md 开源选型原则提交 USER 决策，禁止直接造轮子。
- **去魔鬼化**：禁止硬编码魔法数字/字符串；契约常量与错误码须强类型化。
- **测试质量红线**：语句覆盖率 ≥95%、分支覆盖率 ≥90%（SonarQube Quality Gate）。
- **L10n 强约束**：契约层不含用户可见文案；错误描述走 `AppError`，不走 L10n。
- **环境**：本机 `protoc 36.2` 可用；`protoc-gen-swift` 未装；Skip CLI 未装；Swift 6.4.2；平台版本 iOS/macOS/watchOS 27.0。
- **无占位符**：所有生成/对齐步骤必须产出实际可编译代码，不得留 TODO。

---

## 前置选型决策（Gate 0，须 USER 确认）

> 以下两项为开源选型，按 AGENTS.md 开源选型优先原则，任务 0 完成前须 USER 决策。

| 项 | 候选 | 说明 | 决策点 |
|----|------|------|--------|
| Protobuf Swift 生成 | swift-protobuf (`protoc-gen-swift`) | 官方 protobuf Swift 插件，brew 安装 `swift-protobuf` | 包体积、生成代码风格 |
| Android 转译 | Skip.tools (`brew tap skiptools/skip && brew install skip`) | 将 Swift 转译 Kotlin 的 POC 工具 | 转译覆盖率、许可、稳定性 |

---

## 任务清单

### 任务 0：开源选型与工具链就绪（Gate 0，0.5 天）

**Files:**
- Modify: `Config/opensource_dependencies.yml`（登记 swift-protobuf）
- Modify: `Config/project.yml.template`（可选：若 SwiftProtobuf 需编译期依赖）

**Interfaces:**
- Consumes: 无
- Produces: `protoc-gen-swift` 可用；Skip CLI 可用；opensource_dependencies.yml 登记 swift-protobuf

- [ ] **Step 1: 确认选型决策**

向 USER 汇报 Skip.tools 与 swift-protobuf 的选型对比（包体积/转译质量/许可/维护成本），获得确认后继续。记录到 ADR。

- [ ] **Step 2: 安装 protoc-gen-swift**

```bash
brew install swift-protobuf
protoc --version                # libprotoc 36.2
which protoc-gen-swift          # 应出现 /opt/homebrew/bin/protoc-gen-swift
```

预期：`protoc-gen-swift` 出现在 PATH。

- [ ] **Step 3: 安装 Skip.tools（仅 POC 需要）**

```bash
brew tap skiptools/skip && brew install skip
skip --version
```

预期：`skip` 命令可用。若 Skip 对 Android 转译在 POC 后判定不达标，本步产物可弃用，不影响 IDL 契约层主线。

- [ ] **Step 4: 登记 swift-protobuf 到 opensource_dependencies.yml**

在 `Config/opensource_dependencies.yml` 的 `dependencies:` 段追加：

```yaml
- name: swift-protobuf
  upstream: "https://github.com/apple/swift-protobuf.git"
  version: "1.28.0"
  integration: spm
  license: Apache-2.0
  purpose: "Protobuf 契约层的 Swift 代码生成插件"
```

- [ ] **Step 5: Commit**

```bash
git add Config/opensource_dependencies.yml Config/project.yml.template
git commit -m "feat: Phase0 工具链就绪（swift-protobuf + Skip）"
```

---

### 任务 1：建立 protobuf 契约目录骨架（1 天）

**Files:**
- Create: `Docs/Contracts/google/protobuf/timestamp.proto`（引用标准）
- Create: `Docs/Contracts/zhiyu/domain/auth.proto`
- Create: `Docs/Contracts/zhiyu/domain/knowledge.proto`
- Create: `Docs/Contracts/zhiyu/domain/common.proto`
- Create: `Docs/Contracts/README.md`
- Create: `Tools/contracts/gen.sh`

**Interfaces:**
- Consumes: 任务 0 的 `protoc-gen-swift`
- Produces: 首批 `.proto` 契约文件；`Tools/contracts/gen.sh` 生成脚本入口

- [ ] **Step 1: 创建 common.proto（基础枚举与通用消息）**

Create `Docs/Contracts/zhiyu/domain/common.proto`：

```proto
syntax = "proto3";
package zhiyu.domain;

option swift_prefix = "ZhiYu";

enum Platform {
  PLATFORM_UNSPECIFIED = 0;
  PLATFORM_IOS = 1;
  PLATFORM_MACOS = 2;
  PLATFORM_WATCHOS = 3;
  PLATFORM_ANDROID = 4;
}

message Result {
  bool success = 1;
  string message = 2;
}
```

- [ ] **Step 2: 创建 auth.proto（认证契约，对应 AuthStrategy/DTOs）**

Create `Docs/Contracts/zhiyu/domain/auth.proto`：

```proto
syntax = "proto3";
package zhiyu.domain;

import "zhiyu/domain/common.proto";

option swift_prefix = "ZhiYu";

message OAuthCredential {
  string identity_type = 1;
  string identifier = 2;
  string credential = 3;
  map<string, string> extra_info = 4;
}

message AuthResult {
  bool success = 1;
  string token = 2;
  string message = 3;
}
```

- [ ] **Step 3: 创建 knowledge.proto（知识契约，对应 KnowledgeRepository 等）**

Create `Docs/Contracts/zhiyu/domain/knowledge.proto`：

```proto
syntax = "proto3";
package zhiyu.domain;

import "zhiyu/domain/common.proto";

option swift_prefix = "ZhiYu";

message KnowledgePage {
  string id = 1;
  string title = 2;
  string content = 3;
  int64 created_at = 4;
  int64 updated_at = 5;
}
```

- [ ] **Step 4: 编写生成脚本 gen.sh**

Create `Tools/contracts/gen.sh`（可执行）：

```bash
#!/usr/bin/env bash
# 系统层级：[Tools] 契约生成网关
# 核心职责：从 Docs/Contracts 生成 Swift 契约代码到 Sources/Domain/Contracts
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTRACTS_DIR="$PROJECT_DIR/Docs/Contracts"
OUTPUT_DIR="$PROJECT_DIR/Sources/Domain/Contracts/Generated"
mkdir -p "$OUTPUT_DIR"

protoc \
  --swift_out="$OUTPUT_DIR" \
  -I "$CONTRACTS_DIR" \
  "$CONTRACTS_DIR"/zhiyu/domain/*.proto

echo "✅ Swift 契约已生成到 Sources/Domain/Contracts/Generated"
```

- [ ] **Step 5: 赋执行权限并测试生成**

```bash
chmod +x Tools/contracts/gen.sh
bash Tools/contracts/gen.sh
ls Sources/Domain/Contracts/Generated/
```

预期：生成 `common.pb.swift`、`auth.pb.swift`、`knowledge.pb.swift` 三个文件。

- [ ] **Step 6: Commit**

```bash
git add Docs/Contracts/ Tools/contracts/gen.sh Sources/Domain/Contracts/
git commit -m "feat: Phase0 protobuf 契约骨架与生成脚本"
```

---

### 任务 2：Domain 协议对齐为 `*Contract`（3-4 天）

**Files:**
- Modify: `Sources/Domain/Protocols/AuthStrategy.swift`（对齐 → `AuthStrategyContract`）
- Modify: `Sources/Domain/Protocols/FeatureProtocols.swift`
- Modify: `Sources/Domain/Protocols/DTOs.swift`
- Test: `Tests/Unit/Domain/ContractAlignmentTests.swift`（新建）

**Interfaces:**
- Consumes: 任务 1 生成的 `.pb.swift` 契约类型
- Produces: 首批 `*Contract` 协议；对齐后保持现有调用方兼容

- [ ] **Step 1: 提取 AuthStrategy 为契约协议**

在 `Sources/Domain/Protocols/AuthStrategy.swift` 中新增协议（保留原 `AuthStrategy` 作为别名以保证调用方零改动）：

```swift
/// 契约协议：与 Docs/Contracts/zhiyu/domain/auth.proto 对齐
public protocol AuthStrategyContract {
    var identityType: String { get }
    func acquireCredentials() async throws -> AuthCredential
}

/// 兼容别名：现有实现/调用方保持不变
public typealias AuthStrategy = AuthStrategyContract
```

- [ ] **Step 2: 为 DTOs 增加契约别名**

在 `Sources/Domain/Protocols/DTOs.swift` 中，将 `AuthCredential` 与 `ZhiYuAuthResult` 等映射到生成的契约消息（或提供转换方法），保证 proto 类型可被策略消费：

```swift
public extension AuthCredential {
    /// 转换为 IDL 契约消息（供跨平台透传）
    func toProto() -> ZhiYuOAuthCredential {
        var proto = ZhiYuOAuthCredential()
        proto.identityType = identityType
        proto.identifier = identifier
        proto.credential = credential
        proto.extraInfo = extraInfo ?? [:]
        return proto
    }
}
```

- [ ] **Step 3: 编写对齐回归测试**

Create `Tests/Unit/Domain/ContractAlignmentTests.swift`：

```swift
import XCTest
@testable import ZhiYu

final class ContractAlignmentTests: XCTestCase {
    func testAuthCredentialToProtoRoundTrip() {
        let credential = AuthCredential(
            identityType: "google", identifier: "uid",
            credential: "token", extraInfo: ["idToken": "abc"]
        )
        let proto = credential.toProto()
        XCTAssertEqual(proto.identityType, "google")
        XCTAssertEqual(proto.extraInfo["idToken"], "abc")
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

```bash
make test-spm PKG=ZhiYuDomain
```

预期：`ContractAlignmentTests` 通过，无编译错误。

- [ ] **Step 5: Commit**

```bash
git add Sources/Domain/Protocols/ Tests/Unit/Domain/ContractAlignmentTests.swift
git commit -m "refactor: Phase0 Auth/DTO 协议对齐为 *Contract"
```

---

### 任务 3：Skip POC 评估（2 天）

**Files:**
- Create: `Docs/Contracts/skip-poc-report.md`
- Modify: `Tools/contracts/gen.sh`（追加 skip 转译步骤）

**Interfaces:**
- Consumes: 任务 1 契约骨架
- Produces: Skip POC 报告（转译质量、覆盖率、问题清单）→ 决策 Phase 2 是否采用 Skip

- [ ] **Step 1: 初始化 Skip 项目**

```bash
cd ~/Documents/work/code/opensrc/skip-poc  # 若不存在先创建
skip init ZhiYuPoc
cd ZhiYuPoc
```

- [ ] **Step 2: 复制一个小契约文件做转译测试**

将 `Docs/Contracts/zhiyu/domain/common.proto` 的 Swift 生成物导入 POC，运行 Skip 转译：

```bash
skip build android
```

- [ ] **Step 3: 记录转译结果到报告**

Create `Docs/Contracts/skip-poc-report.md`，记录：转译成功率、覆盖率、编译错误清单、对 Android 的可行性结论。

- [ ] **Step 4: Commit**

```bash
git add Docs/Contracts/skip-poc-report.md Tools/contracts/gen.sh
git commit -m "docs: Phase0 Skip POC 评估报告"
```

---

### 任务 4：Gate 评审 + 交付物收尾（0.5 天）

**Files:**
- Modify: `Docs/Architecture/CROSS_PLATFORM_EXPANSION.md`（§6.2 标记完成）

**Interfaces:**
- Consumes: 任务 1-3 全部产物
- Produces: Phase 0 完成状态；决策记录（Skip 是否全面采用）

- [ ] **Step 1: 全量验证**

```bash
make gen && make ios && make test-spm-all
```

预期：三平台编译通过，SPM 单测全绿。

- [ ] **Step 2: 更新 CROSS_PLATFORM_EXPANSION.md §6.2 为完成状态**

将 §6.2 标题后加 `（✅ 已完成 YYYY-MM-DD）`，更新交付物勾选与决策门结论（记录 Skip 是否采用）。

- [ ] **Step 3: 记录 ADR**

在 `Docs/Architecture/ADR.md` 追加 ADR-015，记录：IDL 契约层落地、Skip POC 结论、契约协议命名规范。

- [ ] **Step 4: Commit**

```bash
git add Docs/Architecture/CROSS_PLATFORM_EXPANSION.md Docs/Architecture/ADR.md
git commit -m "docs: Phase0 IDL 契约层完成 + ADR-015"
```

---

## 验收标准（AC）

1. `Docs/Contracts/*.proto` 存在（common/auth/knowledge），`Tools/contracts/gen.sh` 可一键生成 Swift 契约。
2. `Sources/Domain/Contracts/Generated/` 有可编译的 `.pb.swift`；首批协议对齐为 `*Contract` 且现有调用方零破坏。
3. `protoc-gen-swift` 与 Skip CLI 就绪（或 Skip 判定不采用并记录原因）。
4. Skip POC 报告产出，明确 Android 转译可行性结论。
5. `make gen && make ios && make test-spm-all` 全过。
6. 覆盖率红线（语句 ≥95%、分支 ≥90%）满足。

## 风险与缓解

| 风险 | 缓解 |
|------|------|
| Skip 转译质量不达标 | POC 先行验证，不达标则 Phase 2 改用 KMP/手写，不影响 IDL 契约层 |
| swift-protobuf 生成代码风格与现有不符 | 任务 2 以兼容别名 `typealias` 保底，逐步替换 |
| 协议对齐破坏调用方 | 用 `typealias` 兼容，契约协议增量引入，按模块灰度 |
| protoc-gen-swift 版本与 protoc 36 不兼容 | 锁定 swift-protobuf 版本，验证生成产物 |