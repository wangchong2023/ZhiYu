//
//  UnsupportedServicesTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：验证 3 个 Unsupported 桩服务在不支持平台上的行为（返回 false/抛错）。
//

import XCTest
import UFPCore
@testable import ZhiYu

final class UnsupportedServicesTests: XCTestCase {

    // MARK: - UnsupportedReminderService

    /// requestAccess 应返回 false（不支持平台）
    func testUnsupportedReminderService_requestAccess_返回false() async {
        let service = UnsupportedReminderService()
        let result = await service.requestAccess()
        XCTAssertFalse(result, "不支持平台应返回 false")
    }

    /// createReminder 应不抛错（空实现，Do nothing）
    func testUnsupportedReminderService_createReminder_不抛错() async {
        let service = UnsupportedReminderService()
        do {
            try await service.createReminder(title: "test", notes: "notes")
            // 不抛错即通过
        } catch {
            XCTFail("createReminder 空实现不应抛错：\(error)")
        }
    }

    // MARK: - UnsupportedExportService

    /// exportToPDF 应抛出 NSError（domain=export, code=501）
    func testUnsupportedExportService_exportToPDF_抛出NSError() async {
        let service = UnsupportedExportService()
        do {
            _ = try await service.exportToPDF(markdown: "# test", fileName: "test.pdf")
            XCTFail("应抛出错误")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, CoreConstants.ErrorDomain.export)
            XCTAssertEqual(nsError.code, SystemConstants.HTTPStatusCode.notImplemented)
            XCTAssertEqual(nsError.localizedDescription, CoreConstants.Export.unsupportedMessage)
        }
    }

    /// exportMindmapToPDF 应抛出 NSError
    func testUnsupportedExportService_exportMindmapToPDF_抛出NSError() async {
        let service = UnsupportedExportService()
        do {
            _ = try await service.exportMindmapToPDF(mermaidCode: "graph TD", fileName: "test.pdf")
            XCTFail("应抛出错误")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, CoreConstants.ErrorDomain.export)
            XCTAssertEqual(nsError.code, SystemConstants.HTTPStatusCode.notImplemented)
        }
    }

    /// exportToPPTX 应抛出 NSError
    func testUnsupportedExportService_exportToPPTX_抛出NSError() async {
        let service = UnsupportedExportService()
        do {
            _ = try await service.exportToPPTX(markdown: "# test", fileName: "test.pptx")
            XCTFail("应抛出错误")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, CoreConstants.ErrorDomain.export)
            XCTAssertEqual(nsError.code, SystemConstants.HTTPStatusCode.notImplemented)
        }
    }

    // MARK: - UnsupportedFileArchiver

    /// zip 应抛出 FileArchiverError.platformNotSupported
    func testUnsupportedFileArchiver_zip_抛出platformNotSupported() async {
        let archiver = UnsupportedFileArchiver()
        let sourceDir = URL(fileURLWithPath: "/tmp/test-source")
        let destURL = URL(fileURLWithPath: "/tmp/test.zip")
        do {
            try await archiver.zip(directory: sourceDir, to: destURL)
            XCTFail("应抛出错误")
        } catch let error as FileArchiverError {
            guard case .platformNotSupported = error else {
                XCTFail("应抛出 .platformNotSupported，实际：\(error)")
                return
            }
        } catch {
            XCTFail("应抛出 FileArchiverError，实际类型：\(type(of: error))")
        }
    }

    /// extractContents 应抛出 FileArchiverError.platformNotSupported
    func testUnsupportedFileArchiver_extractContents_抛出platformNotSupported() {
        let archiver = UnsupportedFileArchiver()
        let archiveURL = URL(fileURLWithPath: "/tmp/test.zip")
        let destURL = URL(fileURLWithPath: "/tmp/test-dest")
        do {
            try archiver.extractContents(from: archiveURL, to: destURL)
            XCTFail("应抛出错误")
        } catch let error as FileArchiverError {
            guard case .platformNotSupported = error else {
                XCTFail("应抛出 .platformNotSupported，实际：\(error)")
                return
            }
        } catch {
            XCTFail("应抛出 FileArchiverError，实际类型：\(type(of: error))")
        }
    }

    // MARK: - Sendable 遵循

    /// 辅助函数：接受 Sendable 值以静态验证 Sendable 遵循
    private func acceptSendable<T: Sendable>(_ value: T) {}

    /// UnsupportedReminderService 应遵循 Sendable
    func testUnsupportedReminderService_遵循Sendable() {
        acceptSendable(UnsupportedReminderService())
    }

    /// UnsupportedExportService 应遵循 Sendable
    func testUnsupportedExportService_遵循Sendable() {
        acceptSendable(UnsupportedExportService())
    }

    /// UnsupportedFileArchiver 应遵循 Sendable
    func testUnsupportedFileArchiver_遵循Sendable() {
        acceptSendable(UnsupportedFileArchiver())
    }
}
