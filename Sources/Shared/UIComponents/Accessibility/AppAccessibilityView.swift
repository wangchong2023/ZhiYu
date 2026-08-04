//
//  AppAccessibilityView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 共享标准层
//  核心职责：构建 AppAccessibility 界面的 UI 视图层组件。
//
import SwiftUI

// MARK: - View Extension for Accessibility
extension View {
    /// 为视图添加标准的无障碍标签、提示和特征
    /// - Note: 遵循 HIG：hint 为 nil 时不设置，避免空字符串被 VoiceOver 播报为停顿
    func appAccessibility(label: String, hint: String? = nil, traits: AccessibilityTraits = .isStaticText) -> some View {
        self
            .accessibilityLabel(label)
            .modifier(OptionalHintModifier(hint: hint))
            .accessibilityAddTraits(traits)
    }
    
    /// 为知识库页面列表项配置无障碍元素
    func appPageRow(page: KnowledgePage) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(AccessibilityService.pageAnnouncement(
                title: page.title,
                pageTypeDisplay: page.pageType.displayName,
                statusDisplay: page.status.displayName,
                tags: page.tags,
                wordCount: page.wordCount
            ))
            .accessibilityHint(L10n.Accessibility.tapToOpen)
            .accessibilityAddTraits(.isButton)
    }
    
    /// 为图谱节点配置无障碍元素
    func appGraphNode(title: String, type: PageType, linkCount: Int) -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(title), \(type.displayName), \(linkCount) " + L10n.Accessibility.links)
            .accessibilityHint(L10n.Accessibility.tapToOpen)
            .accessibilityAddTraits(.isButton)
    }
    
    /// 根据“减弱动态效果”设置应用条件动画
    func appAnimation(_ animation: Animation = .easeInOut(duration: 0.3)) -> some View {
        self.modifier(ConditionalAnimationModifier(animation: animation))
    }
}

// MARK: - Optional Hint Modifier

/// 可选无障碍提示修饰符
/// 遵循 HIG：hint 为 nil 时不调用 accessibilityHint()，避免空字符串导致 VoiceOver 停顿
private struct OptionalHintModifier: ViewModifier {
    let hint: String?
    
    func body(content: Content) -> some View {
        if let hint {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

// MARK: - Dependency for Reduce Motion
struct AccessibilityReduceMotionKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// 减弱动态效果的环境变量
    var accessibilityReduceMotion: Bool {
        get { self[AccessibilityReduceMotionKey.self] }
        set { self[AccessibilityReduceMotionKey.self] = newValue }
    }
}

// MARK: - Conditional Animation Modifier
/// 条件动画修饰符
/// 负责在“减弱动态效果”开启时禁用动画，否则应用指定的动画效果
struct ConditionalAnimationModifier: ViewModifier {
    let animation: Animation
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    /// 视图主体
    /// - Parameter content: content
    /// - Returns: 返回值
    func body(content: Content) -> some View {
        // 遵循 HIG: 以 reduceMotion 状态作为动画触发值
        // 避免使用 UUID() 每次渲染都生成新值而意外重复触发动画
        content.animation(reduceMotion ? .none : animation, value: reduceMotion)
    }
}

// MARK: - SwiftUI Bridge for Scaling
extension AccessibilityService {
    /// 视图层使用的字体缩放逻辑，桥接到 SwiftUI 的 ContentSizeCategory
    func scaledFont(base: CGFloat, category: ContentSizeCategory) -> CGFloat {
        base * (CategoryMultiplier.map[category] ?? 1.0)
    }
}

private enum CategoryMultiplier {
    static let map: [ContentSizeCategory: CGFloat] = [
        .extraSmall: 0.82,
        .small: 0.88,
        .medium: 0.95,
        .large: 1.0,
        .extraLarge: 1.12,
        .extraExtraLarge: 1.23,
        .extraExtraExtraLarge: 1.35,
        .accessibilityMedium: 1.5,
        .accessibilityLarge: 1.65,
        .accessibilityExtraLarge: 1.8,
        .accessibilityExtraExtraLarge: 2.0,
        .accessibilityExtraExtraExtraLarge: 2.2
    ]
}
