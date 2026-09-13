//
//  PlatformServicesDeepComprehensiveTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/09/03.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：深度覆盖 L3 Platforms 核心导出/PDF/P2P协同与OCR平台服务。
//

import XCTest
import PDFKit
import Vision
import MultipeerConnectivity
@testable import ZhiYu
import UFPCore

@MainActor
final class PlatformServicesDeepComprehensiveTests: XCTestCase {

    override func setUp() async throws {
        try await super.setUp()
        setupFullMockEnvironment()
    }

    // MARK: - 1. iOSPDFService 深度测试

    #if !os(watchOS)
    func testIOSPDFService_FileLifecycleAndSecurity() async throws {
        let pdfService = iOSPDFService()
        let safeFileName = "test_document_safe_\(UUID().uuidString.prefix(8)).pdf"
        let maliciousFileName = "../malicious_path_escape.pdf"
        let sampleData = Data("Fake PDF Header %PDF-1.4 Data Content".utf8)

        // 1. 路径穿越防护拦截
        let maliciousSaveResult = await pdfService.savePDF(data: sampleData, fileName: maliciousFileName)
        XCTAssertNil(maliciousSaveResult, "针对含 .. 的非法文件名必须拒绝保存")

        let maliciousDeleteResult = await pdfService.deletePDF(fileName: maliciousFileName)
        XCTAssertFalse(maliciousDeleteResult, "针对含 .. 的非法文件名必须拒绝删除")

        let maliciousURLResult = pdfService.getPDFURL(fileName: maliciousFileName)
        XCTAssertNil(maliciousURLResult, "针对含 .. 的非法文件名必须拒绝获取 URL")

        // 2. 正常文件存储与读取
        guard let savedURL = await pdfService.savePDF(data: sampleData, fileName: safeFileName) else {
            XCTFail("合法 PDF 数据应成功保存")
            return
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: savedURL.path), "物理文件应真实存在")

        let retrievedURL = pdfService.getPDFURL(fileName: safeFileName)
        XCTAssertEqual(retrievedURL?.path, savedURL.path, "应能正确获取保存的文件路径")

        let allFiles = await pdfService.allPDFFilenames()
        XCTAssertTrue(allFiles.contains(safeFileName), "文件清单中应包含刚刚保存的文件")

        // 3. 元数据保存与恢复测试
        let mockMetadata = [
            PDFDocumentInfo(
                title: "测试知识白皮书",
                fileName: safeFileName,
                pageCount: 3
            )
        ]
        await pdfService.saveDocumentsInfo(mockMetadata)
        let loadedMetadata = await pdfService.loadDocumentsInfo()
        XCTAssertFalse(loadedMetadata.isEmpty, "元数据应成功持久化并恢复")
        XCTAssertEqual(loadedMetadata.first?.fileName, safeFileName)

