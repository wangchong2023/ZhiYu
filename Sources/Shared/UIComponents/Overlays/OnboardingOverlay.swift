//
//  OnboardingOverlay.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI
import UFPDesignSystem

// MARK: - Onboarding Overlay
/// 引导蒙层组件
/// 负责在引导流程中展示各步骤的视觉元素、描述信息及操作按钮，采用沉浸式背景与弹性动画。
struct OnboardingOverlay: View {
    @ObservedObject var service: OnboardingService
    
    var body: some View {
        if let step = service.currentStep {
            ZStack {
                Color.theme.black.opacity(DesignTokens.Colors.Opacity.secondaryOpacity * 0.875) // 0.7
                    .ignoresSafeArea()
                
                VStack(spacing: DesignTokens.Spacing.loosePadding) { // 24
                    Image(systemName: step.icon)
                        .font(.system(size: DesignTokens.Spacing.iconHuge * 1.25))
                        .foregroundStyle(.appAccent)
                    
                    VStack(spacing: DesignTokens.Spacing.tightPadding) { // 8
                        Text(step.title)
                            .font(.title2.bold())
                        Text(step.description)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, DesignTokens.Spacing.huge) // 32
                    }
                    
                    Button(action: { 
                        withAnimation {
                            service.nextStep()
                        }
                    }) {
                        Text(step == .vault ? L10n.Onboarding.Action.start : L10n.Onboarding.Action.next)
                            .font(.headline)
                            .foregroundStyle(Color.theme.white)
                            .padding(.horizontal, DesignTokens.Spacing.Sidebar.backButtonWidth) // 40
                            .padding(.vertical, DesignTokens.Spacing.medium) // 12
                            .background(Color.appAccent)
                            .clipShape(Capsule())
                    }
                    
                    Button(L10n.Onboarding.Action.skip) {
                        withAnimation {
                            service.completeOnboarding()
                        }
                    }
                    .font(.footnote)
                    .foregroundStyle(.appSecondary)
                }
                .padding(DesignTokens.Spacing.huge)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Spacing.chipRadius))
                .shadow(radius: DesignTokens.Spacing.giant)
                .padding(DesignTokens.Spacing.giant)
                .transition(.scale.combined(with: .opacity))
            }
            .zIndex(999)
        }
    }
}
