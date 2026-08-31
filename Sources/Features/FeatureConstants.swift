//
//  FeatureConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/26.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：Features 模块强类型常量集（Mock 数据颜色名、业务语义字符串等）。
//

import Foundation
import UFPCore

/// Features 模块业务常量集
enum FeatureConstants {

    // MARK: - Mock 数据颜色名 (Mock Color Names)
    /// ModelLab Mock 数据中 colorName 字段的强类型常量
    enum MockColorName {
        static let cyan: String = "cyan"
        static let purple: String = "purple"
        static let blue: String = "blue"
        static let green: String = "green"
        static let red: String = "red"
        static let orange: String = "orange"
        static let yellow: String = "yellow"
        static let pink: String = "pink"
        static let teal: String = "teal"
        static let gray: String = "gray"
    }

    // MARK: - 模型任务名 (Task Name)
    /// 大模型支持的任务类型字符串键，用于 switch case 匹配
    enum TaskName {
        static let chat: String = "chat"
        static let completion: String = "completion"
        static let reasoning: String = "reasoning"
        static let code: String = "code"
        static let rag: String = "rag"
        static let translation: String = "translation"
    }

    // MARK: - 插件权限名 (Permission Name)
    /// 插件权限标识字符串键，用于 switch case 匹配
    enum PermissionName {
        static let readContent: String = "readContent"
        static let writeContent: String = "writeContent"
        static let network: String = "network"
        static let aiAccess: String = "aiAccess"
        static let log: String = "log"
    }

    // MARK: - 语言代码 (Language Code)
    /// 语音识别语言代码映射键
    enum LanguageCode {
        static let en: String = "en"
        static let ja: String = "ja"
        static let ko: String = "ko"
        static let fr: String = "fr"
        static let de: String = "de"
        static let es: String = "es"
        static let zhHant: String = "zh-Hant"
        static let enUS: String = "en-US"
        static let jaJP: String = "ja-JP"
        static let koKR: String = "ko-KR"
        static let frFR: String = "fr-FR"
        static let deDE: String = "de-DE"
        static let esES: String = "es-ES"
        static let zhTW: String = "zh-TW"
    }

    // MARK: - OAuth 提供商 (OAuth Provider)
    /// 第三方登录提供商标识字符串键
    enum OAuthProvider {
        static let apple: String = "apple"
        static let wechat: String = "wechat"
        static let google: String = "google"
        static let github: String = "github"
        static let carrier: String = "carrier"
    }

    // MARK: - OAuth 提供商 ID (OAuth Provider ID)
    /// 第三方登录按钮标识
    enum OAuthProviderId {
        static let apple: String = "auth.thirdparty.apple"
        static let google: String = "auth.thirdparty.google"
        static let github: String = "auth.thirdparty.github"
    }

    // MARK: - Lint 动作 (Lint Action)
    /// 知识 lint 修复动作字符串键
    enum LintAction {
        static let merge: String = "merge"
        static let split: String = "split"
        static let rename: String = "rename"
    }

    // MARK: - Graph 洞察类型 (Graph Insight Type)
    /// 图谱洞察类型字符串键，用于 switch case 匹配
    enum GraphInsightType {
        static let surprising: String = "surprising"
        static let orphans: String = "orphans"
        static let sparse: String = "sparse"
        static let bridges: String = "bridges"
    }

    // MARK: - 导入状态 (Import Status)
    /// 导入记录状态字符串键
    enum ImportStatus {
        static let done: String = "done"
    }

    // MARK: - 插件设置类型 (Plugin Setting Type)
    /// 插件设置项类型字符串键
    enum PluginSettingType {
        static let toggle: String = "toggle"
        static let text: String = "text"
        static let info: String = "info"
    }

    // MARK: - 来源类型 (Source Type)
    /// 知识来源类型字符串常量，消除 type == "voice" 等魔鬼字符串
    enum SourceType {
        static let voice = "voice"
        static let ocr = "ocr"
        static let audio = "audio"
        static let file = "file"
        static let link = "link"
        static let concept = "concept"
        static let entity = "entity"
        static let source = "source"
        static let map = "map"
        static let notebook = "notebook"
        static let pen = "pen"
        static let manual = "manual"

