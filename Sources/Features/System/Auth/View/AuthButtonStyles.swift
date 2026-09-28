// 系统层级：[L3] 表现层
// 核心职责: 认证模块共享按钮样式修饰符，消除跨文件的 frame+padding+background+clipShape+shadow 链

import SwiftUI
import UFPDesignSystem

/// 认证主操作按钮样式修饰符，消除 AuthPhonePanel 与 OverseasLoginCardView 的重复
struct AuthActionButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Domain.Auth.actionButtonVerticalPadding)
            .background(Color.appAccent)
            .clipShape(Capsule())
            .shadow(color: Color.appAccent.opacity(DesignTokens.Opacity.shadow), radius: DesignTokens.Spacing.shadowRadius, y: DesignTokens.Spacing.shadowY)
    }
}

extension View {
    /// 应用认证主操作按钮样式
    func authActionButtonStyle() -> some View {
        modifier(AuthActionButtonStyle())
    }
}

/// 认证英雄文本样式修饰符，消除 AuthPhonePanel 与 OverseasLoginCardView 的 Text 样式重复
struct AuthHeroTextStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: DesignTokens.SystemFontSize.hero, weight: .bold, design: .rounded))
            .foregroundStyle(.appText)
            .padding(.top, DesignTokens.Spacing.medium)
    }
}

extension View {
    /// 应用认证英雄文本样式
    func authHeroTextStyle() -> some View {
        modifier(AuthHeroTextStyle())
    }
}
