// 系统层级：[L3] 表现层
// 核心职责：RAG 评分颜色映射工具，消除 RAGBenchmarkPanel 与 RAGResultChart 的重复

import SwiftUI

/// RAG 评分颜色映射器，消除跨文件的 scoreColor 重复逻辑
enum RAGScoreColor {
    /// 正向评分颜色（分数越高越好）
    static func score(_ s: Double) -> Color {
        if s >= ScoreThreshold.excellent { return Color.theme.green }
        if s >= ScoreThreshold.fair { return Color.theme.orange }
        return Color.theme.red
    }

    /// 反向评分颜色（分数越低越好，如幻觉率）
    static func inverted(_ s: Double) -> Color {
        if s <= ScoreThreshold.invertedExcellent { return Color.theme.green }
        if s <= ScoreThreshold.invertedFair { return Color.theme.orange }
        return Color.theme.red
    }
}
