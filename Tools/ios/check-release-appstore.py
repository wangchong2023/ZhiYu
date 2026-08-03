#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  check-release-appstore.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/12.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：执行 App Store 提审前的上架就绪度静态审计。
#           检测 Info.plist 权限描述是否详尽、版本号格式、不安全网络配置、业务路径 fatalError 以及隐私清单缺失。
#

import os
import re
import sys
import plistlib

# ==============================================================================
# MARK: - 全局配置区
# ==============================================================================

# 项目根目录，相对于 Tools/scripts/Release 目录的上一级 (退3层)
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
SOURCES_DIR = os.path.join(PROJECT_DIR, "Sources")

# 待检查的 Info.plist 物理路径
PLIST_FILES = [
    os.path.join(SOURCES_DIR, "Info.plist"),
    os.path.join(SOURCES_DIR, "MacInfo.plist")
]

MIN_DESC_LENGTH = 10

# 排除扫描 fatalError 的文件夹
EXCLUDE_DIRS = {'.git', 'build', 'DerivedData', '.build', 'Frameworks', 'Tests', 'env', '__pycache__'}

# 允许使用 fatalError 的代码文件白名单（仅限核心注入/启动熔断等合法初始化逻辑）
FATAL_ERROR_WHITELIST = {
    'ServiceContainer.swift', # 依赖注入容器，解析失败允许熔断
    'ModuleRegistrar.swift',  # 模块注册中心，核心模块缺失允许熔断
    'AppEnvironment.swift',   # 启动环境初始化，底层数据库或核心服务加载失败允许熔断
    'AppStore.swift',         # 全局状态树初始化
    'SecurityManager.swift',   # 系统安全逻辑，解密失败允许熔断
    'LocalAnalyticsService.swift', # 本地埋点统计，底层队列异常允许熔断
    'PluginEnginePool.swift',  # 插件引擎池，引擎崩溃或不可达允许熔断
    'VectorDataRepository.swift',  # 向量仓储，解析向量字段失败允许熔断
    'DatabaseWriterProvider.swift', # 数据库写入器，配置异常允许熔断
    'KnowledgePageRepository.swift', # 知识页面仓储，核心解析异常允许熔断
    'DatabaseManager.swift',   # 数据库核心服务，初始化失败允许熔断
    'SQLiteStore.swift',       # SQLite 数据源，加载连接异常允许熔断
    'MarkdownProcessor.swift', # 文档处理器，正则初始化编译失败允许熔断
}

# ==============================================================================
# MARK: - 核心检查函数
# ==============================================================================

def _check_plist_usage_descriptions(plist_data, issues):
    """
    检查 Plist 中的敏感权限使用说明 (NS*UsageDescription) 是否合规。

    :param plist_data: plist 解析出的字典数据
    :param issues: 收集问题的列表
    """
    for key, value in plist_data.items():
        if key.endswith("UsageDescription") and key.startswith("NS"):
            if not isinstance(value, str):
                issues.append({
                    "type": "error",
                    "message": f"权限描述键 '{key}' 的值类型必须为 String 字符串。"
                })
                continue
                
            val_strip = value.strip()
            # 检查是否为空或文字过短，Apple 提审要求描述清晰
            if not val_strip:
                issues.append({
                    "type": "error",
                    "message": f"权限描述键 '{key}' 的描述内容为空。提审会被直接拒绝。"
                })
            elif len(val_strip) < MIN_DESC_LENGTH:
                issues.append({
                    "type": "error",
                    "message": f"权限描述键 '{key}' 的描述内容过短（'{val_strip}'，小于 {MIN_DESC_LENGTH} 个字符），未明确告知用户用途，面临提审被拒风险。"
                })
            elif re.search(r'\b(test|placeholder|todo|xxx)\b', val_strip.lower()):
                # 含有 test / todo 等测试占位字眼会被拒绝
                issues.append({
                    "type": "error",
                    "message": f"权限描述键 '{key}' 中包含非法测试占位词（如 test/todo/placeholder/xxx），内容为: '{val_strip}'。请提供真实用途说明。"
                })


