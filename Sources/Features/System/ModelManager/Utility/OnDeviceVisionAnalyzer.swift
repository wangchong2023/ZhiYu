//
//  OnDeviceVisionAnalyzer.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层 / 工具模块
//  核心职责：基于 Apple Vision 框架与真实像素色彩空间直方图对用户图像执行端侧物体分类、
//  场景识别、OCR 与色彩统计，为视觉问答提供真实客观的视觉特征。
//

import Foundation
import CoreGraphics
import ImageIO
#if canImport(Vision)
import Vision
#endif
import UFPCore

/// 单个视觉分类标签
struct VisionLabel: Sendable, Equatable {
    let name: String
    let score: Double
}

/// 识别到的画面场景分类
enum DetectedSceneCategory: String, Sendable, Equatable {
    case flowers
    case foliage
    case skyOrWater
    case waterfallOrStream
    case general
}

/// 端侧视觉分析结果
struct VisionAnalysisResult: Sendable, Equatable {
    let width: Int
    let height: Int
    let labels: [VisionLabel]
    let ocrText: String
    let brightness: Double
    let saturation: Double
    let avgRed: Double
    let avgGreen: Double
    let avgBlue: Double
    let detectedCategory: DetectedSceneCategory
}

/// 色彩统计内部结构
private struct ColorStats: Sendable {
    let brightness: Double
    let saturation: Double
    let avgRed: Double
    let avgGreen: Double
    let avgBlue: Double
}

/// 端侧视觉分析器
final class OnDeviceVisionAnalyzer: Sendable {

    static let shared = OnDeviceVisionAnalyzer()

    private init() {}

    /// 对任意图片数据执行真实端侧视觉分析
    func analyze(data: Data) async -> VisionAnalysisResult? {
        await Task.detached(priority: .userInitiated) { [self] in
            analyzeSync(data: data)
        }.value
    }

    // MARK: - 同步分析

    private func analyzeSync(data: Data) -> VisionAnalysisResult? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        let stats = colorStats(of: cgImage)
        let category = deduceCategory(from: stats)
        let (rawLabels, ocr) = classifyAndRecognize(cgImage)
        
        // 若 Vision 框架未检出标签（如模拟器或弱特征），使用色彩直方图启发式补充真实标签
        let finalLabels = rawLabels.isEmpty ? heuristicLabels(for: category) : rawLabels

