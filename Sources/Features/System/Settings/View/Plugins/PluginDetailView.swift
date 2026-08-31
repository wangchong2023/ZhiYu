//
//  PluginDetailView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：参照业界最佳实践（VS Code 扩展商店、Obsidian 社区插件）构建插件详情展示页面容器，
//  负责状态持有与各 Section 子视图的分发组合。各功能 Section 已拆分至独立文件。
//

import SwiftUI
import Dependencies

/// 插件详情页（参照 VS Code 扩展商店 / Obsidian 社区插件标准）
struct PluginDetailView: View {
    let plugin: MarketPlugin
    @ObservedObject var marketService: PluginMarketService
    @Dependency(\.pluginRegistry) var registry

    @Environment(\.dismiss) var dismiss
    @State var isInstalling = false
    @State var localIcon: UIImage?
    @State var localReadme: String?
    @State var remoteReadme: String?
    @State var isReadmeLoading = false
    @State var isDescriptionExpanded = false

    /// 计算插件的当前展示版本 (如果已安装则展示本地已安装的真实版本号，否则展示市场版本)
    var displayVersion: String {
        // 兼容简短 ID 和物理包名规范 ID 的后缀匹配，寻找对应的本地已安装插件实体
        if let localPlugin = registry.plugins.first(where: {
            $0.manifest.id == plugin.id || $0.manifest.id.hasSuffix("." + plugin.id)
        }) {
            return localPlugin.manifest.version
        }
        return plugin.version
    }

    /// 校验该插件是否已经成功下载并安装落地于沙盒中
    var isInstalled: Bool {
        // 检查 PluginRegistry 中是否存在完全匹配或后缀点拼接匹配（.id）的插件实例
        registry.plugins.contains(where: {
            $0.manifest.id == plugin.id || $0.manifest.id.hasSuffix("." + plugin.id)
        })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.giant) {

                // MARK: - 1. 头部信息区 (Squircle 图标与简要)
                headerSection

                // MARK: - 2. 操作按钮 (获取/卸载与分享)
                actionButtons

                if let error = marketService.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(Color.theme.red)
                        .padding(.top, -DesignSystem.small)
                }

                Divider()

                // MARK: - App Store 风格快捷指标横向栏
                appStoreMetricsBar

                Divider()

                // MARK: - 4. 功能描述 (README 折叠渐变展开)
                descriptionSection

                Divider()

                // MARK: - 5. 权限声明
                permissionsSection

                Divider()

                // MARK: - 3. 详细信息面板 (底栏信息)
                metadataSection
            }
            .padding()
        }
        .background(PageBackgroundView(accentColor: .appAccent))
        .task {
            // 异步加载本地图标和 README，支持包名 ID（如 com.zhiyu.plugin...）与市场简短 ID 的模糊联通匹配，避免主线程 I/O 阻塞
            let targetID = registry.plugins.first(where: {
                $0.manifest.id == plugin.id || $0.manifest.id.hasSuffix("." + plugin.id)
            })?.manifest.id ?? plugin.id

            if let url = registry.iconURL(for: targetID) {
                localIcon = UIImage(data: (try? Data(contentsOf: url)) ?? Data())
            }
            localReadme = registry.localizedReadme(for: targetID)

            // 异步拉取云端多语言 README
            await fetchRemoteReadme()
        }
        .appNavigationBarTitleDisplayMode(.inline)
    }
}
