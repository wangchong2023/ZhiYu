//
//  L10n+ModelManager.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/05.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：本地大模型管理模块的国际化词条扩展
//

import Foundation
import UFPCore

extension L10n {
    public enum ModelManager: L10nTableEntry {
        public static let tableName = "ModelManager"
        public static var t: String { tableName }
        // MARK: - Tab 标题

        public static var storeTitle: String {
            ModelManager.tr("model_manager.store.title")
        }

        public static var parametersTitle: String {
            ModelManager.tr("model_manager.parameters.title")
        }

        public static var serversTitle: String {
            ModelManager.tr("model_manager.servers.title")
        }

        public static var routingTitle: String {
            ModelManager.tr("model_manager.routing.strategy.smart_routing")
        }

        // MARK: - 卡片组件

        public enum Card {
            /// 模型供应商名称
            /// - Parameter name: 供应商名称
            /// - Returns: 格式化的供应商文本
            public static func vendor(_ name: String) -> String {
                ModelManager.trf("model_manager.card.vendor", name)
            }

            /// 模型大小
            /// - Parameter gb: 大小（GB）
            /// - Returns: 格式化的大小文本
            public static func size(_ gb: String) -> String {
                ModelManager.trf("model_manager.card.size", gb)
            }

            public static var ready: String {
                ModelManager.tr("model_manager.card.ready")
            }

            public static var activated: String {
                ModelManager.tr("model_manager.card.activated")
            }

            public static var activate: String {
                ModelManager.tr("model_manager.card.activate")
            }

            public static var download: String {
                ModelManager.tr("model_manager.card.download")
            }

            public static var pause: String {
                ModelManager.tr("model_manager.card.pause")
            }

            public static var resume: String {
                ModelManager.tr("model_manager.card.resume")
            }

            public static var cancel: String {
                ModelManager.tr("model_manager.card.cancel")
            }

            public static var unavailable: String {
                ModelManager.tr("model_manager.card.unavailable")
            }

            public static var warningLowMemory: String {
                ModelManager.tr("model_manager.card.warning_low_memory")
            }

            public static var learnMore: String {
                ModelManager.tr("model_manager.card.learnMore")
            }

            public static func etaFormat(_ eta: String) -> String {
                ModelManager.trf("model_manager.card.eta_format", eta)
            }
        }

        // MARK: - 顶部摘要

        public enum Header {
            public static var availableModels: String { ModelManager.tr("model_manager.header.availableModels") }
        }

        // MARK: - 任务标签

        public enum Task {
            public static var chat: String { ModelManager.tr("model_manager.task.chat") }
            public static var completion: String { ModelManager.tr("model_manager.task.completion") }
            public static var reasoning: String { ModelManager.tr("model_manager.task.reasoning") }
            public static var code: String { ModelManager.tr("model_manager.task.code") }
            public static var rag: String { ModelManager.tr("model_manager.task.rag") }
            public static var translation: String { ModelManager.tr("model_manager.task.translation") }
            public static var multimodal: String { ModelManager.tr("model_manager.task.multimodal") }
            public static var mediaSearch: String { ModelManager.tr("model_manager.task.media_search") }
            public static var videoSearch: String { ModelManager.tr("model_manager.task.video_search") }
        }

        // MARK: - 规格详表（Model Spec Sheet）

        public enum Spec {
            public static var memory: String { ModelManager.tr("model_manager.spec.memory") }
            public static var downloadSize: String { ModelManager.tr("model_manager.spec.downloadSize") }
            public static var parameters: String { ModelManager.tr("model_manager.spec.parameters") }
            public static var checksum: String { ModelManager.tr("model_manager.spec.checksum") }
            public static var tasks: String { ModelManager.tr("model_manager.spec.tasks") }
            public static var quantization: String { ModelManager.tr("model_manager.spec.quantization") }
            public static var runtimeEngine: String { ModelManager.tr("model_manager.spec.runtime_engine") }
            public static var sandboxPath: String { ModelManager.tr("model_manager.spec.sandbox_path") }
            public static var reloadModel: String { ModelManager.tr("model_manager.spec.reload_model") }
            public static var clearCache: String { ModelManager.tr("model_manager.spec.clear_cache") }
            public static var reloadSuccess: String { ModelManager.tr("model_manager.spec.reload_success") }
            public static var cacheCleared: String { ModelManager.tr("model_manager.spec.cache_cleared") }
        }

        // MARK: - 参数调节

        public enum Parameters {
            public static var temperature: String {
                ModelManager.tr("model_manager.params.temperature")
            }

            public static var topP: String {
                ModelManager.tr("model_manager.params.top_p")
            }

            public static var topK: String {
                ModelManager.tr("model_manager.params.top_k")
            }

            public static var maxTokens: String {
                ModelManager.tr("model_manager.params.max_tokens")
            }

            public static var presetCreative: String {
                ModelManager.tr("model_manager.params.preset.creative")
            }

            public static var presetBalanced: String {
                ModelManager.tr("model_manager.params.preset.balanced")
            }

            public static var presetPrecise: String {
                ModelManager.tr("model_manager.params.preset.precise")
            }

            public static var custom: String { ModelManager.tr("model_manager.params.custom") }

            public static var resetToDefaults: String {
                ModelManager.tr("model_manager.params.reset")
            }

            public static var saveConfiguration: String {
                ModelManager.tr("model_manager.params.save")
            }

            public static var currentModel: String {
                ModelManager.tr("model_manager.params.current_model")
            }

            public static var presetTemplate: String {
                ModelManager.tr("model_manager.params.preset_template")
            }

            public static var tipTemperature: String {
                ModelManager.tr("model_manager.params.tip.temperature")
            }

            public static var tipTopP: String {
                ModelManager.tr("model_manager.params.tip.top_p")
            }