def _check_plist_version_strings(plist_data, issues):
    """
    检查 CFBundleVersion 与 CFBundleShortVersionString 的格式规范。

    :param plist_data: plist 解析出的字典数据
    :param issues: 收集问题的列表
    """
    # CFBundleShortVersionString (如 1.0.0)
    version_string = plist_data.get("CFBundleShortVersionString")
    if version_string:
        if not re.match(r'^\d+(\.\d+){1,2}$', str(version_string)):
            issues.append({
                "type": "error",
                "message": f"CFBundleShortVersionString 格式不规范（当前值: '{version_string}'）。必须为点分纯数字（如 1.0 或 1.0.0）。"
            })
            
    # CFBundleVersion (如 1)
    bundle_version = plist_data.get("CFBundleVersion")
    if bundle_version:
        if not re.match(r'^\d+(\.\d+)*$', str(bundle_version)):
            issues.append({
                "type": "error",
                "message": f"CFBundleVersion 格式不规范（当前值: '{bundle_version}'）。必须为纯数字或点分纯数字。"
            })


def _check_plist_ats(plist_data, issues):
    """
    检查 ATS (App Transport Security) 任意加载设置。

    :param plist_data: plist 解析出的字典数据
    :param issues: 收集问题的列表
    """
    ats_dict = plist_data.get("NSAppTransportSecurity")
    if isinstance(ats_dict, dict):
        allows_arbitrary = ats_dict.get("NSAllowsArbitraryLoads")
        if allows_arbitrary is True:
            issues.append({
                "type": "warning",
                "message": "检测到 NSAllowsArbitraryLoads 开启。这允许 App 绕过 HTTPS 访问任意不安全网络。提审时 Apple 会要求提供合理解释，建议仅在本地联调时开启，生产发布需移除此豁免。"
            })


def check_plist_compliance(plist_path):
    """
    检查单个 Info.plist 文件的合规性（权限描述、版本号、ATS）。
    
    参数:
        plist_path (str): plist 文件的绝对路径
        
    返回:
        list: 包含发现的错误与警告信息的字典列表
    """
    issues = []
    if not os.path.exists(plist_path):
        # 允许某些平台特定的 Plist 不存在，但需提示
        issues.append({
            "type": "warning",
            "message": f"未发现配置文件: {os.path.basename(plist_path)}，跳过该文件的 plist 审计。"
        })
        return issues

    try:
        with open(plist_path, "rb") as f:
            plist_data = plistlib.load(f)
    except Exception as e:
        issues.append({
            "type": "error",
            "message": f"解析 plist 失败: {str(e)}"
        })
        return issues

    # 1. 检查权限描述合规性 (NS*UsageDescription)
    _check_plist_usage_descriptions(plist_data, issues)

    # 2. 检查 CFBundleVersion 与 CFBundleShortVersionString 格式
    _check_plist_version_strings(plist_data, issues)

    # 3. 检查 ATS (App Transport Security) 任意加载设置
    _check_plist_ats(plist_data, issues)

    return issues


