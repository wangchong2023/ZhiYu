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
                VStack(spacing: DesignSystem.medium) {
                    Image(systemName: DesignSystem.Icons.library)
                        .font(.system(size: DesignSystem.Gallery.mainIconSize, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.appAccent, Color.appAccent.opacity(DesignSystem.secondaryOpacity)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .opacity(logoOpacity)
                    
                    Text(L10n.Common.Splash.appName)
                        .font(.system(size: DesignSystem.titleFontSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .opacity(logoOpacity)
                }
                .padding(.bottom, DesignSystem.Gallery.splashLogoBottomPadding)
                
                // 名言
                VStack(spacing: DesignSystem.standardPadding) {
                    Text(L10n.Common.Splash.quote)
                        .font(.system(size: DesignSystem.bodyFontSize, weight: .medium, design: .serif))
                        .foregroundStyle(.white.opacity(DesignSystem.pressedOpacity))
                        .multilineTextAlignment(.center)
                        .lineSpacing(DesignSystem.small)
                        .padding(.horizontal, DesignSystem.Metrics.largeIconBoxSize)
                        .opacity(quoteOpacity)
                    
                    // 署名 (仅保留装饰线)
                    HStack(spacing: 0) {
                        Text(" ")
                            .foregroundStyle(.white.opacity(DesignSystem.secondaryOpacity))
                        Text(L10n.Common.Splash.author)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.appAccent.opacity(DesignSystem.secondaryOpacity), Color.appAccent],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .font(.system(size: DesignSystem.captionFontSize, weight: .medium, design: .serif))
                    .opacity(authorOpacity)
                }
                
                Spacer()
                
                // 继续按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: DesignSystem.Animation.standardDuration)) {
                        onDismiss()
                    }
                }) {
                    HStack(spacing: DesignSystem.small) {
                        Text(L10n.Common.Splash.enter)
                            .font(.system(size: DesignSystem.subheadlineFontSize, weight: .semibold, design: .rounded))
                        Image(systemName: DesignSystem.Icons.arrowRight)
                            .font(DesignSystem.caption2Font)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignSystem.huge)
                    .padding(.vertical, DesignSystem.medium)
                    .background(
                        Capsule()
                            .fill(Color.appAccent.opacity(SystemOpacity.glassStrong))
                            .overlay(
                                Capsule()
                                    .strokeBorder(Color.appAccent.opacity(SystemOpacity.disabled), lineWidth: SystemStroke.border)
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
        withAnimation(.easeOut(duration: DesignSystem.Animation.slowDuration)) {
            logoOpacity = 1
        }

        // 名言淡入
        DispatchQueue.main.asyncAfter(deadline: .now() + DesignSystem.Animation.Splash.quoteDelay) {
            withAnimation(.easeOut(duration: 1.2)) {
                quoteOpacity = 1
            }
        }
        
        // 署名淡入
        DispatchQueue.main.asyncAfter(deadline: .now() + DesignSystem.Animation.Splash.authorDelay) {
            withAnimation(.easeOut(duration: DesignSystem.Animation.slowDuration)) {
                authorOpacity = 1
            }
        }
        
        // 5 秒后自动进入（仅在用户未手动点击时）
        DispatchQueue.main.asyncAfter(deadline: .now() + DesignSystem.Animation.Splash.autoDismissDelay) {
            withAnimation(.easeInOut(duration: DesignSystem.Animation.standardDuration)) {
                onDismiss()
            }
        }
    }
}
