//
//  BugHuntBatch7Tests.swift
//  ZhiYuTests
//
//  批次7 针对性测试：覆盖 Bug #132-#141 修复点
//

import XCTest
import UFPCore
@testable import ZhiYu

final class BugHuntBatch7Tests: XCTestCase {

    // MARK: - Bug #132: topKeywords 按频率排序而非字典序

    /// 验证 generateWeeklyInsight 的 topKeywords 按出现频率降序排列
    @MainActor
    func testBug132_TopKeywordsSortedByFrequencyNotLexicographic() async throws {
        setupFullMockEnvironment()

        let service = KnowledgeInsightService()
        let llm = MockLLMService()
        llm.generateHandler = { _, _ in "summary" }

        // 构造页面：tag "zebra" 出现 1 次，tag "apple" 出现 3 次
        // 字典序下 zebra > apple，但频率下 apple > zebra
        let now = Date()
        let applePages: [KnowledgePage] = (0..<3).map { i in
            KnowledgePage(
                title: "Page\(i)",
                content: "content \(i)",
                tags: ["apple"],
                createdAt: now,
                updatedAt: now
            )
        }
        let zebraPage = KnowledgePage(
            title: "ZebraPage",
            content: "zebra content",
            tags: ["zebra"],
            createdAt: now,
            updatedAt: now
        )
        let pages = applePages + [zebraPage]

        let insight = try await service.generateWeeklyInsight(pages: pages, llmService: llm, forceRefresh: true)

        // apple (3次) 应排在 zebra (1次) 前面
        XCTAssertFalse(insight.topKeywords.isEmpty, "topKeywords 不应为空")
        if insight.topKeywords.count >= 2 {
            XCTAssertEqual(insight.topKeywords[0], "apple", "频率最高的 tag 应排第一")
            XCTAssertEqual(insight.topKeywords[1], "zebra", "频率次高的 tag 应排第二")
        }
    }

    // MARK: - Bug #133 & #134: TextChunkerProcessor startIndex 和重叠窗口

    /// 验证重叠窗口在短 chunk 时不会塌缩
    func testBug134_OverlapWindowDoesNotCollapseOnShortChunk() {
        let chunker = TextChunkerProcessor()
        // chunkSize=20, overlap=10
        let config = TextChunkerProcessor.Config(
            chunkSize: 20,
            chunkOverlap: 10,
            separators: ["\n"]
        )

        // 每行 25 字符，超过 chunkSize=20
        let line1 = String(repeating: "A", count: 25)
        let line2 = String(repeating: "B", count: 25)
        let text = line1 + "\n" + line2 + "\n"

        let chunks = chunker.split(text: text, config: config)

        // 至少应产生 2 个 chunk
        XCTAssertGreaterThanOrEqual(chunks.count, 2, "应产生至少 2 个 chunk")

        // 验证 startIndex 单调递增（不回退、不重叠到同一位置）
        for i in 1..<chunks.count {
            XCTAssertGreaterThan(
                chunks[i].startIndex,
                chunks[i-1].startIndex,
                "startIndex 应严格单调递增（Bug #134: 重叠不应导致 startIndex 塌缩）"
            )
        }
    }

    /// 验证 startIndex 偏移不超出原文长度
    func testBug133_StartIndexWithinBounds() {
        let chunker = TextChunkerProcessor()
        let config = TextChunkerProcessor.Config(
            chunkSize: 15,
            chunkOverlap: 5,
            separators: ["\n"]
        )

        let text = String(repeating: "X", count: 50) + "\n" + String(repeating: "Y", count: 50) + "\n"
        let chunks = chunker.split(text: text, config: config)

        XCTAssertFalse(chunks.isEmpty, "应产生 chunk")
        for chunk in chunks {
            XCTAssertGreaterThanOrEqual(chunk.startIndex, 0, "startIndex 不应为负")
            XCTAssertLessThanOrEqual(
                chunk.startIndex,
                text.count,
                "startIndex 不应超出原文长度（Bug #133: 偏移基于含空白文本导致越界）"
            )
        }
    }

    /// 验证空文本返回空数组
    func testBug133_EmptyTextReturnsEmpty() {
        let chunker = TextChunkerProcessor()
        let chunks = chunker.split(text: "", config: TextChunkerProcessor.default)
        XCTAssertTrue(chunks.isEmpty, "空文本应返回空数组")
    }

    // MARK: - Bug #136: anyCreatePage 失败返回 nil

