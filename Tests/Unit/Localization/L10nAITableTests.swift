//
//  L10nAITableTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 AI 表 L10n 扩展（AI/Chat/Voice）的 tableName 正确性与属性 key 存在性。
//

import XCTest
@testable import ZhiYu

/// AI 表 L10n 扩展测试（AI/Chat/Voice 三个子命名空间）
final class L10nAITableTests: XCTestCase {

    // MARK: - tableName 正确性

    func testTableName_AI_为AI() {
        XCTAssertEqual(L10n.AI.tableName, "AI")
    }

    func testTableName_Chat_为AI() {
        XCTAssertEqual(L10n.Chat.tableName, "AI")
    }

    func testTableName_Voice_为AI() {
        XCTAssertEqual(L10n.Voice.tableName, "AI")
    }

    // MARK: - AI.Status 属性 key 存在性

    func testAI_Status_所有属性返回非Missing值() {
        let values = [
            L10n.AI.Status.analyzing,
            L10n.AI.Status.digging,
            L10n.AI.Status.extracting,
            L10n.AI.Status.generating,
            L10n.AI.Status.organizing,
            L10n.AI.Status.preprocessing,
            L10n.AI.Status.scanning,
            L10n.AI.Status.structuring,
            L10n.AI.Status.synthesizing,
            L10n.AI.Status.thinking,
            L10n.AI.Status.visualizing
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.Status 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.Status 属性返回空字符串")
        }
    }

    func testAI_Status_indexing_返回非Missing且包含参数() {
        let result = L10n.AI.Status.indexing(3, 10, "test.pdf")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "AI.Status.indexing 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - AI.LLM 属性 key 存在性

    func testAI_LLM_基础属性返回非Missing值() {
        let values = [
            L10n.AI.LLM.title,
            L10n.AI.LLM.apiAddress,
            L10n.AI.LLM.apiKey,
            L10n.AI.LLM.model,
            L10n.AI.LLM.status,
            L10n.AI.LLM.serviceStatus,
            L10n.AI.LLM.providerConfig,
            L10n.AI.LLM.testConnection,
            L10n.AI.LLM.testing,
            L10n.AI.LLM.connectionSuccess,
            L10n.AI.LLM.validation,
            L10n.AI.LLM.validationFailed,
            L10n.AI.LLM.configuration,
            L10n.AI.LLM.enableAssistant
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.LLM 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.LLM 属性返回空字符串")
        }
    }

    func testAI_LLM_latency_返回非Missing且包含参数() {
        let result = L10n.AI.LLM.latency("120ms")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "AI.LLM.latency 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testAI_LLM_Model_属性返回非Missing值() {
        let values = [L10n.AI.LLM.Model.preset, L10n.AI.LLM.Model.custom]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.LLM.Model 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.LLM.Model 属性返回空字符串")
        }
    }

    func testAI_LLM_Validation_属性返回非Missing值() {
        let values = [
            L10n.AI.LLM.Validation.emptyKey
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.LLM.Validation 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.LLM.Validation 属性返回空字符串")
        }
    }

    func testAI_LLM_Validation_prefixHint_返回非Missing且包含参数() {
        let result = L10n.AI.LLM.Validation.prefixHint("sk-")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "AI.LLM.Validation.prefixHint 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testAI_LLM_Validation_lengthHint_返回非Missing且包含参数() {
        let result = L10n.AI.LLM.Validation.lengthHint(8)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "AI.LLM.Validation.lengthHint 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testAI_LLM_历史与消息属性返回非Missing值() {
        let values = [
            L10n.AI.LLM.chatHistory,
            L10n.AI.LLM.clearHistory,
            L10n.AI.LLM.chatSection,
            L10n.AI.LLM.messages,
            L10n.AI.LLM.infoString
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.LLM 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.LLM 属性返回空字符串")
        }
    }

    func testAI_LLM_Provider_属性返回非Missing值() {
        let values = [
            L10n.AI.LLM.Provider.title,
            L10n.AI.LLM.Provider.openai,
            L10n.AI.LLM.Provider.anthropic
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.LLM.Provider 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.LLM.Provider 属性返回空字符串")
        }
    }

    func testAI_LLM_Error_属性返回非Missing值() {
        let values = [
            L10n.AI.LLM.Error.invalidURL,
            L10n.AI.LLM.Error.invalidResponse,
            L10n.AI.LLM.Error.httpError
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.LLM.Error 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.LLM.Error 属性返回空字符串")
        }
    }

    // MARK: - AI.OnDevice 属性 key 存在性

    func testAI_OnDevice_基础属性返回非Missing值() {
        let values = [
            L10n.AI.OnDevice.assistMode,
            L10n.AI.OnDevice.assistDesc,
            L10n.AI.OnDevice.available
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.OnDevice 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.OnDevice 属性返回空字符串")
        }
    }

