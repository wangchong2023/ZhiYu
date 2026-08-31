//
//  L10n+Common.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 本地化层
//  核心职责：为 Common 模块提供本地化强类型字符串的访问扩展。
//
import Foundation

extension L10n {
    public static var SearchPlaceholder: String { Common.searchPlaceholder }

    public enum Common: L10nTableEntry {
        public static let tableName = "Common"
        public static var t: String { tableName }
        // MARK: - App Metadata
        public static var appName: String { tr("app.name") }
        public static var aiThinking: String { tr("aiThinking") }
        public static var configureAI: String { tr("configureAI") }
        public static var rename: String { tr("rename") }
        public static var appendToBody: String { tr("appendToBody") }
        
        // MARK: - Basic Actions
        public static var ok: String { tr("ok") }
        public static var cancel: String { tr("cancel") }
        public static var done: String { tr("done") }
        public static var select: String { tr("select") }
        public static var selectAll: String { tr("selectAll") }
        public static var deselectAll: String { tr("deselectAll") }
        public static var save: String { tr("save") }
        public static var delete: String { tr("delete") }
        public static var edit: String { tr("edit") }
        public static var refresh: String { tr("refresh") }
        public static var success: String { tr("success") }
        public static var failed: String { tr("failed") }
        public static var error: String { tr("error") }
        public static var logout: String { tr("logout") }
        public static var settings: String { tr("settings") }
        public static var help: String { tr("help") }
        public static var lock: String { tr("lock") }
        public static var usage: String { tr("menu.stats") }
        public static var skip: String { tr("skip") }
        public static var action: String { tr("action") }
        public static var confirm: String { tr("confirm") }
        public static var deleteConfirm: String { tr("deleteConfirm") }
        public static var ignore: String { tr("ignore") }
        public static var preview: String { tr("preview") }
        public static var quickPreview: String { tr("quickPreview") }
        public static var copyPageLink: String { tr("copyPageLink") }
        public static var copy: String { tr("misc.copy") }
        public static var syncToReminders: String { tr("syncToReminders") }
        public static var `import`: String { tr("misc.import") }
        public static var create: String { Localized.tr("logAction.create", table: t) }
        public static var deleteAll: String { Localized.tr("misc.deleteAll", table: t) }
        public static var bulkDelete: String { Localized.tr("misc.bulkDelete", table: t) }
        public static var close: String { Localized.tr("misc.close", table: t) }
        public static var reset: String { Localized.tr("misc.reset", table: t) }
        public static var correct: String { Localized.tr("misc.correct", table: t) }
        public static var incorrect: String { Localized.tr("misc.incorrect", table: t) }
        public static var nextQuestion: String { Localized.tr("misc.nextQuestion", table: t) }
        public static var viewResults: String { Localized.tr("misc.viewResults", table: t) }

        // MARK: - Generic States
        public static var loading: String { tr("loading") }
        public static var awesome: String { tr("awesome") }
        public static var recentUpdates: String { tr("recentUpdates") }
        public static var unitTenThousand: String { tr("unitTenThousand") }
        public static var searchPlaceholder: String { tr("searchPlaceholder") }
        public static var pinned: String { tr("pinned") }
        public static var yesterday: String { tr("yesterday") }
        public static var justNow: String { tr("justNow") }
        public static var about: String { tr("about") }
        public static var unknown: String { tr("unknown") }
        public static var testRunnerWorking: String { tr("common.testRunnerWorking") }
        public static var none: String { Localized.tr("misc.none", table: t) }
        public static var all: String { Localized.tr("misc.all", table: t) }

        public enum Error {
            public static var notFound: String { Common.tr("Error.notFound") }
        }

        public enum Status {
            public static var simulatorNotSupported: String { Common.tr("common.status.simulatorNotSupported") }
        }

        public enum Security {
            public static var title: String { Common.tr("security") }
            public static var unlockReason: String { Common.tr("security.unlockReason") }
            public static var unlockToView: String { Common.tr("security.unlockToView") }
            public static var privacyMasked: String { Common.tr("security.privacyMasked") }
            public static var unlock: String { Common.tr("security.unlock") }
            public static var unlockHint: String { Common.tr("security.unlockHint") }
            public static var vaultLocked: String { Common.tr("security.vaultLocked") }
        }

