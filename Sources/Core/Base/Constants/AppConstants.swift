//
//  AppConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：应用级编译时常量定义（存储 key、超时、默认值等）。
//
import Foundation
import UFPCore

/// [L0] 底层基座层：硬编码常量配置 (AppConstants)
public struct AppConstants {
    
    // MARK: - Network
    public struct Network {
        // MARK: - Token 与超时
        /// Keychain 中存储 JWT access token 的 key
        public static let jwtTokenKey = "jwt_token_key"
        /// Keychain 中存储 refresh token 的 key
        public static let refreshTokenKey = "refresh_token"

        // MARK: - 头像上传
        /// 默认头像文件名
        public static let avatarFileName: String = "avatar.png"
        /// 默认头像 MIME 类型
        public static let avatarMimeType: String = "image/png"
        /// OAuth 回调 URL Scheme
        public static let oauthCallbackScheme: String = "zhiyu"
        /// 单次请求超时时长（秒）
        public static let requestTimeout: TimeInterval = 30.0
        /// 资源请求超时时长（秒）
        public static let resourceTimeout: TimeInterval = 30.0

        // MARK: - Header 键名（引用 SystemConstants.HTTPHeader）
        /// Content-Type 请求头字段名
        public static let headerContentType: String = SystemConstants.HTTPHeader.contentType
        /// Authorization 请求头字段名
        public static let headerAuthorization: String = SystemConstants.HTTPHeader.authorization

        // MARK: - Content-Type 值（引用 SystemConstants.ContentType / MIMEType）
        /// JSON 请求体 MIME 类型
        public static let contentTypeJSON: String = SystemConstants.ContentType.applicationJSON
        /// multipart/form-data 前缀（boundary 拼接后缀）
        public static let contentTypeMultipartPrefix: String = SystemConstants.ContentType.multipartFormDataPrefix
        /// 图片 PNG MIME 类型
        public static let mimeTypePNG: String = SystemConstants.MIMEType.png
        /// 图片 JPEG MIME 类型
        public static let mimeTypeJPEG: String = SystemConstants.MIMEType.jpeg

        // MARK: - HTTP 方法（引用 SystemConstants.HTTPMethod）
        public static let methodGET: String = SystemConstants.HTTPMethod.get
        public static let methodPOST: String = SystemConstants.HTTPMethod.post
        public static let methodPUT: String = SystemConstants.HTTPMethod.put
        public static let methodDELETE: String = SystemConstants.HTTPMethod.delete
        public static let methodPATCH: String = SystemConstants.HTTPMethod.patch

        // MARK: - Multipart 构造字符（引用 SystemConstants.Multipart）
        /// multipart boundary 分隔符前缀
        public static let multipartBoundaryPrefix: String = SystemConstants.Multipart.boundaryPrefix
        /// multipart body 字段名（文件表单 field name）
        public static let multipartFieldName: String = SystemConstants.Multipart.defaultFieldName
        /// HTTP 换行符
        public static let crlf: String = SystemConstants.Multipart.crlf

        // MARK: - Bearer Token 格式（引用 SystemConstants.HTTPAuthentication）
        /// Authorization header 中 Bearer 前缀
        public static let bearerPrefix: String = SystemConstants.HTTPAuthentication.bearerPrefix

        // MARK: - 后端业务错误码 (API Business Code)
        /// 后端返回的业务错误码常量集
        public enum BusinessCode {
            /// Token 过期，需刷新后重试
            public static let tokenExpired: Int = 40101
        }
    }
    
    // MARK: - 存储与基础配置
    public struct Storage {
        /// 数据库文件名 (向下兼容)
        public static let databaseName: String = "App.sqlite"
        /// 系统全局配置数据库文件名
        public static let globalDatabaseName: String = "global.sqlite3"
        /// 笔记本专属物理数据库文件名
        public static let vaultDatabaseName: String = "vault.sqlite3"
        /// 笔记本沙盒存储子目录名称
        public static let vaultsDirectoryName: String = "Vaults"
        /// App Group 标识符（用于 Widget / Watch 共享数据）
        public static let appGroupIdentifier: String = "group.com.zhiyu.app"
        /// Widget 统计快照文件名
        public static let widgetStatsFileName: String = "widget_stats.json"
        /// 间隔重复算法(SRS)默认易用度因子 (SuperMemo-2 经典默认值)
        public static let defaultEaseFactor: Double = 2.5
        /// 日志文件名
        public static let logsFileName: String = "audit_logs.json"
        /// 默认调用状态
        public static let defaultCallStatus: String = "success"
        