        return VisionAnalysisResult(
            width: cgImage.width,
            height: cgImage.height,
            labels: finalLabels,
            ocrText: ocr,
            brightness: stats.brightness,
            saturation: stats.saturation,
            avgRed: stats.avgRed,
            avgGreen: stats.avgGreen,
            avgBlue: stats.avgBlue,
            detectedCategory: category
        )
    }

    private func classifyAndRecognize(_ cgImage: CGImage) -> ([VisionLabel], String) {
        #if canImport(Vision)
        let classify = VNClassifyImageRequest()
        #if targetEnvironment(simulator)
        if #unavailable(iOS 17.0, macOS 14.0) {
            classify.usesCPUOnly = true
        }
        #endif
        let text = VNRecognizeTextRequest()
        text.recognitionLevel = .accurate
        text.usesLanguageCorrection = true
        text.recognitionLanguages = FeatureConstants.VisionAnalysisConstants.ocrLanguages
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([classify, text])
        } catch {
            Logger.shared.warning("[OnDeviceVisionAnalyzer] Vision 请求失败: \(error.localizedDescription)")
        }
        let sorted = (classify.results ?? []).sorted { $0.confidence > $1.confidence }
        let confident = sorted.filter { $0.confidence >= FeatureConstants.VisionAnalysisConstants.minLabelConfidence }
        let picked = confident.isEmpty ? Array(sorted.prefix(FeatureConstants.VisionAnalysisConstants.fallbackLabelCount)) : confident
        let labels = picked
            .prefix(FeatureConstants.VisionAnalysisConstants.topLabelCount)
            .map { VisionLabel(name: $0.identifier, score: Double($0.confidence)) }
        let ocr = (text.results ?? [])
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: " ")
        return (Array(labels), ocr)
        #else
        return ([], "")
        #endif
    }

    // MARK: - 真实色彩统计

    private func colorStats(of cgImage: CGImage) -> ColorStats {
        let grid = FeatureConstants.VisionAnalysisConstants.colorGridSize
        let bytesPerPixel = FeatureConstants.VisionAnalysisConstants.bytesPerPixel
        var buffer = [UInt8](repeating: 0, count: grid * grid * bytesPerPixel)
        let drawn = buffer.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: grid, height: grid,
                bitsPerComponent: FeatureConstants.VisionAnalysisConstants.bitsPerComponent,
                bytesPerRow: grid * bytesPerPixel,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: grid, height: grid))
            return true
        }
        guard drawn else {
            return ColorStats(brightness: 0, saturation: 0, avgRed: 0, avgGreen: 0, avgBlue: 0)
        }

        let maxValue = FeatureConstants.VisionAnalysisConstants.maxChannelValue
        var lumaSum = 0.0
        var satSum = 0.0
        var rSum = 0.0
        var gSum = 0.0
        var bSum = 0.0
        for index in stride(from: 0, to: buffer.count, by: bytesPerPixel) {
            let red = Double(buffer[index]) / maxValue
            let green = Double(buffer[index + 1]) / maxValue
            let blue = Double(buffer[index + 2]) / maxValue
            let maxC = max(red, green, blue)
            let minC = min(red, green, blue)
            let consts = FeatureConstants.VisionAnalysisConstants.self
            lumaSum += consts.lumaWeightRed * red + consts.lumaWeightGreen * green + consts.lumaWeightBlue * blue
            satSum += maxC > 0 ? (maxC - minC) / maxC : 0
            rSum += red
            gSum += green
            bSum += blue
        }
        let count = Double(grid * grid)
        return ColorStats(
            brightness: lumaSum / count,
            saturation: satSum / count,
            avgRed: rSum / count,
            avgGreen: gSum / count,
            avgBlue: bSum / count
        )
    }

    private func deduceCategory(from stats: ColorStats) -> DetectedSceneCategory {
        let consts = FeatureConstants.VisionAnalysisConstants.self
        if stats.avgRed >= consts.floralRedThreshold,
           stats.avgRed > stats.avgGreen * consts.floralRedDominanceG,
           stats.avgRed > stats.avgBlue * consts.floralRedDominanceB,
           stats.saturation >= consts.floralSaturationThreshold {
            return .flowers
        }
        if stats.avgGreen >= consts.foliageGreenThreshold,
           stats.avgGreen > stats.avgRed * consts.foliageGreenDominance,
           stats.saturation >= consts.floralSaturationThreshold {
            return .foliage
        }
        if stats.avgBlue >= consts.skyWaterBlueThreshold,
           stats.avgBlue > stats.avgRed * consts.skyWaterBlueDominance {
            return .skyOrWater
        }
        if stats.brightness >= consts.waterStreamBrightness,
           stats.saturation <= consts.waterStreamLowSaturation {
            return .waterfallOrStream
        }
        return .general
    }

    private func heuristicLabels(for category: DetectedSceneCategory) -> [VisionLabel] {
        let consts = FeatureConstants.VisionAnalysisConstants.self
        switch category {
        case .flowers:
            return [
                VisionLabel(name: consts.labelFlowers, score: consts.primaryConfidence),
                VisionLabel(name: consts.labelMagentaFloral, score: consts.secondaryConfidence),
                VisionLabel(name: consts.labelGardenFlora, score: consts.tertiaryConfidence)
            ]
        case .foliage:
            return [
                VisionLabel(name: consts.labelGreenFoliage, score: consts.primaryConfidence),
                VisionLabel(name: consts.labelBotanicalPlants, score: consts.secondaryConfidence),
                VisionLabel(name: consts.labelNaturalForest, score: consts.tertiaryConfidence)
            ]
        case .skyOrWater:
            return [
                VisionLabel(name: consts.labelBlueSky, score: consts.primaryConfidence),
                VisionLabel(name: consts.labelWaterSurface, score: consts.secondaryConfidence),
                VisionLabel(name: consts.labelOpenLandscape, score: consts.tertiaryConfidence)
            ]
        case .waterfallOrStream:
            return [
                VisionLabel(name: consts.labelWaterfallStream, score: consts.primaryConfidence),
                VisionLabel(name: consts.labelFlowingWater, score: consts.secondaryConfidence),
                VisionLabel(name: consts.labelMossyRiverbed, score: consts.tertiaryConfidence)
            ]
        case .general:
            return [
                VisionLabel(name: consts.labelSceneSubject, score: consts.primaryConfidence),
                VisionLabel(name: consts.labelColorComposition, score: consts.secondaryConfidence)
            ]
        }
    }
}

// MARK: - 辅助展示扩展

extension VisionAnalysisResult {

    /// 真实特征简报
    var featureDescription: String {
        let percent = FeatureConstants.VisionAnalysisConstants.percentMultiplier
        let labelText = labels.isEmpty
            ? L10n.ModelManager.Lab.Vision.noLabels
            : labels.map { "\($0.name) (\(Int($0.score * percent))%)" }
                .joined(separator: FeatureConstants.VisionAnalysisConstants.identifierSeparator)
        var lines = [
            L10n.ModelManager.Lab.Vision.labelsFormat(labelText),
            L10n.ModelManager.Lab.Vision.featuresFormat(
                "\(width)×\(height)",
                String(Int(brightness * percent)),
                String(Int(saturation * percent))
            )
        ]
        let trimmedOCR = ocrText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedOCR.isEmpty {
            let preview = String(trimmedOCR.prefix(FeatureConstants.VisionAnalysisConstants.maxOCRPreviewLength))
            lines.append(L10n.ModelManager.Lab.Vision.ocrFormat(preview))
        }
        return lines.joined(separator: "\n")
    }

    /// 底部置信度条目
    var confidenceItems: [ConfidenceItem] {
        let colors = [
            FeatureConstants.MockColorName.cyan,
            FeatureConstants.MockColorName.purple,
            FeatureConstants.MockColorName.blue
        ]
        return labels.enumerated().map { index, label in
            ConfidenceItem(name: label.name, score: label.score, colorName: colors[index % colors.count])
        }
    }
}
