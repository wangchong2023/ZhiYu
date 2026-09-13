//
//  AppSyncOrchestratorTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/13.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：对 AppSyncOrchestrator 双向云同步逻辑、自愈同步、逻辑时钟状态机转化及错误重试流程提供高保真的单元测试。
//

import XCTest
import Combine
@testable import ZhiYu

/// Mock 云存储提供商
final class MockCloudStorageProvider: CloudStorageProvider, @unchecked Sendable {
    var checkAvailabilityHandler: (() async -> Bool)?
    var pushHandler: (([KnowledgePage], [LogEntry]) async throws -> Void)?
    var pullHandler: (() async throws -> CloudSnapshot)?
    
    func checkAvailability() async -> Bool {
        return await checkAvailabilityHandler?() ?? true
    }
    
    func push(pages: [KnowledgePage], logs: [LogEntry]) async throws {
        try await pushHandler?(pages, logs)
    }
    
    func pull() async throws -> CloudSnapshot {
        if let handler = pullHandler {
            return try await handler()
        }
        throw NSError(domain: "MockCloudStorageProvider", code: -1, userInfo: [NSLocalizedDescriptionKey: "No pull handler"])
    }
    
    func subscribeToChanges() async throws {}
}

/// Mock 冲突合并解决器
final class MockSyncConflictResolver: SyncConflictResolver, @unchecked Sendable {
    var mergePagesHandler: (([KnowledgePage], [KnowledgePage]) -> [KnowledgePage])?
    var mergeLogsHandler: (([LogEntry], [LogEntry]) -> [LogEntry])?
    
    func mergePages(local: [KnowledgePage], remote: [KnowledgePage]) -> [KnowledgePage] {
        return mergePagesHandler?(local, remote) ?? local
    }
    
    func mergeLogs(local: [LogEntry], remote: [LogEntry]) -> [LogEntry] {
        return mergeLogsHandler?(local, remote) ?? local
    }
}

@MainActor
final class AppSyncOrchestratorTests: XCTestCase {
    
    private var provider: MockCloudStorageProvider!
    private var resolver: MockSyncConflictResolver!
    private var orchestrator: AppSyncOrchestrator!
    
    private var localPages: [KnowledgePage]!
    private var localLogs: [LogEntry]!
    
    override func setUp() {
        super.setUp()
        provider = MockCloudStorageProvider()
        resolver = MockSyncConflictResolver()
        orchestrator = AppSyncOrchestrator(provider: provider, resolver: resolver)
        
        // 构造基础测试数据
        localPages = [KnowledgePage(title: "Local Page A")]
        localLogs = [LogEntry(action: .create, target: "pageA")]
    }
    
    override func tearDown() {
        provider = nil
        resolver = nil
        orchestrator = nil
        localPages = nil
        localLogs = nil
        super.tearDown()
    }
    
    // MARK: - 辅助断言方法
    
    /// 由于 LogEntry 并不遵循 Equatable，使用此方法手动检验两个 LogEntry 数组的值是否一致
    private func assertLogEntriesEqual(_ actual: [LogEntry], _ expected: [LogEntry], file: StaticString = #file, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, "日志数量不一致", file: file, line: line)
        for (act, exp) in zip(actual, expected) {
            XCTAssertEqual(act.id, exp.id, "日志 ID 不一致", file: file, line: line)
            XCTAssertEqual(act.action, exp.action, "日志 action 不一致", file: file, line: line)
            XCTAssertEqual(act.target, exp.target, "日志 target 不一致", file: file, line: line)
            XCTAssertEqual(act.details, exp.details, "日志 details 不一致", file: file, line: line)
        }
    }
    
    // MARK: - 测试用例
    
    /// 测试当云端存储不可用时，同步应当安全退出并报出对应状态错误，且不改变本地数据
    func testPerformSyncWhenCloudUnavailable() async throws {
        // Arrange
        provider.checkAvailabilityHandler = { false }
        
        // Act
        let (pages, logs) = try await orchestrator.performSync(localPages: localPages, localLogs: localLogs)
        
        // Assert
        XCTAssertEqual(pages, localPages, "云端不可用时应返回原本地数据")
        assertLogEntriesEqual(logs, localLogs)
        
        // 验证状态机变迁为 error 态
        if case .error(let errMsg) = orchestrator.syncStatus {
            XCTAssertEqual(errMsg, L10n.ICloud.Status.notAvailable, "错误消息应与本地化契约一致")
        } else {
            XCTFail("同步状态应处于 error，实际为 \(orchestrator.syncStatus)")
        }
    }
    
