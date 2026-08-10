//
//  SourceStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：负责在对话或生成时，将命中的 RAG 信源列表保持全局响应式状态以供 UI 侧追溯渲染。
//
import Foundation
import Observation

/// [L1.5] 信源状态存储器
@MainActor
@Observable
public final class SourceStore {
    public static let shared = SourceStore()
    
    /// 当前活跃的信源列表 (对标 NotebookLM 的 Sources 面板)
    public private(set) var activeSources: [KnowledgeSource] = []
    
    private init() {}
    
    /// 根据检索到的 RAG 源片段刷新侧边栏信源列表
    /// - Parameter sources: 已通过向量排名的信源块数组
    @MainActor
    /// 刷新当前活跃 RAG 信源列表
    public func updateSources(_ sources: [KnowledgeSource]) {
        self.activeSources = sources.sorted { $0.score > $1.score }
    }
    
    /// 重置并清空所有已展示的信源状态，通常在新建会话时调用
    @MainActor
    /// 清空活跃信源列表
    public func clear() {
        self.activeSources = []
    }
}
