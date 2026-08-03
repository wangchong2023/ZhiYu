#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check_sonarqube_coverage.py
#  ZhiYu
#
#  Created by Antigravity on 2026/08/03.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/CI] 持续集成
#  核心职责：从 SonarQube API 拉取项目整体与各模块的语句覆盖率、分支覆盖率，
#           对照 Quality Gate 阈值（语句 ≥95%、分支 ≥90%、重复率 <3%）生成报告并判定是否达标。
#

import argparse
import json
import os
import sys
import urllib.request
import urllib.error

# ==============================================================================
# MARK: - 常量定义
# ==============================================================================

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

PERCENT_MULTIPLIER = 100.0

LINE_COVERAGE_THRESHOLD = 95.0
BRANCH_COVERAGE_THRESHOLD = 90.0
DUPLICATED_LINES_DENSITY_THRESHOLD = 3.0

OVERALL_METRICS = [
    "coverage",
    "branch_coverage",
    "line_coverage",
    "duplicated_lines_density",
    "ncloc",
    "code_smells",
    "bugs",
    "vulnerabilities",
]

MODULE_METRICS = [
    "coverage",
    "branch_coverage",
    "line_coverage",
    "duplicated_lines_density",
    "ncloc",
]

MODULE_DEFINITIONS = [
    {"key": "app-swift", "label": "App Core (Swift)", "type": "sonar_module"},
    {"key": "tools-scripts", "label": "Tools & Pipeline (Python/Shell/YAML)", "type": "sonar_module"},
    {"key": "Sources/App", "label": "Sources/App", "type": "directory"},
    {"key": "Sources/Core", "label": "Sources/Core", "type": "directory"},
    {"key": "Sources/Domain", "label": "Sources/Domain", "type": "directory"},
    {"key": "Sources/Features", "label": "Sources/Features", "type": "directory"},
    {"key": "Sources/Infrastructure", "label": "Sources/Infrastructure", "type": "directory"},
    {"key": "Sources/Shared", "label": "Sources/Shared", "type": "directory"},
    {"key": "Sources/Localization", "label": "Sources/Localization", "type": "directory"},
    {"key": "Packages/UFPCore", "label": "SPM: UFPCore", "type": "directory"},
    {"key": "Packages/UFPStorage", "label": "SPM: UFPStorage", "type": "directory"},
    {"key": "Packages/UFPDesignSystem", "label": "SPM: UFPDesignSystem", "type": "directory"},
    {"key": "Packages/ZhiYuDomain", "label": "SPM: ZhiYuDomain", "type": "directory"},
    {"key": "Packages/ZhiYuAICore", "label": "SPM: ZhiYuAICore", "type": "directory"},
    {"key": "Packages/ZhiYuFeatures", "label": "SPM: ZhiYuFeatures", "type": "directory"},
]

COLOR_RED = "\033[31m"
COLOR_GREEN = "\033[32m"
COLOR_YELLOW = "\033[33m"
COLOR_CYAN = "\033[36m"
COLOR_BOLD = "\033[1m"
COLOR_RESET = "\033[0m"

HTTP_UNAUTHORIZED = 401
HTTP_NOT_FOUND = 404
API_TIMEOUT_SECONDS = 30
REPORT_LINE_WIDTH = 72
TABLE_SEPARATOR_WIDTH = 60
MODULE_TABLE_SEPARATOR_WIDTH = 80


# ==============================================================================
# MARK: - 日志函数
# ==============================================================================

def log_info(msg: str):
    print(f"{COLOR_CYAN}[INFO]{COLOR_RESET} {msg}")


def log_success(msg: str):
    print(f"{COLOR_GREEN}[PASS]{COLOR_RESET} {msg}")


def log_error(msg: str):
    print(f"{COLOR_RED}[FAIL]{COLOR_RESET} {msg}")


def log_warn(msg: str):
    print(f"{COLOR_YELLOW}[WARN]{COLOR_RESET} {msg}")


# ==============================================================================
# MARK: - SonarQube API 交互
# ==============================================================================

def _make_url(host: str, path: str) -> str:
    """构造 SonarQube API 完整 URL"""
    base = host.rstrip("/")
    return f"{base}{path}"


