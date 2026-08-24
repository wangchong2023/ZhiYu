//
//  LockOverlayView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：构建 LockOverlay 界面的 UI 视图层组件。
//
import SwiftUI

/// 隐私锁屏覆盖视图
/// 负责在应用进入后台或由于空闲触发锁定时，提供全屏的生物识别解锁界面，确保知识库内容的安全性
struct LockOverlayView: View {
    @Environment(AppStore.self) var store
    @State private var isAnimating = false
    
    private var unlockIcon: String {
        #if os(macOS)
        return "touchid"
        #else
        return "faceid"
        #endif
    }
    
    private var titleSize: CGFloat {
        #if os(macOS)
        return 36
        #elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? 36 : 28
        #else
        return 24
        #endif
    }

    var body: some View {
        ZStack {
            // 1. Immersive Deep Glass Background
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            
            // Animated Background Glows
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                    .frame(width: DesignSystem.Metrics.largeGlowSize, height: DesignSystem.Metrics.largeGlowSize)
                    .blur(radius: 100)
                    .offset(x: isAnimating ? 150 : -150, y: isAnimating ? -100 : 100)
                
                Circle()
                    .fill(Color.theme.purple.opacity(DesignSystem.Opacity.light))
                    .frame(width: DesignSystem.Metrics.mediumGlowSize, height: DesignSystem.Metrics.mediumGlowSize)
                    .blur(radius: 80)
                    .offset(x: isAnimating ? -180 : 180, y: isAnimating ? 80 : -80)
            }
            .animation(.easeInOut(duration: 10).repeatForever(autoreverses: true), value: isAnimating)
            
            VStack(spacing: ComponentSpacing.ultra) {
                Spacer()
                
                // 2. The Vault Icon Container
                ZStack {
                    // Rotating decorative rings
                    Circle()
                        .stroke(
                            LinearGradient(colors: [Color.appAccent.opacity(DesignSystem.Opacity.disabled), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: SystemStroke.divider
                        )
                        .frame(width: DesignSystem.Metrics.ringSmallSize, height: DesignSystem.Metrics.ringSmallSize)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .animation(.linear(duration: 20).repeatForever(autoreverses: false), value: isAnimating)
                    
                    Circle()
                        .stroke(
                            LinearGradient(colors: [.clear, Color.appAccent.opacity(DesignSystem.Opacity.medium)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: SystemStroke.divider
                        )
                        .frame(width: DesignSystem.Metrics.ringLargeSize, height: DesignSystem.Metrics.ringLargeSize)
                        .rotationEffect(.degrees(isAnimating ? -360 : 0))
                        .animation(.linear(duration: 25).repeatForever(autoreverses: false), value: isAnimating)

                    VStack(spacing: DesignSystem.wide) {
                        Image(systemName: DesignSystem.Icons.lockShieldFill)
                            .font(.largeTitle.weight(.ultraLight))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color.appAccent, Color.appAccent.opacity(DesignSystem.Opacity.overlay)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: Color.appAccent.opacity(DesignSystem.Opacity.disabled), radius: 30, y: 15)
                            .symbolEffect(.bounce, options: .repeat(2), value: isAnimating)
                    }
                }
                
                // 3. Information & Copy
                VStack(spacing: DesignSystem.medium) {
                    Text(L10n.Common.Security.vaultLocked)
                        .font(.system(size: titleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(.appText)
                    
                    Text(L10n.Common.Security.unlockHint)
                        .font(.subheadline)
                        .foregroundStyle(.appSecondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: DesignSystem.Gallery.modalMaxWidth)
                        .lineSpacing(4)
                }
                
                Spacer()
                
                // 4. Elegant Unlock Button
                Button(action: { 
                    #if os(iOS)
                    HapticFeedback.shared.trigger(.selection)
                    #endif
                    Task { await store.securityService.unlock() }
                }) {
                    HStack(spacing: DesignSystem.standardPadding) {
                        Image(systemName: unlockIcon)
                            .font(.title2)
                        
                        Text(L10n.Common.Security.unlock)
                            .font(.headline)
                    }
                    .padding(.horizontal, ComponentSpacing.ultra)
                    .padding(.vertical, SystemSpacing.medium)
                    .background {
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.appAccent, Color.appAccent.opacity(DesignSystem.Opacity.prominent)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            Capsule()
                                .stroke(.appGloss.opacity(DesignSystem.Opacity.disabled), lineWidth: 0.5)
                        }
                    }
                    .foregroundStyle(Color.theme.white)
                    .shadow(color: Color.appAccent.opacity(DesignSystem.Opacity.soft), radius: 25, y: 12)
                }
                .buttonStyle(ScaleButtonStyle())
                .padding(.bottom, ComponentSpacing.colossal)
            }
            .padding(.horizontal)
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// Moved to DesignSystem.swift
