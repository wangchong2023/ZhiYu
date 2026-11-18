//
//  PDFKitRepresentedView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：构建 PDFKitRepresented 界面的 UI 视图层组件（跨平台：iOS 用 UIViewRepresentable，macOS 用 NSViewRepresentable）。
//
#if canImport(PDFKit)
import SwiftUI
import PDFKit

/// PDFKit 包装视图（跨平台）
struct PDFKitRepresentedView: View {
    let document: PDFKit.PDFDocument
    @Binding var currentPage: Int
    var onTextSelected: (String) -> Void

    var body: some View {
        // iOS 用 UIViewRepresentable，macOS 用 NSViewRepresentable
        #if os(iOS)
        IOSPDFKitRepresentedView(
            document: document,
            currentPage: $currentPage,
            onTextSelected: onTextSelected
        )
        #elseif os(macOS)
        MacPDFKitRepresentedView(
            document: document,
            currentPage: $currentPage,
            onTextSelected: onTextSelected
        )
        #else
        EmptyView()
        #endif
    }
}

#if os(iOS)
/// iOS 平台 PDFKit 包装视图（UIViewRepresentable）
private struct IOSPDFKitRepresentedView: UIViewRepresentable {
    let document: PDFKit.PDFDocument
    @Binding var currentPage: Int
    var onTextSelected: (String) -> Void

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor class Coordinator: NSObject {
        var parent: IOSPDFKitRepresentedView

        init(_ parent: IOSPDFKitRepresentedView) {
            self.parent = parent
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let page = pdfView.currentPage,
                  let document = pdfView.document else { return }

            let pageIndex = document.index(for: page)
            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex
            }
        }
    }
}
#elseif os(macOS)
/// macOS 平台 PDFKit 包装视图（NSViewRepresentable）
private struct MacPDFKitRepresentedView: NSViewRepresentable {
    let document: PDFKit.PDFDocument
    @Binding var currentPage: Int
    var onTextSelected: (String) -> Void

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    @MainActor class Coordinator: NSObject {
        var parent: MacPDFKitRepresentedView

        init(_ parent: MacPDFKitRepresentedView) {
            self.parent = parent
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let page = pdfView.currentPage,
                  let document = pdfView.document else { return }

            let pageIndex = document.index(for: page)
            DispatchQueue.main.async {
                self.parent.currentPage = pageIndex
            }
        }
    }
}
#endif
#endif
