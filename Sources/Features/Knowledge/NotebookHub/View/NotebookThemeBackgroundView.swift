//
//  NotebookThemeBackgroundView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 NotebookThemeBackground 界面的 UI 视图层组件。
//
import SwiftUI

/// 笔记本主题背景视图
/// 负责根据主题配置渲染笔记本卡片的背景，支持线性渐变和网格渐变（iOS 18+）
struct NotebookThemeBackgroundView: View {
    /// 主题配置
    let config: NotebookThemeConfig
    
    var body: some View {
        ZStack {
            let colors = config.colors.map { Color(hex: $0) }
            
            switch config.type {
            case .linear:
                // 渲染线性渐变背景
                LinearGradient(
                    colors: colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            case .mesh:
                // 如果是 iOS 18.0 或 macOS 15.0 以上版本，实装真正的 MeshGradient
                if #available(iOS 18.0, macOS 15.0, *) {
                    // 使用 3x3 网格实现流体效果
                    // 9个顶点颜色通过对 config.colors 的循环采样获得
                    let meshColors: [Color] = (0..<9).map { i in
                        colors[i % colors.count]
                    }
                    
                    // 基于 seed 计算中点的扰动偏移，增加“AI 随机感”
                    let s = Double(config.seed % 100) / 100.0
                    let offsetX = Float(s * 0.2 - 0.1) // -0.1 ~ 0.1
                    let offsetY = Float(((Double(config.seed) / 10.0).truncatingRemainder(dividingBy: 10.0) / 10.0) * 0.2 - 0.1)
                    
                    MeshGradient(
                        width: 3,
                        height: 3,
                        points: [
                            [0, 0], [0.5, 0], [1, 0],
                            [0, 0.5], [0.5 + offsetX, 0.5 + offsetY], [1, 0.5],
                            [0, 1], [0.5, 1], [1, 1]
                        ],
                        colors: meshColors
                    )
                    .ignoresSafeArea()
                } else {
                    // 低版本回退到多色径向渐变，模拟流体感
                    ZStack {
                        colors[0]
                        ForEach(1..<colors.count, id: \.self) { i in
                            Circle()
                                .fill(colors[i])
                                .frame(width: DesignSystem.Metrics.backgroundDecorativeSize, height: DesignSystem.Metrics.backgroundDecorativeSize)
                                .blur(radius: 80)
                                .offset(
                                    x: CGFloat(sin(Double(config.seed + i)) * 100),
                                    y: CGFloat(cos(Double(config.seed + i)) * 100)
                                )
                        }
                    }
                    .clipped()
                }
            }
        }
    }
}
