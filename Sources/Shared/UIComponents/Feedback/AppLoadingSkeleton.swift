//
//  AppLoadingSkeleton.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

/// 骨架屏占位加载组件
/// 包含流光闪烁微动画，能够模拟不同尺寸与结构的排版占位。
public struct AppLoadingSkeleton: View {
    /// 骨架屏类型
    public enum SkeletonType: Sendable {
        /// 单行占位条
        case textRow
        /// 详情段落占位
        case paragraph
        /// 卡片大图块占位
        case cardBlock
    }
    
    /// 当前骨架屏样式
    public let type: SkeletonType
    
    /// 动画透明度控制状态
    @State private var animateOpacity = DesignSystem.Opacity.shadow
    
    /// 初始化骨架屏加载组件
    /// - Parameter type: 骨架样式，默认为 .textRow
    public init(type: SkeletonType = .textRow) {
        self.type = type
    }
    
    public var body: some View {
        Group {
            switch type {
            case .textRow:
                skeletonRectangle()
                    .frame(height: DesignSystem.IconSize.micro)
                
            case .paragraph:
                VStack(alignment: .leading, spacing: SystemSpacing.tight) {
                    skeletonRectangle().frame(height: DesignSystem.IconSize.micro).frame(maxWidth: .infinity)
                    skeletonRectangle().frame(height: DesignSystem.IconSize.micro).frame(maxWidth: .infinity)
                    skeletonRectangle().frame(height: DesignSystem.IconSize.micro).frame(width: DesignSystem.Metrics.sourceCardWidth)
                }
                
            case .cardBlock:
                VStack(alignment: .leading, spacing: SystemSpacing.medium) {
                    skeletonRectangle()
                        .frame(height: DesignSystem.Metrics.heroValueSize)
                    HStack(spacing: SystemSpacing.element) {
                        skeletonRectangle().frame(width: DesignSystem.Metrics.avatarSkeletonSize, height: DesignSystem.Metrics.avatarSkeletonSize)
                        VStack(alignment: .leading, spacing: DesignSystem.tightPadding) {
                            skeletonRectangle().frame(height: DesignSystem.Metrics.textSkeletonHeight).frame(width: ComponentSpacing.colossal)
                            skeletonRectangle().frame(height: DesignSystem.mediumRadius).frame(width: DesignSystem.Metrics.emptyStateGraphicHeight)
                        }
                    }
                }
            }
        }
        .onAppear {
            // 1. 物理挂载后立即执行无限往复的流光透明度插值动画
            withAnimation(
                .easeInOut(duration: Animations.Decorator.pulseDuration)
                .repeatForever(autoreverses: true)
            ) {
                animateOpacity = DesignSystem.Opacity.prominent
            }
        }
        // Bug #103 修复：onDisappear 时停止动画，避免 repeatForever 动画
        // 仍持有渲染资源，导致内存泄漏与 CPU 占用（同 Bug #65）。
        .onDisappear {
            withAnimation(.easeOut(duration: DesignSystem.Animation.fastDuration)) {
                animateOpacity = DesignSystem.Opacity.shadow
            }
        }
    }
    
    /// 构建骨架屏基础灰色微动画圆角矩形
    private func skeletonRectangle() -> some View {
        RoundedRectangle(cornerRadius: DesignSystem.chipRadius)
            .fill(Color.secondary.opacity(Colors.subtleOpacity))
            .opacity(animateOpacity)
    }
}
