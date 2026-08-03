# 版本号管理 — 实现计划

> **对于自动化工作器：** 必需子技能：使用 superpowers:subagent-driven-development（推荐）或 superpowers:executing-plans 按任务逐步实现此计划。步骤使用 checkbox (`- [ ]`) 语法进行跟踪。

**目标：** 实现 Git Tag 驱动的版本管理系统——CI 自动注入 SemVer + 构建号 + 短哈希到 Info.plist，关于页面从 Bundle 读取真实版本号。

**架构：** `git tag → ci-build-pipeline-version-inject.sh (CI) → Info.plist → Bundle.main → AboutView`。注入脚本使用 `PlistBuddy`（macOS 原生），双 CI（Woodpecker + GitHub Actions）均兼容。开发和 PR 构建无 tag 时 fallback 为 `0.0.0-dev`。

**技术栈：** Bash + PlistBuddy (ci-build-pipeline-version-inject.sh)，SwiftUI (AboutView)，Shell 测试 (Bats 风格)，SnapTesting (AboutView 快照)，YAML (CI 配置)

---

## 文件结构

| 文件 | 操作 | 职责 |
|------|------|------|
| `Tools/ci/build-pipeline-version-inject.sh` | 创建 | 从 git 提取版本号，写入 Info.plist |
| `Tools/ci/run-test-version-inject-unit.sh` | 创建 | ci-build-pipeline-version-inject.sh 的单元测试（4 个场景） |
| `Sources/App/Scenes/AboutView.swift` | 修改 | 替换硬编码版本号为 Bundle 读取 |
| `Tests/SnapshotTests/ComponentSnapshots.swift` | 修改 | 新增 AboutView 快照测试 |
| `project.yml` | 修改 | 新增 MARKETING_VERSION / CURRENT_PROJECT_VERSION 占位 |
| `.woodpecker.yml` | 修改 | 新增 inject-version 步骤，调整依赖拓扑 |
| `.github/workflows/ci.yml` | 修改 | 多平台编译前注入版本号 |

---

### Task 1: 创建 ci-build-pipeline-version-inject.sh 脚本

**文件：**
- 创建: `Tools/ci/build-pipeline-version-inject.sh`

- [ ] **Step 1: 编写版本注入脚本**

```bash
#!/bin/bash
# ci-build-pipeline-version-inject.sh — 注入版本号到 Info.plist（双 CI 通用）
#
# 用法: Tools/ci/build-pipeline-version-inject.sh <info_plist_path>
# 示例: bash Tools/ci/build-pipeline-version-inject.sh Sources/Info.plist
#
# 环境要求:
#   - macOS（需要 /usr/libexec/PlistBuddy）
#   - git（需要 git describe / git rev-list / git rev-parse）
#
# 输出字段:
#   CFBundleShortVersionString  — SemVer（来自 git tag，无 tag 时为 "0.0.0-dev"）
#   CFBundleVersion             — 构建号（git rev-list --count HEAD）
#   GIT_SHORT_HASH              — 短提交哈希（git rev-parse --short HEAD）

set -euo pipefail

PLIST="${1:?用法: $0 <info_plist_path>}"

if [ ! -f "$PLIST" ]; then
    echo "[inject_version] ERROR: Info.plist 不存在: $PLIST"
    exit 1
fi

# ── 1. SemVer：从最近祖先 git tag 提取 ──
TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
if [ -n "$TAG" ]; then
    VERSION="${TAG#v}"          # v1.2.3 → 1.2.3
else
    VERSION="0.0.0-dev"         # 无 tag 时 fallback
fi

# ── 2. 构建号：提交总数（跨 CI 系统一致）──
BUILD=$(git rev-list --count HEAD)

# ── 3. 短哈希：精确回溯 commit ──
HASH=$(git rev-parse --short HEAD)

# ── 4. 写入 Info.plist ──
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"

# 自定义键 GIT_SHORT_HASH（Info.plist 无标准字段，运行时通过 infoDictionary 读取）
if /usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" "$PLIST" &>/dev/null; then
    /usr/libexec/PlistBuddy -c "Set :GIT_SHORT_HASH $HASH" "$PLIST"
else
    /usr/libexec/PlistBuddy -c "Add :GIT_SHORT_HASH string $HASH" "$PLIST"
fi

echo "[inject_version] CFBundleShortVersionString=$VERSION  CFBundleVersion=$BUILD  GIT_SHORT_HASH=$HASH"
```

