//
//  DashboardCoordinator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：负责 Dashboard 业务流的导航路由与协作管理。
//
import SwiftUI
import Observation

@MainActor
@Observable
final class DashboardCoordinator {
    // ── 状态属性 ──
    var tags: [(tag: String, count: Int)] = []
    var totalLinks = 0
    var densityData: [DensityInfo] = []
    var isCalculating = false
    
    // ── AI 洞察状态（由 Observable 追踪，确保 UI 响应式更新） ──
    /// 是否正在生成每日灵感见解
    var isGeneratingInsights = false
    /// 当前缓存在内存中的每日灵感数据
    var dailyRecap: KnowledgeInsightService.DailyRecap?
    
    // ── 基础设施依赖 ──
    @ObservationIgnored @Inject private var store: AppStore
    @ObservationIgnored @Inject private var aiStore: AIInsightStore
    @ObservationIgnored @Inject private var logger: any LoggerProtocol

    init() {}

    // ── 业务动作 ──

    /// 刷新所有统计数据与 AI 洞察
    func refreshAll() async {
        guard !Task.isCancelled else { return }
        isCalculating = true
        updateTags()
        guard !Task.isCancelled else { isCalculating = false; return }
        await calculateStats()
        guard !Task.isCancelled else { isCalculating = false; return }
        await refreshInsights()
        isCalculating = false
    }

    /// 仅触发 AI 洞察刷新并同步追踪状态
    func refreshInsights() async {
        // 同步启动生成状态
        self.isGeneratingInsights = true
        
        // 异步调用底层 AI 洞察商店的生成动作
        await aiStore.generateDailyRecap(forceRefresh: false)
        
        // 将底层状态实时同步至本地追踪属性，触发 UI 重新渲染
        self.dailyRecap = aiStore.dailyRecap
        self.isGeneratingInsights = aiStore.isGeneratingDailyRecap
    }

    /// 计算知识库核心统计指标（反链、密度等）
    func calculateStats() async {
        let pages = store.pages
        guard !pages.isEmpty else {
            self.totalLinks = 0
            self.densityData = []
            return
        }
        
        // 1. 计算反链地图 (In-memory calculation)
        var backlinkMap: [String: Int] = [:]
        for page in pages {
            for link in page.outgoingLinks {
                backlinkMap[link, default: 0] += 1
            }
        }
        
        // 2. 计算总链接数
        let links = pages.reduce(0) { $0 + $1.outgoingLinks.count }
        
        // 3. 计算重要度 (In + Out) Top 5 密度数据
        let density = pages.map { page in
            let inbound = backlinkMap[page.title, default: 0]
            let outbound = page.outgoingLinks.count
            return DensityInfo(name: page.title, inbound: Double(inbound), outbound: Double(outbound))
        }
        .sorted { ($0.inbound + $0.outbound) > ($1.inbound + $1.outbound) }
        .prefix(5)
        .map { $0 }
        
        // 更新状态
        self.totalLinks = links
        self.densityData = density
        
        logger.debug(" [Dashboard] : \(links) , \(density.count) ")
    }

    /// 聚合标签分布
    func updateTags() {
        var dict: [String: Int] = [:]
        for page in store.pages {
            for tag in page.getAllTags() {
                dict[tag, default: 0] += 1
            }
        }
        self.tags = dict.map { ($0.key, $0.value) }.sorted { $0.count > $1.count }
    }
}
