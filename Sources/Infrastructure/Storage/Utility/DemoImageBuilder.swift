//
//  DemoImageBuilder.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层 / 工具
//  核心职责：为 OCR 扫描与图片导入记录生成高可读性、高精度且与页面内容 100% 对应的出版级图像。
//

#if canImport(UIKit)
import UIKit
import SwiftUI

public struct DemoImageBuilder {
    /// 确保 OCR 扫描示例图片就绪，若不存在或需要更新则动态绘制高精度原图
    public static func ensureImageExists(at path: String, title: String) -> UIImage? {
        // 如果文件存在，先尝试加载；如果加载成功且高度符合高清标准，则返回
        if FileManager.default.fileExists(atPath: path), let img = UIImage(contentsOfFile: path), img.size.width >= 1000 {
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
        // 使用 1200 x 900 像素的高分辨画板，确保多倍缩放高清可读
        let size = CGSize(width: 1200, height: 900)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let cgContext = context.cgContext
            drawBackgroundAndGrid(cgContext: cgContext, size: size)
            
            let neuronKeyword1 = String(localized: "demo.ocr.keyword.neuron", defaultValue: "神经")
            let neuronKeyword2 = String(localized: "demo.ocr.keyword.pkm", defaultValue: "PKM")
            let neuronKeyword3 = String(localized: "demo.ocr.keyword.knowledge", defaultValue: "知识")
            
            if title.contains(neuronKeyword1) || title.contains(neuronKeyword2) || title.contains(neuronKeyword3) {
                drawNeuronKnowledgeOCR(cgContext: cgContext, title: title, size: size)
            } else {
                drawCoffeeSOPOCR(cgContext: cgContext, title: title, size: size)
            }
        }
    }

    private static func drawBackgroundAndGrid(cgContext: CGContext, size: CGSize) {
        let colors = [
            UIColor(red: 0.07, green: 0.09, blue: 0.15, alpha: 1.0).cgColor,
            UIColor(red: 0.12, green: 0.15, blue: 0.24, alpha: 1.0).cgColor
        ]
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: [0.0, 1.0]) {
            cgContext.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
        }
        
        // 绘制高科技质感的网格背景线
        cgContext.setLineWidth(1)
        cgContext.setStrokeColor(UIColor.white.withAlphaComponent(0.06).cgColor)
        let step: CGFloat = 50
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

    /// 绘制 PKM 神经元主题的高精图表与大字
    private static func drawNeuronKnowledgeOCR(cgContext: CGContext, title: String, size: CGSize) {
        // 1. 顶栏标题
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
            .foregroundColor: UIColor(red: 0.40, green: 0.75, blue: 1.0, alpha: 1.0)
        ]
        let headerText = String(localized: "demo.ocr.neuron.header", defaultValue: "📷 OCR 图文识别文本 [识别置信度: 99.4% | 原图来源: 神经元与脑网络导图.png]")
        headerText.draw(at: CGPoint(x: 50, y: 40), withAttributes: headerAttrs)
        
