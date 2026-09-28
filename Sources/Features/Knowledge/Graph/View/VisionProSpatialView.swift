//
//  VisionProSpatialView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 VisionProSpatial 界面的 UI 视图层组件。
//
import SwiftUI
import UFPDesignSystem

struct VisionProSpatialView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) var themeManager
    
    var body: some View {
        ZStack {
            // Background mesh gradient
            themeManager.pageBackground()
                .ignoresSafeArea()
            
            VStack(spacing: DesignTokens.Spacing.giant) {
                header(title: L10n.Common.Spatial.title, subtitle: L10n.Common.Spatial.subtitle)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
                        Text(L10n.Common.Spatial.features)
                            .font(.headline)
                            .foregroundStyle(.appText)
                        
                        SpatialFeatureRow(icon: DesignTokens.Icons.cubeTransparent, title: L10n.Common.Spatial.featureGraph3D, desc: L10n.Common.Spatial.featureGraph3DDesc)
                        SpatialFeatureRow(icon: DesignTokens.Icons.handTap, title: L10n.Common.Spatial.featureGesture, desc: L10n.Common.Spatial.featureGestureDesc)
                        SpatialFeatureRow(icon: DesignTokens.Icons.eyeFill, title: L10n.Common.Spatial.featureGaze, desc: L10n.Common.Spatial.featureGazeDesc)
                        SpatialFeatureRow(icon: DesignTokens.Icons.personCropPlus, title: L10n.Common.Spatial.featureSpatialAudio, desc: L10n.Common.Spatial.featureSpatialAudioDesc)
                    }
                    .appContainer(cornerRadius: DesignTokens.Spacing.largeRadius, padding: true)
                    
                    // Device Requirement
                    VStack(spacing: DesignTokens.Spacing.small) {
                        Image(systemName: DesignTokens.Icons.visionpro)
                            .font(.largeTitle)
                            .foregroundStyle(.appAccent)
                        
                        Text(L10n.Common.Spatial.requirement)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, DesignTokens.ComponentSpacing.ultra)
                }
            }
            .padding()
        }
        .navigationTitle(L10n.Common.Spatial.title)
        .doneDismissToolbar()
    }
    
    private func header(title: String, subtitle: String) -> some View {
        VStack(spacing: DesignTokens.Spacing.small) {
            Text(title)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(.appText)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
        }
        .padding(.top, DesignTokens.Spacing.wide)
    }
}

struct SpatialFeatureRow: View {
    let icon: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.standardPadding) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.appAccent)
                .frame(width: DesignTokens.IconSize.xlarge, height: DesignTokens.IconSize.xlarge)
                .background(Color.appAccent.opacity(DesignTokens.Opacity.subtle))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.atomic) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.appText)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.small)
    }
}

#Preview {
    NavigationStack {
        VisionProSpatialView()
            .environment(ThemeManager())
    }
}