        /// Widget 默认来源分布比例（source 40% / concept 30% / entity 20% / map 10%）
        static let defaultWidgetDistribution: [String: Double] = [
            source: 0.4, concept: 0.3, entity: 0.2, map: 0.1
        ]
    }

    // MARK: - 场景节点名 (Scene Node Name)
    /// SceneKit 3D 场景节点名常量
    enum SceneNode {
        static let mainCamera = "mainCamera"
    }

    // MARK: - 模块名 (Module Name)
    /// 日志 module 字段与错误 domain 使用的类名常量
    enum ModuleName {
        static let tagStore = "TagStore"
        static let googleAuthStrategy = "GoogleAuthStrategy"
        static let weChatAuthStrategy = "WeChatAuthStrategy"
        static let carrierAuthStrategy = "CarrierAuthStrategy"
        static let aiWorkflowStore = "AIWorkflowStore"
        static let ingestService = "IngestService"
        static let dashboard = "Dashboard"
    }

    // MARK: - Mock 数据 (Mock Data)
    /// Mock/Preview 测试数据中的字符串常量
    enum MockData {
        static let multipleTags = "Multiple Tags"
        static let notDownloaded = "Not Downloaded"
        static let mockGoogleCode = "mock_google_code"
        static let mockSub123 = "mock_sub_123"
        static let mockJwtAccess = "mock_jwt_access_token"
        static let mockJwtRefresh = "mock_jwt_refresh_token"
        static let mockAutologinUser = "Mock Autologin User"
        static let mockAutologinEmail = "mock_autologin@example.com"
        static let mockAutologinPhone = "13800000000"
        static let mockAppleCode = "mock_apple_authorization_code"
        static let weChatMockUser = "WeChat Mock User"
        static let gitHubMockUser = "GitHub Mock User"
        static let googleMockUser = "Google Mock User"
        static let bearer = "Bearer"
        static let workspaceBenchFileName: String = "workspace_bench.jpg"
        static let litePlanName: String = "Lite"
        static let github = "github"
        static let carrier = "carrier"
        static let wifi = "WiFi"
        static let latency23ms = "23ms"
    }

    // MARK: - OAuth 授权类型 (OAuth Grant Type)
    /// OAuth 登录授权类型字面量
    enum GrantType {
        static let pwd = "password"
        static let sms = "sms_code"
    }

    // MARK: - 文件扩展名补充 (File Extension Supplement)
    /// Features 层使用的文件扩展名（UFPCore 未覆盖的）
    enum FileExtension {
        static let rtf = "rtf"
        static let pdf = "pdf"
        static let md = "md"
        static let markdown = "markdown"
        static let doc = "doc"
        static let docx = "docx"
        static let xls = "xls"
        static let xlsx = "xlsx"
        static let csv = "csv"
        static let ppt = "ppt"
        static let pptx = "pptx"
        static let txt = "txt"
        static let json = "json"
        static let swift = "swift"
        static let py = "py"
        static let png = "png"
        static let jpg = "jpg"
        static let jpeg = "jpeg"
        static let heic = "heic"
        static let webp = "webp"
        static let mp3 = "mp3"
        static let m4a = "m4a"
        static let wav = "wav"
        static let zip = "zip"
        static let tar = "tar"
        static let gz = "gz"
    }

    // MARK: - 文件类型名 (File Type Name)
    /// 文件类型识别关键词
    enum FileTypeName {
        static let word = "word"
        static let excel = "excel"
        static let pdf = "PDF"
        static let markdown = "Markdown"
        static let ppt = "PPT"
        static let txt = "TXT"
    }

    // MARK: - 分类筛选 (Category Filter)
    /// 导入记录分类筛选标签
    enum CategoryFilter {
        static let all = "all"
    }

    // MARK: - 单位名 (Unit Name)
    /// 性能指标单位字符串
    enum UnitName {
        static let millisecond = "ms"
        static let tokPerSec = "Tok/s"
        static let megabyte = "MB"
    }