            public static var tipTopK: String {
                ModelManager.tr("model_manager.params.tip.top_k")
            }

            public static var tipMaxTokens: String {
                ModelManager.tr("model_manager.params.tip.max_tokens")
            }

            public static var selectModel: String {
                ModelManager.tr("model_manager.lab.select_model")
            }

            public static var reset: String {
                ModelManager.tr("model_manager.params.reset")
            }

            public static var save: String {
                ModelManager.tr("model_manager.params.save")
            }
        }

        // MARK: - 服务器配置

        public enum Server {
            public static var addServer: String {
                ModelManager.tr("model_manager.server.add")
            }

            public static var editServer: String {
                ModelManager.tr("model_manager.server.edit")
            }

            public static var testConnection: String {
                ModelManager.tr("model_manager.server.test")
            }

            public static var deleteServer: String {
                ModelManager.tr("model_manager.server.delete")
            }

            public static var setDefault: String {
                ModelManager.tr("model_manager.server.set_default")
            }

            /// 服务器延迟
            /// - Parameter ms: 延迟时间（毫秒）
            /// - Returns: 格式化的延迟文本
            public static func latency(_ ms: Int) -> String {
                ModelManager.trf("model_manager.server.latency", ms)
            }

            public static var emptyTitle: String {
                ModelManager.tr("model_manager.server.empty.title")
            }

            public static var emptySubtitle: String {
                ModelManager.tr("model_manager.server.empty.subtitle")
            }

            public static var serverName: String {
                ModelManager.tr("model_manager.server.form.name_label")
            }

            public static var serverURL: String {
                ModelManager.tr("model_manager.server.form.url_label")
            }

            public static var apiKey: String {
                ModelManager.tr("model_manager.server.api_key")
            }

            /// 最后测试时间
            /// - Parameter date: 格式化的日期字符串
            /// - Returns: 格式化的测试时间文本
            public static func lastTested(_ date: String) -> String {
                ModelManager.trf("model_manager.server.last_tested", date)
            }

            /// 服务器延迟（毫秒）
            /// - Parameter ms: 延迟时间（毫秒）
            /// - Returns: 格式化的延迟文本
            public static func latencyMs(_ ms: Int) -> String {
                ModelManager.trf("model_manager.server.latency_ms", ms)
            }

            public static var editAction: String {
                ModelManager.tr("model_manager.server.edit_action")
            }

            public static var deleteAction: String {
                ModelManager.tr("model_manager.server.delete_action")
            }

            public static var setDefaultAction: String {
                ModelManager.tr("model_manager.server.set_default_action")
            }

            public static var formNameLabel: String {
                ModelManager.tr("model_manager.server.form.name_label")
            }

            public static var formURLLabel: String {
                ModelManager.tr("model_manager.server.form.url_label")
            }

            public static var formAPIKeyLabel: String {
                ModelManager.tr("model_manager.server.form.api_key_label")
            }

            public static var formSetDefault: String {
                ModelManager.tr("model_manager.server.form.set_default")
            }

            public static var formEnableSSL: String {
                ModelManager.tr("model_manager.server.form.enable_ssl")
            }

            public static var testSuccess: String {
                ModelManager.tr("model_manager.server.test_success")
            }

            public static var formAddTitle: String {
                ModelManager.tr("model_manager.server.add")
            }

            public static var formEditTitle: String {
                ModelManager.tr("model_manager.server.edit")
            }

            public static var formCancel: String {
                ModelManager.tr("model_manager.server.form.cancel")
            }

            public static var formSave: String {
                ModelManager.tr("model_manager.server.form.save")
            }

            public static var testResult: String {
                ModelManager.tr("model_manager.server.test_result")
            }

            public static var mockLocalDev: String {
                ModelManager.tr("model_manager.server.mock_local_dev")
            }
        }

        // MARK: - 智能路由

        public enum Routing {
            public static var onlineEscalation: String {
                ModelManager.tr("model_manager.routing.online_escalation")
            }

            public static var modelStrategy: String {
                ModelManager.tr("model_manager.routing.modelStrategy")
            }

            public static var runtimeStatus: String {
                ModelManager.tr("model_manager.routing.runtimeStatus")
            }

            public static var onlineModel: String {
                ModelManager.tr("model_manager.routing.online_model")
            }

            public static var routingRules: String {
                ModelManager.tr("model_manager.routing.rules")
            }

            public static var networkStatus: String {
                ModelManager.tr("model_manager.routing.network_monitoring")
            }

            public static var advancedSettings: String {
                ModelManager.tr("model_manager.routing.advanced")
            }

            public static var onlineEscalationTitle: String {
                ModelManager.tr("model_manager.routing.online_escalation_title")
            }

            public static var onlineEscalationToggle: String {
                ModelManager.tr("model_manager.routing.online_escalation_toggle")
            }

            public static var onlineEscalationDesc: String {
                ModelManager.tr("model_manager.routing.online_escalation_desc")
            }

            public static var onlineModelSelection: String {
                ModelManager.tr("model_manager.routing.online_model_selection")
            }

            /// 当前在线模型
            /// - Parameter model: 模型名称
            /// - Returns: 格式化的在线模型文本
            public static func currentOnlineModel(_ model: String) -> String {
                ModelManager.trf("model_manager.routing.current_online_model", model)
            }

            public static var taskRules: String {
                ModelManager.tr("model_manager.routing.rules")
            }

            public static var taskSemanticChunking: String {
                L10n.Common.tr("demo.chunking.title")
            }

            public static var taskLinkDiscovery: String {
                ModelManager.tr("model_manager.routing.task.link_discovery")
            }

            public static var taskSynthesis: String {
                L10n.Common.Sidebar.synthesis
            }

            public static var taskChat: String {
                ModelManager.tr("model_manager.routing.task.chat")
            }

