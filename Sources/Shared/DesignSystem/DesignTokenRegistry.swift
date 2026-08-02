//
//  DesignTokenRegistry.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：多平台跨域设计 Token 动态解析注册表 (Design Token Registry Adaptor)
//

import SwiftUI

/// 语义间距 Token 枚举
public enum SemanticSpacingToken: Sendable {
    case atomic
    case tight
    case compact
    case standard
    case cardPadding
    case sectionPadding
    case screenMargin
}

/// 语义圆角 Token 枚举
public enum SemanticRadiusToken: Sendable {
    case small
    case medium
    case large
    case card
    case capsule
}

/// 多平台设计 Token 动态注册解析中心
public final class DesignTokenRegistry: Sendable {
    public static let shared = DesignTokenRegistry()
    
    private init() {}
    
    /// 根据当前平台上下文动态解析语义间距 (Semantic Spacing)
    public func resolveSpacing(_ token: SemanticSpacingToken, in context: PlatformContext = .current) -> CGFloat {
        switch token {
        case .atomic, .tight, .compact, .standard:
            return resolveBaseSpacing(token, isWatch: context.deviceFamily == .watch)
        case .cardPadding, .sectionPadding, .screenMargin:
            return resolveContainerSpacing(token, family: context.deviceFamily)
        }
    }
    
    /// 基础元素间距解析
    private func resolveBaseSpacing(_ token: SemanticSpacingToken, isWatch: Bool) -> CGFloat {
        switch token {
        case .atomic:
            return DesignSystem.Tier2.Spacing.atomic
        case .tight:
            return DesignSystem.Tier2.Spacing.tight
        case .compact:
            return isWatch ? DesignSystem.Tier1.Spacing.space4 : DesignSystem.Tier2.Spacing.compact
        case .standard:
            return isWatch ? DesignSystem.Tier1.Spacing.space8 : DesignSystem.Tier2.Spacing.standard
        default:
            return DesignSystem.Tier2.Spacing.standard
        }
    }
    
    /// 容器组件间距解析
    private func resolveContainerSpacing(_ token: SemanticSpacingToken, family: PlatformDeviceFamily) -> CGFloat {
        switch (token, family) {
        case (.cardPadding, .watch): return DesignSystem.Tier1.Spacing.space8
        case (.cardPadding, .mac): return DesignSystem.Tier1.Spacing.space12
        case (.cardPadding, _): return DesignSystem.Tier2.Spacing.cardPadding
        case (.sectionPadding, .watch): return DesignSystem.Tier1.Spacing.space12
        case (.sectionPadding, .mac): return DesignSystem.Tier1.Spacing.space16
        case (.sectionPadding, _): return DesignSystem.Tier2.Spacing.sectionPadding
        case (.screenMargin, .watch): return DesignSystem.Tier1.Spacing.space4
        case (.screenMargin, .mac): return DesignSystem.Tier1.Spacing.space16
        case (.screenMargin, _): return DesignSystem.Tier2.Spacing.screenMargin
        default: return DesignSystem.Tier2.Spacing.standard
        }
    }
    
    /// 根据当前平台上下文动态解析语义圆角 (Semantic Radius)
    public func resolveRadius(_ token: SemanticRadiusToken, in context: PlatformContext = .current) -> CGFloat {
        switch token {
        case .small:
            return DesignSystem.Tier2.Radius.small
        case .medium:
            return DesignSystem.Tier2.Radius.medium
        case .large, .card:
            return context.deviceFamily == .watch ? DesignSystem.Tier1.Radius.r8 : DesignSystem.Tier2.Radius.large
        case .capsule:
            return DesignSystem.Tier2.Radius.capsule
        }
    }
    
    /// 解析适合平台的最小可点击热区尺寸 (Min Touch Target)
    public func resolveTouchTarget(in context: PlatformContext = .current) -> CGFloat {
        if context.isTouchOptimized {
            return context.deviceFamily == .watch ? DesignSystem.Tier1.Spacing.space32 : DesignSystem.Tier3.Action.minTouchTargetTouch
        } else {
            return DesignSystem.Tier3.Action.minTouchTargetPointer
        }
    }
    
    /// 解析适合平台的侧边栏标准宽度 (Sidebar Width)
    public func resolveSidebarWidth(in context: PlatformContext = .current) -> CGFloat {
        return context.deviceFamily == .mac ? DesignSystem.Tier3.Sidebar.widthMac : DesignSystem.Tier3.Sidebar.widthPhone
    }
}
