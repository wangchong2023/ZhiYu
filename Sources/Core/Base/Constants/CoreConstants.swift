//
//  CoreConstants.swift
//  ZhiYu
//
//  系统层级：[L0] 基础设施层
//  核心职责：Core 模块业务常量集（语言代码/本地化/安全/工作流/错误类型等）
//

import UFPCore

/// Core 模块业务常量集
public enum CoreConstants {

    // MARK: - 语言代码 (Language Code)
    public enum LanguageCode {
        public static let zh = "zh"
        public static let zhHans = "zh-Hans"
        public static let zhHant = "zh-Hant"
        public static let zhHK = "zh-HK"
        public static let zhTW = "zh-TW"
        public static let zhMO = "zh-MO"
        public static let en = "en"
        public static let es = "es"
        public static let fr = "fr"
        public static let ar = "ar"
        public static let ru = "ru"
        public static let ko = "ko"
        public static let ja = "ja"
        public static let pt = "pt"
    }

    // MARK: - 本地化 (Localization)
    public enum Localization {
        public static let lproj = "lproj"
        public static let commonTable = "Common"
    }

    // MARK: - 安全 (Security)
    public enum Security {
        public static let redacted = "[REDACTED]"
        public static let masked = "***"
        public static let piiMask = "[PII]"
        public static let logModule = "Security"
    }

    // MARK: - 安全日志目标 (Security Log Target)
    public enum SecurityLogTarget {
        public static let contentModerationEngine = "ContentModerationEngine"
        public static let securityManager = "SecurityManager"
        public static let promptSecurityGuard = "PromptSecurityGuard"
        public static let promptSanitizer = "PromptSanitizer"
        public static let piiMasker = "PIIMasker"
        public static let dynamicComplianceManager = "DynamicComplianceManager"
        public static let coreMLModerationClassifier = "CoreMLModerationClassifier"
    }

    // MARK: - 安全日志详情 (Security Log Details)
    public enum SecurityLogDetails {
        public static let blockedPolitical = "Blocked political content"
        public static let blockedNSFW = "Blocked NSFW content"
        public static let blockedViolence = "Blocked violence content"
        public static let blockedSensitive = "Blocked sensitive content"
        public static let criticalFailed = "Critical: Failed"
        /// 引用 CoreConstants.LogDetails.failedTo，避免重复定义
        public static let failedTo: String = CoreConstants.LogDetails.failedTo
    }

    // MARK: - ML 审核原因 (ML Moderation Reason)
    public enum ModerationReason {
        public static let emptyText = "empty_text"
        public static let deviceHwBypass = "device_hw_bypass"
        public static let detectedPromptInjection = "detected_prompt_injection"
        public static let clean = "clean"
    }

    // MARK: - PII 脱敏 (PII Masking)
    public enum PIIMasking {
        public static let redactedPII = "[REDACTED_PII]"
    }

    // MARK: - Prompt 安全 (Prompt Security)
    public enum PromptSecurity {
        public static let systemPrefix = "System: "
        public static let assistantPrefix = "Assistant: ["
        public static let bracketOpen = "\\["
        public static let bracketClose = "\\]"
    }

    // MARK: - 内容审核 (Content Moderation)
    public enum Moderation {
        public static let safe = "safe"
        public static let unsafe = "unsafe"
        public static let sensitive = "sensitive"
        public static let unknown = "unknown"
    }

    // MARK: - 工作流 (Workflow)
    public enum Workflow {
        public static let pending = "pending"
        public static let running = "running"
        public static let completed = "completed"
        public static let failed = "failed"
        public static let cancelled = "cancelled"
    }

    // MARK: - 错误类型 (Error Type)
    public enum ErrorType {
        public static let network = "network"
        public static let storage = "storage"
        public static let validation = "validation"
        public static let authorization = "authorization"
        public static let notFound = "notFound"
        public static let conflict = "conflict"
        public static let server = "server"
        public static let unknown = "unknown"
    }

    // MARK: - 日志 (Logger)
    public enum Logger {
        public static let defaultCategory = "App"
    }

    // MARK: - 性能 (Performance)
    public enum Performance {
        public static let defaultMetric = "default"
    }

    // MARK: - 快照 (Snapshot)
    public enum Snapshot {
        public static let defaultPrefix = "snapshot_"
    }

