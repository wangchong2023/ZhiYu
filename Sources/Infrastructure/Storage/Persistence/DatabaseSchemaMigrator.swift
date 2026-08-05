//
//  DatabaseSchemaMigrator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：提供专属笔记本与全局共享库的架构升级与迁移逻辑（抽取自 DatabaseManager，改用 Model 类型安全常量）。
//

import Foundation
import UFPStorage

extension DatabaseManager {
    
    // MARK: - 专属笔记本库迁移方案 (DatabaseMigrator)
    
    /// 专属笔记本数据库对应的渐进式架构迁移器。
    var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        // DEBUG 模式下也不抹除——schema 变更统一通过增量迁移处理
        // (eraseDatabaseOnSchemaChange=true 会导致每次切库数据全部丢失)

        // V1: 初始工业化架构 - 全表审计标准化
        migrator.registerMigration("v1_initial_schema") { db in
            // 1. 核心知识页面主表
            try db.create(table: KnowledgePage.databaseTableName) { t in
                t.column(KnowledgePage.Columns.id.rawValue, .blob).primaryKey()
                t.column(KnowledgePage.Columns.title.rawValue, .text).notNull().unique()
                t.column(KnowledgePage.Columns.pageType.rawValue, .text).notNull().indexed()
                t.column(KnowledgePage.Columns.content.rawValue, .text).notNull()
                t.column(KnowledgePage.Columns.aliases.rawValue, .text) // JSON 字符串数组
                t.column(KnowledgePage.Columns.tags.rawValue, .text)    // JSON 字符串数组
                t.column(KnowledgePage.Columns.status.rawValue, .text).notNull().defaults(to: "active")
                t.column(KnowledgePage.Columns.confidence.rawValue, .text).notNull().defaults(to: "medium")
                t.column(KnowledgePage.Columns.sources.rawValue, .text) // JSON 引用数据
                t.column(KnowledgePage.Columns.relatedPageIDs.rawValue, .text) // JSON 关联的 UUID 数组
                t.column(KnowledgePage.Columns.isPinned.rawValue, .boolean).notNull().defaults(to: false)
                t.column(KnowledgePage.Columns.contentHash.rawValue, .text)
                t.column(KnowledgePage.Columns.customIcon.rawValue, .text)
                t.column(KnowledgePage.Columns.sourceURL.rawValue, .text)
                t.column(KnowledgePage.Columns.rawTextSnippet.rawValue, .text)
                t.column(KnowledgePage.Columns.fileSize.rawValue, .integer)
                t.column(KnowledgePage.Columns.sourceType.rawValue, .text)
                t.column(KnowledgePage.Columns.lamportTimestamp.rawValue, .integer).notNull().defaults(to: 0)
                t.column(KnowledgePage.Columns.createdAt.rawValue, .datetime).notNull().defaults(to: Date())
                t.column(KnowledgePage.Columns.updatedAt.rawValue, .datetime).notNull().defaults(to: Date())
            }

            // 2. 知识图谱双向链接映射表 (物理 ID 级强关联)
            try db.create(table: PageLink.databaseTableName) { t in
                t.column(PageLink.Columns.sourceID.name, .blob).notNull().references(KnowledgePage.databaseTableName, column: KnowledgePage.Columns.id.rawValue, onDelete: .cascade)
                t.column(PageLink.Columns.targetID.name, .blob).notNull().references(KnowledgePage.databaseTableName, column: KnowledgePage.Columns.id.rawValue, onDelete: .cascade).indexed()
                t.column(PageLink.Columns.context.name, .text)
                t.column(PageLink.Columns.createdAt.name, .datetime).notNull().defaults(to: Date())
                t.primaryKey([PageLink.Columns.sourceID.name, PageLink.Columns.targetID.name])
            }

            // 3. 语义块切片表 (RAG 核心承载)
            try db.create(table: PageChunk.databaseTableName) { t in
                t.column(PageChunk.Columns.id.name, .text).primaryKey()
                t.column(PageChunk.Columns.pageID.name, .blob).notNull().references(KnowledgePage.databaseTableName, column: KnowledgePage.Columns.id.rawValue, onDelete: .cascade)
                t.column(PageChunk.Columns.parentID.name, .text).references(PageChunk.databaseTableName, column: PageChunk.Columns.id.name, onDelete: .cascade)
                t.column(PageChunk.Columns.chunkType.name, .text).notNull()
                t.column(PageChunk.Columns.content.name, .text).notNull()
                t.column(PageChunk.Columns.anchorPath.name, .text) // 页面内具体语义锚点 Markdown Header 路径
                t.column(PageChunk.Columns.index.name, .integer).notNull()
                t.column(PageChunk.Columns.embedding.name, .blob)
                t.column(PageChunk.Columns.startIndex.name, .integer)
                t.column(PageChunk.Columns.createdAt.name, .datetime).notNull().defaults(to: Date())
                t.column(PageChunk.Columns.updatedAt.name, .datetime).notNull().defaults(to: Date())
            }

            // 4. 页面层级高维稠密向量映射表
            try db.create(table: PageEmbedding.databaseTableName) { t in
                t.column(PageEmbedding.Columns.id.name, .blob).primaryKey().references(KnowledgePage.databaseTableName, column: KnowledgePage.Columns.id.rawValue, onDelete: .cascade)
                t.column(PageEmbedding.Columns.vector.name, .blob).notNull()
                t.column(PageEmbedding.Columns.modelName.name, .text).notNull()
                t.column(PageEmbedding.Columns.createdAt.name, .datetime).notNull().defaults(to: Date())
                t.column(PageEmbedding.Columns.updatedAt.name, .datetime).notNull().defaults(to: Date())
            }

            // 5. 合规治理与 AI 资源开销审计表
            try db.create(table: TokenUsage.databaseTableName) { t in
                t.autoIncrementedPrimaryKey(TokenUsage.Columns.id.name)
                t.column(TokenUsage.Columns.model.name, .text).notNull()
                t.column(TokenUsage.Columns.promptTokens.name, .integer).notNull()
                t.column(TokenUsage.Columns.completionTokens.name, .integer).notNull()
                t.column(TokenUsage.Columns.totalTokens.name, .integer).notNull()
                t.column(TokenUsage.Columns.createdAt.name, .datetime).notNull().defaults(to: Date())
            }

            try db.create(table: LLMCallLog.databaseTableName) { t in
                t.autoIncrementedPrimaryKey(LLMCallLog.Columns.id.name)
                t.column(LLMCallLog.Columns.model.name, .text).notNull()
                t.column(LLMCallLog.Columns.promptTokens.name, .integer).notNull()
                t.column(LLMCallLog.Columns.completionTokens.name, .integer).notNull()
                t.column(LLMCallLog.Columns.latencyMS.name, .integer).notNull()
                t.column(LLMCallLog.Columns.status.name, .text).notNull()
                t.column(LLMCallLog.Columns.createdAt.name, .datetime).notNull().defaults(to: Date())
            }

            try db.create(table: RAGEvaluation.databaseTableName) { t in
                t.autoIncrementedPrimaryKey(RAGEvaluation.Columns.id.name)
                t.column(RAGEvaluation.Columns.query.name, .text).notNull()
                t.column(RAGEvaluation.Columns.answer.name, .text).notNull()
                t.column(RAGEvaluation.Columns.faithfulness.name, .double).notNull()
                t.column(RAGEvaluation.Columns.relevance.name, .double).notNull()
                t.column(RAGEvaluation.Columns.precision.name, .double).notNull()
                t.column(RAGEvaluation.Columns.evaluatorModel.name, .text).notNull()
                t.column(RAGEvaluation.Columns.createdAt.name, .datetime).notNull().defaults(to: Date())
            }

            // 6. 自动化物理审计时间戳更新触发器
            try db.execute(sql: """
                CREATE TRIGGER trigger_update_pages_timestamp
                AFTER UPDATE ON \(KnowledgePage.databaseTableName)
                BEGIN
                    UPDATE \(KnowledgePage.databaseTableName) SET \(KnowledgePage.Columns.updatedAt.rawValue) = CURRENT_TIMESTAMP WHERE \(KnowledgePage.Columns.id.rawValue) = OLD.\(KnowledgePage.Columns.id.rawValue);
                END;
            """)
        }

