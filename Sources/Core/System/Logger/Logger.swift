//
//  Logger.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 系统集成层
//  核心职责：结构化日志系统，支持分级、分类、持久化与性能指标记录。
//
import Foundation
import Combine

// MARK: - Logger Protocol

/// 日志记录协议，定义日志输出与持久化的核心行为
public protocol LoggerProtocol: Sendable {

    /// 添加记录日志
    func addLog(
        action: LogAction,
        target: String,
        details: String,
        duration: TimeInterval?,
        startTime: Date?,
        endTime: Date?,
        module: String?,
        status: LogStatus?,
        failureReason: String?
    )
    
    /// 调试
    /// - Parameter message: message
    /// - Parameter file: file
    /// - Parameter function: function
    /// - Parameter line: line
    func debug(_ message: String, file: String, function: String, line: Int)

    /// info
    /// - Parameter message: message
    /// - Parameter file: file
    /// - Parameter function: function
    /// - Parameter line: line
    func info(_ message: String, file: String, function: String, line: Int)

    /// warning
    /// - Parameter message: message
    /// - Parameter file: file
    /// - Parameter function: function
    /// - Parameter line: line
    func warning(_ message: String, file: String, function: String, line: Int)

    /// error
    /// - Parameter message: message
    /// - Parameter error: error
    /// - Parameter file: file
    /// - Parameter function: function
    /// - Parameter line: line
    func error(_ message: String, error: Error?, file: String, function: String, line: Int)
    
    /// 执行并记录一个耗时操作 (@SRS-7.2)
    func logTimed<T>(action: LogAction, target: String, module: String?, details: String, operation: () throws -> T) rethrows -> T
    
    /// 暴露日志流供 UI 订阅
    func saveToDisk() async

    /// 加载FromDisk
    func loadFromDisk() async

    /// 清除AllLogs
    func clearAllLogs() async
    
    /// 获取内存中缓存的所有日志条目
    func getLogEntries() async -> [LogEntry]
    
    var logEntriesPublisher: AnyPublisher<[LogEntry], Never> { get }
}

extension LoggerProtocol {

    /// 添加记录日志
    public func addLog(
        action: LogAction,
        target: String,
        details: String = "",
        duration: TimeInterval? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        module: String? = nil,
        status: LogStatus? = nil,
        failureReason: String? = nil
    ) {
        addLog(action: action, target: target, details: details, duration: duration, startTime: startTime, endTime: endTime, module: module, status: status, failureReason: failureReason)
    }

    /// 调试
    /// - Parameter message: message
    /// - Parameter file: file
    /// - Parameter function: function
    /// - Parameter line: line
    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, file: file, function: function, line: line)
    }
    
    /// info
    /// - Parameter message: message
    /// - Parameter file: file
    /// - Parameter function: function
    /// - Parameter line: line
    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, file: file, function: function, line: line)
    }
    
    /// warning
    /// - Parameter message: message
    /// - Parameter file: file
    /// - Parameter function: function
    /// - Parameter line: line
    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        warning(message, file: file, function: function, line: line)
    }
    
    /// error
    /// - Parameter message: message
    /// - Parameter error: error
    /// - Parameter file: file
    /// - Parameter function: function
    /// - Parameter line: line
    public func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        self.error(message, error: error, file: file, function: function, line: line)
    }
}

// MARK: - Logger Implementation

