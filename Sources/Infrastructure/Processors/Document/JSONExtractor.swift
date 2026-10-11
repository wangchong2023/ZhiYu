//
//  JSONExtractor.swift
//  ZhiYu
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：兼容层。JSONExtractor 已下沉至 UFPCore 通用底座包，此处保留 typealias 以维持 App 层既有调用点（KnowledgeInsightService / IngestCoordinator）无需改动。
//
import UFPCore

/// JSON 对象提取工具（兼容层，实际实现见 `UFPCore.JSONExtractor`）
public typealias JSONExtractor = UFPCore.JSONExtractor
