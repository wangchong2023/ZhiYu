//
//  LocalAnalyticsService.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：实现 LocalAnalytics 模块的核心业务逻辑服务。
//
import Foundation

/// 基础分析服务实现：目前仅打印日志，未来可接入端侧埋点或 Firebase
@MainActor
final class LocalAnalyticsService: AnalyticsServiceProtocol, @unchecked Sendable {
    static let shared = LocalAnalyticsService()

    private let logURL: URL

    init(logURL: URL? = nil) {
        if let customURL = logURL {
            self.logURL = customURL
        } else {
            // 文档目录获取失败时降级到临时目录，避免启动崩溃（分析日志非关键路径）
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.logURL = docs.appendingPathComponent("analytics_log.json")
        }
    }
    
    /// 追踪Event
    /// - Parameter name: name
    /// - Parameter properties: properties
    func trackEvent(_ name: String, properties: [String: Any]? = nil) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        
        // 1. 控制台实时反馈
        Logger.shared.info(" [Analytics] \(timestamp) | \(name) | \(properties?.description ?? "")")
        
        let event: [String: Any] = [
            "name": name,
            "properties": properties ?? [:],
            "timestamp": Date().timeIntervalSince1970
        ]
        
        // 2. 持久化至沙盒 (异步追加)
        saveEventToFile(event)
    }
    
    private func saveEventToFile(_ event: [String: Any]) {
        // 先序列化为 Data，确保可以安全传递给后台线程
        guard let dataToSave = try? JSONSerialization.data(withJSONObject: event) else { return }
        let logURL = self.logURL
        
        DispatchQueue.global(qos: .utility).async {
            var logs: [[String: Any]] = []
            if let data = try? Data(contentsOf: logURL),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                logs = existing
            }
            
            if let newEvent = try? JSONSerialization.jsonObject(with: dataToSave) as? [String: Any] {
                logs.append(newEvent)
                if let updatedData = try? JSONSerialization.data(withJSONObject: logs, options: .prettyPrinted) {
                    try? updatedData.write(to: logURL)
                }
            }
        }
    }
    
    /// 追踪Error
    /// - Parameter error: error
    /// - Parameter details: details
    func trackError(_ error: Error, details: String? = nil) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        Logger.shared.error(" [Analytics] \(timestamp) | Error: \(error.localizedDescription) | Details: \(details ?? "")", error: error)
    }
}