/// 结构化日志系统 (L0.5Actor)
/// 负责全局操作审计、性能监测以及故障追溯。
public actor Logger: LoggerProtocol {
    
    public static let shared = Logger()
    
    private var _logEntries: [LogEntry] = []
    private nonisolated(unsafe) let entriesSubject = CurrentValueSubject<[LogEntry], Never>([])
    
    public nonisolated var logEntriesPublisher: AnyPublisher<[LogEntry], Never> {
        entriesSubject.eraseToAnyPublisher()
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let customDirectory: URL?
    
    private var documentsDirectory: URL {
        customDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    internal var logsFileURL: URL {
        documentsDirectory.appendingPathComponent(AppConstants.Storage.logsFileName)
    }
    
    private static let maxLogEntries = 500
    
    internal init(customDirectory: URL? = nil) {
        self.customDirectory = customDirectory
        // 异步初始化
        Task {
            await self.loadFromDisk()
            await self.setupSubscriptions()
        }
    }

    private func setupSubscriptions() {
        // 订阅系统级清理事件
        NotificationCenter.default.publisher(for: .languageChanged) // 借用作为占位
            .sink { _ in } 
            .store(in: &cancellables)
    }

    // MARK: - Standard Logging (nonisolated entry points)
    
    /// 调试
    /// - Parameter message: message
    /// - Parameter file: file
    /// - Parameter function: function
    /// - Parameter line: line
    public nonisolated func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        // 审查修复 MED-7: 日志输出前脱敏，防止 API key 明文泄露
        print(" [DEBUG] [\(fileName):\(line)] \(function) -> \(LogMasker.mask(message))")
        #endif
    }
    
    /// info
    /// - Parameter message: message
    /// - Parameter file: file
    /// - Parameter function: function
    /// - Parameter line: line
    public nonisolated func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        // 审查修复 MED-7: 日志输出前脱敏
        print(" [INFO] [\(fileName):\(line)] \(function) -> \(LogMasker.mask(message))")
    }
    
    /// warning
    /// - Parameter message: message
    /// - Parameter file: file
    /// - Parameter function: function
    /// - Parameter line: line
    public nonisolated func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        // 审查修复 MED-7: 日志输出前脱敏
        print(" [WARNING] [\(fileName):\(line)] \(function) -> \(LogMasker.mask(message))")
    }
    
    /// error
    /// - Parameter message: message
    /// - Parameter error: error
    /// - Parameter file: file
    /// - Parameter function: function
    /// - Parameter line: line
    public nonisolated func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        let errDesc = error.map { " (Error: \($0.localizedDescription))" } ?? ""
        // 审查修复 MED-7: 日志输出前脱敏
        print(" [ERROR]" + " [\(fileName):\(line)]" + " \(function)" + " -> \(LogMasker.mask(message))\(errDesc)")
        
        addLog(action: .error, target: message, details: errDesc, module: "System", status: .failure, failureReason: error?.localizedDescription)
    }

    // MARK: - Structured Logging
    
    /// 添加记录日志
    public nonisolated func addLog(
        action: LogAction,
        target: String,
        details: String = "",
        duration: TimeInterval? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        module: String? = nil,
        status: LogStatus? = nil,
        failureReason: String? = nil
    ) {
        Task {
            await _addLog(
                action: action,
                target: target,
                details: details,
                duration: duration,
                startTime: startTime,
                endTime: endTime,
                module: module,
                status: status,
                failureReason: failureReason
            )
        }
    }

    private func _addLog(
        action: LogAction,
        target: String,
        details: String = "",
        duration: TimeInterval? = nil,
        startTime: Date? = nil,
        endTime: Date? = nil,
        module: String? = nil,
        status: LogStatus? = nil,
        failureReason: String? = nil
    ) async {
        // 审查修复 MED-7: 持久化前对 target/details 脱敏，防止 API key 明文写入日志文件
        let maskedTarget = LogMasker.mask(target)
        let maskedDetails = LogMasker.mask(details)
        let entry = LogEntry(
            action: action,
            target: maskedTarget,
            details: maskedDetails,
            duration: duration,
            startTime: startTime,
            endTime: endTime,
            module: module,
            status: status,
            failureReason: failureReason
        )
        
        logToConsole(entry)
        
        _logEntries.insert(entry, at: 0)
        if _logEntries.count > Self.maxLogEntries {
            _logEntries = Array(_logEntries.prefix(Self.maxLogEntries))
        }
        
        entriesSubject.send(_logEntries.sorted { $0.timestamp > $1.timestamp })
        await saveToDisk()
    }

    /// 记录日志ToConsole
    /// - Parameter entry: entry
    private nonisolated func logToConsole(_ entry: LogEntry) {
        let durationStr = entry.duration.map { " (: \($0.formattedAdaptive))" } ?? ""
        let statusEmoji: String
        switch entry.status {
        case .success: statusEmoji = ""
        case .failure: statusEmoji = ""
        case .processing: statusEmoji = ""
        case .none: statusEmoji = entry.action == .error ? "" : ""
        }
        
        print("\(statusEmoji) [LOG] [\(entry.module ?? "System")] \(entry.action.rawValue) -> \(entry.target): \(entry.details)\(durationStr)")
    }

    /// 记录日志Timed
    public nonisolated func logTimed<T>(
        action: LogAction,
        target: String,
        module: String? = nil,
        details: String = "",
        operation: () throws -> T
    ) rethrows -> T {
        let startTime = Date()
        do {
            let result = try operation()
            let duration = Date().timeIntervalSince(startTime)
            addLog(action: action, target: target, details: details, duration: duration, 
                   startTime: startTime, endTime: Date(), module: module, status: .success)
            return result
        } catch {
            addLog(action: action == .error ? .error : action, target: target, details: details, 
                   duration: Date().timeIntervalSince(startTime), startTime: startTime, 
                   endTime: Date(), module: module, status: .failure, failureReason: error.localizedDescription)
            throw error
        }
    }

    /// 保存ToDisk
    public func saveToDisk() async {
        let entries = self._logEntries
        let url = self.logsFileURL

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        do {
            let data = try encoder.encode(entries)
            try data.write(to: url, options: .atomicWrite)
        } catch {
            print(" [Logger]" + " Failed to" + " save logs:" + " \(error.localizedDescription)")
        }
    }

    /// 加载FromDisk
    public func loadFromDisk() async {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let data = try Data(contentsOf: logsFileURL)
            self._logEntries = try decoder.decode([LogEntry].self, from: data)
            self.entriesSubject.send(_logEntries)
        } catch {
            // 首次运行或文件损坏时，静默初始化为空列表
            #if DEBUG
            print(" [Logger]" + " No existing" + " logs found" + " or load" + " failed (Expected" + " on first" + " run): \(error.localizedDescription)")
            #endif
        }
    }

    /// 清除AllLogs
    public func clearAllLogs() async {
        _logEntries.removeAll()
        entriesSubject.send([])
        await saveToDisk()
    }
    
    /// 获取记录日志Entries
    /// - Returns: 列表
    public func getLogEntries() async -> [LogEntry] {
        return _logEntries.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - TimeInterval Extension
extension TimeInterval {
    /// 自动根据量级选择最合适的单位进行格式化 (µs, ms, s, m)
    public var formattedAdaptive: String {
        if self < 0.001 {
            return String(format: "%.0fµs", self * 1_000_000)
        } else if self < 1.0 {
            return String(format: "%.1fms", self * 1000)
        } else if self < 60.0 {
            return String(format: "%.2fs", self)
        } else {
            let minutes = Int(self) / 60
            let seconds = self.truncatingRemainder(dividingBy: 60)
            return String(format: "%dm %.1fs", minutes, seconds)
        }
    }
}
