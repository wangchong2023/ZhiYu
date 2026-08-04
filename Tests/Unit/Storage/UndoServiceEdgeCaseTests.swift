//
//  UndoServiceEdgeCaseTests.swift
//  ZhiYu
//
//  系统层级：[Shared] 测试层
//  核心职责：验证 UndoService 的栈大小限制 50、redo 后新操作清空 redoStack、
//           undo/redo 往返一致性等边界条件。
//

import XCTest
@testable import ZhiYu

final class UndoServiceEdgeTests: XCTestCase {

    var undoService: UndoService!

    override func setUp() async throws {
        try await super.setUp()
        undoService = UndoService()
    }

    override func tearDownWithError() throws {
        undoService = nil
    }

    // MARK: - 辅助方法

    private func makePages(count: Int) -> [KnowledgePage] {
        (0..<count).map { i in
            KnowledgePage(title: "Page\(i)", content: "内容\(i)")
        }
    }

    // MARK: - pushSnapshot 基本语义

    /// 验证：pushSnapshot 后 canUndo 为 true，canRedo 为 false。
    func testPushSnapshotEnablesUndo() {
        XCTAssertFalse(undoService.canUndo)
        XCTAssertFalse(undoService.canRedo)

        undoService.pushSnapshot(makePages(count: 1))

        XCTAssertTrue(undoService.canUndo, "pushSnapshot 后 canUndo 应为 true")
        XCTAssertFalse(undoService.canRedo, "pushSnapshot 后 canRedo 应为 false")
    }

    /// 验证：pushSnapshot 清空 redoStack。
    func testPushSnapshotClearsRedoStack() {
        // 先 undo 建立 redo 状态
        undoService.pushSnapshot(makePages(count: 1))
        undoService.pushSnapshot(makePages(count: 2))
        _ = undoService.undo(currentPages: makePages(count: 3))
        XCTAssertTrue(undoService.canRedo, "undo 后 canRedo 应为 true")

        // 新操作应清空 redo
        undoService.pushSnapshot(makePages(count: 4))
        XCTAssertFalse(undoService.canRedo, "新 pushSnapshot 应清空 redoStack")
    }

    // MARK: - undo/redo 往返

    /// 验证：undo 返回前一个快照，redo 返回下一个快照。
    func testUndoRedoRoundTrip() {
        let state1 = makePages(count: 1)
        let state2 = makePages(count: 2)
        let state3 = makePages(count: 3)

        undoService.pushSnapshot(state1)
        undoService.pushSnapshot(state2)

        // 当前是 state3，undo 应返回 state2
        let undone = undoService.undo(currentPages: state3)
        XCTAssertEqual(undone?.count, 2, "undo 应返回 state2（2 个页面）")

        // redo 应返回 state3
        let redone = undoService.redo(currentPages: state2)
        XCTAssertEqual(redone?.count, 3, "redo 应返回 state3（3 个页面）")
    }

    /// 验证：空 undoStack 时 undo 返回 nil。
    func testUndoEmptyStackReturnsNil() {
        let result = undoService.undo(currentPages: makePages(count: 1))
        XCTAssertNil(result, "空 undoStack 时应返回 nil")
    }

    /// 验证：空 redoStack 时 redo 返回 nil。
    func testRedoEmptyStackReturnsNil() {
        let result = undoService.redo(currentPages: makePages(count: 1))
        XCTAssertNil(result, "空 redoStack 时应返回 nil")
    }

    // MARK: - 栈大小限制 50

    /// 验证：超过 50 个快照时丢弃最旧的。
    func testMaxStackSizeDropsOldest() {
        // 推入 55 个快照
        for i in 0..<55 {
            undoService.pushSnapshot(makePages(count: i))
        }

        // 连续 undo 50 次应都能成功，第 51 次返回 nil
        var currentPages = makePages(count: 999)
        var undoCount = 0
        while let previous = undoService.undo(currentPages: currentPages) {
            currentPages = previous
            undoCount += 1
        }

        XCTAssertEqual(undoCount, 50, "应能 undo 50 次（栈大小限制）")
    }

    /// 验证：恰好 50 个快照时全部可 undo。
    func testMaxStackSizeAtExactLimit() {
        for i in 0..<50 {
            undoService.pushSnapshot(makePages(count: i))
        }

        var currentPages = makePages(count: 999)
        var undoCount = 0
        while let previous = undoService.undo(currentPages: currentPages) {
            currentPages = previous
            undoCount += 1
        }

        XCTAssertEqual(undoCount, 50, "恰好 50 个应全部可 undo")
    }

    // MARK: - clear

    /// 验证：clear 清空所有栈。
    func testClearEmptiesAllStacks() {
        undoService.pushSnapshot(makePages(count: 1))
        undoService.pushSnapshot(makePages(count: 2))
        _ = undoService.undo(currentPages: makePages(count: 3))

        XCTAssertTrue(undoService.canUndo)
        XCTAssertTrue(undoService.canRedo)

        undoService.clear()

        XCTAssertFalse(undoService.canUndo, "clear 后 canUndo 应为 false")
        XCTAssertFalse(undoService.canRedo, "clear 后 canRedo 应为 false")
    }

    // MARK: - 多次 undo/redo 交替

    /// 验证：多次 undo 后再 redo 能正确恢复。
    func testMultipleUndoThenRedo() {
        let states = (0..<5).map { makePages(count: $0 + 1) }

        // 推入 5 个快照
        for state in states {
            undoService.pushSnapshot(state)
        }

        // undo 3 次
        var current = makePages(count: 999)
        for _ in 0..<3 {
            current = undoService.undo(currentPages: current) ?? current
        }

        // redo 2 次
        for _ in 0..<2 {
            current = undoService.redo(currentPages: current) ?? current
        }

        // 此时 canRedo 应为 true（还有 1 个可 redo）
        XCTAssertTrue(undoService.canRedo, "redo 2 次后还应能继续 redo")
    }

    /// 验证：undo 后新 pushSnapshot 清空 redo，之前的 redo 不可再用。
    func testNewActionAfterUndoClearsRedo() {
        undoService.pushSnapshot(makePages(count: 1))
        undoService.pushSnapshot(makePages(count: 2))
        _ = undoService.undo(currentPages: makePages(count: 3))
        XCTAssertTrue(undoService.canRedo)

        // 新操作
        undoService.pushSnapshot(makePages(count: 5))

        XCTAssertFalse(undoService.canRedo, "新操作后 redo 应被清空")
        XCTAssertTrue(undoService.canUndo, "新操作后 undo 应可用")
    }
}
