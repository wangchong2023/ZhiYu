//
//  ZoomableOCRImageView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：为 OCR 扫描原图提供带有手势捏合 (Pinch-to-Zoom)、平移拖拽、双击放大与浮动控件控制的无缝缩放查看器。
//

#if canImport(UIKit)
import SwiftUI
import UIKit

struct ZoomableOCRImageView: View {
    let image: UIImage
    
    @State private var currentScale: CGFloat = 1.0
    @State private var gestureScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var gestureOffset: CGSize = .zero
    
    private var totalScale: CGFloat {
        max(0.8, min(4.0, currentScale * gestureScale))
    }
    
    var body: some View {
        VStack(spacing: DesignSystem.small) {
            ZStack(alignment: .bottomTrailing) {
                // 1. 动态可缩放平移的图像展示框
                GeometryReader { _ in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(totalScale)
                        .offset(x: offset.width + gestureOffset.width, y: offset.height + gestureOffset.height)
                        .gesture(
                            SimultaneousGesture(
                                MagnifyGesture()
                                    .onChanged { value in
                                        gestureScale = value.magnification
                                    }
                                    .onEnded { value in
                                        currentScale = max(1.0, min(4.0, currentScale * value.magnification))
                                        gestureScale = 1.0
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        if totalScale > 1.0 {
                                            gestureOffset = value.translation
                                        }
                                    }
                                    .onEnded { value in
                                        if totalScale > 1.0 {
                                            offset.width += value.translation.width
                                            offset.height += value.translation.height
                                            gestureOffset = .zero
                                        }
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                if currentScale > 1.2 {
                                    resetZoom()
                                } else {
                                    currentScale = 2.0
                                    offset = .zero
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
                
                // 2. 浮动缩放控制面板
                HStack(spacing: DesignSystem.small) {
                    Text(String(format: "%.1fx", totalScale))
                        .font(.caption2.monospacedDigit().weight(.bold))
                        .foregroundStyle(.appAccent)
                        .padding(.horizontal, DesignSystem.small)
                    
                    Button(action: zoomOut) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    
                    Button(action: zoomIn) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    
                    Button(action: resetZoom) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, DesignSystem.medium)
                .padding(.vertical, DesignSystem.tightPadding)
                .background(
                    Capsule()
                        .fill(Color.appCard)
                        .shadow(color: Color.appAccent.opacity(DesignSystem.Opacity.shadow), radius: DesignSystem.smallRadius)
                )
                .padding(DesignSystem.medium)
            }
        }
    }
    
    private func zoomIn() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentScale = min(4.0, currentScale + 0.25)
        }
    }
    
    private func zoomOut() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentScale = max(1.0, currentScale - 0.25)
            if currentScale <= 1.0 {
                offset = .zero
            }
        }
    }
    
    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            currentScale = 1.0
            gestureScale = 1.0
            offset = .zero
            gestureOffset = .zero
        }
    }
}
#endif