        public enum LogAction {
            public static var create: String { Common.tr("logAction.create") }
            public static var delete: String { Common.tr("misc.delete") }
            public static var update: String { Common.tr("logAction.update") }
            public static var ingest: String { Common.tr("logAction.ingest") }
        }

        public enum Stat {
            public static var newPages: String { Common.tr("stats.newPages") }
            public static var growth: String { Common.tr("stats.growth") }
            public static var title: String { Common.tr("stats.title") }
            public static var totalWords: String { Common.tr("stat.totalWords") }
        }
        
        public enum Stats {
            public static var newPages: String { Common.tr("stats.newPages") }
            public static var growth: String { Common.tr("stats.growth") }
            public static var title: String { Common.tr("stats.title") }
        }

        public enum Sidebar {
            public static var title: String { Common.tr("sidebar.title") }
            public static var weeklyInsight: String { Common.tr("sidebar.weeklyInsight") }
            public static var dashboard: String { Common.tr("sidebar.dashboard") }
            public static var allPages: String { Common.tr("sidebar.allPages") }
            public static var tags: String { Common.tr("accessibility.tags") }
            public static var trash: String { Common.tr("sidebar.trash") }
            public static var synthesis: String { Common.tr("tab.synthesis") }
            public static var system: String { Common.tr("sidebar.system") }
            public static var tools: String { Common.tr("tags.tools") }
            public static var capabilities: String { Common.tr("sidebar.capabilities") }
            public static var healthCheck: String { Common.tr("sidebar.healthCheck") }
            public static var knowledge: String { Common.tr("tab.knowledge") }
            public static var pageList: String { Common.tr("sidebar.pageList") }
            public static var universe: String { Common.tr("sidebar.universe") }
            public static var tagManager: String { Common.tr("sidebar.tagManager") }
            public static var plugins: String { Common.tr("sidebar.plugins") }
            public static var collaboration: String { Common.tr("sidebar.collaboration") }
        }

        public enum Tab {
            public static var knowledge: String { Common.tr("tab.knowledge") }
            public static var chat: String { Common.tr("tab.chat") }
            public static var graph: String { Common.tr("perf.summary.graph") }
            public static var synthesis: String { Common.tr("tab.synthesis") }
            public static var ingest: String { Common.tr("sources") }
            public static var settings: String { Common.tr("tab.settings") }
            public static var voice: String { Common.tr("tab.voice") }
            public static var pdf: String { Common.tr("tab.pdf") }
            public static var collab: String { Common.tr("tab.collab") }
            public static var search: String { Common.tr("components.search") }
        }

        public enum Global {
            public static var noData: String { Common.tr("common.noData") }
            public static var esc: String { Common.tr("esc") }
        }

        public enum Empty {

            /// 本地化翻译
            /// - Parameter key: key
            /// - Returns: 返回值
            public static func tr(_ key: String) -> String { Common.tr(key) }
            public static var noData: String { Common.tr("common.noData") }
        }

        public enum Log {
            public enum Status {
                public static var success: String { Common.tr("log.status.success") }
                public static var failure: String { Common.tr("log.status.failure") }
                public static var processing: String { Common.tr("log.status.processing") }
            }
        }

        public enum Perf {
            public static var title: String { Common.tr("perf.title") }
            public static var lastUpdated: String { Common.tr("perf.lastUpdated") }
            public static var memory: String { Common.tr("tags.memory") }
            public static var timing: String { Common.tr("perf.timing") }
                public static var pages: String { Common.tr("perf.summary.pages") }
            public static var words: String { Common.tr("perf.words") }
            public static var nodes: String { Common.tr("perf.nodes") }
            public static var load: String { Common.tr("perf.load") }
            public static var lint: String { Common.tr("action.healthCheck") }
            public static var graphLayout: String { Common.tr("perf.graphLayout") }
            public static var search: String { Common.tr("components.search") }
            public static var edges: String { Common.tr("perf.edges") }
            public static var save: String { Common.tr("perf.save") }
            public static var ragChain: String { Common.tr("perf.ragChain") }
            public static var llmCalls: String { Common.tr("perf.llmCalls") }
            public static var aiSuccessRate: String { Common.tr("perf.aiSuccessRate") }
            
