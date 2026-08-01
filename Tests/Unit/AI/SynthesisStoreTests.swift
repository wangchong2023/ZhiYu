//
//  SynthesisStoreTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/08/01.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 SynthesisStore 的物理防空门禁、状态推演、持久化防空及文档删除等开展单元测试。
//

import XCTest
@testable import ZhiYu

@MainActor
final class SynthesisStoreTests: XCTestCase {

    var store: SynthesisStore!

    override func setUp() {
        super.setUp()
        store = SynthesisStore()
    }

    override func tearDown() {
        store = nil
        super.tearDown()
    }

    // MARK: - 防空物理门禁测试 (Empty & Skeleton Rejection Tests)

    func testSaveSynthesisResult_rejectsEmptyOrSkeletonContent() {
        let type = SynthesisStore.SynthesisType.mindmap
        
        // 尝试保存小于 minValidSynthesisTextBytes (10B) 的无效内容
        store.saveSynthesisResult(type: type, content: "mindmap")
        XCTAssertTrue(store.synthesisResults[type]?.isEmpty ?? true, "纯 'mindmap' 骨架内容必须拒绝存盘")

        store.saveSynthesisResult(type: type, content: "  \n  ")
        XCTAssertTrue(store.synthesisResults[type]?.isEmpty ?? true, "纯空白内容必须拒绝存盘")

        store.saveSynthesisResult(type: type, content: "graph TD")
        XCTAssertTrue(store.synthesisResults[type]?.isEmpty ?? true, "纯 'graph TD' 骨架必须拒绝存盘")

        // 保存有效内容
        let validContent = "# 深度知识报告\n这是经过 AI 合成分析后的有效正文内容。"
        store.saveSynthesisResult(type: type, content: validContent)
        XCTAssertEqual(store.synthesisResults[type]?.count, 1, "有效内容必须成功存盘")
        XCTAssertGreaterThanOrEqual(store.synthesisResults[type]?.first?.size ?? 0, AppConstants.ExportLimits.minValidSynthesisTextBytes)
    }

    // MARK: - 文档增删改与状态管理测试

    func testRenameSynthesisDoc() {
        let type = SynthesisStore.SynthesisType.report
        let content = "# 原始分析报告\n正文数据"
        store.saveSynthesisResult(type: type, content: content)

        guard let doc = store.synthesisResults[type]?.first else {
            XCTFail("应该存在已存盘文档")
            return
        }

        let newName = "重命名后的报告"
        store.renameSynthesisDoc(type: type, docID: doc.id, newName: newName)
        XCTAssertEqual(store.synthesisResults[type]?.first?.name, newName, "文档名称必须成功更名")
    }

    func testDeleteSynthesisDoc() {
        let type = SynthesisStore.SynthesisType.quiz
        let validQuizJSON = """
        {"title":"测验","questions":[{"id":1,"text":"1+1=?","options":["1","2"],"answer":1,"explanation":"解析"}]}
        """
        store.saveSynthesisResult(type: type, content: validQuizJSON)
        XCTAssertEqual(store.synthesisResults[type]?.count, 1)

        if let docID = store.synthesisResults[type]?.first?.id {
            store.deleteSynthesisDoc(type: type, docID: docID)
            XCTAssertTrue(store.synthesisResults[type]?.isEmpty ?? true, "删除操作必须清理内存列表")
        }
    }
}
