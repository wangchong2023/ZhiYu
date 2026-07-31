//
//  PageBackground.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

// MARK: @PR-03: 工业级页面背景系统，优化了渐变渲染性能
// MARK: @PR-04: AI 思考指示器背景

/// 动态网格背景渲染器
public struct MeshGradientView: View {
    public init() {}
    
    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                Color.appBackground
                
                if size.width > 1 && size.height > 1 {
                    if #available(iOS 18.0, macOS 15.0, *) {
                        #if os(watchOS)
                        watchOSCanvasBackground(size: size)
                        #else
                        MeshGradient(
                            width: 3,
                            height: 3,
                            points: [
                                [0, 0], [0.5, 0], [1, 0],
                                [0, 0.5], [0.5, 0.5], [1, 0.5],
                                [0, 1], [0.5, 1], [1, 1]
                            ],
                            colors: [
                                .appBackground, .appBackground, .appBackground,
                                // swiftlint:disable:next magic_numbers_opacity
                                .appAccent.opacity(DesignSystem.Opacity.medium), .appConcept.opacity(DesignSystem.Opacity.glass), .appSource.opacity(0.18),
                                .appBackground, .appBackground, .appBackground
                            ],
                            smoothsColors: true
                        )
                        #endif
                    } else {
                        legacyCanvasBackground(size: size)
                    }
                }
            }
            .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    private func watchOSCanvasBackground(size: CGSize) -> some View {
        Canvas { context, size in
            let gridPadding: CGFloat = 40
            let rows = Int(size.height / gridPadding)
            let cols = Int(size.width / gridPadding)
            
            for row in 0...rows {
                let y = CGFloat(row) * gridPadding
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }, with: .color(Color.appAccent.opacity(DesignSystem.Opacity.ghost)), lineWidth: 0.5)
            }
            
            for col in 0...cols {
                let x = CGFloat(col) * gridPadding
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }, with: .color(Color.appAccent.opacity(DesignSystem.Opacity.ghost)), lineWidth: 0.5)
            }
        }
    }
    
    @ViewBuilder
    private func legacyCanvasBackground(size: CGSize) -> some View {
        Canvas { context, size in
            let gridPadding: CGFloat = 40
            let rows = Int(size.height / gridPadding)
            let cols = Int(size.width / gridPadding)
            
            for row in 0...rows {
                let y = CGFloat(row) * gridPadding
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: 0, y: y))
                    p.addLine(to: CGPoint(x: size.width, y: y))
                }, with: .color(Color.appAccent.opacity(DesignSystem.Opacity.ghost)), lineWidth: 0.5)
            }
            
            for col in 0...cols {
                let x = CGFloat(col) * gridPadding
                context.stroke(Path { p in
                    p.move(to: CGPoint(x: x, y: 0))
                    p.addLine(to: CGPoint(x: x, y: size.height))
                }, with: .color(Color.appAccent.opacity(DesignSystem.Opacity.ghost)), lineWidth: 0.5)
            }
        }
    }
}

/// 氛围光渐变背景
public struct AmbientGlowView: View {
    public let color: Color
    
    public init(color: Color) {
        self.color = color
    }
    
    public var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            if size.width > 1 && size.height > 1 {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [color.opacity(DesignSystem.Opacity.medium), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 300
                        )
                    )
                    .frame(width: DesignSystem.Metrics.backgroundLargeDecorativeSize, height: DesignSystem.Metrics.backgroundLargeDecorativeSize)
                    .blur(radius: 80)
                    .position(x: size.width / 2, y: size.height / 2)
            }
        }
    }
}

/// 统一的工业级页面背景
public struct PageBackgroundView: View {
    public let accentColor: Color
    
    public init(accentColor: Color) {
        self.accentColor = accentColor
    }
    
    public var body: some View {
        ZStack {
            MeshGradientView()
            VStack {
                AmbientGlowView(color: accentColor)
                    .frame(height: DesignSystem.Metrics.backgroundDecorativeSize)
                    .offset(y: -150)
                Spacer()
            }
        }
        .ignoresSafeArea()
        .background(Color.appBackground)
    }
}
