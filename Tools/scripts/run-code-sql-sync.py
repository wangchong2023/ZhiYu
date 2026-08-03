# -*- coding: utf-8 -*-
#
#  run-code-sql-sync.py
#  ZhiYu
#
#  Created by Antigravity on 2026/05/30.
#  Copyright © 2026 WangChong. All rights reserved.
#
#  核心职责：自动读取 init_schema.sql 和 global_schema.sql 两个物理 DDL 脚本，
#           并为 Swift 自动渲染并刷新 GeneratedSQL.swift 内存承载类，达成单源信赖（SSoT）。
#

import os

def main():
    base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    persistence_dir = os.path.join(base_dir, "Sources", "Infrastructure", "Storage", "Persistence")
    
    init_sql_path = os.path.join(persistence_dir, "init_schema.sql")
    global_sql_path = os.path.join(persistence_dir, "global_schema.sql")
    generated_swift_path = os.path.join(persistence_dir, "GeneratedSQL.swift")
    
    if not os.path.exists(init_sql_path) or not os.path.exists(global_sql_path):
        print("[Error] [scripts-run-dev-sql-sync.py] Target SQL schema files not found.")
        return
        
    with open(init_sql_path, "r", encoding="utf-8") as f:
        init_sql = f.read()
        
    with open(global_sql_path, "r", encoding="utf-8") as f:
        global_sql = f.read()
        
    swift_content = f"""//
//  GeneratedSQL.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  【自动生成，请勿直接编辑】
//  此代码文件由 Tools/scripts-run-dev-sql-sync.py 预构建脚本在每次 Xcode 编译前自动渲染生成。
//  物理 SQL 脚本（init_schema.sql 与 global_schema.sql）是系统的唯一真实源（Single Source of Truth）。
//

import Foundation

struct GeneratedSQL {{
    /// 专属业务笔记本数据库初始化 SQL 脚本
    static let initSchemaSQL = \"\"\"
{init_sql}
\"\"\"

    /// 全局共享系统配置数据库初始化 SQL 脚本
    static let globalSchemaSQL = \"\"\"
{global_sql}
\"\"\"
}}
"""
    
    with open(generated_swift_path, "w", encoding="utf-8") as f:
        f.write(swift_content)
        
    print("[Success] [scripts-run-dev-sql-sync.py] GeneratedSQL.swift successfully updated and synchronized.")

if __name__ == "__main__":
    main()
