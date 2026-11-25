//
//  SynthesisView+Presentations.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层 / AI 合成视图辅助扩展
//  核心职责：承载 SynthesisView 的弹窗与告警（Sheet / Alert / ConfirmationDialog）修饰符，
//           与主视图解耦以遵守单一职责与文件规模规范。
//

import SwiftUI
import Dependencies
import UFPDesignSystem

// MARK: - 辅助扩展：解耦 View Presentations

extension View {

    /// synthesisViewPresentations
    func synthesisViewPresentations(
        showOutput: Binding<Bool>,
        pdfURL: Binding<IdentifiableURL?>,
        showNoPagesAlert: Binding<Bool>,
        showLimitAlert: Binding<Bool>,
        showRenameDialog: Binding<Bool>,
        showLLMAlert: Binding<Bool>,
        showBatchDeleteConfirm: Binding<Bool>,
        showDeleteDocConfirm: Binding<Bool>,
        newDocName: Binding<String>,
        docToRename: SynthesisStore.SynthesisDocument?,
        docToDelete: SynthesisStore.SynthesisDocument?,
        batchDelete: @escaping () -> Void,
        onConfigureAI: @escaping () -> Void,
        synthesisStore: SynthesisStore,
        outputSheet: some View
    ) -> some View {
        self
            .sheet(isPresented: showOutput) {
                outputSheet
                    .appDesktopSheetSize(.large)
            }
            .sheet(item: pdfURL) { identifiable in
                Group {
                    #if canImport(PDFKit)
                    PDFPreviewWrapper(url: identifiable.url)
                    #else
                    Text(identifiable.url.lastPathComponent)
                    #endif
                }
                .appDesktopSheetSize(.large)
            }
            .alertNoPages(isPresented: showNoPagesAlert)
            .alertLimitReached(isPresented: showLimitAlert)
            .alertRenameDoc(isPresented: showRenameDialog, name: newDocName, doc: docToRename)
            .alertLLMNotConfigured(isPresented: showLLMAlert, onConfigure: onConfigureAI)
            .confirmBatchDelete(isPresented: showBatchDeleteConfirm, action: batchDelete)
            .alertDeleteDoc(isPresented: showDeleteDocConfirm, doc: docToDelete, store: synthesisStore)
    }

    /// alertLLMNotConfigured
    /// - Parameter isPresented: isPresented
    func alertLLMNotConfigured(isPresented: Binding<Bool>, onConfigure: @escaping () -> Void) -> some View {
        self.alert(L10n.Common.configureAI, isPresented: isPresented) {
            Button(L10n.Settings.Section.ai) {
                HapticFeedback.shared.trigger(.selection)
                onConfigure()
            }
            Button(L10n.Common.cancel, role: .cancel) { }
        } message: {
            Text(L10n.Common.configureAI)
        }
    }
}

extension View {

    /// alertNoPages
    /// - Parameter isPresented: isPresented
    func alertNoPages(isPresented: Binding<Bool>) -> some View {
        self.alert(L10n.AI.Synthesis.Error.noPages, isPresented: isPresented) {
            Button(L10n.Common.ok, role: .cancel) { }
        }
    }

    /// alertLimitReached
    /// - Parameter isPresented: isPresented
    func alertLimitReached(isPresented: Binding<Bool>) -> some View {
        self.alert(L10n.AI.Synthesis.Error.limitReached, isPresented: isPresented) {
            Button(L10n.Common.done, role: .cancel) { }
        }
    }

    /// alert重命名Doc
    /// - Parameter isPresented: isPresented
    /// - Parameter name: name
    /// - Parameter doc: doc
    func alertRenameDoc(isPresented: Binding<Bool>, name: Binding<String>, doc: SynthesisStore.SynthesisDocument?) -> some View {
        self.alert(L10n.Common.rename, isPresented: isPresented) {
            TextField(L10n.Tag.Management.inputName, text: name)
            Button(L10n.Common.rename) {
                if let doc = doc {
                    let trimmed = name.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    @Dependency(\.synthesisStore) var store: SynthesisStore
                    store.renameSynthesisDoc(type: doc.type, docID: doc.id, newName: trimmed)
                }
            }
            Button(L10n.Common.cancel, role: .cancel) { }
        }
    }

    /// confirmBatch删除
    /// - Parameter isPresented: isPresented
    /// - Parameter action: action
    /// - Returns: 视图
    func confirmBatchDelete(isPresented: Binding<Bool>, action: @escaping () -> Void) -> some View {
        self.confirmationDialog(L10n.AI.Synthesis.batchDeleteConfirm, isPresented: isPresented, titleVisibility: .automatic) {
            Button(L10n.Common.delete, role: .destructive) { action() }
            Button(L10n.Common.cancel, role: .cancel) { }
        }
    }

    /// alert删除Doc
    /// - Parameter isPresented: isPresented
    /// - Parameter doc: doc
    func alertDeleteDoc(isPresented: Binding<Bool>, doc: SynthesisStore.SynthesisDocument?, store: SynthesisStore) -> some View {
        self.alert(L10n.Common.deleteConfirm, isPresented: isPresented) {
            Button(L10n.Common.delete, role: .destructive) {
                if let doc = doc {
                    store.deleteSynthesisDoc(type: doc.type, docID: doc.id)
                    HapticFeedback.shared.trigger(.success)
                }
            }
            Button(L10n.Common.cancel, role: .cancel) { }
        }
    }
}