            public static var taskTagGeneration: String {
                ModelManager.tr("model_manager.routing.task.tag_generation")
            }

            public static var strategyForceLocal: String {
                ModelManager.tr("model_manager.routing.strategy.force_local")
            }

            public static var strategySmartRouting: String {
                ModelManager.tr("model_manager.routing.strategy.smart_routing")
            }

            public static var networkMonitoring: String {
                ModelManager.tr("model_manager.routing.network_monitoring")
            }

            public static var networkCurrent: String {
                ModelManager.tr("model_manager.routing.network.current")
            }

            public static var networkLatency: String {
                ModelManager.tr("model_manager.routing.network.latency")
            }

            public static var networkBandwidth: String {
                ModelManager.tr("model_manager.routing.network.bandwidth")
            }

            public static var networkBandwidthExcellent: String {
                ModelManager.tr("model_manager.routing.network.bandwidth_excellent")
            }

            public static var localModelReady: String {
                ModelManager.tr("model_manager.routing.local_model_ready")
            }

            public static var currentDecision: String {
                ModelManager.tr("model_manager.routing.current_decision")
            }

            public static var advanced: String {
                ModelManager.tr("model_manager.routing.advanced")
            }

            public static var wifiOnly: String {
                ModelManager.tr("model_manager.routing.wifi_only")
            }

            public static var autoFallback: String {
                ModelManager.tr("model_manager.routing.auto_fallback")
            }

            public static var preferLocal: String {
                ModelManager.tr("model_manager.routing.prefer_local")
            }

            public static var decisionUnselected: String {
                ModelManager.tr("model_manager.routing.decision.unselected")
            }

            public static var decisionOnline: String {
                ModelManager.tr("model_manager.routing.decision.online")
            }

            public static var decisionLocal: String {
                ModelManager.tr("model_manager.routing.decision.local")
            }

            public static var autoOnlineDesc: String {
                ModelManager.tr("model_manager.routing.auto_online_desc")
            }

            public static var statusNotReady: String {
                ModelManager.tr("model_manager.routing.status_not_ready")
            }

            public static var decisionAutoOnline: String {
                ModelManager.tr("model_manager.routing.decision.auto_online")
            }
        }

        // MARK: - 状态与提示

        public enum Status {
            public static var downloading: String {
                ModelManager.tr("model_manager.status.downloading")
            }

            public static var verifying: String {
                ModelManager.tr("model_manager.status.verifying")
            }

            public static var completed: String {
                ModelManager.tr("model_manager.status.completed")
            }

            public static var failed: String {
                ModelManager.tr("model_manager.status.failed")
            }

            public static var paused: String {
                ModelManager.tr("model_manager.status.paused")
            }

            public static var fileCorrupted: String {
                ModelManager.tr("model_manager.status.file_corrupted")
            }

            public static var verificationFailed: String {
                ModelManager.tr("model_manager.status.verification_failed")
            }

            /// 下载过程中产生的错误消息
            public enum DownloadError {
                /// 无续传数据文件
                public static var noResumeData: String {
                    ModelManager.tr("model_manager.status.download_error.no_resume_data")
                }

                /// 空闲状态占位
                public static var idle: String {
                    ModelManager.tr("model_manager.status.download_error.idle")
                }

                /// 临时副本生成失败前缀
                public static var temporaryCopyFailedPrefix: String {
                    ModelManager.tr("model_manager.status.download_error.temporary_copy_failed_prefix")
                }

                /// 生成失败连接符
                public static var generationFailedConnector: String {
                    ModelManager.tr("model_manager.status.download_error.generation_failed_connector")
                }

                /// resumeData 持久化失败前缀
                public static var persistResumeDataFailedPrefix: String {
                    ModelManager.tr("model_manager.status.download_error.persist_resume_data_failed_prefix")
                }

                /// 网络错误 resumeData 持久化失败前缀
                public static var networkErrorResumeDataFailedPrefix: String {
                    ModelManager.tr("model_manager.status.download_error.network_error_resume_data_failed_prefix")
                }

                /// 暂停时生成 resumeData 失败
                public static var resumeDataGenerationFailed: String {
                    ModelManager.tr("model_manager.status.download_error.resume_data_generation_failed")
                }
            }
        }

        // MARK: - 测试实验室

        public static var laboratoryTitle: String {
            ModelManager.tr("model_manager.laboratory.title")
        }

        public enum Lab {
            public static var modelNotReadyTitle: String { ModelManager.tr("model_manager.lab.model_not_ready_title") }
            public static var modelNotReadyDesc: String { ModelManager.tr("model_manager.lab.model_not_ready_desc") }
            public static var modelLoadingTitle: String { ModelManager.tr("model_manager.lab.model_loading_title") }
            public static var modelLoadingDesc: String { ModelManager.tr("model_manager.lab.model_loading_desc") }
            public static var modelLoadingIndicator: String { ModelManager.tr("model_manager.lab.model_loading_indicator") }
            public static var noActiveModelTitle: String { ModelManager.tr("model_manager.lab.no_active_model.title") }
            public static var noActiveModelSubtitle: String { ModelManager.tr("model_manager.lab.no_active_model.subtitle") }
            public static var goToStore: String { ModelManager.tr("model_manager.lab.go_to_store") }
            public static var unsupportedUseCase: String { ModelManager.tr("model_manager.lab.unsupported_use_case") }

