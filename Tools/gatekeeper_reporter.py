# -*- coding: utf-8 -*-
# NAMING-bypass: 兼容层别名文件，供现有审计脚本无缝导入 GatekeeperReporter
import importlib.util
from pathlib import Path

_script_path = Path(__file__).parent / "scripts" / "generate-quality-report.py"
_spec = importlib.util.spec_from_file_location("generate_quality_report", _script_path)
_mod = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(_mod)

GatekeeperReporter = _mod.GatekeeperReporter
