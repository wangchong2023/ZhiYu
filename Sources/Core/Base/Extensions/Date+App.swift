//
//  Date+App.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：业务层兼容层。通用日期格式化能力已迁移至 `UFPCore.Date+Formatting`，
//           此处仅保留 `AppFormat` 别名以维持现有调用点不变。
//

import Foundation
import UFPCore

extension Date {
    /// 预定义的 App 日期格式规范（兼容别名，指向 `UFPCore.Date.AppFormatStyle`）
    typealias AppFormat = Date.AppFormatStyle
}
