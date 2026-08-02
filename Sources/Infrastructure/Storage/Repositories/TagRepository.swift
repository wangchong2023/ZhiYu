//
//  TagRepository.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/29.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：属于 Repositories 模块，负责标签数据的持久化与迁移。
//
import Foundation
import UFPStorage

/// 标签数据仓储
public struct TagRepository: Sendable {
    
    /// 迁移历史标签数据
    /// 从页面 JSON 中提取标签，并存入独立表与建立关联
    public static func migrateLegacyTags(in db: Database) throws {
        let rows = try Row.fetchAll(db, sql: "SELECT \(KnowledgePage.Columns.id.rawValue)," + " \(KnowledgePage.Columns.tags.rawValue)" + " FROM \(KnowledgePage.databaseTableName)")
        for row in rows {
            let pageID: Data = row[KnowledgePage.Columns.id.rawValue]
            let tagsJSON: String? = row[KnowledgePage.Columns.tags.rawValue]
            if let data = tagsJSON?.data(using: .utf8),
               let tags = try? JSONDecoder().decode([String].self, from: data) {
                 for tagName in tags {
                     // 建立基础标签记录 (如存在则忽略)
                     try db.execute(sql: "INSERT OR" + " IGNORE INTO" + " \(TagRecord.databaseTableName)" + " (\(TagRecord.CodingKeys.id.rawValue)," + " \(TagRecord.CodingKeys.name.rawValue)," + " \(TagRecord.CodingKeys.createdAt.rawValue))" + " VALUES (?," + " ?, ?)", arguments: [tagName, tagName, Date()])
                     // 绑定多对多关联
                     try db.execute(sql: "INSERT OR" + " IGNORE INTO" + " \(PageTagRecord.databaseTableName)" + " (\(PageTagRecord.CodingKeys.pageID.rawValue)," + " \(PageTagRecord.CodingKeys.tagID.rawValue))" + " VALUES (?," + " ?)", arguments: [pageID, tagName])
                 }
            }
        }
    }
}
