//
//  ModelDownloadLifecycleTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/06/12.
//  Copyright © 2026 WangChong. All rights reserved.
//

import XCTest
import Foundation
import UFPCore
@testable import ZhiYuUnitTestHost

@MainActor
final class ModelDownloadLifecycleTests: XCTestCase {

    private var testModelId: String = "gemma-4-e2b-it"
    private var testFileURL: URL!

    override func setUp() async throws {
        try await super.setUp()
        ServiceContainer.shared.register(RemoteConfigService.shared as any RemoteConfigCapabilities, for: (any RemoteConfigCapabilities).self)
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        testFileURL = docDir.appendingPathComponent("\(testModelId).bin")
    }

    override func tearDown() async throws {
        if let testFileURL, FileManager.default.fileExists(atPath: testFileURL.path) {
            try? FileManager.default.removeItem(at: testFileURL)
        }
        ModelReceiptStore.shared.removeReceipt(for: testModelId)
        GlobalModelManager.shared.clearModelCache(for: testModelId)
        try await super.tearDown()
    }

    // MARK: - 1. Tab 切换防误删与状态持久化测试

    /// 验证大模型文件下载完成（物理文件字节数与预估值不等）后，Tab 切换触发 reload/refresh 绝不静默删除文件，且保持已就绪状态
    func testModelDownloadTabSwitchPersistenceAndNoSilentDelete() async {
        let manager = GlobalModelManager.shared
        
        // 1. Arrange: 写入一个有效内容的大模型权重（大小与白名单中粗估的 1450000000 明确不相等）
        let mockGGUFHeader = Data([0x47, 0x47, 0x55, 0x46]) // "GGUF" 魔数
        var dummyWeightData = mockGGUFHeader
        dummyWeightData.append(Data(repeating: 0xAB, count: 1024 * 64)) // 64KB 非估算整数大小
        
        try? dummyWeightData.write(to: testFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFileURL.path), "沙盒必须已成功写入测试大模型文件")

        // 2. Act: 模拟用户切换 Tab，触发重新加载和沙盒扫描对齐
        await manager.reload()
        manager.refreshLocalModelFiles()

