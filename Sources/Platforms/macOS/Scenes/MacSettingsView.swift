//
//  MacSettingsView.swift
//  ZhiYu
//
//  系统层级：[L3] 应用层
//  核心职责：macOS 原生设置，复用 SettingsView 的 .mac 分支。
//
import SwiftUI

/// macOS 原生设置：复用 SettingsView（含 sidebarColumn + detailColumn 布局）
struct MacSettingsView: View {
    var body: some View {
        SettingsView()
    }
}
