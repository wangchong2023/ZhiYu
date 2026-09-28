//
//  SiriWaveformView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：提供高品质“智感流光”Siri波形动效，使用 TimelineView 与 Canvas 硬件加速绘制。
//

import SwiftUI
import UFPDesignSystem

/// Siri-like 智感流光正弦波形视图
struct SiriWaveformView: View {
    /// 整体动画速度乘数
    var speedMultiplier: Double = 1.0
    
    /// 整体振幅乘数 (0.0 ~ 1.0)
    var amplitudeMultiplier: Double = 1.0

    // MARK: - 波形参数配置
    private struct WaveConfig {
        let count: Int = 3
        // 三个波浪分别赋予不同的初相（Phase offset）、频率（Frequency）和基准高度比例
        let frequencies: [CGFloat] = [1.2, 2.0, 0.8]
        let amplitudes: [CGFloat] = [25.0, 15.0, 8.0]
        let phaseOffsets: [CGFloat] = [0.0, .pi / 3, .pi / 1.5]
        let speeds: [CGFloat] = [2.0, 3.5, 1.5]
        let colors: [[Color]] = [
            [.cyan, .blue],
            [.purple, .pink],
            [.indigo, .cyan]
        ]
    }
    
    private let config = WaveConfig()

    var body: some View {
        TimelineView(.animation) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate * speedMultiplier
            
            Canvas { context, size in
                let width = size.width
                let height = size.height
                let centerY = height / 2
                
                // 绘制三路交错正弦波
                for i in 0..<config.count {
                    let freq = config.frequencies[i]
                    let amp = config.amplitudes[i] * CGFloat(amplitudeMultiplier)
                    let phaseOffset = config.phaseOffsets[i]
                    let speed = config.speeds[i]
                    let colors = config.colors[i]
                    
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: centerY))
                    
                    // 用密集线条点连成平滑正弦曲线
                    for x in stride(from: CGFloat(0), through: width, by: 2) {
                        // y = A * sin(w * x + phase) + centerY
                        let normalizedX = x / width * .pi * 2
                        let t = CGFloat(time) * speed
                        let y = amp * sin(normalizedX * freq + t + phaseOffset) + centerY
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                    
                    // 绘制渐变曲线
                    let gradient = Gradient(colors: colors)
                    let shading = GraphicsContext.Shading.linearGradient(
                        gradient,
                        startPoint: CGPoint(x: 0, y: centerY),
                        endPoint: CGPoint(x: width, y: centerY)
                    )
                    
                    // 应用发光线条描边
                    context.stroke(
                        path,
                        with: shading,
                        style: StrokeStyle(lineWidth: i == 0 ? 3.0 : 2.0, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .blur(radius: 1.5) // 微量高斯模糊增强炫彩融合感
            .blendMode(.screen) // 屏幕混合模式让交汇点更加明亮炫丽
        }
    }
}

#Preview {
    ZStack {
        Color.theme.black.ignoresSafeArea()
        SiriWaveformView(speedMultiplier: 1.0, amplitudeMultiplier: 1.0)
            .frame(height: DesignTokens.Metrics.heroValueSize)
            .padding()
    }
}
