//
//  SynthesisStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：AI 合成实验室：摘要、思维导图、测验、报告生成。
//
import Foundation
import UFPCore
import Observation
import Combine
import Dependencies

@MainActor
@Observable
public final class SynthesisStore {
    @ObservationIgnored @Dependency(\.taskCenter) private var taskCenter
    public struct SynthesisDocument: Codable, Identifiable, Sendable {
        public let id: UUID
        public let type: SynthesisType
        public let name: String
        public let content: String
        public let createdAt: Date
        public let size: Int
        public var sourcePageIDs: [UUID]

        public init(id: UUID = UUID(), type: SynthesisType, name: String, content: String, createdAt: Date = Date(), size: Int, sourcePageIDs: [UUID] = []) {
            self.id = id
            self.type = type
            self.name = name
            self.content = content
            self.createdAt = createdAt
            self.size = size
            self.sourcePageIDs = sourcePageIDs
        }
    }

    public enum SynthesisType: String, CaseIterable, Codable, Identifiable, Sendable {
        case mindmap
        case slides
        case quiz
        case report
        case infographic
        case expansion
        public var id: String { rawValue }
        public var title: String {
            switch self {
            case .mindmap: return L10n.AI.Prompt.Expert.Mindmap.title
            case .slides: return L10n.AI.Prompt.Expert.Slides.title
            case .quiz: return L10n.AI.Prompt.Expert.Quiz.title
            case .report: return L10n.AI.Prompt.Expert.Report.title
            case .infographic: return L10n.Knowledge.Page.AI.infographic
            case .expansion: return L10n.Knowledge.Page.AI.expansion
            }
        }
        public var icon: String {
            switch self {
            case .mindmap: return "circle.hexagongrid.fill"
            case .slides: return "play.rectangle"
            case .quiz: return "checklist.checked"
            case .report: return "doc.text.magnifyingglass"
            case .infographic: return "chart.bar.doc.horizontal"
            case .expansion: return "text.badge.plus"
            }
        }
        public var formatIcon: String {
            switch self {
            case .mindmap: return "circle.hexagongrid.fill"
            case .slides: return "play.rectangle.fill"
            case .quiz: return "checklist.checked"
            case .report: return "doc.richtext.fill"
            case .infographic: return "chart.bar.fill"
            case .expansion: return "text.badge.plus"
            }
        }
        public var customPromptPlaceholder: String {
            switch self {
            case .mindmap: return L10n.AI.Synthesis.Control.Placeholder.mindmap
            case .slides: return L10n.AI.Synthesis.Control.Placeholder.slides
            case .quiz: return L10n.AI.Synthesis.Control.Placeholder.quiz
            case .report: return L10n.AI.Synthesis.Control.Placeholder.report
            case .infographic: return L10n.AI.Synthesis.Control.Placeholder.infographic
            case .expansion: return L10n.AI.Synthesis.Control.Placeholder.expansion
            }
        }
    }

    public enum SynthesisStatus: Equatable, Sendable {
        case idle
        case generating
        case completed
        case error(String)
        public var isError: Bool {
            if case .error = self { return true }
            return false
        }
    }

    @ObservationIgnored private var _synthesisResults: [SynthesisType: [SynthesisDocument]] = [:]
    public var synthesisResults: [SynthesisType: [SynthesisDocument]] {
        get { access(keyPath: \.synthesisResults); return _synthesisResults }
        set { withMutation(keyPath: \.synthesisResults) { _synthesisResults = newValue } }
    }

    @ObservationIgnored private var _synthesisStates: [SynthesisType: SynthesisStatus] = {
        var states: [SynthesisType: SynthesisStatus] = [:]
        for type in SynthesisType.allCases { states[type] = .idle }
        return states
    }()

    public var synthesisStates: [SynthesisType: SynthesisStatus] {
        get { access(keyPath: \.synthesisStates); return _synthesisStates }
        set { withMutation(keyPath: \.synthesisStates) { _synthesisStates = newValue } }
    }