        // V2: SQLite 内嵌混合倒排高性能检索 (FTS5 搜索引擎)
        migrator.registerMigration("v2_fts_initial") { db in
            try db.execute(sql: """
                CREATE VIRTUAL TABLE \(KnowledgePageFTS.databaseTableName) USING fts5(
                    \(KnowledgePageFTS.Columns.id.name) UNINDEXED, \(KnowledgePageFTS.Columns.title.name), \(KnowledgePageFTS.Columns.content.name), \(KnowledgePageFTS.Columns.tags.name), \(KnowledgePageFTS.Columns.aliases.name),
                    content='\(KnowledgePage.databaseTableName)'
                )
            """)
            try db.execute(sql: """
                CREATE TRIGGER pages_ai AFTER INSERT ON \(KnowledgePage.databaseTableName) BEGIN
                    INSERT INTO \(KnowledgePageFTS.databaseTableName)(\(KnowledgePageFTS.Columns.id.name), \(KnowledgePageFTS.Columns.title.name), \(KnowledgePageFTS.Columns.content.name), \(KnowledgePageFTS.Columns.tags.name), \(KnowledgePageFTS.Columns.aliases.name))
                    VALUES (new.\(KnowledgePage.Columns.id.rawValue), new.\(KnowledgePage.Columns.title.rawValue), new.\(KnowledgePage.Columns.content.rawValue), new.\(KnowledgePage.Columns.tags.rawValue), new.\(KnowledgePage.Columns.aliases.rawValue));
                END;
            """)
            try db.execute(sql: """
                CREATE TRIGGER pages_ad AFTER DELETE ON \(KnowledgePage.databaseTableName) BEGIN
                    INSERT INTO \(KnowledgePageFTS.databaseTableName)(\(KnowledgePageFTS.databaseTableName), \(KnowledgePageFTS.Columns.id.name), \(KnowledgePageFTS.Columns.title.name), \(KnowledgePageFTS.Columns.content.name), \(KnowledgePageFTS.Columns.tags.name), \(KnowledgePageFTS.Columns.aliases.name))
                    VALUES ('delete', old.\(KnowledgePage.Columns.id.rawValue), old.\(KnowledgePage.Columns.title.rawValue), old.\(KnowledgePage.Columns.content.rawValue), old.\(KnowledgePage.Columns.tags.rawValue), old.\(KnowledgePage.Columns.aliases.rawValue));
                END;
            """)
            try db.execute(sql: """
                CREATE TRIGGER pages_au AFTER UPDATE ON \(KnowledgePage.databaseTableName) BEGIN
                    INSERT INTO \(KnowledgePageFTS.databaseTableName)(\(KnowledgePageFTS.databaseTableName), \(KnowledgePageFTS.Columns.id.name), \(KnowledgePageFTS.Columns.title.name), \(KnowledgePageFTS.Columns.content.name), \(KnowledgePageFTS.Columns.tags.name), \(KnowledgePageFTS.Columns.aliases.name))
                    VALUES ('delete', old.\(KnowledgePage.Columns.id.rawValue), old.\(KnowledgePage.Columns.title.rawValue), old.\(KnowledgePage.Columns.content.rawValue), old.\(KnowledgePage.Columns.tags.rawValue), old.\(KnowledgePage.Columns.aliases.rawValue));
                    INSERT INTO \(KnowledgePageFTS.databaseTableName)(\(KnowledgePageFTS.Columns.id.name), \(KnowledgePageFTS.Columns.title.name), \(KnowledgePageFTS.Columns.content.name), \(KnowledgePageFTS.Columns.tags.name), \(KnowledgePageFTS.Columns.aliases.name))
                    VALUES (new.\(KnowledgePage.Columns.id.rawValue), new.\(KnowledgePage.Columns.title.rawValue), new.\(KnowledgePage.Columns.content.rawValue), new.\(KnowledgePage.Columns.tags.rawValue), new.\(KnowledgePage.Columns.aliases.rawValue));
                END;
            """)
        }