    // MARK: - 分析事件 Key (Analytics Key)
    /// LocalAnalyticsService 事件名与属性 key
    enum AnalyticsKey {
        static let documentIngested = "document_ingested"
        static let format = "format"
    }

    // MARK: - 功能 Key (Feature Key)
    /// 用户 features 列表中的功能标识
    enum FeatureKey {
        static let privacySecurity = "privacy_security"
    }

    // MARK: - URL Scheme 名 (URL Scheme Name)
    /// 协议链接 scheme 与 host 标识
    enum URLSchemeName {
        static let privacy = "privacy"
        static let terms = "terms"
    }

    // MARK: - UI 装饰符号 (UI Decorator)
    /// UI 装饰性符号常量
    enum Decorator {
        static let middleDot: String = "·"
        static let hash: String = "#"
        static let percent: String = "%"
        static let dash: String = "--"
    }

    // MARK: - 输入占位符 (Input Placeholder)
    /// 输入框占位符示例
    enum Placeholder {
        static let apiBaseURL: String = "https://api.example.com/v1"
        static let modelName: String = "model-name"
    }

    // MARK: - 协作 Key (Collaboration Key)
    /// 协作消息字典 key
    enum CollaborationKey {
        static let type = "type"
        static let pageSync = "pageSync"
    }

    // MARK: - 任务标签 (Task Tag)
    /// 端云路由决策的任务标签
    enum TaskTag {
        static let chunking = "Chunking"
        static let linkDiscovery = "LinkDiscovery"
        static let synthesis = "Synthesis"
    }

    // MARK: - 模型参数 (Model Parameter)
    /// 模型参数量标识
    enum ModelParameter {
        static let e4B = "4B"
    }

    // MARK: - 资产名 (Asset Name)
    /// Asset Catalog 资产名
    enum AssetName {
        static let githubLogo = "GithubLogo"
    }

    // MARK: - 区域标识 (Locale Identifier)
    /// 区域与语言标识符
    enum LocaleIdentifier {
        static let cn = "CN"
        static let zhHans = "zh-Hans"
        static let zhHansCN = "_CN"
    }

    // MARK: - OAuth 字段名 (OAuth Field Name)
    /// OAuth 凭证 extraInfo 字典 key
    enum OAuthField {
        static let nickname = "nickname"
        static let state = "state"
        static let code = "code"
        static let idToken = "idToken"
    }

    // MARK: - Google 配置 (Google Config)
    /// Google SDK 配置键与占位符
    enum GoogleConfig {
        static let clientIDKey = "GIDClientID"
        static let placeholderClientID = "YOUR_GOOGLE_CLIENT_ID"
    }

    // MARK: - 正则转义字符串 (Regex Escape)
    /// replacingOccurrences 中使用的正则转义模式字面量
    enum RegexEscape {
        static let escapedBacktick = "\\`"
        static let escapedAsterisk = "\\*"
        static let escapedUnderscore = "\\_"
        static let escapedWikiLinkOpen = "\\[\\["
        static let escapedWikiLinkClose = "\\]\\]"
        static let whitespaceOrDash = "\\s+|-"
        static let underscorePlus = "_+"
    }

    // MARK: - 正则模板 (Regex Template)
    /// NSRegularExpression 替换模板
    enum RegexTemplate {
        static let captureGroup1 = "$1"
    }

    // MARK: - 日志详情文本 (Log Details)
    /// Logger.addLog details 字段使用的文本片段
    enum LogDetails {
        static let renamedTag = "Renamed tag"
        static let tagRemovedFromAllPages = "Tag removed from all pages"
        static let newTagRegistered = "New tag registered"
        static let llmServiceDisabled = "LLM service disabled"
        static let aiWorkflowDataCleared = "AI Workflow data cleared."
        static let toSpace = " to "
        static let ingestQueuePrefix = " [IngestQueue]"
        static let processingTask = " Processing task:"
        static let taskCancelled = " Task cancelled:"
        static let taskFailedPrefix = " [IngestQueue] Task failed: "
        static let errorPrefix = ", Error: "
        static let failedTo = "Failed to"
        static let enumerateFolder = " enumerate folder:"
    }

