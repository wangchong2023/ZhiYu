//
//  Color+ModelName.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] 共享设计系统包
//  核心职责：提供从领域模型颜色名称字符串到 SwiftUI.Color 的集中式映射。
//

import SwiftUI

public extension Color {
    /// 颜色名称到 SwiftUI.Color 的映射表（集中管理以降低圈复杂度）
    private static let modelColorNameMap: [String: Color] = [
        "entity": .appEntity, "concept": .appConcept, "source": .appSource,
        "map": .appMap, "comparison": .appComparison,
        "green": .green, "blue": .blue, "red": .red, "orange": .orange,
        "purple": .purple, "yellow": .yellow, "teal": .teal, "indigo": .indigo,
        "pink": .pink, "gray": .gray
    ]

    /// 从模型层的颜色名称字符串转换为 SwiftUI.Color
    /// - Parameter name: 颜色名称（如 "green", "red", "entity" 等）
    /// - Returns: 对应的 SwiftUI.Color，未命中时默认为 .gray
    static func fromModelColorName(_ name: String) -> Color {
        modelColorNameMap[name] ?? .gray
    }
}
