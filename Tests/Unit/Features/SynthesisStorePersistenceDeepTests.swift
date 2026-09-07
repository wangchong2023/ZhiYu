//
//  SynthesisStorePersistenceDeepTests.swift
//  ZhiYuTests
//
//  系统层级：[Test] 单元测试
//  核心职责：SynthesisStore 深度补盲测试（持久化 CRUD 分片）— 覆盖 deleteSynthesisDoc/renameSynthesisDoc/
//            batchDeleteSynthesisDocs/clearAll/loadSynthesisResults 持久化反向读取、
//            AppEventBus.clearAllDataRequested 联动，以发现生产代码潜在 bug 为首要目标。
//
//  说明：从 SynthesisStoreDeepTests.swift 拆分而来（按 MARK 分段）。本文件聚焦持久化 CRUD 与事件联动。
//

import XCTest
import UFPCore
import Combine
import Dependencies
@testable import ZhiYu

// MARK: - SynthesisStore 持久化 CRUD 深度测试

@MainActor
final class SynthesisStorePersistenceDeepTests: XCTestCase {

    // MARK: - 测试夹具

    private var mockLLM: SynthesisStoreControllableLLM!
    private var taskCenter: TaskCenter!
    private var store: SynthesisStore!

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
        resetPersistentTestState()

        // 创建可控 LLM Mock 并双重注入：
        // 1) ServiceContainer 注册（AISynthesisService.currentLLM 优先从 DI 解析）
        // 2) AISynthesisService.shared.updateLLMForTesting（覆盖 actor 内部 llm 后备引用）
        let llm = SynthesisStoreControllableLLM()
        self.mockLLM = llm
        ServiceContainer.shared.register(llm as any LLMServiceProtocol, for: (any LLMServiceProtocol).self)
        await AISynthesisService.shared.updateLLMForTesting(llm)

        // 创建独立的 TaskCenter 实例，通过 withDependencies 注入到 SynthesisStore
        self.taskCenter = TaskCenter(activityService: nil)
        self.taskCenter.reset()

        // 清理 UserDefaults.standard 中可能残留的合成文档键（跨测试隔离）
        for type in SynthesisStore.SynthesisType.allCases {
            let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
            UserDefaults.standard.removeObject(forKey: key)
        }

