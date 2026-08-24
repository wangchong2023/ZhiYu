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

struct VisionProSpatialView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) var themeManager
    
    var body: some View {
        ZStack {
            // Background mesh gradient
            themeManager.pageBackground()
                .ignoresSafeArea()
            
            VStack(spacing: DesignSystem.giant) {
                header(title: L10n.Common.Spatial.title, subtitle: L10n.Common.Spatial.subtitle)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.medium) {
                        Text(L10n.Common.Spatial.features)
                            .font(.headline)
                            .foregroundStyle(.appText)
                        
                        SpatialFeatureRow(icon: DesignSystem.Icons.cubeTransparent, title: L10n.Common.Spatial.featureGraph3D, desc: L10n.Common.Spatial.featureGraph3DDesc)
                        SpatialFeatureRow(icon: DesignSystem.Icons.handTap, title: L10n.Common.Spatial.featureGesture, desc: L10n.Common.Spatial.featureGestureDesc)
                        SpatialFeatureRow(icon: DesignSystem.Icons.eyeFill, title: L10n.Common.Spatial.featureGaze, desc: L10n.Common.Spatial.featureGazeDesc)
                        SpatialFeatureRow(icon: DesignSystem.Icons.personCropPlus, title: L10n.Common.Spatial.featureSpatialAudio, desc: L10n.Common.Spatial.featureSpatialAudioDesc)
                    }
                    .appContainer(cornerRadius: DesignSystem.largeRadius, padding: true)
                    
                    // Device Requirement
                    VStack(spacing: DesignSystem.small) {
                        Image(systemName: DesignSystem.Icons.visionpro)
                            .font(.largeTitle)
                            .foregroundStyle(.appAccent)
                        
                        Text(L10n.Common.Spatial.requirement)
                            .font(.caption)
                            .foregroundStyle(.appSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, ComponentSpacing.ultra)
                }
            }
            .padding()
        }
        .navigationTitle(L10n.Common.Spatial.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.Common.done) { dismiss() }
            }
        }
    }
    
    private func header(title: String, subtitle: String) -> some View {
        VStack(spacing: DesignSystem.small) {
            Text(title)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(.appText)
            
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
        }
        .padding(.top, DesignSystem.wide)
    }
}

struct SpatialFeatureRow: View {
    let icon: String
    let title: String
    let desc: String
    
    var body: some View {
        HStack(spacing: DesignSystem.standardPadding) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.appAccent)
                .frame(width: DesignSystem.IconSize.xlarge, height: DesignSystem.IconSize.xlarge)
                .background(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.appText)
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, DesignSystem.small)
    }
}

#Preview {
    NavigationStack {
        VisionProSpatialView()
            .environment(ThemeManager())
    }
}
