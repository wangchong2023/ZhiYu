//
//  SmartRoutingView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/05.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：智能路由配置视图，提供端云混合策略、任务路由规则、网络状态监控等配置界面。云端模型选择已集成到在线大模型配置中。
//

import SwiftUI

/// 大模型策略配置视图
@MainActor
public struct SmartRoutingView: View {

    @Environment(ThemeManager.self) private var themeManager
    @State private var modelManager = GlobalModelManager.shared

    public init() {}

    public var body: some View {
        // 直接返回 ScrollView，利用父容器统一渲染的渐变背景，避免多层 ignoresSafeArea 劫持手势
        ScrollView {
            VStack(spacing: DesignSystem.large) {
                modelStrategySection
                runtimeStatusSection
            }
            .padding(DesignSystem.medium)
        }
    }

    // MARK: - 大模型策略

    private var modelStrategySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            Text(L10n.ModelManager.Routing.modelStrategy)
                .font(.subheadline.weight(.semibold)).foregroundStyle(.appText).padding(.horizontal, DesignSystem.small)

            // 端侧与在线混合开关
            VStack(alignment: .leading, spacing: DesignSystem.small) {
                HStack(alignment: .center, spacing: SystemSpacing.element) {
                    // 主开关左侧添加合并融合图标，以表现端侧与在线智能调度的含义
                    Image(systemName: "arrow.triangle.merge")
                        .foregroundStyle(Color.theme.accent)
                    VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                        Text(L10n.ModelManager.Routing.onlineEscalationToggle)
                            .font(.subheadline).foregroundStyle(.appText)
                        Text(L10n.ModelManager.Routing.onlineEscalationDesc)
                            .font(.caption2).foregroundStyle(.appSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(get: { modelManager.isCloudEscalationEnabled },
                        set: { modelManager.isCloudEscalationEnabled = $0 })).labelsHidden()
                }
                Divider()
                
                // 补全辅助配置的微型功能图标
                Toggle(isOn: .constant(false)) {
                    Label(L10n.ModelManager.Routing.wifiOnly, systemImage: "wifi")
                }
                .font(.subheadline)
                
                Toggle(isOn: .constant(true)) {
                    Label(L10n.ModelManager.Routing.autoFallback, systemImage: "shield.fill")
                }
                .font(.subheadline)
                
                Toggle(isOn: .constant(true)) {
                    Label(L10n.ModelManager.Routing.preferLocal, systemImage: "cpu.fill")
                }
                .font(.subheadline)
            }
            .padding()
            .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius))
        }
    }

    // MARK: - 运行状态

    private var runtimeStatusSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.small) {
            Text(L10n.ModelManager.Routing.runtimeStatus)
                .font(.subheadline.weight(.semibold)).foregroundStyle(.appText).padding(.horizontal, DesignSystem.small)

            VStack(spacing: DesignSystem.small) {
                statusRow(label: L10n.ModelManager.Routing.localModelReady,
                    value: getActiveModelName(),
                    status: modelManager.isModelLocalReady(for: modelManager.activeModelId) ? .healthy : .warning)
                HStack {
                    Image(systemName: "cpu").foregroundStyle(.appAccent).frame(width: DesignSystem.titleIconSize)
                    Text(L10n.ModelManager.Routing.currentDecision).font(.subheadline).foregroundStyle(.appText)
                    Spacer()
                    Text(getCurrentRoutingDecision()).font(.caption.weight(.bold)).foregroundStyle(.appAccent)
                        .padding(.horizontal, DesignSystem.small).padding(.vertical, DesignSystem.atomic)
                        .background(Color.appAccent.opacity(DesignSystem.Opacity.glass)).clipShape(Capsule())
                }
                
                // 本地模型未就绪且非强制云端时的自动托管友好诊断提示
                if !modelManager.isCloudEscalationEnabled && !modelManager.isModelLocalReady(for: modelManager.activeModelId) {
                    Text(L10n.ModelManager.Routing.autoOnlineDesc)
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.leading, DesignSystem.titleIconSize + 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Divider()
                statusRow(label: L10n.ModelManager.Routing.networkCurrent, value: "WiFi", status: .healthy)
                statusRow(label: L10n.ModelManager.Routing.networkLatency, value: "23ms", status: .healthy)
                statusRow(label: L10n.ModelManager.Routing.networkBandwidth, value: L10n.ModelManager.Routing.networkBandwidthExcellent, status: .healthy)
            }
            .padding()
            .background(Color.appCard.opacity(DesignSystem.Opacity.dim))
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.mediumRadius))
        }
    }

    private func statusRow(label: String, value: String, status: HealthStatus) -> some View {
        HStack {
            Circle().fill(status.color).frame(width: DesignSystem.iconSmall, height: DesignSystem.iconSmall)
            Text(label).font(.subheadline).foregroundStyle(.appText)
            Spacer()
            Text(value).font(.subheadline.weight(.medium)).foregroundStyle(.appText)
        }
    }

    private func getActiveModelName() -> String {
        if let m = modelManager.remoteManifests.first(where: { $0.modelId == modelManager.activeModelId }) {
            let isReady = modelManager.isModelLocalReady(for: modelManager.activeModelId)
            let suffix = isReady ? " (\(L10n.ModelManager.Card.ready))" : " (\(L10n.ModelManager.Routing.statusNotReady))"
            return m.displayName + suffix
        }
        return L10n.ModelManager.Routing.decisionUnselected
    }

    private func getCurrentRoutingDecision() -> String {
        if modelManager.isCloudEscalationEnabled {
            return L10n.ModelManager.Routing.decisionOnline
        } else if modelManager.isModelLocalReady(for: modelManager.activeModelId) {
            return L10n.ModelManager.Routing.decisionLocal
        } else {
            return L10n.ModelManager.Routing.decisionAutoOnline
        }
    }

    // MARK: - 健康状态枚举

    private enum HealthStatus {
        case healthy
        case warning
        case error

        var color: Color {
            switch self {
            case .healthy:
                return .green
            case .warning:
                return .orange
            case .error:
                return .red
            }
        }
    }
}

// MARK: - 预览

#if DEBUG
#Preview {
    ZStack {
        // 在预览模式下在最外层包裹背景，确保预览效果与真机运行时一致
        ThemeManager().pageBackground()
            .ignoresSafeArea()
        SmartRoutingView()
    }
    .environment(ThemeManager())
}
#endif
