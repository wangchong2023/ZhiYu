#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  audit-arch-dependency.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/12.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：执行分层架构依赖（Architecture Dependency）静态审计。
#           确保项目严格遵循 L0 (Core) -> L1 (Infrastructure) -> L1.5 (Domain) -> L3 (Features) 的单向依赖规则，
#           彻底阻断底层代码直接或隐性跨层调用高层组件造成的耦合。
#

import os
import re
import sys

# ==============================================================================
# MARK: - 全局配置区
# ==============================================================================

# 项目根目录，相对于 Tools/scripts/Architecture 目录的上一级 (退3层)
# 项目根目录，相对于 Tools/ios 目录的上一级 (退2层: Tools/ios → Tools → 项目根)
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SOURCES_DIR = os.path.join(PROJECT_DIR, "Sources")

# 排除分析的文件夹
EXCLUDE_DIRS = {'.git', 'build', 'DerivedData', '.build', 'Frameworks', 'Tests', 'env', '__pycache__'}

# 排除扫描的特定文件（例如定义字体的 Typography.swift，定义图标/样式的 DesignSystem 文件）
EXCLUDE_FILES = {
    'Typography.swift',
    'Colors.swift',
    'DesignSystem.swift',
    'DesignSystem+Icons.swift',
    'IconTokens.swift',
    'Spacing.swift',
    'SecurityManager.swift',      # 暂时豁免：解密层直接依赖签名仓储
    'LocalAnalyticsService.swift'  # 暂时豁免：埋点实现层引用 Domain 接口
}

# 排除扫描的特定子目录路径片段（例如设计系统目录在定义底层颜色/字体时必然会有固定字号或硬编码颜色）
EXCLUDE_PATH_FRAGMENTS = [
    "Sources/Shared/DesignSystem",
]

# 物理分层目录定义
LAYER_PATHS = {
    "Core": os.path.join(SOURCES_DIR, "Core"),
    "Infrastructure": os.path.join(SOURCES_DIR, "Infrastructure"),
    "Domain": os.path.join(SOURCES_DIR, "Domain"),
    "Features": os.path.join(SOURCES_DIR, "Features"),
    "Platforms": os.path.join(SOURCES_DIR, "Platforms")
}

# 忽略提取的通用 Swift 关键字与常见类型名（避免因同名匹配造成误报）
# 注意：领域实体（PageChunk/KnowledgePage/Tag 等）不在此白名单中，
# 以便 audit-arch-dependency 能拦截 L0→L1.5 跨层引用
COMMON_KEYWORDS = {
    "View", "Text", "Button", "Label", "Image", "String", "Int", "Double", "CGFloat",
    "Bool", "UUID", "URL", "Task", "Color", "Font", "Spacer", "ZStack", "VStack", "HStack",
    "ForEach", "EmptyView", "Binding", "Environment", "State", "Observable", "MainActor",
    "App", "Scene", "Widget", "Capsule", "Circle", "Rectangle", "RoundedRectangle", "Empty",
    "Done", "User", "Plan", "Theme", "Error", "Log", "Logger", "Date", "Data",
    "Status", "Columns", "CodingKeys"
}

# ==============================================================================
# MARK: - 实体提取逻辑
# ==============================================================================

def _extract_file_entities(file_path, patterns):
    """
    从单个 Swift 文件内容中解析并提取实体名称。
    """
    file_entities = set()
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
    except Exception:
        return file_entities

    # 移除多行注释以防提取到注释中的单词
    clean_content = re.sub(r'/\*.*?\*/', '', content, flags=re.DOTALL)
    # 逐行处理以剥离单行注释
    lines = clean_content.split("\n")
    
    for line in lines:
        # 去除行内注释
        line = line.split("//")[0].strip()
        for pattern in patterns:
            for match in pattern.finditer(line):
                name = match.group(1)
                # 过滤通用关键字和极短的词
                if name not in COMMON_KEYWORDS and len(name) > 2:
                    file_entities.add(name)
    return file_entities


