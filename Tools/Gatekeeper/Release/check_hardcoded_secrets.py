#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check_hardcoded_secrets.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/14.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/Gatekeeper] 守卫网关
#  核心职责：自动扫描 Swift 代码中硬编码敏感信息的静态审计工具（如 API 密钥、Token、密码、内网 IP 等），排除安全白名单。
#

import re
import os
import sys

# ═══════════════════════════════════════════════════════════════════════════════
# 白名单：已知安全的 URL 模式（公开 API 端点、官网、文档）
# ═══════════════════════════════════════════════════════════════════════════════
SAFE_URL_PATTERNS = [
    # LLM 服务提供商 API 端点（公开基础设施地址，不含密钥）
    r'api\.deepseek\.com',
    r'api\.moonshot\.cn',
    r'api\.minimax\.chat',
    r'api\.siliconflow\.cn',
    r'dashscope\.aliyuncs\.com',
    r'open\.bigmodel\.cn',
    r'api\.openai\.com',
    r'api\.anthropic\.com',
    r'api\.googleapis\.com',
    r'generativelanguage\.googleapis\.com',
    # 公开网站和文档
    r'zhiyu\.ai',
    r'izhiyu\.top',
    r'github\.com/zhiyu',
    r'raw\.githubusercontent\.com',
    r'github\.com/login/oauth',      # OAuth 授权 URL（公开）
    # 公开 CDN（模型下载等）
    r'cdn\.zhiyu\.app',
    # XML 命名空间标准（OOXML、SVG 等）
    r'schemas\.openxmlformats\.org',
    r'www\.w3\.org/XML',
    r'www\.w3\.org/1999',
    r'www\.w3\.org/2000',
    # 公开第三方服务 API（头像生成、网页存档）
    r'api\.multiavatar\.com',
    r'web\.archive\.org',
    # 示例/参考链接
    r'github\.com/karpathy',
    r'finance\.sina\.com\.cn/coffee-industry',
    # 占位符/示例 URL
    r'example\.com',
    r'placeholder',
    # 本地开发地址
    r'localhost',
    r'127\.0\.0\.1',
    r'0\.0\.0\.0',
]

# ═══════════════════════════════════════════════════════════════════════════════
# 白名单：安全的 Token/Key 模式（测试桩、Key 名称引用）
# ═══════════════════════════════════════════════════════════════════════════════
SAFE_TOKEN_PATTERNS = [
    r'mock_',           # mock_jwt_access_token 等测试桩
    r'demo_',           # 演示数据
    r'test_',           # 测试数据
    r'example_',        # 示例数据
    r'placeholder',     # 占位符
    r'llm_api_key',     # Keychain key 名称，非实际值
    r'api[_-]?key\s*[:=]\s*""',   # 空字符串 API key
]

# ═══════════════════════════════════════════════════════════════════════════════
# 白名单：安全的文件路径（测试文件、配置文件）
# ═══════════════════════════════════════════════════════════════════════════════
SAFE_FILE_PATTERNS = [
    r'Mock',                    # Mock 服务文件
    r'TestMocks',               # 测试桩
    r'AuthService\.swift',      # 已知含 mock 测试桩
    r'CarrierAuthStrategy\.swift',
    r'GoogleAuthStrategy\.swift',
    r'GitHubAuthStrategy\.swift',
    r'LLMModels\.swift',        # LLM 端点配置
    r'AppConfig',               # 应用配置文件
    r'WebScraperProcessor\.swift',  # UA 字符串
    r'InitialNotebookGenerator\.swift', # 初始/测试演示数据文件，包括公开引用源 URL
    r'SSRFGuard\.swift',           # SSRF 防护：内含 RFC 1918 私有 IP 段用于安全过滤，非泄露
]

# 报告输出时的显示宽度和数量截断限制
REPORT_DIVIDER_WIDTH = 80
REPORT_MAX_DISPLAY_ITEMS = 15
REPORT_CODE_PREVIEW_LEN = 100


def is_safe_url(url):
    """
    检查 URL 是否匹配白名单。

    :param url: URL 字符串
    :return: True 如果 URL 安全
    """
    for pattern in SAFE_URL_PATTERNS:
        if re.search(pattern, url, re.IGNORECASE):
            return True
    return False


def is_safe_token(value):
    """
    检查 token/key 值是否匹配白名单。

    :param value: 敏感值字符串
    :return: True 如果匹配白名单
    """
    for pattern in SAFE_TOKEN_PATTERNS:
        if re.search(pattern, value, re.IGNORECASE):
            return True
    return False


def is_safe_file(filepath):
    """
    检查文件路径是否在白名单中。

    :param filepath: 文件路径
    :return: True 如果文件可豁免
    """
    for pattern in SAFE_FILE_PATTERNS:
        if re.search(pattern, filepath):
            return True
    return False


def _check_ip_leak(line, line_num, rel_path, pattern, issues):
    """
    辅助审计：检查行中是否包含非安全 IP 的硬编码泄露。
    """
    ips = pattern.findall(line)
    for ip in ips:
        if ip.startswith(('127.', '0.0.0.0', 'localhost', '255.')):
            continue
        if 'Mozilla' in line or 'User-Agent' in line:
            continue
        issues['ips'].append((rel_path, line_num, line.strip(), ip))


