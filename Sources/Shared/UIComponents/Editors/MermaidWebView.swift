//
//  MermaidWebView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：构建 MermaidWeb 界面的 UI 视图层组件。
//
import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

@MainActor
/// Mermaid 图表渲染视图
/// 负责在 WebKit 容器中加载 Mermaid.js 并渲染流程图、甘特图等知识图谱扩展内容
struct MermaidWebView: View {
    let mermaidCode: String
    #if canImport(WebKit)
    @State private var webView: WKWebView?
    #endif
    @State private var showExportSheet = false
    @State private var identifiablePDFURL: IdentifiableURL?

    var body: some View {
        #if canImport(WebKit)
        ZStack(alignment: .bottomTrailing) {
            #if os(macOS)
            MermaidWKWebViewMac(mermaidCode: mermaidCode, webView: $webView)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
            #else
            MermaidWKWebView(mermaidCode: mermaidCode, webView: $webView)
                .background(Color.appCard)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
            #endif
            
            // Zoom Controls (统一图谱风格：合拢式排列)
            HStack(spacing: 0) {
                zoomButton(icon: DesignSystem.Icons.minusMagnifyingglass) { zoom(by: 0.8) }
                zoomButton(icon: DesignSystem.Icons.plusMagnifyingglass) { zoom(by: 1.2) }
                
                Divider()
                    .frame(width: DesignSystem.Metrics.dividerThickness, height: DesignSystem.IconSize.small)
                    .background(Color.appBorder.opacity(DesignSystem.Opacity.soft))
                
                zoomButton(icon: DesignSystem.Icons.refresh) { resetZoom() }
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.smallRadius)
                    .stroke(Color.appBorder.opacity(DesignSystem.Opacity.soft), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(DesignSystem.Opacity.light), radius: 8, x: 0, y: 4)
            .padding(DesignSystem.Layout.cardContentPadding)
        }
        .frame(minHeight: 400)
        .sheet(item: $identifiablePDFURL) { identifiable in
            #if os(iOS)
            ActivityView(activityItems: [identifiable.url])
            #endif
        }
        #else
        VStack {
            Image(systemName: DesignSystem.Icons.chartBarDoc)
                .font(.largeTitle)
            Text(L10n.AI.Synthesis.Mindmap.renderError)
            Text(L10n.Common.demo)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
        #endif
    }

    private func zoomButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            HapticFeedback.shared.trigger(.selection)
            action()
        }) {
            Image(systemName: icon)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.appText)
                // swiftlint:disable:next magic_numbers_frame
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(ScaleButtonStyle()) // 使用统一的缩放反馈样式
    }

    private func zoom(by factor: CGFloat) {
        #if os(iOS)
        guard let webView = webView else { return }
        let currentScale = webView.scrollView.zoomScale
        let newScale = min(max(currentScale * factor, webView.scrollView.minimumZoomScale), webView.scrollView.maximumZoomScale)
        webView.scrollView.setZoomScale(newScale, animated: true)
        #endif
    }

    private func resetZoom() {
        #if os(iOS)
        webView?.scrollView.setZoomScale(1.0, animated: true)
        #endif
    }

    private func exportToPDF() {
        #if canImport(WebKit) && os(iOS)
        guard let webView = webView else { return }
        
        let config = WKPDFConfiguration()
        webView.createPDF(configuration: config) { result in
            switch result {
            case .success(let data):
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(L10n.AI.Synthesis.Mindmap.title).pdf")
                try? data.write(to: tempURL)
                self.identifiablePDFURL = IdentifiableURL(url: tempURL)
            case .failure(let error):
                ToastManager.shared.show(type: .error, message: error.localizedDescription)
            }
        }
        #endif
    }
}

#if canImport(WebKit)
#if os(iOS)
struct MermaidWKWebView: UIViewRepresentable {
    let mermaidCode: String
    @Binding var webView: WKWebView?
    