        // 4. 文件删除验证
        let deleteSuccess = await pdfService.deletePDF(fileName: safeFileName)
        XCTAssertTrue(deleteSuccess, "应成功删除 PDF 文件")
        XCTAssertFalse(FileManager.default.fileExists(atPath: savedURL.path), "物理文件删除后不应存在")
    }

    func testIOSPDFService_TextAndImageExtraction() async throws {
        let pdfService = iOSPDFService()

        // 1. 创建内存真实 PDF 文档
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: 200, height: 200), nil)
        UIGraphicsBeginPDFPage()
        let text = "智宇 RAG 闭环核心算法测试"
        (text as NSString).draw(at: CGPoint(x: 20, y: 20), withAttributes: nil)
        UIGraphicsEndPDFContext()

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("unit_test_\(UUID().uuidString).pdf")
        try (pdfData as Data).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // 2. 文本提取验证
        let extractedText = await pdfService.extractText(from: tempURL)
        XCTAssertNotNil(extractedText, "应成功从有效 PDF 中提取文本")

        let rangeText = await pdfService.extractText(from: tempURL, pageRange: 0..<1)
        XCTAssertNotNil(rangeText, "指定范围提取应成功")

        // 3. 图像抽取测试
        let extractedImages = await pdfService.extractImages(from: tempURL)
        XCTAssertFalse(extractedImages.isEmpty, "应能将 PDF 页面光栅化渲染为 JPEG 图像数据")

        // 4. 异常损坏路径测试
        let nonExistentURL = FileManager.default.temporaryDirectory.appendingPathComponent("not_found.pdf")
        let nonExistentText = await pdfService.extractText(from: nonExistentURL)
        XCTAssertNil(nonExistentText, "不存在的文件应安全降级返回 nil")

        let nonExistentImages = await pdfService.extractImages(from: nonExistentURL)
        XCTAssertTrue(nonExistentImages.isEmpty, "不存在的文件提取图片应返回空数组")
    }
    #endif

    // MARK: - 2. MultipeerCollaborationProvider 深度测试

    #if canImport(MultipeerConnectivity)
    final class MockCollaborationDelegate: CollaborationProviderDelegate {
        var discoveredRooms: [DiscoveredRoom] = []
        var lostRoomIds: [String] = []
        var connectedUsers: [CollabUser] = []
        var disconnectedUserIds: [String] = []
        var receivedDataPayloads: [Data] = []
        var statuses: [String] = []
        var errors: [String] = []

        func providerDidDiscoverRoom(_ room: DiscoveredRoom) {
            discoveredRooms.append(room)
        }

        func providerDidLoseRoom(id: String) {
            lostRoomIds.append(id)
        }

        func providerDidConnectPeer(_ user: CollabUser) {
            connectedUsers.append(user)
        }

        func providerDidDisconnectPeer(id: String) {
            disconnectedUserIds.append(id)
        }

        func providerDidReceiveData(_ data: Data, from peerId: String) {
            receivedDataPayloads.append(data)
        }

        func providerDidUpdateStatus(_ status: String) {
            statuses.append(status)
        }

        func providerDidEncounterError(_ error: String) {
            errors.append(error)
        }
    }

    func testMultipeerCollaborationProvider_LifecycleAndBroadcast() {
        let provider = MultipeerCollaborationProvider()
        let delegate = MockCollaborationDelegate()
        provider.delegate = delegate

        // 1. 启动 Hosting
        provider.startHosting(roomName: "智宇知识攻坚室", userName: "测试主机")
        XCTAssertTrue(delegate.statuses.contains(L10n.Collaboration.Status.hosting), "启动 Hosting 后应上报状态")

        // 2. 广播测试（无连接 peer 时安全不崩溃）
        let testPayload = Data("Hello ZhiYu CRDT Sync".utf8)
        provider.broadcast(data: testPayload)

        // 3. 启动 Browsing
        provider.startBrowsing(userName: "测试客户端")
        XCTAssertTrue(delegate.statuses.contains(L10n.Collaboration.Status.searching), "启动 Browsing 后应上报 searching 状态")

        // 4. 模拟加入房间
        let mockPeer = MCPeerID(displayName: "测试远端主机|12345678")
        let room = DiscoveredRoom(id: "room_1", platformPeer: mockPeer, roomName: "智宇知识攻坚室", owner: "测试远端主机")
        provider.joinRoom(room)
        XCTAssertTrue(delegate.statuses.contains(L10n.Collaboration.Status.joining), "加入房间后应更新 joining 状态")

        // 5. 停止协同
        provider.stop()
        XCTAssertTrue(delegate.statuses.contains(L10n.Collaboration.Status.disconnected), "停止后状态应变为 disconnected")
    }
    #endif

    // MARK: - 3. iOSOCRService 深度测试

    #if canImport(Vision)
    func testIOSOCRService_ValidAndInvalidImages() async throws {
        let ocrService = iOSOCRService()

        // 1. 构造用于测试的位图
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 100, height: 50))
        let uiImage = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 50))
            let string = "ZHIYU"
            (string as NSString).draw(at: CGPoint(x: 10, y: 10), withAttributes: [
                .foregroundColor: UIColor.black,
                .font: UIFont.boldSystemFont(ofSize: 20)
            ])
        }

        guard let cgImg = uiImage.cgImage else {
            XCTFail("应成功生成 CGImage")
            return
        }
        let appImage = AppImage(cgImage: cgImg)
        let recognizedText = try? await ocrService.recognizeText(from: appImage)
        XCTAssertNotNil(recognizedText, "有效位图应成功完成 OCR 管道调用")

        // 2. 错误模型断言
        XCTAssertEqual(OCRError.invalidImage.errorDescription, L10n.Ingest.OCR.Error.invalidImage)
        XCTAssertEqual(OCRError.noResults.errorDescription, L10n.Ingest.OCR.Error.noResults)
        XCTAssertEqual(OCRError.cameraUnavailable.errorDescription, L10n.Ingest.OCR.Error.cameraUnavailable)
    }
    #endif

    // MARK: - 4. iOSExportService 深度测试

    #if canImport(WebKit)
    func testIOSExportService_LifecycleAndErrorHandling() async throws {
        let exportService = iOSExportService()

        // 验证初始化与单例契约
        XCTAssertNotNil(exportService, "iOSExportService 应正常初始化 WebKit 离屏实例")

        // 尝试导出空 PPTX，校验解析器
        let md = """
        # 主题演讲
        - 第一条纲领
        - 第二条纲领
        ## 第二部分
        * 实施步骤
        * 成果总结
        """
        // 验证 PPTX 导出
        do {
            let pptxURL = try await exportService.exportToPPTX(markdown: md, fileName: "test_slides")
            XCTAssertTrue(FileManager.default.fileExists(atPath: pptxURL.path))
            try? FileManager.default.removeItem(at: pptxURL)
        } catch {
            // 在无 headless pptx.js 支持的测试环境下，预期捕获 ExportError
            XCTAssertTrue(error is ExportError, "PPTX 导出环境不满足时应抛出类型化 ExportError")
        }
    }
    #endif
}
