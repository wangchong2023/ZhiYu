//
//  NotebookHubViewModel.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：管理 NotebookHub 视图的状态绑定与数据交互逻辑。
//
import Foundation
import Observation
import SwiftUI

/// 笔记本工作台视图模型
@Observable
@MainActor
public final class NotebookHubViewModel {
    
    // MARK: - 状态属性
    
    /// 显示模式
    public enum DisplayMode {
        case grid, list
        
        var icon: String {
            self == .grid ? DesignSystem.Icons.gridOutline : DesignSystem.Icons.list
        }
    }
    
    /// 排序方式
    public enum SortOption {
        case date, name
    }
    
    /// 当前显示模式
    public var displayMode: DisplayMode = .grid
    
    /// 当前排序方式
    public var sortOption: SortOption = .date
    
    /// 是否正在显示创建笔记本的弹窗
    public var isShowingCreateSheet: Bool = false
    
    /// 新笔记本名称
    public var newNotebookName: String = "" {
        didSet {
            let limit = DesignSystem.Metrics.maxNotebookNameLength
            if newNotebookName.count > limit {
                newNotebookName = String(newNotebookName.prefix(limit))
            }
        }
    }
    
    /// 新笔记本图标 (Emoji)
    public var newNotebookIcon: String = DesignSystem.Icons.Notebook.options.first ?? DesignSystem.Icons.Notebook.fallback
    
    /// 新笔记本描述
    public var newNotebookDescription: String = ""
    
    /// 是否正在处理加载
    public var isLoading: Bool = false
    
    /// 搜索文本
    public var searchText: String = ""
    
    // ── 编辑/重命名相关状态 ──
    public var isShowingRenameAlert: Bool = false
    public var isShowingEditSheet: Bool = false
    public var editingVault: Vault?
    public var editingName: String = "" {
        didSet {
            let limit = DesignSystem.Metrics.maxNotebookNameLength
            if editingName.count > limit {
                editingName = String(editingName.prefix(limit))
            }
        }
    }
    public var editingIcon: String = ""
    public var editingDescription: String = ""
    
    // MARK: - 依赖
    
    private let vaultService = VaultService.shared
    
    // MARK: - 初始化
    
    public init() {}
    
    // MARK: - 业务逻辑
    
    /// 所有笔记本列表
    /// 过滤后的笔记本列表
    /// 过滤且排序后的笔记本列表
    public var notebooks: [Vault] {
        var result = vaultService.vaults
        
        // 1. 过滤
        if !searchText.isEmpty {
            result = result.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) 
            }
        }
        
        // 2. 排序
        switch sortOption {
        case .date:
            // 默认按创建时间倒序排列 (最新创建的在前)
            result.sort { $0.createdAt > $1.createdAt }
        case .name:
            result.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
        
        return result
    }
    
    /// 切换显示模式
    public func toggleDisplayMode() {
        displayMode = (displayMode == .grid) ? .list : .grid
    }
    
    /// 选择Notebook
    /// - Parameter notebook: notebook
    public func selectNotebook(_ notebook: Vault) {
        Task { @MainActor in
            // Phase 1: 重置路由状态，让 SwiftUI 在当前周期中安全处理
            Router.shared.sidebarSelection = nil
            Router.shared.selectedTab = .knowledge
            Router.shared.path = NavigationPath()
            // 让出主线程：确保 NavigationStack 被完全销毁、手势系统稳定后，
            // 再触发 NavigationSplitView 创建，避免 GestureRecognizer 冲突崩溃
            await Task.yield()
            // Phase 2: 触发视图层级切换 (NotebookHubView → mainContent)
            vaultService.selectVault(notebook)
        }
    }
    
    /// 创建新笔记本
    public func createNotebook() {
        guard !newNotebookName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        let icon = newNotebookIcon.trimmingCharacters(in: .whitespaces).isEmpty ? nil : newNotebookIcon
        let description = newNotebookDescription.trimmingCharacters(in: .whitespaces).isEmpty ? nil : newNotebookDescription
        
        vaultService.createVault(
            name: newNotebookName,
            icon: icon,
            description: description
        )
        
        // 重置状态
        newNotebookName = ""
        newNotebookIcon = DesignSystem.Icons.Notebook.options.first ?? DesignSystem.Icons.Notebook.fallback
        newNotebookDescription = ""
        isShowingCreateSheet = false
    }
    
    /// 删除笔记本
    /// - Parameter id: 笔记本 ID
    public func deleteNotebook(id: UUID) {
        vaultService.deleteVault(id: id)
    }
    
    /// 准备编辑 (全量属性)
    public func prepareEdit(_ vault: Vault) {
        editingVault = vault
        editingName = vault.name
        editingIcon = vault.icon ?? ""
        editingDescription = vault.description ?? ""
        isShowingEditSheet = true
    }
    
    /// 执行编辑保存
    public func confirmEdit() {
        guard let vault = editingVault else { return }
        vaultService.updateVault(
            id: vault.id,
            name: editingName,
            icon: editingIcon.isEmpty ? nil : editingIcon,
            description: editingDescription.isEmpty ? nil : editingDescription
        )
        editingVault = nil
        isShowingEditSheet = false
    }
    
    /// 准备重命名 (仅名称，用于 Alert 场景)
    public func prepareRename(_ vault: Vault) {
        editingVault = vault
        editingName = vault.name
        isShowingRenameAlert = true
    }
    
    /// 执行重命名保存
    public func confirmRename() {
        guard let vault = editingVault else { return }
        renameNotebook(id: vault.id, newName: editingName)
        editingVault = nil
        editingName = ""
        isShowingRenameAlert = false
    }
    
    /// 重命名笔记本
    /// - Parameters:
    ///   - id: 笔记本 ID
    ///   - newName: 新名称
    public func renameNotebook(id: UUID, newName: String) {
        vaultService.renameVault(id: id, newName: newName)
    }
}
