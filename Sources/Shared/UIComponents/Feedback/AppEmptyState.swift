//
//  AppEmptyState.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI

/// 智适应空状态视图组件
/// 负责在内容为空时展示视觉占位符、说明文案及引导操作按钮。
public struct AppEmptyState: View {
    // MARK: - Properties
    
    public let icon: String
    public let title: String
    public let description: String?
    public let hint: String?
    public let action: Action?

    /// 操作按钮配置结构
    public struct Action {
        public let label: String
        public let icon: String?
        public let role: Role?
        public let handler: () -> Void

        public enum Role { case primary, secondary, destructive }

        public init(label: String, icon: String? = nil, role: Action.Role = .secondary, handler: @escaping () -> Void) {
            self.label = label
            self.icon = icon
            self.role = role
            self.handler = handler
        }
    }

    // MARK: - Initialization
    
    public init(
        icon: String,
        title: String,
        description: String? = nil,
        hint: String? = nil,
        action: Action? = nil
    ) {
        self.icon = icon
        self.title = title
        self.description = description
        self.hint = hint
        self.action = action
    }

    // MARK: - Body
    
    public var body: some View {
        VStack(spacing: Spacing.giant) { // 24
            // 视觉展示区
            ZStack {
                // 背景装饰圆环
                Circle()
                    .fill(Color.appAccent.opacity(Colors.glassOpacity * 0.5))
                    .frame(width: DesignSystem.Metrics.heroValueSize, height: DesignSystem.Metrics.heroValueSize)

                Circle()
                    .fill(Color.appAccent.opacity(Colors.glassOpacity * 0.3))
                    .frame(width: DesignSystem.Gallery.emptyStateImageSize, height: DesignSystem.Gallery.emptyStateImageSize)

                // 主图标容器
                Image(systemName: icon)
                    .font(.system(size: Spacing.iconHuge * 1.5, weight: .light))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.appAccent, .appAccent.opacity(DesignSystem.Opacity.dim)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .frame(height: DesignSystem.Metrics.emptyStateGraphicHeight)

            // 文字说明区
            VStack(spacing: Spacing.small) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.appText)

                if let description = description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundStyle(.appSecondary)
                        .multilineTextAlignment(.center)
                }
            }

            // 辅助提示区
            if let hint = hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.appAccent)
                    .padding(.horizontal, Spacing.medium)
                    .padding(.vertical, DesignSystem.tiny)
                    .background(
                        RoundedRectangle(cornerRadius: Spacing.chipRadius)
                            .fill(Color.appAccent.opacity(Colors.glassOpacity))
                    )
            }

            // 操作引导按钮
            if let action = action {
                Button(action: action.handler) {
                    HStack(spacing: Spacing.tiny + Spacing.atomic) {
                        if let icon = action.icon {
                            Image(systemName: icon)
                        }
                        Text(action.label)
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(actionForegroundColor(for: action.role))
                    .padding(.horizontal, Spacing.widePadding)
                    .padding(.vertical, Spacing.medium)
                    .background(
                        action.role == .primary || action.role == nil
                            ? Color.appAccent
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: Spacing.smallRadius))
                    .overlay(
                        RoundedRectangle(cornerRadius: Spacing.smallRadius)
                            .stroke(
                                action.role == .primary || action.role == nil ? Color.clear : Color.appAccent, 
                                lineWidth: Spacing.borderWidth
                            )
                    )
                }
                .buttonStyle(ScaleButtonStyle())
                // MARK: [UI 测试自愈] 注入唯一的可测试性定位标识符，以便在冷启动空状态下定位此引导按钮
                .accessibilityIdentifier("empty_state_action_button")
            }
        }
        .padding(.horizontal, Spacing.huge)
        .frame(maxWidth: .infinity)
        // MARK: [UI 测试自愈] 在进行 UI 自动化测试时，允许 XCUITest 穿透容器定位到具体的 action Button；非测试状态下合并为单个无障碍节点以优化 VoiceOver 体验
        .accessibilityElement(children: ProcessInfo.processInfo.arguments.contains("--uitesting") ? .contain : .combine)
        .accessibilityLabel(buildAccessibilityLabel())
    }

    // MARK: - Private Methods
    
    private func actionForegroundColor(for role: Action.Role?) -> Color {
        switch role {
        case .primary, .none: return .white
        case .secondary: return .appAccent
        case .destructive: return .red
        }
    }

    private func buildAccessibilityLabel() -> String {
        var label = "\(title)."
        if let description = description { label += " \(description)." }
        if let hint = hint { label += " Hint: \(hint)" }
        if let action = action { label += " Action: \(action.label)." }
        return label
    }
}

// MARK: - Convenience Initializers

public extension AppEmptyState {
    /// 简单空状态：仅图标、标题与描述
    static func simple(icon: String, title: String, description: String? = nil) -> AppEmptyState {
        AppEmptyState(icon: icon, title: title, description: description)
    }

    /// 带操作的空状态：包含主/次引导按钮
    static func withAction(
        icon: String,
        title: String,
        description: String? = nil,
        hint: String? = nil,
        actionLabel: String,
        actionIcon: String? = nil,
        actionRole: Action.Role = .secondary,
        actionHandler: @escaping () -> Void
    ) -> AppEmptyState {
        AppEmptyState(
            icon: icon,
            title: title,
            description: description,
            hint: hint,
            action: Action(label: actionLabel, icon: actionIcon, role: actionRole, handler: actionHandler)
        )
    }
}
