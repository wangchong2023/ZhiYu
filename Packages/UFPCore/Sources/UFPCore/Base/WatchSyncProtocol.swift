//
//  WatchSyncProtocol.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：定义 WatchSync 模块的抽象契约接口。
//
import Foundation
import Combine

/// 跨端通信协议
@MainActor
public protocol WatchSyncProtocol: ObservableObject, Sendable {
    /// 最近接收到的文本
    var lastReceivedText: String { get set }

    /// 最近接收到的语音简报文本
    var latestBriefing: String? { get set }

    /// 简报加载状态
    var isBriefingLoading: Bool { get set }

    /// 向配对设备发送内容
    func sendContent(_ text: String)

    /// 发送音频数据，支持分片传输与断点续传 (TC-WAT-03)
    func sendAudioData(_ data: Data, filename: String)

    /// [Watch 端] 请求 iOS 端合成每日语音简报
    func requestDailyBriefing()

    /// 内部调用：处理接收到的简报数据
    func handleBriefingResponse(_ text: String)
}

extension WatchSyncProtocol {

    /// 发送AudioData
    /// /// - Parameter data: data
    /// /// - Parameter filename: filename
    public func sendAudioData(_ data: Data, filename: String) {}

    /// 处理接收到的 new_page 内容：更新 lastReceivedText 并广播通知。
    /// 消除 iOS/Watch 两端 `didReceiveUserInfo` 中重复的
    /// `lastReceivedText = content; NotificationCenter.post(.didReceiveWatchContent)` 模式。
    public func handleReceivedPageContent(_ content: String) {
        lastReceivedText = content
        NotificationCenter.default.post(name: .didReceiveWatchContent, object: content)
    }
}

extension Notification.Name {
    /// 收到来自手表的同步内容通知
    public static let didReceiveWatchContent = Notification.Name("didReceiveWatchContent")
    /// 收到来自手表的音频数据通知
    public static let didReceiveWatchAudio = Notification.Name("didReceiveWatchAudio")
    /// 收到来自 iOS 端的简报通知
    public static let didReceiveBriefing = Notification.Name("didReceiveBriefing")
    /// 请求简报的通知 (仅限 iOS 端监听)
    public static let didRequestBriefing = Notification.Name("didRequestBriefing")
}
