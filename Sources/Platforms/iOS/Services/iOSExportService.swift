//
//  iOSExportService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：实现 iOSExport 模块的核心业务逻辑服务。
//
#if canImport(WebKit)
import Foundation
import WebKit

/// iOS 导出服务实现
@MainActor
final class iOSExportService: NSObject, ExportServiceProtocol, @unchecked Sendable {
    private var webView: WKWebView?
    private var isExporting = false
    
    override init() {
        super.init()
        setupWebView()
    }
    
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 1000), configuration: config)
        webView?.navigationDelegate = self
        
        // 读取本地 JS 内容
        let pptxJS = loadLocalJS(named: "pptxgen.bundle")
        let markedJS = loadLocalJS(named: "marked.min")
        let mermaidJS = loadLocalJS(named: "mermaid.min")
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <script>\(pptxJS)</script>
            <script>\(markedJS)</script>
            <script>\(mermaidJS)</script>
            <style>
                body { font-family: -apple-system, sans-serif; padding: 40px; color: #333; line-height: 1.6; background-color: white; }
                h1 { color: #222; text-align: center; margin-bottom: 40px; padding-bottom: 10px; }
                pre { background: #f6f8fa; padding: 16px; border-radius: 8px; white-space: pre-wrap; word-break: break-all; }
                code { font-family: ui-monospace, monospace; }
                blockquote { border-left: 4px solid #dfe2e5; color: #6a737d; padding-left: 16px; margin-left: 0; }
                table { border-collapse: collapse; width: 100%; margin: 16px 0; }
                th, td { border: 1px solid #dfe2e5; padding: 8px 12px; }
                th { background-color: #f6f8fa; }
                #mermaid-root { width: 100%; display: flex; justify-content: center; }
                img { max-width: 100%; height: auto; }
            </style>
        </head>
        <body>
            <div id="content"></div>
            <div id="mermaid-root"></div>
        </body>
        </html>
        """
        webView?.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
    }

    private func loadLocalJS(named name: String) -> String {
        if let url = Bundle.main.url(forResource: name, withExtension: "js"),
           let content = try? String(contentsOf: url) {
            return content
        }
        return "// JS Library \(name) not found in Bundle"
    }
    
    /// 导出ToPDF
    /// - Parameter markdown: markdown
    /// - Parameter fileName: fileName
    /// - Returns: 链接
    func exportToPDF(markdown: String, fileName: String) async throws -> URL {
        if isExporting {
            try? await Task.sleep(for: .milliseconds(500))
            if isExporting { throw ExportError.systemBusy }
        }
        
        isExporting = true
        defer { 
            isExporting = false
            Task { @MainActor in
                _ = try? await webView?.evaluateJavaScript("document.body.innerHTML = '';")
            }
        }

        guard let webView = webView else { throw ExportError.engineNotReady }
        
        let escapedMarkdown = markdown.replacingOccurrences(of: "\\", with: "\\\\")
                                      .replacingOccurrences(of: "`", with: "\\`")
                                      .replacingOccurrences(of: "$", with: "\\$")
        
        let js = """
        (async () => {
            const root = document.getElementById('mermaid-root');
            if (root) root.innerHTML = '';
            const content = document.getElementById('content');
            if (content) content.innerHTML = marked.parse(`\(escapedMarkdown)`);
            
            await new Promise(r => {
                if (document.readyState === 'complete') r();
                else window.addEventListener('load', r);
                setTimeout(r, 800);
            });
            return true;
        })();
        """
        _ = try await webView.evaluateJavaScript(js)
        
        return try await createPDF(fileName: fileName)
    }

    /// 导出MindmapToPDF
    /// - Parameter mermaidCode: mermaidCode
    /// - Parameter fileName: fileName
    /// - Returns: 链接
    func exportMindmapToPDF(mermaidCode: String, fileName: String) async throws -> URL {
        if isExporting {
            try? await Task.sleep(for: .milliseconds(500))
            if isExporting { throw ExportError.systemBusy }
        }
        
        isExporting = true
        defer { 
            isExporting = false 
            Task { @MainActor in
                _ = try? await webView?.evaluateJavaScript("document.body.innerHTML = '';")
            }
        }

        guard let webView = webView else { throw ExportError.engineNotReady }
        
        let escapedCode = mermaidCode.replacingOccurrences(of: "\\", with: "\\\\")
                                     .replacingOccurrences(of: "`", with: "\\`")
                                     .replacingOccurrences(of: "$", with: "\\$")
        
        let js = """
        (async () => {
            const content = document.getElementById('content');
            if (content) content.innerHTML = '';
            const root = document.getElementById('mermaid-root');
            if (!root) return false;
            
            mermaid.initialize({ startOnLoad: false, theme: 'neutral', securityLevel: 'loose', mindmap: { useMaxWidth: true } });
            try {
                const { svg } = await mermaid.render('mindmap-export', `\(escapedCode)`);
                root.innerHTML = svg;
            } catch (e) {
                root.innerHTML = '<div style="color:red">' + e.message + '</div>';
            }
            await new Promise(r => setTimeout(r, 800));
            return true;
        })();
        """
        _ = try await webView.evaluateJavaScript(js)
        
        return try await createPDF(fileName: fileName)
    }

    private func createPDF(fileName: String) async throws -> URL {
        guard let webView = webView else { throw ExportError.engineNotReady }
        
        return try await withCheckedThrowingContinuation { continuation in
            let config = WKPDFConfiguration()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                webView.createPDF(configuration: config) { result in
                    switch result {
                    case .success(let data):
                        guard Int64(data.count) >= AppConstants.ExportLimits.minValidPDFBytes else {
                            continuation.resume(throwing: ExportError.internalError("PDF_Content_Empty"))
                            return
                        }
                        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).pdf")
                        do {
                            try data.write(to: url)
                            continuation.resume(returning: url)
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    /// 导出ToPPTX
    /// - Parameter markdown: markdown
    /// - Parameter fileName: fileName
    /// - Returns: 链接
    func exportToPPTX(markdown: String, fileName: String) async throws -> URL {
        if isExporting {
            try? await Task.sleep(for: .milliseconds(500))
            if isExporting { throw ExportError.systemBusy }
        }
        isExporting = true
        defer { isExporting = false }

        guard let webView = webView else { throw ExportError.engineNotReady }
        
        let slides = parseMarkdownForSlides(markdown)
        let slidesJSON = try JSONEncoder().encode(slides)
        let slidesJSString = String(data: slidesJSON, encoding: .utf8) ?? "[]"
        
        let js = """
        (async () => {
            const pptx = new PptxGenJS();
            pptx.title = "\(fileName)";
            pptx.layout = 'LAYOUT_16x9';
            
            const slidesData = \(slidesJSString);
            
            slidesData.forEach(data => {
                let slide = pptx.addSlide();
                slide.background = { fill: 'F5F7FA' };
                
                slide.addText(data.title, { 
                    x: 0.5, y: 0.5, w: '90%', h: 1, 
                    fontSize: 36, bold: true, color: '2D3436',
                    fontFace: 'Arial', align: 'center'
                });
                
                if (data.bullets && data.bullets.length > 0) {
                    slide.addText(data.bullets.map(b => ({ text: b, options: { bullet: true, indentLevel: 0, breakLine: true } })), { 
                        x: 1.0, y: 1.8, w: '80%', h: 3.5, 
                        fontSize: 20, color: '636E72', valign: 'top',
                        lineSpacing: 28
                    });
                }
                
                ""
            });
            
            const base64 = await pptx.write('base64');
            return base64;
        })();
        """
        
        guard let base64String = try await webView.evaluateJavaScript(js) as? String,
              let data = Data(base64Encoded: base64String) else {
            throw ExportError.internalError("PPTX_Failed")
        }
        
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(fileName).pptx")
        try data.write(to: url)
        return url
    }
    
    private struct SlideData: Codable {
        let title: String
        let bullets: [String]
    }
    
    private func parseMarkdownForSlides(_ markdown: String) -> [SlideData] {
        var slides: [SlideData] = []
        let parts = markdown.components(separatedBy: "\n## ")
        for part in parts {
            let lines = part.components(separatedBy: .newlines)
            let title = lines.first?.replacingOccurrences(of: "# ", with: "").trimmingCharacters(in: .whitespaces) ?? ""
            let bullets = lines.dropFirst().filter { 
                let trimmed = $0.trimmingCharacters(in: .whitespaces)
                return trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") 
            }.map { 
                $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "- ", with: "").replacingOccurrences(of: "* ", with: "") 
            }
            slides.append(SlideData(title: title, bullets: bullets))
        }
        return slides
    }
}

extension iOSExportService: WKNavigationDelegate {

    /// webView回调
    /// - Parameter webView: webView
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Logger.shared.error("Export_Failed", error: error)
    }
}
#endif