        // 2. 主标题
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 34),
            .foregroundColor: UIColor.white
        ]
        let displayTitle = String(localized: "demo.ocr.neuron.title", defaultValue: "神经网络与人脑知识表征")
        displayTitle.draw(at: CGPoint(x: 50, y: 80), withAttributes: titleAttrs)
        
        // 3. 详细干货段落
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .regular),
            .foregroundColor: UIColor(white: 0.90, alpha: 1.0)
        ]
        let bodyText = String(localized: "demo.ocr.neuron.body", defaultValue: "人脑记忆是由数百亿个神经元 (Neuron) 通过突触 (Synapse) 互相连接构成的复杂网络，这与「双向链接」在网状图谱中的价值高度相似：")
        let bodyRect = CGRect(x: 50, y: 135, width: size.width - 100, height: 70)
        bodyText.draw(in: bodyRect, withAttributes: bodyAttrs)
        
        // 4. 画 4 个核心要素表格卡片
        let startY = drawNeuronTableRows(size: size)
        
        // 5. 底部 RAG 考据备注框
        let noteRect = CGRect(x: 50, y: startY + 20, width: size.width - 100, height: 80)
        let notePath = UIBezierPath(roundedRect: noteRect, cornerRadius: 10)
        UIColor(red: 0.10, green: 0.30, blue: 0.45, alpha: 0.6).setFill()
        notePath.fill()
        UIColor(red: 0.30, green: 0.70, blue: 0.95, alpha: 0.8).setStroke()
        notePath.lineWidth = 1.5
        notePath.stroke()
        
        let noteAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .medium),
            .foregroundColor: UIColor(red: 0.85, green: 0.95, blue: 1.0, alpha: 1.0)
        ]
        let noteText = String(localized: "demo.ocr.neuron.note", defaultValue: "💡 RAG 考据备注：关于大脑记忆表征与网状索引的数学证明，请参见「跨领域笔记枢纽指南」的相关章节。")
        noteText.draw(in: noteRect.insetBy(dx: 20, dy: 20), withAttributes: noteAttrs)
    }

    private static func drawNeuronTableRows(size: CGSize) -> CGFloat {
        let rows = [
            (String(localized: "demo.ocr.neuron.r1c1", defaultValue: "结构要素"), String(localized: "demo.ocr.neuron.r1c2", defaultValue: "生物大脑 (Biological Brain)"), String(localized: "demo.ocr.neuron.r1c3", defaultValue: "智宇数字外脑 (ZhiYu PKM)")),
            (String(localized: "demo.ocr.neuron.r2c1", defaultValue: "基本单元"), String(localized: "demo.ocr.neuron.r2c2", defaultValue: "神经元 (Neuron)"), String(localized: "demo.ocr.neuron.r2c3", defaultValue: "原子化卡片 (KnowledgePage)")),
            (String(localized: "demo.ocr.neuron.r3c1", defaultValue: "连接纽带"), String(localized: "demo.ocr.neuron.r3c2", defaultValue: "突触 (Synapse)"), String(localized: "demo.ocr.neuron.r3c3", defaultValue: "双向引用链接 (「...」)")),
            (String(localized: "demo.ocr.neuron.r4c1", defaultValue: "信号传导"), String(localized: "demo.ocr.neuron.r4c2", defaultValue: "电冲动与神经递质"), String(localized: "demo.ocr.neuron.r4c3", defaultValue: "混合检索 & 向量相似度计算")),
            (String(localized: "demo.ocr.neuron.r5c1", defaultValue: "记忆重构"), String(localized: "demo.ocr.neuron.r5c2", defaultValue: "神经可塑性 (Neuroplasticity)"), String(localized: "demo.ocr.neuron.r5c3", defaultValue: "3D 知识图谱聚类与涌现"))
        ]
        
        var startY: CGFloat = 220
        let colWidths: [CGFloat] = [220, 420, 420]
        
        for (i, row) in rows.enumerated() {
            let isHeader = (i == 0)
            let cardBgColor = isHeader ? UIColor(red: 0.15, green: 0.22, blue: 0.38, alpha: 0.9) : UIColor(red: 0.12, green: 0.16, blue: 0.26, alpha: 0.8)
            let font = isHeader ? UIFont.boldSystemFont(ofSize: 20) : UIFont.systemFont(ofSize: 19, weight: .medium)
            let textColor = isHeader ? UIColor(red: 0.40, green: 0.75, blue: 1.0, alpha: 1.0) : UIColor.white
            
            var startX: CGFloat = 50
            let rowHeight: CGFloat = 60
            
            for (j, text) in [row.0, row.1, row.2].enumerated() {
                let rect = CGRect(x: startX, y: startY, width: colWidths[j] - 15, height: rowHeight - 10)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
                cardBgColor.setFill()
                path.fill()
                
                let borderStroke = isHeader ? UIColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 0.5) : UIColor.white.withAlphaComponent(0.1)
                borderStroke.setStroke()
                path.lineWidth = 1
                path.stroke()
                
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor
                ]
                let textSize = text.size(withAttributes: textAttrs)
                text.draw(at: CGPoint(x: rect.minX + 20, y: rect.minY + (rect.height - textSize.height) / 2), withAttributes: textAttrs)
                
                startX += colWidths[j]
            }
            startY += rowHeight
        }
        return startY
    }

    /// 绘制商业/选址 SOP 主题的高精图表与大字
    private static func drawCoffeeSOPOCR(cgContext: CGContext, title: String, size: CGSize) {
        // 1. 顶栏标题
        let headerAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .semibold),
            .foregroundColor: UIColor(red: 1.0, green: 0.65, blue: 0.30, alpha: 1.0)
        ]
        let headerText = String(localized: "demo.ocr.coffee.header", defaultValue: "📷 OCR 图文识别文本 [识别置信度: 98.8% | 原图来源: ocr_store_manual.png]")
        headerText.draw(at: CGPoint(x: 50, y: 40), withAttributes: headerAttrs)
        
        // 2. 主标题
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 34),
            .foregroundColor: UIColor.white
        ]
        let displayTitle = String(localized: "demo.ocr.coffee.title", defaultValue: "咖啡连锁店 SOP 选址评估与坪效模型")
        displayTitle.draw(at: CGPoint(x: 50, y: 80), withAttributes: titleAttrs)
        
        // 3. 详细干货段落
        let bodyAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 22, weight: .regular),
            .foregroundColor: UIColor(white: 0.90, alpha: 1.0)
        ]
        let bodyText = String(localized: "demo.ocr.coffee.body", defaultValue: "理性的数据模型是打破经验主义的最好武器，直接指导「瑞幸与库迪竞争策略对比分析」与选址决策：")
        let bodyRect = CGRect(x: 50, y: 135, width: size.width - 100, height: 70)
        bodyText.draw(in: bodyRect, withAttributes: bodyAttrs)
        
        // 4. 画 4 个核心要素表格卡片
        let startY = drawCoffeeTableRows(size: size)
        
        // 5. 底部 SOP 考据备注框
        let noteRect = CGRect(x: 50, y: startY + 20, width: size.width - 100, height: 80)
        let notePath = UIBezierPath(roundedRect: noteRect, cornerRadius: 10)
        UIColor(red: 0.40, green: 0.25, blue: 0.10, alpha: 0.6).setFill()
        notePath.fill()
        UIColor(red: 0.95, green: 0.60, blue: 0.25, alpha: 0.8).setStroke()
        notePath.lineWidth = 1.5
        notePath.stroke()
        
        let noteAttrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 20, weight: .medium),
            .foregroundColor: UIColor(red: 1.0, green: 0.90, blue: 0.80, alpha: 1.0)
        ]
        let noteText = String(localized: "demo.ocr.coffee.note", defaultValue: "📋 SOP 运营备注：选址数据与成本控制模型相关，详情参见「咖啡连锁行业选址规划」。")
        noteText.draw(in: noteRect.insetBy(dx: 20, dy: 20), withAttributes: noteAttrs)
    }

    private static func drawCoffeeTableRows(size: CGSize) -> CGFloat {
        let rows = [
            (String(localized: "demo.ocr.coffee.r1c1", defaultValue: "评估维度"), String(localized: "demo.ocr.coffee.r1c2", defaultValue: "核心权重"), String(localized: "demo.ocr.coffee.r1c3", defaultValue: "实测数据与 SOP 考核标准")),
            (String(localized: "demo.ocr.coffee.r2c1", defaultValue: "人流密度"), String(localized: "demo.ocr.coffee.r2c2", defaultValue: "30% 权重"), String(localized: "demo.ocr.coffee.r2c3", defaultValue: "峰值 > 120人/分钟（早高峰/午休）")),
            (String(localized: "demo.ocr.coffee.r3c1", defaultValue: "竞品分布"), String(localized: "demo.ocr.coffee.r3c2", defaultValue: "25% 权重"), String(localized: "demo.ocr.coffee.r3c3", defaultValue: "500米圈内已有 3 家，主打差异化冷萃")),
            (String(localized: "demo.ocr.coffee.r4c1", defaultValue: "预估坪效"), String(localized: "demo.ocr.coffee.r4c2", defaultValue: "25% 权重"), String(localized: "demo.ocr.coffee.r4c3", defaultValue: "目标 4,500元/㎡/月，外卖比例 > 40%")),
            (String(localized: "demo.ocr.coffee.r5c1", defaultValue: "供应链可达"), String(localized: "demo.ocr.coffee.r5c2", defaultValue: "20% 权重"), String(localized: "demo.ocr.coffee.r5c3", defaultValue: "冷链配送 24h 内完备交付（见采购清单）"))
        ]
        
        var startY: CGFloat = 220
        let colWidths: [CGFloat] = [220, 260, 580]
        
        for (i, row) in rows.enumerated() {
            let isHeader = (i == 0)
            let cardBgColor = isHeader ? UIColor(red: 0.35, green: 0.20, blue: 0.10, alpha: 0.9) : UIColor(red: 0.22, green: 0.14, blue: 0.10, alpha: 0.8)
            let font = isHeader ? UIFont.boldSystemFont(ofSize: 20) : UIFont.systemFont(ofSize: 19, weight: .medium)
            let textColor = isHeader ? UIColor(red: 1.0, green: 0.70, blue: 0.40, alpha: 1.0) : UIColor.white
            
            var startX: CGFloat = 50
            let rowHeight: CGFloat = 60
            
            for (j, text) in [row.0, row.1, row.2].enumerated() {
                let rect = CGRect(x: startX, y: startY, width: colWidths[j] - 15, height: rowHeight - 10)
                let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
                cardBgColor.setFill()
                path.fill()
                
                let borderStroke = isHeader ? UIColor(red: 0.9, green: 0.5, blue: 0.2, alpha: 0.5) : UIColor.white.withAlphaComponent(0.1)
                borderStroke.setStroke()
                path.lineWidth = 1
                path.stroke()
                
                let textAttrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: textColor
                ]
                let textSize = text.size(withAttributes: textAttrs)
                text.draw(at: CGPoint(x: rect.minX + 20, y: rect.minY + (rect.height - textSize.height) / 2), withAttributes: textAttrs)
                
                startX += colWidths[j]
            }
            startY += rowHeight
        }
        return startY
    }
}
#endif
