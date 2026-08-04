//
//  IngestFileHandler.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：文件导入处理 — 本地文档安全导入、OCR 图片提取、去重检测与后台任务编排。
//
import SwiftUI
import UFPCore
import UniformTypeIdentifiers

// MARK: - 文件导入处理

extension IngestCoordinator {

    /// 处理File导入
    func handleFileImport(_ result: Result<[URL], Error>) {
        guard !isImporting else {
            ToastManager.shared.show(type: .info, message: L10n.Ingest.importCooldown)
            return
        }
        switch result {
        case .success(let urls):
            for url in urls {
                importSingleFile(at: url)
            }
        case .failure(let error):
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    /// 处理单个本地文档文件的安全导入与 OCR 处理
    private func importSingleFile(at url: URL) {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let fileName = url.lastPathComponent
        lastImportTime = Date()
        let taskID = TaskCenter.shared.addTask(type: .ingest, name: L10n.Ingest.importingFile, target: fileName)
        let recordID = UUID().uuidString

        let fileSize: Int64? = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize.map(Int64.init)
        if let size = fileSize, size > AppConstants.Keys.ImportLimits.maxFileSizeBytes {
            lastImportTime = .distantPast
            Task { @MainActor in
                ToastManager.shared.show(type: .error, message: L10n.Ingest.fileTooLarge)
            }
            TaskCenter.shared.updateTask(taskID, status: .failed(error: L10n.Ingest.fileTooLarge))
            return
        }

        let textContent: String? = {
            let ext = url.pathExtension.lowercased()
            guard ["md", "txt", "markdown", "rtf"].contains(ext) else { return nil }
            return try? String(contentsOf: url, encoding: .utf8)
        }()

        guard let savedPath = fileStore.copyFile(at: url, category: .file) else {
            lastImportTime = .distantPast
            Task { @MainActor in
                ToastManager.shared.show(type: .error, message: L10n.Ingest.importFailed)
            }
            TaskCenter.shared.updateTask(taskID, status: .failed(error: L10n.Ingest.importFailed))
            return
        }
        
        let actualPath = savedPath
        let sandboxURL = URL(fileURLWithPath: savedPath)

        let record = ImportRecord(
            id: recordID, category: ImportCategory.file.rawValue,
            title: fileName, status: ImportRecordStatus.processing,
            rawText: textContent,
            filePath: actualPath, fileSize: fileSize,
            vaultID: VaultService.shared.selectedVaultID?.uuidString
        )

        let targetType = newType
        let forceDeepScan = useSmartIngest

        saveRecordAndExecute(
            record: record,
            sandboxURL: sandboxURL,
            taskID: taskID,
            targetType: targetType,
            forceDeepScan: forceDeepScan
        )
    }

    /// 保存导入记录并触发异步后台任务
    private func saveRecordAndExecute(
        record: ImportRecord,
        sandboxURL: URL,
        taskID: UUID,
        targetType: PageType,
        forceDeepScan: Bool
    ) {
        Task {
            let existing = (try? await importRecordRepo.fetchAll(category: ImportCategory.file.rawValue, limit: 1000)) ?? []
            if existing.contains(where: { $0.filePath == record.filePath && $0.status == ImportRecordStatus.done }) {
                await MainActor.run {
                    ToastManager.shared.show(type: .info, message: L10n.Ingest.duplicateFile(record.title))
                }
                TaskCenter.shared.updateTask(taskID, status: .failed(error: L10n.Ingest.duplicateFile(record.title)))
                return
            }
            try? await importRecordRepo.save(record)

            executeImportTask(
                at: sandboxURL,
                recordID: record.id,
                textContent: record.rawText,
                taskID: taskID,
                type: targetType,
                forceDeepScan: forceDeepScan
            )
        }
    }

    /// 异步执行文件导入的后台任务，包括 OCR 提取及最终文档摄入
    private func executeImportTask(
        at url: URL,
        recordID: String,
        textContent: String?,
        taskID: UUID,
        type: PageType,
        forceDeepScan: Bool
    ) {
        Task {
            let ocrText = await self.extractImagesFromFile(url: url)
            if !ocrText.isEmpty, var existingText = textContent {
                existingText += ocrText
                try? await importRecordRepo.updateRawText(id: recordID, rawText: existingText)
            }
            let page = await store.ingestService.ingestDocument(at: url, type: type, forceDeepScan: forceDeepScan, pageStore: store)
            await MainActor.run {
                if let page = page {
                    Task { @MainActor in
                        try? await importRecordRepo.updateStatus(id: recordID, status: ImportRecordStatus.done, completedAt: Date())
                        try? await importRecordRepo.updatePageID(id: recordID, pageID: page.id.uuidString)
                    }
                    TaskCenter.shared.updateTask(taskID, status: .completed)
                    HapticFeedback.shared.trigger(.success)
                } else {
                    Task { @MainActor in
                        try? await importRecordRepo.updateStatus(id: recordID, status: ImportRecordStatus.failed, completedAt: Date())
                    }
                    TaskCenter.shared.updateTask(taskID, status: .failed(error: L10n.Ingest.importFailed))
                    HapticFeedback.shared.trigger(.error)
                }
            }
        }
    }

    /// 从文件提取图片并 OCR（PDF/Office）
    func extractImagesFromFile(url: URL) async -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case AppConstants.Keys.ImportLimits.pdfExtension:
            let pdfService = ServiceContainer.shared.resolve((any PDFServiceProtocol).self)
            return await imageExtractor.extractImagesFromPDF(at: url, pdfService: pdfService)
        case let ext where AppConstants.Keys.ImportLimits.officeExtensions.contains(ext):
            return await imageExtractor.extractImagesFromOfficeFile(at: url)
        default:
            return ""
        }
    }
}
