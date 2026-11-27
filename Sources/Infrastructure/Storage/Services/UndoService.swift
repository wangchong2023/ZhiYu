//
//  UndoService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：实现 Undo 模块的核心业务逻辑服务。
//
import Foundation
import Combine
import os
import UFPCore
import Dependencies

// MARK: - Undo Service
/// Manages undo/redo for AppStore operations using snapshot-based approach.
/// Each mutation saves a snapshot of pages before the change, enabling full rollback.
final class UndoService: ObservableObject, @unchecked Sendable {
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false

    private enum Config {
        static let maxStackSize: Int = 50
    }

    private struct StackState {
        var undoStack: [[KnowledgePage]] = []
        var redoStack: [[KnowledgePage]] = []
    }

    private struct StackTransition {
        let pages: [KnowledgePage]?
        let canUndo: Bool
        let canRedo: Bool
    }

    /// 保护 undoStack/redoStack 并发读写（如后台 Vault/DB 切换通知与前台编辑并发）
    private let stateLock = OSAllocatedUnfairLock(initialState: StackState())
    private var cancellables = Set<AnyCancellable>()

    init() {
        // 多 Vault 切换/底层数据库热切换时立即清空撤销与重做栈，
        // 杜绝在 Vault B 按撤销把 Vault A 的整库快照覆盖写入 Vault B 造成跨库数据污染。
        NotificationCenter.default.publisher(for: .vaultWillSwitch)
            .merge(with: NotificationCenter.default.publisher(for: .databaseDidSwitch))
            .sink { [weak self] _ in
                self?.clear()
            }
            .store(in: &cancellables)
    }

    // MARK: - Snapshot Management
    /// 推送Snapshot
    /// - Parameter pages: pages
    func pushSnapshot(_ pages: [KnowledgePage]) {
        let flags: (canUndo: Bool, canRedo: Bool) = stateLock.withLock { state in
            state.undoStack.append(pages.map { $0 })
            if state.undoStack.count > Config.maxStackSize {
                state.undoStack.removeFirst()
            }
            // Any new action clears the redo stack
            state.redoStack.removeAll()
            return (!state.undoStack.isEmpty, !state.redoStack.isEmpty)
        }
        updatePublishedState(canUndo: flags.canUndo, canRedo: flags.canRedo)
    }

    /// 撤销
    /// - Parameter currentPages: currentPages
    /// - Returns: 列表
    func undo(currentPages: [KnowledgePage]) -> [KnowledgePage]? {
        let outcome: StackTransition = stateLock.withLock { state in
            guard !state.undoStack.isEmpty else {
                return StackTransition(pages: nil, canUndo: !state.undoStack.isEmpty, canRedo: !state.redoStack.isEmpty)
            }
            state.redoStack.append(currentPages.map { $0 })
            if state.redoStack.count > Config.maxStackSize {
                state.redoStack.removeFirst()
            }
            let previous = state.undoStack.removeLast()
            return StackTransition(pages: previous, canUndo: !state.undoStack.isEmpty, canRedo: !state.redoStack.isEmpty)
        }
        if outcome.pages != nil {
            updatePublishedState(canUndo: outcome.canUndo, canRedo: outcome.canRedo)
        }
        return outcome.pages
    }

    /// 重做
    /// - Parameter currentPages: currentPages
    /// - Returns: 列表
    func redo(currentPages: [KnowledgePage]) -> [KnowledgePage]? {
        let outcome: StackTransition = stateLock.withLock { state in
            guard !state.redoStack.isEmpty else {
                return StackTransition(pages: nil, canUndo: !state.undoStack.isEmpty, canRedo: !state.redoStack.isEmpty)
            }
            state.undoStack.append(currentPages.map { $0 })
            if state.undoStack.count > Config.maxStackSize {
                state.undoStack.removeFirst()
            }
            let next = state.redoStack.removeLast()
            return StackTransition(pages: next, canUndo: !state.undoStack.isEmpty, canRedo: !state.redoStack.isEmpty)
        }
        if outcome.pages != nil {
            updatePublishedState(canUndo: outcome.canUndo, canRedo: outcome.canRedo)
        }
        return outcome.pages
    }

    /// 清除
    func clear() {
        stateLock.withLock { state in
            state.undoStack.removeAll()
            state.redoStack.removeAll()
        }
        updatePublishedState(canUndo: false, canRedo: false)
    }

    private func updatePublishedState(canUndo: Bool, canRedo: Bool) {
        if Thread.isMainThread {
            self.canUndo = canUndo
            self.canRedo = canRedo
        } else {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let latest: (Bool, Bool) = self.stateLock.withLock {
                    (!$0.undoStack.isEmpty, !$0.redoStack.isEmpty)
                }
                self.canUndo = latest.0
                self.canRedo = latest.1
            }
        }
    }
}

// MARK: - DependencyKey 注册

/// UndoService 的 DependencyKey（P7 迁移：过渡期 liveValue 从 ServiceContainer 解析，可选）
enum UndoServiceKey: DependencyKey {
    nonisolated public static var liveValue: UndoService? {
        ServiceContainer.shared.resolveOptional(UndoService.self)
    }

    nonisolated public static var testValue: UndoService? {
        ServiceContainer.shared.resolveOptional(UndoService.self)
    }
    nonisolated static var previewValue: UndoService? { testValue }
}

extension DependencyValues {
    /// 撤销服务依赖（可选）
    nonisolated var undoService: UndoService? {
        get { self[UndoServiceKey.self] }
        set { self[UndoServiceKey.self] = newValue }
    }
}
