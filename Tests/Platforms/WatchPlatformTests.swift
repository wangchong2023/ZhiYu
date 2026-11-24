//
//  WatchPlatformTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 WatchPlatform 开展自动化单元测试验证。
//
import XCTest
import LocalAuthentication
#if os(watchOS)
@testable import ZhiYuWatch
#else
@testable import ZhiYuUnitTestHost
#endif

/// 验证 watchOS 专有平台能力降级类 (Stub) 的行为
final class WatchPlatformTests: XCTestCase {

    /// 测试 WatchModelCompiler 降级机制
    /// 验证其 supportsCompilation 返回 false，且 compileModel 方法能正确抛出不可编译的 NSError 异常
    func testWatchModelCompilerThrows() async {
        let compiler = WatchModelCompiler()
        
        // 1. 验证是否声明不支持运行时模型编译
        XCTAssertFalse(compiler.supportsCompilation, "WatchModelCompiler 应该声明不支持模型编译")
        
        // 2. 验证调用 compileModel 时抛出特定的降级异常
        let testURL = URL(fileURLWithPath: "/tmp/test.mlmodel")
        do {
            _ = try await compiler.compileModel(at: testURL)
            XCTFail("WatchModelCompiler.compileModel 应该抛出异常，但却成功执行了")
        } catch {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "WatchModelCompiler", "抛出的错误 Domain 应该是 WatchModelCompiler")
            XCTAssertEqual(nsError.code, -1, "错误码应该为 -1")
            XCTAssertTrue(
                nsError.localizedDescription.contains("watchOS does not support model compilation"),
                "错误描述信息应该包含不支持编译的提示"
            )
        }
    }

    /// 测试 WatchSecurityScopedStorage 书签存根行为
    /// 验证其 restoreURL 返回 nil，且 storeBookmark 调用时不会触发崩溃
    func testWatchSecurityScopedStorageStub() {
        let storage = WatchSecurityScopedStorage()
        
        // 1. 验证存储书签不引发任何异常或崩溃
        let testURL = URL(fileURLWithPath: "/tmp/bookmark_test")
        XCTAssertNoThrow(storage.storeBookmark(for: testURL), "存储书签应该安全地忽略而不抛出异常")
        
        // 2. 验证恢复书签始终返回 nil
        let dummyData = Data([0, 1, 2])
        let restoredURL = storage.restoreURL(from: dummyData)
        XCTAssertNil(restoredURL, "watchOS 书签恢复应该始终返回 nil 降级值")
    }

    /// 测试 WatchBiometricAuthProvider 的可用性查询与鉴权接口
    /// 通过注入 MockLAContext 来验证其在可用/不可用、成功/失败场景下的逻辑，且绝对不唤起系统安全认证弹窗，规避卡死
    @MainActor
    func testWatchBiometricAuthProviderInterface() async {
        let mockContext = MockLAContext()
        mockContext.mockCanEvaluatePolicyResult = true
        mockContext.mockEvaluatePolicyResult = true
        
        let provider = WatchBiometricAuthProvider()
        
        // 1. 验证 canEvaluatePolicy
        let isAvailable = provider.canEvaluatePolicy(context: mockContext)
        XCTAssertTrue(isAvailable, "当 MockContext 返回可用时，provider 应当为 true")
        
        // 2. 验证 evaluatePolicy 成功场景，应当返回 true
        let successResult = await provider.evaluatePolicy(context: mockContext, reason: "Test authentication success")
        XCTAssertTrue(successResult, "当 MockContext 授权成功时，provider 应当返回 true")
        
        // 3. 验证 evaluatePolicy 失败场景，应当返回 false
        mockContext.mockEvaluatePolicyResult = false
        let failResult = await provider.evaluatePolicy(context: mockContext, reason: "Test authentication failure")
        XCTAssertFalse(failResult, "当 MockContext 授权失败时，provider 应当返回 false")
    }
    
    /// 测试 WatchOCRService 降级行为
    @MainActor
    func testWatchOCRServiceStub() async throws {
        let service = WatchOCRService()
        // 验证 recognizeText(from:) 返回空字符串，不抛出异常
        let image = AppImage()
        let text = try await service.recognizeText(from: image)
        XCTAssertEqual(text, "", "watchOS OCR 存根应该返回空字符串")
    }
    
    /// 测试 WatchPDFService 降级行为
    @MainActor
    func testWatchPDFServiceStub() async {
        let service = WatchPDFService()
        
        let dummyData = Data()
        let url = try XCTUnwrap(URL(string: "file:///tmp/test.pdf"))
        
        let savedURL = await service.savePDF(data: dummyData, fileName: "test.pdf")
        XCTAssertNil(savedURL, "watchOS PDF 存根应该返回 nil URL")
        
        let deleted = await service.deletePDF(fileName: "test.pdf")
        XCTAssertFalse(deleted, "watchOS PDF 存根删除应该返回 false")
        
        let allFiles = await service.allPDFFilenames()
        XCTAssertTrue(allFiles.isEmpty, "watchOS PDF 存根文件列表应该为空")
        
        let getURL = service.getPDFURL(fileName: "test.pdf")
        XCTAssertNil(getURL, "watchOS PDF 存根获取 URL 应该返回 nil")
        
        let text1 = await service.extractText(from: url)
        XCTAssertNil(text1, "watchOS PDF 存根提取文本应该返回 nil")
        
        let text2 = await service.extractText(from: url, pageRange: 0..<1)
        XCTAssertNil(text2, "watchOS PDF 存根提取分页文本应该返回 nil")
        
        // 验证 saveDocumentsInfo 和 loadDocumentsInfo
        await service.saveDocumentsInfo([])
        let loadedInfo = await service.loadDocumentsInfo()
        XCTAssertTrue(loadedInfo.isEmpty, "watchOS PDF 存根加载 info 应该为空")
    }
    
    /// 测试 WatchPasteboardService 降级行为
    @MainActor
    func testWatchPasteboardServiceStub() {
        let service = WatchPasteboardService()
        
        // 验证 getter 返回 nil
        XCTAssertNil(service.string, "watchOS 剪贴板存根读取应该为 nil")
        
        // 验证 setter 安全执行且不影响 getter
        service.string = "test"
        XCTAssertNil(service.string, "watchOS 剪贴板存根在写入后应该仍为 nil")
    }
    
    /// 测试 WatchSpeechService 存根及可观察对象行为
    @MainActor
    func testWatchSpeechServiceStub() async throws {
        let service = WatchSpeechService()
        
        // 1. 验证默认属性值
        XCTAssertFalse(service.isRecording)
        XCTAssertFalse(service.isTranscribing)
        XCTAssertEqual(service.transcribedText, "")
        XCTAssertEqual(service.audioLevel, 0)
        XCTAssertEqual(service.audioLevelHistory.count, 20)
        XCTAssertEqual(service.statusMessage, "Not Supported")
        XCTAssertTrue(service.supportedLanguages.isEmpty)
        XCTAssertEqual(service.selectedLanguage, "zh-CN")
        XCTAssertFalse(service.hasPermission)
        XCTAssertTrue(service.recordings.isEmpty)
        
        // 2. 验证接口调用无崩溃且不发生改变
        service.checkPermission()
        service.startRecording()
        service.stopRecording()
        service.clearTranscription()
        
        let text = try await service.transcribeFile(url: URL(fileURLWithPath: "/tmp/audio.wav"))
        XCTAssertEqual(text, "", "watchOS 语音转写存根应返回空字符串")
        
        let recording = service.saveRecording(title: "Test")
        XCTAssertNotNil(recording, "watchOS 语音保存应返回有效的录音对象")
        
        service.deleteRecording(recording)
    }
}

// MARK: - Mock 辅助类

/// 用于测试的 MockLAContext，重写 canEvaluatePolicy 和 evaluatePolicy 方法，避免在单元测试运行时弹出系统身份验证弹窗
private final class MockLAContext: LAContext {
    /// 模拟 canEvaluatePolicy 的返回值
    var mockCanEvaluatePolicyResult: Bool = false
    /// 模拟 evaluatePolicy 的返回值
    var mockEvaluatePolicyResult: Bool = false
    
    /// 重写 canEvaluatePolicy
    override func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool {
        return mockCanEvaluatePolicyResult
    }
    
    /// 重写 evaluatePolicy
    override func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping (Bool, Error?) -> Void) {
        // 直接同步回调模拟结果，避开异步多线程闭包捕获，防止 Swift 6 并发警报，且能正常唤起回调
        reply(mockEvaluatePolicyResult, nil)
    }
}