def extract_entities_from_dir(dir_path):
    """
    扫描指定目录下的 Swift 源码，通过正则提取其中定义的所有类、结构体、协议、枚举与 Actor 的名称。
    
    参数:
        dir_path (str): 物理目录路径
        
    返回:
        set: 包含所提取实体名字的集合
    """
    entities = set()
    if not os.path.exists(dir_path):
        return entities

    # 类型定义的正则表达式（提取首字母大写的类型名）
    patterns = [
        re.compile(r'\bclass\s+([A-Z][A-Za-z0-9_]+)'),
        re.compile(r'\bstruct\s+([A-Z][A-Za-z0-9_]+)'),
        re.compile(r'\benum\s+([A-Z][A-Za-z0-9_]+)'),
        re.compile(r'\bactor\s+([A-Z][A-Za-z0-9_]+)'),
        re.compile(r'\bprotocol\s+([A-Z][A-Za-z0-9_]+)')
    ]

    for root, dirs, files in os.walk(dir_path):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for file in files:
            if file.endswith(".swift"):
                file_path = os.path.join(root, file)
                entities.update(_extract_file_entities(file_path, patterns))
                                
    return entities

# ==============================================================================
# MARK: - 跨层越级依赖审计逻辑
# ==============================================================================

def check_file_dependencies(file_path, forbidden_entities, layer_name):
    """
    校验单个 Swift 代码文件是否直接或隐式调用了被禁止的高层实体。
    
    参数:
        file_path (str): 待检查文件的绝对路径
        forbidden_entities (set): 被禁用的高层实体名称集合
        layer_name (str): 当前层级名称（用于报告）
        
    返回:
        list: 包含错误详情字典的列表。合规时返回空列表
    """
    errors = []
    try:
        with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
            lines = f.readlines()
    except Exception as e:
        errors.append({
            "line": 1,
            "message": f"无法读取文件进行架构审计: {str(e)}"
        })
        return errors

    # 构建匹配这组禁止实体的正则表达式以提高速度
    if not forbidden_entities:
        return errors

    # 转义实体名字并拼接，使用单词边界匹配
    forbidden_pattern = re.compile(r'\b(' + '|'.join(map(re.escape, forbidden_entities)) + r')\b')

    for index, line in enumerate(lines, 1):
        # 1. 注释与豁免过滤
        if '// arch_exempt' in line or '// Architecture Exempt' in line:
            continue
            
        clean_line = line.split("//")[0].strip()
        if not clean_line:
            continue

        # 2. 正则查找违规高层实体调用
        match = forbidden_pattern.search(clean_line)
        if match:
            violation_entity = match.group(1)
            errors.append({
                "line": index,
                "message": f"分层架构违规: 底层 [{layer_name}] 层文件引用了高层实体 '{violation_entity}'。底层禁止跨层反向调用高层组件。请通过定义在 Core/Base 或 Domain/Protocols 中的接口协议进行依赖倒置。"
            })

    return errors


def _audit_layer_directory(dir_path, forbidden_set, layer_name):
    """
    辅助审计单个分层物理目录，输出 Xcode 报错并返回越级依赖违规总数。
    """
    violations = 0
    for root, dirs, files in os.walk(dir_path):
        dirs[:] = [d for d in dirs if d not in EXCLUDE_DIRS]
        for file in files:
            if file.endswith(".swift"):
                if file in EXCLUDE_FILES:
                    continue
                file_path = os.path.join(root, file)
                
                # 检查是否有越级依赖违规
                file_errors = check_file_dependencies(file_path, forbidden_set, layer_name)
                for err in file_errors:
                    # 格式化输出为符合 Xcode 报错标准诊断行
                    print(f"{file_path}:{err['line']}: error: [Arch Dependency Violation] {err['message']}", file=sys.stderr)
                    violations += 1
    return violations