    // MARK: - 日志目标 (Log Target)
    /// Logger.addLog target 字段使用的固定标识
    enum LogTarget {
        static let weeklyInsight = "WeeklyInsight"
        static let dailyRecap = "DailyRecap"
    }

    // MARK: - Mock 文本 (Mock Text)
    /// ModelLab Mock 演示数据中的中文文本
    enum MockText {
        static let notebookLabel = "Notebook (笔记本)"
        static let penLabel = "Pen (钢笔)"
        static let iphoneScreenLabel = "iPhone Screen (手机屏)"
        static let traceStep1Title = "00:01 - 00:03"
        static let traceStep1Desc = "智宇大模型本地测试实验室今日上线"
        static let traceStep2Title = "00:04 - 00:08"
        static let traceStep2Desc = "完美支持 Gemma 4 最新端侧模型"
        static let intentMatchDesc = "🌹 玫瑰播种意图触发 - SUCCESS"
        static let uiRenderingDesc = "玫瑰花瓣粒子开花效果就绪"
        static let intentAnalyserDesc = "识别切换暗黑主题指令 - PASS"
        static let sandboxGatekeeperTitle = "Sandbox Gatekeeper"
        static let sandboxGatekeeperDesc = "设备安全准入校验 - PASS"
        static let hapticFeedbackDesc = "系统调用已触发生效"
        static let sandboxReadTitle = "Sandbox Read"
        static let sandboxReadDesc = "大模型方案设计.md (145行) - 读取成功"
        static let contextSummaryDesc = "总结任务处理中，输出结果对齐 L0-L3 设计"
    }

    // MARK: - Mock 颜色名补充 (Mock Color Name Supplement)
    /// ModelLab Mock 数据中 colorName 字段补充
    enum MockColorNameSupplement {
        static let green = "green"
        static let blue = "blue"
    }

    // MARK: - 格式字符串 (Format String)
    /// 字符串格式化模板
    enum FormatString {
        static let float2 = "%.2f"
    }

    // MARK: - 模型参数标签 (Model Parameter Label)
    /// ModelLab 配置面板 slider 标题
    enum ModelParameterLabel {
        static let temperature = "Temperature"
        static let topP = "Top-P"
    }

    // MARK: - UI 测试参数 (UI Testing Argument)
    /// ProcessInfo 启动参数标识
    enum UITestingArg {
        static let uiTesting = "--uitesting"
        static let resetAuthState = "--reset-auth-state"
    }

    // MARK: - 辅助功能标识 (Accessibility Identifier)
    /// accessibilityIdentifier 前缀
    enum AccessibilityID {
        static let filterPrefix = "filter-"
        static let filterAll = "filter-all"
    }

    // MARK: - 语音标识 (Voice Marker)
    /// 语音笔记前缀与语言代码
    enum VoiceMarker {
        static let micEmoji = "🎙️"
        static let zhCN = "zh-CN"
    }

    // MARK: - 标签前缀 (Tag Prefix)
    /// 标签展示前缀
    enum TagPrefix {
        static let hash = "#"
    }

    // MARK: - 错误描述 (Error Description)
    /// AppError / NSError 描述文本
    enum ErrorDescription {
        static let weChatSDKNotConfigured = "WeChat SDK not configured"
        static let githubURLError = "GitHub URL Error"
        static let githubCallbackError = "GitHub Callback Error"
        static let githubStateMismatch = "GitHub State Mismatch"
        static let watchOSNotSupported = "WatchOS not supported"
    }

    // MARK: - Mock 凭证 (Mock Credential)
    /// Mock 认证凭证字面量
    enum MockCredential {
        static let mockJwtToken = "mock_jwt_token"
    }

    // MARK: - 统计展示值 (Stat Display Value)
    /// 仪表盘 Mock 展示值
    enum StatDisplayValue {
        static let newPagesDelta = "+12"
        static let refPercent = "85%"
    }

    // MARK: - Markdown 缩进 (Markdown Indent)
    /// 换行后缩进
    enum MarkdownIndent {
        static let newlineIndent = "\n    "
    }

