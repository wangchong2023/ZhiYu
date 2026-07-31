#!/bin/bash
#
# 版权所有 (c) 2026 ZhiYu。保留所有权利。
#
# 职责说明:
# 本脚本用于在 CI 流水线构建或本地提交前，集中执行项目中全部静态分析和安全合规检查。
# 采用多进程并发设计以最大化 CPU 利用率，缩短开发者的等待时间，并规范日志存储及 Xcode 格式输出。
# 任何一项检查若失败，脚本将立即以非零状态码退出并熔断后续流程。
#

set -uo pipefail

# 自动探测 Python 解释器：优先本地 venv（含 radon），CI 环境回退到系统 python3
# CI 环境须在 static-analysis step 中预先执行 pip3 install radon
if [ -x "./env/venv/bin/python3" ]; then
    PYTHON3="./env/venv/bin/python3"
else
    PYTHON3="python3"
fi
export PYTHON3

LOG_DIR="build/static_analysis_logs"
mkdir -p "$LOG_DIR"

echo "====== Static Analysis (Consolidated & Parallel) ======"
echo ""

EXIT_CODE=0

# 并行任务运行及日志重定向包装器
run_parallel_task() {
    local name="$1"
    local log_name="$2"
    local cmd="$3"
    
    local log_file="$LOG_DIR/${log_name}.log"
    echo "  [START] $name..."
    eval "$cmd" > "$log_file" 2>&1
    local status=$?
    
    if [ $status -ne 0 ]; then
        echo "  ❌ [FAILED] $name (退出状态码: $status)"
        echo "     👉 错误日志详见: file://$PWD/$log_file"
        echo "--------------------------------------------------"
        # 提取关键报错行输出，确保 Xcode 可双击跳转定位
        grep -E "error:|warning:|Exception:|PyCompileError:|L[0-9]+:" "$log_file" || tail -n 10 "$log_file"
        echo "--------------------------------------------------"
        return $status
    else
        echo "  ✅ [PASSED] $name"
        return 0
    fi
}

# 并发执行所有的独立检查
run_parallel_task "Architecture Dependency" "arch_dependency" "python3 Tools/Gatekeeper/Architecture/check_architecture_dependency.py" & pid1=$!
run_parallel_task "Domain Purity" "domain_purity" "python3 Tools/Gatekeeper/Architecture/check_domain_purity.py" & pid2=$!
run_parallel_task "DI Test Setup" "di_test_setup" "python3 Tools/Gatekeeper/Architecture/check_test_di_setup.py" & pid3=$!
run_parallel_task "Root Hygiene" "root_hygiene" "python3 Tools/Gatekeeper/Sanity/check_root_hygiene.py" & pid4=$!
run_parallel_task "Magic Numbers & Strings" "magic_numbers" "python3 Tools/Gatekeeper/Compliance/check_magic_numbers.py" & pid5=$!
run_parallel_task "Layer Markers" "layer_markers" "bash Tools/Gatekeeper/Architecture/check_layer_markers.sh" & pid6=$!
run_parallel_task "Unsafe String.Index Scan" "unsafe_string_index" "python3 Tools/Gatekeeper/Sanity/check_unsafe_string_index.py" & pid7=$!
run_parallel_task "Docs & Config Integrity" "docs_and_configs" "python3 Tools/Gatekeeper/Sanity/check_docs_and_configs.py" & pid8=$!
run_parallel_task "SPM Dependencies Audit" "spm_audit" "python3 Tools/CI/Analyze/audit_spm_dependencies.py" & pid9=$!
run_parallel_task "SPM Integrity" "spm_integrity" "bash Tools/CI/Analyze/verify_spm_integrity.sh" & pid10=$!
run_parallel_task "Tools Quality Gatekeeper" "tools_quality" "$PYTHON3 Tools/Gatekeeper/Sanity/check_scripts_quality.py" & pid11=$!
run_parallel_task "Swift Quality Guard" "swift_quality" "$PYTHON3 Tools/Gatekeeper/Sanity/check_swift_quality.py" & pid12=$!
run_parallel_task "Cyclomatic Complexity" "complexity" "python3 Tools/Gatekeeper/Compliance/check_complexity.py" & pid13=$!
run_parallel_task "Localization Compliance" "localization" "python3 Tools/Gatekeeper/Compliance/check_localization.py" & pid14=$!
run_parallel_task "SwiftLint" "swiftlint" "swiftlint --strict --reporter github-actions-logging 2>/dev/null || swiftlint --strict" & pid15=$!
run_parallel_task "Hardcoded Secrets" "hardcoded_secrets" "python3 Tools/Gatekeeper/Release/check_hardcoded_secrets.py" & pid16=$!
run_parallel_task "Duplicate Code (jscpd)" "duplicate_code" "python3 Tools/Gatekeeper/Sanity/check_duplicate_code.py" & pid17=$!
run_parallel_task "Commit Signature" "signature" "bash Tools/CI/Analyze/verify_commit_signature.sh" & pid18=$!
run_parallel_task "SBOM Generation & Syft Scan" "sbom_generation" "(python3 Tools/CI/Analyze/generate_sbom.py && (syft . --exclude ./build --exclude ./env -o cyclonedx-json=build/syft.cdx.json 2>/dev/null || echo Syft skipped) && python3 Tools/CI/Analyze/merge_sbom.py)" & pid19=$!
run_parallel_task "Heuristic View Duplication" "view_duplication" "python3 Tools/Gatekeeper/Architecture/check_view_duplication.py" & pid20=$!

# 等待所有后台任务，并收拢退出状态
wait $pid1 || EXIT_CODE=1
wait $pid2 || EXIT_CODE=1
wait $pid3 || EXIT_CODE=1
wait $pid4 || EXIT_CODE=1
wait $pid5 || EXIT_CODE=1
wait $pid6 || EXIT_CODE=1
wait $pid7 || EXIT_CODE=1
wait $pid8 || EXIT_CODE=1
wait $pid9 || EXIT_CODE=1
wait $pid10 || EXIT_CODE=1
wait $pid11 || EXIT_CODE=1
wait $pid12 || EXIT_CODE=1
wait $pid13 || EXIT_CODE=1
wait $pid14 || EXIT_CODE=1
wait $pid15 || EXIT_CODE=1
wait $pid16 || EXIT_CODE=1
wait $pid17 || EXIT_CODE=1
wait $pid18 || EXIT_CODE=1
wait $pid19 || EXIT_CODE=1
wait $pid20 || EXIT_CODE=1

echo ""
if [ $EXIT_CODE -ne 0 ]; then
    echo "❌ [Static Analysis] 静态分析未通过！部分合规检查项存在缺陷，请修复上述报错。"
    exit 1
else
    echo "====== ✓ Static Analysis PASSED ======"
    exit 0
fi
