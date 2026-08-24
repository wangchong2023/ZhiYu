//
//  SplashComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

// MARK: - Splash Background View
/// 程序化启动画面背景：深空 + 神经网络节点 + 书本光芒
struct SplashBackgroundView: View {
    let starTwinkle: Bool
    let nodeGlow: Bool

    private struct Star { let x: CGFloat; let y: CGFloat; let size: CGFloat; let delay: Double }
    private struct NetworkNode { let x: CGFloat; let y: CGFloat; let size: CGFloat; let isAccent: Bool }

    // 预生成的随机数据
    private let stars: [Star] = [
        Star(x: 0.12, y: 0.08, size: 1.5, delay: 0.0), Star(x: 0.85, y: 0.05, size: 1.0, delay: 0.3), Star(x: 0.45, y: 0.12, size: 2.0, delay: 0.6),
        Star(x: 0.72, y: 0.18, size: 1.2, delay: 0.2), Star(x: 0.28, y: 0.22, size: 1.8, delay: 0.8), Star(x: 0.93, y: 0.25, size: 1.0, delay: 0.1),
        Star(x: 0.08, y: 0.30, size: 1.5, delay: 0.5), Star(x: 0.55, y: 0.08, size: 1.3, delay: 0.7), Star(x: 0.38, y: 0.28, size: 1.0, delay: 0.4),
        Star(x: 0.65, y: 0.32, size: 2.0, delay: 0.9), Star(x: 0.18, y: 0.42, size: 1.2, delay: 0.15), Star(x: 0.78, y: 0.38, size: 1.5, delay: 0.55),
        Star(x: 0.50, y: 0.45, size: 1.0, delay: 0.35), Star(x: 0.90, y: 0.48, size: 1.8, delay: 0.75), Star(x: 0.32, y: 0.52, size: 1.3, delay: 0.25),
        Star(x: 0.05, y: 0.55, size: 1.0, delay: 0.65), Star(x: 0.62, y: 0.58, size: 2.0, delay: 0.45), Star(x: 0.42, y: 0.35, size: 1.5, delay: 0.85),
        Star(x: 0.75, y: 0.55, size: 1.2, delay: 0.05), Star(x: 0.22, y: 0.62, size: 1.0, delay: 0.95), Star(x: 0.88, y: 0.62, size: 1.8, delay: 0.38),
        Star(x: 0.15, y: 0.68, size: 1.5, delay: 0.58), Star(x: 0.58, y: 0.42, size: 1.0, delay: 0.18), Star(x: 0.35, y: 0.72, size: 2.0, delay: 0.78),
        Star(x: 0.82, y: 0.72, size: 1.3, delay: 0.28), Star(x: 0.48, y: 0.68, size: 1.0, delay: 0.48), Star(x: 0.68, y: 0.48, size: 1.5, delay: 0.68),
        Star(x: 0.10, y: 0.78, size: 1.2, delay: 0.88), Star(x: 0.92, y: 0.82, size: 1.0, delay: 0.08), Star(x: 0.40, y: 0.82, size: 1.8, delay: 0.42)
    ]

    // 神经网络节点位置
    private let networkNodes: [NetworkNode] = [
        NetworkNode(x: 0.20, y: 0.15, size: 5, isAccent: false), NetworkNode(x: 0.40, y: 0.10, size: 6, isAccent: true), NetworkNode(x: 0.60, y: 0.18, size: 5, isAccent: false),
        NetworkNode(x: 0.80, y: 0.12, size: 4, isAccent: false), NetworkNode(x: 0.15, y: 0.30, size: 4, isAccent: false), NetworkNode(x: 0.35, y: 0.28, size: 7, isAccent: true),
        NetworkNode(x: 0.55, y: 0.25, size: 5, isAccent: false), NetworkNode(x: 0.75, y: 0.30, size: 6, isAccent: true), NetworkNode(x: 0.90, y: 0.22, size: 4, isAccent: false),
        NetworkNode(x: 0.25, y: 0.45, size: 5, isAccent: false), NetworkNode(x: 0.50, y: 0.40, size: 8, isAccent: true), NetworkNode(x: 0.70, y: 0.42, size: 5, isAccent: false),
        NetworkNode(x: 0.10, y: 0.50, size: 4, isAccent: false), NetworkNode(x: 0.85, y: 0.48, size: 5, isAccent: false), NetworkNode(x: 0.30, y: 0.55, size: 6, isAccent: true),
        NetworkNode(x: 0.60, y: 0.52, size: 4, isAccent: false), NetworkNode(x: 0.80, y: 0.55, size: 5, isAccent: false), NetworkNode(x: 0.45, y: 0.60, size: 7, isAccent: true)
    ]

