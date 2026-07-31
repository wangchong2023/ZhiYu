//
//  DemoImageBuilder.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层 / 工具
//  核心职责：为 OCR 扫描与图片导入记录生成高可读性、高精度的原生 Preview 图像。
//

#if canImport(UIKit)
import UIKit
import SwiftUI

public struct DemoImageBuilder {
    /// 确保 OCR 扫描示例图片就绪，若不存在则使用 UIGraphicsImageRenderer 动态绘制高科技质感的导图原图
    public static func ensureImageExists(at path: String, title: String) -> UIImage? {
        if FileManager.default.fileExists(atPath: path), let img = UIImage(contentsOfFile: path) {
            return img
        }
        
        let generated = generateDemoImage(title: title)
        if let data = generated.pngData() {
            let fileURL = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: fileURL)
        }
        return generated
    }
    
    private static func generateDemoImage(title: String) -> UIImage {
        let size = CGSize(width: 800, height: 480)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            drawBackgroundAndGrid(cgContext: cgContext, size: size)
            drawTopologyNodes(cgContext: cgContext, size: size)
            drawOCRTitleAndFooter(title: title, size: size)
        }
    }

    private static func drawBackgroundAndGrid(cgContext: CGContext, size: CGSize) {
        let colors = [
            UIColor(Color.appBackground).cgColor,
            UIColor(Color.appCard).cgColor
        ]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0]) {
            cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
        
        cgContext.setLineWidth(1)
        cgContext.setStrokeColor(UIColor(Color.appText).withAlphaComponent(0.06).cgColor)
        let step: CGFloat = 40
        for x in stride(from: CGFloat(0), to: size.width, by: step) {
            cgContext.move(to: CGPoint(x: x, y: 0))
            cgContext.addLine(to: CGPoint(x: x, y: size.height))
        }
        for y in stride(from: CGFloat(0), to: size.height, by: step) {
            cgContext.move(to: CGPoint(x: 0, y: y))
            cgContext.addLine(to: CGPoint(x: size.width, y: y))
        }
        cgContext.strokePath()
    }

    private static func drawTopologyNodes(cgContext: CGContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2 - 10)
        let nodes: [CGPoint] = [
            CGPoint(x: center.x - 180, y: center.y - 70),
            CGPoint(x: center.x + 180, y: center.y - 70),
            CGPoint(x: center.x - 180, y: center.y + 70),
            CGPoint(x: center.x + 180, y: center.y + 70),
            CGPoint(x: center.x, y: center.y - 120)
        ]
        
        cgContext.setLineWidth(2)
        cgContext.setStrokeColor(UIColor(Color.appAccent).withAlphaComponent(0.4).cgColor)
        for node in nodes {
            cgContext.move(to: center)
            cgContext.addLine(to: node)
        }
        cgContext.strokePath()
        
        for node in nodes {
            let rect = CGRect(x: node.x - 16, y: node.y - 16, width: 32, height: 32)
            UIColor(Color.appAccent).withAlphaComponent(0.2).setFill()
            cgContext.fillEllipse(in: rect)
            
            UIColor(Color.appAccent).setStroke()
            cgContext.setLineWidth(2)
            cgContext.strokeEllipse(in: rect)
        }
        
        let mainRect = CGRect(x: center.x - 45, y: center.y - 25, width: 90, height: 50)
        UIColor(Color.appAccent).setFill()
        let path = UIBezierPath(roundedRect: mainRect, cornerRadius: DesignSystem.cardRadius)
        path.fill()
    }

    private static func drawOCRTitleAndFooter(title: String, size: CGSize) {
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 18),
            .foregroundColor: UIColor(Color.appText)
        ]
        let displayTitle = "📷 \(title)"
        let titleSize = (displayTitle as NSString).size(withAttributes: titleAttrs)
        displayTitle.draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: 30), withAttributes: titleAttrs)
        
        let tagAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 13), // Dynamic Type
            .foregroundColor: UIColor(Color.appSecondary)
        ]
        let tagText = L10n.Ingest.ocrScan
        let tagSize = (tagText as NSString).size(withAttributes: tagAttrs)
        tagText.draw(at: CGPoint(x: (size.width - tagSize.width) / 2, y: size.height - 40), withAttributes: tagAttrs)
    }
}
#endif