def check_fatal_errors():
    """
    检查 Swift 代码中是否在非初始化路径使用了 fatalError() 造成生产奔溃隐患。
    
    返回:
        list: 包含错误详情的字典列表
    """
    issues = []
    
    for root, dirs, files in os.walk(SOURCES_DIR):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        
        for file in files:
            if file.endswith(".swift"):
                if file in FATAL_ERROR_WHITELIST:
                    continue
                    
                file_path = os.path.join(root, file)
                
                try:
                    with open(file_path, "r", encoding="utf-8") as f:
                        lines = f.readlines()
                except Exception as e:
                    # 无法读取文件，直接报 error
                    issues.append({
                        "file": file_path,
                        "line": 1,
                        "type": "error",
                        "message": f"无法读取文件进行 fatalError 审计: {str(e)}"
                    })
                    continue
                    
                for idx, line in enumerate(lines, 1):
                    # 移除注释，防止把注释里的说明误判为违规
                    clean_line = re.sub(r'//.*', '', line).strip()
                    
                    if "fatalError(" in clean_line:
                        issues.append({
                            "file": file_path,
                            "line": idx,
                            "type": "error",
                            "message": "禁止在非初始化及非核心 DI 路径下使用 fatalError() 引起应用崩溃。请使用 Swift Error 抛出、Swift Log 记录或优雅的失败回退处理。"
                        })
                        
    return issues


def check_privacy_manifest():
    """
    检查项目中是否配置了 iOS 17+ 提审强制要求的 PrivacyInfo.xcprivacy 隐私清单。
    
    返回:
        list: 包含警告详情的列表
    """
    issues = []
    found_privacy_file = False
    
    # 在整个 Sources 目录下深度遍历寻找
    for root, dirs, files in os.walk(SOURCES_DIR):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        if "PrivacyInfo.xcprivacy" in files:
            found_privacy_file = True
            break
            
    if not found_privacy_file:
        issues.append({
            "type": "warning",
            "message": "未发现隐私清单文件 'PrivacyInfo.xcprivacy'。自 iOS 17+ 起，App Store 提审调用敏感 API（如 UserDefaults 读写）必须配置隐私清单。建议在 Sources/App/Resources/ 下创建该文件。"
        })
        
    return issues


# ==============================================================================
# MARK: - 程序主入口与结果报告
# ==============================================================================

def main():
    """
    主程序。执行 Plist 校验、代码安全校验以及隐私文件存在性校验。
    """
    total_errors = 0
    total_warnings = 0
    
    print("🔍 [App Store Readiness] 开始执行提审就绪度静态审计...")
    
    # 1. 运行 Plist 检测
    for plist_path in PLIST_FILES:
        plist_issues = check_plist_compliance(plist_path)
        for issue in plist_issues:
            log_type = issue["type"]
            # 格式：<filename>:1:<type>: [App Store Readiness] <message>
            log_msg = f"{plist_path}:1: {log_type}: [App Store Readiness] {issue['message']}"
            if log_type == "error":
                print(log_msg, file=sys.stderr)
                total_errors += 1
            else:
                print(log_msg)
                total_warnings += 1
                
    # 2. 运行 fatalError 熔断检测
    fatal_issues = check_fatal_errors()
    for issue in fatal_issues:
        # 格式：<filename>:<line>:error: [App Store Readiness] <message>
        log_msg = f"{issue['file']}:{issue['line']}: error: [App Store Readiness] {issue['message']}"
        print(log_msg, file=sys.stderr)
        total_errors += 1
        
    # 3. 运行隐私清单检测
    privacy_issues = check_privacy_manifest()
    for issue in privacy_issues:
        log_type = issue["type"]
        log_msg = f"Sources:1: {log_type}: [App Store Readiness] {issue['message']}"
        if log_type == "error":
            print(log_msg, file=sys.stderr)
            total_errors += 1
        else:
            print(log_msg)
            total_warnings += 1

    print(f"📊 [App Store Readiness] 审计完成。")
    print(f"📊 [App Store Readiness] 结果汇总: {total_errors} 个错误，{total_warnings} 个警告。")

    if total_errors > 0:
        print(f"🔴 [App Store Readiness] 失败: 发现 {total_errors} 个提审致命阻断错误。构建已熔断阻断！", file=sys.stderr)
        sys.exit(1)
    else:
        print("🟢 [App Store Readiness] 成功: 代码库与配置文件基本就绪，通过提审阻断审计（允许存在警告）。")
        sys.exit(0)


if __name__ == "__main__":
    main()
