# CI 纵深加固实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按四阶段补齐 ZhiYu CI 质量门禁、供应链安全、性能防护、运维韧性四个维度的缺口。

**Architecture:** 新建 12 个工具脚本/配置文件，修改 5 个现有 CI 配置。每个阶段独立可交付——Phase 1 完成后即可获得分支保护 + 不稳定测试自动管理；Phase 2 补齐 SBOM + Dependabot；Phase 3 增加性能回归检测；Phase 4 实现确定性构建 + 飞书告警。

**Tech Stack:** Python 3 (脚本), Bash (CI 脚本), YAML (配置), Swift (@flaky 标记), Ruby (fastlane)

---

## 文件结构

```
新建:
  .github/CODEOWNERS                              # 代码所有权分配
  .github/pull_request_template.md                # PR 提交流程标准化
  .github/dependabot.yml                          # 自动依赖更新
  Tools/ci/run-test-flaky-report.sh                 # @flaky → 跳过列表
  Tools/ci/generate-arch-sbom-single.py                       # Package.resolved → SPDX
  Tools/ci/generate-arch-sbom-merged.py                          # 自解析 + Syft 合并
  Tools/ci/check-arch-spm-integrity.sh                # SPM 哈希校验
  Tools/ci/check-pipeline-perf-regression.py               # 性能基线比对
  Tools/ci/generate-pipeline-perf-baseline.sh                # 手动更新基线
  Tools/ci/run-pipeline-feishu.sh                       # 飞书 CI 告警
  Tools/ci/check-pipeline-reproducible.sh           # 确定性构建验证
  fastlane/Fastfile                               # Canary 部署管道

修改:
  .woodpecker.yml                                 # +静态分析步骤 +确定性验证
  .github/workflows/ci.yml                        # +完整性/SBOM/性能/确定性
  project.yml                                     # +SWIFT_COMPILATION_MODE
  Tools/ci/run-test-unit.sh                      # +不稳定测试自动收集
  Tools/ci/run-test-ui.sh                        # +不稳定测试自动收集
```

---

## Phase 1: 护栏与可观测性

### Task 1: 创建 CODEOWNERS 文件

**Files:**
- Create: `.github/CODEOWNERS`

- [ ] **Step 1: 创建 CODEOWNERS**

```bash
cat > .github/CODEOWNERS << 'EOF'
# ZhiYu 代码所有权分配
# 最后更新: 2026-06-14
# 规则: 最后匹配优先; * 为默认兜底

# CI / 基础设施
.github/workflows/                      @wangchong2023
.woodpecker.yml                         @wangchong2023
project.yml                             @wangchong2023
Tools/                                  @wangchong2023

# 核心 DI 容器 — 任何变更需额外审查
Sources/Core/Base/ServiceContainer.swift @wangchong2023

# 存储层
Sources/Infrastructure/Storage/         @wangchong2023

# 安全相关
Sources/Infrastructure/Storage/Persistence/DatabaseManager.swift @wangchong2023
Sources/Core/System/Security/           @wangchong2023

# 功能域
Sources/Features/Knowledge/             @wangchong2023
Sources/Features/AI/                    @wangchong2023
Sources/Features/System/                @wangchong2023

# 测试
Tests/                                  @wangchong2023

# 默认兜底
*                                       @wangchong2023
EOF
```

- [ ] **Step 2: 验证**

```bash
cat .github/CODEOWNERS && echo "✅ CODEOWNERS created"
```

- [ ] **Step 3: 提交**

```bash
git add .github/CODEOWNERS
git commit -m "ci: 添加 CODEOWNERS 文件 — 按领域分配代码所有权"
```

---

### Task 2: 创建 PR 模板

**Files:**
- Create: `.github/pull_request_template.md`

- [ ] **Step 1: 创建 PR 模板**

```bash
cat > .github/pull_request_template.md << 'EOF'
## 类型
- [ ] feat  - [ ] fix  - [ ] refactor  - [ ] test  - [ ] ci  - [ ] docs

## 变更说明
<!-- 描述此 PR 做了什么以及为什么 -->

## 测试计划
- [ ] 单元测试通过（本地运行 `Tools/ci/run-test-unit.sh`）
- [ ] UI 测试通过（本地运行 `Tools/ci/run-test-ui.sh`）
- [ ] Monkey 测试通过（仅本地，CI 跳过）
- [ ] 新增测试覆盖（如有）

## CI Gatekeeper Checklist
<!-- CI 将自动检查以下项目，PR 提交前请自行确认 -->
- [ ] SwiftLint 无新增违规
- [ ] 硬编码密钥扫描通过
- [ ] L10n 本地化合规
- [ ] 架构分层依赖合规 (L0→L3)
- [ ] 魔鬼数字/字符串审计通过
- [ ] 根目录卫生检查通过

## 截图 / 录屏（如有 UI 变更）
<!-- 拖入图片或粘贴链接 -->
EOF
```

- [ ] **Step 2: 验证**

```bash
wc -l .github/pull_request_template.md && echo "✅ PR template created"
```

- [ ] **Step 3: 提交**

```bash
git add .github/pull_request_template.md
git commit -m "ci: 添加 PR 模板 — 标准化提交前检查清单"
```

---

### Task 3: 配置 GitHub 分支保护

- [ ] **Step 1: 通过 GitHub Web UI 配置分支保护**

打开 `https://github.com/wangchong2023/ZhiYu/settings/branches`，添加 `main` 分支规则：

```
Branch name pattern: main

✅ Require a pull request before merging
    ✅ Require approvals: 1
    ✅ Dismiss stale pull request approvals when new commits are pushed
✅ Require status checks to pass before merging
    ✅ Require branches to be up to date before merging
    Status checks:
    - "ci / lint-and-audit"
    - "ci / test"
    - "ci / multi-platform (iOS)"
✅ Require conversation resolution before merging
✅ Do not allow bypassing the above settings
    ✅ Include administrators
```

