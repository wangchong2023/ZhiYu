// 系统层级: L3 表现层
// 核心职责: 插件远程图标加载器，消除 PluginCenterView 与 PluginDetailHeaderSection 的 CachedAsyncImage phase switch 重复

import SwiftUI

/// 插件远程图标加载器
///
/// 统一 `PluginCenterView` 与 `PluginDetailHeaderSection` 中重复的
/// `CachedAsyncImage(url:) { phase in switch phase { ... } }` 模式。
/// 通过 `size`、`cornerRadius`、`strokeOpacity`、`emptyContent` 与 `fallback` 参数注入差异化样式。
@MainActor
struct PluginRemoteIconLoader<Empty: View, Fallback: View>: View {
    let iconURL: URL
    let size: CGFloat
    let cornerRadius: CGFloat
    let strokeOpacity: Double
    let strokeColor: Color
    @ViewBuilder let emptyContent: () -> Empty
    @ViewBuilder let fallback: () -> Fallback

    var body: some View {
        CachedAsyncImage(url: iconURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .scaledToFit()
            case .empty:
                emptyContent()
            case .failure:
                fallback()
            @unknown default:
                fallback()
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(strokeColor.opacity(strokeOpacity), lineWidth: SystemStroke.hairline)
        )
    }
}