    /// 创建UIView
    /// - Parameter context: context
    /// - Returns: 返回值
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.maximumZoomScale = 5.0
        webView.scrollView.minimumZoomScale = 1.0
        DispatchQueue.main.async {
            self.webView = webView
        }
        return webView
    }
    
    /// 更新UIView
    /// - Parameter uiView: uiView
    /// - Parameter context: context
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(generateHTML(), baseURL: Bundle.main.bundleURL)
    }
    
    private func generateHTML() -> String {
        let escapedCode = mermaidCode
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes">
            <script src="mermaid.min.js"></script>
            <style>
                body { background-color: transparent; margin: 0; display: flex; justify-content: center; align-items: flex-start; min-height: 100vh; width: 100vw; font-family: -apple-system; }
                #mermaid-root { background-color: transparent; width: 100%; height: 100%; padding: 20px; box-sizing: border-box; }
                svg { max-width: 100% !important; height: auto !important; }
                .error-container { color: #ff453a; text-align: center; padding: 40px 20px; font-size: 14px; background: rgba(255,69,58,0.1); border-radius: 12px; margin: 20px; border: 1px solid rgba(255,69,58,0.2); }
                .error-details { font-family: monospace; font-size: 11px; margin-top: 12px; opacity: 0.7; word-break: break-all; text-align: left; }
            </style>
        </head>
        <body>
            <div id="mermaid-root"></div>
            <script>
                mermaid.initialize({
                    startOnLoad: false,
                    theme: 'neutral',
                    securityLevel: 'loose',
                    mindmap: { useMaxWidth: true }
                });
                (async () => {
                    const root = document.getElementById('mermaid-root');
                    try {
                        const { svg } = await mermaid.render('mindmap-svg', `\(escapedCode)`);
                        root.innerHTML = svg;
                    } catch (e) {
                        root.innerHTML = `
                            <div class="error-container">
                                <div>\(L10n.AI.Synthesis.Mindmap.renderError)</div>
                                <div class="error-details">${e.message || e}</div>
                            </div>
                        `;
                    }
                })();
            </script>
        </body>
        </html>
        """
    }
}

struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    /// 创建UIViewController
    /// - Parameter context: context
    /// - Returns: 返回值
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    /// 更新UIViewController
    /// - Parameter uiViewController: uiViewController
    /// - Parameter context: context
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#elseif os(macOS)
struct MermaidWKWebViewMac: NSViewRepresentable {
    let mermaidCode: String
    @Binding var webView: WKWebView?
    
    /// 创建NSView
    /// - Parameter context: context
    /// - Returns: 返回值
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        DispatchQueue.main.async {
            self.webView = webView
        }
        return webView
    }
    
    /// 更新NSView
    /// - Parameter nsView: nsView
    /// - Parameter context: context
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(generateHTML(), baseURL: Bundle.main.bundleURL)
    }
    
    private func generateHTML() -> String {
        let escapedCode = mermaidCode
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "")

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <script src="mermaid.min.js"></script>
            <style>
                body { background-color: transparent; margin: 0; display: flex; justify-content: center; align-items: flex-start; min-height: 100vh; font-family: -apple-system; color: white; }
                #mermaid-root { background-color: transparent; width: 100%; padding: 20px; box-sizing: border-box; }
                svg { max-width: 100% !important; height: auto !important; }
                .error-container { color: #ff453a; text-align: center; padding: 40px 20px; font-size: 14px; background: rgba(255,69,58,0.1); border-radius: 12px; margin: 20px; border: 1px solid rgba(255,69,58,0.2); }
                .error-details { font-family: monospace; font-size: 11px; margin-top: 12px; opacity: 0.7; word-break: break-all; text-align: left; }
            </style>
        </head>
        <body>
            <div id="mermaid-root"></div>
            <script>
                mermaid.initialize({
                    startOnLoad: false,
                    theme: 'dark',
                    securityLevel: 'loose',
                    mindmap: { useMaxWidth: true }
                });
                (async () => {
                    const root = document.getElementById('mermaid-root');
                    try {
                        const { svg } = await mermaid.render('mindmap-svg', `\(escapedCode)`);
                        root.innerHTML = svg;
                    } catch (e) {
                        const rawCode = `\(escapedCode)`;
                        const lines = rawCode.split('\\n').filter(l => l.trim() && !l.trim().startsWith('```'));
                        let listHtml = '<div style="padding:20px; color:#e0e0e0; font-family:sans-serif;">';
                        lines.forEach(line => {
                            const trimmed = line.trim();
                            if (trimmed.startsWith('#')) {
                                listHtml += `<h3 style="color:#0A84FF;margin-top:16px;">${trimmed.replace(/^#+\\s*/, '')}</h3>`;
                            } else {
                                listHtml += `<div style="padding-left:16px;margin-vertical:4px;border-left:2px solid #0A84FF;">• ${trimmed}</div>`;
                            }
                        });
                        listHtml += '</div>';
                        root.innerHTML = listHtml;
                    }
                })();
            </script>
        </body>
        </html>
        """
    }
}
#endif
#endif
