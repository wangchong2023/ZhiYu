//
//  TagCloudCoordinator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：负责 TagCloud 业务流的导航路由与协作管理。
//
import SwiftUI
import UFPCore
import Observation

@MainActor
@Observable
final class TagCloudCoordinator {
    // ── 状态属性 ──
    var tags: [(tag: String, count: Int)] = []
    var selectedTag: String?
    static let searchThreshold = 30
    var searchText = ""
    var isEditMode = false
    var selectedTagsForBulk: Set<String> = []
    
    // 弹窗控制
    var showAddTagDialog = false
    var addTagName = ""
    var tagToRename: String?
    var newTagName = ""
    var showDeleteConfirm = false
    var tagToDelete: String?
    
    // ── 基础设施依赖 ──
    @ObservationIgnored @Inject private var store: AppStore
    @ObservationIgnored @Inject private var haptic: any HapticFeedbackProtocol

    init(initialTag: String? = nil) {
        self.selectedTag = initialTag
    }

    // ── 计算属性 ──

    /// 经过搜索过滤后的标签列表
    var filteredTags: [(tag: String, count: Int)] {
        if searchText.isEmpty { return tags }
        return tags.filter { $0.tag.localizedCaseInsensitiveContains(searchText) }
    }

    /// 基于选中标签筛选的页面列表
    var filteredPages: [KnowledgePage] {
        guard let tag = selectedTag else { return store.pages }
        return store.pages.filter { $0.tags.contains(tag) }
    }

    // ── 业务动作 ──

    /// 执行数据抓取
    func fetchData() async {
        let allTags = store.getAllTags()
        self.tags = allTags.map { (tag: $0.key, count: $0.value) }.sorted { $0.tag < $1.tag }
    }

    /// 执行标签重命名逻辑
    func performRename() {
        guard let old = tagToRename, !newTagName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let trimmed = newTagName.trimmingCharacters(in: .whitespaces)
        Task {
            await store.renameTag(old, to: trimmed)
            if selectedTag == old { selectedTag = trimmed }
            await fetchData()
        }
        tagToRename = nil
        haptic.trigger(.success)
    }

    /// 执行标签删除逻辑
    func performDelete() {
        if let tag = tagToDelete {
            Task {
                await store.deleteTag(tag)
                if selectedTag == tag { selectedTag = nil }
                await fetchData()
            }
        }
        tagToDelete = nil
        haptic.trigger(.success)
    }

    /// 创建新标签并自动设为选中状态
    func performAddTag() {
        let trimmed = addTagName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        
        Task {
            store.addNewTag(trimmed)
            await fetchData()
            // 体验优化：若新创建的标签尚未被任何页面使用，将其作为空闲预设插入内存列表，供用户选中并关联页面
            if !self.tags.contains(where: { $0.tag == trimmed }) {
                self.tags.append((tag: trimmed, count: 0))
                self.tags.sort { $0.tag < $1.tag }
            }
            self.selectedTag = trimmed
        }
        
        addTagName = ""
        showAddTagDialog = false
        haptic.trigger(.success)
    }
    
    /// 批量删除
    func performBulkDelete() {
        guard !selectedTagsForBulk.isEmpty else { return }
        Task {
            await store.bulkDeleteTags(Array(selectedTagsForBulk))
            selectedTagsForBulk.removeAll()
            await fetchData()
        }
        isEditMode = false
        haptic.trigger(.success)
    }
    
    /// 切换Selection
    /// - Parameter tag: tag
    func toggleSelection(_ tag: String) {
        if selectedTagsForBulk.contains(tag) {
            selectedTagsForBulk.remove(tag)
        } else {
            selectedTagsForBulk.insert(tag)
        }
        haptic.trigger(.selection)
    }
}
