//
//  iOSWatchSyncService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 平台适配层
//  核心职责：实现 iOSWatchSync 模块的核心业务逻辑服务。
//
#if os(iOS) && !os(watchOS)
import Foundation
import UFPCore
import WatchConnectivity
import Combine

/// iOS 端手表同步实现
final class iOSWatchSyncService: NSObject, WatchSyncProtocol, WCSessionDelegate {
    @Published var lastReceivedText: String = ""
    @Published var latestBriefing: String?
    @Published var isBriefingLoading: Bool = false
    
    /// Factory 风格：属性类型标注为可选（T?），@Inject 自动使用 resolveOptional
    @Inject private var keyStore: (any KeyStoreProtocol)?
    
    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }
    
    /// 发送Content
    /// - Parameter text: text
    func sendContent(_ text: String) {
        let session = WCSession.default
        guard session.activationState == .activated else {
            Logger.shared.warning("WatchSync_Error1")
            return
        }
        guard session.isPaired else {
            Logger.shared.warning("WatchSync_Error2")
            return
        }
        guard session.isWatchAppInstalled else {
            Logger.shared.warning("WatchSync_Error3")
            return
        }
        
        let userInfo = ["type": "new_page", "content": text, "date": Date()] as [String: Any]
        session.transferUserInfo(userInfo)
        Logger.shared.info("WatchSync_Success")
    }
    
    /// 请求DailyBriefing
    func requestDailyBriefing() {
        // iOS 宿主端通常不主动请求，此接口预留
    }
    
    /// 处理BriefingResponse
    /// - Parameter text: text
    func handleBriefingResponse(_ text: String) {
        // iOS 宿主端不处理响应
    }
    
    /// 响应手表的简报请求，生成并推送
    private func generateAndSendBriefing() {
        Task {
            do {
                guard let appStore = ServiceContainer.shared.resolveOptional(AppStore.self),
                      let llmService = ServiceContainer.shared.resolveOptional((any LLMServiceProtocol).self) else {
                    return
                }
                
                let twentyFourHoursAgo = Date().addingTimeInterval(-86400)
                let recentPages = await appStore.pageStore.pages.filter { $0.updatedAt > twentyFourHoursAgo }
                
                guard !recentPages.isEmpty else {
                    sendBriefingToWatch(content: L10n.Watch.briefingNoNewContent)
                    return
                }
                
                // 2. 聚合并使用 LLM 生成简报
                let combinedContent = recentPages.map { "- \($0.title): \($0.content.prefix(100))" }.joined(separator: "\n")
                let prompt = L10n.Watch.briefingPromptTemplate(combinedContent)
                let briefing = try await llmService.generate(prompt: prompt, systemPrompt: L10n.Watch.briefingSystemPrompt)
                
                // 3. 推送回手表
                sendBriefingToWatch(content: briefing)
                
            } catch {
                Logger.shared.error("Briefing_Generation_Failed: \(error)")
                sendBriefingToWatch(content: L10n.Watch.briefingFailed)
            }
        }
    }
    
    private func sendBriefingToWatch(content: String) {
        let session = WCSession.default
        guard session.activationState == .activated && session.isPaired && session.isWatchAppInstalled else {
            return
        }
        let userInfo = ["type": "briefing_response", "content": content] as [String: Any]
        session.transferUserInfo(userInfo)
    }
    
    /// 处理接收到的音频分片并组装，支持乱序到达和自愈拼接 (TC-WAT-03)
    @MainActor

    /// 处理ReceivedAudio分块
    /// /// - Parameter transferId: transferId
    /// /// - Parameter index: 索引
    /// /// - Parameter total: total
    /// /// - Parameter filename: filename
    /// /// - Parameter data: data
    func handleReceivedAudioChunk(transferId: String, index: Int, total: Int, filename: String, data: Data) {
        var assembly = keyStore?.object(forKey: "\(AppConstants.Keys.Storage.iOSAudioAssemblyPrefix)\(transferId)") as? [String: Data] ?? [:]
        assembly["\(index)"] = data
        
        if assembly.count == total {
            var chunks: [Data] = []
            for i in 0..<total {
                if let chunk = assembly["\(i)"] {
                    chunks.append(chunk)
                } else {
                    Logger.shared.warning("Audio_chunk_missing_at_index: \(i)")
                    return
                }
            }
            let mergedData = AudioSplitter.merge(chunks: chunks)
            
            keyStore?.removeObject(forKey: "\(AppConstants.Keys.Storage.iOSAudioAssemblyPrefix)\(transferId)")
            
            self.lastReceivedText = "audio:\(filename):\(mergedData.count)"
            NotificationCenter.default.post(name: .didReceiveWatchAudio, object: mergedData, userInfo: ["filename": filename])
            Logger.shared.info("Audio_transfer_completed_and_merged_successfully: \(filename)")
        } else {
            keyStore?.set(assembly, forKey: "\(AppConstants.Keys.Storage.iOSAudioAssemblyPrefix)\(transferId)")
        }
    }
    
    // MARK: - WCSessionDelegate
    
    /// session回调
    /// - Parameter session: session
    /// - Parameter error: error
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if error != nil {
            Logger.shared.error("WatchSync_Anomaly")
        }
    }
    
    /// sessionDidBecomeInactive回调
    /// - Parameter session: session
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    /// sessionDid停用回调
    /// - Parameter session: session
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    
    /// session回调
    /// - Parameter session: session
    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if let type = userInfo["type"] as? String {
            if type == "request_briefing" {
                Task { @MainActor in
                    self.generateAndSendBriefing()
                }
            } else if type == "new_page", let content = userInfo["content"] as? String {
                Task { @MainActor in
                    self.lastReceivedText = content
                    NotificationCenter.default.post(name: .didReceiveWatchContent, object: content)
                }
            } else if type == "audio_chunk",
                      let transferId = userInfo["transferId"] as? String,
                      let index = userInfo["index"] as? Int,
                      let total = userInfo["total"] as? Int,
                      let filename = userInfo["filename"] as? String,
                      let chunkData = userInfo["data"] as? Data {
                Task { @MainActor in
                    self.handleReceivedAudioChunk(transferId: transferId, index: index, total: total, filename: filename, data: chunkData)
                }
            }
        } else if let content = userInfo["content"] as? String {
            Task { @MainActor in
                self.lastReceivedText = content
                NotificationCenter.default.post(name: .didReceiveWatchContent, object: content)
            }
        }
    }
}

extension iOSWatchSyncService: @unchecked Sendable {}
#endif
