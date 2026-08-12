//
//  IngestCoordinator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：Ingest 业务流 thin coordinator — 持有核心状态、DI 注入与表单编排逻辑，
//            将文件导入、URL 导入委托至专用扩展文件。
//
import SwiftUI
import UFPCore
import Observation
import UniformTypeIdentifiers
import Dependencies

@MainActor
@Observable
final class IngestCoordinator {
    @ObservationIgnored @Dependency(\.toastService) var toastManager
    // ── 基础设施依赖 ──
    @ObservationIgnored @Inject var store: AppStore
    @ObservationIgnored @Inject var ingestStore: IngestStore
    @ObservationIgnored @Inject var llmService: any LLMServiceProtocol
    @ObservationIgnored @Inject var importRecordRepo: any ImportRecordRepository
    @ObservationIgnored @Inject private var logger: any LoggerProtocol

    // ── 频控 ──
    let importCooldownSeconds = AppConstants.Keys.ImportLimits.importCooldownSeconds
    var lastImportTime: Date = .distantPast

    // ── UI 控制状态 ──
    var isIngesting = false
    var isImporting: Bool {
        let elapsed = Date().timeIntervalSince(lastImportTime)
        return elapsed < importCooldownSeconds
    }
    var showManualForm = false
    var manualFormTitle = L10n.Ingest.manualEntry
    var showOCRScan = false
    var showURLImport = false
    var showFileImporter = false
    var showVoiceNote = false
    var errorMessage: String?
    var showError = false
    var showLLMAlert = false

    // ── 业务表单数据 ──
    var newTitle = ""
    var newContent = ""
    var newType: PageType = .source
    var newCustomIcon: String?
    var newURL = ""
    var useSmartIngest = false
    var sourceHint: ImportCategory = .manual
    var pendingImageData: Data?
    var pendingVoiceFileURL: URL?

    var isLLMConfigured: Bool {
        llmService.isEnabled && !llmService.apiKey.isEmpty
    }

    // ── 图片提取器（共享依赖） ──
    let imageExtractor = ImageExtractor()
    @ObservationIgnored @Inject var fileStore: any ImportFileStore

    init() {}

    // ── 业务动作 ──

    /// 执行导入摄取
    func performIngest() {
        guard !isImporting else {
            toastManager.show(type: .info, message: L10n.Ingest.importCooldown)
            return
        }
        isIngesting = true
        lastImportTime = Date()
        let recordID = UUID().uuidString

        guard let prep = prepareImportFiles(recordID: recordID) else {
            return
        }

        let title = newTitle
        let content = newContent
        let type = newType
        let icon = newCustomIcon
        let smart = useSmartIngest
        let category = sourceHint.rawValue

        let record = ImportRecord(
            id: recordID, category: category, title: title,
            status: ImportRecordStatus.processing, rawText: prep.rawText,
            sourceURL: nil, filePath: prep.savedPath,
            vaultID: VaultService.shared.selectedVaultID?.uuidString
        )
        Task { try? await importRecordRepo.save(record) }

        Task {
            do {
                let page = try await ingestStore.performIngest(
                    title: title,
                    content: content,
                    type: type,
                    tags: [],
                    customIcon: icon,
                    useSmart: smart,
                    useDeepScan: true
                )
                try? await importRecordRepo.updateStatus(id: recordID, status: ImportRecordStatus.done, completedAt: Date())
                try? await importRecordRepo.updatePageID(id: recordID, pageID: page.id.uuidString)

                if let icon = icon {
                    var updated = page
                    updated.customIcon = icon
                    await store.updatePage(updated, forceDeepScan: true)
                }

                await MainActor.run {
                    self.isIngesting = false
                    self.showManualForm = false
                    self.resetForm()
                    HapticFeedback.shared.trigger(.success)
                }
            } catch {
                try? await importRecordRepo.updateStatus(id: recordID, status: ImportRecordStatus.failed, completedAt: Date())
                await MainActor.run {
                    self.isIngesting = false
                    self.errorMessage = L10n.Ingest.importFailed
                    self.showError = true
                    HapticFeedback.shared.trigger(.error)
                }
            }
        }
    }

