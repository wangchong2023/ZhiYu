//
//  NotebookCard.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：笔记本中心：入口页面、笔记本卡片、创建表单。
//
import SwiftUI

/// 笔记本网格卡片组件。
/// 
/// 该组件承载于 [L2] 业务功能层笔记本工作台。它直观展示笔记本卡片元数据（包含图标、名、更新时间及相对描述），
/// 并且深度挂载了由 Task 2 升级的 `AppCardButtonStyle`，使用户在点击、长按或执行 ContextMenu 时获得拟真阻尼按压物理回跃触感。
struct NotebookCard: View {
    
    /// 获取当前笔记本工作台的数据和路由视图模型
    @Environment(NotebookHubViewModel.self) var viewModel
    
    /// 当前卡片所绑定的笔记本元数据实体 (Vault)
    let notebook: Vault
    
    /// 当用户点击该笔记本卡片时触发的回调行为
    let action: () -> Void
    
    /// 笔记本卡片的渲染视图布局
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DesignSystem.standardPadding) {
                // 1. 图标展示 (根据卡片哈希色计算出来的彩色发光底座，赋予视觉独特性)
                ZStack {
                    RoundedRectangle(cornerRadius: DesignSystem.cardRadius, style: .continuous)
                        .fill(colorForVault.opacity(DesignSystem.Opacity.subtle))
                        .frame(width: DesignSystem.IconSize.xlarge, height: DesignSystem.IconSize.xlarge)
                    
                    Text(notebook.icon ?? defaultIcon)
                        .font(.title2)
                }
                .padding(.top, DesignSystem.tiny)
                .accessibilityHidden(true) // 屏蔽装饰性发光底座及 Emoji 的无谓直译，由外壳统合播报
                
                // 2. 笔记本名称标题
                Text(notebook.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                // 3. 摘要描述文案，字数过多时优雅截断
                Text(notebook.description ?? L10n.Vault.defaultDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer(minLength: DesignSystem.small)
                
                // 4. 元数据底部说明（采用强类型相对时间表达，保持跨语言的国际化适配）
                Text("\(L10n.Vault.lastEdited) \(notebook.updatedAt.formatted(.relative(presentation: .numeric)))")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.secondary.opacity(DesignSystem.Opacity.dim))
            }
            .padding(.horizontal, DesignSystem.small)
            .padding(.top, DesignSystem.small)
            .padding(.bottom, DesignSystem.small) // 统一收紧内边距，减少卡片内部白边
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: DesignSystem.Metrics.notebookCardHeight)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.cardRadius, style: .continuous)
                    .strokeBorder(.primary.opacity(DesignSystem.Opacity.faint), lineWidth: 0.5)
            )
            .premiumAmbientShadow(color: .primary.opacity(DesignSystem.Opacity.light), radius: 10)
            .scaleOnHover()
            // 绑定长按上下文菜单 (ContextMenu)，支持重命名与沙盒物理彻底擦除
            .contextMenu {
                Button {
                    viewModel.prepareEdit(notebook)
                } label: {
                    Label(L10n.Vault.edit, systemImage: DesignSystem.Icons.edit)
                }
                
                // 统一删除操作文案：使用“删除笔记本”以确保与“编辑笔记本”的动宾结构对齐
                Button(role: .destructive) {
                    viewModel.deleteNotebook(id: notebook.id)
                } label: {
                    Label(L10n.Vault.deleteNotebook, systemImage: DesignSystem.Icons.delete)
                }
            }
        }
        // 绑定 Task 2 微动效交互的核心成果，使用户物理压下卡片时得到即时的 Spring 回弹与下沉反馈
        .buttonStyle(AppCardButtonStyle())
        .accessibilityIdentifier("NotebookCard_Item") // 添加 UI 自动化测试精确定位标识，防止测试误触新建按钮
        // MARK: - A11y 无障碍适配
        // UI 测试模式下使用 .contain 允许 XCUITest 穿透容器定位 Button，
        // 确保 element.tap() 能正常触发 SwiftUI Button action（coordinate.tap() 兜底不可靠）
        .accessibilityElement(children: ProcessInfo.processInfo.arguments.contains(FeatureConstants.UITestingArg.uiTesting) ? .contain : .combine)
        .accessibilityLabel("\(notebook.name)\(L10n.Accessibility.notebookCardLabel)")
        .accessibilityValue(notebook.description ?? L10n.Vault.defaultDescription)
        .accessibilityHint("\(L10n.Vault.lastEdited) \(notebook.updatedAt.formatted(.relative(presentation: .numeric)))\(L10n.Accessibility.notebookCardHint)")
    }
    
    /// 根据笔记本名称的哈希值自动计算底座主色调，确保不同笔记本具有差异化的视觉令牌颜色
    private var colorForVault: Color {
        let colors: [Color] = [Color.theme.blue, Color.theme.purple, Color.theme.orange, Color.theme.green, Color.theme.pink, Color.theme.teal]
        let index = abs(notebook.name.hashValue) % colors.count
        return colors[index]
    }
    
    /// 获取根据笔记本 ID 哈希值计算出来的兜底默认 Emoji 图标，收拢至强类型设计令牌
    private var defaultIcon: String {
        let index = abs(notebook.id.hashValue) % DesignSystem.Icons.Notebook.options.count
        return DesignSystem.Icons.Notebook.options[index]
    }
}
