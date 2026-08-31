//
//  CommandPaletteView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 CommandPalette 界面的 UI 视图层组件。
//
import SwiftUI
import Dependencies

/// 全局指令中枢 (Command Palette)
/// 满足硬核用户 Cmd+K 盲操需求，极大缩短交互路径。
struct CommandPaletteView: View {
    @Environment(KnowledgeStore.self) var store
    @Environment(\.dismiss) var dismiss
    @Dependency(\.pluginRegistry) var registry
    @State private var searchText = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜索栏
            HStack {
                Image(systemName: DesignSystem.Icons.command)
                    .foregroundStyle(.appAccent)
                TextField(L10n.Common.Palette.searchPlaceholder, text: $searchText)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                Text(L10n.Common.Global.esc)
                    .font(.caption2.weight(.bold))
                    .padding(DesignSystem.tiny)
                    .background(Color.appBorder.opacity(DesignSystem.Opacity.shadow))
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.microRadius))
            }
            .padding()
            .background(Color.appCard)
            
            Divider()
            
            // 结果列表
            List {
                Section(L10n.Action.cmd.quickActions) {
                    CommandRow(icon: DesignSystem.Icons.sparkles, title: L10n.Action.cmd.deepExplore, shortcut: "") {
                        // 触发逻辑
                        dismiss()
                    }
                    CommandRow(icon: DesignSystem.Icons.docBadgePlus, title: L10n.Action.cmd.newKnowledgePage, shortcut: "N") {
                        dismiss()
                    }
                }
                
                // 插件指令板块
                if !registry.commands.isEmpty {
                    let filteredCommands = registry.commands.filter { 
                        searchText.isEmpty || $0.name.localizedCaseInsensitiveContains(searchText) 
                    }
                    
                    if !filteredCommands.isEmpty {
                        Section(L10n.Plugin.commands.title) {
                            ForEach(filteredCommands) { command in
                                CommandRow(icon: DesignSystem.Icons.pluginOutline, title: command.name) {
                                    command.action()
                                    dismiss()
                                }
                            }
                        }
                    }
                }
                
                Section(L10n.Action.cmd.recentAccess) {
                    ForEach(store.pages.prefix(FeatureConstants.CommandPalette.recentAccessCount)) { page in
                        CommandRow(icon: page.pageType.icon, title: page.title) {
                            dismiss()
                        }
                    }
                }
            }
            .listStyle(.plain)
            .frame(height: DesignSystem.Metrics.commandPaletteHeight)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius, style: .continuous))
            .shadow(color: Color.appAccent.opacity(DesignSystem.Opacity.shadow), radius: DesignSystem.mediumRadius)
        }
        .frame(width: DesignSystem.Metrics.commandPaletteWidth)
        .onAppear { isFocused = true }
    }
}

private struct CommandRow: View {
    let icon: String
    let title: String
    var shortcut: String?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: DesignSystem.IconSize.small)
                Text(title)
                    .font(.subheadline)
                Spacer()
                if let sc = shortcut {
                    Text(sc)
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                }
            }
        }
    }
}