    /// 测试云端没有快照数据时（例如首次同步，pull 抛出异常），系统自愈自动执行全量 Push 并重置 lastSyncDate
    func testPerformSyncWhenCloudIsEmpty() async throws {
        // Arrange
        var pushCalled = false
        var pushedPages: [KnowledgePage] = []
        var pushedLogs: [LogEntry] = []
        
        provider.pullHandler = {
            // 模拟云端为空抛出错误
            throw NSError(domain: "iCloud", code: 404, userInfo: nil)
        }
        provider.pushHandler = { pages, logs in
            pushCalled = true
            pushedPages = pages
            pushedLogs = logs
        }
        
        // Act
        let (pages, logs) = try await orchestrator.performSync(localPages: localPages, localLogs: localLogs)
        
        // Assert
        XCTAssertTrue(pushCalled, "当云端为空时，应自动执行 push操作")
        XCTAssertEqual(pushedPages, localPages, "推送的数据应为本地的主权数据集")
        assertLogEntriesEqual(pushedLogs, localLogs)
        XCTAssertEqual(pages, localPages)
        assertLogEntriesEqual(logs, localLogs)
        XCTAssertEqual(orchestrator.syncStatus, .synced, "同步状态应处于已同步 synced")
        XCTAssertNotNil(orchestrator.lastSyncDate, "拉取失败后，自愈推送应刷新最后同步时间")
    }
    
    /// 测试当云端数据未更新（上一次同步后云端无修改），则跳过冲突解决，维持本地不变
    func testPerformSyncWhenCloudNotUpdated() async throws {
        // Arrange
        var pushCallCount = 0

        provider.pullHandler = {
            return CloudSnapshot(pages: self.localPages, logs: self.localLogs, lastModified: Date().addingTimeInterval(-10))
        }
        provider.pushHandler = { _, _ in
            pushCallCount += 1
        }
        
        // 第一次同步：确立 lastSyncDate 状态为“现在”
        _ = try await orchestrator.performSync(localPages: localPages, localLogs: localLogs)
        XCTAssertEqual(orchestrator.syncStatus, .synced)
        
        // 重置 push 计数
        pushCallCount = 0
        
        // 修改云端快照为更早的修改时间（模拟云端没有发生新更新）
        provider.pullHandler = {
            return CloudSnapshot(pages: [KnowledgePage(title: "Cloud Page Ignore")], logs: [], lastModified: Date().addingTimeInterval(-120))
        }
        
        // Act
        let (pages, logs) = try await orchestrator.performSync(localPages: localPages, localLogs: localLogs)
        
        // Assert
        XCTAssertEqual(pages, localPages, "云端未更新时应当忽略合并，保持本地数据")
        assertLogEntriesEqual(logs, localLogs)
        XCTAssertEqual(pushCallCount, 1, "忽略合并后仍应推送以对齐两端逻辑时钟")
    }
    
    /// 测试当云端存在更新时，同步调用 ConflictResolver 并把合并后的黄金数据推送至云端
    func testPerformSyncWhenCloudHasNewerUpdate() async throws {
        // Arrange
        let remotePage = KnowledgePage(title: "Remote Page B")
        let remoteLogs = [LogEntry(action: .create, target: "pageB")]
        
        provider.pullHandler = {
            // 提供拉取修改时间为“现在”的云快照
            return CloudSnapshot(pages: [remotePage], logs: remoteLogs, lastModified: Date())
        }
        
        var pushedPages: [KnowledgePage] = []
        var pushedLogs: [LogEntry] = []
        provider.pushHandler = { pages, logs in
            pushedPages = pages
            pushedLogs = logs
        }
        
        let mergedPage = KnowledgePage(title: "Merged Page")
        resolver.mergePagesHandler = { local, remote in
            XCTAssertEqual(local, self.localPages)
            XCTAssertEqual(remote, [remotePage])
            return [mergedPage]
        }
        
        resolver.mergeLogsHandler = { local, remote in
            self.assertLogEntriesEqual(local, self.localLogs)
            self.assertLogEntriesEqual(remote, remoteLogs)
            return remote
        }
        
        // Act
        let (pages, logs) = try await orchestrator.performSync(localPages: localPages, localLogs: localLogs)
        
        // Assert
        XCTAssertEqual(pages, [mergedPage], "应返回合并后的页面列表")
        assertLogEntriesEqual(logs, remoteLogs)
        XCTAssertEqual(pushedPages, [mergedPage], "推送去云端的页面应是合并后的黄金数据")
        assertLogEntriesEqual(pushedLogs, remoteLogs)
        XCTAssertEqual(orchestrator.syncStatus, .synced, "同步状态应为 synced")
        XCTAssertNotNil(orchestrator.lastSyncDate)
    }
}
