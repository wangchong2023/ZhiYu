//
//  StubWatchSyncService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：实现 StubWatchSync 模块的核心业务逻辑服务。
//
import Foundation
import Combine

@MainActor
public final class StubWatchSyncService: NSObject, WatchSyncProtocol {
    @Published public var lastReceivedText: String = ""
    @Published public var latestBriefing: String?
    @Published public var isBriefingLoading: Bool = false

    public override init() {
        super.init()
    }

    /// 发送Content
    /// - Parameter text: text
    public func sendContent(_ text: String) {}
    
    /// 请求DailyBriefing
    public func requestDailyBriefing() {}

    /// 处理BriefingResponse
    /// /// - Parameter text: text
    public func handleBriefingResponse(_ text: String) {}
}
