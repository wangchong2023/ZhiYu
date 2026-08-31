//
//  PlatformConstants.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：Platforms 层强类型常量集，消除魔鬼数字/字符串。
//

import Foundation
import SwiftUI

/// Platforms 层强类型常量集
public enum PlatformConstants {

    // MARK: - PDF 服务

    /// PDF 文件管理安全约束
    public enum PDFSecurity {
        /// 路径穿越检测的非法字符
        public static let pathTraversalMarker: String = ".."
        /// 路径分隔符
        public static let pathSeparator: String = "/"
    }

    // MARK: - Spotlight 索引

    /// Spotlight 索引约束
    public enum Spotlight {
        /// contentDescription 最大截断长度
        public static let contentDescriptionMaxLength: Int = 200
        /// 索引域标识符
        public static let domainIdentifier: String = "com.zhiyu.app.pages"
    }

    // MARK: - Multipeer 协作

    /// MultipeerConnectivity 超时与广播约束
    public enum Multipeer {
        /// 加入房间超时秒数
        public static let joinTimeoutSeconds: TimeInterval = 30
    }

    // MARK: - Reminder 服务

    /// EventKit 错误码
    public enum Reminder {
        /// "未找到" 错误码（对应 EKErrorCode notFound）
        public static let notFoundErrorCode: Int = 404
    }

    // MARK: - Widget/Watch 视图

    /// Widget 与 Watch 视图约束
    public enum WidgetWatch {
        /// 进度环分母（页面数满格阈值）
        public static let progressRingDenominator: Double = 100.0
        /// 最近更新列表最大显示条数
        public static let maxRecentTitles: Int = 5
        /// "万" 单位阈值
        public static let tenThousandThreshold: Int = 10000
        /// "k" 单位阈值
        public static let thousandThreshold: Int = 1000
        /// "万" 单位换算因子
        public static let tenThousandDivisor: Double = 10000.0
        /// "k" 单位换算因子
        public static let thousandDivisor: Double = 1000.0
        /// 知识分布小组件默认页面数（Preview 占位值）
        public static let defaultPageCount: Int = 42
        /// 知识分布小组件默认分布比例（Source/Concept/Entity/Map）
        public static let defaultDistribution: [String: Double] = [
            "Source": 0.4,
            "Concept": 0.3,
            "Entity": 0.2,
            "Map": 0.1
        ]
        /// 分布比例缺失时的 fallback 透明度
        public static let distributionFallbackOpacity: Double = 0.2
    }

    // MARK: - DeepLink URL
    /// Widget 深度链接 URL 常量
    public enum DeepLink {
        public static let scheme: String = "zhiyu"
        public static let voice: String = "zhiyu://voice"
        public static let ocr: String = "zhiyu://ocr"
        public static let search: String = "zhiyu://search"
        public static let chat: String = "zhiyu://chat"
        public static let create: String = "zhiyu://create"
    }

    // MARK: - Widget 颜色令牌 (Color Tokens)
    /// Widget Extension 专用颜色令牌（独立 target 无法访问主 App 的 Color.theme）
    public enum WidgetColor {
        public static let purple: SwiftUI.Color = .purple
        public static let blue: SwiftUI.Color = .blue
        public static let orange: SwiftUI.Color = .orange
        public static let teal: SwiftUI.Color = .teal
        public static let green: SwiftUI.Color = .green
        public static let red: SwiftUI.Color = .red
        public static let yellow: SwiftUI.Color = .yellow
        public static let gray: SwiftUI.Color = .gray
        public static let cyan: SwiftUI.Color = .cyan
        public static let indigo: SwiftUI.Color = .indigo
        public static let mint: SwiftUI.Color = .mint
        public static let pink: SwiftUI.Color = .pink
        public static let brown: SwiftUI.Color = .brown
    }
}
