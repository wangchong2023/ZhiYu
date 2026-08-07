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
    public enum APIKeySecret {
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

    // MARK: - LLM API 请求体字段名 (API Request Keys)

    /// LLM API 请求体 JSON 字段名常量集
    public enum APIKey {
        /// messages 数组的 role 字段名
        public static let role: String = "role"
        /// messages 数组的 content 字段名
        public static let content: String = "content"
        /// 顶层 model 字段名
        public static let model: String = "model"
        /// 顶层 messages 字段名
        public static let messages: String = "messages"
        /// 顶层 temperature 字段名
        public static let temperature: String = "temperature"
        /// 顶层 max_tokens 字段名
        public static let maxTokens: String = "max_tokens"
        /// 顶层 stream 字段名
        public static let stream: String = "stream"
        /// 顶层 prompt 字段名
        public static let prompt: String = "prompt"
    }

    /// messages 中 role 字段的取值常量
    public enum Role {
        /// system 角色
        public static let system: String = "system"
        /// user 角色
        public static let user: String = "user"
        /// assistant 角色
        public static let assistant: String = "assistant"
    }

    // MARK: - 模型 ID 前缀 (Model ID Prefixes)

    /// 模型 ID 前缀常量集（用于区分模型来源）
    public enum ModelIDPrefix {
        /// 已下载模型 ID 前缀
        public static let downloaded: String = "downloaded_"
        /// 内置模型 ID 前缀
        public static let bundled: String = "bundled_"
    }

    // MARK: - Prompt 沙箱标签 (Prompt Security Tags)

    /// Prompt 沙箱转义标签常量集
    public enum PromptTag {
        /// 上下文开标签
        public static let contextOpen: String = "<context>"
        /// 上下文闭标签
        public static let contextClose: String = "</context>"
        /// 用户查询开标签
        public static let userQueryOpen: String = "<user_query>"
        /// 用户查询闭标签
        public static let userQueryClose: String = "</user_query>"
        /// 转义后的上下文开标签
        public static let contextOpenEscaped: String = "[context]"
        /// 转义后的上下文闭标签
        public static let contextCloseEscaped: String = "[/context]"
        /// 转义后的用户查询开标签
        public static let userQueryOpenEscaped: String = "[user_query]"
        /// 转义后的用户查询闭标签
        public static let userQueryCloseEscaped: String = "[/user_query]"
    }

    // MARK: - 端侧模型名 (On-Device Model Names)

    /// 端侧模型显示名常量集
    public enum OnDeviceModel {
        /// 内置模型显示名
        public static let bundledName: String = "Bundled_Model"
        /// Apple Intelligence 模型显示名
        public static let appleIntelligenceName: String = "Apple_Intelligence"
    }

    // MARK: - SSE 流式响应标记 (SSE Stream Markers)

    /// SSE 流式响应标记常量集
    public enum SSEStream {
        /// 流结束标记
        public static let doneMarker: String = "[DONE]"
        /// data 行前缀
        public static let dataPrefix: String = "data: "
    }

    // MARK: - 任务中心任务名 (Task Center Names)

    /// 任务中心任务名常量集
    public enum TaskName {
        /// AI 对话任务名
        public static let aiChat: String = "AI Chat"
        /// AI 流式对话任务名
        public static let aiChatStream: String = "AI Chat Stream"
    }

    // MARK: - 健康检查 (Health Check)

    /// LLM 健康检查常量集
    public enum HealthCheck {
        /// 健康检查 Prompt 内容
        public static let prompt: String = "Hi"
        /// 健康检查 SystemPrompt 内容
        public static let systemPrompt: String = "Reply 'OK' only."
    }

    // MARK: - CoreML 特征名 (ML Feature Names)

    /// CoreML 模型特征名常量集
    public enum MLFeature {
        /// 生成文本输出特征名
        public static let generatedText: String = "generated_text"
    }

    // MARK: - Bundle 资源名 (Bundle Resources)

    /// LLM 模块 Bundle 资源名常量集
    public enum BundleResource {
        /// LLM Providers 配置文件名
        public static let llmProviders: String = "LLMProviders"
        /// 端侧 CoreML 模型资源名
        public static let appLLM: String = "AppLLM"
    }

    // MARK: - UI 自动化测试 Mock 参数 (UITesting Mock Parameters)

    /// UI 自动化测试模式下 Mock 响应参数常量集
    /// 集中管理 `--uitesting` 自愈分支的延迟、Mock 文本与流式 chunks
    public enum UITesting {
        /// 纳秒与秒的换算系数
        public static let nanosecondsPerSecond: Double = 1_000_000_000
        /// 非流式 Mock 响应初始延迟（秒）
        public static let mockNonStreamDelaySeconds: Double = 0.5
        /// 流式 Mock 响应初始延迟（秒），模拟 RAG 检索/思考状态
        public static let mockStreamInitialDelaySeconds: Double = 1.5
        /// 流式 Mock 字间吐字延迟（秒）
        public static let mockStreamChunkDelaySeconds: Double = 0.15

        /// 非流式 Mock 大模型回复内容（纯 ASCII，避免 L10n 红线）
        public static let mockNonStreamReply: String = "Mock non-stream LLM reply for UI testing."
        /// Mock RAG 回复内容（纯 ASCII，避免 L10n 红线）
        public static let mockRAGReply: String = "Mock non-stream RAG reply for UI testing."

        /// 流式 Mock 打字机 chunks 数组（纯 ASCII，避免 L10n 红线）
        public static let mockStreamChunks: [String] = [
            "Mock", " stream", " LLM", " reply", " for", " UI", " testing.",
            " Supports", " RAG", " deep", " citation", " retrieval", " auto-heal."
        ]
    }

    // MARK: - 端侧模型 ID 字面量 (On-Device Model ID Literals)

    /// 端侧模型 ID 字面量常量集（补充 ModelIDPrefix 未覆盖的完整 ID）
    public enum OnDeviceModelID {
        /// 内置 ZhiYu 模型 ID
        public static let bundledZhiyu: String = "bundled_zhiyu"
        /// Apple Intelligence 模型 ID
        public static let appleIntelligence: String = "apple_intelligence"
    }

    // MARK: - 端侧模型持久化 Key (On-Device Storage Key)

    /// 端侧模型偏好持久化 UserDefaults Key
    public enum OnDeviceStorage {
        /// 本地选型偏好持久化 Key
        public static let configKey: String = "zhiyu_ondevice_config"
    }

    // MARK: - 端侧模型 SF Symbol 图标名 (On-Device Icon Names)

    /// 端侧模型 SF Symbol 图标名常量集
    public enum OnDeviceIcon {
        /// 内置模型图标
        public static let bundled: String = "cube.box.fill"
        /// 已下载模型图标
        public static let downloaded: String = "arrow.down.circle.fill"
        /// 系统模型图标
        public static let system: String = "apple.logo"
    }

    // MARK: - Prompt 指令模板 (Prompt Instruction Templates)

    /// Prompt 指令模板常量集
    public enum PromptInstruction {
        /// 回复篇幅控制指令模板（注入 systemPrompt 末尾）
        /// - Parameter maxChars: 最大字符数
        public static func lengthHint(_ maxChars: Int) -> String {
            "\nKeep response within \(maxChars) characters."
        }
        /// 端侧 LLM chat prompt 中的 Question 标签
        public static let questionLabel: String = "Question"
    }
}
