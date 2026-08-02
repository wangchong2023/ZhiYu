//
//  OCRImageContentView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/04.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：跨平台 OCR 图片展示 —— watchOS 上显示不支持提示，其他平台渲染真实图片。
//

import SwiftUI

/// OCR 选中图片展示组件
///
/// watchOS 端由于系统限制无法展示相册图片，降级为提示文本；
/// iOS / macOS 端渲染带圆角、阴影、描边的等比例缩放图片。
public struct OCRImageContentView: View {
    let image: AppImage?

    public init(image: AppImage?) {
        self.image = image
    }

    public var body: some View {
        #if os(watchOS)
        Text(L10n.Common.Status.simulatorNotSupported)
        #elseif canImport(UIKit)
        imageContent(uiImage: image)
        #else
        imageContent(nsImage: image)
        #endif
    }

    #if canImport(UIKit) && !os(watchOS)
    private func imageContent(uiImage: AppImage?) -> some View {
        Group {
            if let img = uiImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: Spacing.Grid.emptyStateHeight)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
                    .shadow(color: .primary.opacity(DesignSystem.shadowOpacity), radius: DesignSystem.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                            .stroke(Color.appBorder, lineWidth: DesignSystem.borderWidth)
                    )
            }
        }
    }
    #endif

    #if os(macOS)
    private func imageContent(nsImage: AppImage?) -> some View {
        Group {
            if let img = nsImage {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: Spacing.Grid.emptyStateHeight)
                    .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
                    .shadow(color: .primary.opacity(DesignSystem.shadowOpacity), radius: DesignSystem.small)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                            .stroke(Color.appBorder, lineWidth: DesignSystem.borderWidth)
                    )
            }
        }
    }
    #endif
}
