//
//  SystemConstants.swift
//  UFPCore
//
//  Created by Antigravity on 2026/08/05.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 基础设施层
//  核心职责：与业务无关的系统级换算常量与协议常量集（时间换算、字节换算、HTTP 状态码等）。
//           避免代码中出现裸数字 1000/1024/200 等魔鬼数字。
//

import Foundation

/// 与业务无关的系统级换算与协议常量集
public enum SystemConstants {

    // MARK: - 时间换算 (Time Conversion)
    /// 每秒对应的毫秒数
    public static let millisecondsPerSecond: Double = 1000.0

    // MARK: - 字节换算 (Byte Conversion)
    /// 每 KB 对应的字节数
    public static let bytesPerKB: Double = 1024.0
    /// 每 MB 对应的字节数
    public static let bytesPerMB: Double = bytesPerKB * bytesPerKB
    /// 每 GB 对应的字节数
    public static let bytesPerGB: Double = bytesPerKB * bytesPerKB * bytesPerKB

    // MARK: - HTTP 状态码 (HTTP Status Codes)
    public enum HTTPStatusCode {
        /// 200 OK
        public static let ok: Int = 200
        /// 401 Unauthorized
        public static let unauthorized: Int = 401
        /// 429 Too Many Requests
        public static let rateLimited: Int = 429
    }

    // MARK: - HTTP 请求头 (HTTP Headers)
    public enum HTTPHeader {
        /// Content-Type 请求头字段名
        public static let contentType: String = "Content-Type"
        /// Authorization 请求头字段名
        public static let authorization: String = "Authorization"
        /// Accept 请求头字段名
        public static let accept: String = "Accept"
        /// User-Agent 请求头字段名
        public static let userAgent: String = "User-Agent"
    }

    // MARK: - HTTP 内容类型 (Content Types)
    public enum ContentType {
        /// application/json
        public static let applicationJSON: String = "application/json"
        /// application/xml
        public static let applicationXML: String = "application/xml"
        /// text/plain
        public static let textPlain: String = "text/plain"
        /// text/html
        public static let textHTML: String = "text/html"
        /// application/x-www-form-urlencoded
        public static let formURLEncoded: String = "application/x-www-form-urlencoded"
    }

    // MARK: - 文件扩展名 (File Extensions)
    public enum FileExtension {
        /// .json
        public static let json: String = "json"
        /// .mlmodelc（CoreML 编译后模型包）
        public static let mlmodelC: String = "mlmodelc"
        /// .mlmodel（CoreML 源模型）
        public static let mlmodel: String = "mlmodel"
        /// .md（Markdown 文档）
        public static let markdown: String = "md"
        /// .txt（纯文本）
        public static let text: String = "txt"
        /// .sqlite（SQLite 数据库）
        public static let sqlite: String = "sqlite"
    }

    // MARK: - URL 协议 (URL Schemes)
    public enum URLScheme {
        /// https://
        public static let https: String = "https://"
        /// http://
        public static let http: String = "http://"
    }
}
