//
//  AgentSkill.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义动态 Agent 智能技能的领域模型结构，封装 Prompt 模板、输入限制与应用场景元数据。
//

import Foundation

/// 动态 Agent 智能体技能描述实体
public struct AgentSkill: Codable, Sendable, Identifiable, Equatable {
    /// 唯一标识 ID
    public var id: String { skillId }
    
    /// 技能唯一 ID 标识 (如: "markdown_formatter", "link_discovery", "depth_research")
    public let skillId: String
    
    /// 技能展示名称
    public let displayName: String
    
    /// 技能描述
    public let description: String
    
    /// 系统级 System Prompt 推理模板 (支持 {{input}} 动态参数占位符替换)
    public let systemPromptTemplate: String
    
    /// 外部托管的复杂 Markdown Prompt 纯文本拉取 URL (为 nil 时直接采用本地预设的 systemPromptTemplate)
    public let remotePromptURLString: String?
    
    /// 远程 Prompt 的 SHA-256 哈希值（VULN-009 修复：完整性校验，防止 MITM 篡改）
    /// - Note: 若提供此字段，下载的远程 Prompt 必须匹配此哈希，否则拒绝使用并降级到本地模板
    public let remotePromptSHA256: String?
    
    /// 输入限制规约 JSON Schema 描述串 (可选)，用于约束返回格式或交互参数校验
    public let inputSchema: String?
    
    /// 适用场景标签 (如: ["Tagging", "Synthesis", "Chat"])
    public let tags: [String]
    
    /// 技能专属首选的推理超参覆盖 (为 nil 时自动降级为大模型 Manifest 默认超参)
    public let customParameters: InferenceParameters?
    
    /// 技能版本号，用于判断远端热更新与缓存对比
    public let version: String
    
    public init(
        skillId: String,
        displayName: String,
        description: String,
        systemPromptTemplate: String,
        remotePromptURLString: String? = nil,
        remotePromptSHA256: String? = nil,
        inputSchema: String? = nil,
        tags: [String] = [],
        customParameters: InferenceParameters? = nil,
        version: String = "1.0.0"
    ) {
        self.skillId = skillId
        self.displayName = displayName
        self.description = description
        self.systemPromptTemplate = systemPromptTemplate
        self.remotePromptURLString = remotePromptURLString
        self.remotePromptSHA256 = remotePromptSHA256
        self.inputSchema = inputSchema
        self.tags = tags
        self.customParameters = customParameters
        self.version = version
    }
}