        // MARK: - 表名定义
        /// 存储系统内所有数据表的物理名称。
        public struct Tables {
            public static let pages = "pages"
            public static let pagesFTS = "pages_fts"
            public static let links = "links"
            public static let pageChunks = "page_chunks"
            public static let pageEmbeddings = "page_embeddings"
            public static let tokenUsage = "token_usage"
            public static let llmCallLogs = "llm_call_logs"
            public static let ragEvaluations = "rag_evaluations"
            public static let retrievalSnapshots = "retrieval_snapshots"
            public static let relevanceJudgments = "relevance_judgments"
            public static let globalVaults = "global_vaults"
            public static let fileSignatures = "file_signatures"
            public static let globalSettings = "global_settings"
            public static let auditLogs = "audit_logs"
            public static let tags = "tags"
            public static let pageTags = "page_tags"
            public static let srsMetadata = "srs_metadata"
            public static let importRecords = "import_records"
            public static let feedbackEntries = "feedback_entries"
            public static let pluginRecords = "plugin_records"
            public static let pluginRecordsFTS = "plugin_records_fts"
        }

        // MARK: - 通用列名 (物理)
        /// 定义数据库中高频使用的物理列名称，解除对模型的依赖。
        public struct Columns {
            // 通用
            public static let id = "id"
            public static let title = "title"
            public static let name = "name"
            public static let content = "content"
            public static let created = "created_at"
            public static let updated = "updated_at"
            public static let tags = "tags"
            
            // pages 表
            public static let pageType = "page_type"
            public static let aliases = "aliases"
            public static let status = "status"
            public static let confidence = "confidence"
            public static let sources = "sources"
            public static let relatedPageIds = "related_page_ids"
            public static let isPinned = "is_pinned"
            public static let contentHash = "content_hash"
            public static let customIcon = "custom_icon"
            public static let sourceUrl = "source_url"
            public static let rawSnippet = "raw_snippet"
            public static let fileSize = "file_size"
            public static let sourceType = "source_type"
            public static let lamportTimestamp = "lamport_timestamp"

            // links 表
            public static let sourceId = "source_id"
            public static let targetId = "target_id"
            public static let context = "context"

            // page_chunks 表
            public static let pageId = "page_id"
            public static let parentId = "parent_id"
            public static let chunkType = "chunk_type"
            public static let anchorPath = "anchor_path"
            public static let chunkIndex = "chunk_index"
            public static let embedding = "embedding"
            public static let startIndex = "start_index"

            // page_embeddings 表
            public static let vectorBlob = "vector_blob"
            public static let modelName = "model_name"

            // token_usage & llm_call_logs 表
            public static let model = "model"
            public static let promptTokens = "prompt_tokens"
            public static let completionTokens = "completion_tokens"
            public static let totalTokens = "total_tokens"
            public static let latencyMs = "latency_ms"

            // rag_evaluations 表
            public static let query = "query"
            public static let answer = "answer"
            public static let faithfulness = "faithfulness_score"
            public static let relevance = "relevance_score"
            public static let precision = "context_precision"
            public static let evaluatorModel = "evaluator_model"
            
            // page_tags 表
            public static let tagId = "tag_id"
            
            // srs_metadata 表
            public static let easeFactor = "ease_factor"
            public static let repetitions = "repetitions"
            public static let reviewInterval = "review_interval"
            public static let nextReviewAt = "next_review_at"
            
            // global_vaults 表
            public static let path = "path"
            public static let icon = "icon"
            public static let lastAccessedAt = "last_accessed_at"
            
            // file_signatures 表
            public static let filePath = "file_path"
            public static let signature = "signature"
            public static let salt = "salt"
            
            // global_settings 表
            public static let key = "key"
            public static let value = "value"
            
            // audit_logs 表
            public static let action = "action"
            public static let details = "details"
        }
    }

    // MARK: - 性能与监控
    public struct Performance {
        /// 延迟警告阈值 (毫秒)
        public static let latencyWarningThreshold: Int = 2000

        // MARK: - 压力测试 (Stress Test)
        /// 压力测试默认写入条数
        public static let stressTestDefaultCount: Int = 50000
        /// 压力测试进度日志步长
        public static let stressTestProgressStep: Int = 5000
        /// 压力测试单次操作慢阈值（秒）
        public static let stressTestSlowOperationThreshold: TimeInterval = 0.8
    }

    // MARK: - 全局存储键名 (Magic Strings)
    public struct Keys {
        public struct Storage {
            public static let languageMode = "app_language_mode"
            public static let userHasOnboarded = "app_user_has_onboarded"
            public static let lastUsedModel = "app_last_used_model"
            public static let themePreference = "app_theme_preference"
            public static let hasSeenSplash = "app_has_seen_splash"
            public static let colorSchemeMode = "app_color_scheme_mode"
            public static let accentColor = "app_accent_color"
            public static let userName = "app_username"
            public static let isPrivacyModeEnabled = "app_is_privacy_mode_enabled"
            public static let isBiometricEnabled = "app_is_biometric_enabled"
            public static let hasShownGraphCoachMark = "app_has_shown_graph_coach_mark"
            public static let iCloudConflictResolution = "app_icloud_conflict_resolution"
            public static let iCloudAutoSync = "app_icloud_auto_sync"
            public static let hasCompletedOnboarding = "app_has_completed_onboarding"
            public static let selectedTab = "app_selected_tab"
            