            public enum summary {
                public static var title: String { Common.tr("perf.summary.title") }
                public static var search: String { Common.tr("components.search") }
                public static var pages: String { Common.tr("perf.summary.pages") }
                public static var words: String { Common.tr("perf.summary.words") }
                public static var nodes: String { Common.tr("perf.summary.nodes") }
                public static var edges: String { Common.tr("perf.summary.edges") }
                public static var load: String { Common.tr("perf.load") }
                public static var save: String { Common.tr("perf.summary.save") }
                public static var graph: String { Common.tr("perf.summary.graph") }
                public static var lint: String { Common.tr("action.healthCheck") }
                public static var memory: String { Common.tr("demo.memory.title") }
                public static var graphLayout: String { Common.tr("perf.graphLayout") }
            }
        }

        public enum Palette {
            public static var searchPlaceholder: String { Common.tr("palette.searchPlaceholder") }
        }

        public enum Splash {
            public static var appName: String { Common.tr("app.name") }
            public static var author: String { Common.tr("splash.author") }
            public static var enter: String { Common.tr("splash.enter") }
            public static var quote: String { Common.tr("splash.quote") }
            public static var title: String { Common.tr("app.name") }
        }

        public enum Spatial {
            public static var title: String { Common.tr("spatial.title") }
            public static var subtitle: String { Common.tr("spatial.subtitle") }
            public static var features: String { Common.tr("spatial.features") }
            public static var requirement: String { Common.tr("spatial.requirement") }
            
            public static var featureGraph3D: String { Feature.Graph3D.title }
            public static var featureGraph3DDesc: String { Feature.Graph3D.desc }
            public static var featureGaze: String { Feature.Gaze.title }
            public static var featureGazeDesc: String { Feature.Gaze.desc }
            public static var featureGesture: String { Feature.Gesture.title }
            public static var featureGestureDesc: String { Feature.Gesture.desc }
            public static var featureSpatialAudio: String { Feature.SpatialAudio.title }
            public static var featureSpatialAudioDesc: String { Feature.SpatialAudio.desc }

            public enum Feature {
                public enum Gaze {
                    public static var title: String { Common.tr("spatial.feature.gaze") }
                    public static var desc: String { Common.tr("spatial.feature.gaze.desc") }
                }
                public enum Gesture {
                    public static var title: String { Common.tr("spatial.feature.gesture") }
                    public static var desc: String { Common.tr("spatial.feature.gesture.desc") }
                }
                public enum SpatialAudio {
                    public static var title: String { Common.tr("spatial.feature.spatialAudio") }
                    public static var desc: String { Common.tr("spatial.feature.spatialAudio.desc") }
                }
                public enum Graph3D {
                    public static var title: String { Common.tr("spatial.feature.3dGraph") }
                    public static var desc: String { Common.tr("spatial.feature.3dGraph.desc") }
                }
            }
        }

        public enum Demo {
            public enum Welcome {
                public static var title: String { Common.tr("demo.welcome.title") }
                public static var content: String { Common.tr("demo.welcome.content") }
                public static var prompt: String { Common.tr("demo.welcome.prompt") }
                public static var tag1: String { Common.tr("demo.welcome.tag1") }
                public static var tag2: String { Common.tr("app.name") }
                public static var tag3: String { Common.tr("demo.welcome.tag3") }
                public static var cardTitle: String { Common.tr("demo.welcome.card.title") }
                public static var cardDesc: String { Common.tr("demo.welcome.card.desc") }
                public static var cardRecommend: String { Common.tr("demo.welcome.card.recommend") }
            }
            public enum aiAgent {
                public static var title: String { Common.tr("demo.aiAgent.title") }
                public static var content: String { Common.tr("demo.aiAgent.content") }
            }
            public enum planning {
                public static var title: String { Common.tr("demo.planning.title") }
                public static var content: String { Common.tr("demo.planning.content") }
            }
            public enum memory {
                public static var title: String { Common.tr("demo.memory.title") }
                public static var content: String { Common.tr("demo.memory.content") }
            }
            public enum toolUse {
                public static var title: String { Common.tr("demo.toolUse.title") }
                public static var content: String { Common.tr("demo.toolUse.content") }
            }
            public enum llm {
                public static var title: String { Common.tr("demo.llm.title") }
                public static var content: String { Common.tr("demo.llm.content") }
            }
            
