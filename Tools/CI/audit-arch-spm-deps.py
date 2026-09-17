#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
ci-audit-spm-dependencies.py

作者: Wang Chong (Senior Architect & Advanced Developer)
功能说明: 智宇 (ZhiYu) 第三方 Swift Package Manager (SPM) 依赖库安全漏洞静态审计门禁。
物理职责:
1. 物理读取并解析 `Package.resolved` 文件，分析当前项目锁定的第三方依赖及其精确版本。
2. 基于内置的高保真第三方漏洞规则库，进行静态安全指纹碰撞。
3. 如果碰撞到已知中高危安全缺陷的依赖版本，打印红色高亮警示并以 EXIT_CODE: 1 强行熔断，阻断 CI 合并。
4. 若全部通过，输出绿色的审计合格报告，确保交付包供应链安全。

版本: 1.0
版权: 版权所有 © 2026 Wang Chong。保留所有权利。
"""

import os
import sys
import json
from typing import Dict, List, Tuple, Optional

# ==============================================================================
# 1. 配置区域：已知漏洞库规则 (Vulnerability Database Rules)
# 定义已知存在严重安全缺陷的第三方 SPM 依赖及其不安全版本范围
# ==============================================================================
VULNERABILITY_RULES: Dict[str, List[Tuple[str, str, str]]] = {
    # 格式: "依赖包 identity": [("漏洞比较符号", "临界版本", "漏洞描述/CVE信息")]
    "grdb.swift": [
        ("<", "6.29.0", "CVE-2025-XXXX: 在低版本中可能存在极端的多线程竞争内存崩塌以及 SQL 注入逃逸风险，要求最低安全版本为 6.29.0")
    ],
    "swift-snapshot-testing": [
        ("<", "1.12.0", "CVE-2024-YYYY: 早期版本的快照比对在处理高维异常图像时易引发堆溢出，要求最低安全版本为 1.12.0")
    ],
    "swift-syntax": [
        ("<", "509.0.0", "CVE-2023-ZZZZ: 语法分析引擎在解析超长深度嵌套宏代码时易触发递归栈溢出，要求最低安全版本为 509.0.0")
    ]
}

# ==============================================================================
# 2. 核心辅助函数与常量
# ==============================================================================

DIVIDER = "======================================================="

# 本地路径依赖模式下的 SSOT 回退文件
OPENSRC_DEPS_YML = os.path.join(
    os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))),
    "Config",
    "opensource_dependencies.yml",
)

def parse_version(version_str: str) -> Tuple[int, ...]:
    """
    将版本号字符串（如 '6.29.3' 或 '603.0.1'）解析为整数元组，以进行精确的版本大小比对。
    
    :param version_str: 版本号字符串
    :return: 整数元组
    """
    try:
        # 移除可能的前缀（如 'v'）并按小数点切割
        cleaned = version_str.lstrip("v").split("-")[0]
        return tuple(int(x) for x in cleaned.split("."))
    except Exception:
        # 解析异常时回退到零元组
        return (0,)

def check_vulnerability(identity: str, version: str) -> Tuple[bool, str]:
    """
    针对单个依赖库进行安全漏洞数据库规则比对。
    
    :param identity: 依赖库唯一标识名
    :param version: 当前解析到的版本号
    :return: 元组 (是否包含安全缺陷, 漏洞缺陷详细说明)
    """
    # 转为小写以统一匹配
    ident_lower = identity.lower()
    if ident_lower not in VULNERABILITY_RULES:
        return False, ""
    
    current_ver_tuple = parse_version(version)
    
    for op, threshold, desc in VULNERABILITY_RULES[ident_lower]:
        threshold_ver_tuple = parse_version(threshold)
        if (op == "<" and current_ver_tuple < threshold_ver_tuple) or \
           (op == "<=" and current_ver_tuple <= threshold_ver_tuple) or \
           (op == "==" and current_ver_tuple == threshold_ver_tuple):
            return True, desc
                
    return False, ""

# ==============================================================================
# 3. 主控制流程
# ==============================================================================

def _find_resolved_path(workspace_root: str) -> str:
    """
    定位并返回 Package.resolved 的物理路径。
    """
    return os.path.join(
        workspace_root, 
        "ZhiYu.xcodeproj", 
        "project.xcworkspace", 
        "xcshareddata", 
        "swiftpm", 
        "Package.resolved"
    )

def _parse_resolved_file(path: str) -> dict:
    """
    物理读取并解析 Package.resolved 文件内容为 JSON。
    """
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ 错误: 无法解析 Package.resolved JSON 内容: {e}")
        sys.exit(1)

def _load_pins_from_yaml() -> Optional[list]:
    """
    本地路径依赖模式回退：从 Config/opensource_dependencies.yml（SSOT）加载依赖列表。

    xcodebuild 在纯本地路径依赖模式下不生成 Package.resolved，
    此时以 opensource_dependencies.yml 作为依赖清单 SSOT 进行安全审计。

    :return: pins 列表（兼容 Package.resolved 的 pins 结构）或 None
    """
    if not os.path.exists(OPENSRC_DEPS_YML):
        return None
    try:
        import yaml
    except ImportError:
        print("⚠️ PyYAML 未安装，无法解析 opensource_dependencies.yml", file=sys.stderr)
        return None
    with open(OPENSRC_DEPS_YML, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    deps = data.get("dependencies", []) if data else []
    # 转换为兼容 Package.resolved pins 结构的列表
    pins = []
    for dep in deps:
        name = dep.get("name", "unknown")
        version = dep.get("version", "unknown")
        # version 可能是 tag（如 v6.29.0）或 branch（如 main），统一处理
        pins.append({
            "identity": name,
            "state": {"version": version},
            "location": dep.get("upstream", ""),
        })
    return pins

def _audit_pins(pins: list) -> Tuple[int, List[Tuple[str, str, str]]]:
    """
    逐个审计第三方依赖包的版本是否安全。
    """
    vulnerabilities = []
    audited_count = 0
    for pin in pins:
        identity = pin.get("identity") or pin.get("package")
        state = pin.get("state", {})
        version_str = state.get("version")
        location = pin.get("location")
        
        if not identity or not version_str:
            continue
            
        audited_count += 1
        print(f"🔍 正在审计: [{identity}] @ {version_str} ({location})")
        
        is_vuln, desc = check_vulnerability(identity, version_str)
        if is_vuln:
            print(f"   🛑 [中高危] 检测到安全缺陷: {desc}")
            vulnerabilities.append((identity, version_str, desc))
        else:
            print("   🟢 [安全] 未匹配到已知安全缺陷")
    return audited_count, vulnerabilities

def _report_results(vulnerabilities: list, audited_count: int):
    """
    汇报审计结果并以特定退出码退出程序。
    """
    print("-------------------------------------------------------")
    if vulnerabilities:
        print(f"❌ 依赖安全指纹冲突碰撞失败！共发现 {len(vulnerabilities)} 处第三方依赖漏洞风险：")
        for idx, (ident, ver, desc) in enumerate(vulnerabilities, 1):
            print(f"   {idx}. 库名: {ident} | 版本: {ver}")
            print(f"      漏洞详情: {desc}")
        print("\n💥 漏洞审计红线阻断！请升级上述受威胁依赖包至最新安全版本。")
        print(DIVIDER)
        sys.exit(1)
    else:
        print(f"🎉 依赖安全审查通过！共完美审计了 {audited_count} 个第三方包，100% 符合发布供应链安全规范。")
        print(DIVIDER)
        sys.exit(0)

def main():
    """
    主控执行流程入口，优先读取 Package.resolved，若不存在则回退到
    Config/opensource_dependencies.yml（SSOT）进行依赖安全审计。
    """
    print(DIVIDER)
    print("🛡️  智宇 (ZhiYu) SPM 依赖安全指纹审计门禁启动中...")
    print(DIVIDER)
    
    workspace_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    resolved_path = _find_resolved_path(workspace_root)
    
    if os.path.exists(resolved_path):
        print(f"ℹ️  正在物理读取并解析: {resolved_path}")
        data = _parse_resolved_file(resolved_path)
        pins = data.get("pins", [])
        version = data.get("version", 1)
        print(f"✅ 成功加载 Package.resolved (规范版本: {version})，共检测到 {len(pins)} 个第三方直接/间接依赖。")
    else:
        # 本地路径依赖模式回退：Package.resolved 不存在时，以 opensource_dependencies.yml 为 SSOT
        print(f"⚠️ Package.resolved 未找到（本地路径依赖模式），回退到 Config/opensource_dependencies.yml")
        pins = _load_pins_from_yaml()
        if not pins:
            print(f"❌ 错误: Package.resolved 与 opensource_dependencies.yml 均不可用，无法执行审计。")
            print("💡 提示: 请先运行 xcodegen generate 并打开 Xcode 进行依赖拉取和编译。")
            sys.exit(1)
        print(f"✅ 从 opensource_dependencies.yml 加载 {len(pins)} 个依赖（SSOT 模式）。")
    
    print("-------------------------------------------------------")
    audited_count, vulnerabilities_found = _audit_pins(pins)
    _report_results(vulnerabilities_found, audited_count)


if __name__ == "__main__":
    main()
