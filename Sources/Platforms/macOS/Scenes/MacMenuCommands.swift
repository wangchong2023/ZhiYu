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
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button(L10n.Creation.newPage) {
                NotificationCenter.default.post(name: .createNewPage, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }
}
