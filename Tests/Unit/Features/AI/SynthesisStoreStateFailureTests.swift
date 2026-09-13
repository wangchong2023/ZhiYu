//
//  SynthesisStoreStateFailureTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/31.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Unit] 测试层
//  核心职责：测试 SynthesisStore 在任务并发冲突、容量超限、畸形内容拦截及全量清理事件下的状态机鲁棒性。
//

import XCTest
import UFPCore
@testable import ZhiYu

@MainActor
final class SynthesisStoreStateFailureTests: XCTestCase {

    private var store: SynthesisStore!

    override func setUp() {
        super.setUp()
        store = SynthesisStore()
    }

    override func tearDown() {
        store.clearAll()
        store = nil
        super.tearDown()
    }

    // MARK: - 1. 并发冲突与上限拦截

    func testPerformSynthesisWhenAlreadyGeneratingThrows() async {
        store.synthesisStates[.mindmap] = .generating

        do {
            _ = try await store.performSynthesis(type: .mindmap, combinedContent: "测试正文")
            XCTFail("处于 generating 状态时应拒绝并发启动新任务")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, CoreConstants.ErrorDomain.synthesisStore)
            XCTAssertEqual(error.code, -1)
        } catch {
            XCTFail("应抛出 NSError，实际为: \(error)")
        }
    }

    func testPerformSynthesisLimitReachedThrows() async {
        // 人工塞满 5 份文档
        for i in 1...store.maxSynthesisDocsPerType {
            let validContent = "# 标题 \(i)\n\n" + String(repeating: "有效且充实的合成内容描述。", count: 5)
            store.saveSynthesisResult(type: .report, content: validContent)
        }

        XCTAssertEqual(store.synthesisResults[.report]?.count, 5)

        do {
            _ = try await store.performSynthesis(type: .report, combinedContent: "新的内容")
            XCTFail("超出 5 份上限时必须拦截并抛错")
        } catch let error as NSError {
            XCTAssertEqual(error.domain, CoreConstants.ErrorDomain.synthesisStore)
            XCTAssertEqual(error.code, -2)
        } catch {
            XCTFail("应抛出 NSError，实际为: \(error)")
        }
    }

    // MARK: - 2. 畸形与骨架伪内容保存拦截

    func testSaveSynthesisResultRejectsSkeletonContent() {
        // 空文本
        let docEmpty = store.saveSynthesisResult(type: .mindmap, content: "")
        XCTAssertNil(docEmpty, "空内容应被拒绝")

        // 仅包含 mermaid 骨架
        let docMindmap = store.saveSynthesisResult(type: .mindmap, content: "mindmap")
        XCTAssertNil(docMindmap, "纯骨架 mindmap 关键字应被拒绝")

        let docGraph = store.saveSynthesisResult(type: .mindmap, content: "graph TD")
        XCTAssertNil(docGraph, "纯骨架 graph TD 关键字应被拒绝")

        // 小于最小字节阈值
        let docTooShort = store.saveSynthesisResult(type: .mindmap, content: "短")
        XCTAssertNil(docTooShort, "超短内容应被拒绝")
    }

    // MARK: - 3. 重命名、删除与清空

    func testRenameDeleteAndClearAll() {
        let validContent = "# 思维导图分析\n\n" + String(repeating: "详细的思维导图节点内容。", count: 5)
        guard let doc = store.saveSynthesisResult(type: .mindmap, content: validContent) else {
            XCTFail("有效内容应保存成功")
            return
        }

        // 重命名
        let newTitle = "重命名后的文档"
        store.renameSynthesisDoc(type: .mindmap, docID: doc.id, newName: newTitle)
        XCTAssertEqual(store.synthesisResults[.mindmap]?.first?.name, newTitle)

        // 单个删除
        store.deleteSynthesisDoc(type: .mindmap, docID: doc.id)
        XCTAssertTrue(store.synthesisResults[.mindmap]?.isEmpty ?? true)
        XCTAssertEqual(store.synthesisStates[.mindmap], .idle)

        // 保存新文档后触发全局清空事件
        store.saveSynthesisResult(type: .mindmap, content: validContent)
        AppEventBus.shared.publish(.clearAllDataRequested)

        // 等待主循环派发
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        XCTAssertTrue(store.synthesisResults[.mindmap]?.isEmpty ?? true)
    }
}
