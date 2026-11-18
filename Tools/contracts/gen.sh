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