    // MARK: - 列表项前缀 (List Item Prefix)
    /// AI 结果列表项前缀判断
    enum ListItemPrefix {
        static let dashSpace = "- "
    }

    // MARK: - Mock 凭证 JSON Key (Mock Credential JSON Key)
    /// OAuth mock userInfo 字典 key
    enum MockCredentialKey {
        static let nickname = "nickname"
    }

    // MARK: - ModelLab 模拟参数 (ModelLab Simulation)
    /// ModelLab 模拟推理参数阈值
    enum ModelLabSimulation {
        static let longTextThreshold: Int = 100
        static let longTextChunkSize: Int = 2
        static let shortTextChunkSize: Int = 1
        static let tokenSpeedMultiplier: Int = 4
        static let promptSnippetLength: Int = 15
        static let promptEllipsis: String = "..."
    }

    // MARK: - 插件详情图标比例 (Plugin Detail Icon Scale)
    /// 插件详情页图标缩放比例
    enum PluginDetailIconScale {
        static let main: Double = 0.9
    }

    // MARK: - 播放进度增量 (Playback Progress Delta)
    /// 音频播放进度步进值
    enum PlaybackProgress {
        static let step: Double = 0.01
    }

    // MARK: - Lint 健康评分阈值 (Lint Health Threshold)
    /// LintService 健康评分扣分权重与等级阈值
    enum LintHealthThreshold {
        static let errorDeduction: Int = 10
        static let warningDeduction: Int = 5
        static let infoDeduction: Int = 2
        static let baseScore: Int = 100
        static let excellentScore: Int = 90
        static let goodScore: Int = 75
        static let fairScore: Int = 50
        static let progressMax: Double = 100.0
    }

    // MARK: - 六角蜂窝网格 (Hex Spiral Grid)
    /// HexSpiralCalculator 蜂窝网格算法参数
    enum HexSpiral {
        static let directionCount: Int = 6
        static let physicalYScale: Double = 1.5
        static let physicalXRDivisor: Double = 2.0
    }

    // MARK: - 标签气泡云 (Tag Bubble Cloud)
    /// 标签气泡云视图缩放与透明度参数
    enum TagBubbleCloud {
        static let countBadgeFontScale: Double = 0.75
        static let canvasHalfDivisor: Double = 2.0
        static let cosineInterpolatorDivisor: Double = 2.0
        static let capsuleCountFontScale: Double = 0.8
        static let capsuleCountVerticalPadding: Double = 0.5
        static let capsuleBubbleRatioThreshold: Double = 0.5
        static let capsuleShadowOpacityFactor: Double = 0.08
        static let capsuleShadowRadius: CGFloat = 2
        static let capsuleShadowY: CGFloat = 1
    }

    // MARK: - Vault 图表占位 (Vault Chart Placeholder)
    /// VaultInsightsPanel 占位曲线控制点比例
    enum VaultChartPlaceholder {
        static let startHeightRatio: Double = 0.7
        static let endHeightRatio: Double = 0.3
        static let control1WidthRatio: Double = 0.4
        static let control1HeightRatio: Double = 0.9
        static let control2WidthRatio: Double = 0.6
        static let control2HeightRatio: Double = 0.1
    }

    // MARK: - 页面详情元数据 (Page Detail Metadata)
    /// 推荐页摘要截断长度
    enum PageDetailMetadata {
        static let summaryPrefixLength: Int = 60
    }

    // MARK: - AI 工作流 (AI Workflow)
    /// AIWorkflowStore 相似页面推荐默认数量
    enum AIWorkflow {
        static let defaultSimilarPageLimit: Int = 3
    }

    // MARK: - 聊天欢迎页 (Chat Welcome)
    /// ChatWelcomeView 图标字号缩放系数
    enum ChatWelcome {
        static let iconFontScale: Double = 0.38
    }

    // MARK: - 问答完成视图 (Quiz Completion)
    /// QuizView 完成页奖杯与分数字号缩放系数
    enum QuizCompletion {
        static let trophyFontScale: Double = 2.5
        static let scoreFontScale: Double = 1.5
    }

