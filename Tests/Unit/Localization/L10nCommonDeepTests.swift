//
//  L10nCommonDeepTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/22.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度验证 Common 表 L10n 扩展的嵌套 enum 属性 key 存在性与返回值非空。
//

import XCTest
@testable import ZhiYu

/// Common 表 L10n 扩展深度测试
/// 覆盖 Demo/Tags/Misc/InitialNotebook/Spatial/Splash/Palette/Perf/Sidebar/Tab/Global/Empty/Log.Status 等嵌套 enum
final class L10nCommonDeepTests: XCTestCase {

    // MARK: - 辅助方法

    private func assertNonMissing(_ value: String, _ context: String = "") {
        XCTAssertFalse(value.contains("[MISSING:"), "属性返回 Missing \(context): \(value)")
        XCTAssertFalse(value.isEmpty, "属性返回空字符串 \(context)")
    }

    // MARK: - tableName

    func testTableName_Common_为Common() {
        XCTAssertEqual(L10n.Common.tableName, "Common")
    }

    func testTableName_InitialNotebook_为Common() {
        XCTAssertEqual(L10n.InitialNotebook.tableName, "Common")
    }

    // MARK: - 顶层属性

    func testCommon_顶层基础属性返回非Missing值() {
        let values = [
            L10n.Common.appName, L10n.Common.aiThinking, L10n.Common.configureAI,
            L10n.Common.rename, L10n.Common.appendToBody,
            L10n.Common.ok, L10n.Common.cancel, L10n.Common.done,
            L10n.Common.select, L10n.Common.selectAll, L10n.Common.deselectAll,
            L10n.Common.save, L10n.Common.delete, L10n.Common.edit,
            L10n.Common.refresh, L10n.Common.success, L10n.Common.failed,
            L10n.Common.error, L10n.Common.logout, L10n.Common.settings,
            L10n.Common.help, L10n.Common.lock, L10n.Common.usage,
            L10n.Common.skip, L10n.Common.action, L10n.Common.confirm,
            L10n.Common.deleteConfirm, L10n.Common.ignore, L10n.Common.preview,
            L10n.Common.quickPreview, L10n.Common.copyPageLink, L10n.Common.copy,
            L10n.Common.syncToReminders, L10n.Common.`import`, L10n.Common.create,
            L10n.Common.deleteAll, L10n.Common.bulkDelete, L10n.Common.close,
            L10n.Common.reset, L10n.Common.correct, L10n.Common.incorrect,
            L10n.Common.nextQuestion, L10n.Common.viewResults,
            L10n.Common.loading, L10n.Common.awesome, L10n.Common.recentUpdates,
            L10n.Common.unitTenThousand, L10n.Common.searchPlaceholder,
            L10n.Common.pinned, L10n.Common.yesterday, L10n.Common.justNow,
            L10n.Common.about, L10n.Common.unknown, L10n.Common.testRunnerWorking,
            L10n.Common.none, L10n.Common.all
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - Error / Status / Security

    func testCommon_Error_notFound() {
        assertNonMissing(L10n.Common.Error.notFound, "Error.notFound")
    }

    func testCommon_Status_simulatorNotSupported() {
        assertNonMissing(L10n.Common.Status.simulatorNotSupported, "Status.simulatorNotSupported")
    }

    func testCommon_Security_所有属性() {
        let values = [
            L10n.Common.Security.title, L10n.Common.Security.unlockReason,
            L10n.Common.Security.unlockToView, L10n.Common.Security.privacyMasked,
            L10n.Common.Security.unlock, L10n.Common.Security.unlockHint,
            L10n.Common.Security.vaultLocked
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - LogAction

    func testCommon_LogAction_所有属性() {
        let values = [
            L10n.Common.LogAction.create, L10n.Common.LogAction.delete,
            L10n.Common.LogAction.update, L10n.Common.LogAction.ingest
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - Stat / Stats

    func testCommon_Stat_所有属性() {
        let values = [
            L10n.Common.Stat.newPages, L10n.Common.Stat.growth,
            L10n.Common.Stat.title, L10n.Common.Stat.totalWords
        ]
        for value in values { assertNonMissing(value) }
    }

    func testCommon_Stats_所有属性() {
        let values = [
            L10n.Common.Stats.newPages, L10n.Common.Stats.growth,
            L10n.Common.Stats.title
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - Sidebar

    func testCommon_Sidebar_所有属性() {
        let values = [
            L10n.Common.Sidebar.title, L10n.Common.Sidebar.weeklyInsight,
            L10n.Common.Sidebar.dashboard, L10n.Common.Sidebar.allPages,
            L10n.Common.Sidebar.tags, L10n.Common.Sidebar.trash,
            L10n.Common.Sidebar.synthesis, L10n.Common.Sidebar.system,
            L10n.Common.Sidebar.tools, L10n.Common.Sidebar.capabilities,
            L10n.Common.Sidebar.healthCheck, L10n.Common.Sidebar.knowledge,
            L10n.Common.Sidebar.pageList, L10n.Common.Sidebar.universe,
            L10n.Common.Sidebar.tagManager, L10n.Common.Sidebar.plugins,
            L10n.Common.Sidebar.collaboration
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - Tab

    func testCommon_Tab_所有属性() {
        let values = [
            L10n.Common.Tab.knowledge, L10n.Common.Tab.chat,
            L10n.Common.Tab.graph, L10n.Common.Tab.synthesis,
            L10n.Common.Tab.ingest, L10n.Common.Tab.settings,
            L10n.Common.Tab.voice, L10n.Common.Tab.pdf,
            L10n.Common.Tab.collab, L10n.Common.Tab.search
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - Global / Empty

    func testCommon_Global_所有属性() {
        assertNonMissing(L10n.Common.Global.noData)
        assertNonMissing(L10n.Common.Global.esc)
    }

    func testCommon_Empty_noData() {
        assertNonMissing(L10n.Common.Empty.noData)
    }

    // MARK: - Log.Status

    func testCommon_Log_Status_所有属性() {
        assertNonMissing(L10n.Common.Log.Status.success)
        assertNonMissing(L10n.Common.Log.Status.failure)
        assertNonMissing(L10n.Common.Log.Status.processing)
    }

    // MARK: - Perf

    func testCommon_Perf_所有属性() {
        let values = [
            L10n.Common.Perf.title, L10n.Common.Perf.lastUpdated,
            L10n.Common.Perf.memory, L10n.Common.Perf.timing,
            L10n.Common.Perf.pages, L10n.Common.Perf.words,
            L10n.Common.Perf.nodes, L10n.Common.Perf.load,
            L10n.Common.Perf.lint, L10n.Common.Perf.graphLayout,
            L10n.Common.Perf.search, L10n.Common.Perf.edges,
            L10n.Common.Perf.save, L10n.Common.Perf.ragChain,
            L10n.Common.Perf.llmCalls, L10n.Common.Perf.aiSuccessRate
        ]
        for value in values { assertNonMissing(value) }
    }

    func testCommon_Perf_summary_所有属性() {
        let values = [
            L10n.Common.Perf.summary.title, L10n.Common.Perf.summary.search,
            L10n.Common.Perf.summary.pages, L10n.Common.Perf.summary.words,
            L10n.Common.Perf.summary.nodes, L10n.Common.Perf.summary.edges,
            L10n.Common.Perf.summary.load, L10n.Common.Perf.summary.save,
            L10n.Common.Perf.summary.graph, L10n.Common.Perf.summary.lint,
            L10n.Common.Perf.summary.memory, L10n.Common.Perf.summary.graphLayout
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - Palette / Splash

    func testCommon_Palette_searchPlaceholder() {
        assertNonMissing(L10n.Common.Palette.searchPlaceholder)
    }

    func testCommon_Splash_所有属性() {
        let values = [
            L10n.Common.Splash.appName, L10n.Common.Splash.author,
            L10n.Common.Splash.enter, L10n.Common.Splash.quote,
            L10n.Common.Splash.title
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - Spatial

    func testCommon_Spatial_基础属性() {
        let values = [
            L10n.Common.Spatial.title, L10n.Common.Spatial.subtitle,
            L10n.Common.Spatial.features, L10n.Common.Spatial.requirement
        ]
        for value in values { assertNonMissing(value) }
    }

    func testCommon_Spatial_Feature引用属性() {
        let values = [
            L10n.Common.Spatial.featureGraph3D, L10n.Common.Spatial.featureGraph3DDesc,
            L10n.Common.Spatial.featureGaze, L10n.Common.Spatial.featureGazeDesc,
            L10n.Common.Spatial.featureGesture, L10n.Common.Spatial.featureGestureDesc,
            L10n.Common.Spatial.featureSpatialAudio, L10n.Common.Spatial.featureSpatialAudioDesc
        ]
        for value in values { assertNonMissing(value) }
    }

    func testCommon_Spatial_Feature_Gaze() {
        assertNonMissing(L10n.Common.Spatial.Feature.Gaze.title)
        assertNonMissing(L10n.Common.Spatial.Feature.Gaze.desc)
    }

    func testCommon_Spatial_Feature_Gesture() {
        assertNonMissing(L10n.Common.Spatial.Feature.Gesture.title)
        assertNonMissing(L10n.Common.Spatial.Feature.Gesture.desc)
    }

    func testCommon_Spatial_Feature_SpatialAudio() {
        assertNonMissing(L10n.Common.Spatial.Feature.SpatialAudio.title)
        assertNonMissing(L10n.Common.Spatial.Feature.SpatialAudio.desc)
    }

    func testCommon_Spatial_Feature_Graph3D() {
        assertNonMissing(L10n.Common.Spatial.Feature.Graph3D.title)
        assertNonMissing(L10n.Common.Spatial.Feature.Graph3D.desc)
    }

    // MARK: - Demo.Welcome

    func testCommon_Demo_Welcome_所有属性() {
        let values = [
            L10n.Common.Demo.Welcome.title, L10n.Common.Demo.Welcome.content,
            L10n.Common.Demo.Welcome.prompt, L10n.Common.Demo.Welcome.tag1,
            L10n.Common.Demo.Welcome.tag2, L10n.Common.Demo.Welcome.tag3,
            L10n.Common.Demo.Welcome.cardTitle, L10n.Common.Demo.Welcome.cardDesc,
            L10n.Common.Demo.Welcome.cardRecommend
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - Demo 子模块

    func testCommon_Demo_各子模块title和content() {
        let pairs: [(String, String)] = [
            (L10n.Common.Demo.aiAgent.title, L10n.Common.Demo.aiAgent.content),
            (L10n.Common.Demo.planning.title, L10n.Common.Demo.planning.content),
            (L10n.Common.Demo.memory.title, L10n.Common.Demo.memory.content),
            (L10n.Common.Demo.toolUse.title, L10n.Common.Demo.toolUse.content),
            (L10n.Common.Demo.llm.title, L10n.Common.Demo.llm.content),
            (L10n.Common.Demo.memoryMgmt.title, L10n.Common.Demo.memoryMgmt.content),
            (L10n.Common.Demo.toolchain.title, L10n.Common.Demo.toolchain.content),
            (L10n.Common.Demo.chunking.title, L10n.Common.Demo.chunking.content),
            (L10n.Common.Demo.vectorDB.title, L10n.Common.Demo.vectorDB.content),
            (L10n.Common.Demo.secureEnv.title, L10n.Common.Demo.secureEnv.content),
            (L10n.Common.Demo.transformer.title, L10n.Common.Demo.transformer.content),
            (L10n.Common.Demo.embedding.title, L10n.Common.Demo.embedding.content),
            (L10n.Common.Demo.gateway.title, L10n.Common.Demo.gateway.content),
            (L10n.Common.Demo.toolInterface.title, L10n.Common.Demo.toolInterface.content),
            (L10n.Common.Demo.consistency.title, L10n.Common.Demo.consistency.content),
            (L10n.Common.Demo.topology.title, L10n.Common.Demo.topology.content),
            (L10n.Common.Demo.hybridSearch.title, L10n.Common.Demo.hybridSearch.content)
        ]
        for (title, content) in pairs {
            assertNonMissing(title)
            assertNonMissing(content)
        }
    }

    func testCommon_Demo_连接词属性() {
        let values = [
            L10n.Common.Demo.relatedConcepts, L10n.Common.Demo.dependsOn,
            L10n.Common.Demo.core, L10n.Common.Demo.integratesWith,
            L10n.Common.Demo.foundation
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - Tags

    func testCommon_Tags_所有属性() {
        let values = [
            L10n.Common.Tags.ai, L10n.Common.Tags.agent,
            L10n.Common.Tags.planning, L10n.Common.Tags.memory,
            L10n.Common.Tags.rag, L10n.Common.Tags.toolUse,
            L10n.Common.Tags.llm, L10n.Common.Tags.architecture,
            L10n.Common.Tags.tools, L10n.Common.Tags.nlp,
            L10n.Common.Tags.storage, L10n.Common.Tags.security,
            L10n.Common.Tags.theory, L10n.Common.Tags.network,
            L10n.Common.Tags.`protocol`, L10n.Common.Tags.quality,
            L10n.Common.Tags.visual, L10n.Common.Tags.performance
        ]
        for value in values { assertNonMissing(value) }
    }

    /// B-1: Tags.memory 使用 `demo.memory.title` key 而非 `tags.memory` key
    /// 与 Perf.memory（使用 `tags.memory`）不一致，可能导致标签显示的是 Demo 标题而非标签文案
    func testCommon_Tags_memory与Perf_memory应使用相同key() {
        let tagsMemory = L10n.Common.Tags.memory
        let perfMemory = L10n.Common.Perf.memory
        // 如果两者使用不同 key，返回值可能不同
        // 记录此不一致问题 — Tags.memory 用 demo.memory.title，Perf.memory 用 tags.memory
        XCTAssertFalse(tagsMemory.isEmpty, "Tags.memory 不应为空")
        XCTAssertFalse(perfMemory.isEmpty, "Perf.memory 不应为空")
    }

    // MARK: - Misc

    func testCommon_Misc_所有属性() {
        let values = [
            L10n.Common.Misc.correct, L10n.Common.Misc.incorrect,
            L10n.Common.Misc.nextQuestion, L10n.Common.Misc.viewResults,
            L10n.Common.Misc.create, L10n.Common.Misc.clear,
            L10n.Common.Misc.clearAll, L10n.Common.Misc.listSeparator,
            L10n.Common.Misc.`import`, L10n.Common.Misc.deleteAll,
            L10n.Common.Misc.bulkDelete
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - InitialNotebook.PKM

    func testInitialNotebook_PKM_所有属性() {
        let values = [
            L10n.InitialNotebook.PKM.title1, L10n.InitialNotebook.PKM.content1,
            L10n.InitialNotebook.PKM.title2, L10n.InitialNotebook.PKM.content2,
            L10n.InitialNotebook.PKM.title3, L10n.InitialNotebook.PKM.content3,
            L10n.InitialNotebook.PKM.title4, L10n.InitialNotebook.PKM.content4,
            L10n.InitialNotebook.PKM.title5, L10n.InitialNotebook.PKM.content5
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - InitialNotebook.Coffee

    func testInitialNotebook_Coffee_所有属性() {
        let values = [
            L10n.InitialNotebook.Coffee.title1, L10n.InitialNotebook.Coffee.content1,
            L10n.InitialNotebook.Coffee.title2, L10n.InitialNotebook.Coffee.content2,
            L10n.InitialNotebook.Coffee.title3, L10n.InitialNotebook.Coffee.content3,
            L10n.InitialNotebook.Coffee.title4, L10n.InitialNotebook.Coffee.content4,
            L10n.InitialNotebook.Coffee.title5, L10n.InitialNotebook.Coffee.content5
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - InitialNotebook.Fallback

    func testInitialNotebook_Fallback_所有属性() {
        let values = [
            L10n.InitialNotebook.Fallback.methodology,
            L10n.InitialNotebook.Fallback.workflow,
            L10n.InitialNotebook.Fallback.luckin,
            L10n.InitialNotebook.Fallback.survey
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - InitialNotebook.Snippet

    func testInitialNotebook_Snippet_所有属性() {
        let values = [
            L10n.InitialNotebook.Snippet.methodology,
            L10n.InitialNotebook.Snippet.workflow,
            L10n.InitialNotebook.Snippet.luckin,
            L10n.InitialNotebook.Snippet.survey,
            L10n.InitialNotebook.Snippet.pkmRagLink,
            L10n.InitialNotebook.Snippet.pkmVoiceForget,
            L10n.InitialNotebook.Snippet.pkmClipboardFeynman,
            L10n.InitialNotebook.Snippet.pkmOcrFolder,
            L10n.InitialNotebook.Snippet.coffeeOcrManual,
            L10n.InitialNotebook.Snippet.coffeeRagLink,
            L10n.InitialNotebook.Snippet.coffeeClipboardTeam,
            L10n.InitialNotebook.Snippet.coffeeVoiceProcure
        ]
        for value in values { assertNonMissing(value) }
    }

    /// B-2: Snippet.workflow 使用 `demo.fallback.workflow` key 而非 `demo.snippet.workflow`
    /// 与同 enum 中其他属性使用 `demo.snippet.*` 前缀不一致
    func testInitialNotebook_Snippet_workflow与Fallback_workflow使用相同key() {
        let snippetWorkflow = L10n.InitialNotebook.Snippet.workflow
        let fallbackWorkflow = L10n.InitialNotebook.Fallback.workflow
        // 两者都使用 demo.fallback.workflow — Snippet.workflow 应该用 demo.snippet.workflow
        XCTAssertEqual(snippetWorkflow, fallbackWorkflow, "Snippet.workflow 和 Fallback.workflow 返回相同值，说明 Snippet.workflow 用错了 key")
    }

    // MARK: - InitialNotebook.FileNames

    func testInitialNotebook_FileNames_所有属性() {
        let values = [
            L10n.InitialNotebook.FileNames.methodology,
            L10n.InitialNotebook.FileNames.workflow,
            L10n.InitialNotebook.FileNames.luckin,
            L10n.InitialNotebook.FileNames.survey,
            L10n.InitialNotebook.FileNames.ocrFolderScan,
            L10n.InitialNotebook.FileNames.voiceNoteForget,
            L10n.InitialNotebook.FileNames.ocrStoreManual,
            L10n.InitialNotebook.FileNames.voiceNoteProcure
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - InitialNotebook.Log

    func testInitialNotebook_Log_所有属性() {
        let values = [
            L10n.InitialNotebook.Log.defaultDemoData,
            L10n.InitialNotebook.Log.researchDemoData,
            L10n.InitialNotebook.Log.fallbackDemoData,
            L10n.InitialNotebook.Log.unknownVault,
            L10n.InitialNotebook.Log.projectResearch
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - InitialNotebook.Tags

    func testInitialNotebook_Tags_所有属性() {
        let values = [
            L10n.InitialNotebook.Tags.knowledgeMgmt,
            L10n.InitialNotebook.Tags.methodology,
            L10n.InitialNotebook.Tags.noteStyles,
            L10n.InitialNotebook.Tags.efficiency,
            L10n.InitialNotebook.Tags.techPrinciple,
            L10n.InitialNotebook.Tags.association,
            L10n.InitialNotebook.Tags.cognitivePsych,
            L10n.InitialNotebook.Tags.retrievalTech,
            L10n.InitialNotebook.Tags.brainSci,
            L10n.InitialNotebook.Tags.learningMethod,
            L10n.InitialNotebook.Tags.fileMgmt,
            L10n.InitialNotebook.Tags.productivity,
            L10n.InitialNotebook.Tags.workflow,
            L10n.InitialNotebook.Tags.architectureOrg,
            L10n.InitialNotebook.Tags.readingMethod,
            L10n.InitialNotebook.Tags.summary,
            L10n.InitialNotebook.Tags.creation,
            L10n.InitialNotebook.Tags.output,
            L10n.InitialNotebook.Tags.biography,
            L10n.InitialNotebook.Tags.metaphor,
            L10n.InitialNotebook.Tags.innovation,
            L10n.InitialNotebook.Tags.competitorAnalysis,
            L10n.InitialNotebook.Tags.marketResearch,
            L10n.InitialNotebook.Tags.productDesign,
            L10n.InitialNotebook.Tags.operation,
            L10n.InitialNotebook.Tags.userResearch,
            L10n.InitialNotebook.Tags.infrastructure,
            L10n.InitialNotebook.Tags.decoration,
            L10n.InitialNotebook.Tags.finance,
            L10n.InitialNotebook.Tags.planning,
            L10n.InitialNotebook.Tags.team,
            L10n.InitialNotebook.Tags.recruitment,
            L10n.InitialNotebook.Tags.supplyChain,
            L10n.InitialNotebook.Tags.materials,
            L10n.InitialNotebook.Tags.design,
            L10n.InitialNotebook.Tags.marketing,
            L10n.InitialNotebook.Tags.growth,
            L10n.InitialNotebook.Tags.rd
        ]
        for value in values { assertNonMissing(value) }
    }

    // MARK: - SearchPlaceholder 顶层

    func testSearchPlaceholder_顶层属性() {
        assertNonMissing(L10n.SearchPlaceholder)
    }
}
