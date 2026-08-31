//
//  LWWSyncConflictResolver.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：实现基于 LWW (Last-Writer-Wins) 策略的冲突合并算法。
//

import Foundation

/// 贯彻 智宇 数据最终一致性规约的冲突解决器。
public struct LWWSyncConflictResolver: SyncConflictResolver {
    
    public init() {}
    
    /// 页面列表的 LWW 合并实现。
    /// 规则：
    /// 1. 物理对撞：UUID 相同，比较 updatedAt，取较新者。
    /// 2. 重名防止：UUID 不同但 Title 相同，跳过追加以保护数据库索引。
    /// 3. 无冲突：直接追加。
    public func mergePages(local: [KnowledgePage], remote: [KnowledgePage]) -> [KnowledgePage] {
        var merged = local

        for remotePage in remote {
            if let localIndex = merged.firstIndex(where: { $0.id == remotePage.id }) {
                // 1. 物理对撞：UUID 一致，取最近更新版本
                let localPage = merged[localIndex]
                if remotePage.updatedAt >= localPage.updatedAt {
                    merged[localIndex] = remotePage
                }
            } else if !merged.contains(where: { $0.title == remotePage.title }) {
                // 2. 远程新增：UUID 与 Title 均无冲突，安全追加
                merged.append(remotePage)
            }
        }

        return merged
    }
    
    /// 审计日志的 LWW 去重合并实现。
    /// 规则：
    /// 1. 按 ID 去重。
    /// 2. 按产生的物理时刻降序（由新到旧）排列。
    /// 3. 严格限制物理容量上限（滑动窗口 200 条），超限物理驱逐旧日志。
    public func mergeLogs(local: [LogEntry], remote: [LogEntry]) -> [LogEntry] {
        var merged = local

        // 1. 追加不存在于本地的远程审计日志记录，按 id 进行去重判断
        for remoteLog in remote where !merged.contains(where: { $0.id == remoteLog.id }) {
                merged.append(remoteLog)
        }

        // 2. 将去重融合后的审计日志按产生时间戳进行降序（由新到旧）排列
        merged.sort { $0.timestamp > $1.timestamp }

        // 3. 触发容量削减阀值限制，强行裁剪保留最近条数
        let limit = SyncConstants.auditLogWindowLimit
        if merged.count > limit {
            merged = Array(merged.prefix(limit))
        }

        return merged
    }
}