- [ ] **Step 2: 设置脚本可执行权限**

```bash
chmod +x Tools/ci/build-pipeline-version-inject.sh
```

- [ ] **Step 3: 本地验证脚本能正常运行**

```bash
bash Tools/ci/build-pipeline-version-inject.sh Sources/Info.plist
```

预期输出：
```
[inject_version] CFBundleShortVersionString=0.0.0-dev  CFBundleVersion=<N>  GIT_SHORT_HASH=<hash>
```

验证 Info.plist 已写入：
```bash
/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Sources/Info.plist
/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Sources/Info.plist
/usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" Sources/Info.plist
```

- [ ] **Step 4: 提交**

```bash
git add Tools/ci/build-pipeline-version-inject.sh
git commit -m "feat: 新增版本号注入脚本 ci-build-pipeline-version-inject.sh

从 git tag 提取 SemVer + git rev-list 构建号 + 短哈希，
通过 PlistBuddy 写入 Info.plist 的 CFBundleShortVersionString / CFBundleVersion / GIT_SHORT_HASH。
无 tag 时 fallback 为 0.0.0-dev。双 CI (Woodpecker + GitHub Actions) 通用。"
```

---

### Task 2: 编写 ci-build-pipeline-version-inject.sh 单元测试

**文件：**
- 创建: `Tools/ci/run-test-version-inject-unit.sh`

测试策略：在临时 git 仓库中测试，不依赖真实项目仓库。使用 Bats 风格（纯 shell，无外部依赖）或直接手工断言。

- [ ] **Step 1: 编写测试脚本**

