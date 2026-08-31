//
//  DemoMediaConstants.swift
//  ZhiYu
//
//  系统层级：[L1] 基础设施层 / 演示数据工具
//  核心职责：演示用音频/图像/PDF 合成参数常量集（仅 DemoAudioBuilder/DemoImageBuilder/DemoPDFBuilder 使用）。
//

import Foundation

/// 演示媒体合成参数常量集
/// 仅供 DemoAudioBuilder / DemoImageBuilder / DemoPDFBuilder 生成种子数据使用
public enum DemoMediaConstants {

    // MARK: - 演示音频 (Audio)
    /// 默认演示音频时长（秒）
    public static let defaultAudioDuration: TimeInterval = 10.0
    /// 音频采样率 44.1kHz（CD 音质标准）
    public static let audioSampleRate: Double = 44100.0
    /// 和弦切换间隔（秒）— 每 N 秒切换一个和弦音符
    public static let chordSwitchInterval: Float = 2.0
    /// 包络周期（秒）— 渐变衰减循环周期
    public static let envelopePeriod: Float = 0.5
    /// 包络相位归一化除数（与 envelopePeriod 一致，用于将相位归一到 [0,1])
    public static let envelopePhaseDivisor: Float = 0.5
    /// 正弦波角频率系数（2π × frequency × time 中的 2π）
    public static let sineAngularCoefficient: Float = 2.0
    /// 音量缩放系数（防止削波）
    public static let volumeScale: Float = 0.25
    /// 演示和弦频率（C5-E5-G5-C6 悦耳和弦，单位 Hz）
    public static let chordFrequencies: [Float] = [523.25, 659.25, 783.99, 1046.50]

    // MARK: - 演示图像 (Image)
    /// 高清图像最小宽度阈值（像素）
    public static let hdMinWidth: CGFloat = 1000
    /// 笔记图标线宽
    public static let noteIconLineWidth: CGFloat = 1.5
    /// OCR 演示图像表格起始 Y 坐标
    public static let ocrTableStartY: CGFloat = 220
    /// OCR 神经元演示表格列宽（3 列等宽）
    public static let ocrNeuronTableColumnWidths: [CGFloat] = [220, 420, 420]
    /// OCR 咖啡演示表格列宽（3 列不等宽）
    public static let ocrCoffeeTableColumnWidths: [CGFloat] = [220, 260, 580]

    // MARK: - 演示 PDF (PDF)
    /// US Letter 页面宽度（英寸）
    public static let pageWidthInches: CGFloat = 8.5
    /// US Letter 页面高度（英寸）
    public static let pageHeightInches: CGFloat = 11.0
    /// PDF 点/英寸换算（1 inch = 72 pt）
    public static let pointsPerInch: CGFloat = 72.0
    /// 段落默认行间距
    public static let paragraphLineSpacing: CGFloat = 4.0
    /// 紧凑段落行间距
    public static let compactParagraphLineSpacing: CGFloat = 3.0
    /// 段落后垂直间距
    public static let paragraphVerticalSpacing: CGFloat = 8.0
    /// 页眉区域 Y 阈值（低于此值视为页眉）
    public static let headerYThreshold: CGFloat = 140.0
}