def _api_get(url: str, token: str) -> dict | None:
    """发起 SonarQube API GET 请求，返回 JSON 字典；失败返回 None

    认证方式：SonarQube API 同时支持 Basic Auth（用户名:密码）和 Bearer Token。
    对于 squ_ 前缀的 token 使用 Bearer 方式，否则使用 Basic Auth。
    """
    import base64
    if token.startswith("squ_"):
        headers = {"Authorization": f"Bearer {token}"}
    else:
        encoded = base64.b64encode(token.encode()).decode()
        headers = {"Authorization": f"Basic {encoded}"}
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=API_TIMEOUT_SECONDS) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        if e.code == HTTP_UNAUTHORIZED:
            log_error(f"认证失败 (HTTP {HTTP_UNAUTHORIZED})，请检查 SONAR_TOKEN 是否有效")
        elif e.code == HTTP_NOT_FOUND:
            pass
        else:
            log_error(f"HTTP {e.code}: {e.reason}")
        return None
    except urllib.error.URLError as e:
        log_error(f"无法连接 SonarQube: {e.reason}")
        return None


def fetch_project_measures(host: str, token: str, project_key: str) -> dict[str, str]:
    """获取项目整体指标"""
    metrics_str = ",".join(OVERALL_METRICS)
    url = _make_url(host, f"/api/measures/component?component={project_key}&metricKeys={metrics_str}")
    data = _api_get(url, token)
    if not data:
        return {}
    measures = {}
    for m in data.get("component", {}).get("measures", []):
        measures[m["metric"]] = m.get("value", m.get("periods", [{}])[0].get("value", ""))
    return measures


def fetch_module_measures(host: str, token: str, project_key: str, module_key: str) -> dict[str, str]:
    """获取指定模块/目录的指标"""
    metrics_str = ",".join(MODULE_METRICS)
    component = f"{project_key}:{module_key}"
    url = _make_url(host, f"/api/measures/component?component={component}&metricKeys={metrics_str}")
    data = _api_get(url, token)
    if not data:
        return {}
    measures = {}
    for m in data.get("component", {}).get("measures", []):
        measures[m["metric"]] = m.get("value", m.get("periods", [{}])[0].get("value", ""))
    return measures


def fetch_quality_gate_status(host: str, token: str, project_key: str) -> dict:
    """获取 Quality Gate 状态"""
    url = _make_url(host, f"/api/qualitygates/project_status?projectKey={project_key}")
    data = _api_get(url, token)
    if not data:
        return {}
    return data.get("projectStatus", {})


# ==============================================================================
# MARK: - 报告格式化
# ==============================================================================

def _format_pct(value: str | None) -> str:
    """格式化百分比数值"""
    if value is None or value == "":
        return "N/A"
    try:
        return f"{float(value):.1f}%"
    except ValueError:
        return "N/A"


def _format_int(value: str | None) -> str:
    """格式化整数值"""
    if value is None or value == "":
        return "N/A"
    try:
        return f"{int(float(value)):,}"
    except ValueError:
        return "N/A"


def _coverage_status(value: str | None, threshold: float, higher_is_better: bool = True) -> str:
    """判断覆盖率是否达标，返回带颜色的状态标记"""
    if value is None or value == "":
        return f"{COLOR_YELLOW}⚠ 无数据{COLOR_RESET}"
    try:
        pct = float(value)
    except ValueError:
        return f"{COLOR_YELLOW}⚠ 无数据{COLOR_RESET}"
    if higher_is_better:
        if pct >= threshold:
            return f"{COLOR_GREEN}✓ 达标{COLOR_RESET}"
        else:
            return f"{COLOR_RED}✗ 未达标{COLOR_RESET}"
    else:
        if pct <= threshold:
            return f"{COLOR_GREEN}✓ 达标{COLOR_RESET}"
        else:
            return f"{COLOR_RED}✗ 未达标{COLOR_RESET}"


