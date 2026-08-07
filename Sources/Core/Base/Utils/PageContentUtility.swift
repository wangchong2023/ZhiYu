//
//  PageContentUtility.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：提供页面内容分析、字数统计、标签提取等纯算法工具。
//

import Foundation
import UFPCore

/// 页面内容处理工具集 (PageContentUtility)
/// 贯彻 SRP 原则，将模型层中的复杂正则与统计算法剥离至此。
public enum PageContentUtility {
    
    /// 计算字数 (支持中英混排)
    /// 逻辑：中文按字符计费；英文按单词计数。
    /// 通用算法已迁移至 `UFPCore.TextAnalyzer.wordCount`，此处转发以维持调用点不变。
    public static func calculateWordCount(_ content: String) -> Int {
        TextAnalyzer.wordCount(content)
    }
    
    /// 获取所有标签（包括元数据标签和内容中的 #标签）
    public static func extractAllTags(content: String, existingTags: [String]) -> [String] {
        var allTags = Set(existingTags)
        
        // 提取内容中的 #标签 (支持中文标签)
        let pattern = "#([\\w\\u4e00-\\u9fa5]+)"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let nsText = content as NSString
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: nsText.length))
            for match in matches where match.numberOfRanges > 1 {
                    allTags.insert(nsText.substring(with: match.range(at: 1)))
            }
        }
        return Array(allTags).sorted()
    }
}
