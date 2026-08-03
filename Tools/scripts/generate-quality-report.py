# -*- coding: utf-8 -*-
#
#  generate-quality-report.py
#  ZhiYu
#
#  Created by Antigravity on 2026/06/28.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  系统层级：[Tools/ios] 守卫网关工具包
#  核心职责：统一管理所有 Gatekeeper 质量审计脚本的缺陷收集、Xcode/CI 标准输出日志格式化及阻断熔断退出。
#

import os
import sys

class GatekeeperReporter:
    """
    统一的质量门禁报告管理器。
    支持自动探测编译环境，统一生成符合 Xcode Log Parser 以及 CI 控制台分析的可视化气泡错误与警告。
    """
    def __init__(self, check_name):
        self.check_name = check_name
        self.issues = []
        self.has_critical = False

    def add_issue(self, filepath, line_no, message, level="ERROR", content=""):
        """
        收集一处审计缺陷。
        
        参数:
            filepath (str): 违规文件的路径
            line_no (int): 发生违规的行号
            message (str): 缺陷描述
            level (str): 严重等级 (ERROR / WARNING)
            content (str): 出问题的关联源码或键值
        """
        self.issues.append({
            "file": filepath,
            "line": line_no,
            "message": message,
            "level": level.upper(),
            "content": content
        })
        if level.upper() in ("ERROR", "CRITICAL"):
            self.has_critical = True

    def report(self, show_summary=True):
        """
        统一输出报告，并根据是否有阻断级缺陷执行退出。
        """
        # 1. 打印详细的 Xcode 诊断格式（使得 Xcode 本地编译、CI 阻断提取时能够识别）
        # 不论在 Xcode 还是 CI，只要有 error: 或 warning:，构建流或 Xcode 本身就能高效提取
        for issue in self.issues:
            lvl = "error" if issue["level"] in ("ERROR", "CRITICAL") else "warning"
            filepath = issue["file"]
            line = issue["line"]
            msg = issue["message"]
            content = issue["content"]
            suffix = f" \"{content}\"" if content else ""
            
            # 格式：file:line: error/warning: [GatekeeperCheck] message
            print(f"{filepath}:{line}: {lvl}: [{self.check_name}] {msg}{suffix}")

        # 2. 打印控制台直观汇总
        if show_summary:
            if self.issues:
                print(f"\n❌ [{self.check_name}] 审计完成：发现 {len(self.issues)} 处不合规缺陷。")
            else:
                print(f"\n✅ [{self.check_name}] 审计通过：符合所有质量合规标准。")

        # 3. 执行退出阻断
        if self.has_critical:
            sys.exit(1)
        else:
            sys.exit(0)
