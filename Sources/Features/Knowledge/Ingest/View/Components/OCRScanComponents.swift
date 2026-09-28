//
//  OCRScanComponents.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：知识摄入：文档导入、URL 抓取、OCR 扫描、PDF 解析。
//
import SwiftUI
import PhotosUI
import UFPDesignSystem

// MARK: - OCR 组件常量（组件特定尺寸，无对应命名 token）
private enum OCRConstants {
    /// OCR 占位图标尺寸 (36pt)
    static let placeholderIconSize: CGFloat = 36
    /// OCR 结果编辑器最大高度 (368pt)
    static let resultEditorMaxHeight: CGFloat = 368
}

// MARK: - OCR Image Picker Area
/// OCR 图片选择区域：显示选中图片或占位符 + 相册选择按钮 + 识别按钮
@MainActor
/// OCR 图片选择与识别触发区域组件
/// 负责图片的选取（从相册）、预览展示及触发后端 OCR 识别流程的交互
struct OCRImagePickerArea: View {
    let selectedImage: AppImage?
    let isProcessing: Bool
    let selectedPhoto: PhotosPickerItem?

    let onPhotoSelected: (PhotosPickerItem?) -> Void
    let onStartRecognition: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.standardPadding) { // 16
            if let image = selectedImage {
                OCRImageContentView(image: image)
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius)
                    .fill(Color.appCard)
                    .frame(height: DesignTokens.ComponentSpacing.chartHeight) // 220 最近档舍入
                    .overlay(
                        VStack(spacing: DesignTokens.Spacing.medium) { // 12
                            Image(systemName: DesignTokens.Icons.ocr)
                                .font(.system(size: OCRConstants.placeholderIconSize)) // 36 组件特定尺寸
                                .foregroundStyle(.appSecondary)
                            Text(L10n.Ingest.OCR.selectImage)
                                .font(.subheadline)
                                .foregroundStyle(.appSecondary)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Spacing.cardRadius)
                            .strokeBorder(style: StrokeStyle(lineWidth: DesignTokens.Reference.Stroke.two, dash: [CGFloat(DesignTokens.Spacing.small)])) // 2, 8
                            .foregroundStyle(.appBorder)
                    )
            }

            // Photo picker
            HStack(spacing: DesignTokens.Spacing.standardPadding) { // 16
                PhotosPicker(selection: Binding(
                    get: { selectedPhoto },
                    set: { onPhotoSelected($0) }
                ), matching: .images) {
                    Label(L10n.Ingest.OCR.fromAlbum, systemImage: DesignTokens.Icons.photoOnRectangle)
                        .font(.subheadline)
                        .foregroundStyle(.appAccent)
                        .padding(.horizontal, DesignTokens.Spacing.standardPadding) // 16
                        .padding(.vertical, DesignTokens.SystemSpacing.elementLarge) // 10
                        .background(Color.appAccent.opacity(DesignTokens.Colors.Opacity.glassOpacity), in: RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius)) // 0.1
                }
                .accessibilityIdentifier("ocr-select-photo")

                if selectedImage != nil {
                    Button(action: onStartRecognition) {
                        HStack(spacing: DesignTokens.SystemSpacing.small) { // 6
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(DesignTokens.SystemOpacity.textSecondary) // 0.8
                            }
                            Text(isProcessing ? L10n.Ingest.OCR.processing : L10n.Ingest.OCR.recognize)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignTokens.Spacing.standardPadding) // 16
                        .padding(.vertical, DesignTokens.SystemSpacing.elementLarge) // 10
                        .background(Color.appAccent, in: RoundedRectangle(cornerRadius: DesignTokens.Spacing.smallRadius))
                    }
                    .accessibilityIdentifier("ocr-start-recognition")
                    .disabled(isProcessing)
                }
            }
        }
    }
}

// MARK: - OCR Result Display
/// OCR 识别结果展示区：显示识别的文本和字符数统计
/// OCR 识别结果实时展示组件
/// 负责显示提取出的文本内容，并提供手动修正输入、字符计数及剪贴板复制功能
struct OCRResultDisplay: View {
    @Binding var recognizedText: String
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) { // 12
            HStack {
                Label(L10n.Ingest.OCR.result, systemImage: DesignTokens.Icons.document)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.appText)

                Spacer()

                Button(action: onCopy) {
                    Label(L10n.Common.copy, systemImage: DesignTokens.Icons.copy)
                        .font(.caption)
                        .foregroundStyle(.appAccent)
                }
                .accessibilityIdentifier("ocr-copy-text")
            }

            AdaptiveTextEditor(text: $recognizedText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.appText)
                .frame(minHeight: DesignTokens.ComponentSpacing.emptyStateImageHalf, maxHeight: OCRConstants.resultEditorMaxHeight) // 120, 368
                .borderedCardStyle(
                    horizontalPadding: DesignTokens.Spacing.small,
                    verticalPadding: DesignTokens.Spacing.small,
                    backgroundOpacity: DesignTokens.Opacity.dim,
                    cornerRadius: DesignTokens.Spacing.smallRadius,
                    borderWidth: DesignTokens.Spacing.borderWidth
                )

            HStack {
                Text(L10n.Ingest.ocrCharCountFormat(recognizedText.count))
                    .font(.caption)
                    .foregroundStyle(.appSecondary)

                Spacer()
            }
        }
    }
}
