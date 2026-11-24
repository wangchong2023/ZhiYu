//
//  iCloudSyncIntegrationTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 iCloudSyncIntegration 开展自动化单元测试验证。
//
#if ICLOUD_ENABLED
import XCTest
import Combine
@testable import ZhiYuUnitTestHost

@MainActor
final class iCloudSyncIntegrationTests: XCTestCase {
    var syncManager: iCloudSyncManager!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        // 获取单例，重置相关的 UserDefaults 测试状态
        syncManager = iCloudSyncManager.shared
        
        // 清理本地状态，防止受上次测试污染
        UserDefaults.standard.removeObject(forKey: "llm_api_key")
        UserDefaults.standard.removeObject(forKey: "llm_model")
    }
    
    @MainActor
    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: "llm_api_key")
        UserDefaults.standard.removeObject(forKey: "llm_model")
        try await super.tearDown()
    }
    
    /// 测试验证：本地发起 pushToCloud 应当能将数据写入 NSUbiquitousKeyValueStore
    func testPushToCloudWritesToUbiquitousStore() {
        let testKey = "llm_model"
        let testValue = "gpt-4-turbo"
        
        syncManager.pushToCloud(key: testKey, value: testValue)
        
        // 验证 NSUbiquitousKeyValueStore 中的确存入了该值
        let cloudValue = NSUbiquitousKeyValueStore.default.string(forKey: testKey)
        XCTAssertEqual(cloudValue, testValue, "pushToCloud 方法未能将数据成功同步至 iCloud KV Store")
    }
    
    /// 测试验证：模拟 iCloud KV Store 从外部发出的变更通知，验证本地 UserDefaults 是否能自动热同步
    func testExternallyChangedNotificationTriggersLocalUpdate() {
        let testKey = "llm_api_key"
        let newCloudValue = "sk-cloud-test-key-123"
        
        // 1. 模拟在另一台设备上修改了云端数据
        NSUbiquitousKeyValueStore.default.set(newCloudValue, forKey: testKey)
        
        // 2. 派发系统的通知，假装从 iCloud 拉取到了外部数据变化
        NotificationCenter.default.post(name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default)
        
        // 3. 验证本地 UserDefaults 是否成功被 iCloudSyncManager 监听到并覆盖
        let localValue = UserDefaults.standard.string(forKey: testKey)
        XCTAssertEqual(localValue, newCloudValue, "iCloudSyncManager 没有正确监听 didChangeExternallyNotification 并将云端拉取结果映射回本地 UserDefaults")
    }
}
#endif
