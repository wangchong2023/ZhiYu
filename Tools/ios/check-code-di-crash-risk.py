# -*- coding: utf-8 -*-
"""检查 DI 容器提前访问风险：存储属性初始化器中调用 resolve()（非 resolveOptional）。

模式说明：
- `= ServiceContainer.shared.resolve(` → CRITICAL：对象创建时立即执行，DI 未就绪则崩溃
- `ServiceContainer.shared.resolveOptional(` → 安全：返回 nil 优雅降级
- 方法体内的 `resolve()` → 安全：按需调用时 DI 已就绪（除 init 内需人工审查）

退出码: 0=通过, 非0=发现问题
"""

import re
import sys
from pathlib import Path

# ── 常量 ──
SEPARATOR_WIDTH = 72
TRUNCATE_LINE_LENGTH = 120
MAX_COMPLEXITY = 10
SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent.parent.parent
SOURCES_DIR = PROJECT_ROOT / "Sources"


def _is_in_function_context(lines: list[str], line_index: int) -> bool:
    """检测指定行是否在函数体内（缩进块中）。"""
    indent = len(lines[line_index]) - len(lines[line_index].lstrip())
    for i in range(line_index - 1, -1, -1):
        stripped = lines[i].strip()
        if not stripped or stripped.startswith("//"):
            continue
        prev_indent = len(lines[i]) - len(lines[i].lstrip())
        if prev_indent < indent and re.search(r"\bfunc\s+\w+", stripped):
            return True
        if prev_indent < indent and stripped == "}":
            break
    return False


def _is_dangerous_line(stripped: str) -> bool:
    """判断一行是否包含危险的 resolve() 存储属性模式。"""
    if re.search(r"(let|var)\s+\w+.*=.*resolve\(", stripped):
        return True
    if "= {" in stripped:
        return True
    if re.search(r"=\s*ServiceContainer\.shared\.resolve\(", stripped):
        return True
    return False


def _check_file(file_path: Path) -> list[tuple[int, str]]:
    """扫描单个 Swift 文件中危险的 resolve() 调用，返回 (行号, 内容) 列表。"""
    findings = []
    try:
        lines = file_path.read_text().splitlines()
        for i, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith("//") or stripped.startswith("*"):
                continue
            if "resolveOptional" in stripped:
                continue
            if "ServiceContainer.shared.resolve(" not in stripped:
                continue
            if _is_in_function_context(lines, i):
                continue
            if _is_dangerous_line(stripped):
                findings.append((i + 1, stripped))
    except Exception as exc:
        print(f"Error reading {file_path}: {exc}")
    return findings


def _print_findings(all_findings: dict[str, list[tuple[int, str]]]) -> None:
    """格式化输出所有发现的风险点。"""
    total = sum(len(v) for v in all_findings.values())
    print("=" * SEPARATOR_WIDTH)
    print("⚠️  DI Crash Risk: stored-property resolve() without resolveOptional")
    print("   这些代码在对象创建时立即执行，若 DI 未就绪则崩溃。")
    print("   请改用 resolveOptional() + guard/fallback 模式。")
    print("=" * SEPARATOR_WIDTH)
    for file_path, entries in all_findings.items():
        print(f"\n📄 {file_path}")
        for lineno, content in entries:
            trunc = content.strip()[:TRUNCATE_LINE_LENGTH]
            print(f"   L{lineno}: {trunc}")
    print(f"\n共发现 {total} 处风险。")


def main():
    """主入口。"""
    if not SOURCES_DIR.exists():
        print(f"Sources dir not found: {SOURCES_DIR}")
        return 0

    all_findings: dict[str, list[tuple[int, int]]] = {}
    for swift_file in SOURCES_DIR.rglob("*.swift"):
        findings = _check_file(swift_file)
        if findings:
            all_findings[str(swift_file.relative_to(PROJECT_ROOT))] = findings

    if all_findings:
        _print_findings(all_findings)
        return 1

    print("✅ DI crash risk check passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
