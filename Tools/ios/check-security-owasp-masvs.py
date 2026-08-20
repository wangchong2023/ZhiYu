#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-security-owasp-masvs.py
#  ZhiYu
#
#  Created by Antigravity on 2026/08/20.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：OWASP MASVS L1 静态安全扫描 — 检查 OWASP Mobile Top 10 代码级风险点。
#
#  覆盖的 OWASP Mobile Top 10 (2024) 类别：
#    M1  Improper Credential Usage        — 硬编码凭证、不安全 token 存储
#    M3  Insecure Authentication          — 弱认证、绕过认证
#    M4  Insufficient Input Validation    — 不安全的 URL 加载、未校验输入
#    M5  Insecure Communication           — HTTP 明文通信、禁用 ATS
#    M6  Inadequate Privacy Controls      — 日志泄露敏感信息
#    M7  Insufficient Cryptography        — 弱加密、硬编码密钥
#    M9  Insecure Configuration           — Debug 模式残留、不安全配置
#

import os
import re
import sys
import json
from pathlib import Path

# ═══════════════════════════════════════════════════════════════════════════════
# 配置
# ═══════════════════════════════════════════════════════════════════════════════

PROJECT_ROOT = Path(__file__).resolve().parent.parent.parent
SCAN_DIRS = [
    PROJECT_ROOT / "Sources",
    PROJECT_ROOT / "Packages",
]
EXEMPTION_FILE = PROJECT_ROOT / "Config" / "exemptions" / "manual_whitelist.yml"

# 扫描文件扩展名
SCAN_EXTENSIONS = {".swift"}

# ═══════════════════════════════════════════════════════════════════════════════
# OWASP MASVS 检查规则
# ═══════════════════════════════════════════════════════════════════════════════

class MASVSRule:
    """OWASP MASVS 检查规则"""
    def __init__(self, rule_id, category, severity, pattern, description, exclude_lines=None):
        """初始化 MASVS 检查规则实例。

        参数:
            rule_id: 规则唯一标识（如 "M1-001"）
            category: OWASP Mobile Top 10 类别（如 "M1"）
            severity: 严重程度（HIGH/MEDIUM/LOW）
            pattern: 正则表达式字符串
            description: 规则描述
            exclude_lines: 排除行号集合
        """
        self.rule_id = rule_id
        self.category = category
        self.severity = severity
        self.pattern = re.compile(pattern, re.MULTILINE)
        self.description = description
        self.exclude_lines = exclude_lines or set()

    def check(self, content, filepath):
        """检查文件内容，返回违规列表"""
        violations = []
        for match in self.pattern.finditer(content):
            line_num = content[:match.start()].count('\n') + 1
            if line_num in self.exclude_lines:
                continue
            violations.append({
                "rule_id": self.rule_id,
                "category": self.category,
                "severity": self.severity,
                "file": str(filepath),
                "line": line_num,
                "match": match.group(0).strip(),
                "description": self.description,
            })
        return violations


# M1: Improper Credential Usage — 硬编码凭证
RULES_M1 = [
    MASVSRule(
        "M1-001", "M1", "HIGH",
        r'(?:password|passwd|secret|api_key|apikey|access_key|private_key)\s*=\s*["\'][^"\']{8,}["\']',
        "硬编码凭证：检测到疑似密码/API密钥/密钥硬编码",
    ),
    MASVSRule(
        "M1-002", "M1", "HIGH",
        r'Bearer\s+[A-Za-z0-9\-_]{20,}',
        "硬编码 Bearer Token：检测到硬编码的 Bearer Token",
    ),
]

# M3: Insecure Authentication — 弱认证
RULES_M3 = [
    MASVSRule(
        "M3-001", "M3", "MEDIUM",
        r'isAuthenticated\s*=\s*true',
        "认证绕过风险：硬编码 isAuthenticated=true 可能绕过认证",
    ),
]

# M4: Insufficient Input Validation — 不安全的 URL 加载
RULES_M4 = [
    MASVSRule(
        "M4-001", "M4", "MEDIUM",
        r'openURL\s*\(\s*URL\s*\(\s*string:\s*[^)]*\)',
        "不安全 URL 加载：openURL 未校验 URL scheme",
    ),
]