    // MARK: - 导出 (Export)
    public enum Export {
        public static let unsupported = "unsupported"
        public static let unsupportedMessage = "Export is not supported on this platform."
    }

    // MARK: - 性能压测 (Benchmark)
    public enum Benchmark {
        /// 压测页面前缀
        public static let stressTestPagePrefix = "Stress Test Page #"
        /// 压测内容前缀
        public static let stressTestContentPrefix = " "
        /// 压测内容中段
        public static let stressTestContentMiddle = "  SQLite"
        /// 压测内容后缀模板
        public static let stressTestContentSuffix = " FTS5 "
        /// 压测标签
        public static let tagBenchmark = "benchmark"
        /// 压测标签
        public static let tagStressTest = "stress-test"
        /// 搜索查询关键词
        public static let searchQuery = "Stress Test"
    }

    // MARK: - Markdown 语法 (Markdown Syntax)
    /// 通用 Markdown 语法引用 SystemConstants.MarkdownSyntax，业务层转接为语义名称
    public enum MarkdownSyntax {
        public static let taskOpen = "- [ ] "
        public static let taskDone = "- [x] "
        public static let taskDoneUpper = "- [X] "
        /// 引用 SystemConstants.MarkdownSyntax.bulletDash
        public static let dashSpace: String = SystemConstants.MarkdownSyntax.bulletDash
        /// 引用 SystemConstants.MarkdownSyntax.bulletAsterisk
        public static let asteriskSpace: String = SystemConstants.MarkdownSyntax.bulletAsterisk
        public static let boldItalic = "***"
        /// 引用 SystemConstants.MarkdownSyntax.bold
        public static let bold: String = SystemConstants.MarkdownSyntax.bold
        public static let italic = "__"
        public static let strikethrough = "~~"
    }

    // MARK: - 日志拼接符 (Log Concatenation)
    public enum LogConcat {
        /// 引用 SystemConstants.Separator.arrow
        public static let arrow: String = SystemConstants.Separator.arrow
    }

    // MARK: - 文本分隔符 (Text Separator)
    public enum TextSeparator {
        /// 引用 SystemConstants.Separator.commaSpace
        public static let commaSpace: String = SystemConstants.Separator.commaSpace
        /// 引用 SystemConstants.Separator.colon
        public static let colon: String = SystemConstants.Separator.colon
    }

    // MARK: - 错误域 (Error Domain)
    /// 使用反向 DNS 格式，遵循 Apple NSError domain 命名惯例
    public enum ErrorDomain {
        public static let insight = "com.zhiyu.app.insight"
        public static let ingestStore = "com.zhiyu.app.ingestStore"
        public static let export = "com.zhiyu.app.export"
        public static let synthesisStore = "com.zhiyu.app.synthesisStore"
        public static let securityManager = "com.zhiyu.app.securityManager"
    }

    // MARK: - 错误码 (Error Code)
    public enum ErrorCode {
        /// 引用 SystemConstants.ErrorCode.default，避免重复定义
        public static let `default`: Int = SystemConstants.ErrorCode.default
    }

    // MARK: - 日志模块名 (Log Module)
    public enum LogModule {
        public static let system = "System"
    }

    // MARK: - 日志前缀 (Log Prefix)
    public enum LogPrefix {
        public static let error = " [ERROR]"
        public static let logger = " [Logger]"
        public static let deepLinkService = " [DeepLinkService]"
    }

    // MARK: - 日志详情 (Log Details)
    public enum LogDetails {
        public static let failedTo = "Failed to"
        public static let saveLogs = "save logs:"
        public static let rateLimitExceeded = "Rate limit"
        public static let exceededDropping = "exceeded! Dropping"
        public static let request = "request:"
    }

    // MARK: - 深度链接 (Deep Link)
    public enum DeepLink {
        public static let scheme = "zhiyu"
        public static let host = "page"
        public static let createHost = "create"
        public static let searchHost = "search"
        public static let ingestHost = "ingest"
        public static let graphHost = "graph"
        public static let chatHost = "chat"
        public static let spotlightActivityType = "com.zhiyu.app.openPage"
        public static let pageIDKey = "pageID"
        public static let idQueryKey = "id"
        public static let titleQueryKey = "title"
        public static let qQueryKey = "q"
    }

