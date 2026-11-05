//
//  LabVisualSampleProvider.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层 / 工具模块
//  核心职责：Model Lab 视觉问答 (Ask Image) 真实样本提供者与图像元数据解析算子。
//

import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import UFPCore

/// 图像元数据
struct VisualMetadata: Sendable, Equatable {
    let width: Int
    let height: Int
    let byteSize: Int
}

/// 视觉样本描述结构
struct VisualSampleItem: Identifiable, Sendable, Equatable {
    let id: String
    let title: String
    let prompt: String
    let width: Int
    let height: Int
    let byteSize: Int
    let imageData: Data

    var resolutionString: String {
        "\(width)×\(height)"
    }

    var formattedSizeString: String {
        ByteFormatter.format(Int64(byteSize))
    }
}

/// 绘图辅助结构：层级颜色定义
private struct SampleLayerColor: Sendable {
    let rChannel: CGFloat
    let gChannel: CGFloat
    let bChannel: CGFloat
}

/// 绘图辅助结构：建筑物矩形定义
private struct SampleBuildingRect: Sendable {
    let originX: CGFloat
    let originY: CGFloat
    let width: CGFloat
}

/// 视觉样本与元数据提取器
final class LabVisualSampleProvider: Sendable {

    static let shared = LabVisualSampleProvider()

    private init() {}

    /// 解析任意图片数据的真实元数据与分辨率
    func extractMetadata(from data: Data) -> VisualMetadata? {
        guard !data.isEmpty else { return nil }
        #if canImport(UIKit)
        guard let uiImage = UIImage(data: data) else { return nil }
        let pixelWidth = Int(uiImage.size.width * uiImage.scale)
        let pixelHeight = Int(uiImage.size.height * uiImage.scale)
        return VisualMetadata(width: pixelWidth, height: pixelHeight, byteSize: data.count)
        #else
        return nil
        #endif
    }

    /// 预置高保真多模态实测样例集合
    var presetSamples: [VisualSampleItem] {
        [
            createSmartDeskSample(),
            createArchitectureSample(),
            createCityNightSample()
        ].compactMap { $0 }
    }

    // MARK: - 样例图像合成（纯内存 CoreGraphics 真实 PNG）