    // MARK: - AI 合成服务 (AI Synthesis)
    /// AISynthesisService 上下文截取数量
    enum AISynthesis {
        static let insightQuestionsPagePrefix: Int = 15
        static let insightQuestionsContentPrefix: Int = 100
        static let followUpHistorySuffix: Int = 10
        static let suggestFixContentSnippetPrefix: Int = 500
        static let suggestFixOtherTitlesPrefix: Int = 50
    }

    // MARK: - 合成时间线 (Synthesis Timeline)
    /// SynthesisTimelineView 进度百分比换算基数
    enum SynthesisTimeline {
        static let percentageBase: Double = 100
    }

    // MARK: - 任务中心 (Task Center)
    /// TaskCenter 完成任务保留上限
    enum TaskCenter {
        static let maxRetainedTasks: Int = 20
    }

    // MARK: - 语音笔记 (Voice Note)
    /// VoiceNote 录音列表展示与文本预览长度
    enum VoiceNote {
        static let maxRecordingPreview: Int = 5
        static let recordingTextPrefix: Int = 50
    }

    // MARK: - 推理参数 (Inference Parameter)
    /// 推理参数默认值与匹配容差
    enum InferenceParam {
        static let defaultTemperature: Double = 0.7
        static let defaultTopP: Double = 0.9
        static let defaultTopK: Int = 40
        static let defaultMaxTokens: Int = 2048
        static let presetMatchTolerance: Double = 0.01
        static let customNudgeDelta: Double = 0.02
    }

    // MARK: - 百分比基数 (Percentage Base)
    /// 进度/百分比换算基数
    enum PercentageBase {
        static let full: Double = 100
        static let fullInt: Int = 100
    }

    // MARK: - HTTP 状态码 (HTTP Status Code)
    /// HTTP 响应状态码常量
    enum HTTPStatusCode {
        static let ok: Int = 200
    }

    // MARK: - 服务器配置 (Server Config)
    /// 服务器连接测试相关阈值
    enum ServerConfig {
        static let latencyMsPerSecond: Int = 1000
    }

    // MARK: - 模型卡片 (Model Card)
    /// 模型卡片展示参数
    enum ModelCard {
        static let checksumPrefixLength: Int = 12
    }

    // MARK: - 音频波形 (Audio Waveform)
    /// 录音波形可视化条数
    enum AudioWaveform {
        static let barCount: Int = 6
    }

    // MARK: - 认证翻转动效 (Auth Flip Animation)
    /// 认证区域 3D 翻转动效角度
    enum AuthFlip {
        static let rotationDegrees: Double = 180
    }

    // MARK: - 订阅配额 (Subscription Quota)
    /// 订阅配额卡片危险阈值
    enum SubscriptionQuota {
        static let dangerRatioThreshold: Double = 0.9
        /// 免费用户默认最大保险库数
        static let defaultMaxVaults: Int = 2
        /// 免费用户默认最大页面数
        static let defaultMaxPages: Int = 1000
        /// 免费用户默认最大插件数
        static let defaultMaxPlugins: Int = 3
        /// 无限额度显示符号
        static let unlimitedSymbol: String = "∞"
    }

    // MARK: - 插件描述 (Plugin Description)
    /// 插件详情描述折叠阈值
    enum PluginDescription {
        static let expandLineThreshold: Int = 5
        static let collapsedMaxHeight: CGFloat = 180
    }

    // MARK: - 存储列表内边距 (Storage List Padding)
    /// RawStorageList 标签垂直内边距比例
    enum StorageListPadding {
        static let tagVerticalPaddingScale: CGFloat = 0.5
    }

    // MARK: - RAG 评估 (RAG Evaluation)
    /// RAG 评估历史默认天数
    enum RAGEvaluation {
        static let defaultSelectedDays: Int = 30
    }

    // MARK: - 压力测试 (Stress Test)
    /// 开发者压力测试目标数量
    enum StressTest {
        static let defaultTargetCount: Int = 1000
        static let minTargetCount: Int = 100
        static let maxTargetCount: Int = 10000
        static let step: Int = 100
    }

    // MARK: - 图表域 (Chart Domain)
    /// 系统统计图表 Y 轴域参数
    enum ChartDomain {
        static let baseValue: Double = 100.0
        static let maxValueScale: Double = 1.2
    }

