//
//  RegexConstants.swift
//  UFPCore
//
//  Created by Antigravity on 2026/10/11.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：与业务无关的通用正则特征模式常量集，消除内联正则魔鬼字符串。
//

import Foundation

/// 通用正则特征模式常量集
public enum RegexConstants {

    // MARK: - CJK/ANSI 混排边界 (CJK/ANSI Spacing)
    /// CJK 排版空格注入相关正则模式
    public enum CJKSpacing {
        /// 匹配 CJK 在前、ANSI 在后 的字符边界（用于注入空格）
        public static let cjkAnsBoundary: String = #"([\u4e00-\u9fa5\u3040-\u30ff])([A-Za-z0-9@#\$%\^&\*\-\+\=])"#
        /// 匹配 ANSI 在前、CJK 在后 的字符边界（用于注入空格）
        public static let ansCjkBoundary: String = #"([A-Za-z0-9@#\$%\^&\*\-\+\=])([\u4e00-\u9fa5\u3040-\u30ff])"#
    }
}
