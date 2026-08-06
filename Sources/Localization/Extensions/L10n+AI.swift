//
//  L10n+AI.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 AI 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public enum AI: L10nTableEntry {
        public static let tableName = "AI"
        public static var t: String { tableName }

        public enum Status {
            public static var analyzing: String { AI.tr("ai.status.analyzing") }
            public static var digging: String { AI.tr("ai.status.digging") }
            public static var extracting: String { AI.tr("ai.status.extracting") }
            public static var generating: String { AI.tr("ai.status.generating") }
            public static var organizing: String { AI.tr("ai.status.organizing") }
            public static var preprocessing: String { AI.tr("ai.status.preprocessing") }
            public static var scanning: String { AI.tr("ai.status.scanning") }
            public static var structuring: String { AI.tr("ai.status.structuring") }
            public static var synthesizing: String { AI.tr("ai.status.synthesizing") }
            public static var thinking: String { AI.tr("ai.status.thinking") }
            public static var visualizing: String { AI.tr("ai.status.visualizing") }

            /// indexing
            /// - Parameter current: current
            /// - Parameter total: total
            /// - Parameter filename: filename
            /// - Returns: 字符串
            public static func indexing(_ current: Int, _ total: Int, _ filename: String) -> String {
                AI.trf("ai.status.indexing", current, total, filename)
            }
        }

        public enum LLM {
            public static var title: String { AI.tr("llm.title") }
            public static var apiAddress: String { AI.tr("llm.apiAddress") }
            public static var apiKey: String { AI.tr("llm.apiKey") }
            public static var model: String { AI.tr("llm.model") }
            public static var status: String { AI.tr("llm.prompt.statusLabel") }
            public static var serviceStatus: String { AI.tr("llm.serviceStatus") }
            public static var providerConfig: String { AI.tr("llm.providerConfig") }
            public static var testConnection: String { AI.tr("llm.testConnection") }
            public static var testing: String { AI.tr("llm.testing") }
            public static var connectionSuccess: String { AI.tr("llm.connectionSuccess") }
            public static var validation: String { AI.tr("llm.validation") }
            public static var validationFailed: String { AI.tr("llm.validationFailed") }

            /// latency
            /// - Parameter value: value
            /// - Returns: 字符串
            public static func latency(_ value: String) -> String { AI.trf("llm.latency", value) }
            public static var configuration: String { AI.tr("llm.configuration") }
            public static var enableAssistant: String { AI.tr("llm.enableAssistant") }
            
            public enum Model {
                public static var preset: String { AI.tr("llm.model.preset") }
                public static var custom: String { AI.tr("llm.model.custom") }
            }

            public enum Validation {
                public static var emptyKey: String { AI.tr("llm.validation.emptyKey") }
                public static func prefixHint(_ prefix: String) -> String { AI.trf("llm.validation.prefixHint", prefix) }
                public static func lengthHint(_ minLen: Int) -> String { AI.trf("llm.validation.lengthHint", minLen) }
            }
            public static var chatHistory: String { AI.tr("llm.chatHistory") }
            public static var clearHistory: String { AI.tr("llm.clearHistory") }
            public static var chatSection: String { AI.tr("llm.chatSection") }
            public static var messages: String { AI.tr("llm.messages") }
            public static var infoString: String { AI.tr("llm.info") }

            public enum Provider {
                public static var title: String { AI.tr("llm.provider") }
                public static var openai: String { AI.tr("llm.provider.openai") }
                public static var anthropic: String { AI.tr("llm.provider.anthropic") }
                public static var deepseek: String { AI.tr("llm.provider.deepSeek") }
                public static var ollama: String { AI.tr("llm.provider.ollama") }
                public static var qwen: String { AI.tr("llm.provider.qwen") }
                public static var zhipu: String { AI.tr("llm.provider.zhipu") }
                public static var siliconflow: String { AI.tr("llm.provider.siliconflow") }
                public static var minimax: String { AI.tr("llm.provider.minimax") }
            }

            public enum Error {
                public static var invalidURL: String { AI.tr("llm.error.invalidURL") }
                public static var invalidResponse: String { AI.tr("llm.error.invalidResponse") }
                public static var httpError: String { AI.tr("llm.error.httpError") }
                public static var apiError: String { AI.tr("llm.error.apiError") }
                public static var rateLimited: String { AI.tr("llm.error.rateLimited") }
                public static var unauthorized: String { AI.tr("llm.error.unauthorized") }
                public static var notConfigured: String { AI.tr("llm.error.notConfigured") }
                public static var cancelled: String { AI.tr("llm.error.cancelled") }
            }

            public enum info {
                public static var localKey: String { AI.tr("llm.info.localKey") }
                public static var contextSent: String { AI.tr("llm.info.contextSent") }
                public static var openAICompatible: String { AI.tr("llm.info.openAICompatible") }
                public static var smartIngest: String { AI.tr("llm.info.smartIngest") }
            }

            public typealias prompt = Prompt
            public enum Prompt {
                public static var role: String { AI.tr("llm.prompt.role") }
                public static var duty1: String { AI.tr("llm.prompt.duty1") }
                public static var duty2: String { AI.tr("llm.prompt.duty2") }
                public static var duty3: String { AI.tr("llm.prompt.duty3") }
                public static var duty4: String { AI.tr("llm.prompt.duty4") }
                public static var rule1: String { AI.tr("llm.prompt.rule1") }
                public static var rule2: String { AI.tr("llm.prompt.rule2") }
                public static var rule3: String { AI.tr("llm.prompt.rule3") }
                public static var rule4: String { AI.tr("llm.prompt.rule4") }
                public static var rule5: String { AI.tr("llm.prompt.rule5") }
                public static var overview: String { AI.tr("llm.prompt.overview") }
                public static var totalPages: String { AI.tr("llm.prompt.totalPages") }
                public static var entityCount: String { AI.tr("llm.prompt.entityCount") }
                public static var conceptCount: String { AI.tr("llm.prompt.conceptCount") }
                public static var sourceCount: String { AI.tr("llm.prompt.sourceCount") }
                public static var entityList: String { AI.tr("llm.prompt.entityList") }
                public static var conceptList: String { AI.tr("llm.prompt.conceptList") }
                public static var sourceList: String { AI.tr("llm.prompt.sourceList") }
                public static var recentUpdates: String { AI.tr("llm.prompt.recentUpdates") }
                public static var relevantPages: String { AI.tr("llm.prompt.relevantPages") }
                public static var typeLabel: String { L10n.Common.tr("search.sort.type") }
                public static var relevanceScore: String { AI.tr("llm.prompt.relevanceScore") }
                public static var chunkType: String { AI.tr("llm.prompt.chunkType") }
                public static var pageTitle: String { L10n.Common.tr("pageTitle") }
                public static var issueDesc: String { AI.tr("llm.prompt.issueDesc") }
                public static var issueType: String { AI.tr("llm.prompt.issueType") }
                public static var pageContentSnippet: String { AI.tr("llm.prompt.pageContentSnippet") }
                public static var otherPageTitles: String { AI.tr("llm.prompt.otherPageTitles") }
            }

            public typealias ingest = Ingest
            public enum Ingest {
                public static var compileRules: String { AI.tr("llm.ingest.compileRules") }
                public static var compileInstruction: String { AI.tr("llm.ingest.compileInstruction") }
                public static var existingPages: String { AI.tr("llm.ingest.existingPages") }
                public static var rawTitle: String { AI.tr("llm.ingest.rawTitle") }
                public static var rawContent: String { AI.tr("llm.ingest.rawContent") }
                public static var jsonCompiledContent: String { AI.tr("llm.ingest.jsonCompiledContent") }
                public static var jsonSummary: String { AI.tr("llm.ingest.jsonSummary") }
                public static var jsonSuggestedTags: String { AI.tr("llm.ingest.jsonSuggestedTags") }
                public static var jsonFormat: String { AI.tr("llm.ingest.jsonFormat") }
                public static var systemPrompt: String { AI.tr("llm.ingest.systemPrompt") }
                public static var enrichSystemPrompt: String { AI.tr("llm.ingest.enrichSystemPrompt") }
                public static var rule1: String { AI.tr("llm.ingest.rule1") }
                public static var rule2: String { AI.tr("llm.ingest.rule2") }
                public static var rule3: String { AI.tr("llm.ingest.rule3") }
                public static var rule4: String { AI.tr("llm.ingest.rule4") }
                public static var rule5: String { AI.tr("llm.ingest.rule5") }
                public static var rule6: String { AI.tr("llm.ingest.rule6") }
            }
        }

        public enum OnDevice {
            public static var assistMode: String { AI.tr("ondevice.assistMode") }
            public static var assistDesc: String { AI.tr("ondevice.assistDesc") }
            public static var available: String { AI.tr("ondevice.available") }
            public static var unavailable: String { AI.tr("ondevice.unavailable") }
            public static var connected: String { AI.tr("ondevice.connected") }
            public static var statusReady: String { AI.tr("ondevice.status.ready") }
            public static var statusLoading: String { L10n.Common.tr("loading") }
            public static var appleIntelligence: String { AI.tr("ondevice.appleIntelligence") }
            public static var enableAutoScan: String { AI.tr("ondevice.enableAutoScan") }
            public static var autoRefactor: String { AI.tr("ondevice.autoRefactor") }
            
            public static var models: String { AI.tr("ondevice.models") }
            public static var loadModel: String { AI.tr("ondevice.loadModel") }
            public static var test: String { AI.tr("ondevice.test") }
            public static var info: String { AI.tr("llm.info") }
            public static var subtitle: String { AI.tr("ondevice.subtitle") }
            public static var supportsFoundation: String { AI.tr("ondevice.supportsFoundation") }
            public static var supportsCoreML: String { AI.tr("ondevice.supportsCoreML") }
            public static var requiresIOS17: String { AI.tr("ondevice.requiresIOS17") }
            public static var noModels: String { AI.tr("ondevice.noModels") }
            public static var modelLoaded: String { AI.tr("ondevice.modelLoaded") }
            public static var unload: String { AI.tr("ondevice.unload") }
            public static var importModel: String { AI.tr("ondevice.importModel") }
            public static var testGeneration: String { AI.tr("ondevice.testGeneration") }
            public static var inferenceSpeed: String { AI.tr("ondevice.inferenceSpeed") }
            public static var testPrompt: String { AI.tr("ondevice.testPrompt") }
            public static var generating: String { AI.tr("ondevice.generating") }
            public static var generate: String { AI.tr("ondevice.generate") }
            public static var result: String { AI.tr("ondevice.result") }
            public static var system: String { L10n.Common.tr("sidebar.system") }
            public static var local: String { AI.tr("ondevice.local") }

            public enum Info {
                public static var privacy: String { AI.tr("ondevice.info.privacy") }
                public static var offline: String { AI.tr("ondevice.info.offline") }
                public static var ne: String { AI.tr("ondevice.info.ne") }
                public static var memory: String { AI.tr("ondevice.info.memory") }
            }

            /// 端侧智能导入 Prompt 片段
            public enum Ingest {
                public static var compileToKnowledge: String { AI.tr("ondevice.ingest.compileToKnowledge") }
                public static var titleLabel: String { AI.tr("ondevice.ingest.title") }
                public static var contentLabel: String { AI.tr("ondevice.ingest.content") }
                public static var retainLinks: String { AI.tr("ondevice.ingest.linkAndFormat") }
            }

            /// error格式化
            /// - Parameter code: code
            /// - Returns: 字符串
            public static func errorFormat(_ code: String) -> String { L10n.Common.trf("ondevice.errorFormat", code) }

            public enum Error {
                public static var loadFailed: String { AI.tr("ondevice.error.loadFailed") }
                public static var compilationFailed: String { AI.tr("ondevice.error.compilationFailed") }
                public static var inferenceFailed: String { AI.tr("ondevice.error.inferenceFailed") }
                public static var modelNotFound: String { AI.tr("ondevice.error.modelNotFound") }
                public static var modelNotLoaded: String { AI.tr("ondevice.error.modelNotLoaded") }
                public static var notSupported: String { AI.tr("ondevice.error.notSupported") }
            }
        }

        public enum Eval {
            public static var systemPrompt: String { AI.tr("llm.eval.systemPrompt") }

            /// judgePrompt
            /// - Parameter context: context
            /// - Parameter query: query
            /// - Parameter answer: answer
            /// - Returns: 字符串
            public static func judgePrompt(_ context: String, _ query: String, _ answer: String) -> String {
                AI.trf("llm.eval.judgePrompt", context, query, answer)
            }
            
            public enum Status {
                public static var pass: String { AI.tr("llm.eval.status.pass") }
                public static var warning: String { AI.tr("llm.eval.status.warning") }
                public static var fail: String { AI.tr("llm.eval.status.fail") }
                public static var error: String { AI.tr("llm.eval.status.error") }
            }
        }

        public enum Prompt {
            public static func jailbreakError(_ pattern: String) -> String {
                AI.trf("prompt.jailbreakError", pattern)
            }
            public static var relevanceScore: String { AI.tr("llm.prompt.relevanceScore") }
            public static var chunkType: String { AI.tr("llm.prompt.chunkType") }
            public static var fixSuggestion: String { AI.tr("prompt.fixSuggestion") }
            public static var queryRewrite: String { AI.tr("prompt.queryRewrite") }
            public static var rerank: String { AI.tr("prompt.rerank") }
            public static var potentialLinks: String { AI.tr("prompt.potentialLinks") }
            public static var folding: String { AI.tr("prompt.folding") }
            public static var refactor: String { AI.tr("prompt.refactor") }
            public static var resetConfirm: String { AI.tr("prompt.resetConfirm") }
            public static var resetWarning: String { AI.tr("prompt.resetWarning") }
            public static var resetToDefault: String { AI.tr("prompt.resetToDefault") }
            public static func predictQuestions(_ history: String) -> String {
                AI.trf("prompt.predictQuestions", history)
            }

            /// 预测后续问题功能的 System Prompt（约束输出格式）
            public static var predictQuestionsSystem: String {
                AI.tr("prompt.predictQuestionsSystem")
            }

            public enum System {
                public static var summarize: String { AI.tr("prompt.system.summarize") }
                public static var mindmap: String { AI.tr("prompt.system.mindmap") }
                public static var actions: String { AI.tr("prompt.system.actions") }
                public static var slides: String { AI.tr("prompt.system.slides") }
                public static func quiz(_ quizTitle: String) -> String { AI.trf("prompt.system.quiz", quizTitle) }
                public static var infographic: String { AI.tr("prompt.system.infographic") }
                public static var report: String { AI.tr("prompt.system.report") }
                public static var expansion: String { AI.tr("prompt.system.expansion") }
                public static var suggestFix: String { AI.tr("prompt.system.suggestFix") }
                public static var insightQuestions: String { AI.tr("prompt.system.insightQuestions") }
            }

            // MARK: - L10n 净化后的 AI 提示词
            
            /// 搜索变体生成提示词
            public static var queryExpansion: String { AI.tr("prompt.queryExpansion") }
            
            /// 中文回复指令
            public static var replyInChinese: String { AI.tr("prompt.replyInChinese") }
            
            /// 摘要生成提示词前缀
            public static var summaryPrefix: String { AI.tr("prompt.summaryPrefix") }
            
            /// 反向提问生成提示词前缀
            public static var reverseQAPrefix: String { AI.tr("prompt.reverseQAPrefix") }
            
            /// 发现潜在链接提示词前缀 1
            public static var discoverLinksPrefix1: String { AI.tr("prompt.discoverLinksPrefix1") }
            
            /// 发现潜在链接提示词前缀 2
            public static var discoverLinksPrefix2: String { AI.tr("prompt.discoverLinksPrefix2") }

            /// Rerank 引擎系统提示词
            public static var rerankSystem: String { AI.tr("prompt.rerankSystem") }
            
            /// 生成 Rerank 用户提示词
            /// - Parameters:
            ///   - query: 原始查询问题
            ///   - context: 候选文本上下文
            /// - Returns: 格式化后的提示词字符串
            public static func rerankUserPrompt(query: String, context: String) -> String {
                AI.trf("prompt.rerankUserPrompt", query, context)
            }

            /// 延伸探讨推荐前缀标题
            public static var followUpHeader: String { AI.tr("prompt.followUpHeader") }

            /// 假设性回答 (HyDE) 系统提示词
            public static var hydeSystem: String { AI.tr("prompt.hydeSystem") }
            
            /// 生成假设性回答用户提示词
            /// - Parameter query: 原始查询问题
            /// - Returns: 格式化后的提示词字符串
            public static func hydeUserPrompt(query: String) -> String {
                AI.trf("prompt.hydeUserPrompt", query)
            }

            /// 知识导入管理助手角色描述
            public static var ingestManagementAssistant: String { AI.tr("prompt.ingestManagementAssistant") }
            
            /// 知识导入发现助手角色描述
            public static var ingestDiscoveryAssistant: String { AI.tr("prompt.ingestDiscoveryAssistant") }

            /// 内容增强：表格语义分析系统角色描述
            public static var enrichTableSystem: String { AI.tr("prompt.enrichTable.system") }
            /// 内容增强：表格语义分析用户 Prompt 模板（参数：表格 Markdown 文本）
            public static func enrichTableUser(_ table: String) -> String { AI.trf("prompt.enrichTable.user", table) }
            /// 内容增强：图片语义推断系统角色描述
            public static var enrichImageSystem: String { AI.tr("prompt.enrichImage.system") }
            /// 内容增强：图片语义推断用户 Prompt 模板（参数：alt 文本、URL）
            public static func enrichImageUser(alt: String, url: String) -> String { AI.trf("prompt.enrichImage.user", alt, url) }
            /// RAG 评估：评判 Prompt 模板（参数：源列表、源总数、展示数、上下文、查询、回答）
            public static func ragJudgePrompt(sourceList: String, sourceCount: Int, displayCount: Int, context: String, query: String, answer: String) -> String {
                AI.trf("prompt.ragEval.judge", sourceList, sourceCount, displayCount, context, query, answer)
            }

            public enum QueryRewrite {
                public static var instruction: String { AI.tr("prompt.queryRewrite.instruction") }
                public static var rules: String { AI.tr("prompt.queryRewrite.rules") }
                public static var rule1: String { AI.tr("prompt.queryRewrite.rule1") }
                public static var rule2: String { AI.tr("prompt.queryRewrite.rule2") }
                public static var rule3: String { AI.tr("prompt.queryRewrite.rule3") }
                public static var rule4: String { AI.tr("prompt.queryRewrite.rule4") }
                public static var userQuery: String { AI.tr("prompt.queryRewrite.userQuery") }
                public static var footer: String { AI.tr("prompt.queryRewrite.footer") }
            }

            public enum Quiz {
                public static var defaultTitle: String { AI.tr("prompt.expert.quiz.title") }
                public static var question: String { AI.tr("ondevice.chatQuestion") }
                public static var option: String { AI.tr("prompt.quiz.option") }
                public static var explanation: String { AI.tr("prompt.quiz.explanation") }
            }

            public enum Expert {
                public enum Mindmap {
                    public static var title: String { AI.tr("prompt.expert.mindmap.title") }
                    public static var footer: String { AI.tr("prompt.expert.mindmap.footer") }
                }
                public enum Quiz {
                    public static var title: String { AI.tr("prompt.expert.quiz.title") }
                    public static var footer: String { AI.tr("prompt.expert.quiz.footer") }
                }
                public enum Slides {
                    public static var title: String { AI.tr("prompt.expert.slides.title") }
                    public static var footer: String { AI.tr("prompt.expert.slides.footer") }
                }
                public enum Report {
                    public static var title: String { AI.tr("prompt.expert.report.title") }
                    public static var footer: String { AI.tr("prompt.expert.report.footer") }
                }
                public enum Infographic {
                    public static var title: String { AI.tr("prompt.expert.infographic.title") }
                    public static var footer: String { AI.tr("prompt.expert.infographic.footer") }
                }
                public enum Expansion {
                    public static var title: String { AI.tr("prompt.expert.expansion.title") }
                    public static var footer: String { AI.tr("prompt.expert.expansion.footer") }
                }
            }

            public enum Default {
                public static var mindmap: String { AI.tr("prompt.default.mindmap") }
                public static var quiz: String { AI.tr("prompt.default.quiz") }
                public static var slides: String { AI.tr("prompt.default.slides") }
                public static var summary: String { AI.tr("prompt.default.summary") }
                public static var actions: String { AI.tr("prompt.default.actions") }
                public static var infographic: String { AI.tr("prompt.default.infographic") }
                public static var insightQuestions: String { AI.tr("prompt.default.insightQuestions") }
                public static var report: String { AI.tr("prompt.default.report") }
                public static var expansion: String { AI.tr("prompt.default.expansion") }
            }

            public enum Shortcut {
                public static var deepReview: String { AI.tr("prompt.shortcut.deepReview") }
                public static var findGaps: String { AI.tr("prompt.shortcut.findGaps") }
                public static var studyPath: String { AI.tr("prompt.shortcut.studyPath") }

                public enum Key {
                    public static let deepReview: String = "prompt.shortcut.deepReview"
                    public static let findGaps: String = "prompt.shortcut.findGaps"
                    public static let studyPath: String = "prompt.shortcut.studyPath"
                }
            }

            public enum reset {
                public static var factory: String { AI.tr("prompt.reset.factory") }
            }

            public typealias factory = Factory
            public enum Factory {
                public static var title: String { AI.tr("prompt.factory.title") }
            }

            public typealias workshop = Workshop
            public enum Workshop {
                public static var add: String { AI.tr("prompt.workshop.add") }
                
                public enum Intro {
                    public static var title: String { AI.tr("prompt.factory.title") }
                    public static var desc: String { AI.tr("prompt.workshop.intro.desc") }
                }
                public enum shortcuts {
                    public static var title: String { AI.tr("prompt.workshop.shortcuts.title") }
                    public static var footer: String { AI.tr("prompt.workshop.shortcuts.footer") }
                }
                public enum input {
                    public static var placeholder: String { AI.tr("prompt.workshop.input.placeholder") }
                }
            }
        }

        public enum Synthesis {
            public static var title: String { AI.tr("aitask.guide.synthesis") }
            public static var sidebarTitle: String { L10n.Common.Sidebar.synthesis }
            public static var limitReachedWarning: String { AI.tr("synthesis.limitReachedWarning") }
            public static var batchDeleteConfirm: String { AI.tr("synthesis.batchDeleteConfirm") }
            public static var clearAllConfirm: String { AI.tr("synthesis.clearAllConfirm") }
            public static var noDocs: String { AI.tr("synthesis.noDocs") }
            public static var documentList: String { AI.tr("synthesis.documentList") }
            public static var actions: String { AI.tr("synthesis.actions") }
            public static var citationInstruction: String { AI.tr("synthesis.citationInstruction") }
            public static func sourceCount(_ n: Int) -> String { AI.trf("synthesis.sourceCount_%d", n) }

            public enum Actions {
                public static var polish: String { AI.tr("synthesis.actions.polish") }
                public static var regenerate: String { AI.tr("synthesis.actions.regenerate") }
            }

            public enum Control {
                public static var title: String { AI.tr("synthesis.control.title") }
                public static var depth: String { AI.tr("synthesis.control.depth") }
                public static var audience: String { AI.tr("synthesis.control.audience") }
                public static var tone: String { AI.tr("synthesis.control.tone") }
                public static var customPromptTitle: String { AI.tr("synthesis.control.customPromptTitle") }
                public static var startSynthesis: String { AI.tr("synthesis.control.startSynthesis") }
                public static func describeSynthesisType(_ title: String) -> String { AI.trf("synthesis.control.describeType_%@", title) }

                public enum Depth {
                    public static var concise: String { AI.tr("synthesis.control.depth.concise") }
                    public static var standard: String { AI.tr("synthesis.control.depth.standard") }
                    public static var detailed: String { AI.tr("synthesis.control.depth.detailed") }
                }
                public enum Audience {
                    public static var beginner: String { AI.tr("synthesis.control.audience.beginner") }
                    public static var professional: String { AI.tr("synthesis.control.audience.professional") }
                    public static var executive: String { AI.tr("synthesis.control.audience.executive") }
                }
                public enum Tone {
                    public static var academic: String { AI.tr("synthesis.control.tone.academic") }
                    public static var professional: String { AI.tr("synthesis.control.tone.professional") }
                    public static var casual: String { AI.tr("synthesis.control.tone.casual") }
                }
                public enum Placeholder {
                    public static var mindmap: String { AI.tr("synthesis.control.placeholder.mindmap") }
                    public static var slides: String { AI.tr("synthesis.control.placeholder.slides") }
                    public static var quiz: String { AI.tr("synthesis.control.placeholder.quiz") }
                    public static var report: String { AI.tr("synthesis.control.placeholder.report") }
                    public static var infographic: String { AI.tr("synthesis.control.placeholder.infographic") }
                    public static var expansion: String { AI.tr("synthesis.control.placeholder.expansion") }
                }
                public enum Instruction {
                    public static func depthConcise(_ minWords: Int, _ maxWords: Int) -> String { AI.trf("synthesis.control.instruction.depthConcise_%d_%d", minWords, maxWords) }
                    public static func depthStandard(_ minWords: Int, _ maxWords: Int) -> String { AI.trf("synthesis.control.instruction.depthStandard_%d_%d", minWords, maxWords) }
                    public static func depthDetailed(_ minWords: Int, _ maxWords: Int) -> String { AI.trf("synthesis.control.instruction.depthDetailed_%d_%d", minWords, maxWords) }
                    public static var audienceBeginner: String { AI.tr("synthesis.control.instruction.audienceBeginner") }
                    public static var audienceProfessional: String { AI.tr("synthesis.control.instruction.audienceProfessional") }
                    public static var audienceExecutive: String { AI.tr("synthesis.control.instruction.audienceExecutive") }
                    public static var toneAcademic: String { AI.tr("synthesis.control.instruction.toneAcademic") }
                    public static var toneProfessional: String { AI.tr("synthesis.control.instruction.toneProfessional") }
                    public static var toneCasual: String { AI.tr("synthesis.control.instruction.toneCasual") }
                    public static func customPrompt(_ prompt: String) -> String { AI.trf("synthesis.control.instruction.customPrompt_%@", prompt) }
                }
            }
            
            public enum Mindmap {
                public static var title: String { AI.tr("prompt.expert.mindmap.title") }
                public static var renderError: String { AI.tr("synthesis.mindmap.renderError") }
                public static var defaultBranch1: String { AI.tr("synthesis.mindmap.defaultBranch1") }
                public static var defaultBranch2: String { AI.tr("synthesis.mindmap.defaultBranch2") }
            }

            public enum Error {
                public static var limitReached: String { AI.tr("synthesis.error.limitReached") }
                public static var noPages: String { AI.tr("synthesis.error.noPages") }
                public static var invalidResult: String { AI.tr("synthesis.error.invalidResult") }
                public static var pageNotFound: String { AI.tr("synthesis.error.pageNotFound") }
            }

            public enum Fallback {
                public static var slidesHeader: String { AI.tr("synthesis.fallback.slidesHeader") }
                public static var coreConcept: String { AI.tr("synthesis.fallback.coreConcept") }
                public static var reportOverview: String { AI.tr("synthesis.fallback.reportOverview") }
                public static var reportKeyPoints: String { AI.tr("synthesis.fallback.reportKeyPoints") }
                public static func reportPointItem(_ index: Int, _ text: String) -> String { AI.trf("synthesis.fallback.reportPointItem", index, text) }
                public static var reportSummaryHeader: String { AI.tr("synthesis.fallback.reportSummaryHeader") }
                public static var reportSummaryBody: String { AI.tr("synthesis.fallback.reportSummaryBody") }
                public static var expansionBackground: String { AI.tr("synthesis.fallback.expansionBackground") }
                public static var expansionBackgroundBody: String { AI.tr("synthesis.fallback.expansionBackgroundBody") }
                public static var expansionDetailsHeader: String { AI.tr("synthesis.fallback.expansionDetailsHeader") }
                public static func expansionDetailItem(_ index: Int, _ text: String) -> String { AI.trf("synthesis.fallback.expansionDetailItem", index, text) }
                public static var expansionFutureBody: String { AI.tr("synthesis.fallback.expansionFutureBody") }

                // 演示文稿回退
                public static var slidesSubtitle: String { AI.tr("synthesis.fallback.slidesSubtitle") }
                public static func expansionPointTitle(_ index: Int) -> String { AI.trf("synthesis.fallback.expansionPointTitle", index) }
                public static var expansionBullet1: String { AI.tr("synthesis.fallback.expansionBullet1") }
                public static var expansionBullet2: String { AI.tr("synthesis.fallback.expansionBullet2") }
                public static var slideBullet1: String { AI.tr("synthesis.fallback.slideBullet1") }
                public static var slideBullet2: String { AI.tr("synthesis.fallback.slideBullet2") }
                public static var coreAnalysis: String { AI.tr("synthesis.fallback.coreAnalysis") }
                public static var summaryReview: String { AI.tr("synthesis.fallback.summaryReview") }

                // 知识扩充回退
                public static var expansionSection1: String { AI.tr("synthesis.fallback.expansionSection1") }
                public static var expansionSection2: String { AI.tr("synthesis.fallback.expansionSection2") }
                public static var expansionSection3: String { AI.tr("synthesis.fallback.expansionSection3") }
                public static var expansionSection4: String { AI.tr("synthesis.fallback.expansionSection4") }
                public static var expansionBackgroundHeader: String { AI.tr("synthesis.fallback.expansionBackgroundHeader") }
                public static var expansionFiller: String { AI.tr("synthesis.fallback.expansionFiller") }

                // Quiz 回退（通用占位提示，不硬编码领域知识）
                public static func quizInsufficientTitle(_ topic: String) -> String { AI.trf("synthesis.fallback.quizInsufficientTitle", topic) }
                public static var quizInsufficientQuestion: String { AI.tr("synthesis.fallback.quizInsufficientQuestion") }
                public static var quizInsufficientExplanation: String { AI.tr("synthesis.fallback.quizInsufficientExplanation") }

                public static var chatterPrefixes: [String] {
                    [
                        AI.tr("synthesis.chatter.hereIs"),
                        AI.tr("synthesis.chatter.heres"),
                        AI.tr("synthesis.chatter.hereAre"),
                        AI.tr("synthesis.chatter.belowIs"),
                        AI.tr("synthesis.chatter.belowAre"),
                        AI.tr("synthesis.chatter.thisIs"),
                        AI.tr("synthesis.chatter.followingIs"),
                        AI.tr("synthesis.chatter.asRequested"),
                        AI.tr("synthesis.chatter.parsedAs"),
                        AI.tr("synthesis.chatter.belowChinese"),
                        AI.tr("synthesis.chatter.asFollowsChinese")
                    ]
                }

                /// 所有支持语言下的 chatter 前缀集合（去重）。
                ///
                /// 用于匹配 LLM 输出中可能出现的多语言前导废话。
                /// 无论用户当前系统语言为何，均覆盖全部语种翻译，
                /// 避免系统中文环境下漏匹配 LLM 英文输出 "Here is the summary:"。
                public static var allChatterPrefixes: [String] {
                    let keys = [
                        "synthesis.chatter.hereIs",
                        "synthesis.chatter.heres",
                        "synthesis.chatter.hereAre",
                        "synthesis.chatter.belowIs",
                        "synthesis.chatter.belowAre",
                        "synthesis.chatter.thisIs",
                        "synthesis.chatter.followingIs",
                        "synthesis.chatter.asRequested",
                        "synthesis.chatter.parsedAs",
                        "synthesis.chatter.belowChinese",
                        "synthesis.chatter.asFollowsChinese"
                    ]
                    return keys.flatMap { Localized.allValues(forKey: $0, table: "AI") }
                }
            }
        }

        public enum Task {
            public static let t = "AI"

            /// 本地化翻译
            /// - Parameter key: key
            /// - Returns: 返回值
            public static func tr(_ key: String) -> String { Localized.tr("aitask." + key, table: t) }

            /// 本地化格式化翻译
            /// - Parameter key: key
            /// - Parameter args: args
            /// - Returns: 返回值
            public static func trf(_ key: String, _ args: CVarArg...) -> String { Localized.trf("aitask." + key, table: t, args) }
            
            public static var running: String { Localized.tr("aitask.status.running", table: t) }
            public static var processing: String { Localized.tr("aitask.processing", table: t) }
            public static var typeIngest: String { Localized.tr("aitask.type.ingest", table: t) }
            public static var typeHealthCheck: String { Localized.tr("aitask.type.healthCheck", table: t) }
            public static var typeAIScan: String { Localized.tr("aitask.guide.aiscan", table: t) }
            public static var typeSynthesis: String { Localized.tr("aitask.type.synthesis", table: t) }
            
            public static var categories: String { Localized.tr("aitask.categories", table: t) }
            public static var noHistory: String { Localized.tr("aitask.noHistory", table: t) }
            public static var listTitle: String { Localized.tr("aitask.list.title", table: t) }
            public static var clearConfirmTitle: String { Localized.tr("aitask.clearConfirmTitle", table: t) }
            public static var clearConfirmMessage: String { Localized.tr("aitask.clearConfirmMessage", table: t) }
            public static var howToTrigger: String { Localized.tr("aitask.howToTrigger", table: t) }
            
            public static var guideHealth: String { Localized.tr("aitask.guide.health", table: t) }
            public static var guideHealthDesc: String { Localized.tr("aitask.guide.health.desc", table: t) }
            public static var guideAIScan: String { Localized.tr("aitask.guide.aiscan", table: t) }
            public static var guideAIScanDesc: String { Localized.tr("aitask.guide.aiscan.desc", table: t) }
            public static var guideIngest: String { Localized.tr("aitask.guide.ingest", table: t) }
            public static var guideIngestDesc: String { Localized.tr("aitask.guide.ingest.desc", table: t) }
            public static var guideSynthesis: String { Localized.tr("aitask.guide.synthesis", table: t) }
            public static var guideSynthesisDesc: String { Localized.tr("aitask.guide.synthesis.desc", table: t) }
            
            public static var statusPending: String { Localized.tr("aitask.status.pending", table: t) }
            public static var statusCompleted: String { Localized.tr("aitask.status.completed", table: t) }
            public static var statusFailed: String { Localized.tr("aitask.status.failed", table: t) }

            /// historyCount
            public static func historyCount(_ count: Int) -> String {
                Localized.trf("aitask.history.count", table: t, count)
            }

            public static var centerTitle: String { Localized.tr("aitask.center.title", table: t) }
            public static var emptyTitle: String { Status.emptyTitle }
            public static var emptyDesc: String { Status.emptyDesc }
            
            /// starting
            /// - Parameter name: name
            /// - Parameter target: target
            /// - Returns: 字符串
            public static func starting(_ name: String, _ target: String) -> String {
                Localized.trf("aitask.status.startingFormat", table: t, name, target)
            }

            /// running
            /// - Parameter name: name
            /// - Parameter target: target
            /// - Returns: 字符串
            public static func running(_ name: String, _ target: String) -> String {
                Localized.trf("aitask.status.runningFormat", table: t, name, target)
            }

            /// completed
            /// - Parameter name: name
            /// - Returns: 字符串
            public static func completed(_ name: String) -> String {
                Localized.trf("aitask.status.completedFormat", table: t, name)
            }

            /// failed
            /// - Parameter name: name
            /// - Returns: 字符串
            public static func failed(_ name: String) -> String {
                Localized.trf("aitask.status.failedFormat", table: t, name)
            }

            public enum Status {
                public static let t = "AI"
                public static var ready: String { Localized.tr("aitask.status.ready", table: t) }
                public static var running: String { Localized.tr("aitask.status.running", table: t) }
                public static var emptyTitle: String { Localized.tr("aitask.empty.title", table: t) }
                public static var emptyDesc: String { Localized.tr("aitask.empty.desc", table: t) }
            }

            /// AI 异步合成任务专属无障碍本地化定义
            public enum Accessibility {
                public static let t = "AI"
                
                /// 骨架屏占位描述标签
                public static var skeletonLabel: String { Localized.tr("ai.accessibility.skeletonLabel", table: t) }
                
                /// 任务运行中的无障碍基础声明
                public static var taskInProgress: String { Localized.tr("ai.accessibility.taskInProgress", table: t) }
                
                /// 任务圆满完成的主动公告文案模板
                public static func taskFinishedAnnouncement(_ name: String) -> String {
                    Localized.trf("ai.accessibility.taskFinishedAnnouncement", table: t, name)
                }
                
                /// 任务不幸失败的主动公告文案模板
                public static func taskFailedAnnouncement(_ name: String) -> String {
                    Localized.trf("ai.accessibility.taskFailedAnnouncement", table: t, name)
                }
                
                /// 动态进度及执行阶段拼接模板
                public static func progressValue(_ percent: Int, _ stage: String) -> String {
                    Localized.trf("ai.accessibility.progressValueFormat", table: t, percent, stage)
                }
            }
        }
    }
}
