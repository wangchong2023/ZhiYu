#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# 版权所有 (c) 2026 ZhiYu。保留所有权利。
#
# 职责说明: 本脚本用于从 Package.resolved 生成符合 SPDX 2.3 规范的 JSON SBOM 软件物料清单。
# 该文件用于记录项目的第三方 SPM 依赖信息，以供合规性和安全审计使用。
#

"""从 Package.resolved 或 opensource_dependencies.yml 生成 SPDX 2.3 JSON SBOM.

本项目所有 SPM 依赖均为本地路径引用（project.yml 的 path:），
xcodebuild 不会生成 Package.resolved。因此优先解析 Package.resolved，
若不存在则回退到 Config/opensource_dependencies.yml（SSOT）生成 SBOM。
"""
import json, os, sys
from datetime import datetime, timezone

PROJECT_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OPENSRC_DEPS_YML = os.path.join(PROJECT_DIR, "Config", "opensource_dependencies.yml")

def find_resolved():
    paths = [
        os.path.join(PROJECT_DIR, "ZhiYu.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"),
    ]
    for p in paths:
        if os.path.exists(p):
            return p
    for root, dirs, files in os.walk(PROJECT_DIR):
        if "Package.resolved" in files and ".build" not in root:
            return os.path.join(root, "Package.resolved")
    return None

def load_packages_from_yaml():
    """从 Config/opensource_dependencies.yml 解析依赖列表（本地路径依赖回退方案）。

    :return: 依赖列表 [{"name", "version", "repository_url", "license"}] 或 None
    """
    if not os.path.exists(OPENSRC_DEPS_YML):
        return None
    try:
        import yaml
    except ImportError:
        print("⚠️ PyYAML 未安装，无法解析 opensource_dependencies.yml", file=sys.stderr)
        return None
    with open(OPENSRC_DEPS_YML, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    deps = data.get("dependencies", []) if data else []
    packages = []
    for dep in deps:
        packages.append({
            "name": dep.get("name", "unknown"),
            "version": dep.get("version", "unknown"),
            "revision": "",
            "repository_url": dep.get("upstream", ""),
            "license": dep.get("license", "NOASSERTION"),
        })
    return packages

def make_spdx(packages: list[dict]) -> dict:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return {
        "SPDXID": "SPDXRef-DOCUMENT",
        "spdxVersion": "SPDX-2.3",
        "creationInfo": {
            "created": now,
            "creators": ["Tool: ZhiYu-generate-sbom"],
            "licenseListVersion": "3.21"
        },
        "name": "ZhiYu-iOS",
        "dataLicense": "CC0-1.0",
        "documentNamespace": f"https://zhiyu.app/sbom/{datetime.now(timezone.utc).strftime('%Y%m%d-%H%M%S')}",
        "packages": [{
            "SPDXID": "SPDXRef-ZhiYu",
            "name": "ZhiYu",
            "versionInfo": "1.0",
            "supplier": "Organization: wangchong2023",
            "downloadLocation": "NOASSERTION",
            "filesAnalyzed": False,
            "licenseConcluded": "NOASSERTION",
            "licenseDeclared": "NOASSERTION",
            "copyrightText": "NOASSERTION"
        }] + [{
            "SPDXID": f"SPDXRef-{p['name'].replace('.','-').replace('_','-')}",
            "name": p["name"],
            "versionInfo": p["version"],
            "supplier": f"Organization: {p.get('repository_url', 'NOASSERTION')}",
            "downloadLocation": p.get("repository_url", "NOASSERTION"),
            "externalRefs": [{
                "referenceCategory": "PACKAGE-MANAGER",
                "referenceType": "purl",
                "referenceLocator": f"pkg:swift/{p['name']}@{p['version']}"
            }],
            "filesAnalyzed": False,
            "licenseConcluded": p.get("license", "NOASSERTION"),
            "licenseDeclared": p.get("license", "NOASSERTION"),
            "copyrightText": "NOASSERTION"
        } for p in packages],
        "relationships": [{
            "spdxElementId": "SPDXRef-ZhiYu",
            "relationshipType": "CONTAINS",
            "relatedSpdxElement": f"SPDXRef-{p['name'].replace('.','-').replace('_','-')}"
        } for p in packages]
    }

REVISION_SHORT_LEN = 12

def main():
    """
    主入口函数。优先解析 Package.resolved，若不存在则回退到
    Config/opensource_dependencies.yml（SSOT）生成 SPDX 2.3 SBOM。
    """
    resolved_path = find_resolved()
    packages = []
    if resolved_path:
        print(f"📦 解析 Package.resolved: {resolved_path}", file=sys.stderr)
        with open(resolved_path) as f:
            data = json.load(f)
        for pin in data.get("pins", []):
            packages.append({
                "name": pin.get("identity", "unknown"),
                "version": pin.get("state", {}).get("version", "unknown"),
                "revision": pin.get("state", {}).get("revision", "")[:REVISION_SHORT_LEN],
                "repository_url": pin.get("location", ""),
                "license": "NOASSERTION"
            })
    else:
        print("⚠️ Package.resolved 未找到（本地路径依赖模式），回退到 Config/opensource_dependencies.yml", file=sys.stderr)
        packages = load_packages_from_yaml()
        if not packages:
            print("❌ 无法生成 SBOM：Package.resolved 与 opensource_dependencies.yml 均不可用", file=sys.stderr)
            sys.exit(1)
        print(f"📦 从 opensource_dependencies.yml 加载 {len(packages)} 个依赖", file=sys.stderr)

    spdx = make_spdx(packages)
    output_path = os.path.join(PROJECT_DIR, "build", "sbom.spdx.json")
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "w") as f:
        json.dump(spdx, f, indent=2)
    print(f"✅ SBOM (SPDX 2.3) 写入: {output_path}", file=sys.stderr)
    print(f"   包含 {len(packages)} 个依赖", file=sys.stderr)
    print(output_path)

if __name__ == "__main__":
    main()
