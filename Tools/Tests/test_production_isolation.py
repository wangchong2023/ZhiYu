# -*- coding: utf-8 -*-
# 系统层级：[Tools] 质量门禁
# 核心职责：验证生产与测试代码的物理隔离边界。
"""测试隔离门禁及 Xcode target 成员关系的回归验证。"""
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT / "Tools/ios"))


def load_gate(name):
    """加载使用连字符命名的现有命令行门禁。"""
    spec = importlib.util.spec_from_file_location(name, REPO_ROOT / "Tools/ios" / f"{name}.py")
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    spec.loader.exec_module(module)
    return module


DEBUG_GATE = load_gate("audit-debug-in-sources")
COUPLING_GATE = load_gate("check-code-test-coupling")
from production_swift_files import production_swift_files


class ProductionGateTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)

    def scan(self, gate, content, path="Sources/App/Core/ZhiYuApp.swift"):
        file = self.root / path
        file.parent.mkdir(parents=True, exist_ok=True)
        file.write_text(content)
        with patch.object(gate, "REPO_ROOT", self.root):
            return gate.scan_file(file)

    def test_entry_point_has_no_implicit_exemption(self):
        findings = self.scan(COUPLING_GATE, 'let token = environment["UITest_InjectAccessToken"]')
        self.assertTrue(findings)
        self.assertTrue(self.scan(DEBUG_GATE, '#if DEBUG\nlet enabled = true\n#endif'))

    def test_nested_endif_does_not_end_outer_debug_scan(self):
        findings = self.scan(DEBUG_GATE, '#if DEBUG\n#if os(iOS)\nlet enabled = true\n#endif\nlet mockToken = "value"\n#endif')
        self.assertIn("FORBIDDEN_DEBUG_LOGIC", [item.rule for item in findings])

    def test_elseif_and_compound_conditions_are_checked(self):
        for content in ('#if os(iOS)\n#elseif DEBUG\nlet mockToken = "value"\n#endif', '#if os(iOS) && DEBUG\nlet mockToken = "value"\n#endif'):
            with self.subTest(content=content):
                self.assertTrue(self.scan(DEBUG_GATE, content))

    def test_logger_permission_does_not_allow_test_logic(self):
        path = "Sources/Core/System/Logger/Logger.swift"
        self.assertFalse(self.scan(DEBUG_GATE, '#if DEBUG\nprint(value)\n#endif', path))
        self.assertTrue(self.scan(DEBUG_GATE, '#if DEBUG\nlet mockToken = "value"\n#endif', path))

    def test_preview_cannot_hide_prior_business_statement(self):
        self.assertTrue(self.scan(DEBUG_GATE, '#if DEBUG\nlet enabled = true\n#Preview { EmptyView() }\n#endif'))
        self.assertFalse(self.scan(DEBUG_GATE, '#if DEBUG\n#Preview { EmptyView() }\n#endif'))

    def test_local_packages_are_scanned_without_build_or_mock_targets(self):
        paths = (
            "Sources/App.swift",
            "Packages/UFPCore/Sources/UFPCore/App.swift",
            "Packages/UFPCore/Sources/UFPCoreTestMocks/Mock.swift",
            "Packages/UFPCore/.build/App.swift",
            "Packages/AppAuth-iOS/Sources/App.swift",
        )
        for relative in paths:
            path = self.root / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.touch()
        actual = {str(path.relative_to(self.root)) for path in production_swift_files(self.root)}
        self.assertEqual(actual, set(paths[:2]))

    def test_platform_layer_no_longer_bypasses_coupling_check(self):
        self.assertTrue(self.scan(COUPLING_GATE, 'let enabled = arguments.contains("--uitesting")', "Sources/Platforms/macOS/Launcher.swift"))

    def test_comments_are_not_test_branches(self):
        self.assertFalse(self.scan(COUPLING_GATE, '// launchArguments contains "--uitesting"'))
        self.assertFalse(self.scan(DEBUG_GATE, '// #if DEBUG\nlet value = true'))


class XcodeMembershipTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        result = subprocess.run(["plutil", "-convert", "json", "-o", "-", str(REPO_ROOT / "ZhiYu.xcodeproj/project.pbxproj")], check=True, capture_output=True, text=True)
        cls.objects = json.loads(result.stdout)["objects"]
        cls.targets = {item["name"]: item for item in cls.objects.values() if item.get("isa") == "PBXNativeTarget"}

    def source_names(self, name):
        target = self.targets[name]
        result = set()
        for phase_id in target["buildPhases"]:
            phase = self.objects[phase_id]
            if phase["isa"] == "PBXSourcesBuildPhase":
                for build_id in phase["files"]:
                    reference = self.objects[self.objects[build_id]["fileRef"]]
                    result.add(Path(reference["path"]).name)
        return result

    def settings(self, name):
        configurations = self.objects[self.targets[name]["buildConfigurationList"]]["buildConfigurations"]
        return [self.objects[item]["buildSettings"] for item in configurations]

    def test_production_has_only_production_entry(self):
        forbidden = {"UITestHostLauncher.swift", "UnitTestHostApp.swift", "UITestRoute.swift", "UITestPolicies.swift", "EphemeralDatabaseBootstrapStrategy.swift"}
        for target in ("ZhiYu", "ZhiYuMac"):
            with self.subTest(target=target):
                sources = self.source_names(target)
                self.assertIn("ProductionAppLauncher.swift", sources)
                self.assertFalse(sources & forbidden)

    def test_production_has_no_test_target_or_mock_product_dependency(self):
        """正式应用不得间接携带测试宿主或独立替身产品。"""
        for name in ("ZhiYu", "ZhiYuMac", "ZhiYuWatch"):
            target = self.targets[name]
            for dependency_id in target.get("dependencies", []):
                dependency = self.objects[dependency_id]
                linked_target = self.objects.get(dependency.get("target"), {})
                self.assertNotIn("Test", linked_target.get("name", ""))
            for product_id in target.get("packageProductDependencies", []):
                self.assertNotIn("TestMocks", self.objects[product_id]["productName"])

    def test_hosts_share_scenes_and_have_distinct_entries(self):
        for target, entry in (("ZhiYuUnitTestHost", "UnitTestHostApp.swift"), ("ZhiYuMacUnitTestHost", "UnitTestHostApp.swift"), ("ZhiYuUITestHost", "UITestHostLauncher.swift"), ("ZhiYuMacUITestHost", "UITestHostLauncher.swift")):
            with self.subTest(target=target):
                sources = self.source_names(target)
                self.assertIn(entry, sources)
                self.assertIn("ZhiYuApp.swift", sources)
                self.assertNotIn("ProductionAppLauncher.swift", sources)
                for settings in self.settings(target):
                    self.assertTrue(settings["PRODUCT_BUNDLE_IDENTIFIER"].startswith("top.izhiyu.testing."))
                    self.assertEqual(settings["CODE_SIGN_ENTITLEMENTS"], "")

    def test_app_modules_have_unique_output_names(self):
        """同时构建正式应用及宿主时，模块产物不得重名。"""
        targets = ("ZhiYu", "ZhiYuMac", "ZhiYuUnitTestHost", "ZhiYuMacUnitTestHost", "ZhiYuUITestHost", "ZhiYuMacUITestHost")
        for configuration in range(len(self.settings("ZhiYu"))):
            module_names = [self.settings(name)[configuration].get("PRODUCT_MODULE_NAME", name) for name in targets]
            self.assertEqual(len(module_names), len(set(module_names)))

    def test_ui_tests_launch_isolated_targets(self):
        for target, host in (("ZhiYuUITests", "ZhiYuUITestHost"), ("ZhiYuMacUITests", "ZhiYuMacUITestHost")):
            for settings in self.settings(target):
                self.assertEqual(settings["TEST_TARGET_NAME"], host)

    def test_unit_tests_use_empty_hosts(self):
        for target, host in (("ZhiYuTests", "ZhiYuUnitTestHost"), ("ZhiYuMacTests", "ZhiYuMacUnitTestHost")):
            for settings in self.settings(target):
                self.assertIn(host, settings["TEST_HOST"])


if __name__ == "__main__":
    unittest.main()