    private func createSmartDeskSample() -> VisualSampleItem? {
        let sampleWidth = FeatureConstants.ModelLabSimulation.sampleImageWidth
        let sampleHeight = FeatureConstants.ModelLabSimulation.sampleImageHeight
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: sampleWidth, height: sampleHeight))
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            // 桌面底色
            cg.setFillColor(red: 0.15, green: 0.16, blue: 0.20, alpha: 1.0)
            cg.fill(CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

            // 显示器屏幕
            cg.setFillColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0)
            cg.fill(CGRect(x: 100, y: 80, width: 440, height: 260))
            cg.setStrokeColor(red: 0.3, green: 0.4, blue: 0.6, alpha: 1.0)
            cg.setLineWidth(4.0)
            cg.stroke(CGRect(x: 100, y: 80, width: 440, height: 260))

            // 显示器内代码与图表
            cg.setFillColor(red: 0.2, green: 0.7, blue: 0.9, alpha: 0.8)
            cg.fill(CGRect(x: 120, y: 110, width: 200, height: 16))
            cg.fill(CGRect(x: 120, y: 135, width: 140, height: 16))

            // 键盘与触控板
            cg.setFillColor(red: 0.25, green: 0.26, blue: 0.32, alpha: 1.0)
            cg.fill(CGRect(x: 180, y: 370, width: 280, height: 70))

            // 咖啡杯与绿植
            cg.setFillColor(red: 0.85, green: 0.45, blue: 0.25, alpha: 1.0)
            cg.fillEllipse(in: CGRect(x: 500, y: 380, width: 50, height: 50))
            cg.setFillColor(red: 0.2, green: 0.8, blue: 0.4, alpha: 1.0)
            cg.fillEllipse(in: CGRect(x: 40, y: 340, width: 70, height: 90))
        }

        guard let pngData = image.pngData() else { return nil }
        return VisualSampleItem(
            id: "smart_desk",
            title: L10n.ModelManager.Lab.AskImage.sampleSmartDesk,
            prompt: L10n.ModelManager.Lab.Prompt.askImage,
            width: sampleWidth,
            height: sampleHeight,
            byteSize: pngData.count,
            imageData: pngData
        )
        #else
        return nil
        #endif
    }

    private func createArchitectureSample() -> VisualSampleItem? {
        let sampleWidth = FeatureConstants.ModelLabSimulation.sampleImageWidth
        let sampleHeight = FeatureConstants.ModelLabSimulation.sampleImageHeight
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: sampleWidth, height: sampleHeight))
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            // 背景
            cg.setFillColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1.0)
            cg.fill(CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

            // 架构分层框图
            let layers: [SampleLayerColor] = [
                SampleLayerColor(rChannel: 0.3, gChannel: 0.6, bChannel: 0.9), // L3 表现层
                SampleLayerColor(rChannel: 0.2, gChannel: 0.8, bChannel: 0.6), // L2 业务层
                SampleLayerColor(rChannel: 0.9, gChannel: 0.6, bChannel: 0.2), // L1 核心层
                SampleLayerColor(rChannel: 0.6, gChannel: 0.4, bChannel: 0.8)  // L0 底座层
            ]

            for (index, color) in layers.enumerated() {
                let yPos = CGFloat(70 + index * Int(FeatureConstants.LabMultimodal.buildingSpacing))
                cg.setFillColor(red: color.rChannel, green: color.gChannel, blue: color.bChannel, alpha: 0.25)
                cg.fill(CGRect(x: 80, y: yPos, width: 480, height: 70))
                cg.setStrokeColor(red: color.rChannel, green: color.gChannel, blue: color.bChannel, alpha: 0.9)
                cg.setLineWidth(2.5)
                cg.stroke(CGRect(x: 80, y: yPos, width: 480, height: 70))
            }
        }

        guard let pngData = image.pngData() else { return nil }
        return VisualSampleItem(
            id: "arch_chart",
            title: L10n.ModelManager.Lab.AskImage.sampleArchChart,
            prompt: L10n.ModelManager.Lab.Prompt.agentSkills,
            width: sampleWidth,
            height: sampleHeight,
            byteSize: pngData.count,
            imageData: pngData
        )
        #else
        return nil
        #endif
    }

    private func createCityNightSample() -> VisualSampleItem? {
        let sampleWidth = FeatureConstants.ModelLabSimulation.sampleImageWidth
        let sampleHeight = FeatureConstants.ModelLabSimulation.sampleImageHeight
        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: sampleWidth, height: sampleHeight))
        let image = renderer.image { ctx in
            let cg = ctx.cgContext
            // 深夜天空渐变
            cg.setFillColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 1.0)
            cg.fill(CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

            // 月亮/光晕
            cg.setFillColor(red: 0.95, green: 0.95, blue: 0.8, alpha: 0.9)
            cg.fillEllipse(in: CGRect(x: 480, y: 60, width: 60, height: 60))

            // 建筑物轮廓
            let buildings: [SampleBuildingRect] = [
                SampleBuildingRect(originX: 40, originY: 260, width: 90),
                SampleBuildingRect(originX: 140, originY: 180, width: 110),
                SampleBuildingRect(originX: 260, originY: 220, width: 80),
                SampleBuildingRect(originX: 350, originY: 150, width: 120),
                SampleBuildingRect(originX: 480, originY: 240, width: 100)
            ]

            for b in buildings {
                cg.setFillColor(red: 0.12, green: 0.14, blue: 0.22, alpha: 1.0)
                cg.fill(CGRect(x: b.originX, y: b.originY, width: b.width, height: CGFloat(sampleHeight) - b.originY))

                // 发光窗格
                cg.setFillColor(red: 0.95, green: 0.8, blue: 0.3, alpha: 0.7)
                for wy in stride(from: b.originY + 20, to: CGFloat(sampleHeight) - 30, by: 35) {
                    cg.fill(CGRect(x: b.originX + 15, y: wy, width: 12, height: 18))
                    cg.fill(CGRect(x: b.originX + 40, y: wy, width: 12, height: 18))
                }
            }
        }

        guard let pngData = image.pngData() else { return nil }
        return VisualSampleItem(
            id: "city_night",
            title: L10n.ModelManager.Lab.AskImage.sampleCityNight,
            prompt: L10n.ModelManager.Lab.Prompt.tinyGarden,
            width: sampleWidth,
            height: sampleHeight,
            byteSize: pngData.count,
            imageData: pngData
        )
        #else
        return nil
        #endif
    }
}