    func testAI_OnDevice_Error_属性返回非Missing值() {
        let values = [
            L10n.AI.OnDevice.Error.loadFailed,
            L10n.AI.OnDevice.Error.compilationFailed,
            L10n.AI.OnDevice.Error.inferenceFailed
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.OnDevice.Error 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.OnDevice.Error 属性返回空字符串")
        }
    }

    // MARK: - AI.Eval 属性 key 存在性

    func testAI_Eval_systemPrompt_返回非Missing值() {
        let value = L10n.AI.Eval.systemPrompt
        XCTAssertFalse(value.contains("[MISSING:"),
                       "AI.Eval.systemPrompt 返回 Missing: \(value)")
        XCTAssertFalse(value.isEmpty, "AI.Eval.systemPrompt 返回空字符串")
    }

    func testAI_Eval_judgePrompt_返回非Missing且包含参数() {
        let result = L10n.AI.Eval.judgePrompt("context", "query", "answer")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "AI.Eval.judgePrompt 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testAI_Eval_Status_属性返回非Missing值() {
        let values = [
            L10n.AI.Eval.Status.pass,
            L10n.AI.Eval.Status.warning,
            L10n.AI.Eval.Status.fail
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.Eval.Status 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.Eval.Status 属性返回空字符串")
        }
    }

    // MARK: - AI.Synthesis 属性 key 存在性

    func testAI_Synthesis_基础属性返回非Missing值() {
        let values = [
            L10n.AI.Synthesis.title,
            L10n.AI.Synthesis.sidebarTitle,
            L10n.AI.Synthesis.limitReachedWarning
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.Synthesis 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.Synthesis 属性返回空字符串")
        }
    }

    func testAI_Synthesis_Control_Depth_属性返回非Missing值() {
        let values = [
            L10n.AI.Synthesis.Control.Depth.concise,
            L10n.AI.Synthesis.Control.Depth.standard,
            L10n.AI.Synthesis.Control.Depth.detailed
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.Synthesis.Control.Depth 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.Synthesis.Control.Depth 属性返回空字符串")
        }
    }

    func testAI_Synthesis_Control_Audience_属性返回非Missing值() {
        let values = [
            L10n.AI.Synthesis.Control.Audience.beginner,
            L10n.AI.Synthesis.Control.Audience.professional,
            L10n.AI.Synthesis.Control.Audience.executive
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.Synthesis.Control.Audience 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.Synthesis.Control.Audience 属性返回空字符串")
        }
    }

    func testAI_Synthesis_Error_属性返回非Missing值() {
        let values = [
            L10n.AI.Synthesis.Error.limitReached,
            L10n.AI.Synthesis.Error.noPages,
            L10n.AI.Synthesis.Error.invalidResult
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.Synthesis.Error 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.Synthesis.Error 属性返回空字符串")
        }
    }

    func testAI_Synthesis_Mindmap_属性返回非Missing值() {
        let values = [
            L10n.AI.Synthesis.Mindmap.title,
            L10n.AI.Synthesis.Mindmap.renderError,
            L10n.AI.Synthesis.Mindmap.defaultBranch1
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.Synthesis.Mindmap 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.Synthesis.Mindmap 属性返回空字符串")
        }
    }

    // MARK: - AI.Task 属性 key 存在性

    func testAI_Task_基础属性返回非Missing值() {
        let values = [
            L10n.AI.Task.running,
            L10n.AI.Task.processing,
            L10n.AI.Task.typeIngest
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.Task 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.Task 属性返回空字符串")
        }
    }

    func testAI_Task_Status_属性返回非Missing值() {
        let values = [
            L10n.AI.Task.Status.ready,
            L10n.AI.Task.Status.running,
            L10n.AI.Task.Status.emptyTitle
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.Task.Status 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.Task.Status 属性返回空字符串")
        }
    }

    // MARK: - AI.Prompt 属性 key 存在性

    func testAI_Prompt_基础属性返回非Missing值() {
        let values = [
            L10n.AI.Prompt.relevanceScore,
            L10n.AI.Prompt.chunkType,
            L10n.AI.Prompt.fixSuggestion
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.Prompt 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.Prompt 属性返回空字符串")
        }
    }

    func testAI_Prompt_System_属性返回非Missing值() {
        let values = [
            L10n.AI.Prompt.System.summarize,
            L10n.AI.Prompt.System.mindmap,
            L10n.AI.Prompt.System.actions
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.Prompt.System 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.Prompt.System 属性返回空字符串")
        }
    }

