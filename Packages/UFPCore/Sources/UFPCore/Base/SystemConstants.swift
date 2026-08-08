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
    /// 每秒对应的微秒数
    public static let microsecondsPerSecond: Double = 1_000_000.0
    /// 每分钟对应的秒数
    public static let secondsPerMinute: Double = 60.0
    /// 每分钟对应的秒数（整型）
    public static let secondsPerMinuteInt: Int = 60
    /// 微秒阈值：小于此值视为微秒级
    public static let microsecondThreshold: Double = 0.001
    /// 秒阈值：小于此值视为毫秒级
    public static let secondThreshold: Double = 1.0

    // MARK: - 字节换算 (Byte Conversion)
    /// 每 KB 对应的字节数
    public static let bytesPerKB: Double = 1024.0
    /// 每 MB 对应的字节数
    public static let bytesPerMB: Double = bytesPerKB * bytesPerKB
    /// 每 GB 对应的字节数
    public static let bytesPerGB: Double = bytesPerKB * bytesPerKB * bytesPerKB

    // MARK: - Mach API (Mach API Constants)
    /// mach_msg_type_number_t 每个元素占用的 integer_t 字节数
    public static let bytesPerIntegerT: Int = 4

    // MARK: - HTTP 状态码 (HTTP Status Codes)
    public enum HTTPStatusCode {
        /// 200 OK
        public static let ok: Int = 200
        /// 401 Unauthorized
        public static let unauthorized: Int = 401
        /// 404 Not Found
        public static let notFound: Int = 404
        /// 429 Too Many Requests
        public static let rateLimited: Int = 429
        /// 500 Internal Server Error
        public static let internalServerError: Int = 500
        /// 501 Not Implemented
        public static let notImplemented: Int = 501
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
        /// multipart/form-data 前缀（boundary 拼接后缀）
        public static let multipartFormDataPrefix: String = "multipart/form-data; boundary="
    }

    // MARK: - HTTP 方法 (HTTP Methods)
    public enum HTTPMethod {
        /// GET
        public static let get: String = "GET"
        /// POST
        public static let post: String = "POST"
        /// PUT
        public static let put: String = "PUT"
        /// DELETE
        public static let delete: String = "DELETE"
        /// PATCH
        public static let patch: String = "PATCH"
    }

    // MARK: - HTTP 认证 (HTTP Authentication)
    public enum HTTPAuthentication {
        /// Authorization header 中 Bearer 前缀
        public static let bearerPrefix: String = "Bearer "
    }

    // MARK: - MIME 类型 (MIME Types)
    public enum MIMEType {
        /// image/png
        public static let png: String = "image/png"
        /// image/jpeg
        public static let jpeg: String = "image/jpeg"
        /// image/gif
        public static let gif: String = "image/gif"
        /// application/pdf
        public static let pdf: String = "application/pdf"
        /// application/octet-stream
        public static let octetStream: String = "application/octet-stream"
    }

    // MARK: - Multipart 表单构造 (Multipart Form Construction)
    public enum Multipart {
        /// multipart boundary 分隔符前缀
        public static let boundaryPrefix: String = "Boundary-"
        /// multipart body 默认字段名（文件表单 field name）
        public static let defaultFieldName: String = "file"
        /// HTTP 换行符（CRLF）
        public static let crlf: String = "\r\n"
    }

    // MARK: - 时间换算补充 (Time Conversion Supplement)
    public enum Time {
        /// 每秒对应的纳秒数
        public static let nanosecondsPerSecond: Double = 1_000_000_000
        /// 每秒对应的纳秒数（整型）
        public static let nanosecondsPerSecondInt: Int = 1_000_000_000
    }

    // MARK: - 错误码 (Error Codes)
    /// 与业务无关的通用错误码常量
    public enum ErrorCode {
        /// 默认错误码（未指定具体错误码时使用）
        public static let `default`: Int = -1
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
        /// .markdown（Markdown 文档长扩展名）
        public static let markdownLong: String = "markdown"
        /// .txt（纯文本）
        public static let text: String = "txt"
        /// .text（纯文本长扩展名）
        public static let textLong: String = "text"
        /// .sqlite（SQLite 数据库）
        public static let sqlite: String = "sqlite"
        /// .sqlite3（SQLite3 数据库）
        public static let sqlite3: String = "sqlite3"
        /// SQLite WAL 模式 -wal 后缀
        public static let walSuffix: String = "-wal"
        /// SQLite SHM 模式 -shm 后缀
        public static let shmSuffix: String = "-shm"
        /// .pdf（PDF 文档）
        public static let pdf: String = "pdf"
        /// .docx（Word 文档）
        public static let docx: String = "docx"
        /// .doc（Word 旧版文档）
        public static let doc: String = "doc"
        /// .xlsx（Excel 文档）
        public static let xlsx: String = "xlsx"
        /// .pptx（PowerPoint 文档）
        public static let pptx: String = "pptx"
        /// .png（PNG 图片）
        public static let png: String = "png"
        /// .jpg（JPEG 图片）
        public static let jpg: String = "jpg"
        /// .jpeg（JPEG 图片长扩展名）
        public static let jpeg: String = "jpeg"
        /// .gif（GIF 图片）
        public static let gif: String = "gif"
        /// 文本类文件扩展名集合（用于导入识别）
        public static let textFileExtensions: Set<String> = [
            "txt", "md", "json", "csv", "js", "py",
            "html", "xml", "css", "log", "swift", "yaml", "yml",
        ]
    }

    // MARK: - 通用文件名 (File Names)
    public enum FileName {
        /// manifest.json（插件清单文件名）
        public static let manifestJSON: String = "manifest.json"
    }

    // MARK: - Markdown 分隔符 (Markdown Delimiters)
    public enum MarkdownDelimiter {
        /// Markdown 水平线 / Frontmatter YAML 分隔符
        public static let horizontalRule: String = "---"
    }

    // MARK: - Markdown 语法 (Markdown Syntax)
    public enum MarkdownSyntax {
        /// 粗体标记
        public static let bold: String = "**"
        /// H1 前缀
        public static let h1Prefix: String = "# "
        /// H2 前缀
        public static let h2Prefix: String = "## "
        /// 无序列表项标记（星号）
        public static let bulletAsterisk: String = "* "
        /// 无序列表项标记（短横线）
        public static let bulletDash: String = "- "
        /// 表格行分隔符（Markdown 表格分隔行 `---`）
        public static let tableRowSeparator: String = "---"
    }

    // MARK: - 布尔字面量 (Boolean Literals)
    public enum BooleanLiteral {
        /// 字符串 "true"
        public static let `true`: String = "true"
        /// 字符串 "false"
        public static let `false`: String = "false"
    }

    // MARK: - 通用分隔符 (Separators)
    public enum Separator {
        /// 逗号 + 空格
        public static let commaSpace: String = ", "
        /// 箭头拼接符 " + "
        public static let arrow: String = " + "
    }

    // MARK: - 版本号 (Version)
    public enum Version {
        /// 默认语义化版本号
        public static let defaultSemVer: String = "1.0.0"
    }

    // MARK: - User-Agent (User Agents)
    public enum UserAgent {
        /// 桌面版 Safari UA（macOS）
        public static let desktopSafari: String = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
    }

    // MARK: - 加密协议标识 (Crypto Protocol Tags)
    public enum CryptoProtocol {
        /// API Key 加密协议 v2 标识
        public static let apiKeyEncryptionV2: String = "zhiyu-apikey-encryption-v2"
        /// 插件签名协议 v1 标识
        public static let pluginSignatureV1: String = "zhiyu-plugin-signature-v1"
    }

    // MARK: - URL 协议 (URL Schemes)
    public enum URLScheme {
        /// https://
        public static let https: String = "https://"
        /// http://
        public static let http: String = "http://"
    }

    // MARK: - 基础字符 (Base Characters)
    /// 与业务无关的单字符/双字符基础常量，业务层通过转接赋予语义名称
    public enum Character {
        public static let hash: String = "#"
        public static let dash: String = "-"
        public static let asterisk: String = "*"
        public static let lessThan: String = "<"
        public static let greaterThan: String = ">"
        public static let pipe: String = "|"
        public static let dot: String = "."
        public static let comma: String = ","
        public static let colon: String = ":"
        public static let semicolon: String = ";"
        public static let doubleQuote: String = "\""
        public static let singleQuote: String = "'"
        public static let slash: String = "/"
        public static let doubleSlash: String = "//"
        public static let backslash: String = "\\"
        public static let underscore: String = "_"
        public static let equals: String = "="
        public static let at: String = "@"
        public static let ampersand: String = "&"
        public static let percent: String = "%"
        public static let space: String = " "
        public static let newline: String = "\n"
        public static let tab: String = "\t"
        public static let carriageReturn: String = "\r"
        public static let plus: String = "+"
        public static let questionMark: String = "?"
        public static let openParen: String = "("
        public static let closeParen: String = ")"
        public static let openBracket: String = "["
        public static let closeBracket: String = "]"
        public static let openBrace: String = "{"
        public static let closeBrace: String = "}"
        public static let exclamation: String = "!"
    }
}
