//
//  AppTooltip.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

// MARK: - App Tooltip
/// 引导提示组件，用于首次使用时的操作引导。
@MainActor
/// 操作引导提示组件
/// 负责在 UI 元素周围弹出气泡样式的提示信息，用于新手引导或新功能展示
public struct AppTooltip: View {
    public let title: String
    public let description: String
    public let icon: String
    public var arrowDirection: ArrowDirection = .top
    public var accentColor: Color = .appAccent

    public enum ArrowDirection {
        case top, bottom, left, right
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.medium - DesignSystem.atomic) { // 10
            HStack(alignment: .top, spacing: DesignSystem.medium - DesignSystem.atomic) { // 10
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.titleIconSize, weight: .semibold))
                    .foregroundStyle(accentColor)
                    .frame(width: DesignSystem.largeIconSize - DesignSystem.tiny, height: DesignSystem.largeIconSize - DesignSystem.tiny) // 28
                    .background(accentColor.opacity(DesignSystem.glassOpacity * 1.2))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.appText)

                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.appSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(DesignSystem.standardPadding) // 16
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.medium)
                .fill(Color.appCard)
                .shadow(color: .black.opacity(DesignSystem.glassOpacity * 1.2), radius: DesignSystem.shadowRadius + DesignSystem.small, x: 0, y: DesignSystem.shadowY + DesignSystem.atomic * 2) // 0.12, 16, 6
        )
        .overlay(
            arrowView,
            alignment: arrowAlignment
        )
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.medium))
    }

    @ViewBuilder
    private var arrowView: some View {
        switch arrowDirection {
        case .top:
            VStack(spacing: 0) {
                Triangle()
                    .fill(Color.appCard)
                    .frame(width: DesignSystem.medium, height: DesignSystem.small) // 12, 8
                    .shadow(color: .black.opacity(DesignSystem.shadowOpacity * 1.5), radius: DesignSystem.borderWidth * 2, x: 0, y: -DesignSystem.atomic) // 0.06, 2, -1
                Spacer()
            }
        case .bottom:
            VStack(spacing: 0) {
                Spacer()
                Triangle()
                    .fill(Color.appCard)
                    .frame(width: DesignSystem.medium, height: DesignSystem.small) // 12, 8
                    .rotationEffect(.degrees(180))
                    .shadow(color: .black.opacity(DesignSystem.shadowOpacity * 1.5), radius: DesignSystem.borderWidth * 2, x: 0, y: DesignSystem.atomic) // 0.06, 2, 1
            }
        case .left:
            HStack(spacing: 0) {
                Triangle()
                    .fill(Color.appCard)
                    .frame(width: DesignSystem.small, height: DesignSystem.medium) // 8, 12
                    .rotationEffect(.degrees(-90))
                Spacer()
            }
        case .right:
            HStack(spacing: 0) {
                Spacer()
                Triangle()
                    .fill(Color.appCard)
                    .frame(width: DesignSystem.small, height: DesignSystem.medium) // 8, 12
                    .rotationEffect(.degrees(90))
            }
        }
    }

    private var arrowAlignment: Alignment {
        switch arrowDirection {
        case .top: return .bottom
        case .bottom: return .top
        case .left: return .trailing
        case .right: return .leading
        }
    }
}

// MARK: - Triangle Shape
/// 基础三角形形状
/// 负责绘制气泡提示组件的指向箭头，支持 2D 路径闭合
struct Triangle: Shape {

    /// path
    /// - Returns: 返回值
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - View Extension
extension View {
    /// 在视图上叠加一个引导提示浮层
    func tooltip(_ type: TooltipManager.TooltipType, isPresented: Binding<Bool>) -> some View {
        self.overlay(alignment: .bottom) {
            if isPresented.wrappedValue {
                AppTooltip(
                    title: L10n.Coachmark.tr(type.titleKey),
                    description: L10n.Coachmark.tr(type.descriptionKey),
                    icon: type.icon,
                    arrowDirection: .top,
                    accentColor: .appAccent
                )
                .padding(.horizontal, DesignSystem.standardPadding + DesignSystem.small) // 24
                .padding(.bottom, DesignSystem.small)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .onTapGesture {
                    withAnimation(.easeOut(duration: DesignSystem.Animation.standardDuration * 0.8)) { // 0.2
                        isPresented.wrappedValue = false
                        TooltipManager.shared.markShown(type)
                    }
                }
            }
        }
    }
}
