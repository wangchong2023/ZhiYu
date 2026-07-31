//
//  AIRainbowGlowBadge.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层 / 通用 UI 组件
//  核心职责：构建常驻全局 NavigationBar 右上角的“全局 AI 呼吸光晕微标”。动态反映端侧就绪、云端路由、端云混合或后台下载状态，并提供极客级状态 popover 浮窗交互。
//

import SwiftUI

/// 全局常驻发光 AI 呼吸指示微标
@MainActor
public struct AIRainbowGlowBadge: View {
    
    // MARK: - 依赖注入
    
    @State private var modelManager = GlobalModelManager.shared
    
    @Environment(Router.self) private var router
    
    // MARK: - 动画与浮窗状态
    
    /// 控制呼吸动画的周期性缩放与阴影大小
    @State private var breathAnim: Double = 0.0
    
    /// 控制旋转彩虹环的动画旋转角度
    @State private var rotateAnim: Double = 0.0
    
    /// 是否弹出状态 popover 浮窗
    @State private var isShowingPopover = false
    
    public init() {}
    
    public var body: some View {
        Button(action: {
            HapticFeedback.shared.trigger(.selection)
            isShowingPopover = true
        }) {
            badgeIconView
                .popover(isPresented: $isShowingPopover, arrowEdge: .bottom) {
                    controlCenterPopoverView
                }
        }
        .buttonStyle(.plain)
        .onAppear {
            // 启动呼吸光晕周期缩放动画
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                breathAnim = 1.0
            }
            // 启动彩虹霓虹渐变旋转动画
            withAnimation(.linear(duration: 6.0).repeatForever(autoreverses: false)) {
                rotateAnim = 360.0
            }
        }
    }
    
    // MARK: - 微标主体视觉
    
    private var badgeIconView: some View {
        let isLocalReady = modelManager.isModelLocalReady(for: modelManager.activeModelId)
        let isDownloading = isCurrentlyDownloading
        
        // 色彩配置：本地就绪采用极客霓虹绿，云端提权采用极客梦幻蓝紫，正在下载采用炫彩旋转
        let mainColor: Color = isLocalReady ? Color.theme.green : (modelManager.isCloudEscalationEnabled ? Color.theme.purple : .appAccent)
        let glowColor: Color = isLocalReady ? Color.theme.green.opacity(DesignSystem.Opacity.prominent) : .appAccent.opacity(DesignSystem.Opacity.prominent)
        
        return ZStack {
            // 1. 底层呼吸发光光晕 (Rainbow Glow Effect)
            Circle()
                .fill(glowColor)
                .frame(width: DesignSystem.Metrics.glowBadgeSize, height: DesignSystem.Metrics.glowBadgeSize)
                .scaleEffect(1.0 + breathAnim * 0.45)
                .blur(radius: 2.0 + breathAnim * 3.0)
                .opacity(0.4 + breathAnim * 0.5)
            
            // 2. 炫彩旋转霓虹圈 (代表端云混合或下载中)
            if isDownloading {
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.green, .cyan, .blue, .purple, .pink, .green],
                            center: .center
                        ),
                        lineWidth: 2
                    )
                    .frame(width: DesignSystem.Metrics.glowBadgeRingSize, height: DesignSystem.Metrics.glowBadgeRingSize)
                    .rotationEffect(.degrees(rotateAnim))
            } else if modelManager.isCloudEscalationEnabled {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .blue, .cyan],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: DesignSystem.IconSize.small, height: DesignSystem.IconSize.small)
                    .scaleEffect(1.0 + breathAnim * 0.1)
            }
            
            // 3. 核心功能指示图标 (Glow Icon)
            ZStack {
                Circle()
                    .fill(Color.appCard)
                    .frame(width: DesignSystem.large, height: DesignSystem.large)
                
                Image(systemName: isLocalReady ? "checkmark.shield.fill" : (isDownloading ? "arrow.down.circle.fill" : "sparkles"))
                    .font(.system(size: isLocalReady ? 10 : 9, weight: .bold))
                    .foregroundStyle(mainColor)
            }
        }
        .padding(DesignSystem.atomic * 1.5)
        .contentShape(Circle())
    }
    
    // MARK: - 控制中枢 Popover 浮窗 (V2 控制中枢)
    
    private var controlCenterPopoverView: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium) {
            // 头部：标题与关闭按钮
            HStack {
                Image(systemName: "cpu")
                    .foregroundStyle(.appAccent)
                    .font(.headline)
                Text(L10n.Common.unknown)
                    .font(.headline)
                    .foregroundStyle(.appText)
                Spacer()
                
                Button(action: { isShowingPopover = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.appSecondary.opacity(DesignSystem.Opacity.dim))
                        .font(.system(size: 20)) // Dynamic Type
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 2)
            
            Divider()
            
            // 1. 当前大模型运行状态
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.Common.unknown)
                    .font(.caption)
                    .foregroundStyle(.appSecondary)
                
                HStack(spacing: DesignSystem.small) {
                    Image(systemName: modelManager.isModelLocalReady(for: modelManager.activeModelId) ? "checkmark.shield.fill" : "network")
                        .foregroundStyle(modelManager.isModelLocalReady(for: modelManager.activeModelId) ? Color.theme.green : .appAccent)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(modelManager.activeModelId)
                            .font(.system(.body, design: .monospaced))
                            .bold()
                            .foregroundStyle(.appText)
                        
                        Text(modelManager.isModelLocalReady(for: modelManager.activeModelId) ? L10n.Common.unknown : L10n.Common.unknown)
                            .font(.caption2)
                            .foregroundStyle(.appSecondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.appBackground.opacity(DesignSystem.Opacity.dim))
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
            }
            
            // 2. 「云端深度考据提权」一键 Toggle (2.4 契约)
            Toggle(isOn: Binding(
                get: { modelManager.isCloudEscalationEnabled },
                set: { modelManager.isCloudEscalationEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.Common.unknown)
                        .font(.subheadline.bold())
                        .foregroundStyle(.appText)
                    Text(L10n.Common.unknown)
                        .font(.caption2)
                        .foregroundStyle(.appSecondary)
                }
            }
            .tint(.appAccent)
            .padding(.vertical, 4)
            
            // 3. 硬件安全与拦截计数
            let memInGb = Double(modelManager.physicalMemory) / (1024 * 1024 * 1024)
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundStyle(Color.theme.green)
                Text(L10n.Common.unknown)
                    .font(.caption)
                    .foregroundStyle(.appText)
                Spacer()
                Text("\(String(format: "%.1f", memInGb)) GB")
                    .font(.caption.monospaced())
                    .foregroundStyle(.appSecondary)
            }
            .padding(DesignSystem.tiny)
            .background(Color.theme.green.opacity(DesignSystem.Opacity.subtle))
            .clipShape(RoundedRectangle(cornerRadius: Spacing.Chip.cornerRadius))
            
            Divider()
            
            // 4. 快捷前往 AI 模型市场
            Button(action: {
                isShowingPopover = false
                // 在路由中推送大模型市场
                router.isShowingSettingsSheet = true
                // 这里我们可以直接通过 Router 切换到对应的 ModelStoreView
            }) {
                HStack {
                    Spacer()
                    Image(systemName: "cart.badge.plus")
                    Text(L10n.Common.unknown)
                    Spacer()
                }
                .font(.subheadline.bold())
                .padding()
                .background(Color.appAccent)
                .foregroundStyle(Color.theme.white)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.smallRadius))
            }
            .buttonStyle(.plain)
        }
        .padding()
        .frame(width: controlCenterWidth)
        // swiftlint:disable:next magic_numbers_opacity
        .background(Color.appCard.opacity(0.95))
        .presentationBackgroundInteraction(.enabled)
    }

    // MARK: - 平台适配宽度

    /// AI 控制中枢弹窗宽度，按照不同平台与屏幕尺寸自适应
    private var controlCenterWidth: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 360
        #elseif os(iOS)
        return UIDevice.current.userInterfaceIdiom == .pad ? 320 : 300
        #else
        return 300
        #endif
    }
    
    // MARK: - 辅助计算
    
    /// 当前是否正有权重在进行后台静默下载
    private var isCurrentlyDownloading: Bool {
        for (_, state) in modelManager.downloadStates {
            if case .downloading = state {
                return true
            }
        }
        return false
    }
}
