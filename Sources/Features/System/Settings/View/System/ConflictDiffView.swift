//
//  ConflictDiffView.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/24.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L3] 表现层
//  核心职责：提供 iCloud 多端同步版本冲突时的分栏可视化 Diff 比对与手动合并编辑界面。
//

#if ICLOUD_ENABLED
import SwiftUI

/// 冲突比对视图常量
private enum ConflictDiffConstants {
    /// 宽屏分栏阈值 (iPad/横屏判定)
    static let wideWidthThreshold: CGFloat = 700
}

// MARK: - 冲突可视化数据载体
/// 承载单篇页面发生物理碰撞或命名重合时的比对实体结构
struct ConflictingPage: Identifiable, Hashable {
    /// 唯一标识符
    var id: UUID
    /// 冲突文档标题
    var title: String
    /// 本地最新版本页面
    var localPage: KnowledgePage?
    /// 云端最新版本页面
    var remotePage: KnowledgePage?
}

// MARK: - 冲突分栏 Diff 主视图
/// 左右分栏可视化合并面板。左栏展示本地最新版本，右栏展示云端冲突版本。
/// 提供“选用本地”、“选用云端”以及“手动合并（支持在最终编辑框中自行修改）”的一键提交流程。
struct ConflictDiffView: View {
    @Environment(\.dismiss) private var dismiss
    
    /// 当前捕获到的同步冲突信息及 continuation 挂起钩子
    let conflictInfo: ConflictInfo
    
    /// 系统级 AppStore 数据持久化入口
    let store: AppStore
    
    // ── 内部交互状态 ──
    @State private var conflicts: [ConflictingPage] = []
    @State private var selectedIndex: Int = 0
    @State private var mergedContents: [UUID: String] = [:]
    @State private var isApplying = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 采用智宇设计系统的背景装饰色，实现磨砂玻璃视觉基调
                PageBackgroundView(accentColor: .appAccent)
                    .ignoresSafeArea()
                
                if conflicts.isEmpty {
                    emptyConflictStateView
                } else {
                    mainConflictDiffLayout
                }
            }
            .navigationTitle(L10n.ICloud.Conflict.manualMergeTitle)
.appNavigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        // 如果用户取消，默认走 LWW 合并避免流程卡死
                        conflictInfo.continuation.resume(returning: .merge)
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.ICloud.Conflict.completeMerge) {
                        Task {
                            await applyManualMergeResults()
                        }
                    }
                    .disabled(isApplying)
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                loadConflicts()
            }
        }
    }
    
    // MARK: - 骨架与排版组件
    
    /// 空冲突降级状态（通常仅发生日志时碰撞，不含物理 Page 冲突）
    private var emptyConflictStateView: some View {
        VStack(spacing: DesignSystem.medium) {
            Image(systemName: "checkmark.icloud.fill")
                .font(.system(size: ComponentSpacing.colossal)) // Dynamic Type
                .foregroundStyle(.appAccent)
            
            Text(L10n.ICloud.Conflict.noPhysicalConflict)
                .font(.headline)
                .foregroundStyle(.appText)
            
            Text(L10n.ICloud.Conflict.metaConflictAutoSolved)
                .font(.subheadline)
                .foregroundStyle(.appSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(L10n.ICloud.Conflict.runSmartMerge) {
                conflictInfo.continuation.resume(returning: .merge)
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .tint(.appAccent)
        }
        .padding()
    }
    
    /// 包含左侧列表与右侧分栏 Diff 的核心交互板式
    private var mainConflictDiffLayout: some View {
        GeometryReader { geo in
            let isWide = geo.size.width > ConflictDiffConstants.wideWidthThreshold
            
            HStack(spacing: 0) {
                // 1. 左侧冲突文档选取列表
                VStack(alignment: .leading, spacing: DesignSystem.tiny) {
                    Text(L10n.ICloud.Conflict.docListCount(conflicts.count))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.appSecondary)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    List(selection: Binding(
                        get: { selectedIndex },
                        set: { selectedIndex = $0 ?? 0 }
                    )) {
                        ForEach(0..<conflicts.count, id: \.self) { index in
                            let item = conflicts[index]
                            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                                Text(item.title)
                                    .font(.system(size: SystemFontSize.subheadline, weight: .semibold)) // Dynamic Type
                                    .foregroundStyle(.appText)
                                
                                Text("ID: \(item.id.uuidString.prefix(8))...")
                                    .font(.system(size: SystemFontSize.micro)) // Dynamic Type
                                    .foregroundStyle(.appSecondary)
                            }
                            .tag(index)
                        }
                    }
                    .listStyle(.plain)
                }
                .frame(width: isWide ? 240 : 180)
                .background(Color.appCard.opacity(DesignSystem.Opacity.glass))
                
                Divider()
                
                // 2. 右侧三栏比对及最终编辑板式
                if selectedIndex < conflicts.count {
                    let currentConflict = conflicts[selectedIndex]
                    conflictingDetailPanel(for: currentConflict, isWide: isWide)
                }
            }
        }
    }
    
    /// 冲突文档的细节比对区
    /// - Parameters:
    ///   - item: 发生冲突的页面对象
    ///   - isWide: 是否大屏幕并排显示
    @ViewBuilder
    /// 冲突文档的细节比对区
    /// - Parameters:
    ///   - item: 发生冲突的页面对象
    ///   - isWide: 是否大屏幕并排显示
    @ViewBuilder
    private func conflictingDetailPanel(for item: ConflictingPage, isWide: Bool) -> some View {
        VStack(spacing: 0) {
            // 元信息头
            conflictMetaHeader(for: item)
            
            Divider()
            
            // 双栏比对主体与合并编辑区
            ScrollView {
                VStack(spacing: DesignSystem.medium) {
                    conflictDiffColumns(for: item, isWide: isWide)
                    
                    Divider()
                        .padding(.vertical)
                    
                    // 合并编辑编辑区
                    conflictMergedEditor(for: item)
                }
                .padding()
            }
        }
        .background(Color.clear)
    }

    /// 冲突文档的元信息头部视图，展示各版本的修改时间并提供快捷覆盖操作
    /// - Parameter item: 发生冲突的页面对象
    /// - Returns: 包含更新时间和操作菜单的头部视图
    private func conflictMetaHeader(for item: ConflictingPage) -> some View {
        HStack(spacing: DesignSystem.medium) {
            VStack(alignment: .leading, spacing: DesignSystem.atomic) {
                Text(L10n.ICloud.Conflict.localVersionTime(formatDate(item.localPage?.updatedAt)))
                Text(L10n.ICloud.Conflict.remoteVersionTime(formatDate(item.remotePage?.updatedAt)))
            }
            .font(.system(size: SystemFontSize.microLarge)) // Dynamic Type
            .foregroundStyle(.appSecondary)
            
            Spacer()
            
            // 快速选择覆盖模态
            Menu(L10n.ICloud.Conflict.smartOverwriteMode) {
                Button(L10n.ICloud.Conflict.allChooseLocal) {
                    mergedContents[item.id] = item.localPage?.content ?? ""
                }
                Button(L10n.ICloud.Conflict.allChooseRemote) {
                    mergedContents[item.id] = item.remotePage?.content ?? ""
                }
            }
            .font(.subheadline)
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.appCard)
    }

    /// 渲染本地与远程版本的比对分栏视图
    /// - Parameters:
    ///   - item: 发生冲突的页面对象
    ///   - isWide: 是否在大屏设备下宽屏并排显示
    /// - Returns: 比对分栏的布局视图
    private func conflictDiffColumns(for item: ConflictingPage, isWide: Bool) -> some View {
        Group {
            if isWide {
                HStack(alignment: .top, spacing: DesignSystem.medium) {
                    diffContentColumn(title: L10n.ICloud.Conflict.localVersionHeader, content: item.localPage?.content ?? "")
                    diffContentColumn(title: L10n.ICloud.Conflict.remoteVersionHeader, content: item.remotePage?.content ?? "")
                }
            } else {
                VStack(spacing: DesignSystem.medium) {
                    diffContentColumn(title: L10n.ICloud.Conflict.localVersionHeader, content: item.localPage?.content ?? "")
                    diffContentColumn(title: L10n.ICloud.Conflict.remoteVersionHeader, content: item.remotePage?.content ?? "")
                }
            }
        }
    }

    /// 冲突文档的手动合并编辑器视图，允许精细修改并支持快捷载入指定版本内容
    /// - Parameter item: 发生冲突的页面对象
    /// - Returns: 合并编辑器的整体布局视图
    private func conflictMergedEditor(for item: ConflictingPage) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.tiny) {
            HStack {
                Text(L10n.ICloud.Conflict.mergedResultEditorHeader)
                    .font(.subheadline.bold())
                    .foregroundStyle(.appText)
                Spacer()
                Button(L10n.ICloud.Conflict.chooseLocalContent) {
                    mergedContents[item.id] = item.localPage?.content ?? ""
                }
                .font(.caption)
                Button(L10n.ICloud.Conflict.chooseRemoteContent) {
                    mergedContents[item.id] = item.remotePage?.content ?? ""
                }
                .font(.caption)
            }
            
            TextEditor(text: Binding(
                get: { mergedContents[item.id] ?? "" },
                set: { mergedContents[item.id] = $0 }
            ))
            .font(.system(.body, design: .monospaced))
            .frame(minHeight: DesignSystem.Gallery.modalMaxWidth)
            .padding(DesignSystem.tiny)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
            .overlay(
                RoundedRectangle(cornerRadius: SystemRadius.small)
                    .stroke(Color.appAccent.opacity(DesignSystem.Opacity.shadow), lineWidth: SystemStroke.divider)
            )
        }
    }
    
    /// 渲染比对分栏的内容卡片
    /// - Parameters:
    ///   - title: 分栏标题
    ///   - content: Markdown 文本内容
    private func diffContentColumn(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.tiny) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.appSecondary)
            
            ScrollView {
                Text(content)
                    .font(.system(size: SystemFontSize.caption, design: .monospaced)) // Dynamic Type
                    .padding(DesignSystem.tiny)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: DesignSystem.Metrics.sourceCardWidth)
            .background(Color.appCard.opacity(DesignSystem.Opacity.soft))
            .clipShape(RoundedRectangle(cornerRadius: SystemRadius.small))
        }
    }
    
    // MARK: - 数据加载与持久化事务
    
    /// 识别过滤并装载当前冲突的页面，初始化手势与修改状态
    private func loadConflicts() {
        var items: [ConflictingPage] = []
        
        // 1. 首先遍历查找 ID 相同但内容发生偏离的冲突页面
        for localPage in conflictInfo.localPages {
            if let remotePage = conflictInfo.remotePages.first(where: { $0.id == localPage.id }) {
                if localPage.content != remotePage.content {
                    items.append(ConflictingPage(id: localPage.id, title: localPage.title, localPage: localPage, remotePage: remotePage))
                }
            }
        }
        
        // 2. 接着补充查找标题重复冲突，但物理 ID 不匹配的特殊冲突
        for localPage in conflictInfo.localPages {
            if let remotePage = conflictInfo.remotePages.first(where: { $0.title == localPage.title && $0.id != localPage.id }) {
                if !items.contains(where: { $0.title == localPage.title }) {
                    items.append(ConflictingPage(id: localPage.id, title: localPage.title, localPage: localPage, remotePage: remotePage))
                }
            }
        }
        
        self.conflicts = items
        
        // 装填默认值：智能选用较新版本的内容渲染输入框
        for item in items {
            let localTime = item.localPage?.updatedAt ?? Date.distantPast
            let remoteTime = item.remotePage?.updatedAt ?? Date.distantPast
            
            if remoteTime > localTime {
                mergedContents[item.id] = item.remotePage?.content ?? ""
            } else {
                mergedContents[item.id] = item.localPage?.content ?? ""
            }
        }
    }
    
    /// 应用手动合并结果：将编辑好的内容更新写入本地 store，释放挂起的 continuation
    private func applyManualMergeResults() async {
        isApplying = true
        
        // 开启批处理事务将全部用户手动解决的内容落盘
        for item in conflicts {
            let userContent = mergedContents[item.id] ?? ""
            
            // 更新本地已存在的页面实例
            if var page = item.localPage {
                page.content = userContent
                page.updatedAt = Date() // 物理盖戳当前时间
                await store.savePage(page)
            } else if var remotePage = item.remotePage {
                // 如果是远程新增但标题重名的对撞，以用户指定合并值新增本地页面
                remotePage.content = userContent
                remotePage.updatedAt = Date()
                await store.savePage(remotePage)
            }
        }
        
        // 恢复 continuation，选用 .keepLocal 覆盖策略
        // 因为用户在此界面上是完成了手动合并，并将最新合并版本写回了本地 Store
        // 从而同步流程接下来可以用修改后合并的本地最新库单向覆盖 iCloud，完成云端闭环
        conflictInfo.continuation.resume(returning: .keepLocal)
        
        isApplying = false
        dismiss()
    }
    
    // MARK: - 辅助方法
    
    /// 格式化修改时间显示
    /// - Parameter date: 目标日期
    /// - Returns: 时间格式化字符串
    private func formatDate(_ date: Date?) -> String {
        guard let date else { return L10n.ICloud.Conflict.noTimeInfo }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
}
#endif
