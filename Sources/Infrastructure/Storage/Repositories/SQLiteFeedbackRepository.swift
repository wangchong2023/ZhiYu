//
//  SQLiteFeedbackRepository.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：FeedbackEntry 的 SQLite 仓储实现

import Foundation
import UFPStorage

final class SQLiteFeedbackRepository: FeedbackRepository, DatabaseWriterProvider, @unchecked Sendable {

    func save(_ entry: FeedbackEntry) async throws {
        let writer = await dbWriter
        try await writer.write { db in
            var mutatedEntry = entry
            try mutatedEntry.save(db)
        }
    }

    func fetchAll(limit: Int) async throws -> [FeedbackEntry] {
        let writer = await dbWriter
        return try await writer.read { db in
            try FeedbackEntry
                .order(FeedbackEntry.CodingKeys.createdAt.desc)
                .limit(limit)
                .fetchAll(db)
        }
    }

    func fetchByID(id: String) async throws -> FeedbackEntry? {
        let writer = await dbWriter
        return try await writer.read { db in
            try FeedbackEntry.fetchOne(db, key: id)
        }
    }

    func updateStatus(id: String, status: FeedbackStatus) async throws {
        let writer = await dbWriter
        try await writer.write { db in
            try db.execute(
                sql: "UPDATE \(FeedbackEntry.databaseTableName) SET status = ? WHERE id = ?",
                arguments: [status.rawValue, id]
            )
        }
    }
}
