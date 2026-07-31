//
//  ButtonStyles.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：设计系统令牌：颜色、排版、间距、动画、图标等可视化常量。
//
import SwiftUI

// MARK: - 卡片按压交互样式

/// 适用于卡片类按钮的标准物理阻尼缩放与透明度按压交互样式。
/// 
/// 该样式通过将普通的线性插值缓动替换为高性能拟真弹簧阻尼算法，
/// 为笔记本工作台卡片、列表行等交互性容器组件提供拟真的物理下沉与快速回弹反馈。
struct AppCardButtonStyle: ButtonStyle {
    
    /// 创建并定制按钮的主体外观，动态注入拟真物理弹簧缩放及触压透明度变化。
    /// 
    /// - Parameter configuration: 系统提供的按钮状态配置，包含当前标签内容及是否处于手指/鼠标按压状态 (`isPressed`)。
    /// - Returns: 已经融合了物理阻尼回弹反馈机制的高响应度定制按钮视图。
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // 确保整个矩形区域（包括空白部分）都可以接收点击热区响应
            .contentShape(Rectangle())
            // 当用户按下时，卡片产生物理微缩效果，松开时弹性恢复原尺寸
            .scaleEffect(configuration.isPressed ? DesignSystem.Animation.pressScale : 1.0)
            // 按下时透明度略微调降以提供亮度衰减层面的视觉暗示
            .opacity(configuration.isPressed ? DesignSystem.pressedOpacity : DesignSystem.fullOpacity)
            // 绑定苹果设备物理质感的欠阻尼弹簧曲线，实现干脆而又带微小惯性回弹的完美手感
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