```bash
#!/bin/bash
# ci-run-test-version-inject-unit.sh — ci-build-pipeline-version-inject.sh 的单元测试
#
# 测试场景:
#   1. 无 tag → CFBundleShortVersionString = "0.0.0-dev"
#   2. 有 tag  → CFBundleShortVersionString = 去掉 v 前缀的值
#   3. 构建号  → CFBundleVersion = git rev-list --count HEAD
#   4. 短哈希  → GIT_SHORT_HASH 为 7 字符 hex

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INJECT_SCRIPT="$SCRIPT_DIR/.Tools/ci/build-pipeline-version-inject.sh"
PASS=0
FAIL=0

green() { printf '\033[32m%s\033[0m\n' "$1"; }
red()   { printf '\033[31m%s\033[0m\n' "$1"; }

assert_equals() {
    local label="$1" expected="$2" actual="$3"
    if [ "$expected" = "$actual" ]; then
        green "  ✅ $label: $actual"
        PASS=$((PASS + 1))
    else
        red "  ❌ $label: 预期 '$expected'，实际 '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

# ── 初始化临时 git 仓库 ──
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

cd "$TMPDIR"
git init --quiet
git config user.email "test@zhiyu.local"
git config user.name "Test Runner"

# 创建模拟 Info.plist
cat > Info.plist << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
</dict>
</plist>
PLIST

# 创建初始提交（构建号从 1 开始）
git add Info.plist
git commit --quiet -m "Initial commit"

echo ""
echo "════════════════════════════════════════"
echo "  ci-build-pipeline-version-inject.sh 单元测试"
echo "════════════════════════════════════════"
echo ""

# ── 测试 1: 无 tag → fallback "0.0.0-dev" ──
echo "── 测试 1: 无 git tag ──"
bash "$INJECT_SCRIPT" Info.plist > /dev/null 2>&1 || true
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null)
assert_equals "版本号应为 0.0.0-dev" "0.0.0-dev" "$VERSION"
echo ""

# ── 测试 2: 有 tag v1.2.3 → "1.2.3" ──
echo "── 测试 2: git tag v1.2.3 ──"

# 添加第二个提交让构建号变化
echo "test" > dummy.txt
git add dummy.txt
git commit --quiet -m "Second commit"

git tag -a v1.2.3 -m "Test release" 2>/dev/null || git tag v1.2.3
bash "$INJECT_SCRIPT" Info.plist > /dev/null 2>&1 || true
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Info.plist 2>/dev/null)
assert_equals "版本号应为 1.2.3" "1.2.3" "$VERSION"
echo ""

# ── 测试 3: 构建号 = git rev-list --count HEAD ──
echo "── 测试 3: 构建号验证 ──"
EXPECTED_BUILD=$(git rev-list --count HEAD)
ACTUAL_BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Info.plist 2>/dev/null)
assert_equals "构建号应为 $EXPECTED_BUILD" "$EXPECTED_BUILD" "$ACTUAL_BUILD"
echo ""

# ── 测试 4: 短哈希为 hex 字符串 ──
echo "── 测试 4: 短哈希格式 ──"
HASH=$(/usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" Info.plist 2>/dev/null)
if [ -n "$HASH" ] && [ "${#HASH}" -ge 7 ] 2>/dev/null; then
    green "  ✅ 短哈希: $HASH (长度 ${#HASH})"
    PASS=$((PASS + 1))
else
    red "  ❌ 短哈希格式异常: '$HASH'"
    FAIL=$((FAIL + 1))
fi
echo ""

# ── 测试 5: 自定义键 GIT_SHORT_HASH 可正确 Add + Set ──
echo "── 测试 5: GIT_SHORT_HASH 键幂等写入 ──"
bash "$INJECT_SCRIPT" Info.plist > /dev/null 2>&1 || true
HASH2=$(/usr/libexec/PlistBuddy -c "Print :GIT_SHORT_HASH" Info.plist 2>/dev/null)
assert_equals "重复注入后短哈希一致" "$HASH" "$HASH2"
echo ""

# ── 结果汇总 ──
echo "════════════════════════════════════════"
echo "  通过: $PASS  失败: $FAIL"
echo "════════════════════════════════════════"

[ "$FAIL" -eq 0 ] || exit 1
```

- [ ] **Step 2: 运行测试验证全部通过**

```bash
chmod +x Tools/ci/run-test-version-inject-unit.sh
bash Tools/ci/run-test-version-inject-unit.sh
```

预期输出：
```
  ✅ 版本号应为 0.0.0-dev: 0.0.0-dev
  ✅ 版本号应为 1.2.3: 1.2.3
  ✅ 构建号应为 2: 2
  ✅ 短哈希: abc1234 (长度 7)
  ✅ 重复注入后短哈希一致: abc1234
  通过: 5  失败: 0
```

- [ ] **Step 3: 提交**

```bash
git add Tools/ci/run-test-version-inject-unit.sh
git commit -m "test: 新增 ci-build-pipeline-version-inject.sh 单元测试

覆盖 5 个场景：无 tag fallback、正常 tag、构建号验证、短哈希格式、幂等写入。
在临时 git 仓库中运行，不依赖项目真实历史。"
```

---

### Task 3: 修复 AboutView 硬编码版本号

**文件：**
- 修改: `Sources/App/Scenes/AboutView.swift:52`

- [ ] **Step 1: 替换硬编码版本号为动态读取 Bundle**

修改 `Sources/App/Scenes/AboutView.swift`，将第 52 行的硬编码版本号替换为从 `Bundle.main.infoDictionary` 读取：

