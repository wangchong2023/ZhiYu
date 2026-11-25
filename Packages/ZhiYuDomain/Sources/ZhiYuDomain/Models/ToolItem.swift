//
//  ToolItem.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：工具栏路由项枚举 — 定义应用内各功能入口的标准化标识符，支持侧边栏和路由系统。
//
import Foundation

/// 应用内工具页面路由枚举
/// 对应侧边栏或工具栏中的各功能入口，与 SidebarSelection 共同构成路由系统
public enum ToolItem: String, CaseIterable, Hashable {
    case pageList     = "index"
    case dashboard    = "dashboard"
    case tagCloud     = "tagCloud"
    case taskCenter   = "chat"
    case chat         = "chat_ai"
    case synthesis    = "synthesis"
    case weeklyReport = "weeklyReport"
    case log          = "log"
    case collab       = "collab"
    case pluginMarket = "pluginMarket"
    case search       = "search"
    case ingest       = "ingest"
    case graph        = "graph"
    case lint         = "lint"
    case healthCheck  = "healthCheck"
    case sources      = "sources"
}
