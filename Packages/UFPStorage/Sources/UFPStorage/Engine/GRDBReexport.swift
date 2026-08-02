//
//  GRDBReexport.swift
//  UFPStorage
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPStorage] Universal Foundation Platform Storage
//  核心职责：GRDB 开源库的唯一物理封装点。
//           通过 @_exported 将 GRDB 全量重导出，上层模块（Sources/Infrastructure/）
//           只需 import UFPStorage，无需也不允许直接 import GRDB。
//
//  📌 架构契约：
//     - Sources/ 及所有 ZhiYu 业务层严禁直接 import GRDB
//     - 所有 GRDB 类型通过此文件的 @_exported 透明可见
//     - 替换 GRDB 库时只需修改 Package.swift + 此文件，上层零感知
//

@_exported import GRDB
