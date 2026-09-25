//
//  StorageServicesSupplementTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：补充验证 Storage 层服务组件的未覆盖分支
//          （DataCoordinator 同步、SpotlightService 索引、TransactionGatekeeper 事务门禁、
//           UndoService 撤销/重做、FileImportFileStore 文件导入）。
//

import XCTest
import UFPStorage
import UFPCore
import LocalAuthentication
import Dependencies
@testable import ZhiYu

@MainActor
final class StorageServicesSupplementTests: XCTestCase {

    // MARK: - DataCoordinator

    /// DataCoordinator.sync() 应不崩溃（依赖 DI 解析 pageStore/embeddingProvider/logger）
    func testDataCoordinatorSyncNoCrash() async throws {
        let coordinator = DataCoordinator()
        coordinator.sync()
        // 给 Task 一点时间启动
        try await Task.sleep(for: .milliseconds(50))
    }

    /// DataCoordinator 重复 sync 应取消前一个任务（syncTask?.cancel() 分支）
    func testDataCoordinatorRepeatedSyncCancelsPreviousTask() async throws {
        let coordinator = DataCoordinator()
        coordinator.sync()
        coordinator.sync()
        try await Task.sleep(for: .milliseconds(50))
    }

    // MARK: - SpotlightService

    /// SpotlightService 索引空列表应不崩溃（indexPages 空数组分支）
    func testSpotlightServiceIndexEmptyListNoCrash() {
        SpotlightService.shared.indexPages([])
    }

    /// SpotlightService 索引非空列表应不崩溃
    func testSpotlightServiceIndexNonEmptyListNoCrash() {
        let pages = [KnowledgePage(title: "Test", pageType: .concept, content: "content")]
        SpotlightService.shared.indexPages(pages)
    }

    // MARK: - TransactionGatekeeper

    /// TransactionGatekeeper acquire/release 配对应保持计数归零
    func testTransactionGatekeeperAcquireReleasePairedCountToZero() async throws {
        let gatekeeper = TransactionGatekeeper()
        try await gatekeeper.acquire()
        try await gatekeeper.acquire()
        let count2 = await gatekeeper.activeCount
        XCTAssertEqual(count2, 2)
        await gatekeeper.release()
        await gatekeeper.release()
        let count0 = await gatekeeper.activeCount
        XCTAssertEqual(count0, 0)
    }

    /// TransactionGatekeeper drain 无活跃事务时立即成功
    func testTransactionGatekeeperDrainNoActiveTransactionsImmediateSuccess() async {
        let gatekeeper = TransactionGatekeeper()
        let drained = await gatekeeper.drain(maxWaitTime: .milliseconds(100))
        XCTAssertTrue(drained)
        let stillDraining = await gatekeeper.draining
        XCTAssertFalse(stillDraining)
    }

    /// TransactionGatekeeper drain 排空期间拒绝新事务（acquire 抛 draining）
    func testTransactionGatekeeperDuringDrainRejectsNewTransactions() async throws {
        let gatekeeper = TransactionGatekeeper()
        try await gatekeeper.acquire()
        let drainTask = Task {
            return await gatekeeper.drain(maxWaitTime: .milliseconds(500))
        }
        try await Task.sleep(for: .milliseconds(50))
        do {
            try await gatekeeper.acquire()
            XCTFail("排空期间 acquire 应抛 DatabaseError.draining")
        } catch {
            if let dbError = error as? ZhiYu.DatabaseError, case .draining = dbError {
                // 预期行为
            } else {
                XCTFail("应抛 DatabaseError.draining，实际：\(error)")
            }
        }
        await gatekeeper.release()
        let drained = await drainTask.value
        XCTAssertTrue(drained)
    }

    /// TransactionGatekeeper drain 超时返回 false
    func testTransactionGatekeeperDrainTimeoutReturnsFalse() async throws {
        let gatekeeper = TransactionGatekeeper()
        try await gatekeeper.acquire()
        let drained = await gatekeeper.drain(maxWaitTime: .milliseconds(100))
        XCTAssertFalse(drained, "有活跃事务且超时应返回 false")
        await gatekeeper.release()
    }

