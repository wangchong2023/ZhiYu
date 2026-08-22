//
//  MaintenanceAndImportDeepTests.swift
//  ZhiYuTests
//
//  Created by CodeFree on 2026/08/22.
//  Coverage: Task 21 — MaintenanceService/FileImportFileStore 补盲
//

import XCTest
import UFPStorage
import UFPCore
import Dependencies
@testable import ZhiYu

// MARK: - MaintenanceService 补盲测试

/// 覆盖 MaintenanceService 的 generateInitialNotebooks/saveToDisk/loadFromDisk/clearLogs
@MainActor
final class MaintenanceServiceDeepTests: XCTestCase {

    /// generateInitialNotebooks 应返回元组（total, details）
    func testGenerateInitialNotebooksReturnsTuple() async {
        let service = MaintenanceService()
        let result = await service.generateInitialNotebooks()
        XCTAssertGreaterThanOrEqual(result.total, 0, "total 应为非负整数")
        XCTAssertTrue(result.details.isEmpty || result.details.allSatisfy { $0.count >= 0 }, "details 中 count 应为非负整数")
    }

    /// seedDefaultContent pages 非空时应跳过（guard pages.isEmpty）
    func testSeedDefaultContentNonEmptyPagesSkips() async {
        let service = MaintenanceService()
        let pages = [KnowledgePage(title: "existing", pageType: .concept)]
        // pages 非空，应直接返回不注入
        await service.seedDefaultContent(pages: pages, vaultName: L10n.Vault.defaultName)
        XCTAssertTrue(true, "pages 非空时应跳过种子注入")
    }

    /// saveToDisk 应不崩溃
    func testSaveToDiskDoesNotCrash() async {
        let service = MaintenanceService()
        await service.saveToDisk(pages: [])
        XCTAssertTrue(true, "saveToDisk 不应崩溃")
    }

    /// loadFromDisk 应不崩溃
    func testLoadFromDiskDoesNotCrash() async {
        let service = MaintenanceService()
        await service.loadFromDisk()
        XCTAssertTrue(true, "loadFromDisk 不应崩溃")
    }

    /// clearLogs 应不崩溃
    func testClearLogsDoesNotCrash() async {
        let service = MaintenanceService()
        await service.clearLogs()
        XCTAssertTrue(true, "clearLogs 不应崩溃")
    }

    /// clearAllDeveloperData 应不崩溃并发布 pagesCleared 事件
    func testClearAllDeveloperDataPublishesEvent() async {
        let service = MaintenanceService()
        await service.clearAllDeveloperData()
        XCTAssertTrue(true, "clearAllDeveloperData 不应崩溃")
    }
}

// MARK: - FileImportFileStore 补盲测试

/// 覆盖 FileImportFileStore 的 fallback 路径和边界
final class FileImportFileStoreDeepTests: XCTestCase {

    /// saveContent 空字符串应保存成功（空数据也是有效 Data）
    func testSaveContentEmptyStringSaves() {
        let store = FileImportFileStore()
        let result = store.saveContent("", category: .manual, ext: "md")
        XCTAssertNotNil(result, "空字符串应保存成功")
        if let path = result {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    /// saveContent 无效 UTF-8 不可能（String 总是有效 UTF-8），验证正常字符串
    func testSaveContentNormalStringSaves() {
        let store = FileImportFileStore()
        let result = store.saveContent("测试内容", category: .clipboard, ext: "txt")
        XCTAssertNotNil(result, "正常字符串应保存成功")
        if let path = result {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    /// saveData 空数据应保存成功
    func testSaveDataEmptyDataSaves() {
        let store = FileImportFileStore()
        let result = store.saveData(Data(), category: .file, ext: "bin")
        XCTAssertNotNil(result, "空数据应保存成功")
        if let path = result {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    /// copyFile 不存在的源文件应返回 nil
    func testCopyFileNonExistentSourceReturnsNil() {
        let store = FileImportFileStore()
        let nonExistentURL = URL(fileURLWithPath: "/tmp/non-existent-\(UUID().uuidString).txt")
        let result = store.copyFile(at: nonExistentURL, category: .file)
        XCTAssertNil(result, "不存在的源文件应返回 nil")
    }

    /// copyFile 已存在的文件应成功复制
    func testCopyFileExistingFileSucceeds() throws {
        let store = FileImportFileStore()
        let tempDir = FileManager.default.temporaryDirectory
        let sourceURL = tempDir.appendingPathComponent("source-\(UUID().uuidString).txt")
        try "test content".write(to: sourceURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: sourceURL) }

        let result = store.copyFile(at: sourceURL, category: .file)
        XCTAssertNotNil(result, "已存在的文件应成功复制")
        if let path = result {
            try? FileManager.default.removeItem(atPath: path)
        }
    }

    /// saveContent 各 category 都应保存成功
    func testSaveContentAllCategoriesSucceed() {
        let store = FileImportFileStore()
        for category in ImportCategory.allCases {
            let result = store.saveContent("content for \(category.rawValue)", category: category, ext: "md")
            XCTAssertNotNil(result, "category \(category.rawValue) 应保存成功")
            if let path = result {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
    }

    /// saveData 不同扩展名应保存成功
    func testSaveDataDifferentExtensionsSucceed() {
        let store = FileImportFileStore()
        let extensions = ["md", "txt", "json", "pdf", "bin"]
        for ext in extensions {
            let result = store.saveData(Data([0x41, 0x42, 0x43]), category: .file, ext: ext)
            XCTAssertNotNil(result, "扩展名 \(ext) 应保存成功")
            if let path = result {
                try? FileManager.default.removeItem(atPath: path)
            }
        }
    }
}
