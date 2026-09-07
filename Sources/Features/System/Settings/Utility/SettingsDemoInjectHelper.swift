//
//  SettingsDemoInjectHelper.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：格式化示例知识库注入成功/失败 Toast 提示信息与详情拼接
//

import Foundation
import UFPCore

/// 设置中心示例数据注入提示格式化工具
public enum SettingsDemoInjectHelper {

    /// 格式化注入成功提示信息
    /// - Parameters:
    ///   - details: 各笔记本注入详情 (名称与篇数)
    ///   - prefixFormat: 前缀模板
    ///   - pageUnit: 篇数单位
    ///   - separator: 分隔符
    /// - Returns: 组合后的完整 Toast 提示
    public static func formatSuccessMessage(
        details: [(name: String, count: Int)],
        prefixFormat: String,
        pageUnit: String,
        separator: String
    ) -> String {
        guard !details.isEmpty else { return "" }
        let prefix = String(format: prefixFormat, details.count)
        var vaultsDesc = ""
        for (index, detail) in details.enumerated() {
            if index > 0 { vaultsDesc += separator }
            vaultsDesc += detail.name + String(detail.count) + pageUnit
        }
        return prefix + vaultsDesc
    }
}
