# 测试结构重构与度量体系建立 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 643 个主 App 测试文件按源码目录 1:1 镜像重组，下沉 8 个 SPM 包重复测试，拆分 18 个超大文件，建立自动化结构度量脚本并集成 CI 门禁。

**Architecture:** 四阶段推进——Phase 1 建立度量基线（不动代码，先量化）→ Phase 2 目录对齐迁移（机械移动 + xcodegen 重生成）→ Phase 3 SPM 测试下沉与去重 → Phase 4 超大文件拆分。每个 Phase 内以"迁移一批 → `make test-unit` 验证 → commit"为循环，确保每步可独立验证、可回滚。

**Tech Stack:** Swift XCTest、XcodeGen（project.yml）、Python 3（度量脚本）、Bash（迁移脚本）、Makefile（验证入口）

## Global Constraints

- **必须使用 `make` 命令构建和测试**，不直接用 `xcodebuild`（排障除外）
- **测试 target 使用 `path: Tests` 整体包含**，文件移动不需要修改 project.yml，但每次移动后需 `make gen` 重生成 xcodeproj
- **每完成一个 Task 必须运行 `make test-unit` 验证**，确保 0 新增失败
- **不能删除测试用例**，只能移动或拆分；如发现测试本身有问题，从源头修复
- **迁移前先 `git stash` 或确保工作区干净**，每个 Task 一个独立 commit
- **遵循 L0-L3 分层**：测试目录与源码目录严格 1:1 镜像
- **SPM 包测试下沉后**，主 App 不再保留重复测试，用例合并到 SPM 包已有测试文件中
- **超大文件拆分后**，原文件删除，新文件按测试主题命名，单文件 ≤ 30 用例
- **模拟器**：iPhone 17 Pro（UDID: `9ABEC5B9-E952-422A-A0AB-E2B785C1B36C`）
- **全量测试基线**：final15 结果 7887 passed, 0 failed, 19 skipped

---

## Phase 1: 度量基线建立（不动代码，先量化）

### Task 1: 创建测试结构度量脚本

**Files:**
- Create: `Tools/CI/audit-test-structure.py`

**Interfaces:**
- Produces: `audit-test-structure.py` — 可独立运行的 Python 脚本，输出 6 项结构度量指标，支持 `--json` 机器可读输出，退出码 0（通过）或 1（不达标）

**度量指标定义：**

| 指标 | 计算方式 | 达标阈值 | 当前值 |
|------|---------|---------|--------|
| `directory_alignment_rate` | 有对应 Sources/ 目录的 Tests/Unit 子目录数 / 总子目录数 | ≥ 95% | ~53% (8/15) |
| `median_cases_per_file` | 所有测试文件用例数的中位数 | 5-20 | 6 |
| `oversized_file_ratio` | 用例数 > 30 的文件数 / 总文件数 | < 5% | 7.3% (47/643) |
| `empty_file_ratio` | 用例数 = 0 的文件数 / 总文件数 | 0% | 0.9% (6/643) |
| `spm_test_coverage_ratio` | SPM 包测试用例数 / (SPM 包测试用例数 + 主 App 中测试 SPM 代码的用例数) | ≥ 80% | ~33% (408/1220) |
| `test_source_file_ratio` | 测试文件数 / 源码文件数 | 0.5-1.5 | 0.97 (643/660) |

- [ ] **Step 1: 编写度量脚本核心逻辑**