- [ ] **Step 2: 截图留存配置**

```bash
mkdir -p Docs/CI
echo "分支保护规则截图保存至: Docs/CI/branch-protection.png (手动截图)"
```

- [ ] **Step 3: 提交**

```bash
git add Docs/CI/
git commit -m "docs: 记录 GitHub 分支保护规则配置"
```

---

### Task 4: 创建不稳定测试自动收集脚本

**Files:**
- Create: `Tools/ci/run-test-flaky-report.sh`
- Modify: `Tools/ci/run-test-unit.sh:20-30`
- Modify: `Tools/ci/run-test-ui.sh:13-17`

- [ ] **Step 1: 创建收集脚本**

```bash
cat > Tools/ci/run-test-flaky-report.sh << 'EOF'
#!/bin/bash
# ==============================================================================
# run-test-flaky-report.sh
# 扫描 Tests/ 中 @flaky: 标记的测试，生成 CI 跳过列表
# 用法: Tools/ci/run-test-flaky-report.sh [--ci]
# 输出: 打印 -skip-testing:Target/TestClass/testName 参数列表 (stdout)
# ==============================================================================
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "$0")/../../Tests" && pwd)"
OUTPUT_FILE="${1:-build/.flaky_tests}"

echo "🔍 扫描 @flaky 标记的测试..." >&2

# 收集所有被 @flaky 标记的测试方法
# 格式: // @flaky: 原因说明
#        func testMethodName() {
FLAKY_TESTS=()
while IFS= read -r line; do
    # line 格式: 文件路径:行号:  func testMethodName()
    file_path=$(echo "$line" | cut -d: -f1)
    func_name=$(echo "$line" | sed 's/.*func \(test[A-Za-z0-9_]*\).*/\1/')

    # 从文件路径推断 test target 和 class
    if echo "$file_path" | grep -q "Tests/UI/"; then
        target="ZhiYuUITests"
    elif echo "$file_path" | grep -q "Tests/SnapshotTests/"; then
        target="ZhiYuTests"
    else
        target="ZhiYuTests"
    fi

    # 从文件名推断类名（去掉 Tests 前缀后的文件名不含扩展名）
    class_name=$(basename "$file_path" .swift)
    FLAKY_TESTS+=("${target}/${class_name}/${func_name}")
done < <(grep -rn '@flaky:' "$TESTS_DIR" --include="*.swift" -A1 | grep 'func test')

# 输出
if [ ${#FLAKY_TESTS[@]} -eq 0 ]; then
    echo "" > "$OUTPUT_FILE"
    echo "✅ 未发现 @flaky 标记的测试" >&2
else
    printf '%s\n' "${FLAKY_TESTS[@]}" > "$OUTPUT_FILE"
    echo "📋 发现 ${#FLAKY_TESTS[@]} 个不稳定测试:" >&2
    for t in "${FLAKY_TESTS[@]}"; do
        echo "   - $t" >&2
    done
fi

# 输出 -skip-testing 参数
while IFS= read -r test_id; do
    [ -n "$test_id" ] && echo "-skip-testing:${test_id}"
done < "$OUTPUT_FILE"
EOF
chmod +x Tools/ci/run-test-flaky-report.sh
```

- [ ] **Step 2: 验证脚本**

```bash
Tools/ci/run-test-flaky-report.sh && echo "✅ run-test-flaky-report.sh 工作正常"
```

- [ ] **Step 3: 更新 run-test-unit.sh — 替换硬编码 SKIP_TESTS**

修改 `Tools/ci/run-test-unit.sh`，将硬编码 `SKIP_TESTS` 数组替换为脚本调用：

```bash
# 旧代码（删除）:
# SKIP_TESTS=(
#     "ZhiYuUITests/ZhiYuUITests/testChatAISkeletonLoadingState"
#     ...
# )

# 新代码（替换为）:
# 从 @flaky 注释自动收集不稳定测试
FLAKY_ARGS=()
while IFS= read -r skip_arg; do
    [ -n "$skip_arg" ] && FLAKY_ARGS+=("$skip_arg")
done < <(bash Tools/ci/run-test-flaky-report.sh)

# 在 XCODEBUILD_ARGS 中追加
for skip_arg in "${FLAKY_ARGS[@]}"; do
    XCODEBUILD_ARGS+=("$skip_arg")
done
```

- [ ] **Step 4: 同样更新 ci-run-test-ui.sh**

修改 `Tools/ci/run-test-ui.sh` 的 SKIP_TESTS 部分：

```bash
# 旧代码（删除）:
# SKIP_TESTS=(
#     "ZhiYuUITests/ZhiYuMonkeyTests/testWildMonkeyClickTraversal"
# )

# 新代码（替换为）:
# 从 @flaky 注释自动收集不稳定测试
FLAKY_ARGS=()
while IFS= read -r skip_arg; do
    [ -n "$skip_arg" ] && FLAKY_ARGS+=("$skip_arg")
done < <(bash Tools/ci/run-test-flaky-report.sh)
```

- [ ] **Step 5: 给现有 Monkey 测试添加 @flaky 标记**

在 `Tests/UI/ZhiYuMonkeyTests.swift` 的 `testWildMonkeyClickTraversal` 方法前添加：

```swift
// @flaky: Monkey 随机遍历测试，依赖 UI 帧状态，CI 中显式跳过
func testWildMonkeyClickTraversal() throws {
```

- [ ] **Step 6: 提交**

```bash
git add Tools/ci/run-test-flaky-report.sh Tools/ci/run-test-unit.sh Tools/ci/run-test-ui.sh Tests/UI/ZhiYuMonkeyTests.swift
git commit -m "ci: @flaky 自动标记系统 — 替换硬编码 SKIP_TESTS 为注释驱动收集"
```

