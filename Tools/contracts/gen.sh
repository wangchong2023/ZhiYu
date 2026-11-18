#!/usr/bin/env bash
# 系统层级：[Tools] 契约生成网关
# 核心职责：从 Docs/Contracts 生成 Swift 契约代码到 Sources/Domain/Contracts
#
# 说明：
#   遍历 Docs/Contracts/zhiyu/domain/*.proto，经 protoc + protoc-gen-swift 生成
#   .pb.swift 到 Sources/Domain/Contracts/Generated（该目录已被 .gitignore 忽略，
#   生成产物不入库）。供 IDL 契约层按需再生，依赖 brew 安装的 swift-protobuf。
#
# 用法:
#   bash Tools/contracts/gen.sh    # 幂等再生全部 Swift 契约
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