        // V3: 标签存储范式化与检索性能提速 (Tags DIP 范式)
        migrator.registerMigration("v3_tag_normalization") { db in
            // 1. 创建标签字典表
            try db.create(table: TagRecord.databaseTableName) { t in
                t.column(TagRecord.CodingKeys.id.rawValue, .text).primaryKey() // 使用标签文本作为主键 ID
                t.column(TagRecord.CodingKeys.name.rawValue, .text).notNull().unique()
                t.column(TagRecord.CodingKeys.createdAt.rawValue, .datetime).notNull().defaults(to: Date())
            }

            // 2. 创建页面-标签多对多关联关联表
            try db.create(table: PageTagRecord.databaseTableName) { t in
                t.column(PageTagRecord.CodingKeys.pageID.rawValue, .blob).notNull().references(KnowledgePage.databaseTableName, column: KnowledgePage.Columns.id.rawValue, onDelete: .cascade)
                t.column(PageTagRecord.CodingKeys.tagID.rawValue, .text).notNull().references(TagRecord.databaseTableName, column: TagRecord.CodingKeys.id.rawValue, onDelete: .cascade)
                t.primaryKey([PageTagRecord.CodingKeys.pageID.rawValue, PageTagRecord.CodingKeys.tagID.rawValue])
            }

            // 3. 历史存量数据平滑迁移：从 pages.tags JSON 字符串中解离出独立 Tag 实物
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

        // V4: 增加 SRS 间隔重复算法元数据表 (@P1: 促进卡片知识内化吸收)
        migrator.registerMigration("v4_srs_metadata") { db in
            try db.create(table: SRSMetadataRecord.databaseTableName) { t in
                t.column(SRSMetadataRecord.CodingKeys.pageID.rawValue, .blob).primaryKey().references(KnowledgePage.databaseTableName, column: KnowledgePage.Columns.id.rawValue, onDelete: .cascade)
                t.column(SRSMetadataRecord.CodingKeys.easeFactor.rawValue, .double).notNull().defaults(to: AppConstants.Storage.defaultEaseFactor)
                t.column(SRSMetadataRecord.CodingKeys.repetitions.rawValue, .integer).notNull().defaults(to: 0)
                t.column(SRSMetadataRecord.CodingKeys.reviewInterval.rawValue, .integer).notNull().defaults(to: 0)
                t.column(SRSMetadataRecord.CodingKeys.nextReviewAt.rawValue, .datetime).notNull().indexed()
                t.column(SRSMetadataRecord.CodingKeys.createdAt.rawValue, .datetime).notNull().defaults(to: Date())
                t.column(SRSMetadataRecord.CodingKeys.updatedAt.rawValue, .datetime).notNull().defaults(to: Date())
            }
        }

        // V5: RAG 评估维度扩展 — 新增幻觉率与引用准确度指标 (@P2: 生成质量细粒度量化)
        migrator.registerMigration("v5_rag_hallucination_citation") { db in
            // 检查列是否存在，避免重复迁移崩溃
            let columns = try db.columns(in: RAGEvaluation.databaseTableName)
            if !columns.contains(where: { $0.name == RAGEvaluation.Columns.hallucinationRate.name }) {
                try db.alter(table: RAGEvaluation.databaseTableName) { t in
                    t.add(column: RAGEvaluation.Columns.hallucinationRate.name, .double).notNull().defaults(to: 0.0)
                }
            }
            if !columns.contains(where: { $0.name == RAGEvaluation.Columns.citationAccuracy.name }) {
                try db.alter(table: RAGEvaluation.databaseTableName) { t in
                    t.add(column: RAGEvaluation.Columns.citationAccuracy.name, .double).notNull().defaults(to: 0.0)
                }
            }
        }

        // V6: 检索质量标注体系 — 检索快照 + 相关性标注表 (@P3: Hit Rate/MRR/NDCG 数据基座)
        migrator.registerMigration("v6_retrieval_quality") { db in
            // 1. 检索快照表：记录每次评估的完整 Top-N 排序结果
            try db.create(table: RetrievalSnapshot.databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey(RetrievalSnapshot.Columns.id.name)
                t.column(RetrievalSnapshot.Columns.evaluationID.name, .integer)
                    .notNull()
                    .indexed()
                    .references(RAGEvaluation.databaseTableName, column: RAGEvaluation.Columns.id.name, onDelete: .cascade)
                t.column(RetrievalSnapshot.Columns.rank.name, .integer).notNull()
                t.column(RetrievalSnapshot.Columns.sourceID.name, .text).notNull()
                t.column(RetrievalSnapshot.Columns.pageTitle.name, .text).notNull()
                t.column(RetrievalSnapshot.Columns.snippet.name, .text).notNull()
                t.column(RetrievalSnapshot.Columns.score.name, .double).notNull()
                t.column(RetrievalSnapshot.Columns.createdAt.name, .datetime).notNull().defaults(to: Date())
            }

            // 2. 相关性标注表：LLM 自动标注 query→source 的相关性等级
            try db.create(table: RelevanceJudgment.databaseTableName, ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey(RelevanceJudgment.Columns.id.name)
                t.column(RelevanceJudgment.Columns.queryHash.name, .text).notNull().indexed()
                t.column(RelevanceJudgment.Columns.query.name, .text).notNull()
                t.column(RelevanceJudgment.Columns.sourceID.name, .text).notNull()
                t.column(RelevanceJudgment.Columns.relevanceLevel.name, .integer).notNull()
                t.column(RelevanceJudgment.Columns.judgeSource.name, .text).notNull().defaults(to: "llm-auto")
                t.column(RelevanceJudgment.Columns.evaluationID.name, .integer)
                    .references(RAGEvaluation.databaseTableName, column: RAGEvaluation.Columns.id.name, onDelete: .setNull)
                t.column(RelevanceJudgment.Columns.createdAt.name, .datetime).notNull().defaults(to: Date())
            }
        }

        // V7: 导入原始内容留存表 (@P5: 导入原始数据持久化)
        migrator.registerMigration("v7_import_records") { db in
            try db.create(table: ImportRecord.databaseTableName, ifNotExists: true) { t in
                t.column(ImportRecord.CodingKeys.id.name, .text).primaryKey()
                t.column(ImportRecord.CodingKeys.category.name, .text).notNull().indexed()
                t.column(ImportRecord.CodingKeys.title.name, .text).notNull()
                t.column(ImportRecord.CodingKeys.status.name, .text).notNull().defaults(to: "pending")
                t.column(ImportRecord.CodingKeys.rawText.name, .text)
                t.column(ImportRecord.CodingKeys.sourceURL.name, .text)
                t.column(ImportRecord.CodingKeys.filePath.name, .text)
                t.column(ImportRecord.CodingKeys.fileSize.name, .integer)
                t.column(ImportRecord.CodingKeys.pageID.name, .text)
                t.column(ImportRecord.CodingKeys.vaultID.name, .text)
                t.column(ImportRecord.CodingKeys.taskID.name, .text)
                t.column(ImportRecord.CodingKeys.createdAt.name, .datetime).notNull().defaults(to: Date())
                t.column(ImportRecord.CodingKeys.completedAt.name, .datetime)
            }
        }

        // V8: 导入记录 AI 分类标签（幂等：V7 创建表时可能已含此列）
        migrator.registerMigration("v8_import_record_tags") { db in
            let columns = try db.columns(in: ImportRecord.databaseTableName).map(\.name)
            guard !columns.contains(ImportRecord.CodingKeys.tags.name) else { return }
            try db.alter(table: ImportRecord.databaseTableName) { t in
                t.add(column: ImportRecord.CodingKeys.tags.name, .text)
            }
        }

        // V9: 用户反馈表
        migrator.registerMigration("v9_feedback_entries") { db in
            try db.create(table: FeedbackEntry.databaseTableName, ifNotExists: true) { t in
                t.column(FeedbackEntry.CodingKeys.id.name, .text).primaryKey()
                t.column(FeedbackEntry.CodingKeys.title.name, .text).notNull()
                t.column(FeedbackEntry.CodingKeys.category.name, .text).notNull().indexed()
                t.column(FeedbackEntry.CodingKeys.rating.name, .integer).notNull().defaults(to: 3)
                t.column(FeedbackEntry.CodingKeys.content.name, .text).notNull()
                t.column(FeedbackEntry.CodingKeys.appVersion.name, .text)
                t.column(FeedbackEntry.CodingKeys.osVersion.name, .text)
                t.column(FeedbackEntry.CodingKeys.deviceModel.name, .text)
                t.column(FeedbackEntry.CodingKeys.createdAt.name, .datetime).notNull().defaults(to: Date())
            }
        }

        // V10: RAG 评估新增答案正确性维度（幂等：检查列是否存在）
        migrator.registerMigration("v10_rag_answer_correctness") { db in
            let columns = try db.columns(in: RAGEvaluation.databaseTableName)
            if !columns.contains(where: { $0.name == RAGEvaluation.Columns.answerCorrectness.name }) {
                try db.alter(table: RAGEvaluation.databaseTableName) { t in
                    t.add(column: RAGEvaluation.Columns.answerCorrectness.name, .double).notNull().defaults(to: 0.0)
                }
            }
        }

        // V11: RAG 评估新增上下文充分性维度（幂等）
        migrator.registerMigration("v11_rag_context_sufficiency") { db in
            let columns = try db.columns(in: RAGEvaluation.databaseTableName)
            if !columns.contains(where: { $0.name == RAGEvaluation.Columns.contextSufficiency.name }) {
                try db.alter(table: RAGEvaluation.databaseTableName) { t in
                    t.add(column: RAGEvaluation.Columns.contextSufficiency.name, .double).notNull().defaults(to: 0.0)
                }
            }
        }

        // V13: 反馈条目新增处理状态列
        migrator.registerMigration("v13_feedback_status") { db in
            let columns = try db.columns(in: FeedbackEntry.databaseTableName)
            if !columns.contains(where: { $0.name == FeedbackEntry.CodingKeys.status.name }) {
                try db.alter(table: FeedbackEntry.databaseTableName) { t in
                    t.add(column: FeedbackEntry.CodingKeys.status.name, .text).notNull().defaults(to: FeedbackStatus.pending.rawValue)
                }
            }
        }

        // V12: RAG 评估新增用户满意度评分（幂等）
        migrator.registerMigration("v12_rag_user_rating") { db in
            let columns = try db.columns(in: RAGEvaluation.databaseTableName)
            if !columns.contains(where: { $0.name == RAGEvaluation.Columns.userRating.name }) {
                try db.alter(table: RAGEvaluation.databaseTableName) { t in
                    t.add(column: RAGEvaluation.Columns.userRating.name, .integer)
                }
            }
        }

        return migrator
    }

