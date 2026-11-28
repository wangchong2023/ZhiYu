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
final class LocalAnalyticsService: AnalyticsServiceProtocol {
    static let shared = LocalAnalyticsService()

    private enum AnalyticsConstants {
        static let maxRetainedEvents = 1000
        static let ioQueueLabel = "com.zhiyu.analytics.io"
        static let logFileName = "analytics_log.json"
        static let nameKey = "name"
        static let propertiesKey = "properties"
        static let timestampKey = "timestamp"
    }

    private let logURL: URL
    /// 专用串行磁盘队列：保证多线程高并发埋点按序原子落盘，彻底杜绝 RMW 丢事件与 JSON 撕裂
    private let ioQueue = DispatchQueue(label: AnalyticsConstants.ioQueueLabel, qos: .utility)

    init(logURL: URL? = nil) {
        if let customURL = logURL {
            self.logURL = customURL
        } else {
            // 文档目录获取失败时降级到临时目录，避免启动崩溃（分析日志非关键路径）
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory
            self.logURL = docs.appendingPathComponent(AnalyticsConstants.logFileName)
        }
    }

    /// 递归将任意属性字典转为 100% JSONSerialization 安全结构，
    /// 彻底杜绝传入 Date/UUID/URL/NaN 时触发底层未捕获 ObjC `NSInvalidArgumentException` 崩溃
    nonisolated internal static func sanitizeJSONObject(_ properties: [String: Any]) -> [String: Any] {
        var sanitized: [String: Any] = [:]
        for (key, value) in properties {
            sanitized[key] = sanitizeJSONValue(value)
        }
        return sanitized
    }

    private nonisolated static func sanitizeJSONValue(_ value: Any) -> Any {
        switch value {
        case let str as String:
            return str
        case let bool as Bool:
            return bool
        case let num as NSNumber:
            let dbl = num.doubleValue
            return dbl.isFinite ? num : String(describing: num)
        case let date as Date:
            return ISO8601DateFormatter().string(from: date)
        case let url as URL:
            return url.absoluteString
        case let uuid as UUID:
            return uuid.uuidString
        case let dict as [String: Any]:
            return sanitizeJSONObject(dict)
        case let array as [Any]:
            return array.map { sanitizeJSONValue($0) }
        default:
            return String(describing: value)
        }
    }

    /// 追踪Event
    /// - Parameter name: name
    /// - Parameter properties: properties
    func trackEvent(_ name: String, properties: [String: Any]? = nil) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        let safeProps = properties.map { Self.sanitizeJSONObject($0) } ?? [:]

        // 1. 控制台实时反馈
        Logger.shared.info(" [Analytics] \(timestamp) | \(name) | \(properties?.description ?? "")")

        let event: [String: Any] = [
            AnalyticsConstants.nameKey: name,
            AnalyticsConstants.propertiesKey: safeProps,
            AnalyticsConstants.timestampKey: Date().timeIntervalSince1970
        ]

        // 2. 持久化至沙盒 (串行原子追加)
        saveEventToFile(event)
    }

    /// 追踪Error
    /// - Parameter error: error
    /// - Parameter details: details
    func trackError(_ error: Error, details: String? = nil) {
        let timestamp = Date().formatted(date: .omitted, time: .standard)
        Logger.shared.error(" [Analytics] \(timestamp) | Error: \(error.localizedDescription) | Details: \(details ?? "")", error: error)
    }

    private func saveEventToFile(_ event: [String: Any]) {
        // 先校验与序列化为 Data，杜绝 NSInvalidArgumentException 与跨线程共享非 Sendable 字典
        guard JSONSerialization.isValidJSONObject(event),
              let dataToSave = try? JSONSerialization.data(withJSONObject: event) else { return }
        let logURL = self.logURL
        let maxEvents = AnalyticsConstants.maxRetainedEvents

        ioQueue.async {
            var logs: [[String: Any]] = []
            if let data = try? Data(contentsOf: logURL),
               let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                logs = existing
            }

            if let newEvent = try? JSONSerialization.jsonObject(with: dataToSave) as? [String: Any] {
                logs.append(newEvent)
                if logs.count > maxEvents {
                    logs.removeFirst(logs.count - maxEvents)
                }
                if JSONSerialization.isValidJSONObject(logs),
                   let updatedData = try? JSONSerialization.data(withJSONObject: logs, options: .prettyPrinted) {
                    try? updatedData.write(to: logURL, options: .atomicWrite)
                }
            }
        }
    }
}
