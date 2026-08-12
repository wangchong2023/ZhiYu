//
//  IngestStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：知识摄入：文档导入、URL 抓取、OCR 扫描、PDF 解析。
//
import Foundation
import UFPCore
import Observation
import Combine
import Dependencies

/// 摄入业务存储，专门负责文件导入、智能提取及摄入工作流管理。
/// 实现从“原始数据”到“系统页面”的转换逻辑。
@MainActor
@Observable
final class IngestStore {
    @ObservationIgnored @Inject private var pageStore: any AnyPageStoreCapabilities  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    @ObservationIgnored @Inject private var llmService: any LLMServiceProtocol  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    @ObservationIgnored @Inject private var logger: any LoggerProtocol  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    @ObservationIgnored @Inject private var ingestService: IngestService  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    @ObservationIgnored @Inject private var pdfService: any PDFServiceProtocol  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    @ObservationIgnored @Inject private var ocrService: any OCRServiceProtocol  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    @ObservationIgnored @Dependency(\.taskCenter) private var taskCenter

    init() {}

    // MARK: - OCR 业务

    /// 从图像中提取文本
    public func recognizeText(from image: AppImage) async throws -> String {
        try await ocrService.recognizeText(from: image)
    }

    // MARK: - PDF 业务操作

    /// 加载所有保存的 PDF 文档元数据
    public func loadPDFDocuments() async -> [PDFDocumentInfo] {
        await pdfService.loadDocumentsInfo()
    }

    /// 加载单个 PDF 文档元数据
    public func loadPDFDocument(id: UUID) async -> PDFDocumentInfo? {
        let all = await pdfService.loadDocumentsInfo()
        return all.first { $0.id == id }
    }

    /// 根据文件名加载 PDF 物理路径
    public func loadPDFDocument(fileName: String) async -> URL? {
        pdfService.getPDFURL(fileName: fileName)
    }

    /// 保存 PDF 文档元数据
    public func savePDFDocument(_ document: PDFDocumentInfo) async {
        var all = await pdfService.loadDocumentsInfo()
        if let idx = all.firstIndex(where: { $0.id == document.id }) {
            all[idx] = document
        } else {
            all.append(document)
        }
        await pdfService.saveDocumentsInfo(all)
    }

    /// 批量保存 PDF 文档元数据
    public func savePDFDocuments(_ documents: [PDFDocumentInfo]) async {
        await pdfService.saveDocumentsInfo(documents)
    }

    /// 物理保存 PDF 文件并返回其物理路径
    @discardableResult

    /// 保存PDFDocument
    /// - Parameter data: data
    /// - Parameter fileName: fileName
    /// - Returns: 可选值
    public func savePDFDocument(data: Data, fileName: String) async -> URL? {
        await pdfService.savePDF(data: data, fileName: fileName)
    }

    /// 删除 PDF 文档及其元数据
    public func deletePDFDocument(_ document: PDFDocumentInfo) async {
        var all = await pdfService.loadDocumentsInfo()
        all.removeAll { $0.id == document.id }
        await pdfService.saveDocumentsInfo(all)
        _ = await pdfService.deletePDF(fileName: document.fileName)
    }

    /// 根据文件名物理删除 PDF 文件
    @discardableResult

    /// 删除PDFDocument
    /// - Parameter fileName: fileName
    /// - Returns: 是否成功
    public func deletePDFDocument(fileName: String) async -> Bool {
        await pdfService.deletePDF(fileName: fileName)
    }

    /// 从 PDF 中提取全量文本内容
    public func extractPDFText(from url: URL) async -> String {
        await pdfService.extractText(from: url) ?? ""
    }

    /// 从 PDF 中提取指定页码范围的文本内容
    public func extractPDFText(from url: URL, pageRange: Range<Int>) async -> String {
        await pdfService.extractText(from: url, pageRange: pageRange) ?? ""
    }

    /// 确认并完成智能摄入
    func finalizeSmartIngest(title: String, result: SmartIngestResult, customIcon: String?) async -> KnowledgePage {
        let type: PageType = PageType(rawValue: result.suggestedType) ?? .concept

        // 我们需要一种方式来创建页面，而不依赖 AppStore
        // 这里我们直接模拟 createPage 逻辑，或者调用底层 Repository
        var page = KnowledgePage(title: title, content: result.compiledContent)
        page.pageType = type
        page.customIcon = customIcon
        page.tags = result.suggestedTags

        // 自动建立关联
        var relatedIDs: [UUID] = []
        for t in result.relatedTitles {
            if let linked = await pageStore.pages.first(where: { $0.title == t }) {
                relatedIDs.append(linked.id)
            }
        }
        page.relatedPageIDs = relatedIDs

        // 持久化
        await pageStore.syncRemotePage(page)

        logger.addLog(action: .smartIngest, target: title, details: L10n.Ingest.smartIngestDoneDesc(type.displayName))
        HapticFeedback.shared.trigger(.success)

        // 刷新缓存
        await pageStore.reloadFromDisk()

        return page
    }

    /// 执行综合摄入逻辑
    @discardableResult

    /// 执行导入摄取
    func performIngest(
        title: String,
        content: String,
        type: PageType,
        tags: [String],
        customIcon: String?,
        useSmart: Bool,
        useDeepScan: Bool,
        fileSize: Int64? = nil,
        sourceType: String? = nil
    ) async throws -> KnowledgePage {
        let taskID = taskCenter.addTask(type: .ingest, name: L10n.Ingest.manualEntry, target: title)

        do {
            let page: KnowledgePage
            if useSmart && llmService.isEnabled {
                let result = try await llmService.smartIngest(title: title, rawContent: content, pages: await pageStore.pages)
                let pageType = PageType(rawValue: result.suggestedType) ?? type

                // 借用 finalizeSmartIngest 的 logic 进行创建
                page = await finalizeSmartIngest(title: title, result: result, customIcon: customIcon)
                logger.addLog(action: .smartIngest, target: title, details: L10n.Ingest.smartIngestDoneDesc(pageType.displayName))
            } else {
                // 使用 IngestService 的 standard 流程
                page = try await ingestWithFolding(
                    title: title,
                    content: content,
                    type: type,
                    forceDeepScan: useDeepScan,
                    fileSize: fileSize,
                    sourceType: sourceType
                )

                var updatedPage = page
                updatedPage.tags = tags
                updatedPage.customIcon = customIcon
                _ = try? await pageStore.updatePage(updatedPage)
            }

            taskCenter.updateTask(taskID, status: .completed, associatedPageID: page.id)
            HapticFeedback.shared.trigger(.success)
            await pageStore.reloadFromDisk() // 确保数据同步
            return page
        } catch {
            taskCenter.updateTask(taskID, status: .failed(error: error.localizedDescription))
            throw error
        }
    }

    private func ingestWithFolding(title: String, content: String, type: PageType, forceDeepScan: Bool, fileSize: Int64? = nil, sourceType: String? = nil) async throws -> KnowledgePage {
        return try await ingestService.ingestRawContent(
            title: title,
            content: content,
            type: type,
            forceDeepScan: forceDeepScan,
            llmService: llmService,
            pageStore: pageStore,
            fileSize: fileSize,
            sourceType: sourceType
        )
    }
}
