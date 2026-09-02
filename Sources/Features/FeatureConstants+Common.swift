//
//  FeatureConstants+Common.swift
//  ZhiYu
//
//  系统层级：[L2] 业务功能层
//  核心职责：Features 模块跨领域共享常量（Mock 数据、日志、文件类型、正则、UI 装饰等）。
//

import Foundation
import UFPCore

// MARK: - 跨领域共享常量
extension FeatureConstants {

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

    // MARK: - Mock 颜色名补充 (Mock Color Name Supplement)
    /// ModelLab Mock 数据中 colorName 字段补充
    enum MockColorNameSupplement {
        static let green = "green"
        static let blue = "blue"
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

    // MARK: - 开发者设置 (Developer Settings)
    /// 日志 target 标识
    enum DeveloperLogTarget {
        static let stressTest: String = "StressTest"
    }

    // MARK: - 分析事件 Key (Analytics Key)
    /// LocalAnalyticsService 事件名与属性 key
    enum AnalyticsKey {
        static let documentIngested = "document_ingested"
        static let format = "format"
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

    // MARK: - Markdown 缩进 (Markdown Indent)
    /// 换行后缩进
    enum MarkdownIndent {
        static let newlineIndent = "\n    "
    }

    // MARK: - 插件设置类型 (Plugin Setting Type)
    /// 插件设置项类型字符串键
    enum PluginSettingType {
        static let toggle: String = "toggle"
        static let text: String = "text"
        static let info: String = "info"
    }

    // MARK: - 插件详情图标比例 (Plugin Detail Icon Scale)
    /// 插件详情页图标缩放比例
    enum PluginDetailIconScale {
        static let main: Double = 0.9
    }

    // MARK: - 存储列表内边距 (Storage List Padding)
    /// RawStorageList 标签垂直内边距比例
    enum StorageListPadding {
        static let tagVerticalPaddingScale: CGFloat = 0.5
    }

    // MARK: - 统计展示值 (Stat Display Value)
    /// 仪表盘 Mock 展示值
    enum StatDisplayValue {
        static let newPagesDelta = "+12"
        static let refPercent = "85%"
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
}
