//
//  PromptService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 Prompt 模块的核心业务逻辑服务。
//
import Foundation
import Combine
import Dependencies

/// [L2] 领域服务：统一 Prompt 资产管理中心
/// 实现提示词与逻辑代码的解耦，便于后续调优与多语言适配。
@Observable
public final class PromptService: @unchecked Sendable {
    @ObservationIgnored private var cancellables = Set<AnyCancellable>()
    @ObservationIgnored private var defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        reload()
        setupObservers()
    }

    private func setupObservers() {
        NotificationCenter.default.publisher(for: .languageChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateLocalizables()
            }
            .store(in: &cancellables)
    }

    private func load() {
        if let savedMindmap = defaults.string(forKey: "prompt_mindmap") { self.mindmapPrompt = savedMindmap }
        if let savedQuiz = defaults.string(forKey: "prompt_quiz") { self.quizPrompt = savedQuiz }
        if let savedSlides = defaults.string(forKey: "prompt_slides") { self.slidesPrompt = savedSlides }
        if let savedReport = defaults.string(forKey: "prompt_report") { self.reportPrompt = savedReport }
        if let expansion = defaults.string(forKey: "prompt_expansion") { self.expansionPrompt = expansion }
        
        if let data = defaults.data(forKey: "prompt_user_shortcuts"),
           let decoded = try? JSONDecoder().decode([ShortcutItem].self, from: data) {
            self.userShortcuts = decoded
        }
    }

    // MARK: - 检索增强 (RAG) 相关

    public var queryRewritePrompt: String = L10n.AI.Prompt.queryRewrite

    public var rerankPrompt: String = L10n.AI.Prompt.rerank

    public var queryExpansionPrompt: String = L10n.AI.Prompt.queryExpansion

    // MARK: - 知识维护相关

    public var potentialLinksPrompt: String = L10n.AI.Prompt.potentialLinks

    public var foldingPrompt: String = L10n.AI.Prompt.folding

    public var refactorPrompt: String = L10n.AI.Prompt.refactor

    // MARK: - 知识合成 (Synthesis) 相关

    public var fixSuggestionPrompt: String = L10n.AI.Prompt.fixSuggestion

    public var mindmapPrompt: String = L10n.AI.Prompt.Default.mindmap
    public var quizPrompt: String = L10n.AI.Prompt.Default.quiz
    public var slidesPrompt: String = L10n.AI.Prompt.Default.slides
    public var summaryPrompt: String = L10n.AI.Prompt.Default.summary
    public var actionPrompt: String = L10n.AI.Prompt.Default.actions
    public var infographicPrompt: String = L10n.AI.Prompt.Default.infographic
    public var insightQuestionsPrompt: String = L10n.AI.Prompt.Default.insightQuestions
    public var reportPrompt: String = L10n.AI.Prompt.Default.report
    public var expansionPrompt: String = L10n.AI.Prompt.Default.expansion
    public var expansionSystemPrompt: String = "You are a senior knowledge expert and researcher. Your goal is to provide deep, insightful expansion of existing knowledge."

    // MARK: - 用户资产

    public var userShortcuts: [ShortcutItem] = []

    /// 更新Localizables
    public func updateLocalizables() {
        if userShortcuts.isEmpty {
            userShortcuts = [
                ShortcutItem(text: L10n.AI.Prompt.Shortcut.deepReview, localizationKey: L10n.AI.Prompt.Shortcut.Key.deepReview),
                ShortcutItem(text: L10n.AI.Prompt.Shortcut.findGaps, localizationKey: L10n.AI.Prompt.Shortcut.Key.findGaps),
                ShortcutItem(text: L10n.AI.Prompt.Shortcut.studyPath, localizationKey: L10n.AI.Prompt.Shortcut.Key.studyPath)
            ]
        }
        queryRewritePrompt = L10n.AI.Prompt.queryRewrite
        rerankPrompt = L10n.AI.Prompt.rerank
        potentialLinksPrompt = L10n.AI.Prompt.potentialLinks
        foldingPrompt = L10n.AI.Prompt.folding
        refactorPrompt = L10n.AI.Prompt.refactor
        fixSuggestionPrompt = L10n.AI.Prompt.fixSuggestion

        let defaults = self.defaults
        if defaults.string(forKey: "prompt_mindmap") == nil { mindmapPrompt = L10n.AI.Prompt.Default.mindmap }
        if defaults.string(forKey: "prompt_quiz") == nil { quizPrompt = L10n.AI.Prompt.Default.quiz }
        if defaults.string(forKey: "prompt_slides") == nil { slidesPrompt = L10n.AI.Prompt.Default.slides }
        if defaults.string(forKey: "prompt_report") == nil { reportPrompt = L10n.AI.Prompt.Default.report }
        if defaults.string(forKey: "prompt_expansion") == nil { expansionPrompt = L10n.AI.Prompt.Default.expansion }
    }

    /// reload
    public func reload() {
        load()
        updateLocalizables()
    }

    /// 保存
    public func save() {
        defaults.set(mindmapPrompt, forKey: "prompt_mindmap")
        defaults.set(quizPrompt, forKey: "prompt_quiz")
        defaults.set(slidesPrompt, forKey: "prompt_slides")
        defaults.set(reportPrompt, forKey: "prompt_report")
        defaults.set(expansionPrompt, forKey: "prompt_expansion")
        
        if let encoded = try? JSONEncoder().encode(userShortcuts) {
            defaults.set(encoded, forKey: "prompt_user_shortcuts")
        }
        Logger.shared.info("Prompt configurations saved to UserDefaults.")
    }

    /// 重置
    public func reset() {
        defaults.removeObject(forKey: "prompt_mindmap")
        defaults.removeObject(forKey: "prompt_quiz")
        defaults.removeObject(forKey: "prompt_slides")
        defaults.removeObject(forKey: "prompt_report")
        defaults.removeObject(forKey: "prompt_expansion")
        defaults.removeObject(forKey: "prompt_user_shortcuts")

        self.mindmapPrompt = L10n.AI.Prompt.Default.mindmap
        self.quizPrompt = L10n.AI.Prompt.Default.quiz
        self.slidesPrompt = L10n.AI.Prompt.Default.slides
        self.reportPrompt = L10n.AI.Prompt.Default.report
        self.expansionPrompt = L10n.AI.Prompt.Default.expansion
        
        self.userShortcuts = [
            ShortcutItem(text: L10n.AI.Prompt.Shortcut.deepReview, localizationKey: L10n.AI.Prompt.Shortcut.Key.deepReview),
            ShortcutItem(text: L10n.AI.Prompt.Shortcut.findGaps, localizationKey: L10n.AI.Prompt.Shortcut.Key.findGaps),
            ShortcutItem(text: L10n.AI.Prompt.Shortcut.studyPath, localizationKey: L10n.AI.Prompt.Shortcut.Key.studyPath)
        ]
        
        Logger.shared.info("Prompt configurations reset to default.")
    }

    /// 根据当前客户端界面语言动态生成的 AI 多语言回复 Prompt 指令
    public var languageInstruction: String {
        let langCode = Localized.currentLanguage
        return "\n\nPlease reply in the user's current locale language (\(langCode))."
    }
}

// MARK: - PromptService DependencyKey

private enum PromptServiceKey: DependencyKey {
    static var liveValue: PromptService {
        PromptService(defaults: .standard)
    }
    static let testValue: PromptService = {
        guard let defaults = UserDefaults(suiteName: "test") else {
            return PromptService(defaults: .standard)
        }
        return PromptService(defaults: defaults)
    }()
    static let previewValue: PromptService = PromptService(defaults: .standard)
}

extension DependencyValues {
    /// Prompt 服务依赖（原 PromptService.shared）
    public var promptService: PromptService {
        get { self[PromptServiceKey.self] }
        set { self[PromptServiceKey.self] = newValue }
    }
}

public struct ShortcutItem: Identifiable, Equatable, Codable {
    public var id = UUID()
    public var rawText: String
    public var localizationKey: String?
    
    public var text: String {
        get {
            if let key = localizationKey {
                return Localized.tr(key, table: "AI")
            }
            return rawText
        }
        set {
            rawText = newValue
            localizationKey = nil
        }
    }
    
    public init(text: String, localizationKey: String? = nil) {
        self.rawText = text
        self.localizationKey = localizationKey
    }
}
