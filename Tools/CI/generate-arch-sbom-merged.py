#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 版权所有 (c) 2026 ZhiYu。保留所有权利。
#
# 职责说明: 本脚本用于合并 Package.resolved 的生成结果与 Syft 扫描生成的 SBOM 文件。
# 目的是补充和丰富第三方包的 License 开源许可协议信息，使 SBOM 更加完整。
#

"""合并 ci-generate-spm-sbom-single.py 输出与 Syft 扫描结果，补齐 License 信息."""
import json, os, sys

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))

def find_license_in_syft(syft_path: str, package_name: str) -> str:
    """
    在 Syft 生成的 CycloneDX 报告中查找对应包的 License。
    
    参数:
        syft_path (str): Syft 导出的 JSON 报文路径
        package_name (str): 需要查找的第三方 SPM 依赖包名称
        
    返回:
        str: 找到的 License 标识名，未找到则返回 "NOASSERTION"
    """
    if not os.path.exists(syft_path) or os.path.getsize(syft_path) == 0:
        return "NOASSERTION"
    try:
        with open(syft_path, "r", encoding="utf-8") as f:
            syft = json.load(f)
    except json.JSONDecodeError as e:
        print(f"⚠️ [SBOM Merge] 解析 Syft 报告失败 (JSON 格式损坏): {e}", file=sys.stderr)
        return "NOASSERTION"
    except Exception as e:
        print(f"⚠️ [SBOM Merge] 读取 Syft 报告遭遇异常: {e}", file=sys.stderr)
        return "NOASSERTION"

    for comp in syft.get("components", []):
        if comp.get("name", "").lower() == package_name.lower():
            licenses = comp.get("licenses", [])
            if licenses:
                return licenses[0].get("license", {}).get("id", "NOASSERTION")
    return "NOASSERTION"

def main():
    """
    主入口函数。读取 ci-generate-spm-sbom-single.py 生成的 sbom.spdx.json 文件和 Syft
    生成的 syft.cdx.json 文件，遍历所有依赖项，寻找缺失 License 的包并从 Syft 结果中进行补充。
    最后将丰富后的 SBOM 回写。
    """
    spdx_path = os.path.join(PROJECT_DIR, "build", "sbom.spdx.json")
    syft_path = os.path.join(PROJECT_DIR, "build", "syft.cdx.json")
    if not os.path.exists(spdx_path):
        print("❌ sbom.spdx.json 不存在，请先运行 ci-generate-spm-sbom-single.py", file=sys.stderr)
        sys.exit(1)
    with open(spdx_path) as f:
        spdx = json.load(f)
    enriched = 0
    for pkg in spdx.get("packages", []):
        name = pkg.get("name", "")
        if pkg.get("licenseConcluded") == "NOASSERTION":
            lic = find_license_in_syft(syft_path, name)
            if lic != "NOASSERTION":
                pkg["licenseConcluded"] = lic
                pkg["licenseDeclared"] = lic
                enriched += 1
    with open(spdx_path, "w") as f:
        json.dump(spdx, f, indent=2)
    print(f"✅ SBOM 已丰富: {enriched} 个包的 License 从 Syft 补充", file=sys.stderr)
    print(spdx_path)

if __name__ == "__main__":
    main()
