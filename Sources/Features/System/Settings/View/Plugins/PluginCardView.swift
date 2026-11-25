//
//  PluginCardView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / 插件市场组件
//  核心职责：提供插件来源标识枚举（PluginSource）与通用插件卡片视图（PluginCard），
//           支持本地/远程图标加载、版本号自适应展示与一键安装/卸载交互。
//

import SwiftUI
import Dependencies
import UFPCore
import UFPDesignSystem

/// 插件来源类型
enum PluginSource: String {
    case local
    case community
    /// 市场列表未加载时的未知来源状态，避免将社区插件误判为本地
    case unknown
}

/// 插件卡片通用视图组件
struct PluginCard: View {
    let name: String
    let version: String
    var author: String?
    var downloads: String?
    var rating: Double?
    var icon: String = "puzzlepiece.fill"
    var pluginID: String?
    var source: PluginSource?
    var isLocal: Bool = false
    var marketPlugin: MarketPlugin?
    var marketService: PluginMarketService?

    private var isInstalled: Bool {
        guard let id = pluginID else { return false }
        return registry.plugins.contains {
            $0.manifest.id == id || $0.manifest.id.hasSuffix("." + id)
        }
    }

    @Dependency(\.pluginRegistry) var registry
    @State private var localIcon: AppImage?