            public enum memoryMgmt {
                public static var title: String { Common.tr("demo.memoryMgmt.title") }
                public static var content: String { Common.tr("demo.memoryMgmt.content") }
            }
            
            public enum toolchain {
                public static var title: String { Common.tr("demo.toolchain.title") }
                public static var content: String { Common.tr("demo.toolchain.content") }
            }
            
            public enum chunking {
                public static var title: String { Common.tr("demo.chunking.title") }
                public static var content: String { Common.tr("demo.chunking.content") }
            }
            
            public enum vectorDB {
                public static var title: String { Common.tr("demo.vectorDB.title") }
                public static var content: String { Common.tr("demo.vectorDB.content") }
            }
            
            public enum secureEnv {
                public static var title: String { Common.tr("demo.secureEnv.title") }
                public static var content: String { Common.tr("demo.secureEnv.content") }
            }
            
            public enum transformer {
                public static var title: String { Common.tr("demo.transformer.title") }
                public static var content: String { Common.tr("demo.transformer.content") }
            }
            
            public enum embedding {
                public static var title: String { Common.tr("demo.embedding.title") }
                public static var content: String { Common.tr("demo.embedding.content") }
            }
            
            public enum gateway {
                public static var title: String { Common.tr("demo.gateway.title") }
                public static var content: String { Common.tr("demo.gateway.content") }
            }
            
            public enum toolInterface {
                public static var title: String { Common.tr("demo.toolInterface.title") }
                public static var content: String { Common.tr("demo.toolInterface.content") }
            }
            
            public enum consistency {
                public static var title: String { Common.tr("demo.consistency.title") }
                public static var content: String { Common.tr("demo.consistency.content") }
            }
            
            public enum topology {
                public static var title: String { Common.tr("demo.topology.title") }
                public static var content: String { Common.tr("demo.topology.content") }
            }
            
            public enum hybridSearch {
                public static var title: String { Common.tr("demo.hybridSearch.title") }
                public static var content: String { Common.tr("demo.hybridSearch.content") }
            }
            
            // MARK: - 连接词 (用于国际化拼接)
            public static var relatedConcepts: String { Common.tr("demo.relatedConcepts") }
            public static var dependsOn: String { Common.tr("demo.dependsOn") }
            public static var core: String { Common.tr("demo.core") }
            public static var integratesWith: String { Common.tr("demo.integratesWith") }
            public static var foundation: String { Common.tr("demo.foundation") }
        }

        public enum Tags {
            public static var ai: String { Common.tr("tags.ai") }
            public static var agent: String { Common.tr("tags.agent") }
            public static var planning: String { Localized.tr("tags.planning", table: t) }
            public static var memory: String { Common.tr("demo.memory.title") }
            public static var rag: String { Common.tr("tags.rag") }
            public static var toolUse: String { Common.tr("tags.toolUse") }
            public static var llm: String { Common.tr("tags.llm") }
            public static var architecture: String { Common.tr("tags.architecture") }
            public static var tools: String { Common.tr("tags.tools") }
            public static var nlp: String { Common.tr("tags.nlp") }
            public static var storage: String { Common.tr("tags.storage") }
            public static var security: String { Common.tr("tags.security") }
            public static var theory: String { Common.tr("tags.theory") }
            public static var network: String { Common.tr("tags.network") }
            public static var `protocol`: String { Common.tr("tags.protocol") }
            public static var quality: String { Common.tr("tags.quality") }
            public static var visual: String { Common.tr("tags.visual") }
            public static var performance: String { Common.tr("tags.performance") }
        }

