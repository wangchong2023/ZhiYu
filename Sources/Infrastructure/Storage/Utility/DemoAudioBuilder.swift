//
//  DemoAudioBuilder.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层 / 工具
//  核心职责：为示例语音笔记合成真正的物理音频文件 (.wav/.m4a)，确保播放时能清晰听到声音。
//

#if canImport(AVFoundation)
import AVFoundation

public struct DemoAudioBuilder {
    /// 确保物理音频文件就绪，若不存在则实时合成标准 44.1kHz WAV 音频
    public static func ensureAudioExists(at path: String, duration: TimeInterval = 10.0) -> URL? {
        let fileURL = URL(fileURLWithPath: path)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return fileURL
        }
        
        do {
            let parentDir = fileURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            
            let sampleRate: Double = 44100.0
            let numSamples = Int(sampleRate * duration)
            guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(numSamples)) else {
                return nil
            }
            
            buffer.frameLength = AVAudioFrameCount(numSamples)
            if let channels = buffer.floatChannelData {
                let channelData = channels[0]
                // 合成柔和的和弦波形音符 (C5-E5-G5 悦耳和弦)
                let frequencies: [Float] = [523.25, 659.25, 783.99, 1046.50]
                for i in 0..<numSamples {
                    let time = Float(i) / Float(sampleRate)
                    let chordIndex = Int(time * 2.0) % frequencies.count
                    let freq = frequencies[chordIndex]
                    // 渐变衰减效果
                    let envelope = sin(Float.pi * (time.truncatingRemainder(dividingBy: 0.5)) / 0.5)
                    channelData[i] = sin(2.0 * Float.pi * freq * time) * 0.25 * envelope
                }
            }
            
            let audioFile = try AVAudioFile(forWriting: fileURL, settings: format.settings)
            try audioFile.write(from: buffer)
            return fileURL
        } catch {
            return nil
        }
    }
}
#endif
