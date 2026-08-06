//
//  NotebookThemeFactory.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：笔记本中心：入口页面、笔记本卡片、创建表单。
//
import Foundation

/// [L2] 笔记本主题工厂：负责基于 AI 语义启发生成动态背景配置
public struct NotebookThemeFactory {
    /// 语义配色列表：将标题关键字映射到特定的色系（有序数组保证 first-match-wins 语义）
    private static let semanticPalettes: [(keyword: String, colors: [String])] = [
        ("tech", ["#4A90E2", "#50E3C2", "#B8E986", "#1F3B4D"]), // 科技蓝绿
        ("ai", ["#4A90E2", "#50E3C2", "#B8E986", "#1F3B4D"]),
        ("code", ["#4A90E2", "#50E3C2", "#B8E986", "#1F3B4D"]),
        ("art", ["#FF9A9E", "#FECFEF", "#A18CD1", "#FBC2EB"]), // 艺术粉紫
        ("design", ["#FF9A9E", "#FECFEF", "#A18CD1", "#FBC2EB"]),
        ("retro", ["#F6D365", "#FDA085", "#D4A373", "#7F4F24"]), // 复古暖色
        ("nature", ["#84FAB0", "#8FD3F4", "#2D6A4F", "#00B4D8"]), // 自然苍翠
        ("geek", ["#000000", "#333333", "#00FF41", "#008F11"]), // 极客黑绿
        ("hacker", ["#000000", "#333333", "#00FF41", "#008F11"])
    ]
    
    private static let defaultPalettes: [[String]] = [
        ["#4A90E2", "#50E3C2", "#764BA2", "#FF9A9E"],
        ["#A18CD1", "#FBC2EB", "#8FD3F4", "#84FAB0"],
        ["#F6D365", "#FDA085", "#764BA2", "#4A90E2"]
    ]
    
    /// 根据笔记本名称生成主题配置
    /// - Parameters:
    ///   - name: 笔记本名称
    ///   - id: 笔记本唯一标识
    /// - Returns: 符合语义或随机启发的主题配置
    public static func generate(from name: String, id: UUID) -> NotebookThemeConfig {
        // 1. 语义启发匹配（有序遍历保证 first-match-wins）
        var palette: [String] = []
        for (keyword, colors) in semanticPalettes where name.localizedCaseInsensitiveContains(keyword) {
                palette = colors
                break
        }
        
        // 2. 如果未匹配，使用哈希分发默认配色
        if palette.isEmpty {
            let hash = abs(name.hashValue)
            palette = defaultPalettes[hash % defaultPalettes.count]
        }
        
        let seed = abs(id.hashValue)
        
        // 默认返回 mesh 类型，打造 AI 驱动的流体感
        return NotebookThemeConfig(
            type: .mesh,
            colors: palette,
            seed: seed
        )
    }
}
