//
//  SplashView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：构建 Splash 界面的 UI 视图层组件。
//
import SwiftUI
import UFPCore
import UFPDesignSystem

// MARK: - SplashView
/// 启动画面：名言引导 + 程序化生成的书本 + 神经网络星空背景
struct SplashView: View {
    @State private var quoteOpacity: Double = 0
    @State private var authorOpacity: Double = 0
    @State private var logoOpacity: Double = 0
    @State private var starTwinkle = false
    @State private var nodeGlow = false
    
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            // MARK: - 程序化背景
            SplashBackgroundView(starTwinkle: starTwinkle, nodeGlow: nodeGlow)
                .ignoresSafeArea()
            
            // 内容
            VStack(spacing: 0) {
                Spacer()
                
                // App Logo / 名称
                VStack(spacing: DesignTokens.Spacing.medium) {
                    Image(systemName: DesignTokens.Icons.library)
                        .font(.system(size: DesignSystem.Gallery.mainIconSize, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(DesignTokens.Colors.Opacity.secondaryOpacity)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(logoOpacity)
                    
                    Text(L10n.Common.Splash.appName)
                        .font(.system(size: DesignTokens.Typography.titleFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(logoOpacity)
                }
                .padding(.bottom, DesignSystem.Gallery.splashLogoBottomPadding)
                
                // 名言
                VStack(spacing: DesignTokens.Spacing.standardPadding) {
                    Text(L10n.Common.Splash.quote)
                        .font(.system(size: DesignTokens.Typography.bodyFontSize, weight: .medium, design: .serif))
                        .foregroundStyle(.white.opacity(DesignTokens.Colors.Opacity.pressedOpacity))
                        .multilineTextAlignment(.center)
                        .lineSpacing(DesignTokens.Spacing.small)
                        .padding(.horizontal, DesignTokens.Metrics.largeIconBoxSize)
                        .opacity(quoteOpacity)
                    
                    // 署名 (仅保留装饰线)
                    HStack(spacing: 0) {
                        Text(" ")
                            .foregroundStyle(.white.opacity(DesignTokens.Colors.Opacity.secondaryOpacity))
                        Text(L10n.Common.Splash.author)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.appAccent.opacity(DesignTokens.Colors.Opacity.secondaryOpacity), Color.appAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .font(.system(size: DesignTokens.Typography.captionFontSize, weight: .medium, design: .serif))
                    .opacity(authorOpacity)
                }
                
                Spacer()
                
                // 继续按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: DesignTokens.Animation.standardDuration)) {
                        onDismiss()
                    }
                }) {
                    HStack(spacing: DesignTokens.Spacing.small) {
                        Text(L10n.Common.Splash.enter)
                            .font(.system(size: DesignTokens.Typography.subheadlineFontSize, weight: .semibold, design: .rounded))
                        Image(systemName: DesignTokens.Icons.arrowRight)
                            .font(DesignTokens.Typography.caption2Font)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.Spacing.huge)
                    .padding(.vertical, DesignTokens.Spacing.medium)
                    .background(
                        Capsule()
                            .fill(Color.appAccent.opacity(DesignTokens.SystemOpacity.glassStrong))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.appAccent.opacity(DesignTokens.SystemOpacity.disabled), lineWidth: DesignTokens.SystemStroke.border)
                            )
                    )
                }
                .opacity(authorOpacity)
                .padding(.bottom, DesignSystem.Gallery.splashButtonBottomPadding)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - 动画序列
    private func startAnimations() {
        #if DEBUG
        if TestModeDetector.isUITesting {
            onDismiss()
            return
        }
        #endif
        // 背景动画启动
        starTwinkle = true
        nodeGlow = true
        
        // Logo 淡入
        withAnimation(.easeOut(duration: DesignTokens.Animation.slowDuration)) {
            logoOpacity = 1
        }

        // 名言淡入
        SplashAnimationScheduler.scheduleFadeIn(
            after: DesignTokens.Animation.Splash.quoteDelay,
            duration: DesignTokens.Animation.Splash.quoteFadeDuration
        ) {
            quoteOpacity = 1
        }
        
        // 署名淡入
        SplashAnimationScheduler.scheduleFadeIn(
            after: DesignTokens.Animation.Splash.authorDelay,
            duration: DesignTokens.Animation.slowDuration
        ) {
            authorOpacity = 1
        }
        
        // 自动进入（仅在用户未手动点击时）
        SplashAnimationScheduler.scheduleStandardTransition(
            after: DesignTokens.Animation.Splash.autoDismissDelay
        ) {
            onDismiss()
        }
    }
}
