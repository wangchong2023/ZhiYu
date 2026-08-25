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

// MARK: - OCR 缩放查看器私有常量
private enum OCRZoomConstants {
    static let minScale: CGFloat = 0.8
    static let maxScale: CGFloat = 4.0
    static let resetScale: CGFloat = 1.0
    static let step: CGFloat = 0.25
    static let doubleTapThreshold: CGFloat = 1.2
    static let doubleTapTarget: CGFloat = 2.0
    static let animationDuration: Double = 0.2
    static let tapSpringResponse: CGFloat = 0.3
    static let tapSpringDamping: CGFloat = 0.7
}

struct ZoomableOCRImageView: View {
    let image: UIImage
    
    @State private var currentScale: CGFloat = OCRZoomConstants.resetScale
    @State private var gestureScale: CGFloat = OCRZoomConstants.resetScale
    @State private var offset: CGSize = .zero
    @State private var gestureOffset: CGSize = .zero

    private var totalScale: CGFloat {
        max(OCRZoomConstants.minScale, min(OCRZoomConstants.maxScale, currentScale * gestureScale))
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
                                        currentScale = max(OCRZoomConstants.resetScale, min(OCRZoomConstants.maxScale, currentScale * value.magnification))
                                        gestureScale = OCRZoomConstants.resetScale
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        if totalScale > OCRZoomConstants.resetScale {
                                            gestureOffset = value.translation
                                        }
                                    }
                                    .onEnded { value in
                                        if totalScale > OCRZoomConstants.resetScale {
                                            offset.width += value.translation.width
                                            offset.height += value.translation.height
                                            gestureOffset = .zero
                                        }
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: OCRZoomConstants.tapSpringResponse, dampingFraction: OCRZoomConstants.tapSpringDamping)) {
                                if currentScale > OCRZoomConstants.doubleTapThreshold {
                                    resetZoom()
                                } else {
                                    currentScale = OCRZoomConstants.doubleTapTarget
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
                    Text(String(format: L10n.Ingest.OCR.zoomFormat, totalScale))
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
        withAnimation(.easeInOut(duration: OCRZoomConstants.animationDuration)) {
            currentScale = min(OCRZoomConstants.maxScale, currentScale + OCRZoomConstants.step)
        }
    }

    private func zoomOut() {
        withAnimation(.easeInOut(duration: OCRZoomConstants.animationDuration)) {
            currentScale = max(OCRZoomConstants.resetScale, currentScale - OCRZoomConstants.step)
            if currentScale <= OCRZoomConstants.resetScale {
                offset = .zero
            }
        }
    }

    private func resetZoom() {
        withAnimation(.easeInOut(duration: OCRZoomConstants.animationDuration)) {
            currentScale = OCRZoomConstants.resetScale
            gestureScale = OCRZoomConstants.resetScale
            offset = .zero
            gestureOffset = .zero
        }
    }
}
#endif
