//
//  MacMermaidWebView.swift
//  ZhiYu
//
//  系统层级：[L1] 平台适配层
//  核心职责：macOS 平台 Mermaid 图表 WKWebView 容器（NSViewRepresentable），
//           由 Shared/UIComponents/Editors/MermaidWebView.swift 统一外观调用，消除共享层平台宏。
//

#if os(macOS)
import SwiftUI
import WebKit

/// Mermaid 渲染参数（macOS）
private enum MermaidMacSpec {
    static let drawsBackgroundKey = "drawsBackground"
    static let theme = "dark"
    static let fallbackBulletPrefix = "• "
    static let resetPageZoom: CGFloat = 1.0
}

/// macOS 平台 Mermaid 渲染容器
struct MermaidPlatformWebView: NSViewRepresentable {
    let mermaidCode: String
    @Binding var webView: WKWebView?

    /// 创建 NSView
    /// - Parameter context: context
    /// - Returns: WKWebView
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: MermaidMacSpec.drawsBackgroundKey)
        DispatchQueue.main.async {
            self.webView = webView
        }
        return webView
    }

    /// 更新 NSView
    /// - Parameter nsView: nsView
    /// - Parameter context: context
    func updateNSView(_ nsView: WKWebView, context: Context) {
        let html = generateMermaidHTML(
            mermaidCode: mermaidCode,
            theme: MermaidMacSpec.theme,
            fallbackBulletPrefix: MermaidMacSpec.fallbackBulletPrefix
        )
        nsView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
    }

    /// 按比例缩放（macOS 使用 WKWebView.pageZoom 实现，与 iOS scrollView 缩放保持统一调用面）
    static func zoom(_ webView: WKWebView?, by factor: CGFloat) {
        guard let webView else { return }
        webView.pageZoom *= factor
    }

    /// 重置缩放
    static func resetZoom(_ webView: WKWebView?) {
        webView?.pageZoom = MermaidMacSpec.resetPageZoom
    }
}
#endif