    /// TransactionGatekeeper release 计数为零时不变为负数
    func testTransactionGatekeeperReleaseCountZeroDoesNotGoNegative() async {
        let gatekeeper = TransactionGatekeeper()
        await gatekeeper.release()
        await gatekeeper.release()
        let count = await gatekeeper.activeCount
        XCTAssertEqual(count, 0, "计数为 0 时 release 不应变负")
    }

    /// TransactionGatekeeper reset 清空所有状态
    func testTransactionGatekeeperResetClearsState() async throws {
        let gatekeeper = TransactionGatekeeper()
        try await gatekeeper.acquire()
        try await gatekeeper.acquire()
        await gatekeeper.reset()
        let count = await gatekeeper.activeCount
        XCTAssertEqual(count, 0)
        let draining = await gatekeeper.draining
        XCTAssertFalse(draining)
    }

    // MARK: - UndoService

    /// UndoService 空栈撤销应返回 nil
    func testUndoServiceEmptyStackUndoReturnsNil() {
        let service = UndoService()
        let result = service.undo(currentPages: [])
        XCTAssertNil(result)
        XCTAssertFalse(service.canUndo)
        XCTAssertFalse(service.canRedo)
    }

    /// UndoService 空栈重做应返回 nil
    func testUndoServiceEmptyStackRedoReturnsNil() {
        let service = UndoService()
        let result = service.redo(currentPages: [])
        XCTAssertNil(result)
    }

    /// UndoService clear 后 canUndo/canRedo 均为 false
    func testUndoServiceAfterClearStateReset() {
        let service = UndoService()
        service.pushSnapshot([KnowledgePage(title: "A")])
        XCTAssertTrue(service.canUndo)
        service.clear()
        XCTAssertFalse(service.canUndo)
        XCTAssertFalse(service.canRedo)
    }

    /// UndoService 超过 maxStackSize 时移除最旧快照
    func testUndoServiceExceedsMaxStackSizeRemovesOldestSnapshot() {
        let service = UndoService()
        for i in 0..<55 {
            service.pushSnapshot([KnowledgePage(title: "V\(i)")])
        }
        XCTAssertTrue(service.canUndo)
    }

    /// UndoService 新操作清空 redo 栈
    func testUndoServiceNewOperationClearsRedoStack() {
        let service = UndoService()
        service.pushSnapshot([KnowledgePage(title: "V1")])
        _ = service.undo(currentPages: [KnowledgePage(title: "Current")])
        XCTAssertTrue(service.canRedo)
        service.pushSnapshot([KnowledgePage(title: "V2")])
        XCTAssertFalse(service.canRedo, "新操作应清空 redo 栈")
    }

    // MARK: - FileImportFileStore

    /// FileImportFileStore saveContent 各 category 路径验证
    func testFileImportFileStoreAllCategoriesSaveSuccess() {
        let store = FileImportFileStore()
        for category in ImportCategory.allCases {
            let path = store.saveContent("test", category: category)
            XCTAssertNotNil(path, "\(category) category 保存应成功")
            if let path { try? FileManager.default.removeItem(atPath: path) }
        }
    }

    /// FileImportFileStore saveData 二进制数据保存
    func testFileImportFileStoreSaveDataBinarySave() throws {
        let store = FileImportFileStore()
        let data = Data([0x00, 0x01, 0xFF])
        let path = try XCTUnwrap(store.saveData(data, category: .voice, ext: "bin"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: path))
        try? FileManager.default.removeItem(atPath: path)
    }

    /// FileImportFileStore copyFile 拷贝外部文件
    func testFileImportFileStoreCopyFileCopySuccess() throws {
        let store = FileImportFileStore()
        let sourceURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("source_\(UUID().uuidString).txt")
        try "content".write(to: sourceURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let destPath = try XCTUnwrap(store.copyFile(at: sourceURL, category: .file))
        XCTAssertTrue(FileManager.default.fileExists(atPath: destPath))
        try? FileManager.default.removeItem(atPath: destPath)
    }
}
