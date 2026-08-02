//
//  MacPlatformTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 MacPlatform 开展自动化单元测试验证。
//
import XCTest
import LocalAuthentication
#if os(macOS)
import AppKit
#else
@testable import ZhiYu
#endif

#if os(macOS)
/// 模拟 LAContext 用于测试生物识别逻辑，通过重写方法实现非阻塞回复
final class MockLAContext: LAContext, @unchecked Sendable {
    var mockSuccess = true
    
    override func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping (Bool, Error?) -> Void) {
        reply(mockSuccess, nil)
    }
}
#endif

/// 验证 macOS 专属服务逻辑的单元测试用例
@MainActor
final class MacPlatformTests: XCTestCase {
    
    /// 测试 MacFileArchiver 的压缩归档成功与失败场景
    func testMacFileArchiverZip() async throws {
        #if os(macOS)
        let archiver = MacFileArchiver()
        let fm = FileManager.default
        
        // 1. 创建测试专用的临时源目录
        let sourceDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: sourceDir, withIntermediateDirectories: true)
        
        // 2. 写入测试文本文件
        let testFile = sourceDir.appendingPathComponent("test.txt")
        let testContent = "智宇 macOS 归档测试内容"
        try testContent.write(to: testFile, atomically: true, encoding: .utf8)
        
        // 3. 准备目标 zip 路径
        let destinationZip = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        
        // 4. 执行归档操作 (成功路径)
        do {
            try await archiver.zip(directory: sourceDir, to: destinationZip)
            XCTAssertTrue(fm.fileExists(atPath: destinationZip.path), "生成的 ZIP 压缩包应当存在")
        } catch {
            XCTFail("归档执行异常失败: \(error.localizedDescription)")
        }
        
        // 5. 执行失败归档（尝试向非法路径写 zip 以触发 process.terminationStatus != 0）
        let invalidZipURL = URL(fileURLWithPath: "/nonexistent_folder/failed_test.zip")
        do {
            try await archiver.zip(directory: sourceDir, to: invalidZipURL)
            XCTFail("对于非法的目标路径，压缩操作应当失败并抛出错误")
        } catch {
            // 预期抛出错误
            XCTAssertNotNil(error, "应当能正常捕获到归档失败的异常")
        }
        
        // 6. 清理现场
        try? fm.removeItem(at: sourceDir)
        try? fm.removeItem(at: destinationZip)
        #endif
    }
    
    /// 测试 MacOSBiometricAuthProvider 策略和能力检查
    func testMacOSBiometricAuthProvider() {
        #if os(macOS)
        let provider = MacOSBiometricAuthProvider()
        
        // 1. 验证安全策略类型是否为 deviceOwnerAuthenticationWithBiometrics
        XCTAssertEqual(provider.authenticationPolicy, .deviceOwnerAuthenticationWithBiometrics, "macOS 生物识别策略应为 deviceOwnerAuthenticationWithBiometrics")
        
        // 2. 验证 canEvaluatePolicy 返回值，因测试环境无物理硬件，仅验证方法调用不会崩溃
        let context = LAContext()
        _ = provider.canEvaluatePolicy(context: context)
        #endif
    }
    
    /// 测试 MacOSBiometricAuthProvider 的生物识别策略评估功能
    func testMacOSBiometricAuthProviderEvaluate() async {
        #if os(macOS)
        let provider = MacOSBiometricAuthProvider()
        let mockContext = MockLAContext()
        
        // 1. 模拟评估成功路径
        mockContext.mockSuccess = true
        let successResult = await provider.evaluatePolicy(context: mockContext, reason: "测试生物识别成功")
        XCTAssertTrue(successResult, "模拟成功时评估应当返回 true")
        
        // 2. 模拟评估失败路径
        mockContext.mockSuccess = false
        let failResult = await provider.evaluatePolicy(context: mockContext, reason: "测试生物识别失败")
        XCTAssertFalse(failResult, "模拟失败时评估应当返回 false")
        #endif
    }
    
    /// 测试 MacOSSecurityScopedStorage 安全书签的保存与解析
    func testMacOSSecurityScopedStorage() {
        #if os(macOS)
        let storage = MacOSSecurityScopedStorage()
        let fm = FileManager.default
        
        // 1. 模拟对本地临时文件生成真实合法的安全书签，并验证读取与无损解析路径
        let testURL = fm.temporaryDirectory.appendingPathComponent("test_scoped_file")
        try? "scoped".write(to: testURL, atomically: true, encoding: .utf8)
        
        // 1.1 触发存储
        storage.storeBookmark(for: testURL)
        
        // 1.2 从 UserDefaults 读出刚刚存入的有效书签数据，并调用解析以覆盖成功路径
        let key = AppConstants.Keys.Storage.vaultBookmarkPrefix + testURL.lastPathComponent
        if let savedData = UserDefaults.standard.data(forKey: key) {
            let restored = storage.restoreURL(from: savedData)
            XCTAssertNotNil(restored, "有效的安全书签应当能被成功解析")
            XCTAssertEqual(restored?.resolvingSymlinksInPath(), testURL.resolvingSymlinksInPath())
        }
        
        // 2. 模拟非 file 协议的 URL (如 https 网址)，触发 url.bookmarkData 抛错分支
        let httpsURL = URL(string: "https://www.google.com")!
        storage.storeBookmark(for: httpsURL) // 触发 catch print
        
        // 3. 验证从非法字节数据解析 Bookmark 是否能正确防错并返回 nil
        let invalidBookmarkData = Data([0x00, 0x01, 0x02, 0x03])
        let restoredURL = storage.restoreURL(from: invalidBookmarkData)
        XCTAssertNil(restoredURL, "无效书签数据解析后应返回 nil")
        
        // 4. 清理文件与缓存
        try? fm.removeItem(at: testURL)
        UserDefaults.standard.removeObject(forKey: key)
        #endif
    }
    
    /// 测试 MacPasteboardService 剪贴板文本读写及 NSImage 扩展
    func testMacPasteboardService() {
        #if os(macOS)
        let service = MacPasteboardService()
        let testString = "智宇 macOS 剪贴板测试文本"
        
        // 1. 测试设置与读取字符串
        service.string = testString
        XCTAssertEqual(service.string, testString, "读取到的剪贴板内容应与写入内容一致")
        
        // 2. 测试清空剪贴板
        service.string = nil
        XCTAssertNil(service.string, "清空后剪贴板内容应当为 nil")
        
        // 3. 测试 NSImage 的 appCGImage 扩展转换（即使是空图像也不崩溃且安全返回）
        let emptyImage = NSImage(size: NSSize(width: DesignSystem.Metrics.snapshotEmptyImageSize, height: DesignSystem.Metrics.snapshotEmptyImageSize))
        let cgImage = emptyImage.appCGImage
        // 空画布没有图像表象时可能返回 nil，重点验证不发生崩溃
        XCTAssertNil(cgImage, "未绘制内容的空图像 CGImage 应当为 nil")
        #endif
    }
}
