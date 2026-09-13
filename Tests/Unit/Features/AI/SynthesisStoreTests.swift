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
        store.clearAll()
    }

    override func tearDown() {
        store?.clearAll()
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

    func testPerformSynthesis_throwsLimitReachedErrorWithoutAutoEviction() async {
        let type = SynthesisStore.SynthesisType.mindmap
        // 模拟填满 5 份用户旧文档
        for i in 1...5 {
            let content = "# 知识主题 \(i)\nmindmap\n  root((主题\(i)))\n    节点\(i)"
            store.saveSynthesisResult(type: type, content: content)
        }

        XCTAssertEqual(store.synthesisResults[type]?.count, 5, "满额包含 5 份文档")

        // 尝试再次合成第 6 份
        do {
            _ = try await store.performSynthesis(type: type, combinedContent: "新的合成正文内容数据")
            XCTFail("达到 5 份上限时必须拒绝生成并抛出超限错误，绝对禁止随意自动删剔旧文档")
        } catch {
            XCTAssertEqual(store.synthesisResults[type]?.count, 5, "用户旧文档数量必须保持 5 份完整未减少")
        }
    }

    // MARK: - 深度反向读取语义与物理抹除验证测试 (Reverse Content Inspection Tests)

    func testReverseRead_persistedContentHasRealSemanticContentAndStructure() {
        let type = SynthesisStore.SynthesisType.mindmap
        let rawContent = "# 计算机科学架构\nmindmap\n  root((计算机科学))\n    数据结构\n    操作系统"
        store.saveSynthesisResult(type: type, content: rawContent)

        // 1. 从内存中反向读取
        guard let memoryDoc = store.synthesisResults[type]?.first else {
            XCTFail("内存列表中必须包含存盘文档")
            return
        }
        XCTAssertGreaterThan(memoryDoc.content.utf8.count, 20, "反向读取：正文内容必须包含实际语义，非空非空壳")
        XCTAssertTrue(memoryDoc.content.contains("计算机科学"), "反向读取：正文必须包含生成的真实主题关键字")
        XCTAssertTrue(memoryDoc.content.contains("mindmap"), "反向读取：思维导图必须包含 Mermaid mindmap 结构定义")

        // 2. 从磁盘物理 Key 反向解码读取
        let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
        guard let diskData = UserDefaults.standard.data(forKey: key),
              let diskDocs = try? JSONDecoder().decode([SynthesisStore.SynthesisDocument].self, from: diskData),
              let diskDoc = diskDocs.first else {
            XCTFail("磁盘 Key 下必须能成功物理解包出 SynthesisDocument")
            return
        }
        XCTAssertEqual(diskDoc.id, memoryDoc.id, "物理解包文档 ID 必须与内存数据完全吻合")
        XCTAssertEqual(diskDoc.content, memoryDoc.content, "物理解包文档正文必须与内存数据 100% 一致")
    }

    func testReverseRead_clearAllCompletelyRemovesPhysicalDiskData() {
        let type = SynthesisStore.SynthesisType.mindmap
        let content = "# 待清空知识点\n这是存入的临时测试数据"
        store.saveSynthesisResult(type: type, content: content)

        let key = AppConstants.Keys.Storage.Legacy.synthesisDocsPrefix + type.rawValue
        XCTAssertNotNil(UserDefaults.standard.data(forKey: key), "存盘后磁盘物理 Key 必须存在数据")

        // 执行清空
        store.clearAll()

        // 反向物理读取校验
        XCTAssertTrue(store.synthesisResults[type]?.isEmpty ?? true, "反向读取：内存字典必须已被完全清空")
        XCTAssertNil(UserDefaults.standard.data(forKey: key), "反向读取：磁盘 Key 下物理数据必须已被 100% 抹除，返回 nil")
    }

    func testPerformSynthesis_WithOptionsAndCustomPrompt() async throws {
        let type = SynthesisStore.SynthesisType.report
        let customOptions = SynthesisControlOptions(depth: .detailed, audience: .executive, tone: .academic, customPrompt: "包含高并发架构视角")
        let sourceText = "# 系统架构\n这是智宇应用的技术基座架构说明文档。面向 iOS/macOS/watchOS 多端同步。"

        let doc = try await store.performSynthesis(type: type, combinedContent: sourceText, options: customOptions)
        XCTAssertNotNil(doc, "包含控制选项的合成必须成功返回 SynthesisDocument")
        XCTAssertGreaterThanOrEqual(doc.size, AppConstants.ExportLimits.minValidSynthesisTextBytes)
    }
}
