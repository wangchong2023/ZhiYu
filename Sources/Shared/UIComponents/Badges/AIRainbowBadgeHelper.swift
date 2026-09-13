//
//  AIRainbowBadgeHelper.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层 / 通用 UI 组件
//  核心职责：提供 AI 呼吸光晕微标色彩配置、状态文本与平台宽度自适应纯计算函数
//

import SwiftUI
import UFPCore

/// 全局 AI 呼吸指示微标逻辑与视觉计算辅助
public enum AIRainbowBadgeHelper {

    /// 徽标视觉状态枚举
    public enum VisualState: Equatable, Sendable {
        case localReady
        case cloudEscalation
        case idleNormal
    }

    /// 解析当前徽标核心视觉状态
    public static func resolveVisualState(isLocalReady: Bool, isCloudEscalationEnabled: Bool) -> VisualState {
        if isLocalReady {
            return .localReady
        } else if isCloudEscalationEnabled {
            return .cloudEscalation
        } else {
            return .idleNormal
        }
    }

    /// 解析当前徽标核心颜色
    public static func resolveMainColor(isLocalReady: Bool, isCloudEscalationEnabled: Bool) -> Color {
        switch resolveVisualState(isLocalReady: isLocalReady, isCloudEscalationEnabled: isCloudEscalationEnabled) {
        case .localReady:
            return Color.theme.green
        case .cloudEscalation:
            return Color.theme.purple
        case .idleNormal:
            return .appAccent
        }
    }

    /// 解析发光层颜色
    public static func resolveGlowColor(isLocalReady: Bool) -> Color {
        if isLocalReady {
            return Color.theme.green.opacity(DesignSystem.Opacity.prominent)
        } else {
            return Color.appAccent.opacity(DesignSystem.Opacity.prominent)
        }
    }

    /// 解析控制中枢在不同设备上的自适应宽度
    public static func resolveControlCenterWidth(isPad: Bool, isMacCatalyst: Bool) -> CGFloat {
        if isMacCatalyst {
            return Spacing.Sidebar.macCompactWidth
        } else if isPad {
            return Spacing.Sidebar.padSidebarWidth
        } else {
            return Spacing.Sidebar.popoverDefaultWidth
        }
    }

    /// 格式化物理运存为 GB 文本
    public static func formatMemoryInGB(_ physicalMemory: UInt64) -> String {
        let memInGb = Double(physicalMemory) / SystemConstants.bytesPerGB
        return "\(String(format: "%.1f", memInGb)) GB"
    }
}