    /// 自适应计算插件的展示版本号，已安装则优先显示真实本地版本号
    private var displayVersion: String {
        if let id = pluginID, let localPlugin = findLocalPlugin(for: id) {
            return localPlugin.manifest.version
        }
        return version
    }

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.standardPadding) {
            // 优先显示本地 icon.png，fallback SF Symbol
            if let appImage = localIcon {
                Image(appImage: appImage)
                    .renderingMode(.original)
                    .resizable().scaledToFit()
                    .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.card, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.card, style: .continuous).stroke(Color.appBorder.opacity(DesignTokens.SystemOpacity.glass), lineWidth: DesignTokens.SystemStroke.hairline))
            } else if let iconURL = URL(string: icon), iconURL.scheme?.hasPrefix(SystemConstants.URLScheme.httpLiteral) == true {
                PluginRemoteIconLoader(
                    iconURL: iconURL,
                    size: DesignSystem.Action.minTouchTarget,
                    cornerRadius: DesignTokens.SystemRadius.card,
                    strokeOpacity: DesignTokens.SystemOpacity.glass,
                    strokeColor: Color.appBorder,
                    emptyContent: {
                        // 网络图标加载中时，展示静止淡雅的拼图占位符，去除凌乱的局部菊花与闪烁
                        Image(systemName: DesignTokens.Icons.puzzlepieceExtensionFill)
                            .font(.title3)
                            .foregroundStyle(.appSecondary.opacity(DesignTokens.Colors.Opacity.disabledOpacity))
                            .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
                            .background(Color.appCard.opacity(DesignTokens.Opacity.prominent))
                    },
                    fallback: { pluginCardFallbackIcon }
                )
            } else {
                pluginGradientIcon(icon)
                    .pluginIconContainerStyle(cornerRadius: DesignTokens.SystemRadius.card, strokeOpacity: DesignTokens.SystemOpacity.glass)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.tiny) {
                Text(name)
                    .font(.subheadline.bold())
                    .foregroundStyle(.appText)

                HStack(spacing: DesignTokens.Spacing.tightPadding) {
                    Text("v\(displayVersion)")
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)

                    // 来源类型微缩标签
                    if let src = source {
                        Text(sourceLabel(src))
                            .font(.system(size: DesignTokens.Typography.microFontSize, weight: .bold))
                            .padding(.horizontal, DesignTokens.SystemSpacing.tiny)
                            .padding(.vertical, DesignTokens.SystemSpacing.atomic)
                            .background(sourceColor(src))
                            .clipShape(Capsule())
                            .foregroundStyle(.white)
                    }

                    if let author = author {
                        Text(DesignTokens.Icons.bullet)
                            .font(.caption2)
                            .foregroundStyle(.appSecondary)
                        Text(author)
                            .font(.caption2)
                            .foregroundStyle(.appSecondary)
                    }
                }

                if let downloads = downloads, let rating = rating {
                    HStack(spacing: DesignTokens.Spacing.tightPadding) {
                        Label(downloads, systemImage: DesignTokens.Icons.arrowDownCircle)
                            .font(.system(size: DesignTokens.Typography.microFontSize))
                        Label(String(format: "%.1f", rating), systemImage: DesignTokens.Icons.star)
                            .font(.system(size: DesignTokens.Typography.microFontSize))
                            .foregroundStyle(Color.theme.yellow)
                    }
                    .foregroundStyle(.appSecondary)
                    .padding(.top, DesignTokens.SystemSpacing.atomic)
                }
            }
            Spacer()

            // 快捷安装 / 卸载一键操作按钮
            actionButton

            Image(systemName: DesignTokens.Icons.forward)
                .font(.caption2)
                .foregroundStyle(.appSecondary)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.section, style: .continuous).fill(.ultraThinMaterial))
        .overlay(RoundedRectangle(cornerRadius: DesignTokens.SystemRadius.section, style: .continuous).stroke(Color.theme.white.opacity(DesignTokens.SystemOpacity.glass), lineWidth: DesignTokens.SystemStroke.hairline))
        .shadow(color: Color.theme.black.opacity(DesignTokens.SystemOpacity.faint), radius: DesignTokens.SystemShadow.radiusMedium, x: 0, y: DesignTokens.SystemShadow.offsetSmall)
        .task {
            if let id = pluginID {
                // 兼容支持物理包名 ID 与市场简短 ID 的匹配
                let targetID = resolveTargetID(for: id)

                if let url = registry.iconURL(for: targetID) {
                    // 使用后台异步线程在非 UI 线程中读取物理图片数据，避免直接读取 I/O 导致 UI 卡顿
                    Task.detached(priority: .background) {
                        if let data = try? Data(contentsOf: url), let image = AppImage(data: data) {
                            await MainActor.run {
                                self.localIcon = image
                            }
                        }
                    }
                }
            }
        }
    }

    private func sourceLabel(_ src: PluginSource) -> String {
        switch src {
        case .local: return L10n.Plugin.Detail.categoryLocal
        case .community: return L10n.Plugin.Detail.categoryCommunity
        case .unknown: return L10n.Plugin.Detail.categoryUnknown
        }
    }

    private func sourceColor(_ src: PluginSource) -> Color {
        switch src {
        case .local: return Color.theme.green
        case .community: return Color.theme.orange
        case .unknown: return Color.theme.gray
        }
    }

    @ViewBuilder
    private var actionButton: some View {
        if isInstalled {
            HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                Image(systemName: DesignTokens.Icons.delete)
                    .font(.caption2)
                Text(L10n.Plugin.Action.uninstall)
                    .font(.caption.bold())
            }
            .actionPillStyle(background: Color.theme.red)
            .onTapGesture {
                guard let id = pluginID else { return }
                HapticFeedback.shared.trigger(.success)
                let targetID = resolveTargetID(for: id)
                registry.unloadPlugin(id: targetID)
            }
        } else if let marketPlugin = marketPlugin, let service = marketService {
            let isDownloading = service.downloadingPluginID == pluginID
            HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                if isDownloading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: DesignTokens.Icons.icloudArrowDown)
                        .font(.caption2)
                }
                Text(L10n.Plugin.Action.install)
                    .font(.caption.bold())
            }
            .actionPillStyle(background: Color.appAccent)
            .onTapGesture {
                guard !isDownloading else { return }
                HapticFeedback.shared.trigger(.selection)
                Task {
                    _ = await service.downloadPlugin(marketPlugin)
                }
            }
        }
    }

    /// 远程图标加载失败时的 fallback 拼图块默认图标（带渐变底）
    private var pluginCardFallbackIcon: some View {
        pluginGradientIcon(DesignTokens.Icons.puzzlepieceExtensionFill)
    }

    /// 构建带渐变背景的插件图标，消除 Image+LinearGradient 重复
    private func pluginGradientIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.title3)
            .foregroundStyle(.white)
            .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
            .background(LinearGradient(colors: [Color.appAccent, Color.appAccent.opacity(DesignTokens.SystemOpacity.active)], startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    /// 查找本地已安装插件实体，消除 displayVersion 与 resolveTargetID 的重复查询
    private func findLocalPlugin(for id: String) -> KnowledgePlugin? {
        registry.plugins.first(where: {
            $0.manifest.id == id || $0.manifest.id.hasSuffix("." + id)
        })
    }

    /// 解析插件真实 ID，兼容物理包名 ID 与市场简短 ID 的匹配
    private func resolveTargetID(for id: String) -> String {
        findLocalPlugin(for: id)?.manifest.id ?? id
    }
}

/// 插件卡片图标容器样式修饰符，消除重复的 frame+clipShape+overlay 链
private extension View {
    func pluginIconContainerStyle(cornerRadius: CGFloat, strokeOpacity: Double) -> some View {
        self
            .frame(width: DesignSystem.Action.minTouchTarget, height: DesignSystem.Action.minTouchTarget)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(Color.theme.white.opacity(strokeOpacity), lineWidth: DesignTokens.SystemStroke.hairline))
    }

    /// 操作按钮胶囊样式，消除重复的 padding+background+clipShape+foregroundStyle+contentShape 链
    func actionPillStyle(background: Color) -> some View {
        self
            .padding(.horizontal, DesignTokens.SystemSpacing.small)
            .padding(.vertical, DesignTokens.SystemSpacing.tiny)
            .background(background)
            .clipShape(Capsule())
            .foregroundStyle(.white)
            .contentShape(Capsule())
    }
}
