//
//  DeviceHardwareBar.swift
//  ZhiYu
//
//  系统层级：[L3] 表现层 / 视图组件
//  核心职责：端侧硬件算力看板 — 实时展示设备芯片架构、ANE/Metal 加速器就绪状态与物理内存可用度。
//

import SwiftUI
import Metal
import UFPCore
import UFPDesignSystem

/// 端侧设备算力与硬件看板组件
@MainActor
public struct DeviceHardwareBar: View {

    /// 芯片显示名称
    private var chipName: String {
        #if targetEnvironment(simulator)
        return FeatureConstants.Hardware.fallbackChipName
        #else
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [UInt8](repeating: 0, count: size)
        _ = machine.withUnsafeMutableBytes { buffer in
            sysctlbyname("hw.machine", buffer.baseAddress, &size, nil, 0)
        }
        let identifier = String(bytes: machine, encoding: .utf8)?
            .trimmingCharacters(in: CharacterSet(charactersIn: String(FeatureConstants.Hardware.cStringNullTerminator)))
            ?? FeatureConstants.Hardware.fallbackChipName
        return identifier.isEmpty ? FeatureConstants.Hardware.fallbackChipName : identifier
        #endif
    }

    /// 物理总内存（单位：GB）
    private var totalMemoryGB: Double {
        Double(ProcessInfo.processInfo.physicalMemory) / SystemConstants.bytesPerGB
    }

    /// 估算可用内存（单位：GB）
    private var availableMemoryGB: Double {
        // 收敛到跨平台内存桥接（iOS 用 os_proc_available_memory，macOS 用 host_statistics64）
        let availableBytes = AppMemoryBridge.availableBytes()
        if availableBytes > 0 {
            return max(availableBytes / SystemConstants.bytesPerGB, FeatureConstants.Hardware.minAvailableMemoryGB)
        }
        return max(totalMemoryGB * FeatureConstants.Hardware.fallbackRatio, FeatureConstants.Hardware.minAvailableMemoryGB)
    }

    /// 可用内存比例（百分比）
    private var memoryPercent: Double {
        let ratio = availableMemoryGB / max(totalMemoryGB, 1.0)
        let rawPercent = ratio * FeatureConstants.Hardware.defaultMemoryPercentMultiplier
        return min(max(rawPercent, 0.0), FeatureConstants.Hardware.defaultMemoryPercentMultiplier)
    }

    /// 进度条宽度比例
    private var progressRatio: CGFloat {
        CGFloat(memoryPercent / FeatureConstants.Hardware.defaultMemoryPercentMultiplier)
    }

    /// 进度条颜色状态
    private var progressColor: Color {
        memoryPercent > FeatureConstants.Hardware.lowMemoryWarningPercent ? Color.theme.cyan : Color.theme.red
    }

    /// 是否支持 Metal 3 GPU 加速
    private var isMetalSupported: Bool {
        MTLCreateSystemDefaultDevice() != nil
    }

    /// 格式化内存提示文本
    private var memorySummaryText: String {
        let availableBytes = Int64(availableMemoryGB * SystemConstants.bytesPerGB)
        let totalBytes = Int64(totalMemoryGB * SystemConstants.bytesPerGB)
        let availableFormatted = ByteFormatter.format(availableBytes)
        let totalFormatted = ByteFormatter.format(totalBytes)
        return L10n.ModelManager.Hardware.memoryFormat(availableFormatted, totalFormatted, memoryPercent)
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            headerRow
            acceleratorsRow
            memoryProgressSection
        }
        .padding(DesignTokens.Spacing.standardPadding)
        .background(Color.appCard.opacity(DesignTokens.Opacity.dim))
        .cornerRadius(DesignTokens.Spacing.mediumRadius)
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Spacing.mediumRadius)
                .stroke(Color.appBorder.opacity(DesignTokens.Opacity.prominent), lineWidth: DesignTokens.SystemStroke.divider)
        )
    }

    // MARK: - 视图子模块拆分

    /// 顶行：芯片型号与加速器就绪指示
    @ViewBuilder
    private var headerRow: some View {
        HStack {
            HStack(spacing: DesignTokens.SystemSpacing.tiny) {
                Image(systemName: DesignTokens.Icons.cpu)
                    .foregroundStyle(Color.theme.cyan)
                Text(L10n.ModelManager.Hardware.chipFormat(chipName))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.theme.text)
            }

            Spacer()

            HStack(spacing: DesignTokens.SystemSpacing.atomic) {
                Circle()
                    .fill(Color.theme.green)
                    .frame(width: DesignTokens.SystemSpacing.atomic, height: DesignTokens.SystemSpacing.atomic)
                Text(L10n.ModelManager.Hardware.acceleratorReady)
                    .font(.caption2.bold())
                    .foregroundStyle(Color.theme.green)
            }
            .padding(.horizontal, DesignTokens.SystemSpacing.tiny)
            .padding(.vertical, DesignTokens.SystemSpacing.atomic)
            .background(Color.theme.green.opacity(DesignTokens.Opacity.disabled))
            .clipShape(Capsule())
        }
    }

    /// 加速器硬件能力徽章行
    @ViewBuilder
    private var acceleratorsRow: some View {
        HStack(spacing: DesignTokens.SystemSpacing.small) {
            acceleratorBadge(icon: DesignTokens.Icons.sparkles, title: L10n.ModelManager.Hardware.neuralEngine, isReady: true)
            if isMetalSupported {
                acceleratorBadge(icon: DesignTokens.Icons.boltFill, title: L10n.ModelManager.Hardware.metalGPU, isReady: true)
            }
        }
    }

    /// 内存可用度进度指示
    @ViewBuilder
    private var memoryProgressSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.SystemSpacing.atomic) {
            HStack {
                Text(memorySummaryText)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.theme.gray.opacity(DesignTokens.Opacity.disabled))
                        .frame(height: DesignTokens.SystemSpacing.tiny)

                    Capsule()
                        .fill(progressColor)
                        .frame(width: max(geo.size.width * progressRatio, DesignTokens.SystemSpacing.tiny), height: DesignTokens.SystemSpacing.tiny)
                }
            }
            .frame(height: DesignTokens.SystemSpacing.tiny)
        }
        .padding(.top, DesignTokens.SystemSpacing.atomic)
    }

    @ViewBuilder
    private func acceleratorBadge(icon: String, title: String, isReady: Bool) -> some View {
        HStack(spacing: DesignTokens.SystemSpacing.atomic) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(isReady ? Color.theme.cyan : .secondary)
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(isReady ? Color.theme.text : .secondary)
        }
        .padding(.horizontal, DesignTokens.SystemSpacing.small)
        .padding(.vertical, DesignTokens.SystemSpacing.tiny)
        .background(Color.theme.cyan.opacity(DesignTokens.Opacity.subtle))
        .clipShape(Capsule())
    }
}