    // 网络连接线
    private let connections: [(from: Int, to: Int)] = [
        (0, 1), (1, 2), (2, 3), (0, 4), (1, 5), (2, 6), (3, 7), (8, 7),
        (4, 5), (5, 6), (6, 7), (5, 10), (6, 10), (9, 10), (10, 11),
        (4, 9), (9, 14), (10, 15), (11, 16), (14, 17), (15, 17),
        (12, 9), (13, 16), (8, 5), (1, 6), (5, 10), (10, 17)
    ]

    var body: some View {
        ZStack {
            // MARK: DesignSystem — splash gradient (深靛蓝→海军蓝→暖琥珀光，设计意图明确)
            LinearGradient(
                stops: [
                    .init(color: Colors.Splash.bgStep1, location: 0.0),
                    .init(color: Colors.Splash.bgStep2, location: 0.3),
                    .init(color: Colors.Splash.bgStep3, location: 0.55),
                    .init(color: Colors.Splash.bgStep4, location: 0.7),
                    .init(color: Colors.Splash.bgStep5, location: 0.85),
                    .init(color: Colors.Splash.bgStep6, location: 0.95),
                    .init(color: Colors.Splash.bgStep7, location: 1.0)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // 星星层
            GeometryReader { geo in
                if geo.size.width > 1 && geo.size.height > 1 {
                    ForEach(Array(stars.enumerated()), id: \.offset) { _, star in
                        Circle()
                            .fill(.appGloss)
                            .frame(width: star.size, height: star.size)
                            .position(x: geo.size.width * star.x, y: geo.size.height * star.y)
                            .opacity(starTwinkle ? SystemOpacity.glassStrong : SystemOpacity.disabled)
                            .animation(
                                .easeInOut(duration: DesignSystem.Animation.looseDuration + star.delay)
                                .repeatForever(autoreverses: true)
                                .delay(star.delay),
                                value: starTwinkle
                            )
                    }
                }
            }

            // 神经网络连接线
            GeometryReader { geo in
                if geo.size.width > 1 && geo.size.height > 1 {
                    let indexed: [(offset: Int, element: (from: Int, to: Int))] = Array(connections.enumerated())
                    ForEach(indexed, id: \.offset) { _, conn in
                        let fromNode = networkNodes[conn.from]
                        let toNode = networkNodes[conn.to]
                        let lineColor1 = fromNode.isAccent ? Color.appAccent.opacity(SystemOpacity.disabled) : Color.appGloss.opacity(SystemOpacity.glassStrong)
                        let lineColor2 = toNode.isAccent ? Color.appAccent.opacity(SystemOpacity.disabled) : Color.appGloss.opacity(SystemOpacity.glassStrong)
                        
                        Path { path in
                            path.move(to: CGPoint(
                                x: geo.size.width * fromNode.x,
                                y: geo.size.height * fromNode.y
                            ))
                            path.addLine(to: CGPoint(
                                x: geo.size.width * toNode.x,
                                y: geo.size.height * toNode.y
                            ))
                        }
                        .stroke(
                            LinearGradient(
                                colors: [lineColor1, lineColor2],
                                startPoint: .init(x: fromNode.x, y: fromNode.y),
                                endPoint: .init(x: toNode.x, y: toNode.y)
                            ),
                            lineWidth: SystemStroke.border
                        )
                    }
                }
            }

            // 神经网络节点
            GeometryReader { geo in
                if geo.size.width > 1 && geo.size.height > 1 {
                    ForEach(Array(networkNodes.enumerated()), id: \.offset) { index, node in
                        let nodeColor1 = node.isAccent ? Color.appAccent.opacity(SystemOpacity.active) : Color.appGloss.opacity(SystemOpacity.textSecondary)
                        let nodeColor2 = node.isAccent ? Color.appAccent.opacity(SystemOpacity.disabled) : Color.appGloss.opacity(SystemOpacity.glassStrong)
                        
                        let nodeScale = nodeGlow ? SystemOpacity.active : SystemOpacity.overlay
                        let nodeOpacity = nodeGlow ? SystemOpacity.active : SystemOpacity.disabled
                        let animDuration = DesignSystem.Animation.slowDuration + Double(index) * 0.1
                        let nodeAnim = SwiftUI.Animation.easeInOut(duration: animDuration)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.08)
                        
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [nodeColor1, nodeColor2, .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: node.size * 2
                                )
                            )
                            .frame(width: node.size * 4, height: node.size * 4)
                            .position(x: geo.size.width * node.x, y: geo.size.height * node.y)
                            .scaleEffect(nodeScale)
                            .opacity(nodeOpacity)
                            .animation(nodeAnim, value: nodeGlow)
                    }
                }
            }

            // 书本光芒 — 底部中央的暖光 (暖琥珀渐变，设计意图明确)
            VStack {
                Spacer()
                RadialGradient(
                    colors: [
                        Colors.Splash.glow1.opacity(SystemOpacity.glassStrong), // 0.25
                        Colors.Splash.glow2.opacity(SystemOpacity.glassStrong), // 0.12
                        Colors.Splash.glow3.opacity(SystemOpacity.ghost), // 0.05
                        .clear
                    ],
                    center: .center,
                    startRadius: DesignSystem.loosePadding, // 20
                    endRadius: DesignSystem.Metrics.heroValueSize * 9.6 // 250
                )
                .frame(height: DesignSystem.Metrics.heroValueSize * 11.5) // 300
                .offset(y: DesignSystem.Metrics.heroValueSize * 3) // 80
            }

            // 书本轮廓 — 极简线条
            VStack {
                Spacer()
                ZStack {
                    // 书本主体
                    RoundedRectangle(cornerRadius: DesignSystem.tiny)
                        .stroke(Color.appAccent.opacity(SystemOpacity.disabled), lineWidth: SystemStroke.border) // 0.3, 0.8
                        .frame(width: DesignSystem.Metrics.iconBoxSize + DesignSystem.medium, height: DesignSystem.iconDisplay) // 60, 44
                        .rotationEffect(.degrees(-8))
                        .offset(x: -DesignSystem.atomic) // -2

                    RoundedRectangle(cornerRadius: DesignSystem.tiny)
                        .stroke(Color.appAccent.opacity(SystemOpacity.disabled), lineWidth: SystemStroke.border) // 0.3, 0.8
                        .frame(width: DesignSystem.Metrics.iconBoxSize + DesignSystem.medium, height: DesignSystem.iconDisplay) // 60, 44
                        .rotationEffect(.degrees(8))
                        .offset(x: DesignSystem.atomic) // 2

                    // 书脊
                    Capsule()
                        .fill(Color.appAccent.opacity(SystemOpacity.glassStrong)) // 0.2
                        .frame(width: DesignSystem.atomic + 1, height: DesignSystem.iconDisplay) // 3, 44

                    // 从书中升起的光粒子
                    ForEach(0..<5, id: \.self) { i in
                        Circle()
                            .fill(Color.appAccent.opacity(SystemOpacity.overlay)) // 0.6
                            .frame(width: DesignSystem.atomic + 1, height: DesignSystem.atomic + 1) // 3, 3
                            .offset(
                                x: CGFloat(i - 2) * (DesignSystem.small + DesignSystem.tiny), // 14
                                y: nodeGlow ? -DesignSystem.Metrics.iconBoxSize * 1.35 - CGFloat(i) * 15 : -DesignSystem.loosePadding // -60, -20
                            )
                            .opacity(nodeGlow ? SystemOpacity.overlay : SystemOpacity.glass) // 0.6, 0.1
                            .animation(
                                .easeOut(duration: 3.0)
                                .repeatForever(autoreverses: false)
                                .delay(Double(i) * 0.4),
                                value: nodeGlow
                            )
                    }
                }
                .padding(.bottom, Spacing.Vault.cardHeight) // 180
            }
        }
    }
}
