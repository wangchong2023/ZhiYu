#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
check-pipeline-perf-regression.py

作者: Wang Chong (Senior Architect & Advanced Developer)
功能说明: 性能回归分析门禁。
         提取最新的测试产物 .xcresult，与已存盘的基线比较，若耗时超出 tolerance_pct 比例，
         则抛出非零退出码熔断 CI 提交流程。
"""

import os
import sys
import json
import subprocess

# 项目根路径与各项路径常量定义
PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
BASELINE_DIR = os.path.join(PROJECT_DIR, "build", ".perf_baselines")
XCRESULT_DIR = os.path.join(PROJECT_DIR, "build", "DerivedData-ios", "Logs", "Test")
TEMP_JSON = os.path.join(PROJECT_DIR, "build", "xcresult_check_raw.json")
DETAIL_JSON = os.path.join(PROJECT_DIR, "build", "xcresult_check_detail.json")

MS_PER_SECOND = 1000.0
PERCENT_CONVERSION = 100.0


def find_latest_xcresult():
    """在测试日志目录中按修改时间检索最新的 xcresult 报告文件包."""
    if not os.path.exists(XCRESULT_DIR):
        return None
    candidates = []
    for root, dirs, _ in os.walk(XCRESULT_DIR):
        for d in dirs:
            if d.endswith(".xcresult"):
                full_path = os.path.join(root, d)
                try:
                    mtime = os.path.getmtime(full_path)
                except OSError:
                    mtime = 0
                candidates.append((mtime, full_path))
    if not candidates:
        return None
    # 按修改时间降序排列，返回最新的
    candidates.sort(key=lambda x: x[0], reverse=True)
    return candidates[0][1]


def find_tests_ref(node):
    """递归检索 ActionInvocationRecord 节点中 testsRef 的 ID."""
    if isinstance(node, dict):
        if 'testsRef' in node:
            return node['testsRef'].get('id', {}).get('_value')
        for _, v in node.items():
            res = find_tests_ref(v)
            if res:
                return res
    elif isinstance(node, list):
        for item in node:
            res = find_tests_ref(item)
            if res:
                return res
    return None


def get_tests_ref_id(xcresult_path):
    """解析第一层 ActionInvocationRecord 获取测试结果引用 ID (testsRef)."""
    try:
        # 确保 build 目录已存在
        os.makedirs(os.path.dirname(TEMP_JSON), exist_ok=True)
        with open(TEMP_JSON, "w") as out_f:
            subprocess.check_call(
                ["xcrun", "xcresulttool", "get", "object", "--legacy", "--path", xcresult_path, "--format", "json"],
                stdout=out_f,
                stderr=subprocess.DEVNULL
            )
        with open(TEMP_JSON, "r", encoding="utf-8") as f:
            raw_data = json.load(f)
    except Exception as e:
        print(f"❌ 警告: 无法获取第一层测试动作摘要数据: {e}")
        return None
    finally:
        if os.path.exists(TEMP_JSON):
            os.remove(TEMP_JSON)

    return find_tests_ref(raw_data)


def parse_metadata(node, current_runs):
    """递归提取 ActionTestMetadata 节点，计算其耗时并存入字典."""
    if not isinstance(node, dict):
        return
    if node.get('_type', {}).get('_name') == 'ActionTestMetadata':
        name = node.get('name', {}).get('_value', '')
        duration = node.get('duration', {}).get('_value', '')
        if name and duration:
            clean_name = name.split('()')[0]
            current_runs[clean_name] = float(duration) * MS_PER_SECOND  # 转为毫秒
    for _, val in node.items():
        if isinstance(val, dict):
            parse_metadata(val, current_runs)
        elif isinstance(val, list):
            for item in val:
                parse_metadata(item, current_runs)


def parse_metadata_durations(xcresult_path, ref_id):
    """解析第二层测试计划运行总结，提取具体的测试用例及其耗时 (毫秒)."""
    try:
        os.makedirs(os.path.dirname(DETAIL_JSON), exist_ok=True)
        with open(DETAIL_JSON, "w") as out_f:
            subprocess.check_call(
                ["xcrun", "xcresulttool", "get", "object", "--legacy", "--path", xcresult_path, "--id", ref_id, "--format", "json"],
                stdout=out_f,
                stderr=subprocess.DEVNULL
            )
        with open(DETAIL_JSON, "r", encoding="utf-8") as f:
            detail_data = json.load(f)
    except Exception as e:
        print(f"❌ 警告: 无法使用 xcresulttool 获取测试详细数据: {e}")
        return {}
    finally:
        if os.path.exists(DETAIL_JSON):
            os.remove(DETAIL_JSON)

    current_runs = {}
    parse_metadata(detail_data, current_runs)
    return current_runs


def check_baseline_regression(current_runs):
    """比对当前测试耗时与基线数据，如果超出限额记录倒退."""
    failed_tests = []
    checked_count = 0
    for test_name, current_ms in current_runs.items():
        baseline_file = os.path.join(BASELINE_DIR, f"{test_name}.json")
        if not os.path.exists(baseline_file):
            continue
            
        with open(baseline_file, "r", encoding="utf-8") as f:
            baseline = json.load(f)
            
        base_ms = baseline["baseline_ms"]
        tolerance = baseline["tolerance_pct"]
        max_allowed_ms = base_ms * (1 + tolerance / PERCENT_CONVERSION)
        checked_count += 1
        
        # 性能是否倒退判断
        if current_ms > max_allowed_ms:
            diff_ms = current_ms - base_ms
            diff_pct = (diff_ms / base_ms) * PERCENT_CONVERSION
            print(f"  ❌ 性能倒退: {test_name}")
            print(f"     当前: {current_ms:.2f} ms | 基线: {base_ms:.2f} ms")
            print(f"     超出阈值: {diff_pct:.2f}% (容忍比例: {tolerance}%)")
            failed_tests.append((test_name, base_ms, current_ms, diff_pct))
        else:
            print(f"  ✅ 符合基线 -> {test_name}: {current_ms:.2f} ms (基线: {base_ms:.2f} ms)")

    return failed_tests, checked_count


def main():
    """
    主程序，通过比较当前运行耗时与基线数据，执行性能回归测试校验与拦截。
    """
    # 1. 确认性能基线目录已初始化且不为空
    if not os.path.isdir(BASELINE_DIR) or not os.listdir(BASELINE_DIR):
        print("⚠️  [Performance] 无性能基线数据，跳过比对检测。")
        return 0

    # 2. 检索最新的 xcresult
    xcresult_path = find_latest_xcresult()
    if not xcresult_path:
        print("⚠️  [Performance] 未定位到测试 xcresult 报告，跳过耗时回归拦截。")
        return 0

    print(f"📊 [Performance] 正在对比测试耗时基线，源报告: {os.path.basename(xcresult_path)}")

    # 3. 提取 testsRef ID
    ref_id = get_tests_ref_id(xcresult_path)
    if not ref_id:
        print("⚠️  [Performance] 未在 xcresult 中发现任何 testsRef 引用，跳过性能比对。")
        return 0

    # 4. 解析详细耗时数据
    current_runs = parse_metadata_durations(xcresult_path, ref_id)
    if not current_runs:
        print("⚠️  [Performance] 无法提取到任何有效的用例耗时指标，跳过性能比对。")
        return 0

    # 5. 执行基线比对与判定
    failed_tests, checked_count = check_baseline_regression(current_runs)

    # 6. 熔断处理
    if failed_tests:
        print(f"\n💥 [Performance] 性能回归拦截: 共有 {len(failed_tests)} 个核心用例耗时严重超出基线红线！")
        return 1

    print(f"🎉 [Performance] 性能基线指纹比对通过，无回归威胁 (共比对了 {checked_count} 个用例)。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
