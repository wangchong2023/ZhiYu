// 系统层级：[L3] 表现层
// 核心职责: 认证模块共享按钮样式修饰符，消除跨文件的 frame+padding+background+clipShape+shadow 链

import SwiftUI

/// 认证主操作按钮样式修饰符，消除 AuthPhonePanel 与 OverseasLoginCardView 的重复
struct AuthActionButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignSystem.Domain.Auth.actionButtonVerticalPadding)
            .background(Color.appAccent)
            .clipShape(Capsule())
            .shadow(color: Color.appAccent.opacity(DesignSystem.Opacity.shadow), radius: Spacing.shadowRadius, y: Spacing.shadowY)
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
            .font(.system(size: SystemFontSize.hero, weight: .bold, design: .rounded))
            .foregroundStyle(.appText)
            .padding(.top, Spacing.medium)
    }
}

extension View {
    /// 应用认证英雄文本样式
    func authHeroTextStyle() -> some View {
        modifier(AuthHeroTextStyle())
    }
}
