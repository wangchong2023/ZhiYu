//
//  MedalComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：成就勋章墙：解锁条件追踪与视觉展示。
//
import SwiftUI

/// 奖章卡片视图
struct MedalCard: View {
    let medal: MedalService.Medal
    let isEarned: Bool
    
    var body: some View {
        VStack(spacing: DesignSystem.medium) {
            ZStack {
                let baseColor = Color(hex: medal.colorHex)
                let fillColor = isEarned ? baseColor.opacity(SystemOpacity.glass) : Color.appBorder.opacity(SystemOpacity.disabled) // 0.1
                
                Circle()
                    .fill(fillColor)
                    .frame(width: DesignSystem.Gallery.itemSize, height: DesignSystem.Gallery.itemSize)
                
                Image(systemName: medal.icon)
                    .font(.system(size: DesignSystem.Gallery.iconSize, weight: .bold))
                    .foregroundStyle(isEarned ? baseColor : .appSecondary.opacity(DesignSystem.secondaryOpacity * 0.625)) // 0.5
                
                if !isEarned {
                    Image(systemName: DesignSystem.Icons.lock)
                        .font(.caption2)
                        .padding(DesignSystem.tiny)
                        .background(Circle().fill(.ultraThinMaterial))
                        .offset(x: DesignSystem.Gallery.badgeOffset, y: DesignSystem.Gallery.badgeOffset)
                }
            }
            
            VStack(spacing: DesignSystem.tiny) {
                Text(L10n.Insight.tr(medal.titleKey))
                    .font(.system(size: DesignSystem.subheadlineFontSize, weight: .bold))
                    .foregroundStyle(isEarned ? .appText : .appSecondary)
                
                Text(L10n.Insight.tr(medal.descKey))
                    .font(.system(size: DesignSystem.microFontSize))
                    .foregroundStyle(.appSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(DesignSystem.standardPadding)
        .frame(maxWidth: .infinity)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Gallery.itemRadius))
        .overlay {
            let overlayColor = isEarned ? Color(hex: medal.colorHex).opacity(SystemOpacity.glassStrong) : Color.appBorder.opacity(SystemOpacity.disabled)
            RoundedRectangle(cornerRadius: DesignSystem.Gallery.itemRadius)
                .stroke(overlayColor, lineWidth: DesignSystem.borderWidth)
        }
        .shadow(color: isEarned ? Color(hex: medal.colorHex).opacity(SystemOpacity.disabled) : .clear, radius: SystemRadius.small, y: SystemStroke.heavy)
        .grayscale(isEarned ? 0 : 1)
        .opacity(isEarned ? DesignSystem.fullOpacity : DesignSystem.secondaryOpacity + 0.1) // 0.7
    }
}

/// 奖章奖励弹窗
struct MedalRewardPopup: View {
    let medal: MedalService.Medal
    let onDismiss: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Color.theme.black.opacity(DesignSystem.disabledOpacity + 0.1) // 0.4
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
            
            VStack(spacing: DesignSystem.loosePadding) {
                // 顶部闪烁装饰
                ZStack {
                    let baseColor = Color(hex: medal.colorHex)
                    Circle()
                        .fill(baseColor.opacity(DesignSystem.dimmedOpacity))
                        .frame(width: DesignSystem.Gallery.displayIconSize, height: DesignSystem.Gallery.displayIconSize)
                        .blur(radius: DesignSystem.Gallery.blurRadius)
                        .scaleEffect(isAnimating ? 1.2 : 0.8)
                    
                    Image(systemName: medal.icon)
                        .font(.system(size: DesignSystem.Gallery.mainIconSize, weight: .black))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [baseColor, baseColor.opacity(DesignSystem.Opacity.dim)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: baseColor.opacity(DesignSystem.secondaryOpacity / 1.6), radius: DesignSystem.loosePadding, y: DesignSystem.standardPadding) // 0.5, 20, 10
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                }
                .padding(.top, DesignSystem.Gallery.blurRadius)
                
                VStack(spacing: DesignSystem.medium) {
                    Text(L10n.Insight.Medal.congrats)
                        .font(.subheadline.bold())
                        .foregroundStyle(.appAccent)
                        .kerning(Reference.Spacing.two)
                    
                    Text(L10n.Insight.tr(medal.titleKey))
                        .font(.title.bold())
                        .foregroundStyle(.appText)
                    
                    Text(L10n.Insight.tr(medal.descKey))
                        .font(.body)
                        .foregroundStyle(.appSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, DesignSystem.Metrics.heroValueSize)
                }
                
                Button(action: onDismiss) {
                    let baseColor = Color(hex: medal.colorHex)
                    Text(L10n.Common.awesome)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: DesignSystem.Gallery.callToActionWidth, height: DesignSystem.Gallery.callToActionHeight)
                        .background {
                            Capsule()
                                .fill(LinearGradient(colors: [baseColor, baseColor.opacity(DesignSystem.secondaryOpacity)], startPoint: .leading, endPoint: .trailing))
                        }
                        .shadow(color: baseColor.opacity(DesignSystem.disabledOpacity), radius: SystemRadius.small, y: DesignSystem.microRadius + DesignSystem.atomic) // 0.3, 10, 5
                }
                .padding(.bottom, DesignSystem.Gallery.blurRadius)
                .scaleEffect(isAnimating ? 1 : 0.9)
            }
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Gallery.containerRadius)
                    .fill(Color.appCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.Gallery.containerRadius)
                            .stroke(LinearGradient(colors: [.appGloss.opacity(DesignSystem.dimmedOpacity), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: DesignSystem.borderWidth)
                    )
            )
            .padding(DesignSystem.Gallery.containerPadding)
            .scaleEffect(isAnimating ? 1 : 0.5)
            .opacity(isAnimating ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7, blendDuration: 0)) {
                isAnimating = true
            }
        }
    }
}
