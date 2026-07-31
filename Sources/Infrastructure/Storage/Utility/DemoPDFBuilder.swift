//
//  DemoPDFBuilder.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层 / 工具
//  核心职责：为示例演示数据生成真正的原生的 PDF 物理文件，确保在点击预览时拉起 100% 原生的 QuickLook/PDFKit 渲染器。
//

#if canImport(UIKit)
import UIKit
import PDFKit
import SwiftUI

public struct DemoPDFBuilder {
    /// 确保物理 PDF 文件就绪并采用高精度 Markdown 转义引擎进行矢量排版生成
    public static func ensurePDFExists(at path: String, title: String, content: String) -> URL? {
        let fileURL = URL(fileURLWithPath: path)
        
        // 生成包含转义美化排版的 PDF 数据
        let pdfData = generatePDFData(title: title, content: content)
        do {
            let parentDir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            try pdfData.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }
    
    private static func generatePDFData(title: String, content: String) -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: L10n.Common.appName,
            kCGPDFContextAuthor: L10n.Common.appName,
            kCGPDFContextTitle: title
        ]
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageWidth: CGFloat = 8.5 * 72.0
        let pageHeight: CGFloat = 11.0 * 72.0
        let pageRect = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        return renderer.pdfData { context in
            context.beginPage()
            renderHeader(title: title, pageWidth: pageWidth, context: context)
            renderBodyLines(content: content, pageWidth: pageWidth, pageHeight: pageHeight, context: context)
            renderFooter(pageHeight: pageHeight)
        }
    }

    private static func renderHeader(title: String, pageWidth: CGFloat, context: UIGraphicsPDFRendererContext) {
        let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: 70)
        let headerColor = UIColor(Color.appAccent)
        headerColor.setFill()
        context.fill(headerRect)
        
        let headerTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor.white // Dynamic Color
        ]
        let cleanTitle = sanitizeMarkdownText(title)
        let headerTitle = "📄 \(cleanTitle)"
        headerTitle.draw(at: CGPoint(x: 36, y: 24), withAttributes: headerTitleAttributes)
    }

    private static func renderBodyLines(content: String, pageWidth: CGFloat, pageHeight: CGFloat, context: UIGraphicsPDFRendererContext) {
        var currentY: CGFloat = 90
        let contentWidth = pageWidth - 72
        let lines = content.components(separatedBy: "\n")
        
        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                currentY += 8
                continue
            }
            if isTableSeparator(trimmed) { continue }
            
            if trimmed.hasPrefix("# ") {
                currentY = renderH1(trimmed, currentY: currentY, contentWidth: contentWidth)
            } else if trimmed.hasPrefix("## ") {
                currentY = renderH2(trimmed, currentY: currentY, contentWidth: contentWidth)
            } else if trimmed.hasPrefix("> ") {
                currentY = renderQuoteBlock(trimmed, currentY: currentY, contentWidth: contentWidth, context: context)
            } else if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") {
                currentY = renderTableRow(trimmed, currentY: currentY, contentWidth: contentWidth, context: context)
            } else {
                currentY = renderParagraph(trimmed, currentY: currentY, contentWidth: contentWidth)
            }
            
            if currentY > pageHeight - 60 { break }
        }
    }

    private static func renderH1(_ text: String, currentY: CGFloat, contentWidth: CGFloat) -> CGFloat {
        let h1Text = sanitizeMarkdownText(text.replacingOccurrences(of: "# ", with: ""))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        let rect = CGRect(x: 36, y: currentY + 8, width: contentWidth, height: 26)
        h1Text.draw(in: rect, withAttributes: attrs)
        return currentY + 34
    }

    private static func renderH2(_ text: String, currentY: CGFloat, contentWidth: CGFloat) -> CGFloat {
        let h2Text = sanitizeMarkdownText(text.replacingOccurrences(of: "## ", with: ""))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 13),
            .foregroundColor: UIColor(Color.appAccent)
        ]
        let rect = CGRect(x: 36, y: currentY + 6, width: contentWidth, height: 22)
        h2Text.draw(in: rect, withAttributes: attrs)
        return currentY + 28
    }

    private static func renderQuoteBlock(_ text: String, currentY: CGFloat, contentWidth: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let quoteText = sanitizeMarkdownText(text.replacingOccurrences(of: "> ", with: ""))
        let font = UIFont.systemFont(ofSize: 10.5) // Dynamic Type
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.darkGray,
            .paragraphStyle: paragraph
        ]
        
        let bgRect = CGRect(x: 36, y: currentY, width: contentWidth, height: 28)
        UIColor(Color.appAccent).withAlphaComponent(0.08).setFill()
        context.fill(bgRect)
        
        let lineRect = CGRect(x: 36, y: currentY, width: 3, height: 28)
        UIColor(Color.appAccent).setFill()
        context.fill(lineRect)
        
        let textRect = CGRect(x: 45, y: currentY + 5, width: contentWidth - 15, height: 20)
        quoteText.draw(in: textRect, withAttributes: attrs)
        return currentY + 32
    }

    private static func renderTableRow(_ text: String, currentY: CGFloat, contentWidth: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let cols = text.split(separator: "|").map { sanitizeMarkdownText(String($0)) }
        let colWidth = contentWidth / CGFloat(max(1, cols.count))
        
        let cellBg = CGRect(x: 36, y: currentY, width: contentWidth, height: 20)
        UIColor(Color.appCard).withAlphaComponent(0.5).setFill()
        context.fill(cellBg)
        
        for (idx, col) in cols.enumerated() {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9.5), // Dynamic Type
                .foregroundColor: UIColor.darkGray
            ]
            let cellRect = CGRect(x: 36 + CGFloat(idx) * colWidth + 4, y: currentY + 3, width: colWidth - 8, height: 16)
            col.draw(in: cellRect, withAttributes: attrs)
        }
        return currentY + 22
    }

    private static func renderParagraph(_ text: String, currentY: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var lineText = sanitizeMarkdownText(text)
        if lineText.hasPrefix("- ") || lineText.hasPrefix("* ") {
            lineText = "• " + lineText.dropFirst(2)
        }
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10.5), // Dynamic Type
            .foregroundColor: UIColor(white: 0.2, alpha: 1.0),
            .paragraphStyle: paragraph
        ]
        
        let rect = CGRect(x: 36, y: currentY, width: contentWidth, height: 40)
        let boundingRect = (lineText as NSString).boundingRect(
            with: CGSize(width: contentWidth, height: 100),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        
        lineText.draw(in: rect, withAttributes: attrs)
        return currentY + max(16, ceil(boundingRect.height) + 4)
    }

    private static func renderFooter(pageHeight: CGFloat) {
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9), // Dynamic Type
            .foregroundColor: UIColor.lightGray
        ]
        let footerText = L10n.Ingest.fileImport
        footerText.draw(at: CGPoint(x: 36, y: pageHeight - 30), withAttributes: footerAttributes)
    }

    /// 清理裸 Markdown 规则符号，转义为清晰的干净文本
    private static func sanitizeMarkdownText(_ text: String) -> String {
        var clean = text
        clean = clean.replacingOccurrences(of: "**", with: "")
        clean = clean.replacingOccurrences(of: "[[", with: "「")
        clean = clean.replacingOccurrences(of: "]]", with: "」")
        clean = clean.replacingOccurrences(of: "`", with: "")
        return clean.trimmingCharacters(in: .whitespaces)
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let cleaned = line.replacingOccurrences(of: " ", with: "")
        return cleaned.hasPrefix("|:") || cleaned.hasPrefix("|-") || (cleaned.contains("---") && cleaned.contains("|"))
    }
}
#endif
