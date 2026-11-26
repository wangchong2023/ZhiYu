//
//  SiriWaveformView.swift
//  UFPDesignSystem
//
//  Created by Antigravity on 2026/06/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPDesignSystem] 共享设计系统包
//  核心职责：提供高品质“智感流光”Siri 波形动效，使用 TimelineView 与 Canvas 硬件加速绘制。
//

import SwiftUI

/// Siri-like 智感流光正弦波形视图
public struct SiriWaveformView: View {
    /// 整体动画速度乘数
    public var speedMultiplier: Double

    /// 整体振幅乘数 (0.0 ~ 1.0)
    public var amplitudeMultiplier: Double

    public init(speedMultiplier: Double = 1.0, amplitudeMultiplier: Double = 1.0) {
        self.speedMultiplier = speedMultiplier
        self.amplitudeMultiplier = amplitudeMultiplier
    }

    // MARK: - 波形参数配置

    private enum WaveConfig {
        static let count: Int = 3
        static let sampleStep: CGFloat = 2.0
        static let fullCircleRadians: CGFloat = .pi * 2.0
        static let primaryLineWidth: CGFloat = 3.0
        static let secondaryLineWidth: CGFloat = 2.0
        static let blurRadius: CGFloat = 1.5
        // 三个波浪分别赋予不同的初相（Phase offset）、频率（Frequency）和基准高度比例
        static let frequencies: [CGFloat] = [1.2, 2.0, 0.8]
        static let amplitudes: [CGFloat] = [25.0, 15.0, 8.0]
        static let phaseOffsets: [CGFloat] = [0.0, .pi / 3, .pi / 1.5]
        static let speeds: [CGFloat] = [2.0, 3.5, 1.5]
        static let colors: [[Color]] = [
            [.cyan, .blue],
            [.purple, .pink],
            [.indigo, .cyan]
        ]
    }

    /// 构造单路正弦波路径；对非正尺寸或非有限浮点参数返回空路径，防止 0/0 注入 NaN 坐标污染 CoreGraphics
    internal static func buildWavePath(
        waveIndex: Int,
        width: CGFloat,
        height: CGFloat,
        time: Double,
        amplitudeMultiplier: Double
    ) -> Path {
        guard waveIndex >= 0,
              waveIndex < WaveConfig.count,
              width.isFinite, width > 0,
              height.isFinite, height > 0,
              time.isFinite,
              amplitudeMultiplier.isFinite else {
            return Path()
        }

        let centerY = height / 2
        let freq = WaveConfig.frequencies[waveIndex]
        let amp = WaveConfig.amplitudes[waveIndex] * CGFloat(amplitudeMultiplier)
        let phaseOffset = WaveConfig.phaseOffsets[waveIndex]
        let speed = WaveConfig.speeds[waveIndex]

        var path = Path()
        path.move(to: CGPoint(x: 0, y: centerY))

        for x in stride(from: CGFloat(0), through: width, by: WaveConfig.sampleStep) {
            let normalizedX = x / width * WaveConfig.fullCircleRadians
            let t = CGFloat(time) * speed
            let y = amp * sin(normalizedX * freq + t + phaseOffset) + centerY
            path.addLine(to: CGPoint(x: x, y: y))
        }
        return path
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            let safeSpeed = speedMultiplier.isFinite ? speedMultiplier : 0
            let time = timeline.date.timeIntervalSinceReferenceDate * safeSpeed

            Canvas { context, size in
                let width = size.width
                let height = size.height
                guard width.isFinite, width > 0, height.isFinite, height > 0 else { return }
                let centerY = height / 2

                // 绘制三路交错正弦波
                for i in 0..<WaveConfig.count {
                    let path = Self.buildWavePath(
                        waveIndex: i,
                        width: width,
                        height: height,
                        time: time,
                        amplitudeMultiplier: amplitudeMultiplier
                    )
                    guard !path.isEmpty else { continue }

                    let gradient = Gradient(colors: WaveConfig.colors[i])
                    let shading = GraphicsContext.Shading.linearGradient(
                        gradient,
                        startPoint: CGPoint(x: 0, y: centerY),
                        endPoint: CGPoint(x: width, y: centerY)
                    )

                    context.stroke(
                        path,
                        with: shading,
                        style: StrokeStyle(
                            lineWidth: i == 0 ? WaveConfig.primaryLineWidth : WaveConfig.secondaryLineWidth,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                }
            }
            .blur(radius: WaveConfig.blurRadius)
            .blendMode(.screen)
        }
    }
}
