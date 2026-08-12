//
//  IngestURLHandler.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：URL/剪贴板导入处理 — 网页抓取、批量 URL 任务编排与剪贴板内容导入。
//
import SwiftUI
import UFPCore
import Dependencies

// MARK: - URL / 剪贴板导入处理

extension IngestCoordinator {

    /// 从网页 URL 提取图片并 OCR，返回追加的 Markdown 文本
    func extractImagesFromURL(_ urlString: String) async throws -> String {
        guard let url = URL(string: urlString) else { return "" }
        // VULN-005 修复：SSRF 防护 — 拒绝内网地址
        guard SSRFGuard.isSafeURL(url) else { return "" }
        guard let (htmlData, _) = try? await URLSession.shared.data(from: url) else { return "" }
        guard let html = String(data: htmlData, encoding: .utf8) else { return "" }
        return await imageExtractor.extractImagesFromHTML(html, baseURL: url)
    }

    /// 批量导入 URL
    ///
    /// 返回值：承载批量导入编排的 `Task` handle，供调用方（主要是测试）等待完成或取消。
    /// 生产环境调用方可忽略返回值（fire-and-forget 语义不变）。
    /// 架构修复：此前方法内部启动未结构化 `Task` 且无 handle 返回，导致调用方无法感知
    /// 异步副作用生命周期；测试环境 `tearDown` 清空 DI 后异步任务继续访问 `@Inject` 属性
    /// 触发 `fatalError`。返回 Task handle 后测试可 `await task.value` 等待完成再清理 DI。
    @discardableResult
    func handleBatchURLImport(_ urls: [URL]) -> Task<Void, Never> {
        guard !isImporting else {
            toastManager.show(type: .info, message: L10n.Ingest.importCooldown)
            return Task { }
        }
        showURLImport = false
        lastImportTime = Date()

        let totalCount = urls.count
        let taskID = TaskCenter.shared.addTask(
            type: .ingest,
            name: L10n.Ingest.urlImport,
            target: L10n.Ingest.validURLCount(totalCount, totalCount)
        )

        return Task {
            let scraper = WebScraperProcessor()
            let vaultID = VaultService.shared.selectedVaultID?.uuidString
            let store = fileStore
            let completed = await withTaskGroup(of: (ok: Bool, idx: Int).self) { group in
                for (i, url) in urls.enumerated() {
                    let urlString = url.absoluteString
                    let recordID = UUID().uuidString
                    group.addTask { [self, taskID, urlString, recordID] in
                        let ok = await importSingleURL(
                            urlString: urlString,
                            recordID: recordID,
                            taskID: taskID,
                            scraper: scraper,
                            vaultID: vaultID,
                            store: store
                        )
                        return (ok, i)
                    }
                }

                var results = [(ok: Bool, idx: Int)]()
                var processedCount = 0
                for await r in group {
                    results.append(r)
                    processedCount += 1
                    let progress = Double(processedCount) / Double(totalCount)
                    await MainActor.run {
                        TaskCenter.shared.updateTask(taskID, status: .running(progress: progress, stage: .extraction))
                    }
                }
                return results
            }

            let ok = completed.filter(\.ok).count
            let fail = completed.count - ok
            await MainActor.run {
                if fail == 0 {
                    TaskCenter.shared.updateTask(taskID, status: .completed)
                } else if ok == 0 {
                    TaskCenter.shared.updateTask(taskID, status: .failed(error: L10n.Ingest.importFailed))
                } else {
                    // 部分失败：标记为 failed 但消息说明部分成功，避免 UI 误显示"全部完成"
                    TaskCenter.shared.updateTask(taskID, status: .failed(error: L10n.Ingest.batchResult(ok, fail)))
                }
                toastManager.show(type: ok > 0 ? .success : .error, message: L10n.Ingest.batchResult(ok, fail))
            }
        }
    }