```swift
// 第 52 行：将硬编码字符串替换为 computed property
// 前:
infoRow(title: L10n.Settings.About.version, value: "1.0.0 (20260512)")

// 后:
infoRow(title: L10n.Settings.About.version, value: versionDisplayString)
```

在 `AboutView` 结构体中新增 computed property（`infoRow` 方法之前）：

```swift
/// 从 Bundle 读取 CI 注入的版本信息，展示为 "1.2.3 (342 · abc1234)" 格式
private var versionDisplayString: String {
    let info = Bundle.main.infoDictionary
    let version = info?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    let build = info?["CFBundleVersion"] as? String ?? "?"
    let hash = info?["GIT_SHORT_HASH"] as? String ?? "unknown"
    return "\(version) (\(build) · \(hash))"
}
```

- [ ] **Step 2: 本地验证**

```bash
# 先注入版本号模拟 CI 行为
bash Tools/ci/build-pipeline-version-inject.sh Sources/Info.plist
# 编译验证
xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'generic/platform=iOS Simulator' 2>&1 | tail -5
```

预期：BUILD SUCCEEDED

- [ ] **Step 3: 提交**

```bash
git add Sources/App/Scenes/AboutView.swift
git commit -m "fix: AboutView 版本号从硬编码改为 Bundle 动态读取

CFBundleShortVersionString + CFBundleVersion + GIT_SHORT_HASH
组合展示为 '1.2.3 (342 · abc1234)' 格式。
开发构建无 tag 时显示 '0.0.0-dev (N · hash)'。"
```

---

### Task 4: 新增 AboutView 快照测试

**文件：**
- 修改: `Tests/SnapshotTests/ComponentSnapshots.swift` — 新增 testAboutView 方法

- [ ] **Step 1: 新增快照测试方法**

在 `ComponentSnapshots` 类中新增 `testAboutView` 方法（放在现有测试方法之后，如 `testBreadcrumbView` 之后）：

```swift
/// 测试关于页面 (AboutView) 的视觉一致性，验证版本号从 Info.plist 正确渲染
func testAboutView() {
    setupMockEnvironment()
    
    let view = AboutView()
        .frame(width: DesignSystem.Metrics.customSize375, height: DesignSystem.Metrics.customSize812)
        .background(Color.appBackground)
    
    assertSnapshot(of: view, as: .image(precision: 0.95, layout: .device(config: .iPhone13Pro)))
}
```

- [ ] **Step 2: 运行快照测试（录制模式，首次生成基准图）**

```bash
RECORD_SNAPSHOTS=1 xcodebuild test \
  -project ZhiYu.xcodeproj \
  -scheme ZhiYu \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ZhiYuTests/ComponentSnapshots/testAboutView 2>&1 | tail -10
```

- [ ] **Step 3: 再次运行确认快照匹配**

```bash
xcodebuild test \
  -project ZhiYu.xcodeproj \
  -scheme ZhiYu \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ZhiYuTests/ComponentSnapshots/testAboutView 2>&1 | tail -10
```

预期：** TEST SUCCEEDED **

- [ ] **Step 4: 提交**

```bash
git add Tests/SnapshotTests/ComponentSnapshots.swift
# 如果有新的基准快照图片，也要添加（通常在 Tests/SnapshotTests/__Snapshots__/ 目录下）
git add Tests/SnapshotTests/__Snapshots__/ 2>/dev/null || true
git commit -m "test: 新增 AboutView 快照测试

验证关于页面版本号渲染的视觉一致性。测试从 Bundle 读取版本信息
并正确展示为 '1.2.3 (342 · abc1234)' 格式。"
```

---

### Task 5: 更新 project.yml 版本占位

**文件：**
- 修改: `project.yml` — 在 `settings.base` 中新增版本占位

- [ ] **Step 1: 在 project.yml settings.base 中新增版本占位**

在 `project.yml` 的 `settings.base` 下，`SWIFT_VERSION: "5.9"` 之后新增两行：

