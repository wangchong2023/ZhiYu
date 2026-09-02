//
//  PluginIconView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/09/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：插件图标展示组件，统一支持本地 PNG 缓存、远程 URL 加载与 SF Symbol 降级 (DRY)。
//

import SwiftUI
import UFPCore

/// [L3] 表现层：插件图标渲染组件
struct PluginIconView: View {
    let icon: String
    let localIcon: UIImage?
    let size: CGFloat
    let cornerRadius: CGFloat
    var shadowRadius: CGFloat = 0
    var shadowY: CGFloat = 0

    var body: some View {
        Group {
            if let uiImage = localIcon {
                Image(uiImage: uiImage)
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
            } else if let iconURL = URL(string: icon), iconURL.scheme?.hasPrefix(SystemConstants.URLScheme.httpLiteral) == true {
                CachedAsyncImage(url: iconURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                    case .empty:
                        AppSkeleton(width: size, height: size, cornerRadius: cornerRadius)
                            .overlay(ProgressView().controlSize(.small))
                    case .failure:
                        fallbackSymbolIcon
                    @unknown default:
                        fallbackSymbolIcon
                    }
                }
            } else {
                fallbackSymbolIcon
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.appBorder.opacity(SystemOpacity.glass), lineWidth: SystemStroke.hairline)
        )
        .shadow(
            color: shadowRadius > 0 ? Color.theme.black.opacity(DesignSystem.subtleOpacity) : .clear,
            radius: shadowRadius,
            x: 0,
            y: shadowY
        )
    }

    private var fallbackSymbolIcon: some View {
        Image(systemName: icon.isEmpty ? DesignSystem.Icons.puzzlepieceExtensionFill : icon)
            .font(.system(size: size * FeatureConstants.PluginDetailIconScale.main))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [Color.appAccent, Color.appAccent.opacity(SystemOpacity.textSecondary)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }
}