---

## Phase 2: 供应链加固

### Task 5: 创建 Dependabot 配置

**Files:**
- Create: `.github/dependabot.yml`

- [ ] **Step 1: 创建 Dependabot 配置**

```bash
cat > .github/dependabot.yml << 'EOF'
version: 2
updates:
  # Swift Package Manager
  - package-ecosystem: "swift"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
      timezone: "Asia/Shanghai"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
      - "swiftpm"
    reviewers:
      - "wangchong2023"
    commit-message:
      prefix: "deps"
      include: "scope"

  # GitHub Actions
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "09:00"
      timezone: "Asia/Shanghai"
    labels:
      - "dependencies"
      - "ci"
    reviewers:
      - "wangchong2023"
    commit-message:
      prefix: "ci"
      include: "scope"
EOF
```

- [ ] **Step 2: 验证**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/dependabot.yml'))" && echo "✅ YAML 有效" || echo "⚠️  需要 pip3 install pyyaml 验证"
```

- [ ] **Step 3: 提交**

```bash
git add .github/dependabot.yml
git commit -m "ci: 添加 Dependabot 配置 — SPM + GitHub Actions 每周自动更新"
```

---

### Task 6: 创建 SBOM 生成工具链

**Files:**
- Create: `Tools/ci/generate-arch-sbom-single.py`
- Create: `Tools/ci/generate-arch-sbom-merged.py`
- Create: `Tools/ci/check-arch-spm-integrity.sh`

- [ ] **Step 1: 创建 generate-arch-sbom-single.py — Package.resolved 解析器**

```bash
cat > Tools/ci/generate-arch-sbom-single.py << 'PYEOF'
#!/usr/bin/env python3
"""从 Package.resolved 生成 SPDX 2.3 JSON SBOM."""
import json, os, sys, hashlib
from datetime import datetime, timezone

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
RESOLVED_PATHS = [
    os.path.join(PROJECT_DIR, "ZhiYu.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"),
]

def find_resolved():
    for p in RESOLVED_PATHS:
        if os.path.exists(p):
            return p
    # fallback: search
    for root, dirs, files in os.walk(PROJECT_DIR):
        if "Package.resolved" in files and ".build" not in root:
            return os.path.join(root, "Package.resolved")
    print("❌ Package.resolved not found", file=sys.stderr)
    sys.exit(1)

def make_spdx(packages: list[dict]) -> dict:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    pkg_id = "SPDXRef-ZhiYu"
    return {
        "SPDXID": "SPDXRef-DOCUMENT",
        "spdxVersion": "SPDX-2.3",
        "creationInfo": {
            "created": now,
            "creators": ["Tool: ZhiYu-generate-sbom"],
            "licenseListVersion": "3.21"
        },
        "name": "ZhiYu-iOS",
        "dataLicense": "CC0-1.0",
        "documentNamespace": f"https://zhiyu.app/sbom/{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}",
        "packages": [
            {
                "SPDXID": pkg_id,
                "name": "ZhiYu",
                "versionInfo": "1.0",
                "supplier": "Organization: wangchong2023",
                "downloadLocation": "NOASSERTION",
                "filesAnalyzed": False,
                "licenseConcluded": "NOASSERTION",
                "licenseDeclared": "NOASSERTION",
                "copyrightText": "NOASSERTION"
            }
        ] + [{
            "SPDXID": f"SPDXRef-{p['name'].replace('.','-').replace('_','-')}",
            "name": p["name"],
            "versionInfo": p["version"],
            "supplier": f"Organization: {p.get('repository_url', 'NOASSERTION')}",
            "downloadLocation": p.get("repository_url", "NOASSERTION"),
            "externalRefs": [{
                "referenceCategory": "PACKAGE-MANAGER",
                "referenceType": "purl",
                "referenceLocator": f"pkg:swift/{p['name']}@{p['version']}"
            }],
            "filesAnalyzed": False,
            "licenseConcluded": p.get("license", "NOASSERTION"),
            "licenseDeclared": p.get("license", "NOASSERTION"),
            "copyrightText": "NOASSERTION"
        } for p in packages],
        "relationships": [
            {"spdxElementId": pkg_id, "relationshipType": "CONTAINS",
             "relatedSpdxElement": f"SPDXRef-{p['name'].replace('.','-').replace('_','-')}"}
            for p in packages
        ]
    }

def main():
    resolved_path = find_resolved()
    print(f"📦 解析 Package.resolved: {resolved_path}", file=sys.stderr)

    with open(resolved_path) as f:
        data = json.load(f)

    packages = []
    for pin in data.get("pins", []):
        pkg = {
            "name": pin.get("identity", "unknown"),
            "version": pin.get("state", {}).get("version", "unknown"),
            "revision": pin.get("state", {}).get("revision", "")[:12],
            "repository_url": pin.get("location", ""),
            "license": "NOASSERTION"  # 待 generate-arch-sbom-merged.py 补充
        }
        packages.append(pkg)

    spdx = make_spdx(packages)
    output_path = os.path.join(PROJECT_DIR, "build", "sbom.spdx.json")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(spdx, f, indent=2)

    print(f"✅ SBOM (SPDX 2.3) 写入: {output_path}", file=sys.stderr)
    print(f"   包含 {len(packages)} 个依赖", file=sys.stderr)
    print(output_path)  # stdout 供 CI 脚本使用

if __name__ == "__main__":
    main()
