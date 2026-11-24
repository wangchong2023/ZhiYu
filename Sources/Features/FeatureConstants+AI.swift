//
//  FeatureConstants+AI.swift
//  ZhiYu
//
//  系统层级：[L2] 业务功能层
//  核心职责：Features 模块 AI 推理、合成、语音、模型管理相关强类型常量。
//

import Foundation
import UFPCore

// MARK: - AI 功能相关常量
extension FeatureConstants {

    // MARK: - 模型任务名 (Task Name)
    /// 大模型支持的任务类型字符串键，用于 switch case 匹配
    enum TaskName {
        static let chat: String = "chat"
        static let completion: String = "completion"
        static let reasoning: String = "reasoning"
        static let code: String = "code"
        static let rag: String = "rag"
        static let translation: String = "translation"
        static let mediaSearch: String = "media_search"
        static let videoSearch: String = "video_search"
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

    // MARK: - 模型参数标签 (Model Parameter Label)
    /// ModelLab 配置面板 slider 标题
    enum ModelParameterLabel {
        static let temperature = "Temperature"
        static let topP = "Top-P"
    }

    // MARK: - 格式字符串 (Format String)
    /// 字符串格式化模板
    enum FormatString {
        static let float2 = "%.2f"
    }

    // MARK: - 单位名 (Unit Name)
    /// 性能指标单位字符串
    enum UnitName {
        static let millisecond = "ms"
        static let tokPerSec = "Tok/s"
        static let megabyte = "MB"
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

    // MARK: - 问答解释编号清洗 (Quiz Pattern)
    /// 答案解释编号清洗正则
    enum QuizPattern {
        /// 匹配答案前缀并捕获前缀文本与答案编号 (Bug #152 防腐)。
        /// 支持中英文前缀：正确答案 / 参考答案 / 答案 / The answer is / Correct Option / Answer。
        /// 行首锚定，避免普通句子中的阿拉伯数字被误判为答案编号。
        /// 捕获组 1 = 前缀文本，捕获组 2 = 答案编号数字。
        static let explanationAnswerRegex: String = #"^(?i)(正确答案|参考答案|答案|The\s+answer\s+is|Correct\s+Option|Answer)\s*[:：是]?\s*(\d+)"#
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

    // MARK: - 服务器配置 (Server Config)
    /// 服务器连接测试相关阈值
    enum ServerConfig {
        static let latencyMsPerSecond: Int = 1000
        static let storageKey: String = "FeatureConstants.ServerConfig"
    }

    // MARK: - ModelLab 模拟参数 (ModelLab Simulation)
    /// ModelLab 模拟推理参数阈值
    enum ModelLabSimulation {
        static let longTextThreshold: Int = 100
        static let longTextChunkSize: Int = 2
        static let shortTextChunkSize: Int = 1
        static let tokenSpeedMultiplier: Int = 4
        /// 录音波形可视化条数
        static let waveformBarCount: Int = 6
        /// 预置多模态视觉样本渲染尺寸
        static let sampleImageWidth: Int = 640
        static let sampleImageHeight: Int = 480
        /// 用例卡片描述文本固定槽位高度（保证 2 列卡片绝对等高对齐）
        static let useCaseCardDescriptionHeight: CGFloat = 48.0
        /// 用例卡片统一最小高度
        static let useCaseCardMinHeight: CGFloat = 156.0
    }

    // MARK: - 播放进度增量 (Playback Progress Delta)
    /// 音频播放进度步进值
    enum PlaybackProgress {
        static let step: Double = 0.01
    }

    // MARK: - 语音标识 (Voice Marker)
    /// 语音笔记前缀与语言代码
    enum VoiceMarker {
        static let micEmoji = "🎙️"
        static let zhCN = "zh-CN"
    }

    // MARK: - 语音播放器 (Voice Audio Player)
    /// VoiceAudioPlayerView 时间格式化与语速参数
    enum VoiceAudioPlayer {
        static let secondsPerMinute: Int = 60
        static let defaultSpeechRate: Float = 0.5
    }

    // MARK: - 压力测试 (Stress Test)
    /// 开发者压力测试目标数量
    enum StressTest {
        static let defaultTargetCount: Int = 1000
        static let minTargetCount: Int = 100
        static let maxTargetCount: Int = 10000
        static let step: Int = 100
    }

