//
//  iOSMermaidWebView.swift
//  ZhiYu
//
//  系统层级：[L1] 平台适配层
//  核心职责：iOS 平台 Mermaid 图表 WKWebView 容器（UIViewRepresentable）与缩放控制，
//           由 Shared/UIComponents/Editors/MermaidWebView.swift 统一外观调用，消除共享层平台宏。
//

#if os(iOS)
import SwiftUI
import WebKit

/// Mermaid 缩放参数（iOS）
private enum MermaidZoomSpec {
    static let maximumZoomScale: CGFloat = 5.0
    static let minimumZoomScale: CGFloat = 1.0
    static let resetZoomScale: CGFloat = 1.0
    static let theme = "neutral"
    static let bodyExtraStyle = " width: 100vw;"
}

/// iOS 平台 Mermaid 渲染容器
struct MermaidPlatformWebView: UIViewRepresentable {
    let mermaidCode: String
    @Binding var webView: WKWebView?

    /// 创建 UIView
    /// - Parameter context: context
    /// - Returns: WKWebView
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.maximumZoomScale = MermaidZoomSpec.maximumZoomScale
        webView.scrollView.minimumZoomScale = MermaidZoomSpec.minimumZoomScale
        DispatchQueue.main.async {
            self.webView = webView
        }
        return webView
    }

    /// 更新 UIView
    /// - Parameter uiView: uiView
    /// - Parameter context: context
    func updateUIView(_ uiView: WKWebView, context: Context) {
        let html = generateMermaidHTML(
            mermaidCode: mermaidCode,
            theme: MermaidZoomSpec.theme,
            viewportMeta: true,
            bodyExtraStyle: MermaidZoomSpec.bodyExtraStyle
        )
        uiView.loadHTMLString(html, baseURL: Bundle.main.bundleURL)
    }

    /// 按比例缩放（受 min/max 约束）
    static func zoom(_ webView: WKWebView?, by factor: CGFloat) {
        guard let webView else { return }
        let scrollView = webView.scrollView
        let newScale = min(max(scrollView.zoomScale * factor, scrollView.minimumZoomScale), scrollView.maximumZoomScale)
        scrollView.setZoomScale(newScale, animated: true)
    }

    /// 重置缩放
    static func resetZoom(_ webView: WKWebView?) {
        webView?.scrollView.setZoomScale(MermaidZoomSpec.resetZoomScale, animated: true)
    }
}
#endif