def print_overall_report(measures: dict[str, str], qg_status: dict):
    """打印项目整体覆盖率报告"""
    print(f"\n{'=' * REPORT_LINE_WIDTH}")
    print(f"{COLOR_BOLD}  ZhiYu SonarQube 覆盖率报告 — 项目整体{COLOR_RESET}")
    print(f"{'=' * REPORT_LINE_WIDTH}")

    line_cov = measures.get("line_coverage")
    branch_cov = measures.get("branch_coverage")
    overall_cov = measures.get("coverage")
    dup_density = measures.get("duplicated_lines_density")
    ncloc = measures.get("ncloc")
    code_smells = measures.get("code_smells")
    bugs = measures.get("bugs")
    vulns = measures.get("vulnerabilities")

    qg_result = qg_status.get("status", "NONE")
    if qg_result == "OK":
        qg_label = f"{COLOR_GREEN}OK (通过){COLOR_RESET}"
    elif qg_result == "ERROR":
        qg_label = f"{COLOR_RED}ERROR (未通过){COLOR_RESET}"
    else:
        qg_label = f"{COLOR_YELLOW}{qg_result}{COLOR_RESET}"

    print(f"\n  Quality Gate:  {qg_label}")
    print(f"  代码行数:      {_format_int(ncloc)}")
    print(f"  Bugs:          {_format_int(bugs)}")
    print(f"  漏洞:          {_format_int(vulns)}")
    print(f"  Code Smells:   {_format_int(code_smells)}")

    print(f"\n  {'指标':<24} {'当前值':>10}   {'阈值':>10}   {'状态'}")
    print(f"  {'-' * TABLE_SEPARATOR_WIDTH}")
    print(f"  {'语句覆盖率 (line_coverage)':<24} {_format_pct(line_cov):>10}   {'≥' + str(LINE_COVERAGE_THRESHOLD) + '%':>10}   {_coverage_status(line_cov, LINE_COVERAGE_THRESHOLD)}")
    print(f"  {'分支覆盖率 (branch_coverage)':<24} {_format_pct(branch_cov):>10}   {'≥' + str(BRANCH_COVERAGE_THRESHOLD) + '%':>10}   {_coverage_status(branch_cov, BRANCH_COVERAGE_THRESHOLD)}")
    print(f"  {'综合覆盖率 (coverage)':<24} {_format_pct(overall_cov):>10}   {'—':>10}   —")
    print(f"  {'代码重复率 (dup_lines_density)':<24} {_format_pct(dup_density):>10}   {'<' + str(DUPLICATED_LINES_DENSITY_THRESHOLD) + '%':>10}   {_coverage_status(dup_density, DUPLICATED_LINES_DENSITY_THRESHOLD, higher_is_better=False)}")

    if qg_status.get("conditions"):
        print(f"\n  Quality Gate 条件明细:")
        for cond in qg_status["conditions"]:
            status_icon = "✓" if cond.get("status") == "OK" else "✗"
            metric = cond.get("metricKey", "?")
            val = cond.get("actualValue", "N/A")
            err = cond.get("errorThreshold", "")
            op = cond.get("operator", "")
            print(f"    {status_icon} {metric}: {val} {op} {err}")


def print_module_report(module_results: list[dict]):
    """打印各模块覆盖率报告"""
    print(f"\n{'=' * REPORT_LINE_WIDTH}")
    print(f"{COLOR_BOLD}  ZhiYu SonarQube 覆盖率报告 — 模块明细{COLOR_RESET}")
    print(f"{'=' * REPORT_LINE_WIDTH}")

    has_data = any(r["measures"] for r in module_results)
    if not has_data:
        print(f"\n  {COLOR_YELLOW}所有模块均无覆盖率数据。请先完成一次 SonarQube 扫描。{COLOR_RESET}")
        return

    header = f"  {'模块':<40} {'语句覆盖率':>10} {'分支覆盖率':>10} {'重复率':>8} {'代码行':>8}"
    print(f"\n{header}")
    print(f"  {'-' * MODULE_TABLE_SEPARATOR_WIDTH}")

    for r in module_results:
        label = r["label"]
        m = r["measures"]
        if not m:
            print(f"  {label:<40} {COLOR_YELLOW}{'无数据':>10}{COLOR_RESET} {'':>10} {'':>8} {'':>8}")
            continue

        line_cov = _format_pct(m.get("line_coverage"))
        branch_cov = _format_pct(m.get("branch_coverage"))
        dup = _format_pct(m.get("duplicated_lines_density"))
        ncloc = _format_int(m.get("ncloc"))

        line_val = m.get("line_coverage")
        branch_val = m.get("branch_coverage")
        dup_val = m.get("duplicated_lines_density")

        line_status = _coverage_status(line_val, LINE_COVERAGE_THRESHOLD)
        branch_status = _coverage_status(branch_val, BRANCH_COVERAGE_THRESHOLD)
        dup_status = _coverage_status(dup_val, DUPLICATED_LINES_DENSITY_THRESHOLD, higher_is_better=False)

        print(f"  {label:<40} {line_cov:>10} {branch_cov:>10} {dup:>8} {ncloc:>8}")

    print(f"\n  阈值: 语句覆盖率 ≥ {LINE_COVERAGE_THRESHOLD}%  |  分支覆盖率 ≥ {BRANCH_COVERAGE_THRESHOLD}%  |  重复率 < {DUPLICATED_LINES_DENSITY_THRESHOLD}%")