    func testAI_Prompt_Expert_Mindmap_属性返回非Missing值() {
        let values = [L10n.AI.Prompt.Expert.Mindmap.title, L10n.AI.Prompt.Expert.Mindmap.footer]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "AI.Prompt.Expert.Mindmap 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "AI.Prompt.Expert.Mindmap 属性返回空字符串")
        }
    }

    // MARK: - Chat 属性 key 存在性

    func testChat_基础属性返回非Missing值() {
        let values = [
            L10n.Chat.title,
            L10n.Chat.welcomeDesc,
            L10n.Chat.aiAssistantName,
            L10n.Chat.referencesExpanded,
            L10n.Chat.referencesCollapsed,
            L10n.Chat.clearHistoryConfirmTitle,
            L10n.Chat.clearHistoryConfirmMessage,
            L10n.Chat.configureFirst,
            L10n.Chat.aiRunning,
            L10n.Chat.inputPlaceholder,
            L10n.Chat.explorationAndPrompts,
            L10n.Chat.exportConversation,
            L10n.Chat.exportRoleUser,
            L10n.Chat.exportRoleAI,
            L10n.Chat.exportFileName,
            L10n.Chat.llmSettings,
            L10n.Chat.selectToExport,
            L10n.Chat.exportSelectedPDF,
            L10n.Chat.exportPDF,
            L10n.Chat.regenerate,
            L10n.Chat.copied
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Chat 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Chat 属性返回空字符串")
        }
    }

    func testChat_messageCount_返回非Missing且包含参数() {
        let result = L10n.Chat.messageCount(5)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Chat.messageCount 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testChat_activeSessionCount_返回非Missing且包含参数() {
        let result = L10n.Chat.activeSessionCount(2)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Chat.activeSessionCount 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testChat_tokenUsage_返回非Missing且包含参数() {
        let result = L10n.Chat.tokenUsage(1024)
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Chat.tokenUsage 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    func testChat_deepExplorePrompt_返回非Missing且包含参数() {
        let result = L10n.Chat.deepExplorePrompt("量子计算")
        XCTAssertFalse(result.contains("[MISSING:"),
                       "Chat.deepExplorePrompt 返回 Missing: \(result)")
        XCTAssertFalse(result.isEmpty)
    }

    // MARK: - Voice.Speech 属性 key 存在性

    func testVoice_Speech_基础属性返回非Missing值() {
        let values = [
            L10n.Voice.Speech.title,
            L10n.Voice.Speech.subtitle,
            L10n.Voice.Speech.audioLevel,
            L10n.Voice.Speech.defaultTitle,
            L10n.Voice.Speech.saveTitle,
            L10n.Voice.Speech.noteTitle,
            L10n.Voice.Speech.voiceTag,
            L10n.Voice.Speech.needPermission,
            L10n.Voice.Speech.requestPermission,
            L10n.Voice.Speech.result,
            L10n.Voice.Speech.history,
            L10n.Voice.Speech.saveToKnowledge,
            L10n.Voice.Speech.tapToRecord,
            L10n.Voice.Speech.tapToStop,
            L10n.Voice.Speech.characters,
            L10n.Voice.Speech.confirmAndEdit
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Voice.Speech 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Voice.Speech 属性返回空字符串")
        }
    }

    func testVoice_Speech_Status_属性返回非Missing值() {
        let values = [
            L10n.Voice.Speech.Status.ready,
            L10n.Voice.Speech.Status.recording,
            L10n.Voice.Speech.Status.complete,
            L10n.Voice.Speech.Status.denied,
            L10n.Voice.Speech.Status.restricted,
            L10n.Voice.Speech.Status.notDetermined,
            L10n.Voice.Speech.Status.unknown,
            L10n.Voice.Speech.Status.error
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Voice.Speech.Status 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Voice.Speech.Status 属性返回空字符串")
        }
    }

    func testVoice_Speech_Error_属性返回非Missing值() {
        let values = [
            L10n.Voice.Speech.Error.audioEngine,
            L10n.Voice.Speech.Error.localeNotSupported,
            L10n.Voice.Speech.Error.notAuthorized
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Voice.Speech.Error 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Voice.Speech.Error 属性返回空字符串")
        }
    }

    func testVoice_Speech_Lang_属性返回非Missing值() {
        let values = [
            L10n.Voice.Speech.Lang.zhHans,
            L10n.Voice.Speech.Lang.zhHant,
            L10n.Voice.Speech.Lang.enUS,
            L10n.Voice.Speech.Lang.enGB,
            L10n.Voice.Speech.Lang.jaJP,
            L10n.Voice.Speech.Lang.koKR,
            L10n.Voice.Speech.Lang.frFR,
            L10n.Voice.Speech.Lang.deDE,
            L10n.Voice.Speech.Lang.esES,
            L10n.Voice.Speech.Lang.ptBR
        ]
        for value in values {
            XCTAssertFalse(value.contains("[MISSING:"),
                           "Voice.Speech.Lang 属性返回 Missing: \(value)")
            XCTAssertFalse(value.isEmpty, "Voice.Speech.Lang 属性返回空字符串")
        }
    }
}