    /// 预计算的聚合且排序后的所有合成文档列表（优化 UI 刷新性能）
    public var allSortedDocuments: [(SynthesisType, SynthesisDocument)] {
        SynthesisType.allCases.flatMap { type in
            (synthesisResults[type] ?? []).map { (type, $0) }
        }.sorted { $0.1.createdAt > $1.1.createdAt }
    }

    let maxSynthesisDocsPerType = 5

    @ObservationIgnored private var cancellables = Set<AnyCancellable>()

    public init() {
        loadSynthesisResults()

        AppEventBus.shared.subscribe()
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                if case .clearAllDataRequested = event {
                    self?.clearAll()
                }
            }
            .store(in: &cancellables)
    }

    /// 加载SynthesisResults
    /// 使用 resolveOptional 优雅降级：DI 容器未就绪时静默跳过，等待后续显式加载。
    public func loadSynthesisResults() {
        @Dependency(\.keyStore) var keyStore: (any KeyStoreProtocol)?
        guard let keyStore = keyStore else { return }
        for type in SynthesisType.allCases {
            let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
            if let data = keyStore.data(forKey: key),
               let docs = try? JSONDecoder().decode([SynthesisDocument].self, from: data) {
                _synthesisResults[type] = docs
            }
        }
    }

    /// 保存SynthesisResult
    /// - Parameter type: type
    /// - Parameter content: content
    /// 保存SynthesisResult
    /// - Parameter type: type
    /// - Parameter content: content
    @discardableResult
    public func saveSynthesisResult(type: SynthesisType, content: String, sourcePageIDs: [UUID] = []) -> SynthesisDocument? {
        let cleanedContent = Self.cleanMarkdown(content)
        let trimmed = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 🛡️ 校验生成内容有效性：拒绝 0 字节、纯骨架关键字或小于最小字节阀值的无效填充
        guard !trimmed.isEmpty,
              trimmed != "mindmap",
              trimmed != "graph TD",
              trimmed != "graph",
              trimmed.utf8.count >= AppConstants.ExportLimits.minValidSynthesisTextBytes else {
            Logger.shared.addLog(action: .ingest, target: type.title, details: "Synthesis result invalid or empty (size: \(trimmed.utf8.count) B)")
            return nil
        }

        let title = extractTitle(from: cleanedContent, type: type)
        let name = "\(title) - \(formatDateFull(Date()))"
        let size = cleanedContent.utf8.count
        let doc = SynthesisDocument(id: UUID(), type: type, name: name, content: cleanedContent, createdAt: Date(), size: size, sourcePageIDs: sourcePageIDs)

        var existing = synthesisResults[type] ?? []
        existing.insert(doc, at: 0)
        synthesisResults[type] = existing
        synthesisStates[type] = .completed
        persistResults(for: type)
        return doc
    }

    /// 核心分派执行不同类型的 AI 合成任务
    private func dispatchSynthesis(type: SynthesisType, content: String) async throws -> String {
        switch type {
        case .mindmap:
            return try await AISynthesisService.shared.generateMindMap(content: content)
        case .slides:
            return try await AISynthesisService.shared.generatePresentation(content: content)
        case .quiz:
            return try await AISynthesisService.shared.generateQuiz(content: content)
        case .report:
            return try await AISynthesisService.shared.generateReport(content: content)
        case .infographic:
            return try await AISynthesisService.shared.generateInfographic(content: content)
        case .expansion:
            return try await AISynthesisService.shared.expandKnowledge(content: content)
        }
    }

    /// 执行Synthesis
    /// - Parameter type: type
    /// - Parameter combinedContent: combinedContent
    /// - Returns: 合成文档对象 SynthesisDocument
    public func performSynthesis(type: SynthesisType, combinedContent: String, options: SynthesisControlOptions = SynthesisControlOptions(), sourcePageIDs: [UUID] = []) async throws -> SynthesisDocument {
        guard synthesisStates[type] != SynthesisStatus.generating else { 
            throw AppError.synthesis("Task already in progress", code: -1)
        }

        let existingCount = synthesisResults[type]?.count ?? 0
        if existingCount >= maxSynthesisDocsPerType {
            // 容量管控：已达 5 份上限时拒绝生成并抛错，由 UI 层提示用户清理旧文档
            // 严禁自动删除用户历史文档（用户决策：抛错不删除）
            throw AppError.synthesis(L10n.AI.Synthesis.Error.limitReached, code: -2)
        }

        withMutation(keyPath: \.synthesisStates) {
            _synthesisStates[type] = SynthesisStatus.generating
        }
        let taskID = taskCenter.addTask(type: .synthesis, name: type.title, target: L10n.Common.Sidebar.synthesis)

        let controlInstruction = options.promptInstruction

        // Prepend anti-hallucination + source citation + control options instruction
        let augmentedContent = """
        \(controlInstruction)

        \(L10n.AI.Synthesis.citationInstruction)

        ---
        \(combinedContent)
        """

        let traceID = UUID().uuidString
        Logger.shared.addLog(action: .ingest, target: type.title, details: "[TraceID: \(traceID)] Starting synthesis")

        do {
            let content = try await dispatchSynthesis(type: type, content: augmentedContent)
            let strategy = SynthesisStrategyFactory.strategy(for: type)
            let processedContent = strategy.process(rawContent: content, sourceContent: combinedContent)
            
            let cleaned = Self.cleanMarkdown(processedContent).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty, cleaned != "mindmap", cleaned != "graph TD", cleaned.utf8.count >= AppConstants.ExportLimits.minValidSynthesisTextBytes else {
                let invalidError = L10n.AI.Synthesis.Error.invalidResult
                Logger.shared.addLog(action: .ingest, target: type.title, details: "[TraceID: \(traceID)] Synthesis validation failed, invalid content")
                throw AppError.synthesis(invalidError, code: -3)
            }

            guard let savedDoc = self.saveSynthesisResult(type: type, content: processedContent, sourcePageIDs: sourcePageIDs) else {
                let invalidError = L10n.AI.Synthesis.Error.invalidResult
                throw AppError.synthesis(invalidError, code: -3)
            }
            Logger.shared.addLog(action: .ingest, target: type.title, details: "[TraceID: \(traceID)] [SynthesisStatus: Success] Saved doc \(savedDoc.id)")
            taskCenter.completeTask(id: taskID)
            return savedDoc
        } catch {
            Logger.shared.addLog(action: .ingest, target: type.title, details: "[TraceID: \(traceID)] [SynthesisStatus: Error] \(error.localizedDescription)")
            withMutation(keyPath: \.synthesisStates) {
                self._synthesisStates[type] = SynthesisStatus.error(error.localizedDescription)
            }
            taskCenter.failTask(id: taskID, error: error.localizedDescription)
            throw error
        }
    }

    /// 重命名SynthesisDoc
    /// - Parameter type: type
    /// - Parameter docID: docID
    /// - Parameter newName: newName
    public func renameSynthesisDoc(type: SynthesisType, docID: UUID, newName: String) {
        guard var docs = _synthesisResults[type],
              let idx = docs.firstIndex(where: { $0.id == docID }) else { return }
        let original = docs[idx]
        docs[idx] = SynthesisDocument(id: original.id, type: original.type, name: newName, content: original.content, createdAt: original.createdAt, size: original.size)
        synthesisResults[type] = docs
        persistResults(for: type)
    }

    /// 删除SynthesisDoc
    /// - Parameter type: type
    /// - Parameter docID: docID
    public func deleteSynthesisDoc(type: SynthesisType, docID: UUID) {
        guard var docs = _synthesisResults[type] else { return }
        docs.removeAll { $0.id == docID }
        synthesisResults[type] = docs
        if docs.isEmpty {
            synthesisStates[type] = .idle
        }
        persistResults(for: type)
    }

    /// batch删除SynthesisDocs
    /// - Parameter ids: ids
    public func batchDeleteSynthesisDocs(ids: Set<UUID>) {
        for type in SynthesisType.allCases {
            guard var docs = _synthesisResults[type], !docs.isEmpty else { continue }
            let originalCount = docs.count
            docs.removeAll { ids.contains($0.id) }
            if docs.count != originalCount {
                synthesisResults[type] = docs
                if docs.isEmpty {
                    synthesisStates[type] = .idle
                }
                persistResults(for: type)
            }
        }
    }

    /// 导出SynthesisDocument
    /// - Parameter doc: doc
    /// - Returns: 链接
    public func exportSynthesisDocument(_ doc: SynthesisDocument) async throws -> URL {
        let fileName = doc.name.replacingOccurrences(of: "/", with: "-")
                               .replacingOccurrences(of: ":", with: "-")
        let url: URL
        switch doc.type {
        case .mindmap:
            url = try await WebViewExportService.shared.exportMindmapToPDF(mermaidCode: doc.content, fileName: fileName)
        case .slides:
            url = try await WebViewExportService.shared.exportToPPTX(markdown: doc.content, fileName: fileName)
        case .report, .quiz, .infographic, .expansion:
            url = try await WebViewExportService.shared.exportToPDF(markdown: doc.content, fileName: fileName)
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
        Logger.shared.addLog(
            action: .export,
            target: "\(doc.type.title): \(fileName)",
            details: "size:\(fileSize)"
        )

        return url
    }

    /// 清除All
    public func clearAll() {
        withMutation(keyPath: \.synthesisResults) {
            _synthesisResults.removeAll()
        }
        withMutation(keyPath: \.synthesisStates) {
            for type in SynthesisType.allCases {
                _synthesisStates[type] = .idle
            }
        }
        
        @Dependency(\.keyStore) var keyStore: (any KeyStoreProtocol)?
        for type in SynthesisType.allCases {
            let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
            keyStore?.removeObject(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    /// 清理Markdown
    /// - Parameter text: text
    /// - Returns: 字符串
    static func cleanMarkdown(_ text: String) -> String {
        var cleaned = text
        let pattern = #"\\([\#\(\)\[\]\{\}\_\~\+\-\*\.\!\|])"#
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let range = NSRange(location: 0, length: cleaned.utf16.count)
            cleaned = regex.stringByReplacingMatches(in: cleaned, options: [], range: range, withTemplate: "$1")
        }
        cleaned = cleaned.replacingOccurrences(of: "\\[\\[", with: "[[")
                        .replacingOccurrences(of: "\\]\\]", with: "]]")
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractTitle(from content: String, type: SynthesisType) -> String {
        if type == .quiz {
            let cleaned = content.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let data = cleaned.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let title = json["title"] as? String {
                return title
            }
        }
        return SynthesisProcessor.extractTitle(from: content) ?? type.title
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private func formatDateFull(_ date: Date) -> String {
        Self.dateFormatter.string(from: date)
    }
    
    private func persistResults(for type: SynthesisType) {
        let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
        @Dependency(\.keyStore) var keyStore: (any KeyStoreProtocol)?
        if let docs = _synthesisResults[type], !docs.isEmpty,
           let data = try? JSONEncoder().encode(docs) {
            keyStore?.set(data, forKey: key)
            UserDefaults.standard.set(data, forKey: key)
        } else {
            keyStore?.removeObject(forKey: key)
            UserDefaults.standard.removeObject(forKey: key)
        }
    }
}

// MARK: - DependencyKey

@MainActor
public enum SynthesisStoreKey: DependencyKey {
    @MainActor
    public static var liveValue: SynthesisStore { ServiceContainer.shared.resolve(SynthesisStore.self) }
}

extension DependencyValues {
    @MainActor
    public var synthesisStore: SynthesisStore {
        get { self[SynthesisStoreKey.self] }
        set { self[SynthesisStoreKey.self] = newValue }
    }
}
