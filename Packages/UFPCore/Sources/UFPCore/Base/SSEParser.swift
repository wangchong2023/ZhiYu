//
//  SSEParser.swift
//  UFPCore
//
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：从 SSE 字节流解析文本 chunk，兼容 OpenAI / DeepSeek / Qwen / Zhipu 等主流提供商格式差异。
//
import Foundation

/// SSE 流式响应解析器（纯静态工具）。
/// 从 `URLSession.AsyncBytes` 中逐行解析 `data:` 事件为文本 chunk，并支持 `[DONE]` 终止标记。
public enum SSEParser {

    /// 解析 SSE 字节流为文本 chunk 序列。
    /// 兼容 OpenAI / DeepSeek / Qwen / Zhipu 等主流提供商的流式格式差异。
    ///
    /// - Parameter bytes: URLSession 异步字节流
    /// - Parameter logger: 可选的诊断日志记录器，用于排查格式兼容问题
    /// - Returns: 逐 chunk 产出的文本流
    public static func parse(
        bytes: URLSession.AsyncBytes,
        logger: (any UFPLogging)? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                var lineCount = 0
                var chunkCount = 0
                var rawLinesForDiagnostic: [String] = []
                do {
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        lineCount += 1
                        logDiagnosticLine(line: line, lineCount: lineCount, logger: logger, rawLines: &rawLinesForDiagnostic)

                        guard let dataString = extractDataString(from: line) else { continue }
                        if dataString == SSEConstants.doneMarker { break }

                        guard let json = parseJSONLine(dataString, logger: logger) else { continue }
                        if let content = extractContent(from: json) {
                            chunkCount += 1
                            continuation.yield(content)
                        }
                    }

                    if let logger {
                        logger.debug("[SSE] 流结束 — \(lineCount) 行, \(chunkCount) chunk")
                    }
                    continuation.finish()
                } catch {
                    if let logger {
                        logger.error("[SSE] 流解析异常 — 已读 \(lineCount) 行, \(chunkCount) chunk", error: error)
                        if !rawLinesForDiagnostic.isEmpty {
                            logger.debug("[SSE] 异常前收到的原始行:\n\(rawLinesForDiagnostic.joined(separator: "\n"))")
                        }
                    }
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    /// 诊断日志记录器：仅在前 15 行内记录 SSE 原始行内容供排查格式兼容问题。
    private static func logDiagnosticLine(line: String, lineCount: Int, logger: (any UFPLogging)?, rawLines: inout [String]) {
        guard let logger, lineCount <= SSEConstants.maxDiagnosticLines else { return }
        let preview = String(line.prefix(SSEConstants.diagnosticLineLength))
        rawLines.append(preview)
        if !preview.isEmpty {
            logger.debug("[SSE] L\(lineCount): \(preview)")
        }
    }

    /// 从 SSE 行提取 "data:" 前缀后的内容字符串，兼容 "data: " 和 "data:" 两种格式。
    public static func extractDataString(from line: String) -> String? {
        guard line.hasPrefix(SSEConstants.dataPrefixNoSpace) else { return nil }
        return String(line.dropFirst(line.hasPrefix(SSEConstants.dataPrefix) ? SSEConstants.dataPrefix.count : SSEConstants.dataPrefixNoSpace.count))
    }

    /// 将 SSE 数据行解析为 JSON 字典，非 JSON 行（如空行、注释）静默跳过。
    public static func parseJSONLine(_ dataString: String, logger: (any UFPLogging)?) -> [String: Any]? {
        guard let data = dataString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if let logger, !dataString.isEmpty {
                logger.debug("[SSE] 跳过非 JSON 行: \(String(dataString.prefix(SSEConstants.sseNonJsonLength)))")
            }
            return nil
        }
        return json
    }

    /// 从 LLM 响应 JSON 的 choices[0] 中提取 content 或 reasoning_content。
    /// 兼容 delta（流式）和 message（非流式）两种 SSE 结构，并防御 content 为空字符串时 reasoning_content 丢失问题。
    public static func extractContent(from json: [String: Any]) -> String? {
        guard let choices = json["choices"] as? [[String: Any]],
              let first = choices.first else { return nil }
        let payload = (first["delta"] as? [String: Any]) ?? (first["message"] as? [String: Any])
        guard let payload else { return nil }

        let directContent = (payload["content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let directContent, !directContent.isEmpty {
            return payload["content"] as? String
        }

        let reasoning = (payload["reasoning_content"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let reasoning, !reasoning.isEmpty {
            return payload["reasoning_content"] as? String
        }

        return nil
    }
}