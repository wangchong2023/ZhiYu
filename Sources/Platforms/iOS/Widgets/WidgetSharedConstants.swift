//
//  WidgetSharedConstants.swift
//  ZhiYu
//
//  Created by CodeFree on 2026/08/30.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Platforms] Widget Extension
//  核心职责：Widget Extension 与测试共享的常量集，消除魔鬼字符串/数字。
//           放在 Widgets 目录下，确保 ZhiYuWidgets target 和 ZhiYuTests 都能访问。
//

import Foundation
import SwiftUI

/// Widget Extension 与测试共享的常量集
enum WidgetSharedConstants {

    // MARK: - DeepLink URL
    /// Widget 深度链接 URL 常量
    enum DeepLink {
        static let voice: String = "zhiyu://voice"
        static let ocr: String = "zhiyu://ocr"
        static let search: String = "zhiyu://search"
        static let chat: String = "zhiyu://chat"
        static let create: String = "zhiyu://create"
    }

    // MARK: - 颜色令牌 (Color Tokens)
    /// Widget Extension 专用颜色令牌（独立 target 无法访问主 App 的 Color.theme）
    enum Color {
        static let purple: SwiftUI.Color = .purple
        static let blue: SwiftUI.Color = .blue
        static let orange: SwiftUI.Color = .orange
        static let teal: SwiftUI.Color = .teal
        static let green: SwiftUI.Color = .green
        static let red: SwiftUI.Color = .red
        static let yellow: SwiftUI.Color = .yellow
        static let gray: SwiftUI.Color = .gray
        static let cyan: SwiftUI.Color = .cyan
        static let indigo: SwiftUI.Color = .indigo
        static let mint: SwiftUI.Color = .mint
        static let pink: SwiftUI.Color = .pink
        static let brown: SwiftUI.Color = .brown
    }
}
