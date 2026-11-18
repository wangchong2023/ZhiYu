# 契约层（Contract Layer）

> 系统层级：[Docs] 语言无关 IDL 契约
> 核心职责：以 Protobuf 定义跨平台统一契约，经 swift-protobuf 生成 Swift 代码，对齐领域层 `*Contract` 协议

## 作用

智宇面向 iOS / macOS / watchOS 等多平台扩展。为避免各端各自维护一套接口定义导致语义漂移，这里以 **Protobuf（proto3）** 作为语言无关的 IDL（Interface Description Language），统一描述领域层消息结构（如 `KnowledgePage`、`OAuthCredential`）。

- **单一来源**：`.proto` 文件是契约的权威定义，跨平台（iOS/macOS/watchOS/Android 等）共用一份。
- **生成 Swift 代码**：通过 `swift-protobuf` 插件（`protoc-gen-swift`）把 `.proto` 编译为 Swift `struct`，与领域层 `*Contract` 协议对齐。
- **对齐协议**：生成的 Swift 类型作为 DTO/传输对象，供 `Domain/Protocols` 中的契约协议使用，保证业务协议与 IDL 一致。

## 目录结构

```
Docs/Contracts/
├── README.md
└── zhiyu/
    └── domain/               # 领域契约（package: zhiyu.domain，swift_prefix: ZhiYu）
        ├── common.proto      # 通用枚举/消息（Platform、Result）
        ├── auth.proto        # 认证契约（OAuthCredential、AuthResult）
        └── knowledge.proto   # 知识契约（KnowledgePage）
```

生成的 Swift 代码输出到：

```
Sources/Domain/Contracts/Generated/zhiyu/domain/
├── common.pb.swift
├── auth.pb.swift
└── knowledge.pb.swift
```

> 注：`google/protobuf/timestamp.proto` 未被任何契约引用，按 YAGNI 原则不引入标准库副本。

## 生成脚本用法

`Tools/contracts/gen.sh` 是契约生成网关，从 `Docs/Contracts` 编译所有 `.proto` 到 `Sources/Domain/Contracts/Generated`。

```bash
# 前置：已安装 protoc 与 protoc-gen-swift（如 Homebrew: brew install protobuf protoc-gen-swift）
bash Tools/contracts/gen.sh
```

执行后重新生成 3 个 `.pb.swift` 文件。修改任一 `.proto` 后需重新运行本脚本，并将生成产物一并提交。

## 新增契约步骤

1. 在 `Docs/Contracts/zhiyu/domain/` 下新增或编辑 `.proto`（包名 `zhiyu.domain`，加 `option swift_prefix = "ZhiYu";`）。
2. 运行 `bash Tools/contracts/gen.sh` 重新生成 Swift 代码。
3. 在 `Sources/Domain/Protocols/` 中让对应 `*Contract` 协议引用生成的类型。