    /// 单个 URL 网页抓取与导入
    private func importSingleURL(
        urlString: String,
        recordID: String,
        taskID: UUID,
        scraper: WebScraperProcessor,
        vaultID: String?,
        store: any ImportFileStore
    ) async -> Bool {
        // 防御性 DI 就绪检查：异步任务可能跨 DI 生命周期边界（如测试 tearDown 清空 DI 后
        // 异步 Task 仍在运行），此时访问 @Inject 属性会触发 fatalError。
        // 用 typeErasedResolve 非崩溃 API 预检查，未就绪则降级返回 false 并记录日志。
        guard await isDIReadyForImport(taskID: taskID, urlString: urlString) else { return false }

        await MainActor.run {
            TaskCenter.shared.addSubLog(id: taskID, log: "\(L10n.Ingest.fetchingURL): \(urlString)")
        }

        // VULN-005 修复：SSRF 防护 — 拒绝内网/环回/链路本地地址
        if let url = URL(string: urlString), !SSRFGuard.isSafeURL(url) {
            await MainActor.run {
                TaskCenter.shared.addSubLog(id: taskID, log: "\(L10n.Ingest.fetchingURL): \(urlString) [blocked]")
            }
            return false
        }

        let rawResult = try? await scraper.fetchMarkdown(from: urlString)
        let title = rawResult?.title ?? urlString
        await logFetchResult(rawResult: rawResult, title: title, urlString: urlString, taskID: taskID)

        // 抓取失败时跳过 OCR（对空内容做 OCR 无意义）
        let ocrText: String
        if rawResult != nil {
            await MainActor.run {
                TaskCenter.shared.addSubLog(id: taskID, log: "\(L10n.Ingest.imageExtracting): \(title)")
            }
            ocrText = (try? await self.extractImagesFromURL(urlString)) ?? ""
        } else {
            ocrText = ""
        }

        return await persistImportedURL(
            rawResult: rawResult, urlString: urlString, title: title,
            ocrText: ocrText, recordID: recordID, taskID: taskID,
            vaultID: vaultID, store: store
        )
    }

    /// DI 就绪检查 — 异步任务跨 DI 生命周期边界时防御性降级
    private func isDIReadyForImport(taskID: UUID, urlString: String) async -> Bool {
        guard
            ServiceContainer.shared.typeErasedResolve(AppStore.self) != nil,
            ServiceContainer.shared.typeErasedResolve((any ImportRecordRepository).self) != nil
        else {
            await MainActor.run {
                TaskCenter.shared.addSubLog(id: taskID, log: "\(L10n.Ingest.importFailed): DI not ready [\(urlString)]")
            }
            return false
        }
        return true
    }

    /// 记录网页抓取结果日志
    private func logFetchResult(rawResult: (markdown: String, title: String)?, title: String, urlString: String, taskID: UUID) async {
        if rawResult != nil {
            await MainActor.run {
                TaskCenter.shared.addSubLog(id: taskID, log: "\(L10n.Ingest.Status.webscraperLevel1Success): \(title)")
            }
        } else {
            await MainActor.run {
                TaskCenter.shared.addSubLog(id: taskID, log: "\(L10n.Ingest.Status.webscraperLevel1Failed): \(urlString)")
            }
        }
    }

    /// 持久化导入的 URL 内容并触发 ingest
    private func persistImportedURL(
        rawResult: (markdown: String, title: String)?,
        urlString: String,
        title: String,
        ocrText: String,
        recordID: String,
        taskID: UUID,
        vaultID: String?,
        store: any ImportFileStore
    ) async -> Bool {
        let rawBody = rawResult.map { "> \(L10n.Ingest.urlSourcePrefix)\(urlString)\n> \(L10n.Ingest.scrapeTimePrefix)\(Date().formatted(date: .numeric, time: .shortened))\n\n\($0.markdown)" }
        let rawMarkdown = rawBody.map { $0 + ocrText }
        let filePath = rawMarkdown.flatMap { store.saveContent($0, category: .link, ext: "md") }

        let record = ImportRecord(
            id: recordID, category: ImportCategory.link.rawValue,
            title: title, status: ImportRecordStatus.processing,
            rawText: rawMarkdown, sourceURL: urlString, filePath: filePath,
            vaultID: vaultID
        )
        try? await self.importRecordRepo.save(record)

        let page = try? await self.store.ingestService.ingestURL(urlString: urlString, pageStore: self.store)
        if let page = page {
            try? await self.importRecordRepo.updateStatus(id: recordID, status: ImportRecordStatus.done, completedAt: Date())
            try? await self.importRecordRepo.updatePageID(id: recordID, pageID: page.id.uuidString)
            await MainActor.run {
                TaskCenter.shared.addSubLog(id: taskID, log: "\(L10n.Ingest.Status.completed): \(title)")
            }
            return true
        } else {
            try? await self.importRecordRepo.updateStatus(id: recordID, status: ImportRecordStatus.failed, completedAt: Date())
            await MainActor.run {
                TaskCenter.shared.addSubLog(id: taskID, log: "\(L10n.Ingest.importFailed): \(title)")
            }
            return false
        }
    }

    /// 执行Clipboard导入
    func performClipboardImport() {
        if let content = AppPasteboard.string, !content.isEmpty {
            self.sourceHint = .clipboard
            self.newTitle = String(content.prefix(AppConstants.Keys.ImportLimits.clipboardTitleLength))
            self.newContent = content
            self.manualFormTitle = L10n.Ingest.clipboardImport
            self.showManualForm = true
        }
    }
}
