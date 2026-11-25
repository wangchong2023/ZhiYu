//
//  AgentTool.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义 Agent 智能工具契约结构。封装大模型进行工具调用 (Tool Calling) 时的 Schema 参数、名称描述，以契合端侧 RAG 架构的动态函数分流。
//

import Foundation

/// 动态 Agent 智能工具结构实体
public struct AgentTool: Codable, Sendable, Identifiable, Equatable {
    /// 唯一标识 ID
    public var id: String { toolName }
    
    /// 工具唯一注册名称 (如: "queryVectorDB", "fetchCalendarEvents")
    public let toolName: String
    
    /// 工具的核心职责描述，用于告知 LLM 在什么场景下该主动挑选并调用此工具
    public let description: String
    
    /// 工具调用所需入参的规范 JSON Schema，大模型据此生成标准的调用 JSON 字符串
    public let parametersSchema: String
    
    /// 该工具所属的版本号
    public let version: String
    
    public init(
        toolName: String,
        description: String,
        parametersSchema: String,
        version: String = "1.0.0"
    ) {
        self.toolName = toolName
        self.description = description
        self.parametersSchema = parametersSchema
        self.version = version
    }
}