        // 在 withDependencies 闭包内创建 SynthesisStore，确保 @Dependency(\.taskCenter) 解析到自定义实例
        self.store = withDependencies {
            $0.taskCenter = self.taskCenter
        } operation: {
            SynthesisStore()
        }
        self.store.clearAll()
    }

    override func tearDown() async throws {
        store?.clearAll()
        for type in SynthesisStore.SynthesisType.allCases {
            let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
            UserDefaults.standard.removeObject(forKey: key)
        }
        store = nil
        taskCenter = nil
        mockLLM = nil
        await MainActor.run { resetPersistentTestState() }
        try await super.tearDown()
    }

    // MARK: - deleteSynthesisDoc

    /// 验证 deleteSynthesisDoc 删除指定文档。
    func testDeleteSynthesisDoc删除指定文档() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文内容。")
        let docID = store.synthesisResults[.report]?.first?.id

        if let id = docID {
            store.deleteSynthesisDoc(type: .report, docID: id)
            XCTAssertTrue(store.synthesisResults[.report]?.isEmpty ?? true, "删除后列表应为空")
        } else {
            XCTFail("应存在文档 ID")
        }
    }

    /// 验证 deleteSynthesisDoc 删除不存在的 docID 不崩溃。
    func testDeleteSynthesisDoc不存在的docID不崩溃() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文内容。")
        let initialCount = store.synthesisResults[.report]?.count ?? 0

        // 删除不存在的 UUID
        store.deleteSynthesisDoc(type: .report, docID: UUID())

        XCTAssertEqual(store.synthesisResults[.report]?.count, initialCount, "删除不存在的 ID 不应影响列表")
    }

    /// 验证 deleteSynthesisDoc 删除类型下不存在的文档（类型为空）不崩溃。
    func testDeleteSynthesisDoc类型为空时不崩溃() {
        store.deleteSynthesisDoc(type: .expansion, docID: UUID())
        XCTAssertTrue(store.synthesisResults[.expansion]?.isEmpty ?? true)
    }

    /// 验证 deleteSynthesisDoc 删除最后一个文档后状态重置为 .idle。
    func testDeleteSynthesisDoc删除最后一个后状态重置Idle() {
        store.saveSynthesisResult(type: .quiz, content: "{\"title\":\"测验\",\"questions\":[]}")
        XCTAssertEqual(store.synthesisStates[.quiz], .completed)

        let docID = store.synthesisResults[.quiz]?.first?.id
        if let id = docID {
            store.deleteSynthesisDoc(type: .quiz, docID: id)
            XCTAssertEqual(store.synthesisStates[.quiz], .idle, "删除最后一个后状态应重置为 .idle")
        }
    }

    /// 验证 deleteSynthesisDoc 删除后持久化更新（UserDefaults 中数据同步移除）。
    func testDeleteSynthesisDoc删除后持久化更新() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文内容。")
        let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + SynthesisStore.SynthesisType.report.rawValue
        XCTAssertNotNil(UserDefaults.standard.data(forKey: key))

        let docID = store.synthesisResults[.report]?.first?.id
        if let id = docID {
            store.deleteSynthesisDoc(type: .report, docID: id)
            // 删除最后一个后，persistResults 应移除 key
            XCTAssertNil(UserDefaults.standard.data(forKey: key), "删除最后一个后 UserDefaults key 应被移除")
        }
    }

    // MARK: - renameSynthesisDoc

    /// 验证 renameSynthesisDoc 重命名文档。
    func testRenameSynthesisDoc重命名文档() {
        store.saveSynthesisResult(type: .report, content: "# 原始报告\n正文内容。")
        let docID = store.synthesisResults[.report]?.first?.id

        if let id = docID {
            store.renameSynthesisDoc(type: .report, docID: id, newName: "新名称")
            XCTAssertEqual(store.synthesisResults[.report]?.first?.name, "新名称")
        }
    }

    /// 验证 renameSynthesisDoc 重命名不存在的 docID 不崩溃。
    func testRenameSynthesisDoc不存在的docID不崩溃() {
        store.renameSynthesisDoc(type: .report, docID: UUID(), newName: "新名称")
        // 不崩溃即通过
    }

    /// 验证 renameSynthesisDoc 重命名后保留其他属性（content/createdAt/size）。
    func testRenameSynthesisDoc保留其他属性() {
        let content = "# 报告\n正文内容。"
        store.saveSynthesisResult(type: .report, content: content)
        let original = store.synthesisResults[.report]?.first
        let originalContent = original?.content
        let originalSize = original?.size
        let originalCreatedAt = original?.createdAt

        if let id = original?.id {
            store.renameSynthesisDoc(type: .report, docID: id, newName: "重命名")
            let renamed = store.synthesisResults[.report]?.first
            XCTAssertEqual(renamed?.content, originalContent, "content 应保留")
            XCTAssertEqual(renamed?.size, originalSize, "size 应保留")
            XCTAssertEqual(renamed?.createdAt, originalCreatedAt, "createdAt 应保留")
        }
    }

    // MARK: - batchDeleteSynthesisDocs

    /// 验证 batchDeleteSynthesisDocs 跨类型批量删除。
    func testBatchDeleteSynthesisDocs跨类型批量删除() {
        store.saveSynthesisResult(type: .report, content: "# 报告1\n正文。")
        store.saveSynthesisResult(type: .mindmap, content: "# 导图1\nmindmap\n  root((主题))")
        store.saveSynthesisResult(type: .quiz, content: "{\"title\":\"测验\",\"questions\":[]}")

        let reportID = store.synthesisResults[.report]?.first?.id
        let quizID = store.synthesisResults[.quiz]?.first?.id
        let idsToDelete: Set<UUID> = Set([reportID, quizID].compactMap { $0 })

        store.batchDeleteSynthesisDocs(ids: idsToDelete)

        XCTAssertTrue(store.synthesisResults[.report]?.isEmpty ?? true, "report 应被删除")
        XCTAssertTrue(store.synthesisResults[.quiz]?.isEmpty ?? true, "quiz 应被删除")
        XCTAssertFalse(store.synthesisResults[.mindmap]?.isEmpty ?? true, "mindmap 应保留")
    }

    /// 验证 batchDeleteSynthesisDocs 传入空集合不崩溃。
    func testBatchDeleteSynthesisDocs空集合不崩溃() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文。")
        store.batchDeleteSynthesisDocs(ids: [])
        XCTAssertEqual(store.synthesisResults[.report]?.count, 1, "空集合不应删除任何文档")
    }

    /// 验证 batchDeleteSynthesisDocs 删除后状态重置。
    func testBatchDeleteSynthesisDocs删除后状态重置() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文。")
        XCTAssertEqual(store.synthesisStates[.report], .completed)

        let id = store.synthesisResults[.report]?.first?.id
        if let id = id {
            store.batchDeleteSynthesisDocs(ids: [id])
            XCTAssertEqual(store.synthesisStates[.report], .idle, "删除最后一个后状态应重置")
        }
    }

    // MARK: - clearAll

    /// 验证 clearAll 清空所有类型的文档和状态。
    func testClearAll清空所有文档和状态() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文。")
        store.saveSynthesisResult(type: .mindmap, content: "# 导图\nmindmap\n  root((主题))")

        store.clearAll()

        for type in SynthesisStore.SynthesisType.allCases {
            XCTAssertTrue(store.synthesisResults[type]?.isEmpty ?? true, "\(type.rawValue) 应被清空")
            XCTAssertEqual(store.synthesisStates[type], .idle, "\(type.rawValue) 状态应重置为 .idle")
        }
    }

    /// 验证 clearAll 移除 UserDefaults 中所有合成文档 key。
    func testClearAll移除UserDefaults所有Key() {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文。")
        store.saveSynthesisResult(type: .mindmap, content: "# 导图\nmindmap\n  root((主题))")

        store.clearAll()

        for type in SynthesisStore.SynthesisType.allCases {
            let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
            XCTAssertNil(UserDefaults.standard.data(forKey: key), "\(type.rawValue) 的 UserDefaults key 应被移除")
        }
    }

    /// 验证 clearAll 在空存储时不崩溃。
    func testClearAll空存储时不崩溃() {
        store.clearAll()
        // 不崩溃即通过
        for type in SynthesisStore.SynthesisType.allCases {
            XCTAssertTrue(store.synthesisResults[type]?.isEmpty ?? true)
        }
    }

    // MARK: - AppEventBus.clearAllDataRequested 联动

    /// 验证 AppEventBus 发布 clearAllDataRequested 事件时 SynthesisStore 自动 clearAll。
    func testAppEventBusClearAllDataRequested触发SynthesisStoreClearAll() async throws {
        store.saveSynthesisResult(type: .report, content: "# 报告\n正文。")
        XCTAssertFalse(store.synthesisResults[.report]?.isEmpty ?? true)

        // 发布清理事件
        AppEventBus.shared.publish(.clearAllDataRequested)

        // 等待 RunLoop.main 处理事件（sink 使用 receive(on: RunLoop.main)）
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(store.synthesisResults[.report]?.isEmpty ?? true, "clearAllDataRequested 事件应触发 clearAll")
    }

    // MARK: - loadSynthesisResults

    /// 验证 loadSynthesisResults 从 UserDefaults 加载已持久化的文档。
    func testLoadSynthesisResults从UserDefaults加载文档() {
        // 先保存文档
        let content = "# 加载测试\n正文内容。"
        store.saveSynthesisResult(type: .report, content: content)
        let originalID = store.synthesisResults[.report]?.first?.id

        // 创建新 store 实例（init 会调用 loadSynthesisResults）
        let newStore = withDependencies {
            $0.taskCenter = self.taskCenter
        } operation: {
            SynthesisStore()
        }

        XCTAssertEqual(newStore.synthesisResults[.report]?.first?.id, originalID, "新 store 应从 UserDefaults 加载已持久化文档")
        XCTAssertEqual(newStore.synthesisResults[.report]?.first?.content, content)
    }

    /// 验证 loadSynthesisResults 在空存储时不崩溃。
    func testLoadSynthesisResults空存储时不崩溃() {
        // 确保 UserDefaults 为空
        for type in SynthesisStore.SynthesisType.allCases {
            let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
            UserDefaults.standard.removeObject(forKey: key)
        }

        let newStore = withDependencies {
            $0.taskCenter = self.taskCenter
        } operation: {
            SynthesisStore()
        }

        for type in SynthesisStore.SynthesisType.allCases {
            XCTAssertTrue(newStore.synthesisResults[type]?.isEmpty ?? true, "\(type.rawValue) 应为空")
        }
    }

    /// 验证 loadSynthesisResults 在遇到损坏数据时静默跳过不崩溃。
    func testLoadSynthesisResults损坏数据时静默跳过() {
        // 写入损坏的 JSON 数据
        let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + SynthesisStore.SynthesisType.report.rawValue
        let corruptedData = Data("这不是合法的JSON".utf8)
        UserDefaults.standard.set(corruptedData, forKey: key)

        // 创建新 store，loadSynthesisResults 使用 try? 解码，损坏数据应静默跳过
        let newStore = withDependencies {
            $0.taskCenter = self.taskCenter
        } operation: {
            SynthesisStore()
        }

        XCTAssertTrue(newStore.synthesisResults[.report]?.isEmpty ?? true, "损坏数据应被静默跳过")
    }
}