PYEOF
chmod +x Tools/ci/generate-arch-sbom-single.py
```

- [ ] **Step 2: 测试 generate-arch-sbom-single.py**

```bash
python3 Tools/ci/generate-arch-sbom-single.py
# 预期: 输出 build/sbom.spdx.json 路径
python3 -c "import json; d=json.load(open('build/sbom.spdx.json')); assert d['spdxVersion']=='SPDX-2.3'; print('✅ SPDX 格式有效')"
```

- [ ] **Step 3: 创建 generate-arch-sbom-merged.py — 合并 Syft License 信息**

```bash
cat > Tools/ci/generate-arch-sbom-merged.py << 'PYEOF'
#!/usr/bin/env python3
"""合并 generate-arch-sbom-single.py 输出与 Syft 扫描结果，补齐 License 信息."""
import json, os, sys

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

def find_license_in_syft(syft_path: str, package_name: str) -> str:
    """从 Syft CycloneDX 输出中查找包的 license."""
    if not os.path.exists(syft_path):
        return "NOASSERTION"
    with open(syft_path) as f:
        syft = json.load(f)
    for comp in syft.get("components", []):
        if comp.get("name", "").lower() == package_name.lower():
            licenses = comp.get("licenses", [])
            if licenses:
                return licenses[0].get("license", {}).get("id", "NOASSERTION")
    return "NOASSERTION"

def main():
    spdx_path = os.path.join(PROJECT_DIR, "build", "sbom.spdx.json")
    syft_path = os.path.join(PROJECT_DIR, "build", "syft.cdx.json")

    if not os.path.exists(spdx_path):
        print("❌ sbom.spdx.json 不存在，请先运行 generate-arch-sbom-single.py", file=sys.stderr)
        sys.exit(1)

    with open(spdx_path) as f:
        spdx = json.load(f)

    enriched = 0
    for pkg in spdx.get("packages", []):
        name = pkg.get("name", "")
        if pkg.get("licenseConcluded") == "NOASSERTION":
            lic = find_license_in_syft(syft_path, name)
            if lic != "NOASSERTION":
                pkg["licenseConcluded"] = lic
                pkg["licenseDeclared"] = lic
                enriched += 1

    with open(spdx_path, "w") as f:
        json.dump(spdx, f, indent=2)

    print(f"✅ SBOM 已丰富: {enriched} 个包的 License 从 Syft 补充", file=sys.stderr)
    print(spdx_path)

if __name__ == "__main__":
    main()
PYEOF
chmod +x Tools/ci/generate-arch-sbom-merged.py
```

- [ ] **Step 4: 创建 SPM 完整性校验脚本**

```bash
cat > Tools/ci/check-arch-spm-integrity.sh << 'EOF'
#!/bin/bash
# ==============================================================================
# check-arch-spm-integrity.sh
# 校验 Package.resolved 中记录的 revision 与检出 commit 一致
# 用法: Tools/ci/check-arch-spm-integrity.sh
# ==============================================================================
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/../.." && pwd)"
RESOLVED="$PROJECT_DIR/ZhiYu.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
CHECKOUTS="$PROJECT_DIR/build/DerivedData-ios/SourcePackages/checkouts"

echo "🔐 校验 SPM 依赖完整性..."
FAILED=0

# 解析 Package.resolved 中的 identity → revision 映射
while IFS= read -r line; do
    identity=$(echo "$line" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('identity',''))")
    revision=$(echo "$line" | python3 -c "import sys,json; d=json.loads(sys.stdin.read()); print(d.get('state',{}).get('revision',''))")

    [ -z "$identity" ] && continue
    [ -z "$revision" ] && continue

    # 查找检出的目录（SPM 使用小写 + 连字符）
    checkout_dir=$(find "$CHECKOUTS" -maxdepth 1 -type d -iname "$identity" 2>/dev/null | head -1)

    if [ -z "$checkout_dir" ]; then
        echo "   ⚠️  $identity: checkout 目录不存在，跳过"
        continue
    fi

    actual_rev=$(git -C "$checkout_dir" rev-parse HEAD 2>/dev/null || echo "N/A")
    if [ "${actual_rev:0:12}" != "${revision:0:12}" ]; then
        echo "   ❌ $identity: hash 不匹配"
        echo "      expected: ${revision:0:12}"
        echo "      actual:   ${actual_rev:0:12}"
        FAILED=$((FAILED + 1))
    else
        echo "   ✅ $identity: ${revision:0:12}"
    fi