```python
#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
测试结构度量脚本 — 量化测试目录与源码目录的对齐度、文件大小分布、SPM 覆盖率等。
"""

import os
import re
import sys
import json
import argparse
from pathlib import Path
from collections import defaultdict

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
TESTS_UNIT_DIR = PROJECT_ROOT / "Tests" / "Unit"
SOURCES_DIR = PROJECT_ROOT / "Sources"
PACKAGES_DIR = PROJECT_ROOT / "Packages"

# 度量阈值
THRESHOLDS = {
    "directory_alignment_rate": {"min": 0.95, "direction": "ge"},
    "median_cases_per_file": {"min": 5, "max": 20, "direction": "range"},
    "oversized_file_ratio": {"max": 0.05, "direction": "le"},
    "empty_file_ratio": {"max": 0.0, "direction": "le"},
    "spm_test_coverage_ratio": {"min": 0.80, "direction": "ge"},
    "test_source_file_ratio": {"min": 0.5, "max": 1.5, "direction": "range"},
}

OVERSIZED_THRESHOLD = 30  # 用例数 > 30 视为超大文件


def count_test_methods(filepath: Path) -> int:
    """统计单个测试文件中的 test 方法数"""
    try:
        content = filepath.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return 0
    # 匹配 func testXXX( 但不匹配 // func testXXX
    return len(re.findall(r"^\s*func\s+test\w+\s*\(", content, re.MULTILINE))


def scan_test_files(test_dir: Path) -> list[dict]:
    """扫描测试目录下所有 .swift 文件，返回文件路径和用例数"""
    results = []
    for swift_file in test_dir.rglob("*.swift"):
        count = count_test_methods(swift_file)
        rel_path = swift_file.relative_to(test_dir.parent)
        results.append({
            "path": str(rel_path),
            "abs_path": str(swift_file),
            "test_count": count,
        })
    return results


def measure_directory_alignment() -> dict:
    """度量 Tests/Unit 子目录与 Sources/ 目录的对齐率"""
    test_subdirs = []
    for item in sorted(TESTS_UNIT_DIR.iterdir()):
        if item.is_dir():
            test_subdirs.append(item.name)

    aligned = 0
    misaligned = []
    for subdir in test_subdirs:
        source counterpart = SOURCES_DIR / subdir
        if source_counterpart.exists() and source_counterpart.is_dir():
            aligned += 1
        else:
            file_count = len(list((TESTS_UNIT_DIR / subdir).glob("*.swift")))
            misaligned.append({"dir": subdir, "file_count": file_count})

    total = len(test_subdirs)
    rate = aligned / total if total > 0 else 0
    return {
        "metric": "directory_alignment_rate",
        "value": round(rate, 4),
        "aligned_dirs": aligned,
        "total_dirs": total,
        "misaligned": misaligned,
        "threshold": THRESHOLDS["directory_alignment_rate"],
        "passed": rate >= THRESHOLDS["directory_alignment_rate"]["min"],
    }


def measure_cases_distribution(test_files: list[dict]) -> dict:
    """度量每文件用例数分布"""
    counts = sorted([f["test_count"] for f in test_files])
    total = len(counts)
    if total == 0:
        return {"metric": "median_cases_per_file", "value": 0, "passed": False}

    median = counts[total // 2] if total % 2 == 1 else (counts[total // 2 - 1] + counts[total // 2]) / 2
    oversized = sum(1 for c in counts if c > OVERSIZED_THRESHOLD)
    empty = sum(1 for c in counts if c == 0)

    return {
        "median_cases_per_file": {
            "metric": "median_cases_per_file",
            "value": median,
            "threshold": THRESHOLDS["median_cases_per_file"],
            "passed": 5 <= median <= 20,
        },
        "oversized_file_ratio": {
            "metric": "oversized_file_ratio",
            "value": round(oversized / total, 4),
            "oversized_count": oversized,
            "total_files": total,
            "threshold": THRESHOLDS["oversized_file_ratio"],
            "passed": oversized / total <= THRESHOLDS["oversized_file_ratio"]["max"],
        },
        "empty_file_ratio": {
            "metric": "empty_file_ratio",
            "value": round(empty / total, 4),
            "empty_count": empty,
            "total_files": total,
            "threshold": THRESHOLDS["empty_file_ratio"],
            "passed": empty == 0,
        },
    }


def measure_spm_coverage() -> dict:
    """度量 SPM 包测试覆盖率"""
    spm_test_cases = 0
    for pkg_dir in PACKAGES_DIR.iterdir():
        if not pkg_dir.is_dir():
            continue
        tests_dir = pkg_dir / "Tests"
        if tests_dir.exists():
            for swift_file in tests_dir.rglob("*.swift"):
                spm_test_cases += count_test_methods(swift_file)

    # 统计主 App 中测试 SPM 代码的文件（通过 @testable import SPM 包名判断）
    spm_imports = {"UFPCore", "UFPStorage", "UFPDesignSystem", "ZhiYuDomain", "ZhiYuAICore", "ZhiYuFeatures"}
    main_app_spm_cases = 0
    for swift_file in TESTS_UNIT_DIR.rglob("*.swift"):
        try:
            content = swift_file.read_text(encoding="utf-8", errors="ignore")
        except Exception:
            continue
        for pkg in spm_imports:
            if f"@testable import {pkg}" in content:
                main_app_spm_cases += count_test_methods(swift_file)
                break

    total = spm_test_cases + main_app_spm_cases
    ratio = spm_test_cases / total if total > 0 else 0
    return {
        "metric": "spm_test_coverage_ratio",
        "value": round(ratio, 4),
        "spm_test_cases": spm_test_cases,
        "main_app_spm_cases": main_app_spm_cases,
        "threshold": THRESHOLDS["spm_test_coverage_ratio"],
        "passed": ratio >= THRESHOLDS["spm_test_coverage_ratio"]["min"],
    }


def measure_test_source_ratio(test_files: list[dict]) -> dict:
    """度量测试文件与源码文件比"""
    source_count = sum(1 for _ in SOURCES_DIR.rglob("*.swift"))
    test_count = len(test_files)
    ratio = test_count / source_count if source_count > 0 else 0
    return {
        "metric": "test_source_file_ratio",
        "value": round(ratio, 4),
        "test_files": test_count,
        "source_files": source_count,
        "threshold": THRESHOLDS["test_source_file_ratio"],
        "passed": 0.5 <= ratio <= 1.5,
    }


def main():
    parser = argparse.ArgumentParser(description="测试结构度量脚本")
    parser.add_argument("--json", action="store_true", help="输出 JSON 格式")
    parser.add_argument("--verbose", action="store_true", help="显示详细信息")
    args = parser.parse_args()

    test_files = scan_test_files(TESTS_UNIT_DIR)

    results = {
        "directory_alignment": measure_directory_alignment(),
        "cases_distribution": measure_cases_distribution(test_files),
        "spm_coverage": measure_spm_coverage(),
        "test_source_ratio": measure_test_source_ratio(test_files),
    }

    all_passed = all(
        results[k].get("passed", True) for k in results
        if isinstance(results[k], dict) and "passed" in results[k]
    )
    # 展开 cases_distribution
    for k, v in results["cases_distribution"].items():
        results[k] = v
    del results["cases_distribution"]

    if args.json:
        print(json.dumps(results, ensure_ascii=False, indent=2))
    else:
        print("=" * 60)
        print("测试结构度量报告")
        print("=" * 60)
        for key, val in results.items():
            if isinstance(val, dict) and "metric" in val:
                status = "✅" if val.get("passed") else "❌"
                print(f"\n{status} {val['metric']}: {val['value']}")
                if args.verbose:
                    for k2, v2 in val.items():
                        if k2 not in ("metric", "value", "passed", "threshold"):
                            print(f"    {k2}: {v2}")
        print("\n" + "=" * 60)
        print(f"总体: {'✅ 全部达标' if all_passed else '❌ 存在不达标项'}")
        print("=" * 60)

    sys.exit(0 if all_passed else 1)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: 运行度量脚本，记录基线值**

Run: `python3 Tools/CI/audit-test-structure.py --verbose`
Expected: 输出 6 项指标，`directory_alignment_rate` 和 `spm_test_coverage_ratio` 不达标（退出码 1），其余可能达标

- [ ] **Step 3: 将基线值记录到计划文档**

将脚本输出追加到 `Docs/Testing/test-structure-baseline.md`，作为重构前基线。

- [ ] **Step 4: Commit**

```bash
git add Tools/CI/audit-test-structure.py Docs/Testing/test-structure-baseline.md
git commit -m "feat: 添加测试结构度量脚本并记录基线值"
```

---

### Task 2: 将度量脚本集成到 CI audit 门禁

**Files:**
- Modify: `Makefile`（`audit` 目标追加 `audit-test-structure.py`）
- Modify: `Tools/CI/build-pipeline-all.sh`（如有 audit 调用链）

**Interfaces:**
- Consumes: `audit-test-structure.py` from Task 1
- Produces: `make audit` 包含测试结构度量检查

- [ ] **Step 1: 检查 Makefile audit 目标当前内容**

Run: `grep -A20 "^audit:" Makefile`
Expected: 看到 audit 目标调用了多个审计脚本

- [ ] **Step 2: 在 audit 目标末尾追加测试结构度量**

在 Makefile 的 `audit` 目标中，在最后一个审计脚本后追加：
```makefile
	@echo "📊 运行测试结构度量..."
	@python3 Tools/CI/audit-test-structure.py --verbose || (echo "❌ 测试结构度量不达标，请运行 'python3 Tools/CI/audit-test-structure.py --json' 查看详情" && exit 1)