            public enum Response {
                public static var swiftActorExample: String { ModelManager.tr("model_manager.lab.response.swift_actor_example") }
                public static var ragArchitectureExample: String { ModelManager.tr("model_manager.lab.response.rag_architecture_example") }
                public static var hybridSearchExplanation: String { ModelManager.tr("model_manager.lab.response.hybrid_search_explanation") }
                public static func generalOnDevice(model: String, prompt: String) -> String {
                    ModelManager.trf("model_manager.lab.response.general_on_device_format", model, prompt)
                }
                public static func mobileActionSuccess(action: String) -> String {
                    ModelManager.trf("model_manager.lab.response.mobile_action_success_format", action)
                }
                public static func mobileActionUnauthorized(action: String) -> String {
                    ModelManager.trf("model_manager.lab.response.mobile_action_unauthorized_format", action)
                }
                public static func mobileActionComplex(target: String) -> String {
                    ModelManager.trf("model_manager.lab.response.mobile_action_complex_format", target)
                }
                public static func promptLabCreative(temp: String, topP: String, prompt: String) -> String {
                    ModelManager.trf("model_manager.lab.response.prompt_lab_creative_format", temp, topP, prompt)
                }
                public static func promptLabDeterministic(temp: String, topP: String, prompt: String) -> String {
                    ModelManager.trf("model_manager.lab.response.prompt_lab_deterministic_format", temp, topP, prompt)
                }
                public static var agentReactKnowledgeSummary: String {
                    ModelManager.tr("model_manager.lab.response.agent_react_knowledge_summary")
                }
                public static var chatGreeting: String {
                    ModelManager.tr("model_manager.lab.response.chat_greeting")
                }
                public static func tinyGardenStatus(plant: String) -> String {
                    ModelManager.trf("model_manager.lab.response.tiny_garden_status_format", plant)
                }
                public static func audioScribeResult(duration: String) -> String {
                    ModelManager.trf("model_manager.lab.response.audio_scribe_result_format", duration)
                }
            }

            // MARK: - 意图识别多语言词集
            public enum Keyword {
                public static var greetingList: [String] {
                    ModelManager.tr("model_manager.lab.keyword.greeting").components(separatedBy: ",")
                }
                public static var hybridSearchList: [String] {
                    ModelManager.tr("model_manager.lab.keyword.hybrid_search").components(separatedBy: ",")
                }
                public static var swiftConcurrencyList: [String] {
                    ModelManager.tr("model_manager.lab.keyword.swift_concurrency").components(separatedBy: ",")
                }
                public static var ragArchitectureList: [String] {
                    ModelManager.tr("model_manager.lab.keyword.rag_architecture").components(separatedBy: ",")
                }
            }
            
            // 用例名称
            public static var useCaseInstantMediaSearch: String { ModelManager.tr("model_manager.lab.use_case.instant_media_search") }
            public static var useCaseVideoMomentSearch: String { ModelManager.tr("model_manager.lab.use_case.video_moment_search") }
            public static var useCaseAskImage: String { ModelManager.tr("model_manager.lab.use_case.ask_image") }
            public static var useCaseAudioScribe: String { ModelManager.tr("model_manager.lab.use_case.audio_scribe") }
            public static var useCaseChat: String { ModelManager.tr("model_manager.lab.use_case.chat") }
            public static var useCaseAgentSkills: String { ModelManager.tr("model_manager.lab.use_case.agent_skills") }
            public static var useCasePromptLab: String { ModelManager.tr("model_manager.lab.use_case.prompt_lab") }
            public static var useCaseTinyGarden: String { ModelManager.tr("model_manager.lab.use_case.tiny_garden") }
            public static var useCaseMobileActions: String { ModelManager.tr("model_manager.lab.use_case.mobile_actions") }

            // 用例副标题描述
            public static var descInstantMediaSearch: String { ModelManager.tr("model_manager.lab.desc.instant_media_search") }
            public static var descVideoMomentSearch: String { ModelManager.tr("model_manager.lab.desc.video_moment_search") }
            public static var descAskImage: String { ModelManager.tr("model_manager.lab.desc.ask_image") }
            public static var descAudioScribe: String { ModelManager.tr("model_manager.lab.desc.audio_scribe") }
            public static var descChat: String { ModelManager.tr("model_manager.lab.desc.chat") }
            public static var descAgentSkills: String { ModelManager.tr("model_manager.lab.desc.agent_skills") }
            public static var descPromptLab: String { ModelManager.tr("model_manager.lab.desc.prompt_lab") }
            public static var descTinyGarden: String { ModelManager.tr("model_manager.lab.desc.tiny_garden") }
            public static var descMobileActions: String { ModelManager.tr("model_manager.lab.desc.mobile_actions") }

            /// 格式化可用模型数量
            public static func modelCountFormat(_ count: Int) -> String {
                ModelManager.trf("model_manager.lab.model_count_format", count)
            }

            /// 格式化就绪/总模型数量
            public static func readyModelCountFormat(_ ready: Int, _ total: Int) -> String {
                ModelManager.trf("model_manager.lab.ready_model_count_format", ready, total)
            }

            /// 状态：可体验
            public static var statusAvailable: String { ModelManager.tr("model_manager.lab.status.available") }
            /// 状态：需下载模型
            public static var statusNeedDownload: String { ModelManager.tr("model_manager.lab.status.need_download") }

            // 性能指标与监控
            public static var performanceMetrics: String { ModelManager.tr("model_manager.lab.metrics.title") }
            public static var speed: String { ModelManager.tr("model_manager.lab.metrics.speed") }
            public static var prefillLatency: String { ModelManager.tr("model_manager.lab.metrics.prefill_latency") }
            public static var firstTokenLatency: String { ModelManager.tr("model_manager.lab.metrics.first_token_latency") }
            public static var memoryUsage: String { ModelManager.tr("model_manager.lab.metrics.memory_usage") }
            
            // 交互区
            public static var runTest: String { ModelManager.tr("model_manager.lab.run_test") }
            public static var testing: String { ModelManager.tr("model_manager.lab.testing") }
            public static var placeholderInput: String { ModelManager.tr("model_manager.lab.placeholder_input") }
            public static var selectImage: String { ModelManager.tr("model_manager.lab.select_image") }
            public static var recordAudio: String { ModelManager.tr("model_manager.lab.record_audio") }
            
