//
//  TextAnalyzer.swift
//  UFPCore
//
//  Created by CodeFree on 2026/08/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：通用文本分析工具，与业务无关。
//

import Foundation

/// 通用文本分析工具集
/// 提供与业务无关的文本统计算法，供业务层调用。
public enum TextAnalyzer {

    /// 计算字数（支持中英混排）
    /// - Parameter content: 待统计的文本
    /// - Returns: 字数；中文按字符计数，英文按单词计数
    public static func wordCount(_ content: String) -> Int {
        var count = 0
        var inEnglishWord = false

        for char in content {
            if char.isCJKCharacter {
                if inEnglishWord {
                    count += 1
                    inEnglishWord = false
                }
                count += 1
            } else if char.isLetter || char.isNumber {
                inEnglishWord = true
            } else if inEnglishWord {
                count += 1
                inEnglishWord = false
            }
        }
        if inEnglishWord { count += 1 }
        return count
    }
}