```yaml
settings:
  base:
    SWIFT_VERSION: "5.9"
    MARKETING_VERSION: "0.0.0-dev"       # CI 会在构建前通过 ci-build-pipeline-version-inject.sh 覆盖
    CURRENT_PROJECT_VERSION: "0"          # CI 会在构建前通过 ci-build-pipeline-version-inject.sh 覆盖
```

- [ ] **Step 2: 重新生成 Xcode 工程并验证**

```bash
xcodegen generate
# 验证生成的 pbxproj 中包含 MARKETING_VERSION
grep -c "MARKETING_VERSION" ZhiYu.xcodeproj/project.pbxproj
```

预期输出：`>0`（至少出现一次）

- [ ] **Step 3: 提交**

```bash
git add project.yml ZhiYu.xcodeproj/project.pbxproj
git commit -m "feat: project.yml 新增版本号占位设置

MARKETING_VERSION = 0.0.0-dev, CURRENT_PROJECT_VERSION = 0。
CI 在构建前通过 ci-build-pipeline-version-inject.sh 覆盖实际值。"
```

---

### Task 6: 更新 Woodpecker CI 配置

**文件：**
- 修改: `.woodpecker.yml` — 新增 inject-version 步骤

- [ ] **Step 1: 新增 inject-version 步骤并调整依赖拓扑**

修改 `.woodpecker.yml`，在 `prepare-dependencies` 之后新增 `inject-version` 步骤，并将 `build-ios` 的 `depends_on` 从 `prepare-dependencies` 改为 `inject-version`：

```yaml
labels:
  backend: local

skip_clone: true

pipeline_timeout: 30

steps:
  clone-repo:
    image: bash
    commands:
      - echo "machine localhost login $CI_NETRC_USERNAME password $CI_NETRC_PASSWORD" > ~/.netrc
      - export CLONE_URL=$(echo $CI_REPO_CLONE_URL | sed 's|http://[^/]*:3000|http://localhost:3000|g')
      - git init && git remote add origin $CLONE_URL 2>/dev/null || true
      - git fetch origin $CI_COMMIT_SHA && git reset --hard FETCH_HEAD

  static-analysis:
    depends_on: [clone-repo]
    image: bash
    commands:
      - echo "===> 安装静态分析 Python 依赖"
      - pip3 install --quiet radon 2>/dev/null || true
      - echo "===> 运行全部 19 项静态分析（并行执行）"
      - bash Tools/ci/run-code-static-analysis.sh

  prepare-dependencies:
    depends_on: [clone-repo]
    image: bash
    commands:
      - xcodegen generate
      - mkdir -p build /tmp/zhiyu-spm-cache
      - xcodebuild -resolvePackageDependencies -project ZhiYu.xcodeproj -scheme ZhiYu -clonedSourcePackagesDirPath /tmp/zhiyu-spm-cache

  inject-version:
    depends_on: [prepare-dependencies]
    image: bash
    commands:
      - bash Tools/ci/build-pipeline-version-inject.sh Sources/Info.plist

  build-ios:
    depends_on: [inject-version]
    image: bash
    commands:
      - bash Tools/ci/build-pipeline-platform.sh ZhiYu 'generic/platform=iOS Simulator' ios

  build-macos:
    depends_on: [build-ios]
    image: bash
    commands:
      - bash Tools/ci/build-pipeline-platform.sh ZhiYuMac 'platform=macOS' macos

  build-watchos:
    depends_on: [build-macos]
    image: bash
    commands:
      - bash Tools/ci/build-pipeline-platform.sh ZhiYuWatch 'generic/platform=watchOS Simulator' watchos

  test-and-verify-coverage:
    depends_on: [build-watchos]
    image: bash
    commands:
      - bash Tools/ci/run-test-with-coverage.sh
```

- [ ] **Step 2: 提交**

