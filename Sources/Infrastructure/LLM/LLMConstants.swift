//
//  LLMConstants.swift
//
//  系统层级：[L1] 服务层 (Infrastructure/LLM)
//  核心职责：LLM 模块业务阈值、日志截断长度、重试参数、匿名化常量等强类型常量集。
//           消除 LLM 层魔鬼数字，统一引用源，符合 AGENTS.md 红线 #4。
//

import Foundation
import UFPCore

/// LLM 模块常量集
public enum LLMConstants {
    /// 对话记忆窗口默认值
    public enum Memory {
        /// 默认保留的最近对话条数
        public static let recentCountDefault = 5
    }

    /// 日志/诊断预览截断长度
    public enum LogPreview {
        /// 记忆摘要截断长度
        public static let memorySummaryLength = 300
        /// SystemPrompt 预览截断长度
        public static let systemPromptLength = 300
        /// 用户 Query 预览截断长度
        public static let queryLength = 200
        /// SSE 诊断日志最大记录行数
        public static let maxDiagnosticLines = 15
        /// SSE 诊断单行预览截断长度
        public static let diagnosticLineLength = 250
        /// SSE 非 JSON 行预览截断长度
        public static let sseNonJsonLength = 120
        /// 重构分析页面内容预览截断长度
        public static let refactorPageContentLength = 150
        /// 端侧智能导入摘要截断长度
        public static let smartIngestSummaryLength = 100
    }

    /// 实体占位符解析阈值
    public enum EntityPlaceholder {
        /// 占位符被切断时剩余文本最大长度，超过则视为非合法占位符
        public static let maxRawLength = 25
        /// 缓冲区保留的后缀长度
        public static let bufferSuffixLength = 10
    }

    /// 上下文压缩阈值
    public enum ContextCompression {
        /// Summary 分块或高分块强制纳入的分数阈值
        public static let summaryScoreThreshold: Float = 0.8
    }

    /// 实体匿名化（PII 遮掩）字母表常量
    public enum Anonymization {
        /// ASCII 大写字母 'A' 的码点
        public static let asciiUppercaseA: UInt8 = 65
        /// 英文字母表大小
        public static let alphabetSize = 26
    }

    /// API Key 校验常量
    public enum ApiKey {
        /// 明文 API Key 合法前缀
        public static let prefix = "sk-"
        /// 明文 API Key 最小长度要求
        public static let minLength = 20
    }

    /// Rerank 候选数量
    public enum Rerank {
        /// 参与重排序的最大候选分块数
        public static let candidateCount = 10
    }

    /// 指数退避重试参数
    public enum Retry {
        /// 最大重试次数
        public static let maxAttempts = 3
        /// 初始退避延迟（秒）
        public static let initialDelaySeconds: Double = 0.5
        /// 退避乘数（每次失败后延迟倍增）
        public static let backoffMultiplier: Double = 2.0
    }

    /// 端侧智能导入参数
    public enum SmartIngest {
        /// 传入 Prompt 的现有页面标题最大数量
        public static let existingTitlesCount = 20
    }
}
