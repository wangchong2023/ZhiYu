//
//  SQLiteImportRecordRepository.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/10.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：ImportRecord 的 SQLite 仓储实现

import Foundation
import UFPStorage

final class SQLiteImportRecordRepository: ImportRecordRepository, DatabaseWriterProvider, @unchecked Sendable {
    // MARK: - ImportRecordRepository

    func save(_ record: ImportRecord) async throws {
        let writer = try await dbWriter
        try await writer.write { db in
            var r = record
            try r.save(db)
        }
    }

    func fetchAll(category: String?, limit: Int) async throws -> [ImportRecord] {
        let writer = try await dbWriter
        return try await writer.read { db in
            var request = ImportRecord
                .order(ImportRecord.CodingKeys.createdAt.desc)
            if let cat = category {
                request = request.filter(ImportRecord.CodingKeys.category == cat)
            }
            return try request.limit(limit).fetchAll(db)
        }
    }

    func fetchByID(_ id: String) async throws -> ImportRecord? {
        let writer = try await dbWriter
        return try await writer.read { db in
            try ImportRecord.fetchOne(db, key: id)
        }
    }

    func updateStatus(id: String, status: String, completedAt: Date?) async throws {
        let writer = try await dbWriter
        try await writer.write { db in
            guard var record = try ImportRecord.fetchOne(db, key: id) else { return }
            record.status = status
            record.completedAt = completedAt
            try record.update(db)
        }
    }

    func updatePageID(id: String, pageID: String) async throws {
        let writer = try await dbWriter
        try await writer.write { db in
            guard var record = try ImportRecord.fetchOne(db, key: id) else { return }
            record.pageID = pageID
            try record.update(db)
        }
    }

    func fetchInProgress() async throws -> [ImportRecord] {
        let writer = try await dbWriter
        return try await writer.read { db in
            try ImportRecord
                .filter(ImportRecord.CodingKeys.status == ImportRecordStatus.processing || ImportRecord.CodingKeys.status == ImportRecordStatus.pending)
                .order(ImportRecord.CodingKeys.createdAt.desc)
                .fetchAll(db)
        }
    }

    func updateRawText(id: String, rawText: String) async throws {
        let writer = try await dbWriter
        try await writer.write { db in
            guard var record = try ImportRecord.fetchOne(db, key: id) else { return }
            record.rawText = rawText
            try record.update(db)
        }
    }

    func updateTags(id: String, tags: String) async throws {
        let writer = try await dbWriter
        try await writer.write { db in
            guard var record = try ImportRecord.fetchOne(db, key: id) else { return }
            record.tags = tags
            try record.update(db)
        }
    }

    func totalStorageSize() async throws -> Int64 {
        let records = try await fetchAll(category: nil, limit: 2000)
        var total: Int64 = 0
        for r in records {
            if r.filePath != nil, let size = r.fileSize {
                total += size
            }
            if let text = r.rawText {
                total += Int64(text.utf8.count)
            }
        }
        return total
    }
}
