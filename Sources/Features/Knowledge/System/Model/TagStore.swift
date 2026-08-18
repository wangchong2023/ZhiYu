//
//  TagStore.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L2] 业务功能层
//  核心职责：数据模型与状态管理，定义数据结构与 @Observable 状态。
//
import Foundation
import UFPCore
import Observation

/// 标签领域状态中心 (L2-Store)
@Observable
@MainActor
public final class TagStore {
    
    // ── 核心依赖 ──
    @ObservationIgnored @Inject private var store: any AnyPageStore  // inject_exempt: DI 就绪后由 AppEnvironment 实例化
    @ObservationIgnored @Inject private var logger: any LoggerProtocol  // inject_exempt: DI 就绪后由 AppEnvironment 实例化

    public init() {}

    // MARK: - 状态访问

    /// 获取所有去重后的标签及其频率 (基于外部页面镜像)
    public func getAllTags(from pages: [KnowledgePage]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for page in pages {
            for tag in page.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
    }
    
    /// 获取排序后的标签列表
    public func sortedTags(from pages: [KnowledgePage]) -> [String] {
        var allTags = Set<String>()
        for page in pages {
            allTags.formUnion(page.tags)
        }
        return Array(allTags).sorted()
    }

    // MARK: - 业务操作

    /// 在全库范围内重命名标签
    public func renameTag(old: String, to new: String) async {
        await store.renameTag(old, to: new)
        logger.addLog(action: .update, target: old, details: "Renamed tag" + " to \(new)", module: "TagStore")
    }

    /// 物理删除特定标签引用
    public func deleteTag(_ tag: String) async {
        await store.deleteTag(tag)
        logger.addLog(action: .delete, target: tag, details: "Tag removed from all pages", module: "TagStore")
    }

    /// 批量删除标签
    public func bulkDeleteTags(_ tags: [String]) async {
        for tag in tags {
            await store.deleteTag(tag)
        }
        logger.addLog(action: .delete, target: "Multiple Tags", details: "Deleted \(tags.count) tags", module: "TagStore")
    }

    /// 注册新标签 (用于预设)
    public func addNewTag(_ tag: String) {
        logger.addLog(action: .update, target: tag, details: "New tag registered", module: "TagStore")
    }
}

// MARK: - DependencyKey
import Dependencies

/// TagStore 依赖注入键
@MainActor
public enum TagStoreKey: DependencyKey {
    @MainActor
    public static var liveValue: TagStore { ServiceContainer.shared.resolve(TagStore.self) }

    @MainActor
    public static var testValue: TagStore {
        ServiceContainer.shared.resolveOptional(TagStore.self) ?? TagStore()
    }
}

extension DependencyValues {
    @MainActor
    public var tagStore: TagStore {
        get { self[TagStoreKey.self] }
        set { self[TagStoreKey.self] = newValue }
    }
}
