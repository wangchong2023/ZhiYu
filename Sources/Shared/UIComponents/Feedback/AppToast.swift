//
//  AppToast.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：可复用 UI 组件库：编辑器、卡片、加载态、空状态等通用视图。
//
import SwiftUI
import Combine
import Dependencies

// MARK: - App Toast Type
/// 轻提示类型枚举
/// 负责定义 Toast 的视觉风格（图标与色彩）及其代表的业务状态
public enum AppToastType: Equatable {
    case success
    case error
    case info
    case processing
    
    var icon: String {
        switch self {
        case .success: return DesignSystem.Icons.checkCircle
        case .error: return DesignSystem.Icons.warning
        case .info: return DesignSystem.Icons.info
        case .processing: return DesignSystem.Icons.sparkles
        }
    }
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .info: return .appAccent
        case .processing: return .appAccent
        }
    }
}

// MARK: - App Toast Model
/// 轻提示数据模型
/// 负责封装单条 Toast 的展示内容、类型标识及显示时长，具备唯一标识符
public struct AppToast: Identifiable, Equatable {
    public let id = UUID()
    public let type: AppToastType
    public let message: String
    public var duration: Double = DesignSystem.Animation.slowDuration * 6 // 3.0
}

// MARK: - 提示管理器
@MainActor
/// 轻提示管理器
/// 负责 Toast 的队列调度、生命周期计时（自动隐藏）及并发状态管理，确保 UI 层的非阻塞反馈
@Observable
public final class ToastManager {
    @ObservationIgnored private var timer: AnyCancellable?

    public var currentToast: AppToast?

    public init() {}

    /// 展示
    /// - Parameter type: type
    /// - Parameter message: message
    /// - Parameter duration: duration
    public func show(type: AppToastType, message: String, duration: Double = 3.0) {
        withAnimation(.spring(response: DesignSystem.Animation.standardDuration * 1.6, dampingFraction: DesignSystem.Animation.standardDamping)) { // 0.4, 0.8
            currentToast = AppToast(type: type, message: message, duration: duration)
        }

        timer?.cancel()
        if duration > 0 {
            timer = Just(())
                .delay(for: .seconds(duration), scheduler: RunLoop.main)
                .sink { [weak self] _ in
                    self?.dismiss()
                }
        }
    }

    /// 关闭
    public func dismiss() {
        withAnimation(.spring(response: DesignSystem.Animation.standardDuration * 1.6, dampingFraction: DesignSystem.Animation.standardDamping)) { // 0.4, 0.8
            currentToast = nil
        }
    }
}

// MARK: - ToastManager DependencyKey

private enum ToastManagerKey: DependencyKey {
    @MainActor
    static let liveValue: ToastManager = ToastManager()
    @MainActor
    static let testValue: ToastManager = ToastManager()
    @MainActor
    static let previewValue: ToastManager = ToastManager()
}

extension DependencyValues {
    /// Toast 服务依赖（原 ToastManager.shared）
    var toastService: ToastManager {
        get { self[ToastManagerKey.self] }
        set { self[ToastManagerKey.self] = newValue }
    }
}

// MARK: - App Toast View
/// 系统轻提示（Toast）组件
/// 提供非侵入式的状态反馈信息，支持成功、错误、警告等多种语义化样式
/// 轻提示（Toast）视觉组件
/// 负责在界面顶部提供非侵入式的即时反馈，支持模糊背板与弹性入场动画
struct AppToastView: View {
    let toast: AppToast
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: DesignSystem.medium) { // 12
            if toast.type == .processing {
                ProgressView()
                    .tint(toast.type.color)
                    .scaleEffect(DesignSystem.fullOpacity * 0.8) // 0.8
            } else {
                Image(systemName: toast.type.icon)
                    .foregroundStyle(toast.type.color)
            }
            
            Text(toast.message)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.appText)
            
            Spacer()
            
            Button(action: onDismiss) {
                Image(systemName: DesignSystem.Icons.xmark)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.appSecondary)
            }
        }
        .padding(.horizontal, DesignSystem.standardPadding) // 16
        .padding(.vertical, DesignSystem.medium) // 12
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.medium) // 12
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: DesignSystem.medium) // 12
                    .fill(Color.appCard.opacity(DesignSystem.fullOpacity * 0.7)) // 0.7
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.medium) // 12
                .stroke(Color.appBorder.opacity(DesignSystem.disabledOpacity), lineWidth: DesignSystem.borderWidth / 2) // 0.3, 0.5
        )
        .shadow(color: .black.opacity(DesignSystem.shadowOpacity), radius: DesignSystem.standardRadius, y: DesignSystem.small + DesignSystem.atomic) // 0.1, 10, 5
        .padding(.horizontal, DesignSystem.loosePadding) // 20
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - View Modifier
/// 轻提示视图修饰符
/// 负责将 Toast 展示层注入到视图树的最顶层，实现跨页面的即时消息提示能力
struct AppToastModifier: ViewModifier {
    @Dependency(\.toastService) private var manager

    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            content

            if let toast = manager.currentToast {
                AppToastView(toast: toast) {
                    manager.dismiss()
                }
                .padding(.top, DesignSystem.small + DesignSystem.atomic) // 10
                .zIndex(9999)
            }
        }
    }
}

extension View {

    /// appToast
    func appToast() -> some View {
        modifier(AppToastModifier())
    }
}
