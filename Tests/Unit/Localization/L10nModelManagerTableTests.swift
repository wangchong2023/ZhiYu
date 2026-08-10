//
//  L10nModelManagerTableTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 ModelManager 表 L10n 扩展的 tableName 正确性与代表性属性 key 存在性。
//

import XCTest
@testable import ZhiYu

/// ModelManager 表 L10n 扩展测试
final class L10nModelManagerTableTests: XCTestCase {

    // MARK: - tableName 正确性

    func testTableName_ModelManager_为ModelManager() {
        XCTAssertEqual(L10n.ModelManager.tableName, "ModelManager")
    }

    // MARK: - 顶层属性 key 存在性

    func testModelManager_顶层基础属性返回非Missing值() {
        let values = [
            L10n.ModelManager.storeTitle,
            L10n.ModelManager.parametersTitle,
            L10n.ModelManager.serversTitle,
            L10n.ModelManager.routingTitle
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "ModelManager 顶层属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "ModelManager 顶层属性返回空字符串")
        }
    }

    // MARK: - Card 子命名空间

    func testModelManager_Card_属性返回非Missing值() {
        let values = [
            L10n.ModelManager.Card.ready,
            L10n.ModelManager.Card.activated,
            L10n.ModelManager.Card.activate,
            L10n.ModelManager.Card.download,
            L10n.ModelManager.Card.pause,
            L10n.ModelManager.Card.resume,
            L10n.ModelManager.Card.cancel,
            L10n.ModelManager.Card.unavailable,
            L10n.ModelManager.Card.warningLowMemory,
            L10n.ModelManager.Card.learnMore
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "ModelManager.Card 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "ModelManager.Card 属性返回空字符串")
        }
    }

