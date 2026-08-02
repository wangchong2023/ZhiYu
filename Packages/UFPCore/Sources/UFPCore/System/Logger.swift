//
//  Logger.swift
//  UFPCore
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[UFPCore]
//  核心职责：通用依赖注入与系统日志打印器。
//

import Foundation
import os

public final class Logger: @unchecked Sendable {
    public static let shared = Logger()

    private init() {}

    public func debug(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        print(" 🔍 [DEBUG] [\(fileName):\(line)] \(function) -> \(message)")
        #endif
    }

    public func info(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        print(" ℹ️ [INFO] [\(fileName):\(line)] \(function) -> \(message)")
    }

    public func warning(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        print(" ⚠️ [WARNING] [\(fileName):\(line)] \(function) -> \(message)")
    }

    public func error(_ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        let fileName = (file as NSString).lastPathComponent
        print(" ❌ [ERROR] [\(fileName):\(line)] \(function) -> \(message)")
    }
}
