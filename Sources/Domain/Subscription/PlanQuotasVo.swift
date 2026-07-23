//
//  PlanQuotasVo.swift
//  ZhiYu
//
//  Created by Constantine on 2026/07/23.
//  Description: C 端套餐能力与配额结构体，100% 对应后端 quotas_json 数据库及 JSON 协议。
//

import Foundation

/// 订阅套餐能力与配额对象，映射后端数据库 quotas_json
public struct PlanQuotasVo: Codable, Equatable, Sendable {

    // MARK: - 数字型配额上限 (-1 表示无限)

    /// 最大知识页数，-1 表示无限
    public var maxKnowledgePages: Int

    /// 最大独立金库数，-1 表示无限
    public var maxVaultsCount: Int

    /// 单文件附件大小上限 (MB)
    public var maxFileSizeMb: Int

    /// 每日云端 AI 消息上限，-1 表示无限
    public var dailyAiMessages: Int

    // MARK: - 布尔型能力开关与高级特权

    /// 是否开启高阶云端大模型 (GPT-4o / Claude 3.5)
    public var cloudLlmModelsEnabled: Bool

    /// 是否开启向量语义 (Vector RAG) 混合检索
    public var vectorSearchEnabled: Bool

    /// 是否开启 3D 图谱时间轴演化与高级聚类
    public var graphAdvancedEnabled: Bool

    /// 是否开启双人播客语音合成 (Audio Overview)
    public var audioOverviewEnabled: Bool

    /// 是否开启大文件 iCloud 同步
    public var largeAttachmentSync: Bool

    /// 是否开启 Word (.docx) 及 PPTX 高级格式导出
    public var advancedExportEnabled: Bool

    /// 是否开启 macOS Spotlight 深度索引
    public var spotlightIndexingEnabled: Bool

    /// 是否开启 Pro 专属插件市场访问特权
    public var proPluginsEnabled: Bool

    /// 是否允许自定义 Local LLM / Ollama 节点
    public var customLocalLlmEnabled: Bool

    /// 无广告体验
    public var adFreeEnabled: Bool

    // MARK: - Initializer

    public init(
        maxKnowledgePages: Int,
        maxVaultsCount: Int,
        maxFileSizeMb: Int,
        dailyAiMessages: Int,
        cloudLlmModelsEnabled: Bool,
        vectorSearchEnabled: Bool,
        graphAdvancedEnabled: Bool,
        audioOverviewEnabled: Bool,
        largeAttachmentSync: Bool,
        advancedExportEnabled: Bool,
        spotlightIndexingEnabled: Bool,
        proPluginsEnabled: Bool,
        customLocalLlmEnabled: Bool,
        adFreeEnabled: Bool
    ) {
        self.maxKnowledgePages = maxKnowledgePages
        self.maxVaultsCount = maxVaultsCount
        self.maxFileSizeMb = maxFileSizeMb
        self.dailyAiMessages = dailyAiMessages
        self.cloudLlmModelsEnabled = cloudLlmModelsEnabled
        self.vectorSearchEnabled = vectorSearchEnabled
        self.graphAdvancedEnabled = graphAdvancedEnabled
        self.audioOverviewEnabled = audioOverviewEnabled
        self.largeAttachmentSync = largeAttachmentSync
        self.advancedExportEnabled = advancedExportEnabled
        self.spotlightIndexingEnabled = spotlightIndexingEnabled
        self.proPluginsEnabled = proPluginsEnabled
        self.customLocalLlmEnabled = customLocalLlmEnabled
        self.adFreeEnabled = adFreeEnabled
    }

    // MARK: - CodingKeys (下划线 snake_case <-> 驼峰 camelCase)

    private enum CodingKeys: String, CodingKey {
        case maxKnowledgePages = "max_knowledge_pages"
        case maxVaultsCount = "max_vaults_count"
        case maxFileSizeMb = "max_file_size_mb"
        case dailyAiMessages = "daily_ai_messages"
        case cloudLlmModelsEnabled = "cloud_llm_models_enabled"
        case vectorSearchEnabled = "vector_search_enabled"
        case graphAdvancedEnabled = "graph_advanced_enabled"
        case audioOverviewEnabled = "audio_overview_enabled"
        case largeAttachmentSync = "large_attachment_sync"
        case advancedExportEnabled = "advanced_export_enabled"
        case spotlightIndexingEnabled = "spotlight_indexing_enabled"
        case proPluginsEnabled = "pro_plugins_enabled"
        case customLocalLlmEnabled = "custom_local_llm_enabled"
        case adFreeEnabled = "ad_free_enabled"
    }
}

// MARK: - Static Factory Defaults

extension PlanQuotasVo {

    /// Lite 离线冷启动保底基线 (Cold-Start Baseline)
    public static var createLiteDefault: PlanQuotasVo {
        PlanQuotasVo(
            maxKnowledgePages: 1000,
            maxVaultsCount: 2,
            maxFileSizeMb: 10,
            dailyAiMessages: 0, // 离线无云端消息
            cloudLlmModelsEnabled: false,
            vectorSearchEnabled: false,
            graphAdvancedEnabled: false,
            audioOverviewEnabled: false,
            largeAttachmentSync: false,
            advancedExportEnabled: false,
            spotlightIndexingEnabled: false,
            proPluginsEnabled: false,
            customLocalLlmEnabled: true, // 允许连接本地 Ollama
            adFreeEnabled: true
        )
    }

    /// Pro 专业版无限基线
    public static var createProDefault: PlanQuotasVo {
        PlanQuotasVo(
            maxKnowledgePages: -1,
            maxVaultsCount: -1,
            maxFileSizeMb: 200,
            dailyAiMessages: -1,
            cloudLlmModelsEnabled: true,
            vectorSearchEnabled: true,
            graphAdvancedEnabled: true,
            audioOverviewEnabled: true,
            largeAttachmentSync: true,
            advancedExportEnabled: true,
            spotlightIndexingEnabled: true,
            proPluginsEnabled: true,
            customLocalLlmEnabled: true,
            adFreeEnabled: true
        )
    }
}
