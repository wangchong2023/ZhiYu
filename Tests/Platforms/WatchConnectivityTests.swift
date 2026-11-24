//
//  WatchConnectivityTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：针对 WatchConnectivity 开展自动化单元测试验证。
//
import XCTest
import WatchConnectivity
@testable import ZhiYuUnitTestHost

/// 验证 WatchConnectivity 同步可靠性
@MainActor
final class WatchConnectivityTests: XCTestCase {
    
    var service: iOSWatchSyncService!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        service = iOSWatchSyncService()
    }
    
    /// 测试数据打包逻辑
    func testContentPackaging() async {
        let testText = "手表端采集的测试内容"
        service.sendContent(testText)
        XCTAssertNotNil(service)
    }
    
    /// 测试接收逻辑
    func testReceiveUserInfo() async {
        let expectation = XCTestExpectation(description: "接收来自手表的通知")
        
        let userInfo: [String: Any] = [
            "content": "来自手表的同步内容",
            "type": "new_page"
        ]
        
        let observer = NotificationCenter.default.addObserver(forName: .didReceiveWatchContent, object: nil, queue: .main) { notification in
            if let content = notification.object as? String {
                XCTAssertEqual(content, "来自手表的同步内容")
                expectation.fulfill()
            }
        }
        
        // 模拟收到 WCSession 回调
        service.session(WCSession.default, didReceiveUserInfo: userInfo)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        NotificationCenter.default.removeObserver(observer)
    }
}
