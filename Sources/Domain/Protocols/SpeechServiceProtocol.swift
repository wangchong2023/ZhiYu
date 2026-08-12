//
//  SpeechServiceProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：定义 SpeechService 模块的抽象契约接口。
//
import Foundation
import Combine
import Observation

/// 提供语音录制与实时/离线语音转文字（ASR）的抽象服务接口协议。
@MainActor
public protocol SpeechServiceProtocol: AnyObject, Observable {
    /// 指示当前是否正在录制音频。
    var isRecording: Bool { get }
    
    /// 指示当前是否正在执行语音识别转文字的计算任务。
    var isTranscribing: Bool { get }
    
    /// 获取或设置当前已经转录出来的识别结果文本。
    var transcribedText: String { get set }
    
    /// 获取当前麦克风输入的实时音频分贝电平（通常范围在 0.0 至 1.0 之间）。
    var audioLevel: Float { get }
    
    /// 录音期间采集到的最近音频电平历史数据队列，用于绘制声波动画。
    var audioLevelHistory: [Float] { get }
    
    /// 语音转文字服务当前的运行状态提示短语。
    var statusMessage: String { get }
    
    /// 系统当前支持进行语音转译的语言区域（Locale）列表。
    var supportedLanguages: [(code: String, name: String)] { get }
    
    /// 获取或设置当前生效的识别目标语言标识（如 "zh-CN", "en-US"）。
    var selectedLanguage: String { get set }
    
    /// 用户是否已授权访问麦克风及开启系统语音识别服务。
    var hasPermission: Bool { get }
    
    /// 获取当前应用沙盒下已录制并保存的录音记录列表。
    var recordings: [VoiceRecording] { get }
    
    /// 异步或同步检查并申请系统麦克风及语音识别的隐私权限。
    func checkPermission()
    
    /// 开始音频录制，并初始化实时流式语音转译。
    func startRecording()
    
    /// 停止当前的音频录制，完成录音数据落盘。
    func stopRecording()
    
    /// 对指定路径下的已有音频文件进行异步语音转译。
    ///
    /// - Parameter url: 音频文件在本地沙盒的物理路径。
    /// - Returns: 返回转译出的文本结果。
    /// - Throws: 异常于转录引擎报错或文件读取失败。
    func transcribeFile(url: URL) async throws -> String
    
    /// 将当前录制完毕的临时音频归档保存，并命名。
    ///
    /// - Parameter title: 录音记录的展示标题。
    /// - Returns: 返回保存成功后的录音实体对象。
    func saveRecording(title: String) -> VoiceRecording
    
    /// 从沙盒及记录列表中物理删除一条已有的录音。
    ///
    /// - Parameter recording: 待删除的录音实体模型。
    func deleteRecording(_ recording: VoiceRecording)
    
    /// 当前录制音频文件的沙盒 URL（并行录制），stopRecording 后可用
    var currentAudioFileURL: URL? { get }

    /// 清除当前转录文本缓存，重置输入框状态。
    func clearTranscription()
}

// MARK: - DependencyKey
import Dependencies
import UFPCore

/// SpeechServiceProtocol 的 DependencyKey
@MainActor
public enum SpeechServiceKey: DependencyKey {
    @MainActor
    public static var liveValue: any SpeechServiceProtocol {
        ServiceContainer.shared.resolve((any SpeechServiceProtocol).self)
    }
}

extension DependencyValues {
    @MainActor
    public var speechService: any SpeechServiceProtocol {
        get { self[SpeechServiceKey.self] }
        set { self[SpeechServiceKey.self] = newValue }
    }
}