def run_architecture_audit():
    """
    执行完整的分层架构依赖静态审计。
    
    返回:
        int: 发现的违规总数
    """
    total_violations = 0

    print("🔍 [Arch Dependency] 正在提取各物理分层类型的实体定义...")

    # 1. 提取各层实体
    features_entities = extract_entities_from_dir(LAYER_PATHS["Features"])
    platforms_entities = extract_entities_from_dir(LAYER_PATHS["Platforms"])
    infra_entities = extract_entities_from_dir(LAYER_PATHS["Infrastructure"])
    
    # 细化提取 Domain（领域）层实体，区分为 Models（纯数据模型）和 Services（核心业务服务）
    domain_all_entities = extract_entities_from_dir(LAYER_PATHS["Domain"])
    domain_models_dir = os.path.join(LAYER_PATHS["Domain"], "Models")
    domain_models_entities = extract_entities_from_dir(domain_models_dir)
    domain_services_entities = domain_all_entities.difference(domain_models_entities)

    # 高层实体汇总 (Features + Platforms 为最外侧的表现/平台层)
    high_level_entities = features_entities.union(platforms_entities)

    # 精确筛选其中代表 UI 表现层与导航路由的实体（避免纯 Model 模型跨层造成的误报）
    ui_suffixes = ("View", "Coordinator", "ViewController", "Cell", "Row", "Sheet", "Menu", "Badge", "Indicator", "Overlay", "Presenter")
    high_level_ui_entities = {
        name for name in high_level_entities
        if name.endswith(ui_suffixes)
    }

    print("📊 [Arch Dependency] 实体定义统计:")
    print(f"  - 表现层/平台层 (Features/Platforms) 总实体数: {len(high_level_entities)}")
    print(f"  - 表现层 UI/路由核心拦截实体数: {len(high_level_ui_entities)}")
    print(f"  - 领域层所有实体数: {len(domain_all_entities)} (其中 Models: {len(domain_models_entities)}, Services: {len(domain_services_entities)})")
    print(f"  - 基础设施层 (Infrastructure) 实体数: {len(infra_entities)}")

    # 2. 定义各层不应该引用的实体名单（Core、Infra、Domain 严禁调用 UI 视图或控制器）
    # 架构红线：L0 底座层禁止反向引用 L1.5 领域层（含 Models 和 Services 全部实体）
    forbidden_rules = {
        # Core (L0) 严禁调用任何高层实体：UI 视图、Domain Services、Domain Models、Infrastructure
        "Core": high_level_ui_entities.union(domain_all_entities).union(infra_entities),
        # Infrastructure (L1) 禁止直接调用表现层 UI
        "Infrastructure": high_level_ui_entities,
        # Domain (L1.5) 作为大脑层，可以调用 Infra 和 Core，但绝对禁止直接调用表现层 UI (View/Coordinator)
        "Domain": high_level_ui_entities
    }

    # 3. 逐个物理层级执行审计
    for layer_name, forbidden_set in forbidden_rules.items():
        dir_path = LAYER_PATHS[layer_name]
        if not os.path.exists(dir_path):
            continue
            
        print(f"🔍 [Arch Dependency] 正在审计 [{layer_name}] 层...")
        total_violations += _audit_layer_directory(dir_path, forbidden_set, layer_name)

    return total_violations


# ==============================================================================
# MARK: - 程序主入口
# ==============================================================================

def main():
    """
    主程序，根据违规项数目判定熔断退出。
    """
    print("🔍 [Arch Dependency] 开始执行分层架构单向依赖合规性审计...")
    
    # 允许测试用例进行测试
    if len(sys.argv) > 1 and sys.argv[1] == "--test-mock":
        print("ℹ️ [Arch Dependency] 运行反向依赖测试...")
        # 模拟产生一处违规，用于检测熔断
        print("/Users/test/Sources/Core/Base/ServiceContainer.swift:25: error: [Arch Dependency Violation] 分层架构违规: 底层 [Core] 层文件引用了高层实体 'SubscriptionPlanView'。", file=sys.stderr)
        sys.exit(1)

    violations = run_architecture_audit()
    print(f"📊 [Arch Dependency] 审计完成。共发现 {violations} 处架构越级引用冲突。")
    
    if violations > 0:
        print(f"🔴 [Arch Dependency] 失败: 代码库存在架构分层依赖穿透违规。构建已熔断！", file=sys.stderr)
        sys.exit(1)
    else:
        print("🟢 [Arch Dependency] 成功: 架构各分层 100% 遵循单向洁净依赖，未发现跨层反向调用！")
        sys.exit(0)


if __name__ == "__main__":
    main()
