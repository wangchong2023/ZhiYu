//
//  UFPLogging.swift
//  UFPCore
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：UFPCore 通用日志协议，供上层（如 App 层 LoggerProtocol）继承以实现依赖倒置。
//
import Foundation

/// UFPCore 通用日志协议。
/// 上层可让自有日志协议继承此协议，从而将实现（actor/类）直接 witness 协议要求。
/// 四个方法均为无默认参数签名，带默认参数的便捷调用由 extension 提供。
public protocol UFPLogging: Sendable {
    /// 调试
    func debug(_ message: String, file: String, function: String, line: Int)
    /// 信息
    func info(_ message: String, file: String, function: String, line: Int)
    /// 警告
    func warning(_ message: String, file: String, function: String, line: Int)
    /// 错误（可携带底层 Error）
    func error(_ message: String, error: Error?, file: String, function: String, line: Int)
}

// MARK: - 带默认参数便捷调用

public extension UFPLogging {
    /// 调试（默认 file/function/line）
    func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        debug(message, file: file, function: function, line: line)
    }

    /// 信息（默认 file/function/line）
    func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        info(message, file: file, function: function, line: line)
    }

    /// 警告（默认 file/function/line）
    func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        warning(message, file: file, function: function, line: line)
    }

    /// 错误（默认 file/function/line，error 默认 nil）
    func error(_ message: String, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        self.error(message, error: error, file: file, function: function, line: line)
    }
}
