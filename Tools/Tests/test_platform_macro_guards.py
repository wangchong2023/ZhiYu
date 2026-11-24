#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  test_platform_macro_guards.py
#  ZhiYu
#
#  Created by Antigravity on 2026/11/24.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/Tests] 门禁单元测试
#  核心职责：验证平台宏守卫脚本的正则绕过拦截（正向复合/括号/反向 Catalyst）、注释抗误报、
#           Domain/Features canImport 规则与文件级白名单收窄。
#

import importlib.util
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent


def _load_module(name: str, rel_path: str):
    """动态加载 Tools/ios 下带连字符的 Python 审计脚本模块。"""
    spec = importlib.util.spec_from_file_location(name, ROOT / rel_path)
    module = importlib.util.module_from_spec(spec)
    assert spec and spec.loader
    spec.loader.exec_module(module)
    return module


CHECK_MOD = _load_module("check_platform_macros", "Tools/ios/check-code-platform-macros.py")
DIST_MOD = _load_module("audit_platform_macro_dist", "Tools/ios/audit-platform-macro-distribution.py")


class PlatformMacroGuardTests(unittest.TestCase):
    """平台宏守卫脚本的边界与防绕过回归测试。"""

    def test_os_macro_catches_positive_compound_and_parenthesized_bypasses(self):
        """必须拦截正向复合条件、括号包裹及反向 Catalyst 等历史绕过写法。"""
        bypass_samples = [
            "#if DEBUG && os(iOS)",
            "#if canImport(UIKit) && os(iOS)",
            "#if (os(macOS))",
            "#if !(os(watchOS))",
            "#elseif !targetEnvironment(macCatalyst)",
            "    #if canImport(AppKit) || os(macOS)",
        ]
        for sample in bypass_samples:
            cleaned = CHECK_MOD.strip_line_comment(sample)
            self.assertIsNotNone(
                CHECK_MOD.OS_MACRO_PATTERN.search(cleaned),
                f"未能拦截绕过写法: {sample}",
            )
            self.assertIsNotNone(
                DIST_MOD.OS_MACRO_PATTERN.search(cleaned),
                f"分布审计未能拦截绕过写法: {sample}",
            )

    def test_comments_and_allowed_macros_do_not_false_positive(self):
        """注释中的说明性宏、simulator 与纯框架 canImport 不得触发误报。"""
        safe_samples = [
            "// 替代业务层 #if os(watchOS) 占位代码",
            "/// 消除 #if targetEnvironment(macCatalyst) 宏",
            "#if targetEnvironment(simulator)",
            "#if canImport(FoundationModels)",
            "#if DEBUG",
        ]
        for sample in safe_samples:
            cleaned = CHECK_MOD.strip_line_comment(sample)
            self.assertIsNone(
                CHECK_MOD.OS_MACRO_PATTERN.search(cleaned),
                f"误报合法行: {sample}",
            )

    def test_domain_and_new_feature_canimport_detection(self):
        """Domain 层禁止 UI canImport，Features 层禁止新增不在基线中的 UI canImport。"""
        with tempfile.TemporaryDirectory() as tmp:
            tmp_root = Path(tmp)
            domain_file = tmp_root / "Sources" / "Domain" / "BadDomain.swift"
            domain_file.parent.mkdir(parents=True)
            domain_file.write_text("#if canImport(UIKit)\nimport UIKit\n#endif\n", encoding="utf-8")

            hits = CHECK_MOD.scan_pattern_in_dirs(
                [tmp_root / "Sources" / "Domain"],
                CHECK_MOD.UI_CANIMPORT_PATTERN,
                root=tmp_root,
            )
            self.assertEqual(len(hits), 1)
            self.assertEqual(hits[0][0], "Sources/Domain/BadDomain.swift")

    def test_distribution_rejects_new_file_in_shared_uicomponents(self):
        """原目录级白名单收窄后，Shared/UIComponents 下新增含宏文件必须被拦截。"""
        kind, _ = DIST_MOD._classify("Sources/Shared/UIComponents/NewWidgetView.swift")
        self.assertEqual(kind, "violation")
        bridge_kind, _ = DIST_MOD._classify("Sources/Shared/UIComponents/Modifiers/PlatformModifiers.swift")
        self.assertEqual(bridge_kind, "whitelist")


if __name__ == "__main__":
    unittest.main()
