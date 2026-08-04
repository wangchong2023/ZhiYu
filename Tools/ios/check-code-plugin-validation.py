#!/usr/bin/env python3
# NAMING-bypass: 豁免工具脚本规范规则检查
"""
ZhiYu 插件完整性校验工具

用法：
    python3 check-code-plugin-validation.py plugin.zyplugin
"""

import sys
import json
import zipfile
import re
from pathlib import Path

def validate_plugin(plugin_path):
    """校验插件完整性"""
    
    print(f"🔍 校验插件: {plugin_path}\n")
    
    errors = []
    warnings = []
    info = []
    
    # 1. 检查文件存在
    if not Path(plugin_path).exists():
        errors.append(f"文件不存在: {plugin_path}")
        return False, errors, warnings, info
    
    # 2. 检查文件扩展名
    if not plugin_path.endswith('.zyplugin'):
        errors.append("文件扩展名必须是 .zyplugin")
    else:
        info.append("✓ 文件扩展名正确")
    
    # 3. 检查是否为有效的 ZIP 文件
    try:
        with zipfile.ZipFile(plugin_path, 'r') as zf:
            file_list = zf.namelist()
            info.append(f"✓ ZIP 格式有效，包含 {len(file_list)} 个文件")
            
            # 4. 检查必需文件
            required_files = ['manifest.json', 'index.js']
            for required in required_files:
                if required in file_list:
                    info.append(f"✓ {required} 存在")
                else:
                    errors.append(f"{required} 缺失")
            
            # 5. 检查推荐文件
            recommended_files = ['README.md', 'README.zh-Hans.md', 'LICENSE', 'CHANGELOG.md']

            # 5a. 先解析 manifest 以便后续校验（manifest.json 在步骤 6 才正式校验，此处提前读取 readmeFiles）
            manifest = {}
            if 'manifest.json' in file_list:
                try:
                    manifest = json.loads(zf.read('manifest.json').decode('utf-8'))
                except (json.JSONDecodeError, UnicodeDecodeError):
                    pass  # 步骤 6 会报告详细错误

            # 5b. 检查 manifest 中的 readmeFiles 声明
            if 'readmeFiles' in manifest:
                info.append(f"✓ manifest.readmeFiles 已声明")
            else:
                warnings.append("manifest 缺少 readmeFiles 字段，建议声明多语言 README")
            for recommended in recommended_files:
                if recommended in file_list:
                    info.append(f"✓ {recommended} 存在")
                else:
                    warnings.append(f"{recommended} 缺失（推荐添加）")
            
            # 6. 校验 manifest.json
            if 'manifest.json' in file_list:
                try:
                    manifest_content = zf.read('manifest.json').decode('utf-8')
                    manifest = json.loads(manifest_content)
                    
                    # 必填字段
                    required_fields = ['id', 'version', 'author', 'permissions', 'names', 'descriptions']
                    for field in required_fields:
                        if field in manifest:
                            info.append(f"✓ manifest.{field} 存在")
                        else:
                            errors.append(f"manifest.{field} 缺失")
                    
                    # 校验 ID 格式
                    if 'id' in manifest:
                        if re.match(r'^[a-z][a-z0-9\-\.]+[a-z0-9]$', manifest['id']):
                            info.append(f"✓ ID 格式正确: {manifest['id']}")
                        else:
                            warnings.append(f"ID 格式不规范: {manifest['id']} (建议使用反向域名)")
                    
                    # 校验版本号
                    if 'version' in manifest:
                        if re.match(r'^\d+\.\d+\.\d+', manifest['version']):
                            info.append(f"✓ 版本号格式正确: {manifest['version']}")
                        else:
                            warnings.append(f"版本号格式不符合 semver: {manifest['version']}")
                    
                    # 校验权限
                    if 'permissions' in manifest:
                        valid_permissions = ['readContent', 'writeContent', 'network', 'aiAccess', 'log']
                        for perm in manifest['permissions']:
                            if perm in valid_permissions:
                                info.append(f"✓ 权限有效: {perm}")
                            else:
                                errors.append(f"未知权限: {perm}")
                    
                    # 校验多语言
                    if 'names' in manifest:
                        if 'en' in manifest['names'] or 'zh-Hans' in manifest['names']:
                            info.append(f"✓ 多语言名称完整")
                        else:
                            errors.append("names 必须包含 en 或 zh-Hans")
                    
                    if 'descriptions' in manifest:
                        if 'en' in manifest['descriptions'] or 'zh-Hans' in manifest['descriptions']:
                            info.append(f"✓ 多语言描述完整")
                        else:
                            errors.append("descriptions 必须包含 en 或 zh-Hans")
                    
                except json.JSONDecodeError as e:
                    errors.append(f"manifest.json JSON 解析错误: {e}")
                except UnicodeDecodeError:
                    errors.append("manifest.json 编码错误（必须是 UTF-8）")
            
            # 7. 校验 index.js
            if 'index.js' in file_list:
                try:
                    js_content = zf.read('index.js').decode('utf-8')
                    
                    if len(js_content.strip()) == 0:
                        errors.append("index.js 不能为空")
                    else:
                        info.append(f"✓ index.js 大小: {len(js_content)} 字节")
                    
                    # 检查必需函数
                    if 'function onLoad' in js_content:
                        info.append("✓ onLoad 函数存在")
                    else:
                        errors.append("onLoad 函数缺失")
                    
                    if 'function onUnload' in js_content:
                        info.append("✓ onUnload 函数存在")
                    else:
                        warnings.append("onUnload 函数缺失（推荐添加）")
                    
                except UnicodeDecodeError:
                    errors.append("index.js 编码错误（必须是 UTF-8）")
            
            # 8. 检查文件大小
            file_size = Path(plugin_path).stat().st_size
            if file_size > 10 * 1024 * 1024:  # 10 MB
                warnings.append(f"插件包较大: {file_size / 1024 / 1024:.1f} MB")
            else:
                info.append(f"✓ 插件包大小合理: {file_size / 1024:.1f} KB")
            
    except zipfile.BadZipFile:
        errors.append("不是有效的 ZIP 文件")
        return False, errors, warnings, info
    except Exception as e:
        errors.append(f"校验过程出错: {e}")
        return False, errors, warnings, info
    
    # 输出结果
    print("=" * 60)
    if info:
        print("\n✅ 通过的检查:\n")
        for msg in info:
            print(f"  {msg}")
    
    if warnings:
        print(f"\n⚠️  警告 ({len(warnings)}):\n")
        for msg in warnings:
            print(f"  • {msg}")
    
    if errors:
        print(f"\n❌ 错误 ({len(errors)}):\n")
        for msg in errors:
            print(f"  • {msg}")
    
    print("\n" + "=" * 60)
    
    if errors:
        print("\n❌ 校验失败！请修复上述错误。")
        return False, errors, warnings, info
    elif warnings:
        print("\n⚠️  校验通过，但有警告项。建议改进。")
        return True, errors, warnings, info
    else:
        print("\n✅ 校验通过！插件符合规范。")
        return True, errors, warnings, info

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python3 check-code-plugin-validation.py plugin.zyplugin")
        sys.exit(1)
    
    plugin_path = sys.argv[1]
    success, errors, warnings, info = validate_plugin(plugin_path)
    
    sys.exit(0 if success else 1)
