#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# NAMING-bypass: 本脚本包含旧路径模式字符串作为检测规则，豁免自身正确性扫描
# ==============================================================================
# 脚本名称: Tools/scripts/check-quality-script-refs.py
# 脚本功能: 全量检查所有源文件中的脚本引用健康度：
#   1. [存在性] 引用的脚本路径必须真实存在
#   2. [正确性] 引用路径必须使用新规范（无旧目录名、无旧命名前缀）
#   3. [注释一致性] 脚本头"脚本名称:"字段必须与实际文件名一致
#
# 扫描范围（全量）：
#   - Tools/{ios,ci,scripts,docs}/*.sh/*.py   脚本本身
#   - Makefile                                  构建入口
#   - .gitlab-ci.yml                            CI 主入口
#   - .gitlab/ci/*.yml                          分阶段 CI 配置
#   - .git/hooks/*                              Git hooks
#   - ZhiYu.xcodeproj/project.pbxproj          Xcode Build Phase
#   - Docs/**/*.md                              架构/设计文档代码块
# ==============================================================================

import os
import re
import sys
from pathlib import Path

WORKSPACE   = Path(__file__).resolve().parents[2]
TOOLS       = WORKSPACE / "Tools"
DOMAIN_DIRS = ["ios", "ci", "scripts", "docs"]
SCRIPT_EXTS = {".sh", ".py"}

EXEMPT_NAMES = {"ci-common-shared.sh", "check_duplicate_code.py"}
EXEMPT_PATH_PREFIXES = (
    "Tools/Mock/", "Tools/Plugins/Local/",
    "Tools/Plugins/Remote/", "Tools/Plugins/smart-cleaner",
)

OLD_DIR_COMPONENTS = re.compile(
    r"Tools/Gatekeeper/"
    r"|Tools/CI/"
    r"|Tools/Utils/"
    r"|Tools/Plugins/ios-"
    r"|Tests/Integration/ci-"
    r"|Tests/Unit/CI/ci-"
    r"|/CI/(?:ci-)?"
    r"|/Utils/(?:scripts-)?"
)

OLD_NAME_PREFIX = re.compile(
    r"(?:^|/)(?:"
    r"ios-|ci-assert-|ci-audit-|ci-check-|ci-run-|ci-build-|ci-generate-"
    r"|scripts-assert-|scripts-run-|scripts-check-|scripts-audit-|scripts-calc-"
    r"|docs-check-"
    r"|run_all_gatekeeper"
    r")[\w.-]+\.(?:sh|py)$"
)

PATH_EXTRACT = re.compile(
    r"(?:Tools/[\w/.-]+"
    r"|\$\(dirname[^)]*\)/[\w/.-]+"
    r"|(?:\.\./|\./[\w/.-]+)"
    r")"
    r"\.(?:sh|py)"
)

NON_EXEC_RE = re.compile(
    r"^\s*(?:#|echo\b|printf\b|log\b|LOG\b|info\b|warn\b|//\s)"
)
DATA_LINE_RE = re.compile(r"""^\s*["'][\w/.-]+\.(?:sh|py)["']""")

SCRIPT_NAME_COMMENT = re.compile(r"#\s*脚本名称:\s*(.+)")
BRIEF_NAME_COMMENT  = re.compile(r"^#\s{1,3}([\w.-]+\.(?:sh|py))\s*$")


def skip_line(line: str) -> bool:
    s = line.strip()
    return (not s or s.startswith("#")
            or bool(NON_EXEC_RE.match(line))
            or bool(DATA_LINE_RE.match(line)))


def skip_line_loose(line: str) -> bool:
    """宽松版：用于 Markdown/pbxproj，只跳过空行"""
    return not line.strip()


def read_head(fpath: Path, n: int = 12) -> str:
    try:
        lines = []
        with open(fpath, encoding="utf-8", errors="ignore") as f:
            for _ in range(n):
                ln = f.readline()
                if not ln: break
                lines.append(ln)
        return "".join(lines)
    except Exception:
        return ""


def read_full(fpath: Path) -> str:
    try:
        return fpath.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return ""


def has_bypass(fpath: Path) -> bool:
    return "NAMING-bypass" in read_head(fpath, 12)


def resolve_path(raw: str, source_file: Path):
    if raw.startswith("$(dirname"):
        suffix = re.sub(r"^\$\(dirname[^)]*\)/", "", raw)
        return source_file.parent / suffix
    # YAML CI 文件中 ./ 路径从项目根解析（GitLab CI 惯例）
    is_yaml = source_file.suffix in (".yml", ".yaml")
    if raw.startswith("./") and is_yaml:
        return WORKSPACE / raw[2:]
    if raw.startswith("Tools/"):
        return WORKSPACE / raw
    if raw.startswith("../") or raw.startswith("./"):
        return (source_file.parent / raw).resolve()
    return None


