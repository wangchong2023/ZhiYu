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
