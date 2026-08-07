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

#if canImport(UIKit) && canImport(PDFKit) && !os(watchOS)
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

    private enum PDFTheme {
        static let headerBg = UIColor(displayP3Red: 0.11, green: 0.16, blue: 0.27, alpha: 1.0)
        static let h1Text = UIColor(displayP3Red: 0.06, green: 0.09, blue: 0.16, alpha: 1.0)
        static let h2Text = UIColor(displayP3Red: 0.14, green: 0.38, blue: 0.92, alpha: 1.0)
        static let quoteText = UIColor(displayP3Red: 0.20, green: 0.25, blue: 0.33, alpha: 1.0)
        static let quoteBg = UIColor(displayP3Red: 0.94, green: 0.96, blue: 0.98, alpha: 1.0)
        static let quoteLine = UIColor(displayP3Red: 0.14, green: 0.38, blue: 0.92, alpha: 1.0)
        static let tableHeaderBg = UIColor(displayP3Red: 0.88, green: 0.91, blue: 0.94, alpha: 1.0)
        static let tableCellBg = UIColor(displayP3Red: 0.97, green: 0.98, blue: 0.99, alpha: 1.0)
        static let tableHeaderText = UIColor(displayP3Red: 0.06, green: 0.09, blue: 0.16, alpha: 1.0)
        static let tableCellText = UIColor(displayP3Red: 0.12, green: 0.16, blue: 0.23, alpha: 1.0)
        static let tableBorder = UIColor(displayP3Red: 0.80, green: 0.84, blue: 0.88, alpha: 1.0)
        static let headerText = UIColor(displayP3Red: 1.0, green: 1.0, blue: 1.0, alpha: 1.0)
        static let bodyText = UIColor(displayP3Red: 0.12, green: 0.16, blue: 0.23, alpha: 1.0)
        static let footerText = UIColor(displayP3Red: 0.39, green: 0.45, blue: 0.55, alpha: 1.0)
    }

    private static func renderHeader(title: String, pageWidth: CGFloat, context: UIGraphicsPDFRendererContext) {
        let headerRect = CGRect(x: 0, y: 0, width: pageWidth, height: 72)
        PDFTheme.headerBg.setFill()
        context.fill(headerRect)
        
        let headerTitleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: PDFTheme.headerText
        ]
        let cleanTitle = sanitizeMarkdownText(title)
        let headerTitle = "📄 \(cleanTitle)"
        headerTitle.draw(at: CGPoint(x: 36, y: 24), withAttributes: headerTitleAttributes)
    }

    private static func renderBodyLines(content: String, pageWidth: CGFloat, pageHeight: CGFloat, context: UIGraphicsPDFRendererContext) {
        var currentY: CGFloat = 92
        let contentWidth = pageWidth - 72
        let lines = content.components(separatedBy: "\n")
        
        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                currentY += 8
                continue
            }
            if isTableSeparator(trimmed) { continue }
            
            if trimmed.hasPrefix(StorageConstants.MarkdownSyntax.hashSpace) {
                currentY = renderH1(trimmed, currentY: currentY, contentWidth: contentWidth)
            } else if trimmed.hasPrefix(StorageConstants.MarkdownSyntax.hashHashSpace) {
                currentY = renderH2(trimmed, currentY: currentY, contentWidth: contentWidth)
            } else if trimmed.hasPrefix(StorageConstants.MarkdownSyntax.blockquoteSpace) {
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
        let h1Text = sanitizeMarkdownText(text.replacingOccurrences(of: StorageConstants.MarkdownSyntax.hashSpace, with: ""))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 17),
            .foregroundColor: PDFTheme.h1Text
        ]
        let rect = CGRect(x: 36, y: currentY + 8, width: contentWidth, height: 26)
        h1Text.draw(in: rect, withAttributes: attrs)
        return currentY + 36
    }

    private static func renderH2(_ text: String, currentY: CGFloat, contentWidth: CGFloat) -> CGFloat {
        let h2Text = sanitizeMarkdownText(text.replacingOccurrences(of: StorageConstants.MarkdownSyntax.hashHashSpace, with: ""))
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: PDFTheme.h2Text
        ]
        let rect = CGRect(x: 36, y: currentY + 6, width: contentWidth, height: 22)
        h2Text.draw(in: rect, withAttributes: attrs)
        return currentY + 30
    }

    private static func renderQuoteBlock(_ text: String, currentY: CGFloat, contentWidth: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let quoteText = sanitizeMarkdownText(text.replacingOccurrences(of: StorageConstants.MarkdownSyntax.blockquoteSpace, with: ""))
        let font = UIFont.systemFont(ofSize: 11) // Dynamic Type
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 4
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: PDFTheme.quoteText,
            .paragraphStyle: paragraph
        ]
        
        let bgRect = CGRect(x: 36, y: currentY, width: contentWidth, height: 32)
        PDFTheme.quoteBg.setFill()
        context.fill(bgRect)
        
        let lineRect = CGRect(x: 36, y: currentY, width: 4, height: 32)
        PDFTheme.quoteLine.setFill()
        context.fill(lineRect)
        
        let textRect = CGRect(x: 48, y: currentY + 6, width: contentWidth - 20, height: 22)
        quoteText.draw(in: textRect, withAttributes: attrs)
        return currentY + 38
    }

    private static func renderTableRow(_ text: String, currentY: CGFloat, contentWidth: CGFloat, context: UIGraphicsPDFRendererContext) -> CGFloat {
        let cols = text.split(separator: "|").map { sanitizeMarkdownText(String($0)) }
        let colWidth = contentWidth / CGFloat(max(1, cols.count))
        
        let isHeader = currentY < 140
        let cellBgColor = isHeader ? PDFTheme.tableHeaderBg : PDFTheme.tableCellBg
        let textColor = isHeader ? PDFTheme.tableHeaderText : PDFTheme.tableCellText
        let font = isHeader ? UIFont.boldSystemFont(ofSize: 10) : UIFont.systemFont(ofSize: 10) // Dynamic Type
        
        let cellBg = CGRect(x: 36, y: currentY, width: contentWidth, height: 22)
        cellBgColor.setFill()
        context.fill(cellBg)
        
        // 绘制表框细线
        context.cgContext.setLineWidth(0.5)
        context.cgContext.setStrokeColor(PDFTheme.tableBorder.cgColor)
        context.cgContext.stroke(cellBg)
        
        for (idx, col) in cols.enumerated() {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: textColor
            ]
            let cellRect = CGRect(x: 36 + CGFloat(idx) * colWidth + 6, y: currentY + 4, width: colWidth - 12, height: 16)
            col.draw(in: cellRect, withAttributes: attrs)
        }
        return currentY + 24
    }

    private static func renderParagraph(_ text: String, currentY: CGFloat, contentWidth: CGFloat) -> CGFloat {
        var lineText = sanitizeMarkdownText(text)
        if lineText.hasPrefix(StorageConstants.MarkdownSyntax.dashSpace) || lineText.hasPrefix(StorageConstants.MarkdownSyntax.asteriskSpace) {
            lineText = "• " + lineText.dropFirst(2)
        }
        
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11), // Dynamic Type
            .foregroundColor: PDFTheme.bodyText,
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
        return currentY + max(18, ceil(boundingRect.height) + 4)
    }

    private static func renderFooter(pageHeight: CGFloat) {
        let footerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9), // Dynamic Type
            .foregroundColor: PDFTheme.footerText
        ]
        let footerText = L10n.Ingest.fileImport
        footerText.draw(at: CGPoint(x: 36, y: pageHeight - 30), withAttributes: footerAttributes)
    }

    /// 清理裸 Markdown 规则符号，转义为清晰的干净文本
    static func sanitizeMarkdownText(_ text: String) -> String {
        var clean = text
        clean = clean.replacingOccurrences(of: StorageConstants.MarkdownSyntax.bold, with: "")
        clean = clean.replacingOccurrences(of: StorageConstants.MarkdownSyntax.wikilinkOpen, with: "「")
        clean = clean.replacingOccurrences(of: StorageConstants.MarkdownSyntax.wikilinkClose, with: "」")
        clean = clean.replacingOccurrences(of: "`", with: "")
        return clean.trimmingCharacters(in: .whitespaces)
    }

    static func isTableSeparator(_ line: String) -> Bool {
        let cleaned = line.replacingOccurrences(of: " ", with: "")
        return cleaned.hasPrefix(StorageConstants.MarkdownSyntax.tableSeparator) || cleaned.hasPrefix(StorageConstants.MarkdownSyntax.tableDelimiter) || (cleaned.contains("---") && cleaned.contains("|"))
    }
}
#else
import Foundation

public struct DemoPDFBuilder {
    public static func ensurePDFExists(at path: String, title: String, content: String) -> URL? {
        return nil
    }
}
#endif