            // ── 认证与会话 ──
            public static let authIsAuthenticated = "auth.isAuthenticated"
            public static let authIsGuest = "auth.isGuest"
            
            // ── 笔记本与知识库 ──
            public static let vaultsList = "vaults.list"
            public static let vaultsSelectedID = "vaults.selectedID"
            public static let lastLintIssues = "lastLintIssues"
            public static let earnedMedals = "earned_medals"
            public static let dailyRecapPrefix = "daily_recap_"
            public static let weeklyInsightPrefix = "weekly_insight_cache_"
            
            // ── 协作与同步 ──
            public static let vaultBookmarkPrefix = "vault_bookmark_"
            public static let signaturePrefix = "zhiyu.integrity.sig."
            public static let securitySalt = "zhiyu_security_salt"
            public static let dbPassphrase = "zhiyu_db_passphrase"
            public static let defaultLegacySalt = "App-Integrity-Salt-2026"
            public static let suspendedPlugins = "zhiyu.security.suspendedPlugins"
            
            // ── 语音与录音 ──
            public static let voiceRecordings = "voice_recordings_list"
            
            // ── watchOS / Widget 同步缓存 ──
            public static let watchTotalPages = "watch_totalPages"
            public static let watchTotalWords = "watch_totalWords"
            public static let watchRecentTitles = "watch_recentTitles"
            public static let watchPendingAudioTransfers = "watch_pending_audio_transfers"
            public static let iOSAudioAssemblyPrefix = "ios_audio_assembly_"
            
            // ── 模型管理 ──
            public static let activeModelId = "ZhiYu.ActiveModelId"
            public static let isCloudEscalationEnabled = "ZhiYu.IsCloudEscalationEnabled"
            public static let activeCloudModelId = "ZhiYu.ActiveCloudModelId"
            
            // ── 笔记本选择 ──
            public static let vaultSelectedEnglishName = "vaultSelectedEnglishName"
            public static let seededVaultPrefix = "seeded_vault_"
            
            // ── 提示词资产 ──
            public static let promptMindmap = "prompt_mindmap"
            public static let promptQuiz = "prompt_quiz"
            public static let promptSlides = "prompt_slides"
            public static let promptReport = "prompt_report"
            public static let promptExpansion = "prompt_expansion"
            
            // ── 旧版本迁移键名 (用于数据迁移校验) ──
            public struct Legacy {
                public static let hasCompletedOnboarding = "hasCompletedOnboarding"
                public static let isPrivacyModeEnabled = "isPrivacyModeEnabled"
                public static let isBiometricEnabled = "isBiometricEnabled"
                public static let hasShownGraphCoachMark = "hasShownGraphCoachMark"
                public static let colorSchemeMode = "colorSchemeMode"
                public static let accentColor = "accentColor"
                public static let isDarkMode = "isDarkMode"
                public static let synthesisDocsPrefix = "synthesis_docs_"
            }
        }

        // MARK: - 导入限制