    // MARK: - 性能指标标签 (Performance Metric Label)
    public enum PerformanceLabel {
        public static let save = "save"
        public static let load = "load"
        public static let lint = "lint"
        public static let graphLayout = "graphLayout"
        public static let search = "search"
        public static let ragChain = "ragChain"
        public static let ai = "ai"
        public static let llm = "llm"
    }

    // MARK: - Prompt 注入定界符 (Prompt Injection Delimiter)
    public enum PromptInjection {
        public static let imStart = "<|im_start|>"
        public static let imEnd = "<|im_end|>"
        public static let systemMarker = "### System:"
        public static let assistantMarker = "### Assistant:"
        public static let escapedPrefix = "[ESCAPED_"
        public static let escapedSuffix = "]"
        public static let fullWidthOpenBracket = "【"
        public static let fullWidthCloseBracket = "】"
        public static let fullWidthLessThan = "〈"
        public static let fullWidthGreaterThan = "〉"
        public static let fullWidthPipe = "｜"
        public static let fullWidthHash = "＃"
        public static let escapedBracketOpen = "\\["
        public static let escapedBracketClose = "\\]"
        public static let instructionFragmentSys = "SYS"
        public static let instructionFragmentTem = "TEM"
        public static let instructionFragmentUnderscore = "_"
        public static let instructionFragmentIns = "INS"
        public static let instructionFragmentTru = "TRU"
        public static let instructionFragmentCti = "CTI"
        public static let instructionFragmentOn = "ON"
    }

    // MARK: - Frontmatter 分隔符 (Frontmatter Separator)
    public enum Frontmatter {
        /// 引用 SystemConstants.MarkdownDelimiter.horizontalRule，避免重复定义
        public static let separator: String = SystemConstants.MarkdownDelimiter.horizontalRule
        /// 完整 Frontmatter 块的最小段数（起始分隔符 + 内容 + 结束分隔符）
        public static let minPartCount = 3
        /// 起始分隔符后跳过的段数
        public static let dropFirstCount = 2
    }

    // MARK: - Bundle 资源 (Bundle Resource)
    public enum BundleResource {
        public static let appConfig = "AppConfig"
    }

    // MARK: - LLM Provider (LLM Provider)
    public enum LLMProvider {
        public static let ollama = "ollama"
        public static let deepseek = "deepseek"
    }

    // MARK: - 默认模型 (Default Model)
    public enum DefaultModel {
        public static let deepseekV4Pro = "deepseek-v4-pro"
    }

    // MARK: - 远程配置 (Remote Config)
    public enum RemoteConfig {
        /// 模型白名单资源名（默认/英文）
        public static let modelAllowlist = "model_allowlist"
        /// 模型白名单资源名（简体中文）
        public static let modelAllowlistZhHans = "model_allowlist_zh-Hans"
        /// JSON 顶层 models 字段
        public static let jsonKeyModels = "models"

        /// Agent 技能 ID
        public enum SkillID {
            public static let chunkingFormatter = "chunking_formatter"
            public static let presentationGenerator = "presentation_generator"
            public static let linkDiscovery = "link_discovery"
        }

        /// Agent 技能展示名（离线灾备占位）
        public enum SkillDisplayName {
            public static let chunkingFormatter = " "
            public static let presentationGenerator = "  Quiz "
            public static let linkDiscovery = " "
        }

        /// Agent 技能描述（离线灾备占位）
        public enum SkillDescription {
            public static let presentationGenerator = " Markdown "
        }

        /// Agent 技能标签
        public enum SkillTag {
            public static let tagging = "Tagging"
            public static let offline = "Offline"
            public static let synthesis = "Synthesis"
            public static let edgeCloud = "Edge-Cloud"
            public static let graph = "Graph"
        }

        /// Agent 技能 Prompt 模板占位符
        public enum PromptTemplate {
            public static let inputPlaceholder = "{{input}}"
            public static let chunkingFormatter = "\n{{input}}\n 3-5  JSON Schema "
            public static let presentationGenerator = "\n{{input}}\n '# '  '## ' "
            public static let linkDiscovery = "\n{{input}}\n [[]] "
        }
    }
}