# M5: Insecure Communication — HTTP 明文通信
# 排除：XML 命名空间、User-Agent、正则表达式、URLScheme 常量定义、注释
RULES_M5 = [
    MASVSRule(
        "M5-001", "M5", "HIGH",
        r'(?<!schemas\.openxmlformats\.org/)(?<!www\.w3\.org/)http://(?!localhost|127\.0\.0\.1|0\.0\.0\.0|www\.google\.com|schemas\.openxmlformats\.org|www\.w3\.org|example\.com)',
        "HTTP 明文通信：检测到非本地 HTTP URL，应使用 HTTPS",
    ),
    MASVSRule(
        "M5-002", "M5", "MEDIUM",
        r'NSAllowsArbitraryLoads\s*=\s*true',
        "ATS 禁用：NSAllowsArbitraryLoads=true 禁用了 App Transport Security",
    ),
]

# M6: Inadequate Privacy Controls — 日志泄露敏感信息
RULES_M6 = [
    MASVSRule(
        "M6-001", "M6", "MEDIUM",
        r'print\s*\(\s*[^)]*(?:token|password|secret|apiKey|accessKey)',
        "日志泄露敏感信息：print 输出可能包含敏感信息，应使用 Logger 协议",
    ),
]

# M7: Insufficient Cryptography — 弱加密
# M7-001 排除：文件去重命名场景（Insecure.MD5 用于非安全用途的哈希命名）
RULES_M7 = [
    MASVSRule(
        "M7-001", "M7", "HIGH",
        r'CC_SHA1|CryptoKit\.SHA1|\.SHA1\.hash',
        "弱哈希算法：SHA1 不应用于安全场景，应使用 SHA256+",
    ),
    MASVSRule(
        "M7-002", "M7", "HIGH",
        r'kCCAlgorithmDES\b|kCCAlgorithm3DES\b|kCCAlgorithmCAST',
        "弱加密算法：DES/3DES/CAST 已不安全，应使用 AES-256",
    ),
]

# M9: Insecure Configuration — Debug 模式残留
RULES_M9 = [
    MASVSRule(
        "M9-001", "M9", "LOW",
        r'#if DEBUG\s*\n\s*print\s*\(',
        "Debug 残留：#if DEBUG 块中包含 print 调试语句，应使用 Logger",
    ),
]

ALL_RULES = RULES_M1 + RULES_M3 + RULES_M4 + RULES_M5 + RULES_M6 + RULES_M7 + RULES_M9

# ═══════════════════════════════════════════════════════════════════════════════
# 豁免加载
# ═══════════════════════════════════════════════════════════════════════════════

def load_exemptions():
    """加载豁免白名单"""
    exemptions = set()
    if not EXEMPTION_FILE.exists():
        return exemptions
    try:
        with open(EXEMPTION_FILE, "r", encoding="utf-8") as f:
            content = f.read()
        # 简单解析 owasp_masvs_exempt 分类
        in_owasp = False
        for line in content.split("\n"):
            if line.strip().startswith("owasp_masvs_exempt:"):
                in_owasp = True
                continue
            if in_owasp:
                if line.startswith("  ") and "file:" in line:
                    match = re.search(r'file:\s*(.+)', line)
                    if match:
                        exemptions.add(match.group(1).strip())
                elif not line.startswith(" "):
                    in_owasp = False
    except Exception:
        pass
    return exemptions


def is_exempt(filepath, exemptions):
    """检查文件是否在豁免列表中"""
    for exempt in exemptions:
        if exempt in str(filepath):
            return True
    return False

# ═══════════════════════════════════════════════════════════════════════════════
# 扫描引擎
# ═══════════════════════════════════════════════════════════════════════════════

# 报告分隔线宽度
REPORT_LINE_WIDTH = 80


