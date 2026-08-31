//
//  PluginDetailDescriptionSection.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：插件详情页功能描述区，含 README 骨架屏加载态、降级选择链（本地缓存 → 远端多语言 →
//  简短描述）、折叠渐变展开交互，以及远端 README 的异步拉取逻辑。
//

import SwiftUI

// MARK: - 功能描述

extension PluginDetailView {

    var descriptionSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            Text(L10n.Plugin.section.about)
                .font(.headline)
                .foregroundStyle(.appText)

            // 如果本地没有 README 缓存，且远端 README 正在加载，则呈现骨架屏
            if localReadme == nil && isReadmeLoading {
                VStack(alignment: .leading, spacing: DesignSystem.small) {
                    AppSkeleton(height: Spacing.large, cornerRadius: DesignSystem.microRadius)
                    AppSkeleton(height: Spacing.large, cornerRadius: DesignSystem.microRadius)
                    AppSkeleton(width: 200, height: Spacing.large, cornerRadius: DesignSystem.microRadius)
                }
                .padding(.vertical, DesignSystem.small)
            } else {
                // 降级选择链：优先显示本地缓存的 README -> 远端多语言 README -> 插件自身的简短描述
                let content = localReadme ?? remoteReadme ?? plugin.description
                let lineCount = content.components(separatedBy: .newlines).count
                let showExpandButton = lineCount > FeatureConstants.PluginDescription.expandLineThreshold

                VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                    MarkdownRendererView(content: content, isPrivate: false, onLinkTap: { _ in }, isCompact: true)
                        .frame(maxHeight: (showExpandButton && !isDescriptionExpanded) ? 180 : nil, alignment: .top)
                        .clipped()
                        .overlay(
                            Group {
                                if showExpandButton && !isDescriptionExpanded {
                                    VStack {
                                        Spacer()
                                        // 渐变蒙层，在折叠状态下于底部实现优雅淡出效果
                                        LinearGradient(
                                            colors: [Color.appBackground.opacity(Double.zero), Color.appBackground.opacity(DesignSystem.Metrics.lockOverlayScaleMultiplier), Color.appBackground],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        .frame(height: DesignSystem.iconDisplay)
                                    }
                                }
                            }
                        )

                    if showExpandButton {
                        // 轻量级展开/折叠更多按钮
                        Button(action: {
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                isDescriptionExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: DesignSystem.tiny) {
                                Text(isDescriptionExpanded ? L10n.Plugin.Detail.showLess : L10n.Plugin.Detail.readMore)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.appAccent)
                                Image(systemName: isDescriptionExpanded ? "chevron.up" : "chevron.down")
                                    .font(.caption2.bold())
                                    .foregroundStyle(.appAccent)
                            }
                            .padding(.vertical, DesignSystem.atomic)
                        }
                    }
                }
            }
        }
    }

    /// 异步拉取云端多语言 README.md，包含首选语言 -> 英文 -> 默认无后缀的自动降级策略
    /// - Returns: Void。更新 `@State` 的 `remoteReadme` 与 `isReadmeLoading`。
    func fetchRemoteReadme() async {
        // 如果本地已存在 README 缓存，或者下载 URL 缺失，直接返回无需重复抓取
        guard localReadme == nil,
              let downloadURLString = plugin.downloadURL else { return }

        let urlsToTry = marketService.readmeCandidateURLs(forID: plugin.id, downloadURLString: downloadURLString)
        guard !urlsToTry.isEmpty else { return }

        await MainActor.run { isReadmeLoading = true }

        // 依次尝试降级拉取云端文档数据
        for readmeURL in urlsToTry {
            do {
                Logger.shared.info("PluginDetail.fetchRemoteReadme.try: \(readmeURL.absoluteString)")
                let (data, response) = try await URLSession.shared.data(from: readmeURL)
                let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

                if statusCode == FeatureConstants.HTTPStatusCode.ok, !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                    Logger.shared.info("PluginDetail.fetchRemoteReadme.success: \(readmeURL.lastPathComponent)")
                    await MainActor.run {
                        self.remoteReadme = text
                        self.isReadmeLoading = false
                    }
                    return
                }
            } catch {
                Logger.shared.warning("PluginDetail.fetchRemoteReadme.error: \(readmeURL.lastPathComponent), error: \(error.localizedDescription)")
            }
        }

        await MainActor.run { isReadmeLoading = false }
    }
}