def collect_sources() -> dict[str, list[Path]]:
    """收集所有需要扫描的文件，按类型分组"""
    sources: dict[str, list[Path]] = {
        "脚本":    [],
        "CI配置":  [],
        "Git钩子": [],
        "Xcode":   [],
        "文档":    [],
    }

    # 脚本
    for d in DOMAIN_DIRS:
        dp = TOOLS / d
        if dp.is_dir():
            for f in dp.iterdir():
                if f.suffix in SCRIPT_EXTS:
                    sources["脚本"].append(f)

    # CI 配置
    for p in [WORKSPACE / "Makefile", WORKSPACE / ".gitlab-ci.yml"]:
        if p.is_file():
            sources["CI配置"].append(p)
    ci_dir = WORKSPACE / ".gitlab" / "ci"
    if ci_dir.is_dir():
        sources["CI配置"].extend(sorted(ci_dir.glob("*.yml")))

    # Git hooks
    hooks_dir = WORKSPACE / ".git" / "hooks"
    if hooks_dir.is_dir():
        for h in hooks_dir.iterdir():
            if h.is_file() and not h.name.endswith(".sample"):
                sources["Git钩子"].append(h)

    # Xcode pbxproj
    pbxproj = WORKSPACE / "ZhiYu.xcodeproj" / "project.pbxproj"
    if pbxproj.is_file():
        sources["Xcode"].append(pbxproj)

    # Docs markdown
    docs_dir = WORKSPACE / "Docs"
    if docs_dir.is_dir():
        sources["文档"].extend(sorted(docs_dir.rglob("*.md")))

    return sources


def check_file(source: Path, content: str,
               loose: bool = False) -> tuple[list[str], list[str]]:
    """返回 (existence_issues, correctness_issues)"""
    ev, cv = [], []
    skip = skip_line_loose if loose else skip_line
    rel  = source.relative_to(WORKSPACE)

    for i, line in enumerate(content.splitlines(), 1):
        if skip(line):
            continue
        for raw in PATH_EXTRACT.findall(line):
            fname = Path(raw).name
            if fname in EXEMPT_NAMES:
                continue
            if any(raw.startswith(p) for p in EXEMPT_PATH_PREFIXES):
                continue

            # 存在性
            abs_path = resolve_path(raw, source)
            if abs_path and not abs_path.exists():
                ev.append(
                    f"  [存在性] {rel}:{i}\n"
                    f"    引用不存在: {raw}\n"
                    f"    行内容: {line.strip()[:90]}"
                )

            # 正确性
            m = OLD_DIR_COMPONENTS.search(raw)
            if m:
                cv.append(
                    f"  [正确性/旧目录] {rel}:{i}\n"
                    f"    旧路径片段: '{m.group(0)}'\n"
                    f"    行内容: {line.strip()[:90]}"
                )
            m2 = OLD_NAME_PREFIX.search(raw)
            if m2:
                cv.append(
                    f"  [正确性/旧名称] {rel}:{i}\n"
                    f"    旧前缀文件名: '{Path(raw).name}'\n"
                    f"    行内容: {line.strip()[:90]}"
                )
    return ev, cv


def check_comment(script: Path, head: str) -> list[str]:
    issues = []
    actual = script.name
    m = SCRIPT_NAME_COMMENT.search(head)
    if m:
        declared_base = m.group(1).strip().split("/")[-1]
        if declared_base != actual:
            issues.append(
                f"  [注释/脚本名称] {script.relative_to(WORKSPACE)}\n"
                f"    注释: '{declared_base}'  实际: '{actual}'"
            )
    for m2 in BRIEF_NAME_COMMENT.finditer(head):
        declared = m2.group(1)
        if declared != actual and any(
            declared.startswith(p)
            for p in ("ios-", "ci-", "scripts-", "docs-")
        ):
            issues.append(
                f"  [注释/文件名行] {script.relative_to(WORKSPACE)}\n"
                f"    注释: '#  {declared}'  应为: '#  {actual}'"
            )
            break
    return issues


def main() -> int:
    print("=== ZhiYu 脚本引用全量健康度检查 ===\n")
    sources = collect_sources()

    all_ev, all_cv, all_ov = [], [], []
    total_files = 0

    for category, files in sources.items():
        if not files:
            continue
        cat_ev, cat_cv = [], []
        for f in sorted(files):
            total_files += 1
            content = read_full(f)
            # 脚本：精确跳过 echo/注释行；文档/Xcode：宽松模式（保留注释中的路径检测）
            loose = category in ("文档", "Xcode")
            if category == "脚本" and has_bypass(f):
                # 仅检查注释一致性
                all_ov += check_comment(f, read_head(f))
                continue
            ev, cv = check_file(f, content, loose=loose)
            cat_ev += ev
            cat_cv += cv
            if category == "脚本":
                all_ov += check_comment(f, read_head(f))

        if cat_ev or cat_cv:
            print(f"[{category}] {len(files)} 个文件 → {len(cat_ev)} 存在性, {len(cat_cv)} 正确性违规")
        else:
            print(f"[{category}] {len(files)} 个文件 ✅")
        all_ev += cat_ev
        all_cv += cat_cv

    print()

    def section(title, items):
        if items:
            print(f"── {title}（{len(items)} 处）──")
            for v in items:
                print(v)
            print()

    section("引用存在性违规", all_ev)
    section("引用正确性违规（旧目录/旧名称）", all_cv)
    section("注释一致性违规", all_ov)

    total = len(all_ev) + len(all_cv) + len(all_ov)
    if total == 0:
        print(f"✅ 全量扫描通过：{total_files} 个文件，0 违规\n")
        return 0
    print(f"❌ 共 {total} 处违规（存在性:{len(all_ev)} / 正确性:{len(all_cv)} / 注释:{len(all_ov)}）")
    return 1


if __name__ == "__main__":
    sys.exit(main())
