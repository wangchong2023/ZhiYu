//
//  MacMainWindow.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/19.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 应用层
//  核心职责：macOS 主窗口原生外壳，仅包装复用 ContentView，不重写布局/浮层/锁定/注入。
//
import SwiftUI

/// macOS 主窗口：仅作原生外壳包装，不重写内容
struct MacMainWindow: View {
    var body: some View {
        ContentView()   // 复用：登录分派 + 三栏 + 浮层 + 锁定 + toast + 依赖注入
    }
}
