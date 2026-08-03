#!/bin/bash
# ==============================================================================
# 项目名称: ZhiYu (智宇 iOS 客户端)
# 脚本名称: Tools/ci/generate-pipeline-perf-baseline.sh
# 脚本功能: 物理提取 .xcresult 的测试耗时数据，并自动持久化写入本地性能基线 JSON 文件。
# ==============================================================================
set -euo pipefail

# 1. 性能基线存储物理路径
BASELINE_DIR="$(cd "$(dirname "$0")/../../build/.perf_baselines" && pwd)"
mkdir -p "$BASELINE_DIR"

# 2. 定位最新的测试产物 (.xcresult)
XCRESULT=$(find build/DerivedData-ios/Logs/Test -name '*.xcresult' -type d 2>/dev/null | head -1)

if [ -z "$XCRESULT" ]; then
    echo "❌ 错误: 未能在 build 目录下定位到任何 .xcresult 文件，请先运行单元测试！"
    exit 1
fi

echo "📊 正在从测试包中提取性能数据: $XCRESULT"

# 3. 调用系统底座工具 xcresulttool 获取原始测试动作摘要 JSON 并存入临时文件
TEMP_JSON="build/xcresult_raw.json"
xcrun xcresulttool get object --legacy --path "$XCRESULT" --format json > "$TEMP_JSON"

# 4. 用 Python 解析第一层 JSON 获取 testsRef ID，然后提取第二层测试用例详细数据并写入基线
python3 -c "
import json, sys, os, subprocess

temp_json = '$TEMP_JSON'
xcresult = '$XCRESULT'
baseline_dir = '$BASELINE_DIR'

with open(temp_json, 'r', encoding='utf-8') as f:
    raw_data = json.load(f)

# 递归寻找 testsRef ID
def find_tests_ref(node):
    if isinstance(node, dict):
        if 'testsRef' in node:
            ref_id = node['testsRef'].get('id', {}).get('_value')
            if ref_id:
                return ref_id
        for k, v in node.items():
            res = find_tests_ref(v)
            if res:
                return res
    elif isinstance(node, list):
        for item in node:
            res = find_tests_ref(item)
            if res:
                return res
    return None

ref_id = find_tests_ref(raw_data)
if not ref_id:
    print('⚠️  未在 xcresult 中发现任何 testsRef 引用，可能本次运行无测试。')
    sys.exit(0)

# 调用 xcresulttool 提取第二层 JSON 详情
detail_json_path = 'build/xcresult_detail.json'
try:
    with open(detail_json_path, 'w') as out_f:
        subprocess.check_call(
            ['xcrun', 'xcresulttool', 'get', 'object', '--legacy', '--path', xcresult, '--id', ref_id, '--format', 'json'],
            stdout=out_f,
            stderr=subprocess.DEVNULL
        )
    with open(detail_json_path, 'r', encoding='utf-8') as f:
        detail_data = json.load(f)
finally:
    if os.path.exists(detail_json_path):
        os.remove(detail_json_path)

# 递归解析详细数据，提取 ActionTestMetadata 耗时
def extract_metadata(node):
    results = {}
    if not isinstance(node, dict):
        return results
    if node.get('_type', {}).get('_name') == 'ActionTestMetadata':
        name = node.get('name', {}).get('_value', '')
        duration = node.get('duration', {}).get('_value', '')
        if name and duration:
            # 清理测试方法名后的括号（如 testMethod() -> testMethod）
            clean_name = name.split('()')[0]
            results[clean_name] = float(duration)
    for key, val in node.items():
        if isinstance(val, dict):
            results.update(extract_metadata(val))
        elif isinstance(val, list):
            for item in val:
                results.update(extract_metadata(item))
    return results

test_durations = extract_metadata(detail_data)
written_count = 0
for test_name, duration_sec in test_durations.items():
    # 过滤掉耗时极短的非性能测试或小单测（此处容忍大于 0.01 秒的测试作为基线，亦可调整）
    if duration_sec < 0.01:
        continue
    
    baseline_file = os.path.join(baseline_dir, f'{test_name}.json')
    payload = {
        'test_name': test_name,
        'baseline_ms': round(duration_sec * 1000, 2),
        'tolerance_pct': 10,
        'last_updated': '$(date -u +%Y-%m-%dT%H:%M:%SZ)'
    }
    with open(baseline_file, 'w', encoding='utf-8') as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
    print(f'   ✓ 写入基线 -> {test_name}: {payload[\"baseline_ms\"]} ms')
    written_count += 1

print(f'📊 共物理写入 {written_count} 个测试基线文件。')
"
rm -f "$TEMP_JSON"
echo "✅ 性能基线文件物理更新完成，存放在: $BASELINE_DIR"