def is_false_positive(v, line_text, filepath):
    """判断违规是否为误报。

    参数:
        v: 违规字典
        line_text: 违规所在行的文本
        filepath: 文件路径

    返回:
        True 表示误报应跳过，False 表示真实违规
    """
    # 排除正则表达式中的 http://
    if "http://" in line_text and ("#" in line_text or "regex" in line_text.lower()):
        return True
    # 排除注释行（/// 或 //）
    stripped = line_text.strip()
    if stripped.startswith("///") or stripped.startswith("//"):
        return True
    # 排除 URLScheme 常量定义行（含赋值行）
    if "public static let http" in line_text or "= \"http://\"" in line_text:
        return True
    # 排除 Logger.swift 自身的 #if DEBUG print（Logger 引导日志）
    if v["rule_id"] == "M9-001" and "Logger" in str(filepath):
        return True
    return False


def scan_file(filepath, rules):
    """扫描单个文件，返回违规列表。"""
    violations = []
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
    except Exception:
        return violations

    lines = content.split("\n")

    for rule in rules:
        for v in rule.check(content, filepath):
            line_num = v["line"]
            line_text = lines[line_num - 1] if 0 < line_num <= len(lines) else ""
            if is_false_positive(v, line_text, filepath):
                continue
            violations.append(v)
    return violations


def scan_project():
    """扫描整个项目"""
    exemptions = load_exemptions()
    all_violations = []
    files_scanned = 0

    for scan_dir in SCAN_DIRS:
        if not scan_dir.exists():
            continue
        for filepath in scan_dir.rglob("*"):
            if filepath.suffix not in SCAN_EXTENSIONS:
                continue
            if is_exempt(filepath, exemptions):
                continue
            # 跳过 Tests 目录
            if "Tests" in filepath.parts:
                continue
            files_scanned += 1
            all_violations.extend(scan_file(filepath, ALL_RULES))

    return all_violations, files_scanned

# ═══════════════════════════════════════════════════════════════════════════════
# 报告输出
# ═══════════════════════════════════════════════════════════════════════════════

def print_report(violations, files_scanned):
    """输出扫描报告"""
    print("=" * REPORT_LINE_WIDTH)
    print("OWASP MASVS L1 静态安全扫描报告")
    print("=" * REPORT_LINE_WIDTH)
    print(f"扫描文件数: {files_scanned}")
    print(f"违规总数: {len(violations)}")
    print()

    if not violations:
        print("✅ 未发现 OWASP MASVS L1 违规项")
        return True

    # 按严重程度分组
    by_severity = {"HIGH": [], "MEDIUM": [], "LOW": []}
    for v in violations:
        by_severity.get(v["severity"], []).append(v)

    for severity in ["HIGH", "MEDIUM", "LOW"]:
        items = by_severity[severity]
        if not items:
            continue
        print(f"--- {severity} ({len(items)} 项) ---")
        for v in items:
            print(f"  [{v['rule_id']}] {v['category']}: {v['description']}")
            print(f"    文件: {v['file']}:{v['line']}")
            print(f"    匹配: {v['match']}")
            print()
        print()

    # JSON 报告（供 CI 消费）
    report_path = PROJECT_ROOT / "build" / "owasp-masvs-report.json"
    report_path.parent.mkdir(parents=True, exist_ok=True)
    with open(report_path, "w", encoding="utf-8") as f:
        json.dump({
            "files_scanned": files_scanned,
            "violations": violations,
            "summary": {
                "total": len(violations),
                "high": len(by_severity["HIGH"]),
                "medium": len(by_severity["MEDIUM"]),
                "low": len(by_severity["LOW"]),
            },
        }, f, ensure_ascii=False, indent=2)
    print(f"📄 JSON 报告: {report_path}")

    return len(violations) == 0

# ═══════════════════════════════════════════════════════════════════════════════
# 主入口
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    strict = "--strict" in sys.argv
    violations, files_scanned = scan_project()
    passed = print_report(violations, files_scanned)

    if strict and not passed:
        print("\n❌ [OWASP MASVS] 静态安全扫描未通过！存在违规项需修复或登记豁免。")
        sys.exit(1)
    else:
        print("\n✅ [OWASP MASVS] 静态安全扫描完成")
        sys.exit(0)


if __name__ == "__main__":
    main()