    // MARK: - 全局数据库迁移方案 (DatabaseMigrator)
    
    /// 全局数据库对应的架构迁移器。
    var globalMigrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        // DEBUG 模式下也不抹除——schema 变更统一通过增量迁移处理
        // (eraseDatabaseOnSchemaChange=true 会导致每次切库数据全部丢失)
        
        migrator.registerMigration("v1_global_schema") { db in
            // 1. 笔记本元数据主表：托管所有多笔记本卡片信息
            try db.create(table: VaultRecord.databaseTableName) { t in
                t.column(VaultRecord.CodingKeys.id.rawValue, .text).primaryKey() // 使用 UUID 字符串
                t.column(VaultRecord.CodingKeys.name.rawValue, .text).notNull()
                t.column(VaultRecord.CodingKeys.path.rawValue, .text).notNull()
                t.column(VaultRecord.CodingKeys.icon.rawValue, .text)
                t.column(VaultRecord.CodingKeys.pageCount.rawValue, .integer).notNull().defaults(to: 0)
                t.column(VaultRecord.CodingKeys.createdAt.rawValue, .datetime).notNull().defaults(to: Date())
                t.column(VaultRecord.CodingKeys.updatedAt.rawValue, .datetime).notNull().defaults(to: Date())
                t.column(VaultRecord.CodingKeys.lastAccessedAt.rawValue, .datetime).notNull().defaults(to: Date())
            }
            
            // 2. 物理文件防篡改 HMAC 完整性指纹表：取代原 UserDefaults 强寄生
            try db.create(table: FileSignatureRecord.databaseTableName) { t in
                t.column(FileSignatureRecord.Columns.filePath.name, .text).primaryKey()
                t.column(FileSignatureRecord.Columns.signature.name, .text).notNull()
                t.column(FileSignatureRecord.Columns.salt.name, .text).notNull()
                t.column(FileSignatureRecord.Columns.createdAt.name, .datetime).notNull().defaults(to: Date())
                t.column(FileSignatureRecord.Columns.updatedAt.name, .datetime).notNull().defaults(to: Date())
            }
            
            // 3. 全局设置表：系统级全局偏好持久化
            try db.create(table: GlobalSettingRecord.databaseTableName) { t in
                t.column(GlobalSettingRecord.CodingKeys.key.rawValue, .text).primaryKey()
                t.column(GlobalSettingRecord.CodingKeys.value.rawValue, .text).notNull()
                t.column(GlobalSettingRecord.CodingKeys.updatedAt.rawValue, .datetime).notNull().defaults(to: Date())
            }
            
            // 4. 全局安全及 Token 损耗审计日志表
            try db.create(table: AuditLogRecord.databaseTableName) { t in
                t.autoIncrementedPrimaryKey(AuditLogRecord.CodingKeys.id.rawValue)
                t.column(AuditLogRecord.CodingKeys.action.rawValue, .text).notNull()
                t.column(AuditLogRecord.CodingKeys.details.rawValue, .text)
                t.column(AuditLogRecord.CodingKeys.createdAt.rawValue, .datetime).notNull().defaults(to: Date())
            }

            // 5. 插件持久化记录表：插件元数据、安装状态及运行时统计
            try db.create(table: AppConstants.Storage.Tables.pluginRecords) { t in
                t.column(PluginRecord.Columns.id.rawValue, .text).primaryKey()
                t.column(PluginRecord.Columns.name.rawValue, .text).notNull()
                t.column(PluginRecord.Columns.version.rawValue, .text).notNull()
                t.column(PluginRecord.Columns.author.rawValue, .text).notNull()
                t.column(PluginRecord.Columns.source.rawValue, .text).notNull().defaults(to: "local")
                t.column(PluginRecord.Columns.status.rawValue, .text).notNull().defaults(to: "active")
                t.column(PluginRecord.Columns.permissionsJSON.rawValue, .text).notNull().defaults(to: "[]")
                t.column(PluginRecord.Columns.loadDuration.rawValue, .double).notNull().defaults(to: 0)
                t.column(PluginRecord.Columns.unloadDuration.rawValue, .double).notNull().defaults(to: 0)
                t.column(PluginRecord.Columns.totalExecutionTime.rawValue, .double).notNull().defaults(to: 0)
                t.column(PluginRecord.Columns.callCount.rawValue, .integer).notNull().defaults(to: 0)
                t.column(PluginRecord.Columns.installedAt.rawValue, .datetime).notNull().defaults(to: Date())
                t.column(PluginRecord.Columns.updatedAt.rawValue, .datetime).notNull().defaults(to: Date())
                t.column(PluginRecord.Columns.manifestJSON.rawValue, .text).notNull().defaults(to: "")
            }

            // 6. 插件全文检索索引表（FTS5 external content）
            try db.execute(sql: """
                CREATE VIRTUAL TABLE IF NOT EXISTS \(AppConstants.Storage.Tables.pluginRecordsFTS) USING fts5(
                    id UNINDEXED, name, author, description
                )
            """)
        }
        
        // V2: global_vaults 增加 page_count 列 (@P4: 列表页数展示)
        migrator.registerMigration("v2_global_page_count") { db in
            let columns = try db.columns(in: VaultRecord.databaseTableName)
            if !columns.contains(where: { $0.name == VaultRecord.CodingKeys.pageCount.rawValue }) {
                try db.alter(table: VaultRecord.databaseTableName) { t in
                    t.add(column: VaultRecord.CodingKeys.pageCount.rawValue, .integer).notNull().defaults(to: 0)
                }
            }
        }

        return migrator
    }
}
