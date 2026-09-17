// 系统层级：[L3] 表现层
// 核心职责：插件图标名称映射工具与 fallback 图标样式，根据插件 ID 特征返回对应的 SF Symbol 名称

import SwiftUI

/// 插件图标名称解析器，消除跨文件的 ID→SF Symbol 映射重复逻辑
enum PluginIconResolver {
    /// 根据插件 ID 智能映射默认 SF Symbol 兜底图标，防止在未解压或无本地物理图片时各插件展示单一的拼图块
    static func localIconName(for id: String) -> String {
        if id.contains(PluginConstants.LocalIconKeyword.tocGenerator) {
            return "list.bullet.rectangle.portrait"
        } else if id.contains(PluginConstants.LocalIconKeyword.wordCounter) {
            return "character.textbox"
        } else if id.contains(PluginConstants.LocalIconKeyword.smartCleaner) {
            return "wand.and.stars"
        } else if id.contains(PluginConstants.LocalIconKeyword.aiSummary) {
            return "brain.head.profile"
        } else if id.contains(PluginConstants.LocalIconKeyword.codeHighlighter) {
            return "curlybraces"
        } else if id.contains(PluginConstants.LocalIconKeyword.linkPreview) {
            return "link"
        } else if id.contains(PluginConstants.LocalIconKeyword.aiTranslator) {
            return "translate"
        } else if id.contains(PluginConstants.LocalIconKeyword.markdownBeautifier) {
            return "doc.text.magnifyingglass"
        } else {
            return DesignSystem.Icons.puzzlepieceExtensionFill
        }
    }
}

/// 插件 fallback 图标样式修饰符，消除 LocalPluginDetailView 与 PluginDetailHeaderSection 的重复
struct PluginFallbackIconStyle: ViewModifier {
    let iconName: String
    let gradientOpacity: Double

    func body(content: Content) -> some View {
        Image(systemName: iconName)
            .font(.system(size: DesignSystem.Gallery.mainIconSize * FeatureConstants.PluginDetailIconScale.main))
            .foregroundStyle(.white)
            .frame(width: DesignSystem.Gallery.itemSize, height: DesignSystem.Gallery.itemSize)
            .background(
                LinearGradient(colors: [Color.appAccent, Color.appAccent.opacity(gradientOpacity)],
                               startPoint: .topLeading, endPoint: .bottomTrailing))
    }
}

extension View {
    /// 应用插件 fallback 图标样式
    func pluginFallbackIconStyle(iconName: String, gradientOpacity: Double = DesignSystem.Opacity.prominent) -> some View {
        modifier(PluginFallbackIconStyle(iconName: iconName, gradientOpacity: gradientOpacity))
    }
}

/// 插件版本号标签样式修饰符，消除 LocalPluginDetailView 与 PluginDetailHeaderSection 的重复
struct PluginVersionTagStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, DesignSystem.small)
            .padding(.vertical, DesignSystem.tiny)
            .background(Color.appAccent.opacity(DesignSystem.Opacity.subtle))
            .foregroundStyle(.appAccent)
            .clipShape(Capsule())
    }
}

extension View {
    /// 应用插件版本号标签样式
    func pluginVersionTagStyle() -> some View {
        modifier(PluginVersionTagStyle())
    }
}

/// 插件本地图标基础样式，消除 LocalPluginDetailView 与 PluginDetailHeaderSection 的 Image 基础配置重复
extension Image {
    /// 应用插件本地图标基础样式
    func pluginLocalIconBase() -> some View {
        self
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
            .frame(width: DesignSystem.Gallery.itemSize, height: DesignSystem.Gallery.itemSize)
    }
}

/// 插件详情行视图，消除 LocalPluginDetailView 与 PluginDetailMetadataSection 的 detailRow/metadataRow 重复
struct PluginDetailRow: View {
    let icon: String
    let label: String
    let value: String
    var lineLimit: Int? = .none
    var valueTrailing: Bool = false

    var body: some View {
        HStack(spacing: DesignSystem.medium) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.appAccent)
                .frame(width: DesignSystem.IconSize.small)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
                .fixedSize(horizontal: true, vertical: false)
                .modifier(LineLimitModifier(lineLimit: lineLimit))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.appText)
                .multilineTextAlignment(valueTrailing ? .trailing : .leading)
        }
        .padding(.horizontal, DesignSystem.medium)
        .padding(.vertical, SystemSpacing.small)
    }
}

/// lineLimit 可选修饰符
private struct LineLimitModifier: ViewModifier {
    let lineLimit: Int?
    func body(content: Content) -> some View {
        if let lineLimit {
            content.lineLimit(lineLimit)
        } else {
            content
        }
    }
}
