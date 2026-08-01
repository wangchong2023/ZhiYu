//
//  CloudKitSyncIntegrationTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：模拟真实网络震荡、断网、重连，以及 Device A/B 同步冲突下的 LWW 时序集成测试。
//

#if ICLOUD_ENABLED
import XCTest
@testable import ZhiYu

/// 模拟云存储服务驱动器以验证网络断连/重连与冲突合并 (REQ-SYNC-02)
final class MockCloudStorageProvider: CloudStorageProvider, @unchecked Sendable {
    var isAvailable = true
    var isNetworkConnected = true
    
    // 模拟云端存储的数据
    var cloudPages: [KnowledgePage] = []
    var cloudLogs: [LogEntry] = []
    var cloudLastModified = Date()
    
    func checkAvailability() async -> Bool {
        return isAvailable
    }
    
    func push(pages: [KnowledgePage], logs: [LogEntry]) async throws {
        guard isNetworkConnected else {
            throw NSError(domain: "NSURLErrorDomain", code: -1009, userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."])
        }
        self.cloudPages = pages
        self.cloudLogs = logs
        self.cloudLastModified = Date()
    }
    
    func pull() async throws -> CloudSnapshot {
        guard isNetworkConnected else {
            throw NSError(domain: "NSURLErrorDomain", code: -1009, userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."])
        }
        return CloudSnapshot(pages: cloudPages, logs: cloudLogs, lastModified: cloudLastModified)
    }
    
    func subscribeToChanges() async throws {}
}

@MainActor
final class CloudKitSyncIntegrationTests: XCTestCase {
    
    private var mockProvider: MockCloudStorageProvider!
    private var syncService: iCloudSyncService!
    
    override func setUp() async throws {
        try await super.setUp()
        mockProvider = MockCloudStorageProvider()
        syncService = iCloudSyncService(provider: mockProvider)
    }
    
    override func tearDown() async throws {
        syncService = nil
        mockProvider = nil
        try await super.tearDown()
    }
    
    /// REQ-SYNC-02: 校验在断网/连网冲突合并时序下，LWW 解决策略对同一条卡片物理碰撞与重名防护的正确性
    func testNetworkDisconnectionAndLWWConflictResolution() async throws {
        // 准备初始数据：云端有一篇旧文档
        let pageID = UUID()
        let oldDate = Date().addingTimeInterval(-3600) // 1小时前
        let cloudPage = KnowledgePage(
            id: pageID,
            title: "RAG原理",
            pageType: .concept,
            content: "旧的云端RAG描述",
            createdAt: oldDate,
            updatedAt: oldDate
        )
        
        mockProvider.cloudPages = [cloudPage]
        mockProvider.cloudLastModified = oldDate
        
        // 1. 模拟断网环境
        mockProvider.isNetworkConnected = false
        
        // 本地用户在断网下修改了这篇文档（使其更新时间更晚）
        let localUpdatedDate = Date()
        let localPage = KnowledgePage(
            id: pageID,
            title: "RAG原理",
            pageType: .concept,
            content: "本地在断网下更新的最新RAG描述（更优解）",
            createdAt: oldDate,
            updatedAt: localUpdatedDate
        )
        
        // 尝试执行同步，应当抛出网络错误并进入错误状态
        do {
            _ = try await syncService.sync(localPages: [localPage], localLogs: [])
            XCTFail("断网时同步应该抛出错误")
        } catch {
            // 验证同步服务状态为 error
            if case .error(let msg) = syncService.syncStatus {
                XCTAssertTrue(msg.contains("offline") || msg.contains("connection"))
            } else {
                XCTFail("同步服务状态应为 error")
            }
        }
        
        // 2. 模拟网络恢复
        mockProvider.isNetworkConnected = true
        
        // 执行同步，由于本地更新时刻（localUpdatedDate）晚于云端（oldDate），
        // 根据 LWW (Last-Writer-Wins) 规则，合并后本地修改应当保留并推送到云端。
        let (mergedPages, _) = try await syncService.sync(localPages: [localPage], localLogs: [])
        
        // 验证合并输出与云端数据
        XCTAssertEqual(mergedPages.count, 1)
        XCTAssertEqual(mergedPages.first?.content, "本地在断网下更新的最新RAG描述（更优解）", "LWW 冲突解决器应当保留时间戳更新的本地修改")
        
        let finalCloudData = try await mockProvider.pull()
        XCTAssertEqual(finalCloudData.pages.first?.content, "本地在断网下更新的最新RAG描述（更优解）", "最终黄金数据集应当已被推送到云端")
    }
    
    /// 验证 LWW 冲突解决对于 UUID 不同但 Title 相同的重名卡片，触发索引防护，跳过追加以保证数据库健康
    func testDuplicateTitleProtectionDuringSync() async throws {
        // 云端有 UUID A，标题为 "Swift"
        let pageIDA = UUID()
        let cloudPage = KnowledgePage(
            id: pageIDA,
            title: "Swift",
            pageType: .concept,
            content: "云端关于Swift的内容"
        )
        mockProvider.cloudPages = [cloudPage]
        mockProvider.cloudLastModified = Date()
        
        // 本地在不知情的情况下创建了 UUID B，但标题也叫 "Swift"
        let pageIDB = UUID()
        let localPage = KnowledgePage(
            id: pageIDB,
            title: "Swift",
            pageType: .concept,
            content: "本地关于Swift的冲突内容"
        )
        
        // 按照重名防护规则，不应追加重复标题的页面
        XCTAssertEqual(mergedPages.count, 1, "重名卡片应触发防护，跳过追加以保护数据库索引")
        XCTAssertEqual(mergedPages.first?.id, pageIDB, "应保留本地先入为主的页面结构")
    }

    /// 验证当云端时间戳晚于本地（Cloud > Local）时，逆向 LWW 规则能够精准拉取云端覆盖并更新本地状态
    func testCloudLWWConflictResolution_cloudWins() async throws {
        let pageID = UUID()
        let oldLocalDate = Date().addingTimeInterval(-7200) // 2小时前
        let newCloudDate = Date().addingTimeInterval(-3600) // 1小时前

        let localPage = KnowledgePage(
            id: pageID,
            title: "架构设计",
            content: "本地旧架构描述",
            updatedAt: oldLocalDate
        )

        let cloudPage = KnowledgePage(
            id: pageID,
            title: "架构设计",
            content: "云端最新的重构架构描述",
            updatedAt: newCloudDate
        )

        mockProvider.cloudPages = [cloudPage]
        mockProvider.cloudLastModified = newCloudDate
        mockProvider.isNetworkConnected = true

        let (mergedPages, _) = try await syncService.sync(localPages: [localPage], localLogs: [])

        XCTAssertEqual(mergedPages.count, 1, "合并后结果应维持单条目标页面")
        XCTAssertEqual(mergedPages.first?.content, "云端最新的重构架构描述", "当云端时间戳更晚时，LWW 机制应精准使用云端最新覆盖")
    }
}
#endif
