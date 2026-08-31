//
//  MarkdownEditorView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：构建 MarkdownEditor 界面的 UI 视图层组件。
//
import SwiftUI
import PhotosUI

/// Markdown 编辑器核心视图
struct MarkdownEditorView: View {
    @Binding var text: String
    let placeholder: String
    
    /// 可选依赖：IngestStore 缺失时禁用 OCR 按钮，避免组件崩溃
    @Environment(IngestStore.self) private var ingestStore: IngestStore?
    
    @State private var showOCRScanner = false
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, DesignSystem.tiny)
                    .padding(.vertical, DesignSystem.small)
            }
            
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color.clear)
        }
        .modifier(OCRPickerModifier(ingestStore: ingestStore, isPresented: $showOCRScanner) { recognizedText in
            if !recognizedText.isEmpty {
                text += "\n\(recognizedText)"
            }
        })
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button(action: { showOCRScanner = true }) {
                    Label(L10n.Ingest.ocr.title, systemImage: DesignSystem.Icons.ocr)
                }
                .disabled(ingestStore == nil)
                
                Button(action: { text += "****" }) {
                    Image(systemName: DesignSystem.Icons.bold)
                }
                
                Button(action: { text += "**" }) {
                    Image(systemName: DesignSystem.Icons.italic)
                }
                
                Button(action: { text += "[[]]" }) {
                    Image(systemName: DesignSystem.Icons.link)
                }
            }
        }
    }
}

// MARK: - OCR 辅助
@MainActor
struct OCRPickerModifier: ViewModifier {
    /// 可选依赖：由父视图传入，nil 时跳过 OCR 调用
    let ingestStore: IngestStore?
    @Binding var isPresented: Bool
    let onResult: (String) -> Void
    #if !os(watchOS)
    @State private var selectedItem: PhotosPickerItem?
    #endif

    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    func body(content: Content) -> some View {
        content
            #if !os(watchOS)
            .photosPicker(isPresented: $isPresented, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { _, newValue in
                guard let newItem = newValue else { return }
                guard let ingestStore else {
                    // IngestStore 缺失时清理选择项，不执行 OCR
                    selectedItem = nil
                    return
                }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self),
                       let image = AppImage(data: data) {
                        do {
                            let text = try await ingestStore.recognizeText(from: image)
                            onResult(text)
                        } catch {
                            // 错误处理通常由 UI 层展示 Toast
                            Logger.shared.error("OCR_Failed", error: error)
                        }
                    }
                    selectedItem = nil
                }
            }
            #endif
    }
}