            public static var exploreOther: String { ModelManager.tr("model_manager.lab.explore_other") }
            public static var audioReady: String { ModelManager.tr("model_manager.lab.audio_ready") }
            public static var unsupported: String { ModelManager.tr("model_manager.lab.unsupported") }
            public static var back: String { ModelManager.tr("model_manager.lab.back") }
            public static var configureInputs: String { ModelManager.tr("model_manager.lab.configure_inputs") }
            public static var stopInference: String { ModelManager.tr("model_manager.lab.stop_inference") }
            public static var visualParams: String { ModelManager.tr("model_manager.lab.visual_params") }
            public static var visualDesc: String { ModelManager.tr("model_manager.lab.visual_desc") }
            public static var stopRecording: String { ModelManager.tr("model_manager.lab.stop_recording") }
            public static var audioCompleted: String { ModelManager.tr("model_manager.lab.audio_completed") }
            public static var outputResult: String { ModelManager.tr("model_manager.lab.output_result") }
            
            // 参数配置 Sheet
            public static var configurations: String { ModelManager.tr("model_manager.lab.configurations") }
            public static var modelConfigs: String { ModelManager.tr("model_manager.lab.model_configs") }
            public static var systemPrompt: String { ModelManager.tr("model_manager.lab.system_prompt") }
            public static var defaultSystemPrompt: String { ModelManager.tr("model_manager.lab.default_system_prompt") }
            public static var enableThinking: String { ModelManager.tr("model_manager.lab.enable_thinking") }
            public static var enableSpeculativeDecoding: String { ModelManager.tr("model_manager.lab.enable_speculative_decoding") }
            public static var accelerator: String { ModelManager.tr("model_manager.lab.accelerator") }
            public static var cpu: String { ModelManager.tr("model_manager.lab.cpu") }
            public static var gpu: String { ModelManager.tr("model_manager.lab.gpu") }
            public static var selectModel: String { ModelManager.tr("model_manager.lab.select_model") }
            public static var chatInputPlaceholder: String { ModelManager.tr("model_manager.lab.chat_input_placeholder") }
            public static var send: String { ModelManager.tr("model_manager.lab.send") }
            
            public enum Prompt {
                public static var askImage: String { ModelManager.tr("model_manager.lab.prompt.ask_image") }
                public static var chat: String { ModelManager.tr("model_manager.lab.prompt.chat") }
                public static var agentSkills: String { ModelManager.tr("model_manager.lab.prompt.agent_skills") }
                public static var promptLab: String { ModelManager.tr("model_manager.lab.prompt.prompt_lab") }
                public static var tinyGarden: String { ModelManager.tr("model_manager.lab.prompt.tiny_garden") }
                public static var mobileActions: String { ModelManager.tr("model_manager.lab.prompt.mobile_actions") }
                public static var instantMediaSearch: String { ModelManager.tr("model_manager.lab.prompt.instant_media_search") }
                public static var videoMomentSearch: String { ModelManager.tr("model_manager.lab.prompt.video_moment_search") }
            }

            public enum MediaSearch {
                public static var importImage: String { ModelManager.tr("model_manager.lab.media_search.import_image") }
                public static var emptyHint: String { ModelManager.tr("model_manager.lab.media_search.empty_hint") }
                public static var searchPlaceholder: String { ModelManager.tr("model_manager.lab.media_search.search_placeholder") }
                public static var thresholdLabel: String { ModelManager.tr("model_manager.lab.media_search.threshold_label") }
                public static func thresholdFormat(_ percent: Double) -> String {
                    ModelManager.trf("model_manager.lab.media_search.threshold_format", percent)
                }
            }

            public enum AskImage {
                public static var selectPhoto: String { ModelManager.tr("model_manager.lab.ask_image.select_photo") }
                public static var presetTitle: String { ModelManager.tr("model_manager.lab.ask_image.preset_title") }
                public static var sampleSmartDesk: String { ModelManager.tr("model_manager.lab.ask_image.sample.smart_desk") }
                public static var sampleArchChart: String { ModelManager.tr("model_manager.lab.ask_image.sample.arch_chart") }
                public static var sampleCityNight: String { ModelManager.tr("model_manager.lab.ask_image.sample.city_night") }
                public static var removeImage: String { ModelManager.tr("model_manager.lab.ask_image.remove_image") }
                public static func metaFormat(_ res: String, _ size: String) -> String {
                    ModelManager.trf("model_manager.lab.ask_image.meta_format", res, size)
                }
            }

            public enum Audio {
                public static var startRecording: String { ModelManager.tr("model_manager.lab.audio.start_recording") }
                public static var stopRecording: String { ModelManager.tr("model_manager.lab.audio.stop_recording") }
                public static var sampling: String { ModelManager.tr("model_manager.lab.audio.sampling") }
                public static var presetTitle: String { ModelManager.tr("model_manager.lab.audio.preset_title") }
                public static var sampleMeeting: String { ModelManager.tr("model_manager.lab.audio.sample.meeting") }
                public static var sampleSchedule: String { ModelManager.tr("model_manager.lab.audio.sample.schedule") }
                public static var sampleTech: String { ModelManager.tr("model_manager.lab.audio.sample.tech") }
                public static var sampleMeetingText: String { ModelManager.tr("model_manager.lab.audio.sample.meeting_text") }
                public static var sampleScheduleText: String { ModelManager.tr("model_manager.lab.audio.sample.schedule_text") }
                public static var sampleTechText: String { ModelManager.tr("model_manager.lab.audio.sample.tech_text") }
                public static func durationFormat(_ dur: String) -> String {
                    ModelManager.trf("model_manager.lab.audio.duration_format", dur)
                }
                public static func rtfFormat(_ rtf: String, _ words: Int64) -> String {
                    ModelManager.trf("model_manager.lab.audio.rtf_format", rtf, words)
                }
                public static var copyText: String { ModelManager.tr("model_manager.lab.audio.copy_text") }
                public static var micDenied: String { ModelManager.tr("model_manager.lab.audio.mic_denied") }
                public static var playSample: String { ModelManager.tr("model_manager.lab.audio.play_sample") }
                public static var pauseSample: String { ModelManager.tr("model_manager.lab.audio.pause_sample") }
            }

