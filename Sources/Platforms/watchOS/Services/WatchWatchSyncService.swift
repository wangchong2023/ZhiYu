//
//  WatchWatchSyncService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：实现 WatchWatchSync 模块的核心业务逻辑服务。
//
#if os(watchOS)
import Foundation
import UFPCore
import WatchConnectivity
import Combine
import Dependencies

/// watchOS 端同步实现
final class WatchWatchSyncService: NSObject, WatchSyncProtocol, WCSessionDelegate {
    @Published var lastReceivedText: String = ""
    @Published var latestBriefing: String?
    @Published var isBriefingLoading: Bool = false
    
    /// 激活状态提供者闭包，支持构造注入解耦测试
    private let activationStateProvider: () -> WCSessionActivationState

    /// Factory 风格：可选依赖，DI 未就绪时为 nil
    @Dependency(\.keyStore) private var keyStore: (any KeyStoreProtocol)?
    
    /// 获取当前会话激活状态
    private var currentActivationState: WCSessionActivationState {
        activationStateProvider()
    }
    
    init(activationStateProvider: @escaping () -> WCSessionActivationState = { WCSession.default.activationState }) {
        self.activationStateProvider = activationStateProvider
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
            triggerPendingTransfers()
        }
    }
    
    /// 将文字笔记数据发送给配对的 iPhone 宿主
    /// - Parameter text: 待同步的文本内容
    func sendContent(_ text: String) {
        guard currentActivationState == .activated else { return }
        let userInfo = ["type": "new_page", "content": text, "date": Date()] as [String: Any]
        WCSession.default.transferUserInfo(userInfo)
    }
    
    /// 分片传输大音频数据，支持断点续传自愈 (TC-WAT-03)
    func sendAudioData(_ data: Data, filename: String) {
        let transferId = UUID().uuidString
        let chunks = AudioSplitter.split(data: data)
        let total = chunks.count
        
        var pendingTransfers = keyStore?.object(forKey: AppConstants.Keys.Storage.watchPendingAudioTransfers) as? [String: [String: Any]] ?? [:]
        
        var chunkDicts: [[String: Any]] = []
        for (index, chunk) in chunks.enumerated() {
            let chunkInfo: [String: Any] = [
                "transferId": transferId,
                "index": index,
                "total": total,
                "filename": filename,
                "data": chunk,
                "sent": false
            ]
            chunkDicts.append(chunkInfo)
        }
        
        pendingTransfers[transferId] = [
            "filename": filename,
            "total": total,
            "chunks": chunkDicts
        ]
        keyStore?.set(pendingTransfers, forKey: AppConstants.Keys.Storage.watchPendingAudioTransfers)
        
        triggerPendingTransfers()
    }
    
    /// 触发并尝试发送所有挂起的音频分片自愈任务
    func triggerPendingTransfers() {
        guard currentActivationState == .activated else { return }
        let session = WCSession.default
        
        guard var pendingTransfers = keyStore?.object(forKey: AppConstants.Keys.Storage.watchPendingAudioTransfers) as? [String: [String: Any]] else { return }
        
        var hasUpdates = false
        for (transferId, transferInfo) in pendingTransfers {
            guard var chunks = transferInfo["chunks"] as? [[String: Any]] else { continue }
            
            for (i, var chunk) in chunks.enumerated() {
                let sent = chunk["sent"] as? Bool ?? false
                if !sent {
                    let payload: [String: Any] = [
                        "type": "audio_chunk",
                        "transferId": transferId,
                        "index": chunk["index"] as? Int ?? 0,
                        "total": chunk["total"] as? Int ?? 0,
                        "filename": chunk["filename"] as? String ?? "",
                        "data": chunk["data"] as? Data ?? Data(),
                        "date": Date()
                    ]
                    session.transferUserInfo(payload)
                    chunk["sent"] = true
                    chunks[i] = chunk
                    hasUpdates = true
                }
            }
            
            var updatedInfo = transferInfo
            updatedInfo["chunks"] = chunks
            
            let allSent = chunks.allSatisfy { $0["sent"] as? Bool ?? false }
            if allSent {
                pendingTransfers.removeValue(forKey: transferId)
            } else {
                pendingTransfers[transferId] = updatedInfo
            }
            hasUpdates = true
        }
        
        if hasUpdates {
            keyStore?.set(pendingTransfers, forKey: AppConstants.Keys.Storage.watchPendingAudioTransfers)
        }
    }
    
    /// 向 iOS 端请求生成语音简报
    func requestDailyBriefing() {
        isBriefingLoading = true
        guard currentActivationState == .activated else {
            isBriefingLoading = false
            return
        }
        let userInfo = ["type": "request_briefing"] as [String: Any]
        WCSession.default.transferUserInfo(userInfo)
    }
    
    /// 处理BriefingResponse
    /// /// - Parameter text: text
    func handleBriefingResponse(_ text: String) {
        latestBriefing = text
        isBriefingLoading = false
        NotificationCenter.default.post(name: .didReceiveBriefing, object: text)
    }
    
    // MARK: - WCSessionDelegate
    
    /// session回调
    /// - Parameter session: session
    /// - Parameter error: error
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if error != nil {
            Logger.shared.error("WatchSync_Anomaly2")
        } else if activationState == .activated {
            let delegate = session.delegate as? WatchWatchSyncService
            Task { @MainActor [weak delegate] in
                delegate?.triggerPendingTransfers()
            }
        }
    }
    
    /// session回调
    /// - Parameter session: session
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        let type = userInfo["type"] as? String
        let contentStr = userInfo["content"] as? String
        
        Task { @MainActor in
            if type == "briefing_response", let content = contentStr {
                self.handleBriefingResponse(content)
            } else if type == "new_page", let content = contentStr {
                self.handleReceivedPageContent(content)
            } else if let content = contentStr {
                self.handleReceivedPageContent(content)
            }
        }
    }
}

extension WatchWatchSyncService: @unchecked Sendable {}
#endif
