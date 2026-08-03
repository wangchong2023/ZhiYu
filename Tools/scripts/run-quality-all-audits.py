#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
#  run-quality-all-audits.py
#  ZhiYu
#
#  Created by Antigravity on 2026/08/02.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关
#  核心职责：统一总控调度运行全量 Gatekeeper 门禁静态审计项，向 Xcode IDE/CI 提供统一的诊断曝光与熔断出口。
#

import os
import sys
import subprocess

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))

# 全量门禁审计步骤定义 (名称, 执行命令行)
GATEKEEPER_AUDIT_STEPS = [
    ("SwiftLint 静态规范审计", ["bash", "Tools/ios/assert-code-swiftlint.sh"]),
    ("Domain Purity 领域层纯净化审计", ["python3", "Tools/ios/audit-arch-domain-purity.py"]),
    ("L10n 本地化合规审计", ["python3", "Tools/ios/check-code-localization.py"]),
    ("Prompt 治理与安全合规审计", ["python3", "Tools/ios/check-code-prompt-governance.py"]),
    ("存储层常量提取审计", ["python3", "Tools/ios/check-code-storage-constants.py"]),
    ("魔鬼数字提取审计", ["python3", "Tools/ios/audit-design-magic-numbers.py"]),
    ("硬编码敏感信息扫描", ["python3", "Tools/ios/assert-release-hardcoded-secrets.py"]),
    ("HIG 视觉规范度审计", ["python3", "Tools/ios/check-design-hig.py"]),
    ("App Store 上架就绪度审计", ["python3", "Tools/ios/check-release-appstore.py"]),
    ("L0-L3 单向依赖架构审计", ["python3", "Tools/ios/audit-arch-dependency.py"]),
    ("Tools 脚本静态质量审计", ["python3", "Tools/scripts/audit-quality-scripts.py"]),
    ("跨平台 Layout 布局规范审计", ["python3", "Tools/ios/check-design-layout.py"]),
    ("DI 注入安全与崩溃风险审计", ["python3", "Tools/ios/check-code-di-crash-risk.py"]),
    ("代码重复率静态检测 (jscpd)", ["python3", "Tools/ios/assert-code-duplication.py", "--local"]),
    ("视图重复启发式提取审计", ["python3", "Tools/ios/audit-arch-view-duplication.py"]),
    ("开源库适配器逻辑隔离审计", ["python3", "Tools/ios/check-arch-opensource-adapters.py"]),
    ("开源库适配器物理归位审计", ["python3", "Tools/ios/check-arch-opensource-placement.py"]),
    ("死代码与迁移残留审计 (Periphery)", ["python3", "Tools/ios/audit-code-dead-code.py"]),
]


def main():
    """主入口：按序调度执行全量 Gatekeeper 审计，精准暴露步骤与致命错误。"""
    os.chdir(PROJECT_DIR)
    total_steps = len(GATEKEEPER_AUDIT_STEPS)
    failed_steps = []

    print(f"\n========================================================================")
    print(f"🛡️  [Gatekeeper Orchestrator] 启动全量门禁质量静态审计 ({total_steps} 项)...")
    print(f"========================================================================\n")

    for index, (step_name, cmd) in enumerate(GATEKEEPER_AUDIT_STEPS, start=1):
        print(f"▶️  [{index}/{total_steps}] 正在运行: {step_name}...")
        try:
            result = subprocess.run(cmd, cwd=PROJECT_DIR, check=False)
            if result.returncode != 0:
                print(f"❌ [{index}/{total_steps}] {step_name} 审计失败 (Exit Code: {result.returncode})")
                failed_steps.append((step_name, result.returncode))
            else:
                print(f"✅ [{index}/{total_steps}] {step_name} 通过")
        except Exception as e:
            print(f"❌ [{index}/{total_steps}] {step_name} 执行异常: {e}")
            failed_steps.append((step_name, 1))

    print(f"\n========================================================================")
    if failed_steps:
        print(f"❌ [Gatekeeper Summary] 门禁全量审计完成，共有 {len(failed_steps)} 项检测未通过：")
        for name, code in failed_steps:
            print(f"   • {name} (Exit Code: {code})")
        print(f"========================================================================\n")
        sys.exit(1)
    else:
        print(f"🟢 [Gatekeeper Summary] 恭喜！全量 {total_steps} 项门禁质量审计 100% 顺利通过！")
        print(f"========================================================================\n")
        sys.exit(0)


if __name__ == "__main__":
    main()