    // MARK: - 多模态媒体检索 (Media Search)
    /// MediaSearchIndexer 默认检索数量与展示参数
    enum MediaSearch {
        static let defaultTopK: Int = 10
        static let thumbnailHeight: Double = 120.0
        static let previewImageHeight: Double = 220.0
        static let scoreMultiplier: Float = 100.0
        static let defaultSimilarityThreshold: Double = 0.20
        static let minSimilarityThreshold: Double = 0.0
        static let maxSimilarityThreshold: Double = 0.95
        static let thresholdStep: Double = 0.05
        static let percentMultiplier: Double = 100.0
    }

    // MARK: - 视频时刻检索 (Video Moment Search)
    /// VideoMomentIndexer 默认时刻检索数量与时序聚类参数
    enum VideoMoment {
        static let defaultTopK: Int = 5
        static let defaultSampleInterval: Double = 1.0
        static let demoVideoResourceName: String = "demo_video_moment"
        static let demoVideoExtension: String = "mp4"
    }

    // MARK: - 端侧性能基准跑分 (Model Benchmark)
    /// 端侧模型基准压测与性能评级常量
    enum Benchmark {
        static let fullCircleDegrees: Double = 360.0
        static let placeholderValue: String = "--"
        static let defaultRounds: Int = 3
        static let excellentTPSThreshold: Double = 30.0
        static let goodTPSThreshold: Double = 15.0
        static let excellentTTFTThresholdMs: Double = 250.0
        static let goodTTFTThresholdMs: Double = 600.0
        static let machMsgSizeWordDivisor: Int = 4
        static let benchmarkTokensCount: Int = 32
        static let baseTps2B: Double = 45.8
        static let baseTps4B: Double = 31.2
        static let basePrefill2B: Double = 180.0
        static let basePrefill4B: Double = 260.0
        static let prefillJitterMin: Double = -15.0
        static let prefillJitterMax: Double = 25.0
        static let tpsJitterMin: Double = -1.2
        static let tpsJitterMax: Double = 1.5
        static let gaugeDiameter: CGFloat = 200.0
        static let gaugeStrokeWidth: CGFloat = 10.0
    }

    // MARK: - 端侧行为沙盒 (Mobile Actions)
    enum MobileActionConstants {
        static let maxRecentLogsCount: Int = 10
        static let notificationDelaySeconds: Double = 1.0
        static let defaultNotificationTitle: String = "ZhiYu On-Device AI Reminder"
        static let defaultNotificationBody: String = "Intent recognized offline and action executed."
    }

    // MARK: - 移动端行为意图关键词 (Mobile Action Patterns)
    enum MobileActionPattern {
        static let torchKeywords: [String] = ["手电", "torch", "flash"]
        static let torchOffKeywords: [String] = ["关", "off", "stop"]
        static let hapticKeywords: [String] = ["震动", "触感", "haptic", "vibrat"]
        static let notificationKeywords: [String] = ["通知", "提醒", "notify", "alert"]
        static let themeKeywords: [String] = ["暗黑", "深色", "dark", "浅色", "light"]
        static let lightKeywords: [String] = ["浅色", "light"]
        static let themeModeNotificationKey: String = "isDark"
        static let themeModeNotificationName: String = "ZhiYuThemeModeDidChange"
    }

    // MARK: - 深度思考常量 (Thinking Constants)
    enum ThinkingConstants {
        static let thinkTagOpen: String = "<think>"
        static let thinkTagClose: String = "</think>"
        static let defaultSimulatedThinkingSeconds: Double = 1.4
    }

    // MARK: - 投机采样常量 (Speculative Decoding Constants)
    enum SpeculativeConstants {
        static let fallbackDraftModelId: String = "embeddinggemma-2-740m"
        static let simulatedAcceptanceRatePercent: Double = 78.5
        static let simulatedSpeedupMultiplier: Double = 1.85
    }

