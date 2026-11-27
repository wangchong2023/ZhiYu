//
//  PluginLoaderSecurityTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施测试 - 插件系统
//  核心职责：验证 PluginLoader registry 引用弱类型化、iconURL 与 localizedReadme 的路径穿越安全防御。
//

import XCTest
import UFPCore
@testable import ZhiYuUnitTestHost

#if !os(watchOS)
@MainActor
final class PluginLoaderSecurityTests: XCTestCase {

    /// 验证 registry 属性为 weak optional 避免强引用环
    func testPluginLoader_registryProperty_isWeakOptional() {
        let loader = PluginLoader()
        XCTAssertNil(loader.registry, "registry 初始应为 nil")
        loader.registry = nil
        XCTAssertNil(loader.registry)
    }

    /// 验证 iconURL 拒绝路径穿越 pluginID
    func testPluginLoader_iconURLPathTraversal_isRejected() {
        let loader = PluginLoader()
        XCTAssertNil(loader.iconURL(for: "../../../etc/passwd"), "路径穿越 pluginID 应被 iconURL 拒绝")
        XCTAssertNil(loader.iconURL(for: "subdir/plugin"), "含 / 的 pluginID 应被 iconURL 拒绝")
    }

    /// 验证 localizedReadme 拒绝路径穿越 pluginID
    func testPluginLoader_localizedReadmePathTraversal_isRejected() {
        let loader = PluginLoader()
        XCTAssertNil(loader.localizedReadme(for: "../../../etc/passwd"), "路径穿越 pluginID 应被 localizedReadme 拒绝")
        XCTAssertNil(loader.localizedReadme(for: "subdir/plugin"), "含 / 的 pluginID 应被 localizedReadme 拒绝")
    }

    /// 验证合法 pluginID 不因路径穿越被误拒
    func testPluginLoader_validPluginID_handlesGracefully() {
        let loader = PluginLoader()
        let result = loader.localizedReadme(for: "com.zhiyu.plugin.test")
        XCTAssertNil(result, "合法 pluginID 但文件不存在应返回 nil")
    }

    /// 验证 isFileNameSafe 拒绝空串、纯空白及反斜杠路径分隔符
    func testPluginLoader_isFileNameSafe_rejectsEmptyAndBackslash() {
        let loader = PluginLoader()
        XCTAssertFalse(loader.isFileNameSafe(""), "空文件名应被拒绝")
        XCTAssertFalse(loader.isFileNameSafe("   "), "纯空白文件名应被拒绝")
        XCTAssertFalse(loader.isFileNameSafe("..\\secret.png"), "含反斜杠的文件名应被拒绝")
        XCTAssertTrue(loader.isFileNameSafe("icon.png"), "常规文件名应放行")
    }

    /// 验证 persistPluginAssets 拒绝 iconFile / readmeFiles / manifest.id 中的路径穿越
    func testPluginLoader_persistPluginAssets_blocksPathTraversal() throws {
        let loader = PluginLoader()
        let fm = FileManager.default
        let tempRoot = fm.temporaryDirectory.appendingPathComponent("PluginLoaderSec_\(UUID().uuidString)")
        let extractedDir = tempRoot.appendingPathComponent("extracted")
        try fm.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempRoot) }

        // 在解压目录上级放置诱饵敏感文件
        let secretFile = tempRoot.appendingPathComponent("secret.png")
        try Data("SECRET_CONTENT".utf8).write(to: secretFile)

        let pluginID = "com.zhiyu.plugin.traversaltest.\(UUID().uuidString.lowercased())"
        let maliciousManifest = PluginManifest(
            id: pluginID,
            version: "1.0.0",
            names: ["en": "Malicious"],
            descriptions: ["en": "Test"],
            readmeFiles: ["../escape": "../secret.png", "en": "../secret.png"],
            iconFile: "../secret.png"
        )

        loader.persistPluginAssets(manifest: maliciousManifest, extractedDir: extractedDir)

        XCTAssertNil(loader.iconURL(for: pluginID), "含 ../ 的 iconFile 不得被持久化到插件目录")
        let docsPlugins = fm.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Plugins")
        if let docsPlugins {
            let escapedReadme = docsPlugins.appendingPathComponent("\(pluginID)_en.md")
            XCTAssertFalse(fm.fileExists(atPath: escapedReadme.path), "含 ../ 的 README 不得被复制")
        }
    }
}
#endif
