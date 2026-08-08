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
        VStack(spacing: DesignSystem.standardPadding) { // 16
            if let image = selectedImage {
                OCRImageContentView(image: image)
            } else {
                // Placeholder
                RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                    .fill(Color.appCard)
                    .frame(height: DesignSystem.Metrics.heroValueSize * 7.7) // 200
                    .overlay(
                        VStack(spacing: DesignSystem.medium) { // 12
                            Image(systemName: DesignSystem.Icons.ocr)
                                .font(.system(size: DesignSystem.largeIconSize + DesignSystem.small)) // 40
                                .foregroundStyle(.appSecondary)
                            Text(L10n.Ingest.OCR.selectImage)
                                .font(.subheadline)
                                .foregroundStyle(.appSecondary)
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignSystem.cardRadius)
                            .strokeBorder(style: StrokeStyle(lineWidth: DesignSystem.borderWidth * 2, dash: [CGFloat(DesignSystem.small)])) // 2, 8
                            .foregroundStyle(.appBorder)
                    )
            }

            // Photo picker
            HStack(spacing: DesignSystem.standardPadding) { // 16
                PhotosPicker(selection: Binding(
                    get: { selectedPhoto },
                    set: { onPhotoSelected($0) }
                ), matching: .images) {
                    Label(L10n.Ingest.OCR.fromAlbum, systemImage: DesignSystem.Icons.photoOnRectangle)
                        .font(.subheadline)
                        .foregroundStyle(.appAccent)
                        .padding(.horizontal, DesignSystem.standardPadding) // 16
                        .padding(.vertical, DesignSystem.small + DesignSystem.atomic) // 10
                        .background(Color.appAccent.opacity(DesignSystem.glassOpacity), in: RoundedRectangle(cornerRadius: DesignSystem.smallRadius)) // 0.1
                }
                .accessibilityIdentifier("ocr-select-photo")

                if selectedImage != nil {
                    Button(action: onStartRecognition) {
                        HStack(spacing: DesignSystem.tiny + DesignSystem.atomic) { // 6
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(DesignSystem.fullOpacity * 0.8) // 0.8
                            }
                            Text(isProcessing ? L10n.Ingest.OCR.processing : L10n.Ingest.OCR.recognize)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, DesignSystem.standardPadding) // 16
                        .padding(.vertical, DesignSystem.small + DesignSystem.atomic) // 10
                        .background(Color.appAccent, in: RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
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
        VStack(alignment: .leading, spacing: DesignSystem.medium) { // 12
            HStack {
                Label(L10n.Ingest.OCR.result, systemImage: DesignSystem.Icons.document)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.appText)

                Spacer()

                Button(action: onCopy) {
                    Label(L10n.Common.copy, systemImage: DesignSystem.Icons.copy)
                        .font(.caption)
                        .foregroundStyle(.appAccent)
                }
                .accessibilityIdentifier("ocr-copy-text")
            }

            AdaptiveTextEditor(text: $recognizedText)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.appText)
                .frame(minHeight: DesignSystem.Metrics.heroValueSize * 4.6, maxHeight: DesignSystem.Metrics.heroValueSize * 11.5) // 120, 300
                .padding(DesignSystem.small) // 8
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                        .stroke(Color.appBorder, lineWidth: DesignSystem.borderWidth) // 1
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

// MARK: - Tag Pill
/// 标签胶囊组件
/// 标签胶囊小组件
/// 负责在 OCR 保存表单中以胶囊形态展示已选标签，并提供删除交互
struct TagPill: View {
    let tag: String
    var onRemove: () -> Void = {}

    var body: some View {
        HStack(spacing: DesignSystem.atomic * 2) { // 4
            Text(tag)
                .font(.caption2)
                .foregroundStyle(.appAccent)

            Button(action: onRemove) {
                Image(systemName: DesignSystem.Icons.errorCircle)
                    .font(.caption2)
                    .foregroundStyle(.appSecondary)
            }
        }
        .padding(.horizontal, DesignSystem.small) // 8
        .padding(.vertical, DesignSystem.tiny) // 4
        .background(Color.appAccent.opacity(DesignSystem.glassOpacity), in: Capsule()) // 0.1
    }
}