    // MARK: - 设备硬件看板 (Device Hardware)
    /// 硬件架构与加速器识别常量
    enum Hardware {
        static let defaultMemoryPercentMultiplier: Double = 100.0
        static let lowMemoryWarningPercent: Double = 20.0
        static let fallbackChipName: String = "Apple Silicon"
        static let minAvailableMemoryGB: Double = 0.5
        /// 无法获取可用内存时按物理内存总量估算的占比
        static let fallbackRatio: Double = 0.7
        /// C 字符串数组的 null 终止符（sysctl 返回的 `hw.machine` 以此结尾）
        static let cStringNullTerminator: Character = "\0"
    }

    // MARK: - 模型任务标签常量 (Model Task Tags)
    enum ModelTaskTag {
        static let multimodal = "multimodal"
        static let vision = "vision"
        static let embedding = "embedding"
        static let audio = "audio"
        static let transcription = "transcription"
    }

    // MARK: - 多模态多媒体样例常量 (Lab Multimodal Constants)
    enum LabMultimodal {
        static let buildingSpacing: CGFloat = 95.0
        static let decisecondMultiplier: Double = 10.0
        static let secondsPerMinute: Int = 60
        static let synthesisBaseFrequency: Double = 220.0
        static let synthesisModulationFrequency: Double = 1.5
        static let synthesisAmplitude: Float = 0.4
        static let audioDecibelRange: Float = 60.0
        static let minNormalizedMeter: CGFloat = 0.08
        static let mockTranscribeRTF: Double = 0.20
        static let simulatedSpeechRateMultiplier: Double = 12.0
        static let audioSampleRate: Double = 44100.0
        static let meterTimerInterval: TimeInterval = 0.05
        static let minWaveformLevel: CGFloat = 0.1
        static let maxWaveformLevel: CGFloat = 1.0
        static let simulatedJitterMin: CGFloat = 0.15
        static let simulatedJitterMax: CGFloat = 0.65
        static let recordedAudioSampleId: String = "real_recorded"
    }

    // MARK: - 模型规格与运行时常量 (Model Spec Constants)
    enum ModelSpecConstants {
        static let quantInt4Q4KM: String = "INT4 (Q4_K_M)"
        static let quantInt8: String = "INT8"
        static let quantInt4AWQ: String = "INT4 AWQ"
        static let engineGGUF: String = "GGUF"
        static let engineLiteRT: String = "LiteRT-LM"
        static let q4kmKeyword: String = "q4_k_m"
        static let int8Keyword: String = "int8"
        static let ggufExtension: String = ".gguf"
        static let vendorGoogle: String = "google"
        static let sourceModelScope: String = "ModelScope"
        static let sourceHuggingFace: String = "HuggingFace"
        static let secondsPerMinute: Int = 60
        static let sandboxDocumentsPrefix: String = "Documents/"
        static let modelBinExtension: String = ".bin"
        static let ggufFormatName: String = "gguf"
        static let coremlFormatName: String = "coreml"
        static let genericBinaryFormatName: String = "generic_bin"
        static let magicHeaderByteLength: Int = 4
        static let minValidModelFileSize: Int64 = 32768 // 32KB 最小安全阈值
        static let ggufMagicHeaderBytes: [UInt8] = [0x47, 0x47, 0x55, 0x46] // "GGUF"
    }

    // MARK: - 模型格式探针诊断原因常量
    enum ModelProbeConstants {
        static let reasonCannotOpenFileHandle: String = "probe_cannot_open_file_handle"
        static let reasonHeaderTruncated: String = "probe_header_truncated"
        static let reasonUnknownHeader: String = "probe_unknown_header"
        static let reasonCoreMLPackageIncomplete: String = "probe_coreml_package_incomplete"
        static let reasonBelowMinimumSize: String = "probe_below_min_size"
        static let metadataJSON: String = "metadata.json"
        static let espressoNet: String = "model.espresso.net"
        static let espressoWeights: String = "weights/weight.bin"
    }

    // MARK: - 上下文缓存窗口常量 (Context Window Constants)
    enum ContextWindowConstants {
        static let label2K: String = "2K"
        static let label4K: String = "4K"
        static let label8K: String = "8K"
        static let label32K: String = "32K"
        static let kvMemory2KMB: Int = 128
        static let kvMemory4KMB: Int = 256
        static let kvMemory8KMB: Int = 512
        static let kvMemory32KMB: Int = 1536
    }

