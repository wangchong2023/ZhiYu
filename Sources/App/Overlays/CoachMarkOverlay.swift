//
//  CoachMarkOverlay.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：SwiftUI 视图组件，构建应用的导航、侧边栏、布局等 UI 结构。
//
import SwiftUI

/// 功能引导弹窗常量
private enum CoachMarkConstants {
    /// 卡片圆角 (largeRadius + coachMarkRadiusOffset = 28)
    static let cardCornerRadius: CGFloat = 28
}

/// 功能引导弹窗 (Coach Marks)
struct CoachMarkOverlay: View {
    let type: AppStore.CoachMarkType
    @Binding var selectedTab: AppTab
    let onDismiss: () -> Void
    
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // 半透明背景
            Color.theme.black.opacity(DesignSystem.coachMarkBackgroundOpacity)
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.giant) {
                // 图标
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [.appAccent, .appSource], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: DesignSystem.Gallery.splashIconSize, height: DesignSystem.Gallery.splashIconSize)
                        .shadow(color: .appAccent.opacity(SystemOpacity.disabled), radius: DesignSystem.medium, y: SystemSpacing.element)
                    
                    Image(systemName: iconName)
                        .font(.system(size: DesignSystem.Metrics.titleFontSize * DesignSystem.Metrics.coachMarkIconScale, weight: .bold))
                        .foregroundStyle(.white)
                }
                .scaleEffect(isAnimating ? 1.0 : 0.8)
                .opacity(isAnimating ? 1.0 : 0)
                
                VStack(spacing: DesignSystem.medium) {
                    Text(title)
                        .font(.title3.bold())
                        .foregroundStyle(.appText)
                    
                    Text(desc)
                        .font(.subheadline)
                        .foregroundStyle(.appSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .offset(y: isAnimating ? 0 : DesignSystem.loosePadding)
                .opacity(isAnimating ? SystemOpacity.active : 0)
                
                Button(action: performAction) {
                    Text(actionText)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignSystem.Metrics.coachMarkActionHorizontalPadding)
                        .padding(.vertical, DesignSystem.medium)
                        .background(
                            Capsule()
                                .fill(Color.appAccent)
                        )
                }
                .scaleEffect(isAnimating ? SystemOpacity.active : DesignSystem.Metrics.coachMarkScaleMultiplier)
                .opacity(isAnimating ? SystemOpacity.active : 0)
                
                Button(action: dismissWithAnimation) {
                    Text(L10n.Common.skip)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                }
                .padding(.top, DesignSystem.tiny)
            }
            .padding(ComponentSpacing.ultra)
            .background(
                RoundedRectangle(cornerRadius: CoachMarkConstants.cardCornerRadius)
                    .fill(Color.appCard)
                    .shadow(color: .primary.opacity(SystemOpacity.glassStrong), radius: DesignSystem.Metrics.coachMarkShadowRadius, x: 0, y: DesignSystem.Metrics.coachMarkShadowY)
            )
            .padding(DesignSystem.giant)
        }
        .onAppear {
            withAnimation(.spring(response: DesignSystem.Animation.standardDuration, dampingFraction: 0.7)) {
                isAnimating = true
            }
        }
    }
    
    private var iconName: String {
        switch type {
        case .graphDiscovery: return "circle.hexagongrid.fill"
        }
    }
    
    private var title: String {
        switch type {
        case .graphDiscovery: return L10n.Coachmark.graphDiscoveryTitle
        }
    }
    
    private var desc: String {
        switch type {
        case .graphDiscovery: return L10n.Coachmark.graphDiscoveryDesc
        }
    }
    
    private var actionText: String {
        switch type {
        case .graphDiscovery: return L10n.Coachmark.graphDiscoveryAction
        }
    }
    
    private func performAction() {
        HapticFeedback.shared.trigger(.success)
        switch type {
        case .graphDiscovery:
            withAnimation {
                selectedTab = .graph
            }
        }
        dismissWithAnimation()
    }
    
    private func dismissWithAnimation() {
        withAnimation(.easeIn(duration: DesignSystem.Animation.fastDuration)) {
            isAnimating = false
        }
        // Bug #99 修复：DispatchQueue.main.asyncAfter 改为 Task + Task.sleep，
        // 符合项目并发规范（AGENTS.md：优先 async/await）。
        Task {
            try? await Task.sleep(for: .seconds(DesignSystem.Animation.fastDuration))
            await MainActor.run { onDismiss() }
        }
    }
}