    // MARK: - 耗时进度条 (Timing Bar)
    /// 性能耗时条最大宽度
    enum TimingBar {
        static let maxWidth: CGFloat = 200
    }

    // MARK: - 图谱聚类 (Graph Clustering)
    /// GraphClusteringService K-Means 聚类参数
    enum GraphClustering {
        static let defaultK: Int = 5
        static let maxIterations: Int = 10
    }

    // MARK: - 图谱洞察检测 (Graph Insight Detection)
    /// GraphInsightDetection 桥接节点最小连接社区数
    enum GraphInsightDetection {
        static let minBridgeCommunityCount: Int = 3
    }

    // MARK: - 图谱组件缩放 (Graph Components Scale)
    /// GraphComponents 节点尺寸缩放因子
    enum GraphComponentsScale {
        static let linkCountSizeFactor: CGFloat = 1.5
        static let auraSizeMultiplier: CGFloat = 2.2
    }

    // MARK: - 摄入限制 (Ingest Limit)
    /// IngestService 原始片段截取长度
    enum IngestLimit {
        static let rawSnippetLength: Int = 500
        static let urlRawSnippetLength: Int = 1000
    }

    // MARK: - 摄入网格 (Ingest Grid)
    /// IngestEntryCardsSection 响应式网格列数与尺寸倍数
    enum IngestGrid {
        static let regularColumns: Int = 5
        static let flexibleMinMultiplier: CGFloat = 3
        static let flexibleMaxMultiplier: CGFloat = 7
    }

    // MARK: - 语音播放器 (Voice Audio Player)
    /// VoiceAudioPlayerView 时间格式化与语速参数
    enum VoiceAudioPlayer {
        static let secondsPerMinute: Int = 60
        static let defaultSpeechRate: Float = 0.5
    }

    // MARK: - OCR 扫描 (OCR Scan)
    /// OCRScanView 标题预填长度
    enum OCRScan {
        static let titlePrefixLength: Int = 20
    }

    // MARK: - RAG 评估时间范围 (RAG Eval Time Range)
    /// RAGTimeRangePicker 可选时间窗口（天）
    enum RAGEvalTimeRange {
        /// 短期：7 天
        static let shortDays: Int = 7
        /// 中期：30 天
        static let mediumDays: Int = 30
        /// 长期：90 天
        static let longDays: Int = 90
    }

    // MARK: - 命令面板 (Command Palette)
    /// CommandPaletteView 最近访问展示数量
    enum CommandPalette {
        static let recentAccessCount: Int = 3
    }

    // MARK: - 搜索视图 (Search View)
    /// SearchView 骨架屏行数与空状态图标缩放
    enum SearchView {
        static let skeletonRowCount: Int = 6
        static let emptyIconSizeMultiplier: CGFloat = 1.5
    }

    // MARK: - 知识库引导 (Knowledge Coach Mark)
    /// KnowledgeStore 图谱引导触发最小页面数
    enum KnowledgeCoachMark {
        static let minPagesForGraphCoachMark: Int = 3
    }

    // MARK: - 笔记本洞察面板 (Vault Insights Panel)
    /// VaultInsightsPanel 分类分布柱状图相对高度比例
    /// Bug #104 修复：抽取硬编码 0.6/0.8/0.4/0.2/0.05 为强类型常量
    enum VaultInsightsBarRatio {
        static let entity: Double = 0.6
        static let concept: Double = 0.8
        static let source: Double = 0.4
        static let comparison: Double = 0.2
        static let raw: Double = 0.05
    }

    // MARK: - 笔记本创建按钮 (Create Notebook Button)
    /// 虚线边框 dash pattern（dash 4pt, gap 4pt）
    enum DashedBorder {
        static let dashLength: CGFloat = 4
        static let gapLength: CGFloat = 4
        static let pattern: [CGFloat] = [dashLength, gapLength]
    }

    // MARK: - 开发者设置 (Developer Settings)
    /// 日志 target 标识
    enum DeveloperLogTarget {
        static let stressTest: String = "StressTest"
    }
}