    /// 预备保存导入的多媒体及文本文件
    func prepareImportFiles(recordID: String) -> (savedPath: String?, rawText: String)? {
        let content = newContent
        let sourceName = sourceHint.displayName

        let rawText = "> \(L10n.Ingest.sourcePrefix)\(sourceName) | \(Date().formatted(date: .numeric, time: .shortened))\n\n\(content)"
        let textPath = fileStore.saveContent(rawText, category: sourceHint, ext: "md")

        if sourceHint == .ocr, let imgData = pendingImageData {
            if imgData.count > AppConstants.Keys.ImportLimits.maxOCRImageSizeBytes {
                // OCR 超限时仍保存 ImportRecord 标记为 failed，保留导入历史
                let failedRecord = ImportRecord(
                    id: recordID, category: sourceHint.rawValue, title: newTitle,
                    status: ImportRecordStatus.failed, rawText: rawText,
                    sourceURL: nil, filePath: textPath,
                    vaultID: VaultService.shared.selectedVaultID?.uuidString
                )
                Task { try? await importRecordRepo.save(failedRecord) }
                pendingImageData = nil
                isIngesting = false
                lastImportTime = .distantPast
                errorMessage = L10n.Ingest.imageTooLarge
                showError = true
                return nil
            }
            _ = fileStore.saveData(imgData, category: .ocr, ext: "jpg")
            pendingImageData = nil
        }

        return (textPath, rawText)
    }

    /// AI 标签与分类
    func triggerAITagging(for record: ImportRecord) {
        guard let rawText = record.rawText, !rawText.isEmpty,
              llmService.isEnabled, !llmService.apiKey.isEmpty else { return }
        let id = record.id
        Task {
            await MainActor.run {
                toastManager.show(type: .info, message: L10n.Ingest.aiTagging)
            }
            let snippet = String(rawText.prefix(AppConstants.Keys.ImportLimits.aiTagSnippetLength))
            let prompt = L10n.Ingest.aiTagPrompt(snippet)
            do {
                let result = try await llmService.chat(query: prompt, history: [], pages: [])
                let json = extractJSON(from: result.content)
                if let tags = json["tags"] as? [String], !tags.isEmpty {
                    try? await importRecordRepo.updateTags(id: id, tags: tags.joined(separator: ", "))
                } else if json["tags"] != nil {
                    logger.warning("[IngestCoordinator] AI 标签类型转换失败：\(String(describing: json["tags"]))")
                }
                if let alias = json["aliasTitle"] as? String, !alias.isEmpty {
                    if var r = try? await importRecordRepo.fetchByID(id) {
                        r.title = alias
                        try? await importRecordRepo.save(r)
                    }
                } else if json["aliasTitle"] != nil {
                    logger.warning("[IngestCoordinator] AI aliasTitle 类型转换失败：\(String(describing: json["aliasTitle"]))")
                }
                await MainActor.run {
                    toastManager.show(type: .success, message: L10n.Ingest.aiTagSuccess)
                }
            } catch {
                await MainActor.run {
                    toastManager.show(type: .error, message: L10n.Ingest.aiTagFailed)
                }
            }
        }
    }

    /// 从 LLM 返回文本中提取 JSON
    func extractJSON(from text: String) -> [String: Any] {
        JSONExtractor.extractJSONDictionary(from: text)
    }

    /// 重置Form
    func resetForm() {
        newTitle = ""
        newContent = ""
        newCustomIcon = nil
        useSmartIngest = false
    }

    // MARK: - 手工录入二次编辑

    /// 开启手工录入表单并预填已有的记录数据以供用户再次编辑与重新导入
    func openManualForm(with record: ImportRecord) {
        self.sourceHint = .manual
        self.manualFormTitle = L10n.Ingest.manualEntry
        self.newTitle = record.title

        if let raw = record.rawText {
            let lines = raw.components(separatedBy: .newlines)
            if let firstLine = lines.first, firstLine.hasPrefix(">") {
                self.newContent = lines.dropFirst(AppConstants.Keys.ImportLimits.manualFormHeaderSkipLines).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                self.newContent = raw
            }
        } else {
            self.newContent = ""
        }

        if let pageID = record.pageID, let uuid = UUID(uuidString: pageID),
           let page = store.pages.first(where: { $0.id == uuid }) {
            self.newType = page.pageType
            self.newCustomIcon = page.customIcon
        } else {
            self.newType = .source
            self.newCustomIcon = nil
        }

        self.showManualForm = true
    }
}