        public enum ImportLimits {
            /// Lite 版单文件最大大小：10 MB（引用 SystemConstants.bytesPerMB）
            public static let liteMaxFileSizeBytes: Int64 = 10 * Int64(SystemConstants.bytesPerMB)
            /// Pro 版单文件最大大小：50 MB（引用 SystemConstants.bytesPerMB）
            public static let maxFileSizeBytes: Int64 = 50 * Int64(SystemConstants.bytesPerMB)
            /// 语音录制最大时长：15 分钟
            public static let maxVoiceDurationSeconds: TimeInterval = 15 * 60
            /// OCR 图片最大大小：5 MB（引用 SystemConstants.bytesPerMB）
            public static let maxOCRImageSizeBytes: Int64 = 5 * Int64(SystemConstants.bytesPerMB)
            /// AI 标签分析截取字符数
            public static let aiTagSnippetLength: Int = 3000
            /// 导入冷却间隔（秒）
            public static let importCooldownSeconds: TimeInterval = 1.0
            /// Sheet 关闭后延迟执行操作的等待时间（纳秒）
            public static let dismissDelayNS: UInt64 = 400_000_000
            /// 批量导入 URL 最大数量
            public static let maxURLCount: Int = 10
            /// 图片提取：单张最大大小（5 MB，引用 SystemConstants.bytesPerMB）
            public static let maxImageSizeBytes: Int64 = 5 * Int64(SystemConstants.bytesPerMB)
            /// 图片提取：每页最多数量
            public static let maxImagesPerPage: Int = 10
            /// 图片提取：下载超时（秒）
            public static let imageDownloadTimeoutSeconds: TimeInterval = 10
            /// PDF 页面渲染缩放比例
            public static let pdfRenderScale: CGFloat = 0.5
            /// 图片 JPEG 压缩质量
            public static let imageJPEGQuality: CGFloat = 0.8
            /// 支持图片提取的 Office 文件扩展名（引用 SystemConstants.FileExtension）
            public static let officeExtensions: Set<String> = [
                SystemConstants.FileExtension.docx,
                SystemConstants.FileExtension.xlsx,
                SystemConstants.FileExtension.pptx
            ]
            /// 支持的图片格式扩展名（引用 SystemConstants.FileExtension）
            public static let imageExtensions: Set<String> = [
                SystemConstants.FileExtension.png,
                SystemConstants.FileExtension.jpg,
                SystemConstants.FileExtension.jpeg,
                SystemConstants.FileExtension.gif
            ]
            /// 支持图片提取的 PDF 扩展名（引用 SystemConstants.FileExtension）
            public static let pdfExtension: String = SystemConstants.FileExtension.pdf
            /// Office ZIP 中排除的图片路径关键词（页眉页脚背景通常为装饰性图像）
            public static let officeImageExcludeKeywords: Set<String> = ["header", "footer", "background"]
            /// 去重查询时拉取的最近导入记录数量
            public static let dedupFetchLimit: Int = 1000
            /// 统计查询时拉取的导入记录数量
            public static let statsFetchLimit: Int = 2000
            /// 剪贴板导入时标题截取长度
            public static let clipboardTitleLength: Int = 20
            /// 手工录入二次编辑时跳过的引用头行数（首行 `>` + 空行）
            public static let manualFormHeaderSkipLines: Int = 2
            /// UUID 字符串截取前缀长度（用于日志/默认名称简写）
            public static let uuidPrefixLength: Int = 8
        }

        /// 系统统计相关常量
        public enum Stats {
            /// AI 日报统计的天数范围
            public static let dailyStatsDays: Int = 30
            /// 日报日期格式化模板
            public static let dailyDateFormat: String = "yyyy-MM-dd"
        }
    }
}

// MARK: - App Store 订阅产品 ID 常量

extension AppConstants {
    /// 导出与合成限制
    public struct ExportLimits {
        /// 有效文本生成最小字节数 (10 字节)
        public static let minValidSynthesisTextBytes: Int = 10
        /// 有效 PDF/PPTX 产物导出最小字节数 (100 字节)
        public static let minValidPDFBytes: Int64 = 100
        /// 离屏 Web 渲染降级等待超时 (800 毫秒)
        public static let webRenderFallbackTimeoutMS: UInt64 = 800
    }

    /// App Store 订阅相关常量
    public struct Subscription {
        /// 月付 Pro 套餐商品 ID（对应 App Store Connect 配置）
        public static let monthlyProductId = "com.zhiyu.pro.monthly"
        /// 年付 Pro 套餐商品 ID（对应 App Store Connect 配置）
        public static let yearlyProductId  = "com.zhiyu.pro.yearly"
        /// 所有内购商品 ID 集合（用于批量拉取）
        public static let allProductIds: Set<String> = [monthlyProductId, yearlyProductId]
    }
}

// MARK: - 应用版本号（防抵赖：版本号落代码，与 git tag 保持同步）

extension AppConstants {
    /// 应用版本号常量定义（构建时由 inject_version.sh 自动注入）
    public struct Version {
        /// 语义化版本号（SemVer），发布时需与 git tag 同步更新
        /// 引用 SystemConstants.Version.defaultSemVer 作为默认值
        public static let semVer: String = SystemConstants.Version.defaultSemVer
        /// Git 短提交哈希（构建时自动注入）
        public static let gitShortHash = "6ad301d4"
        /// 构建时间戳 ISO 8601（构建时自动注入）
        public static let buildTimestamp = "2026-08-01T03:02:45Z"
    }
}

/// 支持的 AI 模型枚举 (技术层标识)
public enum AppModel: String, CaseIterable, Sendable {
    case gpt4o = "gpt-4o"
    case appleNLv1 = "apple_nl_v1"
    case evaluator = "evaluator"
}

/// 评估指标枚举 (技术层标识)
public enum EvaluationMetric: String, CaseIterable, Sendable {
    case faithfulness = "faithfulness"
    case relevance = "relevance"
    case precision = "context_precision"
    /// 幻觉率：AI 生成内容中缺乏上下文支撑的比例（越低越好）
    case hallucinationRate = "hallucination_rate"
    /// 引用准确度：引用是否真实指向原文对应位置（越高越好）
    case citationAccuracy = "citation_accuracy"
}