            public enum VideoSearch {
                public static var importVideo: String { ModelManager.tr("model_manager.lab.video_search.import_video") }
                public static var emptyHint: String { ModelManager.tr("model_manager.lab.video_search.empty_hint") }
                public static var searchPlaceholder: String { ModelManager.tr("model_manager.lab.video_search.search_placeholder") }
                public static var indexing: String { ModelManager.tr("model_manager.lab.video_search.indexing") }
                public static func framesCount(_ count: Int) -> String { ModelManager.trf("model_manager.lab.video_search.frames_count", count) }
                public static var filmstripTitle: String { ModelManager.tr("model_manager.lab.video_search.filmstrip_title") }
            }

            public static func similarityScore(_ score: Float) -> String { ModelManager.trf("model_manager.lab.similarity_score", score) }
            public static func timestampLabel(_ time: String) -> String { ModelManager.trf("model_manager.lab.timestamp_label", time) }
            public static var clearIndex: String { ModelManager.tr("model_manager.lab.clear_index") }
            public static var loadDemoImages: String { ModelManager.tr("model_manager.lab.load_demo_images") }
            public static var loadDemoVideo: String { ModelManager.tr("model_manager.lab.load_demo_video") }
            public static var searchSimilarImage: String { ModelManager.tr("model_manager.lab.search_similar_image") }

            public enum Chip {
                public static var plants: String { ModelManager.tr("model_manager.lab.demo_chip_plants") }
                public static var ocean: String { ModelManager.tr("model_manager.lab.demo_chip_ocean") }
                public static var sunset: String { ModelManager.tr("model_manager.lab.demo_chip_sunset") }
                public static var intro: String { ModelManager.tr("model_manager.lab.demo_chip_intro") }
                public static var highlight: String { ModelManager.tr("model_manager.lab.demo_chip_highlight") }
                public static var nature: String { ModelManager.tr("model_manager.lab.demo_chip_nature") }
            }

            public static func demoImageTitle(_ name: String) -> String {
                ModelManager.trf("model_manager.lab.demo_image_title_format", name)
            }

            public static var tipsMultimodal: String { ModelManager.tr("model_manager.lab.tips_multimodal") }
            public static var tipsAgent: String { ModelManager.tr("model_manager.lab.tips_agent") }

            public enum Attach {
                public static var linkPage: String { ModelManager.tr("model_manager.lab.attach.link_page") }
                public static var linkPageSuccess: String { ModelManager.tr("model_manager.lab.attach.link_page_success") }
                public static var injectTag: String { ModelManager.tr("model_manager.lab.attach.inject_tag") }
                public static var injectTagSuccess: String { ModelManager.tr("model_manager.lab.attach.inject_tag_success") }
                public static var mountSandbox: String { ModelManager.tr("model_manager.lab.attach.mount_sandbox") }
                public static var mountSandboxSuccess: String { ModelManager.tr("model_manager.lab.attach.mount_sandbox_success") }
                public static var loadTemplate: String { ModelManager.tr("model_manager.lab.attach.load_template") }
                public static var loadTemplateSuccess: String { ModelManager.tr("model_manager.lab.attach.load_template_success") }
            }

            public enum Extra {
                public static var objectDetection: String { ModelManager.tr("model_manager.lab.extra.object_detection") }
                public static var speechTranscribing: String { ModelManager.tr("model_manager.lab.extra.speech_transcribing") }
                public static var functionCallTree: String { ModelManager.tr("model_manager.lab.extra.function_call_tree") }
                public static var intentMatch: String { ModelManager.tr("model_manager.lab.extra.intent_match") }
                public static var apiInvocation: String { ModelManager.tr("model_manager.lab.extra.api_invocation") }
                public static var gardenRender: String { ModelManager.tr("model_manager.lab.extra.garden_render") }
                public static var uiRendering: String { ModelManager.tr("model_manager.lab.extra.ui_rendering") }
                public static var devicePipeline: String { ModelManager.tr("model_manager.lab.extra.device_pipeline") }
                public static var intentAnalyser: String { ModelManager.tr("model_manager.lab.extra.intent_analyser") }
                public static var hapticFeedback: String { ModelManager.tr("model_manager.lab.extra.haptic_feedback") }
                public static var toolLocation: String { ModelManager.tr("model_manager.lab.extra.tool_location") }
                public static var contextSummary: String { ModelManager.tr("model_manager.lab.extra.context_summary") }
            }

            // MARK: - Mock 演示数据
            public enum Mock {
                public static var notebookLabel: String { ModelManager.tr("model_manager.lab.mock.notebook_label") }
                public static var penLabel: String { ModelManager.tr("model_manager.lab.mock.pen_label") }
                public static var iphoneScreenLabel: String { ModelManager.tr("model_manager.lab.mock.iphone_screen_label") }
                public static var traceStep1Desc: String { ModelManager.tr("model_manager.lab.mock.trace_step1_desc") }
                public static var traceStep2Desc: String { ModelManager.tr("model_manager.lab.mock.trace_step2_desc") }
                public static var intentMatchDesc: String { ModelManager.tr("model_manager.lab.mock.intent_match_desc") }
                public static var uiRenderingDesc: String { ModelManager.tr("model_manager.lab.mock.ui_rendering_desc") }
                public static var intentAnalyserDesc: String { ModelManager.tr("model_manager.lab.mock.intent_analyser_desc") }
                public static var sandboxGatekeeperDesc: String { ModelManager.tr("model_manager.lab.mock.sandbox_gatekeeper_desc") }
                public static var hapticFeedbackDesc: String { ModelManager.tr("model_manager.lab.mock.haptic_feedback_desc") }
                public static var sandboxReadDesc: String { ModelManager.tr("model_manager.lab.mock.sandbox_read_desc") }
                public static var contextSummaryDesc: String { ModelManager.tr("model_manager.lab.mock.context_summary_desc") }
            }