        public enum Misc {
            public static var correct: String { Localized.tr("misc.correct", table: t) }
            public static var incorrect: String { Localized.tr("misc.incorrect", table: t) }
            public static var nextQuestion: String { Localized.tr("misc.nextQuestion", table: t) }
            public static var viewResults: String { Localized.tr("misc.viewResults", table: t) }
            public static var create: String { Localized.tr("logAction.create", table: t) }
            public static var clear: String { Localized.tr("misc.clear", table: t) }
            public static var clearAll: String { Localized.tr("misc.clearAll", table: t) }
            public static var listSeparator: String { Localized.tr("misc.listSeparator", table: t) }
        public static var `import`: String { Localized.tr("misc.import", table: t) }
            public static var deleteAll: String { Localized.tr("misc.deleteAll", table: t) }
            public static var bulkDelete: String { Localized.tr("misc.bulkDelete", table: t) }
        }
    }

    public enum InitialNotebook: L10nTableEntry {
        public static let tableName = "Common"
        public static var t: String { tableName }
        
        public enum PKM {
            public static var title1: String { Localized.tr("demo.pkm.1.title", table: t) }
            public static var content1: String { Localized.tr("demo.pkm.1.content", table: t) }
            public static var title2: String { Localized.tr("demo.pkm.2.title", table: t) }
            public static var content2: String { Localized.tr("demo.pkm.2.content", table: t) }
            public static var title3: String { Localized.tr("demo.pkm.3.title", table: t) }
            public static var content3: String { Localized.tr("demo.pkm.3.content", table: t) }
            public static var title4: String { Localized.tr("demo.pkm.4.title", table: t) }
            public static var content4: String { Localized.tr("demo.pkm.4.content", table: t) }
            public static var title5: String { Localized.tr("demo.pkm.5.title", table: t) }
            public static var content5: String { Localized.tr("demo.pkm.5.content", table: t) }
        }
        
        public enum Coffee {
            public static var title1: String { Localized.tr("demo.coffee.1.title", table: t) }
            public static var content1: String { Localized.tr("demo.coffee.1.content", table: t) }
            public static var title2: String { Localized.tr("demo.coffee.2.title", table: t) }
            public static var content2: String { Localized.tr("demo.coffee.2.content", table: t) }
            public static var title3: String { Localized.tr("demo.coffee.3.title", table: t) }
            public static var content3: String { Localized.tr("demo.coffee.3.content", table: t) }
            public static var title4: String { Localized.tr("demo.coffee.4.title", table: t) }
            public static var content4: String { Localized.tr("demo.coffee.4.content", table: t) }
            public static var title5: String { Localized.tr("demo.coffee.5.title", table: t) }
            public static var content5: String { Localized.tr("demo.coffee.5.content", table: t) }
        }
        
        public enum Fallback {
            public static var methodology: String { Localized.tr("demo.fallback.methodology", table: t) }
            public static var workflow: String { Localized.tr("demo.fallback.workflow", table: t) }
            public static var luckin: String { Localized.tr("demo.fallback.luckin", table: t) }
            public static var survey: String { Localized.tr("demo.fallback.survey", table: t) }
        }
        
        public enum Snippet {
            public static var methodology: String { Localized.tr("demo.snippet.methodology", table: t) }
            public static var workflow: String { Localized.tr("demo.fallback.workflow", table: t) }
            public static var luckin: String { Localized.tr("demo.snippet.luckin", table: t) }
            public static var survey: String { Localized.tr("demo.snippet.survey", table: t) }
            public static var pkmRagLink: String { Localized.tr("demo.snippet.pkmRagLink", table: t) }
            public static var pkmVoiceForget: String { Localized.tr("demo.snippet.pkmVoiceForget", table: t) }
            public static var pkmClipboardFeynman: String { Localized.tr("demo.snippet.pkmClipboardFeynman", table: t) }
            public static var pkmOcrFolder: String { Localized.tr("demo.snippet.pkmOcrFolder", table: t) }
            public static var coffeeOcrManual: String { Localized.tr("demo.snippet.coffeeOcrManual", table: t) }
            public static var coffeeRagLink: String { Localized.tr("demo.snippet.coffeeRagLink", table: t) }
            public static var coffeeClipboardTeam: String { Localized.tr("demo.snippet.coffeeClipboardTeam", table: t) }
            public static var coffeeVoiceProcure: String { Localized.tr("demo.snippet.coffeeVoiceProcure", table: t) }
        }
        