    /// 验证 anyCreatePage 正常路径返回非 nil（使用 NoOp mock）
    @MainActor
    func testBug136_AnyCreatePageReturnsNonNilOnSuccess() async {
        setupFullMockEnvironment()

        let mock = NoOpPageStoreCapabilities()
        let result = await mock.anyCreatePage(
            title: "Bug136Test",
            pageType: .concept,
            customIcon: nil,
            content: "test content",
            tags: [],
            sourceURL: nil,
            rawSnippet: nil,
            fileSize: nil,
            sourceType: nil,
            forceDeepScan: false
        )

        // 正常路径应返回非 nil
        XCTAssertNotNil(result, "正常创建应返回非 nil KnowledgePage")
    }

    // MARK: - Bug #139: ChatHistoryStore 持久化

    /// 验证 ChatHistoryStore.append 持久化到 UserDefaults
    func testBug139_ChatHistoryStoreAppendPersistsToDisk() {
        let key = LLMConstants.ChatHistory.storageKey

        // 清空初始状态
        UserDefaults.standard.removeObject(forKey: key)
        let freshStore = ChatHistoryStore()
        freshStore.clear()
        XCTAssertTrue(freshStore.messages.isEmpty, "清空后应无消息")

        // 添加消息
        let message = ChatMessageDTO(
            id: UUID(),
            role: .user,
            content: "Bug139 test message"
        )
        freshStore.append(message)

        // 验证已持久化到 UserDefaults
        let data = UserDefaults.standard.data(forKey: key)
        XCTAssertNotNil(data, "append 后应持久化到 UserDefaults（Bug #139）")

        // 创建另一个 store 验证能加载
        let reloadStore = ChatHistoryStore()
        XCTAssertEqual(reloadStore.messages.count, 1, "重新加载应能恢复 1 条消息")
        XCTAssertEqual(reloadStore.messages.first?.content, "Bug139 test message")

        // 清理
        UserDefaults.standard.removeObject(forKey: key)
    }

    /// 验证 ChatHistoryStore.clear 也持久化
    func testBug139_ChatHistoryStoreClearPersists() {
        let key = LLMConstants.ChatHistory.storageKey
        UserDefaults.standard.removeObject(forKey: key)

        let store = ChatHistoryStore()
        store.append(ChatMessageDTO(role: .user, content: "msg1"))
        XCTAssertEqual(store.messages.count, 1)

        store.clear()
        let data = UserDefaults.standard.data(forKey: key)
        XCTAssertNotNil(data, "clear 后应持久化空数组到 UserDefaults（Bug #139）")

        let reloadStore = ChatHistoryStore()
        XCTAssertTrue(reloadStore.messages.isEmpty, "clear 后重新加载应为空")

        UserDefaults.standard.removeObject(forKey: key)
    }

    // MARK: - Bug #141: TaskCenter addTask 长度清理

    /// 验证 addTask 在超过上限时清理最旧任务
    @MainActor
    func testBug141_AddTaskTrimsExcessTasks() {
        let taskCenter = TaskCenter()
        taskCenter.tasks = []

        // 添加超过 maxRetainedTasks 个任务
        let maxTasks = FeatureConstants.TaskCenter.maxRetainedTasks
        let totalToAdd = maxTasks + 5

        for i in 0..<totalToAdd {
            _ = taskCenter.addTask(
                type: .ai,
                name: "Task\(i)",
                target: "target\(i)"
            )
        }

        // 任务数不应超过 maxRetainedTasks
        XCTAssertLessThanOrEqual(
            taskCenter.tasks.count,
            maxTasks,
            "任务数不应超过 maxRetainedTasks（Bug #141: addTask 应做长度清理）"
        )

        // 最新的任务应在最前面
        if let firstTask = taskCenter.tasks.first {
            XCTAssertTrue(
                firstTask.name.contains("Task\(totalToAdd - 1)"),
                "最新添加的任务应在列表最前"
            )
        }
    }

    /// 验证正常情况下任务数不超过上限
    @MainActor
    func testBug141_AddTaskWithinLimit() {
        let taskCenter = TaskCenter()
        taskCenter.tasks = []

        let maxTasks = FeatureConstants.TaskCenter.maxRetainedTasks

        // 添加刚好等于上限的任务
        for i in 0..<maxTasks {
            _ = taskCenter.addTask(
                type: .ai,
                name: "Task\(i)",
                target: "target\(i)"
            )
        }

        XCTAssertEqual(
            taskCenter.tasks.count,
            maxTasks,
            "刚好等于上限时不应清理"
        )
    }
}