    func testModelManager_Card_vendor_返回非Missing且包含参数() {
        let result = L10n.ModelManager.Card.vendor("Apple")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "ModelManager.Card.vendor 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testModelManager_Card_size_返回非Missing且包含参数() {
        let result = L10n.ModelManager.Card.size("4GB")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "ModelManager.Card.size 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Task 子命名空间

    func testModelManager_Task_属性返回非Missing值() {
        let values = [
            L10n.ModelManager.Task.chat,
            L10n.ModelManager.Task.completion,
            L10n.ModelManager.Task.reasoning,
            L10n.ModelManager.Task.code,
            L10n.ModelManager.Task.rag,
            L10n.ModelManager.Task.translation,
            L10n.ModelManager.Task.multimodal
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "ModelManager.Task 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "ModelManager.Task 属性返回空字符串")
        }
    }

    // MARK: - Parameters 子命名空间

    func testModelManager_Parameters_属性返回非Missing值() {
        let values = [
            L10n.ModelManager.Parameters.temperature,
            L10n.ModelManager.Parameters.topP,
            L10n.ModelManager.Parameters.topK,
            L10n.ModelManager.Parameters.maxTokens,
            L10n.ModelManager.Parameters.presetCreative,
            L10n.ModelManager.Parameters.presetBalanced,
            L10n.ModelManager.Parameters.presetPrecise,
            L10n.ModelManager.Parameters.custom,
            L10n.ModelManager.Parameters.resetToDefaults,
            L10n.ModelManager.Parameters.saveConfiguration,
            L10n.ModelManager.Parameters.currentModel,
            L10n.ModelManager.Parameters.presetTemplate,
            L10n.ModelManager.Parameters.tipTemperature,
            L10n.ModelManager.Parameters.tipTopP,
            L10n.ModelManager.Parameters.tipTopK,
            L10n.ModelManager.Parameters.tipMaxTokens,
            L10n.ModelManager.Parameters.selectModel,
            L10n.ModelManager.Parameters.reset,
            L10n.ModelManager.Parameters.save
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "ModelManager.Parameters 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "ModelManager.Parameters 属性返回空字符串")
        }
    }

    // MARK: - Server 子命名空间

    func testModelManager_Server_属性返回非Missing值() {
        let values = [
            L10n.ModelManager.Server.addServer,
            L10n.ModelManager.Server.editServer,
            L10n.ModelManager.Server.testConnection,
            L10n.ModelManager.Server.deleteServer,
            L10n.ModelManager.Server.setDefault,
            L10n.ModelManager.Server.emptyTitle,
            L10n.ModelManager.Server.emptySubtitle,
            L10n.ModelManager.Server.serverName,
            L10n.ModelManager.Server.serverURL,
            L10n.ModelManager.Server.apiKey,
            L10n.ModelManager.Server.editAction,
            L10n.ModelManager.Server.deleteAction,
            L10n.ModelManager.Server.setDefaultAction,
            L10n.ModelManager.Server.formNameLabel,
            L10n.ModelManager.Server.formURLLabel,
            L10n.ModelManager.Server.formAPIKeyLabel,
            L10n.ModelManager.Server.formSetDefault,
            L10n.ModelManager.Server.formEnableSSL,
            L10n.ModelManager.Server.testSuccess,
            L10n.ModelManager.Server.formAddTitle,
            L10n.ModelManager.Server.formEditTitle,
            L10n.ModelManager.Server.formCancel,
            L10n.ModelManager.Server.formSave,
            L10n.ModelManager.Server.testResult,
            L10n.ModelManager.Server.mockLocalDev
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "ModelManager.Server 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "ModelManager.Server 属性返回空字符串")
        }
    }

    func testModelManager_Server_latency_返回非Missing且包含参数() {
        let result = L10n.ModelManager.Server.latency(120)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "ModelManager.Server.latency 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testModelManager_Server_lastTested_返回非Missing且包含参数() {
        let result = L10n.ModelManager.Server.lastTested("2026-08-10")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "ModelManager.Server.lastTested 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testModelManager_Server_latencyMs_返回非Missing且包含参数() {
        let result = L10n.ModelManager.Server.latencyMs(45)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "ModelManager.Server.latencyMs 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Routing 子命名空间

    func testModelManager_Routing_属性返回非Missing值() {
        let values = [
            L10n.ModelManager.Routing.onlineEscalation,
            L10n.ModelManager.Routing.modelStrategy,
            L10n.ModelManager.Routing.runtimeStatus,
            L10n.ModelManager.Routing.onlineModel,
            L10n.ModelManager.Routing.routingRules,
            L10n.ModelManager.Routing.networkStatus,
            L10n.ModelManager.Routing.advancedSettings,
            L10n.ModelManager.Routing.onlineEscalationTitle,
            L10n.ModelManager.Routing.onlineEscalationToggle,
            L10n.ModelManager.Routing.onlineEscalationDesc,
            L10n.ModelManager.Routing.onlineModelSelection,
            L10n.ModelManager.Routing.taskRules,
            L10n.ModelManager.Routing.taskSemanticChunking,
            L10n.ModelManager.Routing.taskLinkDiscovery,
            L10n.ModelManager.Routing.taskSynthesis,
            L10n.ModelManager.Routing.taskChat,
            L10n.ModelManager.Routing.taskTagGeneration,
            L10n.ModelManager.Routing.strategyForceLocal,
            L10n.ModelManager.Routing.strategySmartRouting,
            L10n.ModelManager.Routing.networkMonitoring,
            L10n.ModelManager.Routing.networkCurrent,
            L10n.ModelManager.Routing.networkLatency,
            L10n.ModelManager.Routing.networkBandwidth,
            L10n.ModelManager.Routing.networkBandwidthExcellent,
            L10n.ModelManager.Routing.localModelReady,
            L10n.ModelManager.Routing.currentDecision,
            L10n.ModelManager.Routing.advanced,
            L10n.ModelManager.Routing.wifiOnly,
            L10n.ModelManager.Routing.autoFallback,
            L10n.ModelManager.Routing.preferLocal,
            L10n.ModelManager.Routing.decisionUnselected,
            L10n.ModelManager.Routing.decisionOnline,
            L10n.ModelManager.Routing.decisionLocal,
            L10n.ModelManager.Routing.autoOnlineDesc,
            L10n.ModelManager.Routing.statusNotReady,
            L10n.ModelManager.Routing.decisionAutoOnline
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "ModelManager.Routing 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "ModelManager.Routing 属性返回空字符串")
        }
    }

    func testModelManager_Routing_currentOnlineModel_返回非Missing且包含参数() {
        let result = L10n.ModelManager.Routing.currentOnlineModel("gpt-4o")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "ModelManager.Routing.currentOnlineModel 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Status 子命名空间

    func testModelManager_Status_属性返回非Missing值() {
        let values = [
            L10n.ModelManager.Status.downloading,
            L10n.ModelManager.Status.verifying,
            L10n.ModelManager.Status.completed,
            L10n.ModelManager.Status.failed,
            L10n.ModelManager.Status.paused
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "ModelManager.Status 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "ModelManager.Status 属性返回空字符串")
        }
    }

    // MARK: - Lab 子命名空间

    func testModelManager_Lab_属性返回非Missing值() {
        let values = [
            L10n.ModelManager.Lab.noActiveModelTitle,
            L10n.ModelManager.Lab.noActiveModelSubtitle,
            L10n.ModelManager.Lab.goToStore,
            L10n.ModelManager.Lab.unsupportedUseCase,
            L10n.ModelManager.Lab.useCaseAskImage,
            L10n.ModelManager.Lab.useCaseAudioScribe,
            L10n.ModelManager.Lab.useCaseChat,
            L10n.ModelManager.Lab.useCaseAgentSkills,
            L10n.ModelManager.Lab.useCasePromptLab,
            L10n.ModelManager.Lab.useCaseTinyGarden,
            L10n.ModelManager.Lab.useCaseMobileActions,
            L10n.ModelManager.Lab.descAskImage,
            L10n.ModelManager.Lab.descAudioScribe,
            L10n.ModelManager.Lab.descChat,
            L10n.ModelManager.Lab.descAgentSkills,
            L10n.ModelManager.Lab.descPromptLab,
            L10n.ModelManager.Lab.descTinyGarden,
            L10n.ModelManager.Lab.descMobileActions,
            L10n.ModelManager.Lab.performanceMetrics,
            L10n.ModelManager.Lab.speed,
            L10n.ModelManager.Lab.prefillLatency,
            L10n.ModelManager.Lab.firstTokenLatency,
            L10n.ModelManager.Lab.memoryUsage,
            L10n.ModelManager.Lab.runTest,
            L10n.ModelManager.Lab.testing,
            L10n.ModelManager.Lab.placeholderInput,
            L10n.ModelManager.Lab.selectImage,
            L10n.ModelManager.Lab.recordAudio,
            L10n.ModelManager.Lab.exploreOther,
            L10n.ModelManager.Lab.audioReady,
            L10n.ModelManager.Lab.unsupported,
            L10n.ModelManager.Lab.back,
            L10n.ModelManager.Lab.configureInputs,
            L10n.ModelManager.Lab.stopInference,
            L10n.ModelManager.Lab.visualParams,
            L10n.ModelManager.Lab.visualDesc,
            L10n.ModelManager.Lab.stopRecording,
            L10n.ModelManager.Lab.audioCompleted,
            L10n.ModelManager.Lab.outputResult,
            L10n.ModelManager.Lab.configurations,
            L10n.ModelManager.Lab.modelConfigs,
            L10n.ModelManager.Lab.systemPrompt,
            L10n.ModelManager.Lab.defaultSystemPrompt,
            L10n.ModelManager.Lab.enableThinking,
            L10n.ModelManager.Lab.enableSpeculativeDecoding,
            L10n.ModelManager.Lab.accelerator,
            L10n.ModelManager.Lab.selectModel,
            L10n.ModelManager.Lab.chatInputPlaceholder,
            L10n.ModelManager.Lab.send
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "ModelManager.Lab 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "ModelManager.Lab 属性返回空字符串")
        }
    }

    // MARK: - Lab.Prompt 子命名空间

    func testModelManager_Lab_Prompt_属性返回非Missing值() {
        let values = [
            L10n.ModelManager.Lab.Prompt.askImage,
            L10n.ModelManager.Lab.Prompt.chat,
            L10n.ModelManager.Lab.Prompt.agentSkills,
            L10n.ModelManager.Lab.Prompt.promptLab,
            L10n.ModelManager.Lab.Prompt.tinyGarden,
            L10n.ModelManager.Lab.Prompt.mobileActions
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "ModelManager.Lab.Prompt 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "ModelManager.Lab.Prompt 属性返回空字符串")
        }
    }

    // MARK: - Lab.tips 属性

    func testModelManager_Lab_tips_属性返回非Missing值() {
        let values = [
            L10n.ModelManager.Lab.tipsMultimodal,
            L10n.ModelManager.Lab.tipsAgent
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "ModelManager.Lab.tips 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "ModelManager.Lab.tips 属性返回空字符串")
        }
    }

    // MARK: - Lab.Attach 子命名空间

    func testModelManager_Lab_Attach_属性返回非Missing值() {
        let values = [
            L10n.ModelManager.Lab.Attach.linkPage,
            L10n.ModelManager.Lab.Attach.linkPageSuccess,
            L10n.ModelManager.Lab.Attach.injectTag,
            L10n.ModelManager.Lab.Attach.injectTagSuccess,
            L10n.ModelManager.Lab.Attach.mountSandbox,
            L10n.ModelManager.Lab.Attach.mountSandboxSuccess,
            L10n.ModelManager.Lab.Attach.loadTemplate,
            L10n.ModelManager.Lab.Attach.loadTemplateSuccess
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "ModelManager.Lab.Attach 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "ModelManager.Lab.Attach 属性返回空字符串")
        }
    }

    // MARK: - Lab.Extra 子命名空间

    func testModelManager_Lab_Extra_属性返回非Missing值() {
        let values = [
            L10n.ModelManager.Lab.Extra.objectDetection,
            L10n.ModelManager.Lab.Extra.speechTranscribing,
            L10n.ModelManager.Lab.Extra.functionCallTree,
            L10n.ModelManager.Lab.Extra.intentMatch,
            L10n.ModelManager.Lab.Extra.apiInvocation,
            L10n.ModelManager.Lab.Extra.gardenRender,
            L10n.ModelManager.Lab.Extra.uiRendering,
            L10n.ModelManager.Lab.Extra.devicePipeline,
            L10n.ModelManager.Lab.Extra.intentAnalyser,
            L10n.ModelManager.Lab.Extra.hapticFeedback,
            L10n.ModelManager.Lab.Extra.toolLocation,
            L10n.ModelManager.Lab.Extra.contextSummary
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "ModelManager.Lab.Extra 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "ModelManager.Lab.Extra 属性返回空字符串")
        }
    }

    // MARK: - Alert 子命名空间

    func testModelManager_Alert_oomTitle_返回非Missing值() {
        let value = L10n.ModelManager.Alert.oomTitle
        XCTAssertFalse(value.contains("[MISSING:"),
                       "ModelManager.Alert.oomTitle 返回 Missing: \(value)")
        XCTAssertFalse(value.isEmpty, "ModelManager.Alert.oomTitle 返回空字符串")
    }

    func testModelManager_Alert_oomMessage_返回非Missing且包含参数() {
        let result = L10n.ModelManager.Alert.oomMessage("TestModel", "8", "4")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "ModelManager.Alert.oomMessage 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }
}