        public enum FileNames {
            public static var methodology: String { Localized.tr("demo.filename.methodology", table: t) }
            public static var workflow: String { Localized.tr("demo.filename.workflow", table: t) }
            public static var luckin: String { Localized.tr("demo.filename.luckin", table: t) }
            public static var survey: String { Localized.tr("demo.filename.survey", table: t) }
            public static var ocrFolderScan: String { Localized.tr("demo.filename.ocrFolderScan", table: t) }
            public static var voiceNoteForget: String { Localized.tr("demo.filename.voiceNoteForget", table: t) }
            public static var ocrStoreManual: String { Localized.tr("demo.filename.ocrStoreManual", table: t) }
            public static var voiceNoteProcure: String { Localized.tr("demo.filename.voiceNoteProcure", table: t) }
        }
        
        public enum Log {
            public static var defaultDemoData: String { Localized.tr("demo.log.defaultDemoData", table: t) }
            public static var researchDemoData: String { Localized.tr("demo.log.researchDemoData", table: t) }
            public static var fallbackDemoData: String { Localized.tr("demo.log.fallbackDemoData", table: t) }
            public static var unknownVault: String { Localized.tr("demo.log.unknownVault", table: t) }
            public static var projectResearch: String { Localized.tr("demo.log.projectResearch", table: t) }
        }
        
        public enum Tags {
            public static var knowledgeMgmt: String { Localized.tr("tags.knowledgeMgmt", table: t) }
            public static var methodology: String { Localized.tr("tags.methodology", table: t) }
            public static var noteStyles: String { Localized.tr("tags.noteStyles", table: t) }
            public static var efficiency: String { Localized.tr("tags.efficiency", table: t) }
            public static var techPrinciple: String { Localized.tr("tags.techPrinciple", table: t) }
            public static var association: String { Localized.tr("tags.association", table: t) }
            public static var cognitivePsych: String { Localized.tr("tags.cognitivePsych", table: t) }
            public static var retrievalTech: String { Localized.tr("tags.retrievalTech", table: t) }
            public static var brainSci: String { Localized.tr("tags.brainSci", table: t) }
            public static var learningMethod: String { Localized.tr("tags.learningMethod", table: t) }
            public static var fileMgmt: String { Localized.tr("tags.fileMgmt", table: t) }
            public static var productivity: String { Localized.tr("tags.productivity", table: t) }
            public static var workflow: String { Localized.tr("tags.workflow", table: t) }
            public static var architectureOrg: String { Localized.tr("tags.architectureOrg", table: t) }
            public static var readingMethod: String { Localized.tr("tags.readingMethod", table: t) }
            public static var summary: String { Localized.tr("tags.summary", table: t) }
            public static var creation: String { Localized.tr("tags.creation", table: t) }
            public static var output: String { Localized.tr("tags.output", table: t) }
            public static var biography: String { Localized.tr("tags.biography", table: t) }
            public static var metaphor: String { Localized.tr("tags.metaphor", table: t) }
            public static var innovation: String { Localized.tr("tags.innovation", table: t) }
            
            public static var competitorAnalysis: String { Localized.tr("tags.competitorAnalysis", table: t) }
            public static var marketResearch: String { Localized.tr("tags.marketResearch", table: t) }
            public static var productDesign: String { Localized.tr("tags.productDesign", table: t) }
            public static var operation: String { Localized.tr("tags.operation", table: t) }
            public static var userResearch: String { Localized.tr("tags.userResearch", table: t) }
            public static var infrastructure: String { Localized.tr("tags.infrastructure", table: t) }
            public static var decoration: String { Localized.tr("tags.decoration", table: t) }
            public static var finance: String { Localized.tr("tags.finance", table: t) }
            public static var planning: String { Localized.tr("demo.planning.title", table: t) }
            public static var team: String { Localized.tr("tags.team", table: t) }
            public static var recruitment: String { Localized.tr("tags.recruitment", table: t) }
            public static var supplyChain: String { Localized.tr("tags.supplyChain", table: t) }
            public static var materials: String { Localized.tr("tags.materials", table: t) }
            public static var design: String { Localized.tr("tags.design", table: t) }
            public static var marketing: String { Localized.tr("tags.marketing", table: t) }
            public static var growth: String { Localized.tr("stats.growth", table: t) }
            public static var rd: String { Localized.tr("tags.rd", table: t) }
        }
    }
}