            // MARK: - 端侧行为沙盒 (Mobile Actions)
            public enum Mobile {
                public static var quickActionsTitle: String { ModelManager.tr("model_manager.lab.mobile.quick_actions_title") }
                public static var cmdTorchOn: String { ModelManager.tr("model_manager.lab.mobile.cmd_torch_on") }
                public static var cmdTorchOff: String { ModelManager.tr("model_manager.lab.mobile.cmd_torch_off") }
                public static var cmdHaptic: String { ModelManager.tr("model_manager.lab.mobile.cmd_haptic") }
                public static var cmdNotify: String { ModelManager.tr("model_manager.lab.mobile.cmd_notify") }
                public static var cmdDarkMode: String { ModelManager.tr("model_manager.lab.mobile.cmd_dark_mode") }
                public static var statusTitle: String { ModelManager.tr("model_manager.lab.mobile.status_title") }
                public static var torchState: String { ModelManager.tr("model_manager.lab.mobile.torch_state") }
                public static var hapticState: String { ModelManager.tr("model_manager.lab.mobile.haptic_state") }
                public static var themeState: String { ModelManager.tr("model_manager.lab.mobile.theme_state") }
                public static var notificationState: String { ModelManager.tr("model_manager.lab.mobile.notification_state") }
                public static var stateOn: String { ModelManager.tr("model_manager.lab.mobile.state_on") }
                public static var stateOff: String { ModelManager.tr("model_manager.lab.mobile.state_off") }
                public static var stateReady: String { ModelManager.tr("model_manager.lab.mobile.state_ready") }
                public static var recentLogs: String { ModelManager.tr("model_manager.lab.mobile.recent_logs") }
                public static var noLogs: String { ModelManager.tr("model_manager.lab.mobile.no_logs") }
            }

            // MARK: - 投机采样 (Speculative Decoding)
            public enum Speculative {
                public static var enableSpeculativeDecoding: String { ModelManager.tr("model_manager.lab.enable_speculative_decoding") }
                public static var draftModel: String { ModelManager.tr("model_manager.lab.speculative.draft_model") }
                public static var acceptanceRate: String { ModelManager.tr("model_manager.lab.speculative.acceptance_rate") }
                public static var speedup: String { ModelManager.tr("model_manager.lab.speculative.speedup") }
                public static func rateFormat(_ rate: Double) -> String { ModelManager.trf("model_manager.lab.speculative.rate_format", rate) }
                public static func speedupFormat(_ speedup: Double) -> String { ModelManager.trf("model_manager.lab.speculative.speedup_format", speedup) }
            }

            // MARK: - 端侧真实视觉分析 (Vision)
            public enum Vision {
                public static var reportTitle: String { ModelManager.tr("model_manager.lab.vision.report_title") }
                public static func labelsFormat(_ labels: String) -> String { ModelManager.trf("model_manager.lab.vision.labels_format", labels) }
                public static var noLabels: String { ModelManager.tr("model_manager.lab.vision.no_labels") }
                public static func ocrFormat(_ text: String) -> String { ModelManager.trf("model_manager.lab.vision.ocr_format", text) }
                public static func featuresFormat(_ res: String, _ luma: String, _ sat: String) -> String {
                    ModelManager.trf("model_manager.lab.vision.features_format", res, luma, sat)
                }
                public static func questionFormat(_ question: String) -> String { ModelManager.trf("model_manager.lab.vision.question_format", question) }
                public static var llmSystem: String { ModelManager.tr("model_manager.lab.vision.llm_system") }
                public static var customPrompt: String { ModelManager.tr("model_manager.lab.vision.custom_prompt") }
            }

            // MARK: - 深度思考过程 (Thinking Process)
            public enum Thinking {
                public static var enableThinking: String { ModelManager.tr("model_manager.lab.enable_thinking") }
                public static var inProgress: String { ModelManager.tr("model_manager.lab.thinking.in_progress") }
                public static func completedFormat(_ duration: String) -> String { ModelManager.trf("model_manager.lab.thinking.completed_format", duration) }
                public static var collapse: String { ModelManager.tr("model_manager.lab.thinking.collapse") }
                public static var expand: String { ModelManager.tr("model_manager.lab.thinking.expand") }
            }

            // MARK: - 多轮对话沙盒增强 (Chat Sandbox)
            public enum Chat {
                public static func metricsBadgeFormat(_ ttftMs: Int, _ tps: Double) -> String {
                    ModelManager.trf("model_manager.lab.chat.metrics_badge_format", ttftMs, tps)
                }
                public static var suggestionsTitle: String { ModelManager.tr("model_manager.lab.chat.suggestions_title") }
                public static var suggestSwift: String { ModelManager.tr("model_manager.lab.chat.suggest_swift") }
                public static var suggestRAG: String { ModelManager.tr("model_manager.lab.chat.suggest_rag") }
                public static var suggestSummary: String { ModelManager.tr("model_manager.lab.chat.suggest_summary") }
            }