done < <(python3 -c "
import json
with open('$RESOLVED') as f:
    data = json.load(f)
for pin in data.get('pins', []):
    print(json.dumps({'identity': pin['identity'], 'state': pin['state']}))
")

if [ $FAILED -gt 0 ]; then
    echo "❌ $FAILED 个依赖完整性校验失败"
    exit 1
else
    echo "✅ 所有 SPM 依赖完整性校验通过"
fi
EOF
chmod +x Tools/ci/check-arch-spm-integrity.sh
```

- [ ] **Step 5: 在 CI 中加入 SBOM + 完整性检查**

在 `.woodpecker.yml` 的 `static-analysis` 步骤末尾添加：
```yaml
      - echo "--- SPM 完整性校验 ---"
      - bash Tools/ci/check-arch-spm-integrity.sh
      - echo "--- SBOM 生成 ---"
      - python3 Tools/ci/generate-arch-sbom-single.py
      - brew install syft 2>/dev/null || true
      - syft . -o cyclonedx-json=build/syft.cdx.json 2>/dev/null || echo "Syft 不可用，跳过 license 检测"
      - python3 Tools/ci/generate-arch-sbom-merged.py
```

在 `.github/workflows/ci.yml` 的 `lint-and-audit` job 末尾添加：
```yaml
      - name: Verify SPM Integrity
        run: bash Tools/ci/check-arch-spm-integrity.sh

      - name: Generate SBOM
        run: |
          python3 Tools/ci/generate-arch-sbom-single.py
          brew install syft 2>/dev/null || true
          syft . -o cyclonedx-json=build/syft.cdx.json 2>/dev/null || echo "Syft unavailable"
          python3 Tools/ci/generate-arch-sbom-merged.py

      - name: Upload SBOM Artifact
        uses: actions/upload-artifact@v4
        with:
          name: sbom
          path: build/sbom.spdx.json
          retention-days: 90
```

- [ ] **Step 6: 提交**

```bash
git add Tools/ci/generate-arch-sbom-single.py Tools/ci/generate-arch-sbom-merged.py Tools/ci/check-arch-spm-integrity.sh .woodpecker.yml .github/workflows/ci.yml
git commit -m "ci: SBOM(A+C混合) + SPM完整性校验 — Package.resolved解析 + Syft License补齐"
```

---

### Task 7: 签名提交 CI 验证

- [ ] **Step 1: 在 CI lint-and-audit 中添加签名检查（非阻断）**

在 `ci.yml` 和 `.woodpecker.yml` 的 lint 步骤中添加：

```yaml
      - name: Verify Commit Signature
        run: |
          if git log --show-signature -1 | grep -q "Good signature"; then
            echo "✅ Commit signed"
          else
            echo "⚠️  Commit NOT signed — 请配置 GPG 签名: git config commit.gpgsign true"
          fi
        continue-on-error: true
```

- [ ] **Step 2: 提交**

```bash
git add .github/workflows/ci.yml .woodpecker.yml
git commit -m "ci: 添加提交签名验证 — warning 级别，非阻断"
```

---

## Phase 3: 性能防护

### Task 8: 创建性能回归检测工具

**Files:**
- Create: `Tools/ci/check-pipeline-perf-regression.py`
- Create: `Tools/ci/generate-pipeline-perf-baseline.sh`
- Create: `build/.perf_baselines/.gitkeep`

- [ ] **Step 1: 创建基线更新脚本**

```bash
cat > Tools/ci/generate-pipeline-perf-baseline.sh << 'EOF'
#!/bin/bash
# ==============================================================================
# generate-pipeline-perf-baseline.sh
# 从最新 CI 运行中提取性能数据并更新基线
# 用法: Tools/ci/generate-pipeline-perf-baseline.sh [xcresult_path]
# ==============================================================================
set -euo pipefail

BASELINE_DIR="$(cd "$(dirname "$0")/../../build/.perf_baselines" && pwd)"
mkdir -p "$BASELINE_DIR"

XCRESULT="${1:-$(find build/DerivedData-ios/Logs/Test -name '*.xcresult' -type d 2>/dev/null | head -1)}"

if [ -z "$XCRESULT" ]; then
    echo "❌ 未找到 .xcresult 文件"
    exit 1
fi

echo "📊 提取性能数据: $XCRESULT"
# 使用 xcresulttool 提取测试性能指标
xcrun xcresulttool get --path "$XCRESULT" --format json 2>/dev/null \
    | python3 -c "
import json, sys
data = json.load(sys.stdin)
# 遍历测试结果提取 duration
def extract_tests(node, path=''):
    results = {}
    if node.get('type',{}).get('_name') == 'ActionTestSummary':
        name = node.get('name',{}).get('_value','')
        duration = node.get('duration',{}).get('_value',0)
        if name and duration:
            results[name] = float(duration)
    for child in node.get('subtests',{}).get('_values',[]):
        results.update(extract_tests(child, path))
    return results

tests = extract_tests(data)
for name, dur in tests.items():
    print(f'{name}\t{dur}')
" > /tmp/perf_data.tsv

# 更新基线
while IFS=$'\t' read -r name duration; do
    baseline_file="$BASELINE_DIR/${name}.json"
    cat > "$baseline_file" << JSONEOF
{
  "test_name": "$name",
  "baseline_ms": $duration,
  "tolerance_pct": 10,
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
JSONEOF
    echo "   ✅ $name: ${duration}ms"
done < /tmp/perf_data.tsv

echo "✅ 基线已更新至 $BASELINE_DIR"
EOF
chmod +x Tools/ci/generate-pipeline-perf-baseline.sh
```

- [ ] **Step 2: 创建回归检测脚本**

```bash
cat > Tools/ci/check-pipeline-perf-regression.py << 'PYEOF'
#!/usr/bin/env python3
"""性能回归检测 — 比对当前测试耗时与基线，超过 10% 阈值则阻断."""
import json, os, sys, subprocess

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BASELINE_DIR = os.path.join(PROJECT_DIR, "build", ".perf_baselines")
TOLERANCE_PCT = 10
WARNING_PCT = 5

def find_xcresult():
    logs_dir = os.path.join(PROJECT_DIR, "build", "DerivedData-ios", "Logs", "Test")
    for root, dirs, files in os.walk(logs_dir):
        for d in dirs:
            if d.endswith(".xcresult"):
                return os.path.join(root, d)
    return None

def extract_durations(xcresult_path: str) -> dict[str, float]:
    """从 xcresult 提取每个测试的耗时（毫秒）."""
    result = subprocess.run(
        ["xcrun", "xcresulttool", "get", "--path", xcresult_path, "--format", "json"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"⚠️  xcresulttool 失败: {result.stderr}", file=sys.stderr)
        return {}

    # 简化版：用 grep 提取 duration 字段（xcresult JSON 结构复杂，避免递归解析）
    import re
    durations = {}
    lines = result.stdout.splitlines()
    current_test = None
    for line in lines:
        name_match = re.search(r'"testName".*?:\s*"([^"]+)"', line)
        if name_match:
            current_test = name_match.group(1)
        dur_match = re.search(r'"duration".*?:\s*"?([0-9.]+)"?', line)
        if dur_match and current_test:
            durations[current_test] = float(dur_match.group(1)) * 1000  # 秒 → 毫秒
            current_test = None
    return durations

def main():
    xcresult = find_xcresult()
    if not xcresult:
        print("⚠️  未找到 .xcresult，跳过性能回归检测", file=sys.stderr)
        return 0

    print(f"📊 性能回归检测: {os.path.basename(xcresult)}")
    current = extract_durations(xcresult)

    if not current:
        print("⚠️  未能提取性能数据，跳过（首次运行请执行 generate-pipeline-perf-baseline.sh）")
        return 0

    regressions = []
    warnings = []
    for test_name, duration_ms in current.items():
        baseline_file = os.path.join(BASELINE_DIR, f"{test_name}.json")
        if not os.path.exists(baseline_file):
            print(f"   ℹ️  {test_name}: {duration_ms:.1f}ms (无基线，跳过)")
            continue

        with open(baseline_file) as f:
            baseline = json.load(f)

        baseline_ms = baseline["baseline_ms"]
        tolerance = baseline.get("tolerance_pct", TOLERANCE_PCT)
        delta_pct = ((duration_ms - baseline_ms) / baseline_ms) * 100

        if delta_pct > tolerance:
            regressions.append((test_name, baseline_ms, duration_ms, delta_pct))
            print(f"   ❌ {test_name}: {duration_ms:.1f}ms (+{delta_pct:.1f}% vs baseline {baseline_ms:.1f}ms)")
        elif delta_pct > WARNING_PCT:
            warnings.append((test_name, baseline_ms, duration_ms, delta_pct))
            print(f"   ⚠️  {test_name}: {duration_ms:.1f}ms (+{delta_pct:.1f}% vs baseline {baseline_ms:.1f}ms)")
        else:
            print(f"   ✅ {test_name}: {duration_ms:.1f}ms ({delta_pct:+.1f}%)")

    if regressions:
        print(f"\n❌ {len(regressions)} 个性能回归超过 {TOLERANCE_PCT}% 阈值:")
        for name, base, cur, delta in regressions:
            print(f"   {name}: {base:.0f}ms → {cur:.0f}ms (+{delta:.1f}%)")
        print("\n如有意提升基线，请运行: Tools/ci/generate-pipeline-perf-baseline.sh")
        return 1

    if warnings:
        print(f"\n⚠️  {len(warnings)} 个测试性能退化 5-10%，请注意")
    print("✅ 性能回归检测通过")
    return 0

if __name__ == "__main__":
    sys.exit(main())
PYEOF
chmod +x Tools/ci/check-pipeline-perf-regression.py
```

- [ ] **Step 3: 初始化基线目录**

```bash
mkdir -p build/.perf_baselines
touch build/.perf_baselines/.gitkeep
echo "build/.perf_baselines/*.json" >> .gitignore
```

- [ ] **Step 4: 在 CI 中添加性能回归步骤**

在 `.woodpecker.yml` 的 `test` 步骤末尾添加：
```yaml
      - echo "===> Checking performance regression..."
      - python3 Tools/ci/check-pipeline-perf-regression.py
```

在 `.github/workflows/ci.yml` 的 `test` job 中添加：
```yaml
      - name: Check Performance Regression
        run: python3 Tools/ci/check-pipeline-perf-regression.py
```

- [ ] **Step 5: 提交**

```bash
git add Tools/ci/check-pipeline-perf-regression.py Tools/ci/generate-pipeline-perf-baseline.sh build/.perf_baselines/.gitkeep .gitignore .woodpecker.yml .github/workflows/ci.yml
git commit -m "ci: 性能回归检测 — 10%阈值基线比对 + 自动基线更新脚本"
```

---

### Task 9: 增量编译优化

- [ ] **Step 1: 修改 Woodpecker clone-repo 为增量 fetch**

修改 `.woodpecker.yml` 的 `clone-repo` 步骤：

```yaml
  clone-repo:
    image: bash
    commands:
      - |
        if git rev-parse --git-dir > /dev/null 2>&1; then
          echo "📦 已有仓库，增量 fetch..."
          git fetch origin
          git reset --hard $CI_COMMIT_SHA
        else
          echo "📥 首次克隆..."
          git clone http://localhost:3000/constantine/ZhiYu.git .
          git checkout $CI_COMMIT_SHA
        fi
      # 仅 project.yml 或 Package.resolved 变更时清空构建缓存
      - |
        if git diff --name-only HEAD~1 | grep -qE "project.yml|Package.resolved"; then
          echo "🧹 依赖配置变更，清空 DerivedData..."
          rm -rf build/DerivedData-*
        fi
```

- [ ] **Step 2: 提交**

```bash
git add .woodpecker.yml
git commit -m "ci: Woodpecker 增量 fetch + 智能 DerivedData 清理"
```

---

### Task 10: 编译警告转错误（试运行）

- [ ] **Step 1: 在 security-scan.yml 中添加严格构建**

在 `.github/workflows/security-scan.yml` 末尾添加：

```yaml
      - name: Build with Warnings as Errors (trial)
        run: |
          echo "🔨 严格编译模式 (warnings-as-errors)..."
          xcodebuild build \
            -project ZhiYu.xcodeproj \
            -scheme ZhiYu \
            -destination 'generic/platform=iOS Simulator' \
            SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
            CODE_SIGNING_ALLOWED=NO \
            CODE_SIGNING_REQUIRED=NO \
            2>&1 | tee build/warnings_as_errors.log
          if [ ${PIPESTATUS[0]} -ne 0 ]; then
            echo "⚠️  存在编译警告需修复（此为试运行，暂不阻断）"
            echo "警告数: $(grep -c 'warning:' build/warnings_as_errors.log || echo 0)"
          else
            echo "✅ 严格编译通过"
          fi
        continue-on-error: true
```

- [ ] **Step 2: 提交**

```bash
git add .github/workflows/security-scan.yml
git commit -m "ci: security-scan 中试运行 SWIFT_TREAT_WARNINGS_AS_ERRORS"
```

---

## Phase 4: 运维韧性

### Task 11: 确定性构建配置

**Files:**
- Modify: `project.yml`
- Create: `Tools/ci/check-pipeline-reproducible.sh`

- [ ] **Step 1: project.yml 增加确定性编译设置**

修改 `project.yml`，在 `settings.base` 中添加：

```yaml
settings:
  base:
    SWIFT_COMPILATION_MODE: wholemodule
    SWIFT_STRICT_CONCURRENCY: complete
    # 确定性构建: 消除时间戳变数
    # SOURCE_DATE_EPOCH 在 CI 中通过环境变量注入
```

- [ ] **Step 2: 创建构建可重现验证脚本**

```bash
cat > Tools/ci/check-pipeline-reproducible.sh << 'EOF'
#!/bin/bash
# ==============================================================================
# ci-check-pipeline-reproducible.sh
# 两次独立构建 → 比对二进制 hash → 验证确定性
# 用法: Tools/ci/check-pipeline-reproducible.sh
# ==============================================================================
set -euo pipefail

PROJECT="ZhiYu.xcodeproj"
SCHEME="ZhiYu"
DEST="generic/platform=iOS Simulator"
BUILD_DIR="build/reproducible_test"

echo "🔨 确定性构建验证 (L1+L2)"

# 固定时间戳
export SOURCE_DATE_EPOCH=$(git log -1 --format=%ct)

mkdir -p "$BUILD_DIR"

for i in 1 2; do
    echo "   构建 #${i}..."
    xcodebuild build \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "$DEST" \
        -derivedDataPath "$BUILD_DIR/build${i}" \
        CODE_SIGNING_ALLOWED=NO \
        CODE_SIGNING_REQUIRED=NO \
        2>&1 | tail -3
done

# 找到二进制文件
BIN1=$(find "$BUILD_DIR/build1" -name "ZhiYu" -type f -not -path "*.dSYM/*" | head -1)
BIN2=$(find "$BUILD_DIR/build2" -name "ZhiYu" -type f -not -path "*.dSYM/*" | head -1)

if [ -z "$BIN1" ] || [ -z "$BIN2" ]; then
    echo "⚠️  未找到二进制文件，跳过比对"
    exit 0
fi

HASH1=$(shasum -a 256 "$BIN1" | cut -d' ' -f1)
HASH2=$(shasum -a 256 "$BIN2" | cut -d' ' -f1)

echo ""
if [ "$HASH1" = "$HASH2" ]; then
    echo "✅ 构建可重现: SHA256 一致"
    echo "   $HASH1"
else
    echo "⚠️  构建不可重现: SHA256 不一致"
    echo "   build1: $HASH1"
    echo "   build2: $HASH2"
    echo "   差异分析 (前 100 字节):"
    diff <(xxd "$BIN1" | head -20) <(xxd "$BIN2" | head -20) || true
fi

rm -rf "$BUILD_DIR"
EOF
chmod +x Tools/ci/check-pipeline-reproducible.sh
```

- [ ] **Step 3: 在 CI 中添加验证步骤**

在 `ci.yml` 的 `multi-platform` job 中添加最后一个 matrix entry（仅 iOS 做确定性验证）：

```yaml
      - name: Verify Reproducible Build (iOS only)
        if: matrix.platform.name == 'iOS'
        run: bash Tools/ci/check-pipeline-reproducible.sh
```

- [ ] **Step 4: 提交**

```bash
git add project.yml Tools/ci/check-pipeline-reproducible.sh .github/workflows/ci.yml
git commit -m "ci: 确定性构建 L1+L2 — wholemodule + SOURCE_DATE_EPOCH + 双构建比对"
```

---

### Task 12: 飞书 CI 告警

**Files:**
- Create: `Tools/ci/run-pipeline-feishu.sh`

- [ ] **Step 1: 创建飞书通知脚本**

```bash
cat > Tools/ci/run-pipeline-feishu.sh << 'EOF'
#!/bin/bash
# ==============================================================================
# run-pipeline-feishu.sh
# CI 流水线状态飞书通知 — 仅在失败或恢复时发送
# 用法: Tools/ci/run-pipeline-feishu.sh
# 环境变量: FEISHU_WEBHOOK_URL (CI secret), CI_PIPELINE_STATUS, CI_COMMIT_SHA,
#           CI_COMMIT_MESSAGE, CI_PIPELINE_URL, CI_PIPELINE_NUMBER
# ==============================================================================
set -euo pipefail

# 仅在失败或恢复时发送
STATUS="${CI_PIPELINE_STATUS:-unknown}"
if [ "$STATUS" != "failure" ] && [ "$STATUS" != "success" ]; then
    exit 0
fi

# 检查上次运行状态文件，判定是否为"恢复"
HEALTH_FILE="build/.ci_health"
LAST_STATUS="unknown"
if [ -f "$HEALTH_FILE" ]; then
    LAST_STATUS=$(head -1 "$HEALTH_FILE")
fi

# 更新健康状态
echo "$STATUS" > "$HEALTH_FILE"

# 如果状态未变（连续失败或连续成功），不重复告警
if [ "$STATUS" = "$LAST_STATUS" ]; then
    echo "ℹ️  状态未变 ($STATUS)，跳过通知"
    exit 0
fi

WEBHOOK="${FEISHU_WEBHOOK_URL:-}"
if [ -z "$WEBHOOK" ]; then
    echo "⚠️  FEISHU_WEBHOOK_URL 未设置，跳过通知"
    exit 0
fi

SHA_SHORT="${CI_COMMIT_SHA:0:8}"
MSG="${CI_COMMIT_MESSAGE:-No message}"
PIPELINE_URL="${CI_PIPELINE_URL:-https://woodpecker.zhiyu.app}"

if [ "$STATUS" = "failure" ]; then
    EMOJI="🔴"
    TITLE="CI 流水线失败"
    COLOR="red"
else
    EMOJI="🟢"
    TITLE="CI 流水线已恢复"
    COLOR="green"
fi

# 构造飞书消息卡片
JSON=$(cat << JSONEOF
{
  "msg_type": "interactive",
  "card": {
    "header": {
      "title": {"tag": "plain_text", "content": "$EMOJI $TITLE"},
      "template": "$COLOR"
    },
    "elements": [
      {"tag": "div", "text": {"tag": "lark_md", "content": "**提交:** $SHA_SHORT — $MSG"}},
      {"tag": "div", "text": {"tag": "lark_md", "content": "**流水线:** #$CI_PIPELINE_NUMBER"}},
      {"tag": "action", "actions": [{"tag": "button", "text": {"tag": "plain_text", "content": "查看日志"}, "url": "$PIPELINE_URL", "type": "default"}]}
    ]
  }
}
JSONEOF
)

curl -s -X POST -H "Content-Type: application/json" -d "$JSON" "$WEBHOOK"
echo ""
echo "✅ 飞书通知已发送 ($STATUS)"
EOF
chmod +x Tools/ci/run-pipeline-feishu.sh
```

- [ ] **Step 2: 在 Woodpecker 中添加通知步骤**

在 `.woodpecker.yml` 末尾添加：

```yaml
  notify:
    depends_on: [test, ui-test, multi-platform]
    image: bash
    commands:
      - bash Tools/ci/run-pipeline-feishu.sh
    secrets: [FEISHU_WEBHOOK_URL]
    when:
      status: [failure, success]
```

- [ ] **Step 3: 配置 Woodpecker Secret**

```bash
# 在 Woodpecker Web UI → Repository → Secrets 中添加:
# Name: FEISHU_WEBHOOK_URL
# Value: https://open.feishu.cn/open-apis/bot/v2/hook/xxxxxxxxx
echo "⚠️  请手动在 Woodpecker Web UI 中配置 FEISHU_WEBHOOK_URL secret"
```

- [ ] **Step 4: 提交**

```bash
git add Tools/ci/run-pipeline-feishu.sh .woodpecker.yml
git commit -m "ci: 飞书 CI 告警 — 失败/恢复时推送消息卡片"
```

---

### Task 13: Canary 部署管道

**Files:**
- Create: `fastlane/Fastfile`

- [ ] **Step 1: 安装 fastlane**

```bash
brew install fastlane
```

- [ ] **Step 2: 创建 Fastfile**

```bash
mkdir -p fastlane
cat > fastlane/Fastfile << 'EOF'
default_platform(:ios)

platform :ios do
  desc "Canary 构建 → TestFlight Internal 上传"
  lane :canary do
    # 确保使用最新生成的 Xcode 项目
    sh("xcodegen generate")

    # Release 构建
    build_app(
      scheme: "ZhiYu",
      configuration: "Release",
      export_method: "app-store",
      skip_codesigning: true  # CI 中由 Fastlane Match 或手动签名处理
    )

    # 上传到 TestFlight Internal
    upload_to_testflight(
      skip_waiting_for_build_processing: true,
      distribute_external: false,  # 仅 Internal 测试组
      changelog: "Canary build from CI — commit #{last_git_commit[:abbreviated_commit_hash]}"
    )
  end

  desc "获取最新构建状态"
  lane :build_status do
    latest_testflight_build_number = latest_testflight_build_number(
      initial_build_number: 1
    )
    UI.message("Latest TestFlight build: #{latest_testflight_build_number}")
  end
end
EOF
```

- [ ] **Step 3: 添加 Canary 部署步骤到 CI**

在 `.woodpecker.yml` 中添加（手动触发，不随每次 push 自动运行）：

```yaml
  canary-deploy:
    depends_on: [test]
    image: bash
    commands:
      - echo "🚀 触发 Canary 部署..."
      - fastlane canary
    when:
      event: [deployment]
```

- [ ] **Step 4: 提交**

```bash
git add fastlane/Fastfile .woodpecker.yml
git commit -m "ci: Canary 部署管道 — fastlane pilot → TestFlight Internal 自动上传"
```

---

### Task 14: 故障演练文档

- [ ] **Step 1: 创建演练日志模板**

```bash
mkdir -p Docs/CI
cat > Docs/CI/drill-log.md << 'EOF'
# CI 故障演练日志

> 每月第一个周一执行，记录演练结果与改进项。

| 日期 | 场景 | 操作 | 结果 | 改进项 |
|------|------|------|------|--------|
| - | - | - | - | - |

## 演练场景清单

### 1. 依赖不可用
- **操作:** `rm -rf ~/.cache/zhiyu-spm`
- **预期:** CI 能从远程重新下载 SPM 依赖，构建成功
- **异常处理:** CI 超时或网络错误 → 检查 SPM 镜像配置

### 2. 磁盘满
- **操作:** `dd if=/dev/zero of=build/fill.tmp bs=1m count=1024`
- **预期:** CI 超时机制生效，飞书告警触发
- **清理:** `rm build/fill.tmp`

### 3. Agent 宕机
- **操作:** `launchctl unload ~/Library/LaunchAgents/com.zhiyu.woodpecker-agent.plist`
- **预期:** Gitea Webhook 重试机制正常
- **恢复:** `launchctl load ~/Library/LaunchAgents/com.zhiyu.woodpecker-agent.plist`
EOF
```

- [ ] **Step 2: 提交**

```bash
git add Docs/CI/drill-log.md
git commit -m "docs: CI 故障演练日志模板 — 月度演练场景与记录"
```

---

## 自审清单

- [x] Spec 覆盖: 四阶段 15 项全部有对应 Task
- [x] 无占位符: 所有步骤包含实际代码
- [x] 类型一致性: Task 间工具名、路径、参数一致
- [x] 文件路径: 全部使用绝对路径或相对于项目根目录