        // 3. Assert: 物理文件绝不能被误判为坏包而静默删除！
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFileURL.path), "模型文件绝不能在切 Tab 或刷新时被误删！")
        
        // 状态必须判定为已就绪，按钮必须为激活，绝不可变回未下载
        let isReady = manager.isModelLocalReady(for: testModelId)
        XCTAssertTrue(isReady, "下载好的模型切 Tab 后必须保持 isModelLocalReady 为 true")
        
        if case .completed = manager.downloadStates[testModelId] {
            // 符合预期
        } else {
            XCTFail("downloadStates 必须保持为 .completed，当前为: \(String(describing: manager.downloadStates[testModelId]))")
        }
    }

    // MARK: - 2. 模型实验室本地离线就绪识别测试

    /// 验证本地大模型已就绪时，进入实验室问答绝不会错误提示“本地大模型未下载”
    func testModelLabOfflineInferenceRecognizesDownloadedModel() async {
        let manager = GlobalModelManager.shared
        let labManager = ModelLabManager()

        // 1. Arrange: 确保沙盒物理文件存在
        let mockGGUFHeader = Data([0x47, 0x47, 0x55, 0x46])
        var dummyWeightData = mockGGUFHeader
        dummyWeightData.append(Data(repeating: 0xCD, count: 1024 * 32))
        try? dummyWeightData.write(to: testFileURL)

        await manager.reload()
        manager.refreshLocalModelFiles()

        let manifest = LLMManifest(
            modelId: testModelId,
            displayName: "Gemma-4-E2B-it",
            vendor: "Google",
            fileSizeInBytes: 1450000000,
            minDeviceMemoryInGb: 6.0,
            remoteURLString: "https://example.com/model.bin",
            sha256Checksum: "",
            parameterCount: "2B",
            supportedTasks: ["chat"],
            description: "On-device local model for testing",
            defaultParameters: InferenceParameters()
        )

        // 2. Act: 模拟在 AI 智能对话中提问
        await labManager.runSimulation(
            for: .aiChat,
            model: manifest,
            prompt: "编写一段 Swift 6 Actor 线程安全缓存示例"
        )

        // 3. Assert: 输出结果绝不能包含“本地大模型未下载”的错误引导文案
        let output = labManager.generatedText
        let notReadyTitle = L10n.ModelManager.Lab.modelNotReadyTitle
        XCTAssertFalse(
            output.contains(notReadyTitle),
            "已下载模型在任务实验室提问时，绝不能误报为未下载！当前输出: \(output)"
        )
    }

    // MARK: - 3. 损坏包异常透明标记测试（绝不静默删除，显式标为失败）

    /// 验证魔数探针精准识别损坏空壳文件，且严格遵循非破坏性原则透明标记失败，绝不在后台静默删除用户文件
    func testModelDownloadCorruptedFileTransparentFailureMarking() async {
        let manager = GlobalModelManager.shared
        await manager.reload()

        // 写入非法伪造损坏文件（不足最小魔数尺寸）
        let corruptData = Data([0x00, 0x01, 0x02])
        try? corruptData.write(to: testFileURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFileURL.path))

        // 执行沙盒扫描对齐
        manager.refreshLocalModelFiles()

        // 1. 严格断言：物理文件现场被保留，绝不静默删除！
        XCTAssertTrue(FileManager.default.fileExists(atPath: testFileURL.path), "工业级规范要求不得后台静默删除用户文件")

        // 2. 状态断言：绝对不能被误判为就绪，必须透明标记为失败
        XCTAssertFalse(manager.isModelLocalReady(for: testModelId))
        if case .failed = manager.downloadStates[testModelId] {
            // 符合预期
        } else {
            XCTFail("损坏文件必须被标记为 .failed")
        }

        // 3. 用户显式触发清理时才物理移除
        manager.clearModelCache(for: testModelId)
        XCTAssertFalse(FileManager.default.fileExists(atPath: testFileURL.path), "用户显式清理时才执行删除")
    }

    // MARK: - 4. 权威完成凭证（Receipt）精准对齐测试

    /// 验证物理文件被意外截断少字节时，通过权威收据精准识别为截断损坏
    func testModelReceiptStoreExactSizeMatchingDetectsTruncation() async {
        let manager = GlobalModelManager.shared
        await manager.reload()

        let mockGGUFHeader = Data([0x47, 0x47, 0x55, 0x46])
        var validData = mockGGUFHeader
        validData.append(Data(repeating: 0xEE, count: 1024 * 64))
        try? validData.write(to: testFileURL)

        // 伪造权威完成凭证（记录完整字节数应为 1024 * 64 + 4）
        let expectedBytes: Int64 = Int64(validData.count) + 500 // 凭据记录的大小比磁盘多 500 字节（模拟文件被截断）
        let receipt = ModelDownloadReceipt(
            modelId: testModelId,
            exactFileSize: expectedBytes,
            completedAt: Date(),
            sha256Checksum: nil,
            format: "gguf"
        )
        ModelReceiptStore.shared.saveReceipt(receipt)

        // 触发扫描
        manager.refreshLocalModelFiles()

        // 断言：由于大小与权威凭据不符，精准识别为损坏截断，绝不放行就绪
        XCTAssertFalse(manager.isModelLocalReady(for: testModelId), "被截断文件绝不能判定为就绪")
        if case .failed = manager.downloadStates[testModelId] {
            // 成功拦截
        } else {
            XCTFail("截断文件必须被标记为 .failed")
        }
    }

    // MARK: - 5. 缺陷 #232 回归：模型下载 SSRF 防护与空白/单点 modelId 文件名兜底

    func testModelDownloadManager_blocksSSRFAndSanitizesBlankOrDotModelID() async throws {
        let localhostURL = try XCTUnwrap(URL(string: "http://127.0.0.1:8080/model.gguf"))
        let fileURL = try XCTUnwrap(URL(string: "file:///etc/passwd"))
        let publicURL = try XCTUnwrap(URL(string: "https://huggingface.co/org/model.gguf"))

        XCTAssertFalse(ModelDownloadManager.isAllowedModelURL(localhostURL))
        XCTAssertFalse(ModelDownloadManager.isAllowedModelURL(fileURL))
        XCTAssertTrue(ModelDownloadManager.isAllowedModelURL(publicURL))

        XCTAssertEqual(ModelDownloadManager.sanitizedDestinationFileName(for: ""), "model.bin")
        XCTAssertEqual(ModelDownloadManager.sanitizedDestinationFileName(for: "   "), "model.bin")
        XCTAssertEqual(ModelDownloadManager.sanitizedDestinationFileName(for: "."), "model.bin")
        XCTAssertEqual(ModelDownloadManager.sanitizedDestinationFileName(for: "bad\0name"), "badname.bin")

        let downloader = ModelDownloadManager(configuration: .ephemeral)
        do {
            try await downloader.startDownload(modelId: "evil", remoteURL: localhostURL)
            XCTFail("指向内网 SSRF 地址的模型下载必须被拒绝")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .unsupportedURL)
        }
    }
}