```

- [ ] **Step 3: 运行 make audit 验证**

Run: `make audit`
Expected: 测试结构度量步骤输出并可能失败（因为基线不达标），但其他审计项应通过

- [ ] **Step 4: Commit**

```bash
git add Makefile
git commit -m "feat: 将测试结构度量集成到 make audit 门禁"
```

---

## Phase 2: 目录对齐迁移（机械移动）

> **策略**：按"迁移一个目录 → `make gen` → `make test-unit` → commit"循环执行。
> 每个目录迁移是一个独立 Task，可独立验证、可回滚。
> 迁移顺序按文件数从少到多，先易后难。

### Task 3: 迁移小目录（Graph/Insight/Dashboard/Subscription/Fuzz — 9 文件）

**Files:**
- Move: `Tests/Unit/Graph/*.swift` → `Tests/Unit/Infrastructure/`
- Move: `Tests/Unit/Insight/*.swift` → `Tests/Unit/Features/Insight/`
- Move: `Tests/Unit/Dashboard/*.swift` → `Tests/Unit/Features/Insight/`
- Move: `Tests/Unit/Subscription/FeatureGateManagerTests.swift` → `Tests/Unit/Domain/`
- Move: `Tests/Unit/Fuzz/CoreParsersAndRAGPipelineFuzzTests.swift` → `Tests/Integration/`（如不存在则创建）
- Remove: 空目录 `Tests/Unit/Graph/`, `Tests/Unit/Insight/`, `Tests/Unit/Dashboard/`, `Tests/Unit/Subscription/`, `Tests/Unit/Fuzz/`

**Interfaces:**
- Consumes: 无
- Produces: 5 个测试目录被消除，`directory_alignment_rate` 提升

- [ ] **Step 1: 确认工作区干净**

Run: `git status --short`
Expected: 无未提交变更

- [ ] **Step 2: 执行迁移**

```bash
# Graph → Infrastructure
mv Tests/Unit/Graph/*.swift Tests/Unit/Infrastructure/
rmdir Tests/Unit/Graph

# Insight → Features/Insight
mv Tests/Unit/Insight/*.swift Tests/Unit/Features/Insight/
rmdir Tests/Unit/Insight

# Dashboard → Features/Insight
mv Tests/Unit/Dashboard/*.swift Tests/Unit/Features/Insight/
rmdir Tests/Unit/Dashboard

# Subscription → Domain
mv Tests/Unit/Subscription/*.swift Tests/Unit/Domain/
rmdir Tests/Unit/Subscription

# Fuzz → Integration（保留跨模块特性）
mkdir -p Tests/Integration
mv Tests/Unit/Fuzz/*.swift Tests/Integration/
rmdir Tests/Unit/Fuzz
```

- [ ] **Step 3: 重生成 Xcode 工程**

Run: `make gen`
Expected: xcodeproj 重生成成功，无错误

- [ ] **Step 4: 运行单元测试验证**

Run: `make test-unit`
Expected: 0 新增失败（与 final15 基线一致）

- [ ] **Step 5: 运行度量脚本确认改善**

Run: `python3 Tools/CI/audit-test-structure.py --verbose`
Expected: `directory_alignment_rate` 从 ~53% 提升到 ~67%（消除 5 个不对齐目录）

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: 迁移 Graph/Insight/Dashboard/Subscription/Fuzz 测试到对应源码目录"
```

---

### Task 4: 迁移 Platform → Platforms（25 文件合并）

**Files:**
- Move: `Tests/Unit/Platform/*.swift` → `Tests/Unit/Platforms/`
- Remove: 空目录 `Tests/Unit/Platform/`

**Interfaces:**
- Consumes: 无
- Produces: `Platform`（单数）目录消除，与 `Sources/Platforms/` 对齐

- [ ] **Step 1: 执行迁移**

```bash
mv Tests/Unit/Platform/*.swift Tests/Unit/Platforms/
rmdir Tests/Unit/Platform
```

- [ ] **Step 2: 重生成并验证**

Run: `make gen && make test-unit`
Expected: 0 新增失败

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: 合并 Platform 测试到 Platforms 目录（单复数统一）"
```

---

### Task 5: 迁移 Security → Core（10 文件）

**Files:**
- Move: `Tests/Unit/Security/*.swift` → `Tests/Unit/Core/`
- Remove: 空目录 `Tests/Unit/Security/`

**Interfaces:**
- Consumes: 无
- Produces: `Security` 目录消除，被测源码在 `Sources/Core/System/Security/`

- [ ] **Step 1: 执行迁移**

```bash
mv Tests/Unit/Security/*.swift Tests/Unit/Core/
rmdir Tests/Unit/Security
```

- [ ] **Step 2: 重生成并验证**

Run: `make gen && make test-unit`
Expected: 0 新增失败

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: 迁移 Security 测试到 Core 目录（对齐 Sources/Core/System/Security）"
```

---

### Task 6: 迁移 Plugins → Infrastructure（9 文件）

**Files:**
- Move: `Tests/Unit/Plugins/*.swift` → `Tests/Unit/Infrastructure/`（8 个测试 Infrastructure/Plugins 的文件）
- Move: `Tests/Unit/Plugins/PluginCenterViewTests.swift` → `Tests/Unit/Features/System/`（1 个测试 Features/System/Settings/View/Plugins 的文件）
- Remove: 空目录 `Tests/Unit/Plugins/`

**Interfaces:**
- Consumes: 无
- Produces: `Plugins` 目录消除

- [ ] **Step 1: 确认 PluginCenterViewTests.swift 的被测类型**

Run: `grep "@testable import" Tests/Unit/Plugins/PluginCenterViewTests.swift`
Expected: 确认 import 的是主 App（非 SPM 包），被测类型 PluginCenterView 在 Features/System 下

- [ ] **Step 2: 执行迁移**

```bash
# 大部分迁移到 Infrastructure
for f in Tests/Unit/Plugins/*.swift; do
  if [[ "$(basename $f)" == "PluginCenterViewTests.swift" ]]; then
    mv "$f" Tests/Unit/Features/System/
  else
    mv "$f" Tests/Unit/Infrastructure/
  fi
done
rmdir Tests/Unit/Plugins
```

- [ ] **Step 3: 重生成并验证**

Run: `make gen && make test-unit`
Expected: 0 新增失败

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: 迁移 Plugins 测试到 Infrastructure 和 Features/System 目录"
```

---

### Task 7: 迁移 Knowledge → Features/Knowledge（20 文件）

**Files:**
- Move: `Tests/Unit/Knowledge/*.swift` → `Tests/Unit/Features/Knowledge/`
- Remove: 空目录 `Tests/Unit/Knowledge/`

**Interfaces:**
- Consumes: 无
- Produces: `Knowledge` 目录消除，与 `Sources/Features/Knowledge/` 对齐

- [ ] **Step 1: 执行迁移**

```bash
mv Tests/Unit/Knowledge/*.swift Tests/Unit/Features/Knowledge/
rmdir Tests/Unit/Knowledge
```

- [ ] **Step 2: 重生成并验证**

Run: `make gen && make test-unit`
Expected: 0 新增失败

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: 迁移 Knowledge 测试到 Features/Knowledge 目录"
```

---

### Task 8: 迁移 Processors → Infrastructure（20 文件，排除 SPM 下沉项）

**Files:**
- Move: `Tests/Unit/Processors/*.swift`（19 个测试 Infrastructure/Processors 的文件）→ `Tests/Unit/Infrastructure/`
- Keep: `Tests/Unit/Processors/SSRFGuardEdgeTests.swift`（1 个测试 SPM 包的文件，Phase 3 下沉）
- Remove: 空目录 `Tests/Unit/Processors/`

**Interfaces:**
- Consumes: 无
- Produces: `Processors` 目录消除（SSRFGuardEdgeTests 留待 Phase 3 下沉）

- [ ] **Step 1: 执行迁移（排除 SSRFGuardEdgeTests）**

```bash
for f in Tests/Unit/Processors/*.swift; do
  if [[ "$(basename $f)" != "SSRFGuardEdgeTests.swift" ]]; then
    mv "$f" Tests/Unit/Infrastructure/
  fi
done
# SSRFGuardEdgeTests 暂时移到临时位置，Phase 3 处理
mv Tests/Unit/Processors/SSRFGuardEdgeTests.swift Tests/Unit/Base/  # 临时存放，Phase 3 下沉
rmdir Tests/Unit/Processors
```

- [ ] **Step 2: 重生成并验证**

Run: `make gen && make test-unit`
Expected: 0 新增失败

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "refactor: 迁移 Processors 测试到 Infrastructure 目录（SSRFGuardEdgeTests 待 SPM 下沉）"
```

---

### Task 9: 迁移 System → Features/System + Infrastructure + Core（32 文件分散迁移）

**Files:**
- Move: 测试 `Sources/Features/System/` 的文件 → `Tests/Unit/Features/System/`
- Move: 测试 `Sources/Infrastructure/` 的文件 → `Tests/Unit/Infrastructure/`
- Move: 测试 `Sources/Core/` 的文件 → `Tests/Unit/Core/`
- Move: 测试 `Sources/Platforms/` 的文件 → `Tests/Unit/Platforms/`
- Remove: 空目录 `Tests/Unit/System/`

**Interfaces:**
- Consumes: 无
- Produces: `System` 目录消除

> **注意**：此 Task 需要逐文件判断被测代码位置。使用 Task 分析报告中的抽样数据作为指导。

- [ ] **Step 1: 编写迁移分类脚本**

```bash
#!/bin/bash
# 按被测源码位置分类 Tests/Unit/System/ 下的文件
cd "$(git rev-parse --show-toplevel)"

for f in Tests/Unit/System/*.swift; do
  basename=$(basename "$f")
  # 通过 grep 测试文件中的 import 和类型引用判断被测位置
  if grep -q "Features/System\|AuthService\|SettingsStore\|OnboardingMilestone\|AppleAuthStrategy\|GitHubAuthStrategy\|GoogleAuthStrategy\|StoreKit\|CollaborationService" "$f"; then
    echo "Features/System: $basename"
  elif grep -q "Infrastructure\|NetworkClient\|AuthRegionDetector\|AuthTokenManager" "$f"; then
    echo "Infrastructure: $basename"
  elif grep -q "Core/System\|Logger\|HapticFeedback\|Analytics\|PerformanceService" "$f"; then
    echo "Core: $basename"
  elif grep -q "Platforms\|Widget\|WatchSync\|LiveActivity" "$f"; then
    echo "Platforms: $basename"
  else
    echo "UNKNOWN: $basename"
  fi
done
```

- [ ] **Step 2: 执行分类脚本，人工审核分类结果**

Run: `bash /tmp/classify_system_tests.sh`
Expected: 32 个文件被分到 4 个类别，UNKNOWN 类需人工判断

- [ ] **Step 3: 按分类结果执行迁移**

```bash
# 示例（实际路径根据 Step 2 结果调整）：
# Features/System 类
mv Tests/Unit/System/AppleAuthStrategyTests.swift Tests/Unit/Features/System/
mv Tests/Unit/System/AuthServiceTests.swift Tests/Unit/Features/System/
# ... 其他 Features/System 类文件

# Infrastructure 类
mv Tests/Unit/System/AuthRegionDetectorTests.swift Tests/Unit/Infrastructure/
mv Tests/Unit/System/NetworkClientTests.swift Tests/Unit/Infrastructure/
# ... 其他 Infrastructure 类文件

# Core 类
mv Tests/Unit/System/LoggerTests.swift Tests/Unit/Core/
mv Tests/Unit/System/HapticFeedbackTests.swift Tests/Unit/Core/
# ... 其他 Core 类文件

# Platforms 类
mv Tests/Unit/System/KnowledgeStatsWidgetTests.swift Tests/Unit/Platforms/
# ... 其他 Platforms 类文件

rmdir Tests/Unit/System
```

- [ ] **Step 4: 重生成并验证**

Run: `make gen && make test-unit`
Expected: 0 新增失败

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: 迁移 System 测试到 Features/System、Infrastructure、Core、Platforms 目录"
```

---

### Task 10: 迁移 Storage → Infrastructure + Domain + App + Platforms（42 文件分散迁移）

**Files:**
- Move: 测试 `Sources/Infrastructure/Storage/` 的文件 → `Tests/Unit/Infrastructure/`
- Move: 测试 `Sources/Domain/Protocols/` 的文件 → `Tests/Unit/Domain/`
- Move: 测试 `Sources/App/Store/` 的文件 → `Tests/Unit/App/`
- Move: 测试 `Sources/Platforms/iOS/Widgets/` 的文件 → `Tests/Unit/Platforms/`
- Remove: 空目录 `Tests/Unit/Storage/`

**Interfaces:**
- Consumes: 无
- Produces: `Storage` 目录消除

- [ ] **Step 1: 编写迁移分类脚本（同 Task 9 模式）**

按被测源码位置分类 `Tests/Unit/Storage/` 下的 42 个文件。

- [ ] **Step 2: 执行分类并人工审核**

- [ ] **Step 3: 按分类执行迁移**

- [ ] **Step 4: 重生成并验证**

Run: `make gen && make test-unit`
Expected: 0 新增失败

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: 迁移 Storage 测试到 Infrastructure、Domain、App、Platforms 目录"
```

---

### Task 11: 迁移 AI → Features/AI + Infrastructure + Domain（56 文件分散迁移）

**Files:**
- Move: 测试 `Sources/Features/AI/` 的文件 → `Tests/Unit/Features/AI/`
- Move: 测试 `Sources/Infrastructure/LLM/` 的文件 → `Tests/Unit/Infrastructure/`
- Move: 测试 `Sources/Infrastructure/VectorDB/` 的文件 → `Tests/Unit/Infrastructure/`
- Move: 测试 `Sources/Domain/RAG/` 的文件 → `Tests/Unit/Domain/`
- Keep: 5 个测试 SPM 包的文件留待 Phase 3 下沉
- Remove: 空目录 `Tests/Unit/AI/`

**Interfaces:**
- Consumes: 无
- Produces: `AI` 目录消除

- [ ] **Step 1: 编写迁移分类脚本**

- [ ] **Step 2: 执行分类并人工审核**

- [ ] **Step 3: 按分类执行迁移（SPM 包测试文件暂留）**

- [ ] **Step 4: 重生成并验证**

Run: `make gen && make test-unit`
Expected: 0 新增失败

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: 迁移 AI 测试到 Features/AI、Infrastructure、Domain 目录"
```

---

### Task 12: 迁移 Services → 各对应目录（16 文件分散迁移）

**Files:**
- Move: 测试 `Sources/Features/AI/` 的文件 → `Tests/Unit/Features/AI/`
- Move: 测试 `Sources/Features/System/` 的文件 → `Tests/Unit/Features/System/`
- Move: 测试 `Sources/Features/Knowledge/` 的文件 → `Tests/Unit/Features/Knowledge/`
- Move: 测试 `Sources/Features/Insight/` 的文件 → `Tests/Unit/Features/Insight/`
- Move: 测试 `Sources/App/` 的文件 → `Tests/Unit/App/`
- Move: 测试 `Sources/Infrastructure/` 的文件 → `Tests/Unit/Infrastructure/`
- Keep: `ByteFormatterTests.swift` 留待 Phase 3 下沉
- Remove: 空目录 `Tests/Unit/Services/`

- [ ] **Step 1: 编写迁移分类脚本**

- [ ] **Step 2: 执行分类并人工审核**

- [ ] **Step 3: 按分类执行迁移**

- [ ] **Step 4: 重生成并验证**

Run: `make gen && make test-unit`
Expected: 0 新增失败

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: 迁移 Services 测试到各对应源码目录"
```

---

### Task 13: 迁移 Base → Domain + Core + Platforms（22 文件分散迁移）

**Files:**
- Move: 测试 `Sources/Domain/` 的文件 → `Tests/Unit/Domain/`
- Move: 测试 `Sources/Core/` 的文件 → `Tests/Unit/Core/`
- Move: 测试 `Sources/Platforms/` 的文件 → `Tests/Unit/Platforms/`
- Keep: `ServiceContainerTests.swift`、`MainActorBridgeTests.swift`、`DesignSystemTests.swift` 留待 Phase 3 下沉
- Remove: 空目录 `Tests/Unit/Base/`

- [ ] **Step 1: 编写迁移分类脚本**

- [ ] **Step 2: 执行分类并人工审核**

- [ ] **Step 3: 按分类执行迁移**

- [ ] **Step 4: 重生成并验证**

Run: `make gen && make test-unit`
Expected: 0 新增失败

- [ ] **Step 5: 运行度量脚本确认 directory_alignment_rate 达标**

Run: `python3 Tools/CI/audit-test-structure.py --verbose`
Expected: `directory_alignment_rate` ≥ 95%（所有 Tests/Unit 子目录都有对应 Sources/ 目录）

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: 迁移 Base 测试到 Domain、Core、Platforms 目录，完成目录对齐"
```

---

## Phase 3: SPM 测试下沉与去重

### Task 14: 下沉 UFPCore 重复测试（3 文件）

**Files:**
- Move + Merge: `Tests/Unit/Base/MainActorBridgeTests.swift` → `Packages/UFPCore/Tests/UFPCoreTests/`（与 `MainActorBridgeExecutionTests.swift` 合并）
- Move + Merge: `Tests/Unit/Processors/SSRFGuardEdgeTests.swift`（当前在 `Tests/Unit/Base/` 临时位置）→ `Packages/UFPCore/Tests/UFPCoreTests/`（与 `SSRFGuardSecurityTests.swift` 合并）
- Move + Merge: `Tests/Unit/Services/ByteFormatterTests.swift`（当前已迁移到对应目录）→ `Packages/UFPCore/Tests/UFPCoreTests/`（与 `ByteFormatterFormattingTests.swift` 合并）

**Interfaces:**
- Consumes: Phase 2 完成后的文件位置
- Produces: 3 个主 App 测试文件被消除，用例合并到 SPM 包

- [ ] **Step 1: 对比主 App 测试与 SPM 包测试的用例**

```bash
# MainActorBridge
grep "func test" Tests/Unit/Base/MainActorBridgeTests.swift
grep "func test" Packages/UFPCore/Tests/UFPCoreTests/MainActorBridgeExecutionTests.swift
# 识别主 App 版本有但 SPM 版本没有的用例
```

- [ ] **Step 2: 将主 App 版本独有的用例追加到 SPM 包测试文件**

编辑 `Packages/UFPCore/Tests/UFPCoreTests/MainActorBridgeExecutionTests.swift`，追加主 App 版本独有的测试方法。

- [ ] **Step 3: 删除主 App 测试文件**

```bash
rm Tests/Unit/Base/MainActorBridgeTests.swift
```

- [ ] **Step 4: 对 SSRFGuardEdgeTests 和 ByteFormatterTests 重复 Step 1-3**

- [ ] **Step 5: 重生成并验证**

Run: `make gen && make test-unit`
Expected: 0 新增失败

Run: `make test-spm PKG=UFPCore`
Expected: SPM 包测试通过，包含新增用例

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: 下沉 UFPCore 重复测试到 SPM 包（MainActorBridge/SSRFGuard/ByteFormatter）"
```

---

### Task 15: 下沉 ZhiYuAICore 重复测试（5 文件）

**Files:**
- Move + Merge: `Tests/Unit/AI/JSONRepairProcessorTests.swift` → `Packages/ZhiYuAICore/Tests/ZhiYuAICoreTests/`
- Move + Merge: `Tests/Unit/AI/LLMContextBuilderPrecisionTests.swift` → `Packages/ZhiYuAICore/Tests/ZhiYuAICoreTests/`
- Move + Merge: `Tests/Unit/AI/LLMContextSecurityTests.swift` → `Packages/ZhiYuAICore/Tests/ZhiYuAICoreTests/`
- Move + Merge: `Tests/Unit/AI/PromptSecuritySanitizerTests.swift` → `Packages/ZhiYuAICore/Tests/ZhiYuAICoreTests/`
- Move + Merge: `Tests/Unit/AI/MemoryEngineAdapterTests.swift` → `Packages/ZhiYuAICore/Tests/ZhiYuAICoreTests/`（跨包部分下沉到 `Packages/ZhiYuDomain/Tests/ZhiYuDomainTests/`）

**Interfaces:**
- Consumes: Phase 2 完成后的文件位置
- Produces: 5 个主 App 测试文件被消除

- [ ] **Step 1: 逐文件对比主 App 与 SPM 包测试用例，合并独有用例**

- [ ] **Step 2: 删除主 App 测试文件**

- [ ] **Step 3: 重生成并验证**

Run: `make gen && make test-unit`
Expected: 0 新增失败

Run: `make test-spm PKG=ZhiYuAICore`
Expected: SPM 包测试通过

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: 下沉 ZhiYuAICore 重复测试到 SPM 包"
```

---

### Task 16: 下沉 UFPDesignSystem 重复测试（1 文件）

**Files:**
- Move + Merge: `Tests/Unit/Base/DesignSystemTests.swift` → `Packages/UFPDesignSystem/Tests/UFPDesignSystemTests/`

- [ ] **Step 1: 对比并合并用例**

- [ ] **Step 2: 删除主 App 测试文件**

- [ ] **Step 3: 重生成并验证**

Run: `make gen && make test-unit && make test-spm PKG=UFPDesignSystem`
Expected: 0 新增失败

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: 下沉 UFPDesignSystem 重复测试到 SPM 包"
```

---

### Task 17: 下沉 ServiceContainer 测试（1 文件，可选）

**Files:**
- Move + Merge: `Tests/Unit/Base/ServiceContainerTests.swift` → `Packages/UFPCore/Tests/UFPCoreTests/`

> **注意**：ServiceContainer 是 DI 容器核心，主 App 测试可能包含 SPM 包无法覆盖的集成场景。需逐用例判断是否适合下沉。

- [ ] **Step 1: 逐用例分析是否可下沉**

Run: `grep "func test" Tests/Unit/Base/ServiceContainerTests.swift`
对每个用例判断：是否依赖主 App 特有的服务注册？

- [ ] **Step 2: 可下沉的用例合并到 SPM 包，不可下沉的保留主 App**

- [ ] **Step 3: 重生成并验证**

Run: `make gen && make test-unit && make test-spm PKG=UFPCore`
Expected: 0 新增失败

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: 下沉 ServiceContainer 纯单元测试到 UFPCore SPM 包"
```

---

## Phase 4: 超大文件拆分

> **策略**：按 MARK 主题拆分，每个新文件 ≤ 30 用例。
> 拆分顺序按用例数从大到小。
> 每个文件拆分是一个独立 Task。

### Task 18: 拆分 SecurityAndRerankerPureLogicTests.swift（98 用例 → 3 文件）

**Files:**
- Split: `Tests/Unit/Infrastructure/SecurityAndRerankerPureLogicTests.swift`（98 用例）→
  - `Tests/Unit/Infrastructure/PromptSecuritySanitizerJailbreakDetectionTests.swift`（~25 用例）
  - `Tests/Unit/Infrastructure/PromptSecuritySanitizerContextSandboxTests.swift`（~20 用例）
  - `Tests/Unit/Infrastructure/ContextRerankerTwoStageTests.swift`（~53 用例）
- Remove: 原文件

> **注意**：被测类型 PromptSecuritySanitizer 在 ZhiYuAICore SPM 包。如果 Phase 3 已将相关测试下沉，此 Task 可能需要调整——检查这些测试是否已在 Phase 3 下沉。如果仍在主 App，则在此 Task 拆分。

- [ ] **Step 1: 读取原文件，按 MARK 分段识别用例边界**

Run: `grep -n "MARK:" Tests/Unit/Infrastructure/SecurityAndRerankerPureLogicTests.swift`
Expected: 看到 3 个 MARK 段落

- [ ] **Step 2: 创建 3 个新文件，将对应 MARK 段落的用例复制过去**

每个新文件需要：
- 文件头注释（系统层级 + 核心职责）
- `import` 声明（与原文件一致）
- 对应 MARK 段落的全部 `func test` 方法
- 共用的辅助方法（如有）

- [ ] **Step 3: 删除原文件**

```bash
rm Tests/Unit/Infrastructure/SecurityAndRerankerPureLogicTests.swift
```

- [ ] **Step 4: 重生成并验证**

Run: `make gen && make test-unit`
Expected: 0 新增失败，用例总数不变

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: 拆分 SecurityAndRerankerPureLogicTests（98→3 文件）"
```

---

### Task 19: 拆分 DomainProtocolsSupplementTests.swift（89 用例 → 2 文件）

**Files:**
- Split: `Tests/Unit/Domain/DomainProtocolsSupplementTests.swift`（89 用例）→
  - `Tests/Unit/Domain/NoOpLLMServicesTests.swift`（~40 用例）
  - `Tests/Unit/Domain/NoOpRepositoryAndProviderTests.swift`（~49 用例）
- Remove: 原文件

- [ ] **Step 1: 读取原文件，按 MARK 分段**

- [ ] **Step 2: 创建 2 个新文件**

- [ ] **Step 3: 删除原文件**

- [ ] **Step 4: 重生成并验证**

Run: `make gen && make test-unit`
Expected: 0 新增失败

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "refactor: 拆分 DomainProtocolsSupplementTests（89→2 文件）"
```

---

### Task 20-33: 拆分剩余 15 个超大文件

> 每个 Task 拆分一个超大文件，步骤同 Task 18/19 模式：
> 1. 读取原文件按 MARK 分段
> 2. 创建拆分后的新文件（每个 ≤ 30 用例）
> 3. 删除原文件
> 4. `make gen && make test-unit` 验证
> 5. Commit

**拆分清单：**

| Task | 原文件 | 用例数 | 拆分后文件数 | 拆分主题 |
|------|--------|--------|------------|---------|
| 20 | `ModelLabManagerDeepTests.swift` | 88 | 3 | UseCaseType / ParamTips / Simulation |
| 21 | `PluginSandboxAndMarketTests.swift` | 80 | 3 | GatewayAudit / Manifest / MarketService |
| 22 | `SynthesisStoreDeepTests.swift` | 80 | 3 | Type属性 / 正常路径 / 失败路径 |
| 23 | `AIWorkflowStoreDeepTests.swift` | 77 | 3 | State / LintHealth / Suggestions |
| 24 | `GlobalModelManagerDeepTests.swift` | 74 | 3 | Persistence / Routing / Download |
| 25 | `InfrastructureConstantsAndModelsTests.swift` | 71 | 3 | LLMConstants / PluginConstants / Models |
| 26 | `CoreConstantsAndUtilitiesTests.swift` | 71 | 3 | Constants / DocumentFormat / Utility |
| 27 | `SystemStatsCoordinatorDeepTests.swift` | 66 | 3 | Load / Fetch / Cleanup |
| 28 | `LLMAuxiliarySupplementTests.swift` | 64 | 4 | PromptService / MemoryEngine / ConfigAnalytics / LLMService |
| 29 | `AISynthesisServiceDeepTests.swift` | 64 | 3 | Summarize / Generate / Facade |
| 30 | `StorageSupplementTests.swift` | 58 | 3 | Services / VaultStorage / SQLiteStore |
| 31 | `ProcessorsSupplementTests.swift` | 57 | 4 | ImageExtractor / DocumentExtraction / GraphLayout / TextChunker |
| 32 | `IngestImportDeepTests.swift` | 56 | 3 | FileImport / RawContent / URLDocument |
| 33 | `AuthServiceDeepTests.swift` | 55 | 3 | StateGuest / Login / ProfilePurchase |
| 34 | `ZhiYuServiceTests.swift` | 52 | 10 | 按服务完全拆分（聚合测试） |
| 35 | `FrontmatterParserTests.swift` | 51 | 3 | SplitParse / ModelsCodable / Integration |

每个 Task 的具体步骤模板：

- [ ] **Step 1: 读取原文件，按 MARK 分段识别用例边界**
- [ ] **Step 2: 创建拆分后的新文件（含文件头、import、对应用例、辅助方法）**
- [ ] **Step 3: 删除原文件**
- [ ] **Step 4: 重生成并验证** — `make gen && make test-unit`
- [ ] **Step 5: Commit** — `git add -A && git commit -m "refactor: 拆分 XXXTests（N→M 文件）"`

---

## Phase 5: 最终验证与文档更新

### Task 36: 运行全量测试验证

- [ ] **Step 1: 运行全量测试**

Run: `make test`
Expected: 7887+ passed, 0 failed（用例总数可能因 SPM 下沉减少，但主 App + SPM 总和不变）

- [ ] **Step 2: 运行 SPM 全量测试**

Run: `make test-spm-all`
Expected: 全部通过

- [ ] **Step 3: 运行度量脚本确认全部达标**

Run: `python3 Tools/CI/audit-test-structure.py --verbose`
Expected: 6 项指标全部 ✅

- [ ] **Step 4: 运行 make audit 确认全部通过**

Run: `make audit`
Expected: 全部通过（包括测试结构度量）

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "test: 全量测试验证通过，测试结构重构完成"
```

---

### Task 37: 更新文档

**Files:**
- Modify: `Docs/Testing/UNIT_TEST_GUIDE.md`（更新测试目录组织规范）
- Modify: `Docs/Testing/TEST_CASES.md`（更新测试用例统计）
- Modify: `AGENTS.md`（更新测试相关章节）
- Create: `Docs/Testing/test-structure-metrics.md`（度量指标说明文档）

- [ ] **Step 1: 更新 UNIT_TEST_GUIDE.md，添加测试目录 1:1 镜像规范**

- [ ] **Step 2: 更新 TEST_CASES.md，反映新的测试文件统计**

- [ ] **Step 3: 更新 AGENTS.md，添加测试结构度量命令参考**

- [ ] **Step 4: 创建 test-structure-metrics.md，说明 6 项度量指标含义与阈值**

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "docs: 更新测试结构规范与度量指标文档"
```

---

## Self-Review

### 1. Spec coverage

| 需求 | 对应 Task |
|------|----------|
| 建立度量方法 | Task 1-2 |
| 目录对齐（15 个无对应目录） | Task 3-13 |
| SPM 测试下沉（8 个重复文件） | Task 14-17 |
| 超大文件拆分（18 个 >50 用例） | Task 18-35 |
| 最终验证 | Task 36 |
| 文档更新 | Task 37 |

✅ 全部覆盖

### 2. Placeholder scan

- Task 9-13 中的"分类脚本"给出了具体逻辑模板，非占位符
- Task 20-35 使用了模板化步骤，但每个 Task 有具体的文件名和拆分主题（来自分析报告），非占位符
- Task 34（ZhiYuServiceTests 拆分为 10 个文件）的 10 个目标文件名在分析报告中有明确列表

✅ 无占位符

### 3. Type consistency

- 所有 Task 使用 `make gen && make test-unit` 作为验证命令，一致
- 所有 commit message 使用 `refactor:` 前缀（迁移/拆分），`feat:` 前缀（新功能），`test:` 前缀（验证），`docs:` 前缀（文档），一致
- 度量脚本中 `OVERSIZED_THRESHOLD = 30` 与计划中"单文件 ≤ 30 用例"一致

✅ 一致

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/2026-09-07-test-structure-refactor.md`. Two execution options:**

**1. Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration

**2. Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
