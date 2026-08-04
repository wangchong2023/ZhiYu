//
//  LogEntry.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 底层基座层
//  核心职责：操作日志条目模型，记录系统操作的元数据。
//
import Foundation

/// 操作日志条目模型，记录系统操作的元数据
public struct LogEntry: Identifiable, Codable, Sendable {
    public var id: UUID
    public var action: LogAction
    public var target: String
    public var details: String
    public var timestamp: Date
    public var duration: TimeInterval?
    public var startTime: Date?
    public var endTime: Date?
    public var module: String?
    public var status: LogStatus?
    public var failureReason: String?

    public init(
        id: UUID = UUID(),
        action: LogAction,
        target: String,
        details: String = "",
        timestamp: Date = Date(),
        duration: TimeInterval? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        module: String? = nil,
        status: LogStatus? = nil,
        failureReason: String? = nil
    ) {
        self.id = id
        self.action = action
        self.target = target
        self.details = details
        self.timestamp = timestamp
        self.duration = duration
        self.startTime = startTime
        self.endTime = endTime
        self.module = module
        self.status = status
        self.failureReason = failureReason
    }
}
