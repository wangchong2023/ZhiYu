//
//  MacMenuCommands.swift
//  ZhiYu
//
//  系统层级：[L3] 应用层
//  核心职责：macOS 菜单命令（新建页面/退出守卫），归一主窗口菜单。
//
import SwiftUI
import Dependencies

/// macOS 菜单命令
struct MacMenuCommands: Commands {
    /// 打开窗口场景的环境依赖（用于唤起笔记本中心窗口）
    @Environment(\.openWindow) private var openWindow
    /// 全局路由（@MainActor 单例），用于 ⌘P 命令面板切换
    @Dependency(\.router) private var router

    var body: some Commands {
        // 文件：新建页面 (⌘N)
        CommandGroup(replacing: .newItem) {
            Button(L10n.Creation.newPage) {
                NotificationCenter.default.post(name: .createNewPage, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // 文件：命令面板 (⌘P)
        // 命令面板（CommandPalette）是全局搜索/指令入口，放"文件"分组以复用既有菜单标题。
        CommandGroup(after: .newItem) {
            Button(L10n.Search.commandPalette) { @MainActor in
                router.showCommandPalette.toggle()
            }
            .keyboardShortcut("p", modifiers: .command)
        }

        // 查看：切换侧边栏 (⌃⌘S) 与主工作区快捷切换 (⌘1–⌘5)
        CommandGroup(after: .toolbar) {
            Button(L10n.Common.Sidebar.toggle) {
                NotificationCenter.default.post(name: .toggleSidebar, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])

            Divider()

            Button(AppTab.knowledge.displayTitle) { @MainActor in
                router.selectedTab = .knowledge
            }
            .keyboardShortcut("1", modifiers: .command)

            Button(AppTab.chat.displayTitle) { @MainActor in
                router.selectedTab = .chat
            }
            .keyboardShortcut("2", modifiers: .command)

            Button(AppTab.ingest.displayTitle) { @MainActor in
                router.selectedTab = .ingest
            }
            .keyboardShortcut("3", modifiers: .command)

            Button(AppTab.synthesis.displayTitle) { @MainActor in
                router.selectedTab = .synthesis
            }
            .keyboardShortcut("4", modifiers: .command)

            Button(AppTab.graph.displayTitle) { @MainActor in
                router.selectedTab = .graph
            }
            .keyboardShortcut("5", modifiers: .command)
        }

        // 窗口：打开笔记本中心（匹配 MacSceneBuilder.windows() 的 notebook-hub 场景）
        CommandGroup(after: .windowArrangement) {
            Button(L10n.Notebook.openHub) {
                openWindow(id: "notebook-hub")
            }
        }

        // 帮助：官网链接
        CommandGroup(replacing: .help) {
            if let helpURL = URL(string: AppConstants.URLs.officialWebsite) {
                Link(L10n.Common.help, destination: helpURL)
            }
        }
    }
}
