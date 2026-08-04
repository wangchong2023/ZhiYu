//
//  TagCloudSupport.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：标签云模块的辅助视图与 View 扩展 —— 非 macOS 平台的模糊背景占位视图与
//  自适应 Label 样式转换器。
//

import SwiftUI

// 简单的模糊背景视图 (非 macOS 平台使用透明占位)
#if canImport(UIKit)
struct BlurView: View {
    var body: some View {
        Color.clear
    }
}
#endif

// MARK: - View 扩展

extension View {
    /// 智适应 Label 样式转换器，支持在不同屏幕状态下在图文和纯图标间弹性切换，避开三元运算符类型匹配限制
    @ViewBuilder
    func adaptiveLabelStyle(isExpanded: Bool) -> some View {
        if isExpanded {
            self.labelStyle(.titleAndIcon)
        } else {
            self.labelStyle(.iconOnly)
        }
    }
}
