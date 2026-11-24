# -*- coding: utf-8 -*-
# 系统层级：[Tools] 质量门禁
# 核心职责：验证生产与测试代码的物理隔离边界。
"""枚举主应用及六个本地包的生产 Swift 源文件。"""
from pathlib import Path

LOCAL_PACKAGES = ("UFPCore", "UFPStorage", "UFPDesignSystem", "ZhiYuDomain", "ZhiYuAICore", "ZhiYuFeatures")


def production_swift_files(repo_root: Path):
    """按源目录枚举，排除本地包独立的测试替身 target。"""
    yield from (repo_root / "Sources").rglob("*.swift")
    for package in LOCAL_PACKAGES:
        source_root = repo_root / "Packages" / package / "Sources"
        for path in source_root.rglob("*.swift"):
            if not any(part.endswith("TestMocks") for part in path.relative_to(source_root).parts):
                yield path