    // MARK: - 端侧真实视觉分析常量 (Vision Analysis Constants)
    enum VisionAnalysisConstants {
        static let topLabelCount: Int = 5
        static let minLabelConfidence: Float = 0.05
        static let fallbackLabelCount: Int = 3
        static let maxOCRPreviewLength: Int = 200
        static let colorGridSize: Int = 24
        static let bytesPerPixel: Int = 4
        static let bitsPerComponent: Int = 8
        static let maxChannelValue: Double = 255.0
        static let percentMultiplier: Double = 100.0
        static let ocrLanguages: [String] = ["zh-Hans", "en-US"]
        static let identifierSeparator: String = ", "
        
        // ITU-R BT.601 亮度加权转换系数
        static let lumaWeightRed: Double = 0.299
        static let lumaWeightGreen: Double = 0.587
        static let lumaWeightBlue: Double = 0.114
        
        // 色彩与场景启发式阈值
        static let floralRedThreshold: Double = 0.35
        static let floralRedDominanceG: Double = 1.15
        static let floralRedDominanceB: Double = 1.10
        static let floralSaturationThreshold: Double = 0.28
        static let foliageGreenThreshold: Double = 0.35
        static let foliageGreenDominance: Double = 1.10
        static let skyWaterBlueThreshold: Double = 0.35
        static let skyWaterBlueDominance: Double = 1.15
        static let waterStreamBrightness: Double = 0.65
        static let waterStreamLowSaturation: Double = 0.25
        
        // 启发式标签置信度
        static let primaryConfidence: Double = 0.92
        static let secondaryConfidence: Double = 0.86
        static let tertiaryConfidence: Double = 0.78

        // 启发式标签名常量 (Heuristic Label Names)
        static let labelFlowers = "Flowers & Blossoms"
        static let labelMagentaFloral = "Magenta Floral Petals"
        static let labelGardenFlora = "Garden Flora"
        static let labelGreenFoliage = "Green Foliage"
        static let labelBotanicalPlants = "Botanical Plants"
        static let labelNaturalForest = "Natural Forest"
        static let labelBlueSky = "Blue Sky & Horizon"
        static let labelWaterSurface = "Water Surface"
        static let labelOpenLandscape = "Open Landscape"
        static let labelWaterfallStream = "Waterfall & Stream"
        static let labelFlowingWater = "Flowing Water"
        static let labelMossyRiverbed = "Mossy Riverbed"
        static let labelSceneSubject = "Visual Scene Subject"
        static let labelColorComposition = "Color Composition"

        // 预置样本置信度标签常量
        static let presetDeskDisplay = "Ultra-wide Display"
        static let presetDeskKeyboard = "Mechanical Keyboard"
        static let presetDeskPlant = "Desk Plant & Mug"
        static let presetArchTopology = "Layered Topology"
        static let presetArchFlow = "Unidirectional Flow"
        static let presetArchComponents = "Component Blocks"
        static let presetNightSkyline = "Metropolis Skyline"
        static let presetNightWindows = "Illuminated Windows"
        static let presetNightMoon = "Crescent Moon"
    }

    // MARK: - 实验室智能响应合成常量 (Lab Synthesis Constants)
    enum LabSynthesisConstants {
        static let sampleSmartDesk: String = "smart_desk"
        static let sampleArchChart: String = "arch_chart"
        static let sampleCityNight: String = "city_night"
        static let creativeTempSplit: Double = 0.65
    }

    // MARK: - 通用交互缩放与布局常量
    enum TaskCenterLayout {
        static let selectedScale: CGFloat = 1.03
        static let pressedScale: CGFloat = 0.95
        static let collapsedDescriptionHeight: CGFloat = 180
        static let conflictSidebarWide: CGFloat = 240
        static let conflictSidebarCompact: CGFloat = 180
        static let donutInnerRadiusRatio: CGFloat = 0.65
        static let iPadTabBarTopOffset: CGFloat = 48
        static let iPadDetailTopOffset: CGFloat = 36
    }

    enum MedalAnimationScale {
        static let glowMin: CGFloat = 0.8
        static let glowMax: CGFloat = 1.2
        static let iconMin: CGFloat = 0.9
        static let iconMax: CGFloat = 1.1
        static let cardMin: CGFloat = 0.5
    }
}
