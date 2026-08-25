//
//  SettingsComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：系统设置：LLM 配置、性能监控、插件管理、iCloud、备份。
//
import SwiftUI
import Dependencies

// MARK: - 插件扩展组件

struct PluginExtensionsSection: View {
    @Dependency(\.pluginRegistry) var registry

    var body: some View {
        if !registry.settingTabs.isEmpty {
            Section(header: Text(L10n.Plugin.section.pluginSettings)) {
                ForEach(registry.settingTabs) { tab in
                    NavigationLink(destination: PluginCustomSettingsView(tab: tab)) {
                        HStack {
                            Image(systemName: DesignSystem.Icons.puzzlepieceExtension)
                                .foregroundStyle(.appAccent)
                                .frame(width: DesignSystem.IconSize.standard)
                            Text(tab.name)
                                .foregroundStyle(.appText)
                            Spacer()
                        }
                    }
                }
            }
        }
    }
}

/// 插件扩展详情视图：有已安装插件时展示设置列表，无插件时展示空状态引导
struct PluginExtensionsDetailView: View {
    @Dependency(\.pluginRegistry) var registry
    @State private var showPluginCenter = false

    var body: some View {
        Group {
            if registry.settingTabs.isEmpty {
                // 无已安装插件：空状态引导页
                VStack(spacing: DesignSystem.large) {
                    Image(systemName: "puzzlepiece.extension.fill")
                        .font(.system(size: Reference.FontSize.mega)) // Dynamic Type
                        .foregroundStyle(.appSecondary)

                    Text(L10n.Plugin.settings.noSettings)
                        .font(.headline)
                        .foregroundStyle(.appText)

                    Button(action: { showPluginCenter = true }) {
                        Label(L10n.Plugin.title, systemImage: "plus.circle.fill")
                            .font(.body.weight(.medium))
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .sheet(isPresented: $showPluginCenter) {
                    NavigationStack {
                        PluginCenterView()
                    }
                }
            } else {
                // 有已安装插件：展示设置列表
                List {
                    PluginExtensionsSection()
                        .appListRowBackground()
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }
}
