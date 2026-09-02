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
}
