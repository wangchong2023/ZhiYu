//
//  MacMenuCommands.swift
//  ZhiYu
//
//  系统层级：[L3] 应用层
//  核心职责：macOS 菜单命令（新建页面/退出守卫），归一主窗口菜单。
//
import SwiftUI

/// macOS 菜单命令
struct MacMenuCommands: Commands {
    /// 打开窗口场景的环境依赖（用于唤起笔记本中心窗口）
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        // 文件：新建页面 (⌘N)
        CommandGroup(replacing: .newItem) {
            Button(L10n.Creation.newPage) {
                NotificationCenter.default.post(name: .createNewPage, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // 查看：切换侧边栏 (⌃⌘S)
        // macOS 主窗口侧边栏由系统默认控制，当前 NavigationSplitView 布局暂无 toggleSidebar 消费者；
        // 保留此通用菜单语义，系统在有可用响应时（如未来 NavigationView 路径）自动生效。
        CommandGroup(after: .toolbar) {
            Button(L10n.Common.Sidebar.toggle) {
                NotificationCenter.default.post(name: .toggleSidebar, object: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .control])
        }

        // 窗口：打开笔记本中心（匹配 MacSceneBuilder.windows() 的 notebook-hub 场景）
        CommandGroup(after: .windowArrangement) {
            Button(L10n.Notebook.openHub) {
                openWindow(id: "notebook-hub")
            }
        }

        // 帮助：官网链接
        CommandGroup(replacing: .help) {
            Link(L10n.Common.help, destination: URL(string: "https://izhiyu.top")!)
        }
    }
}
