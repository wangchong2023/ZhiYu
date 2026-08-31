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
        }

        // MARK: - 规格详表（Model Spec Sheet）

        public enum Spec {
            public static var memory: String { ModelManager.tr("model_manager.spec.memory") }
            public static var downloadSize: String { ModelManager.tr("model_manager.spec.downloadSize") }
            public static var parameters: String { ModelManager.tr("model_manager.spec.parameters") }
            public static var checksum: String { ModelManager.tr("model_manager.spec.checksum") }
            public static var tasks: String { ModelManager.tr("model_manager.spec.tasks") }
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
        }

        // MARK: - 测试实验室

        public static var laboratoryTitle: String {
            ModelManager.tr("model_manager.laboratory.title")
        }

        public enum Lab {
            public static var noActiveModelTitle: String { ModelManager.tr("model_manager.lab.no_active_model.title") }
            public static var noActiveModelSubtitle: String { ModelManager.tr("model_manager.lab.no_active_model.subtitle") }
            public static var goToStore: String { ModelManager.tr("model_manager.lab.go_to_store") }
            public static var unsupportedUseCase: String { ModelManager.tr("model_manager.lab.unsupported_use_case") }
            
            // 用例名称
            public static var useCaseAskImage: String { ModelManager.tr("model_manager.lab.use_case.ask_image") }
            public static var useCaseAudioScribe: String { ModelManager.tr("model_manager.lab.use_case.audio_scribe") }
            public static var useCaseChat: String { ModelManager.tr("model_manager.lab.use_case.chat") }
            public static var useCaseAgentSkills: String { ModelManager.tr("model_manager.lab.use_case.agent_skills") }
            public static var useCasePromptLab: String { ModelManager.tr("model_manager.lab.use_case.prompt_lab") }
            public static var useCaseTinyGarden: String { ModelManager.tr("model_manager.lab.use_case.tiny_garden") }
            public static var useCaseMobileActions: String { ModelManager.tr("model_manager.lab.use_case.mobile_actions") }

            // 用例副标题描述
            public static var descAskImage: String { ModelManager.tr("model_manager.lab.desc.ask_image") }
            public static var descAudioScribe: String { ModelManager.tr("model_manager.lab.desc.audio_scribe") }
            public static var descChat: String { ModelManager.tr("model_manager.lab.desc.chat") }
            public static var descAgentSkills: String { ModelManager.tr("model_manager.lab.desc.agent_skills") }
            public static var descPromptLab: String { ModelManager.tr("model_manager.lab.desc.prompt_lab") }
            public static var descTinyGarden: String { ModelManager.tr("model_manager.lab.desc.tiny_garden") }
            public static var descMobileActions: String { ModelManager.tr("model_manager.lab.desc.mobile_actions") }

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
        }

        public enum Alert {
            public static var oomTitle: String { ModelManager.tr("model_manager.alert.oom_title") }
            public static func oomMessage(_ displayName: String, _ requiredGb: String, _ currentGb: String) -> String {
                ModelManager.trf("model_manager.alert.oom_message", displayName, requiredGb, currentGb)
            }
        }
    }
}

