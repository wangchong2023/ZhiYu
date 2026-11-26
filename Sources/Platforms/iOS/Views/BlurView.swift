//
//  BlurView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 平台适配层
//  核心职责：iOS/非 macOS 平台模糊背景占位视图（与 Sources/Platforms/macOS/Views/BlurView.swift 对齐）。
//

#if os(iOS)
import SwiftUI

/// iOS 平台模糊背景占位视图
struct BlurView: View {
    var body: some View {
        Color.clear
    }
}
#endif
