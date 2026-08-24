//
//  OCRScanView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：构建 OCRScan 界面的 UI 视图层组件。
//
import SwiftUI
import PhotosUI

// MARK: - OCR Scanner View
@MainActor
struct OCRScanView: View {
    @Environment(IngestStore.self) var ingestStore
    @Environment(\.interfaceIdiom) private var idiom
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: AppImage?
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var showResult = false
    @State private var targetTitle = ""
    @State private var targetType: PageType = .source
    @State private var targetCustomIcon: String?
    @State private var targetTags: [String] = ["OCR", L10n.Ingest.OCR.scanTag]
    @State private var showIconPicker = false
    @State private var showOCRError = false
    @State private var ocrErrorMessage = ""
    @State private var showAddTagInput = false
    @State private var newTagText = ""
    @State private var recognitionTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    var onFinish: ((String, String, Data?) -> Void)?
    
    var body: some View {
        if idiom == .watch {
            WatchFeaturePlaceholderView(placeholderMessage: L10n.Watch.ocrScanPlaceholder)
        } else {
            NavigationStack {
                ScrollView {
                    VStack(spacing: DesignSystem.giant) {
                        // Image picker area
                        OCRImagePickerArea(
                            selectedImage: selectedImage,
                            isProcessing: isProcessing,
                            selectedPhoto: selectedPhoto,
                            onPhotoSelected: { loadImage(from: $0) },
                            onStartRecognition: startRecognition
                        )

                        // Recognized text
                        if !recognizedText.isEmpty {
                            OCRResultDisplay(
                                recognizedText: $recognizedText,
                                onCopy: copyToClipboard
                            )
                        }

                        // Save to 知识库 (Now just finishes and returns data)
                        if !recognizedText.isEmpty {
                            Button(action: {
                                let imageData = selectedImage?.jpegData(compressionQuality: 0.9)
                                onFinish?(targetTitle, recognizedText, imageData)
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: DesignSystem.Icons.squareAndPencil)
                                    Text(L10n.Ingest.OCR.confirmAndEdit)
                                }
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.appAccent)
                                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius))
                            }
                            .padding(.top, SystemSpacing.tight)
                        }
                    }
                    .padding()
                }
                .scrollContentBackground(.hidden)
                .background(PageBackgroundView(accentColor: .appAccent))
                .navigationTitle(L10n.Ingest.OCR.title)
                .appNavigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.Common.done) {
                            dismiss()
                        }
                    }
                }
                .onChange(of: selectedPhoto) { _, newValue in
                    loadImage(from: newValue)
                }
                .sheet(isPresented: $showIconPicker) {
                    IconPickerView(selectedIcon: $targetCustomIcon)
                }
                .alert(L10n.Ingest.OCR.scanFailed, isPresented: $showOCRError) {
                    Button(L10n.Common.ok, role: .cancel) {}
                } message: {
                    Text(ocrErrorMessage)
                }
                .alert(L10n.Editor.addTag, isPresented: $showAddTagInput) {
                    TextField(L10n.Editor.enterTag, text: $newTagText)
                        .accessibilityIdentifier("enterTagName")
                    Button(L10n.Ingest.OCR.addTag) {
                        commitNewTag()
                    }
                    Button(L10n.Common.cancel, role: .cancel) {
                        newTagText = ""
                    }
                } message: {
                    Text(L10n.Editor.enterTag)
                }
            }
        }
    }
    
    // MARK: - Actions
    private func loadImage(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = AppImage(data: data) {
                selectedImage = image
            }
        }
    }
    
    private func startRecognition() {
        guard let image = selectedImage else { return }
        isProcessing = true
        recognitionTask?.cancel()

        recognitionTask = Task {
            do {
                let text = try await ingestStore.recognizeText(from: image)
                try Task.checkCancellation()
                await MainActor.run {
                    recognizedText = text
                    isProcessing = false
                    if targetTitle.isEmpty {
                        targetTitle = String(text.prefix(20)).trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }
            } catch is CancellationError {
                await MainActor.run { isProcessing = false }
            } catch {
                await MainActor.run {
                    ocrErrorMessage = error.localizedDescription
                    showOCRError = true
                    isProcessing = false
                }
            }
        }
    }
    
    private func copyToClipboard() {
        AppPasteboard.string = recognizedText
    }

    private func commitNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !targetTags.contains(trimmed) {
            targetTags.append(trimmed)
        }
        newTagText = ""
    }
}