```bash
git add .woodpecker.yml
git commit -m "ci: Woodpecker 流水线新增 inject-version 步骤

在 prepare-dependencies (xcodegen generate) 之后、build-ios 之前
调用 ci-build-pipeline-version-inject.sh 写入版本号到 Info.plist。
依赖拓扑: prepare-dependencies → inject-version → build-ios → ..."
```

---

### Task 7: 更新 GitHub Actions CI 配置

**文件：**
- 修改: `.github/workflows/ci.yml` — 在 `multi-platform` job 的每个平台编译前注入版本号

- [ ] **Step 1: 在 multi-platform job 的编译步骤前新增 Inject Version step**

在 `.github/workflows/ci.yml` 的 `multi-platform` job 中，`Download Xcode Project` 步骤之后、`Compile` 步骤之前，新增版本注入：

```yaml
      - name: Generate Xcode Project
        run: |
          brew install xcodegen
          xcodegen generate

      - name: Inject Version
        run: bash Tools/ci/build-pipeline-version-inject.sh Sources/Info.plist
```

注意：GHA 的 `multi-platform` job 使用 `download-artifact` 获取 xcodegen 生成的工程，但 `build-pipeline-version-inject.sh` 需要项目根目录下的 `.git` 目录和 `Sources/Info.plist`。`checkout` 步骤已经提供了 `.git` 目录，所以可以直接运行注入脚本。注入在 xcodegen 之后、xcodebuild 之前执行。

- [ ] **Step 2: 提交**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: GitHub Actions 多平台构建前注入版本号

在 multi-platform 矩阵编译前调用 ci-build-pipeline-version-inject.sh，
确保 iOS/macOS/watchOS 三平台都使用正确的版本号。"
```

---

### Task 8: 运行全部测试验证

- [ ] **Step 1: 运行 inject_version 单元测试**

```bash
bash Tools/ci/run-test-version-inject-unit.sh
```

预期：5/5 通过

- [ ] **Step 2: 恢复 Info.plist 并验证 AboutView 编译通过**

```bash
# 恢复 Info.plist 到注入前的状态（git checkout）
git checkout Sources/Info.plist
# 注入版本号
bash Tools/ci/build-pipeline-version-inject.sh Sources/Info.plist
# 重新生成工程
xcodegen generate
# 编译验证
xcodebuild build -project ZhiYu.xcodeproj -scheme ZhiYu -destination 'generic/platform=iOS Simulator' 2>&1 | tail -5
```

预期：BUILD SUCCEEDED

- [ ] **Step 3: 运行快照测试**

```bash
xcodebuild test \
  -project ZhiYu.xcodeproj \
  -scheme ZhiYu \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:ZhiYuTests/ComponentSnapshots/testAboutView 2>&1 | tail -10
```

预期：** TEST SUCCEEDED **

- [ ] **Step 4: 运行完整测试套件确保无回归**

```bash
xcodebuild test \
  -project ZhiYu.xcodeproj \
  -scheme ZhiYu \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30
```

- [ ] **Step 5: 恢复 Info.plist 到仓库状态并提交最终结果**

```bash
git checkout Sources/Info.plist
git add -A
git status
```

确认所有改动文件都在预期范围内，没有意外的变更。

---

## 自审清单

实施完成后验证：

1. **本地无 tag 构建**：About 页显示 `0.0.0-dev (N · abc1234)` — 其中 N 为 commit 数
2. **打 tag 后构建**：`git tag v1.0.0 && bash Tools/ci/build-pipeline-version-inject.sh Sources/Info.plist` → About 页显示 `1.0.0 (N · abc1234)`
3. **构建号单调递增**：每新增一个 commit，构建号 +1
4. **双 CI 兼容**：Woodpecker 和 GitHub Actions 都能正确注入版本号
5. **快照测试覆盖**：AboutView 渲染结果可验证
6. **已有门禁无回归**：`ios-check-release-appstore.py` 校验 CFBundleVersion 格式仍然通过
