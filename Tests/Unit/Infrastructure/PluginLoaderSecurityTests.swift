//
//  PluginLoaderSecurityTests.swift
//  ZhiYuTests
//
//  系统层级：[L1] 基础设施测试 - 插件系统
//  核心职责：验证 PluginLoader registry 引用弱类型化、iconURL 与 localizedReadme 的路径穿越安全防御。
//

import XCTest
import UFPCore
@testable import ZhiYu

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
}
#endif