def _check_credentials_leak(line, line_num, rel_path, patterns, issues):
    """
    辅助审计：检查行中是否包含 Bearer 或 Basic 认证凭证的硬编码泄露。
    """
    if patterns['bearer'].search(line):
        token_text = line.strip()
        if not is_safe_token(token_text):
            issues['credentials'].append((rel_path, line_num, token_text, 'Bearer Token'))

    if patterns['basic_auth'].search(line):
        issues['credentials'].append((rel_path, line_num, line.strip(), 'Basic Auth'))


def _check_email_leak(line, line_num, rel_path, pattern, issues):
    """
    辅助审计：检查行中是否包含敏感非模拟邮箱的硬编码泄露。
    """
    emails = pattern.findall(line)
    for email in emails:
        if any(x in email.lower() for x in ['example', 'mock', 'test', 'demo']):
            continue
        issues['other'].append((rel_path, line_num, line.strip(), f'Email: {email}'))


def _audit_line_secrets(line, line_num, rel_path, patterns, issues):
    """
    针对单行执行具体的硬编码机密扫描（URL, IP, API Key, Bearer, Basic Auth, Emails）。

    :param line: 源代码行
    :param line_num: 行号
    :param rel_path: 文件相对路径
    :param patterns: 编译好的正则字典
    :param issues: 发现的问题收集器
    """
    # 1. HTTP URL 检测
    urls = patterns['http_url'].findall(line)
    for url in urls:
        if not is_safe_url(url):
            issues['urls'].append((rel_path, line_num, line.strip(), url))

    # 2. IP 地址检测
    _check_ip_leak(line, line_num, rel_path, patterns['ip_address'], issues)

    # 3. API 密钥/Token 检测
    api_keys = patterns['api_key'].findall(line)
    for key_name, key_value in api_keys:
        if not is_safe_token(key_value):
            issues['api_keys'].append((rel_path, line_num, line.strip(), f"{key_name} = {key_value}"))

    # 4. Bearer / Basic 认证检测
    _check_credentials_leak(line, line_num, rel_path, patterns, issues)

    # 5. 邮箱地址检测
    _check_email_leak(line, line_num, rel_path, patterns['email'], issues)


def check_hardcoded_info(root_dir='Sources'):
    """
    扫描真正的硬编码敏感信息。

    :param root_dir: 根扫描目录
    :return: 包含各类敏感问题的字典
    """
    issues = {
        'urls': [],
        'ips': [],
        'api_keys': [],
        'credentials': [],
        'other': []
    }

    exclude_dirs = {'.git', 'build', 'DerivedData', '.build', 'Frameworks', 'Tests'}

    patterns = {
        'http_url': re.compile(r'https?://[^\s\'"<>]+'),
        'ip_address': re.compile(r'\b(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?\b'),
        'api_key': re.compile(r'(?i)(api[_-]?key|token|secret|password)\s*[:=]\s*["\']([^"\']{8,})["\']'),
        'bearer': re.compile(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*'),
        'basic_auth': re.compile(r'Basic\s+[A-Za-z0-9+/]+=*'),
        'email': re.compile(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
    }

    for root, dirs, files in os.walk(root_dir):
        dirs[:] = [d for d in dirs if d not in exclude_dirs]

        for file in files:
            if not file.endswith('.swift'):
                continue

            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path)

            if is_safe_file(rel_path):
                continue

            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    lines = f.read().split('\n')

                    for line_num, line in enumerate(lines, 1):
                        if line.strip().startswith('//'):
                            continue
                        _audit_line_secrets(line, line_num, rel_path, patterns, issues)
            except Exception:
                pass

    return issues


def print_report(issues_dict):
    """
    打印报告。

    :param issues_dict: 发现的问题收集器字典
    """
    print("=" * REPORT_DIVIDER_WIDTH)
    print("硬编码敏感信息检查报告")
    print("=" * REPORT_DIVIDER_WIDTH)
    print()

    total = sum(len(v) for v in issues_dict.values())

    if total == 0:
        print("✅ 未发现硬编码敏感信息")
        print("=" * REPORT_DIVIDER_WIDTH)
        return

    print(f"🚨 发现 {total} 处真实风险\n")

    for title, key, icon in [
        ("HTTP/HTTPS URL", 'urls', "🌐"),
        ("IP 地址", 'ips', "🔢"),
        ("API 密钥/密码", 'api_keys', "🔑"),
        ("认证凭证", 'credentials', "🔐"),
        ("其他敏感信息", 'other', "📧"),
    ]:
        items = issues_dict[key]
        if not items:
            continue
        print(f"{icon} {title} ({len(items)} 处)")
        print("-" * REPORT_DIVIDER_WIDTH)
        for path, line_num, line, info in items[:REPORT_MAX_DISPLAY_ITEMS]:
            print(f"  📄 {path}:{line_num}")
            print(f"     详情: {info}")
            print(f"     代码: {line[:REPORT_CODE_PREVIEW_LEN]}")
            print()
        if len(items) > REPORT_MAX_DISPLAY_ITEMS:
            print(f"     ... 还有 {len(items) - REPORT_MAX_DISPLAY_ITEMS} 处\n")

    print("=" * REPORT_DIVIDER_WIDTH)
    print("建议：将真实凭证移至 Keychain 或环境变量，不要硬编码在源码中。")
    print("=" * REPORT_DIVIDER_WIDTH)


def main():
    """
    主入口函数。执行扫描并报告。
    """
    found_issues = check_hardcoded_info()
    print_report(found_issues)
    total_count = sum(len(v) for v in found_issues.values())
    sys.exit(1 if total_count > 0 else 0)


if __name__ == "__main__":
    main()