            // MARK: - 配置抽屉加速器与窗口 (Config Sheet)
            public enum Config {
                public static var accelAuto: String { ModelManager.tr("model_manager.lab.config.accel_auto") }
                public static var accelANE: String { ModelManager.tr("model_manager.lab.config.accel_ane") }
                public static var accelMetal: String { ModelManager.tr("model_manager.lab.config.accel_metal") }
                public static var accelCPU: String { ModelManager.tr("model_manager.lab.config.accel_cpu") }
                public static var contextWindow: String { ModelManager.tr("model_manager.lab.config.context_window") }
                public static func kvCacheFormat(_ mb: Int) -> String {
                    ModelManager.trf("model_manager.lab.config.kv_cache_format", mb)
                }
            }
        }

        public enum Alert {
            public static var oomTitle: String { ModelManager.tr("model_manager.alert.oom_title") }
            public static func oomMessage(_ displayName: String, _ requiredGb: String, _ currentGb: String) -> String {
                ModelManager.trf("model_manager.alert.oom_message", displayName, requiredGb, currentGb)
            }
        }

        // MARK: - 顶层导航与分栏
        public static var tabModels: String { ModelManager.tr("tab_models") }
        public static var tabTasks: String { ModelManager.tr("tab_tasks") }
        public static var tryModelInLab: String { ModelManager.tr("try_model_in_lab") }

        // MARK: - 硬件算力看板
        public enum Hardware {
            public static func chipFormat(_ chip: String) -> String {
                ModelManager.trf("hardware_soc_chip_format", chip)
            }
            public static func memoryFormat(_ available: String, _ total: String, _ percent: Double) -> String {
                ModelManager.trf("hardware_memory_format", available, total, percent)
            }
            public static var acceleratorReady: String { ModelManager.tr("hardware_accelerator_ready") }
            public static var neuralEngine: String { ModelManager.tr("hardware_neural_engine") }
            public static var metalGPU: String { ModelManager.tr("hardware_metal_gpu") }
        }

        // MARK: - 任务类型筛选胶囊
        public enum Filter {
            public static var all: String { ModelManager.tr("filter_all") }
            public static var chat: String { ModelManager.tr("filter_chat") }
            public static var vision: String { ModelManager.tr("filter_vision") }
            public static var search: String { ModelManager.tr("filter_search") }
            public static var audio: String { ModelManager.tr("filter_audio") }
        }

        // MARK: - 性能基准测试
        public enum Benchmark {
            public static var title: String { ModelManager.tr("use_case_benchmark") }
            public static var description: String { ModelManager.tr("use_case_benchmark_desc") }
            public static var ttft: String { ModelManager.tr("benchmark_ttft") }
            public static var tps: String { ModelManager.tr("benchmark_tps") }
            public static var ram: String { ModelManager.tr("benchmark_ram") }
            public static var start: String { ModelManager.tr("benchmark_start") }
            public static var running: String { ModelManager.tr("benchmark_running") }
            public static var gradeExcellent: String { ModelManager.tr("benchmark_grade_excellent") }
            public static var gradeGood: String { ModelManager.tr("benchmark_grade_good") }
            public static var gradeWarning: String { ModelManager.tr("benchmark_grade_warning") }
            public static func roundsFormat(_ current: Int, _ total: Int) -> String {
                ModelManager.trf("benchmark_rounds_format", current, total)
            }
            public static func ttftFormat(_ ms: Double) -> String {
                ModelManager.trf("benchmark_ttft_format", ms)
            }
            public static func ramFormat(_ mb: Double) -> String {
                ModelManager.trf("benchmark_ram_format", mb)
            }
            public static func tpsFormat(_ tps: Double) -> String {
                ModelManager.trf("benchmark_tps_format", tps)
            }
        }

        // MARK: - BYOM 自定义本地模型导入
        public enum BYOM {
            public static var importButton: String { ModelManager.tr("model_manager.byom.import_button") }
            public static func importSuccess(_ name: String) -> String {
                ModelManager.trf("model_manager.byom.import_success", name)
            }
            public static func importFailed(_ reason: String) -> String {
                ModelManager.trf("model_manager.byom.import_failed", reason)
            }
        }

        // MARK: - HuggingFace 令牌鉴权
        public enum HFToken {
            public static var title: String { ModelManager.tr("model_manager.hf.token_title") }
            public static var placeholder: String { ModelManager.tr("model_manager.hf.token_placeholder") }
            public static var description: String { ModelManager.tr("model_manager.hf.token_desc") }
            public static var configured: String { ModelManager.tr("model_manager.hf.token_configured") }
            public static var clear: String { ModelManager.tr("model_manager.hf.token_clear") }
        }

        // MARK: - 魔搭社区与双源下载配置
        public enum ModelSource {
            public static var title: String { ModelManager.tr("model_manager.source.title") }
            public static var preferenceLabel: String { ModelManager.tr("model_manager.source.preference_label") }
            public static var auto: String { ModelManager.tr("model_manager.source.auto") }
            public static var modelscope: String { ModelManager.tr("model_manager.source.modelscope") }
            public static var huggingface: String { ModelManager.tr("model_manager.source.huggingface") }
            public static var autoDesc: String { ModelManager.tr("model_manager.source.auto_desc") }
            public static func autoDetected(_ sourceName: String) -> String {
                ModelManager.trf("model_manager.source.auto_detected_format", sourceName)
            }
            public static var modelscopeDesc: String { ModelManager.tr("model_manager.source.modelscope_desc") }
            public static var huggingfaceDesc: String { ModelManager.tr("model_manager.source.huggingface_desc") }
            public static var msTokenTitle: String { ModelManager.tr("model_manager.source.ms_token_title") }
            public static var msTokenPlaceholder: String { ModelManager.tr("model_manager.source.ms_token_placeholder") }
            public static var msTokenDesc: String { ModelManager.tr("model_manager.source.ms_token_desc") }
        }
    }
}
