//
//  SSEConstants.swift
//  UFPCore
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：SSE 流式响应解析相关常量集，消除解析逻辑中的魔鬼数字/字面量。
//
import Foundation

/// SSE 流式响应解析常量集
public enum SSEConstants {
    /// 流结束标记
    public static let doneMarker = "[DONE]"
    /// data 行前缀（带空格）
    public static let dataPrefix = "data: "
    /// data 行前缀（无空格，兼容部分提供商）
    public static let dataPrefixNoSpace = "data:"
    /// SSE 诊断日志最大记录行数
    public static let maxDiagnosticLines = 15
    /// SSE 诊断单行预览截断长度
    public static let diagnosticLineLength = 250
    /// SSE 非 JSON 行预览截断长度
    public static let sseNonJsonLength = 120
}