def check_gate_pass(measures: dict[str, str]) -> bool:
    """检查整体覆盖率是否满足 Quality Gate 阈值"""
    passed = True

    line_cov = measures.get("line_coverage")
    if line_cov is not None and line_cov != "":
        if float(line_cov) < LINE_COVERAGE_THRESHOLD:
            passed = False

    branch_cov = measures.get("branch_coverage")
    if branch_cov is not None and branch_cov != "":
        if float(branch_cov) < BRANCH_COVERAGE_THRESHOLD:
            passed = False

    dup = measures.get("duplicated_lines_density")
    if dup is not None and dup != "":
        if float(dup) > DUPLICATED_LINES_DENSITY_THRESHOLD:
            passed = False

    return passed


# ==============================================================================
# MARK: - 主流程
# ==============================================================================

def main():
    """主程序：拉取 SonarQube 覆盖率数据，生成整体与模块报告，判定是否达标"""
    parser = argparse.ArgumentParser(
        description="ZhiYu SonarQube 覆盖率报告与 Quality Gate 达标检查",
        epilog="示例: python3 Tools/CI/Test/check_sonarqube_coverage.py --host http://localhost:9000 --token squ_xxx --project ZhiYu",
    )
    parser.add_argument("--host", default=os.environ.get("SONAR_HOST_URL", "http://localhost:9000"), help="SonarQube 服务器地址 (默认: SONAR_HOST_URL 环境变量或 http://localhost:9000)")
    parser.add_argument("--token", default=os.environ.get("SONAR_TOKEN", ""), help="SonarQube 认证 Token (默认: SONAR_TOKEN 环境变量)")
    parser.add_argument("--project", default=os.environ.get("SONAR_PROJECT_KEY", "ZhiYu"), help="SonarQube 项目 Key (默认: SONAR_PROJECT_KEY 环境变量或 ZhiYu)")
    parser.add_argument("--strict", action="store_true", help="严格模式：无数据时返回非零退出码")
    args = parser.parse_args()

    if not args.token:
        log_error("未提供 SONAR_TOKEN，请通过 --token 参数或 SONAR_TOKEN 环境变量设置")
        return 1

    log_info(f"SonarQube 服务器: {args.host}")
    log_info(f"项目 Key: {args.project}")
    log_info("正在拉取覆盖率数据...")

    overall_measures = fetch_project_measures(args.host, args.token, args.project)
    qg_status = fetch_quality_gate_status(args.host, args.token, args.project)

    if not overall_measures and args.strict:
        log_error("无法获取项目整体指标数据")
        return 1

    print_overall_report(overall_measures, qg_status)

    module_results = []
    for mod in MODULE_DEFINITIONS:
        measures = fetch_module_measures(args.host, args.token, args.project, mod["key"])
        module_results.append({"key": mod["key"], "label": mod["label"], "measures": measures})

    print_module_report(module_results)

    print(f"\n{'=' * REPORT_LINE_WIDTH}")
    if not overall_measures:
        log_warn("项目尚无扫描数据，请先完成一次 SonarQube 分析")
        return 1 if args.strict else 0

    gate_pass = check_gate_pass(overall_measures)
    if gate_pass:
        log_success("覆盖率达标，Quality Gate 通过")
        return 0
    else:
        log_error("覆盖率未达标，Quality Gate 阻断")
        return 1


if __name__ == "__main__":
    sys.exit(main())
