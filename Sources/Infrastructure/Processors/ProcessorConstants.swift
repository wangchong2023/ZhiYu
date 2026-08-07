//
//  ProcessorConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/05.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：文档处理器模块的强类型常量集。
//           消除 Markdown 语法符号、HTML 标签、SSRF 防护地址、
//           Mermaid 语法、OOXML 标签等散落的魔鬼字符串。
//

import Foundation
import UFPCore

/// 文档处理器模块常量集
enum ProcessorConstants {

    // MARK: - Markdown 语法符号 (Markdown Syntax)
    /// 基础字符引用 UFPCore.SystemConstants.Character，业务层转接为 Markdown 语义名称
    enum MarkdownSyntax {
        // 单字符标记（转接 UFPCore 基础字符）
        static let hash: String = SystemConstants.Character.hash
        static let dash: String = SystemConstants.Character.dash
        static let asterisk: String = SystemConstants.Character.asterisk
        static let greaterThan: String = SystemConstants.Character.greaterThan
        static let pipe: String = SystemConstants.Character.pipe
        static let dot: String = SystemConstants.Character.dot
        static let doubleQuote: String = SystemConstants.Character.doubleQuote
        static let singleQuote: String = SystemConstants.Character.singleQuote
        static let slash: String = SystemConstants.Character.slash
        static let doubleSlash: String = SystemConstants.Character.doubleSlash
        static let plus: String = SystemConstants.Character.plus
        static let colon: String = SystemConstants.Character.colon
        static let questionMark: String = SystemConstants.Character.questionMark
        static let underscore: String = SystemConstants.Character.underscore
        static let openParen: String = SystemConstants.Character.openParen
        static let closeParen: String = SystemConstants.Character.closeParen
        static let openBracket: String = SystemConstants.Character.openBracket
        static let closeBracket: String = SystemConstants.Character.closeBracket
        static let openBrace: String = SystemConstants.Character.openBrace
        static let closeBrace: String = SystemConstants.Character.closeBrace
        static let exclamation: String = SystemConstants.Character.exclamation
        static let semicolon: String = SystemConstants.Character.semicolon

        // CJK 标点
        static let cjkOpenBracket: String = "【"
        static let cjkCloseBracket: String = "】"
        static let cjkOpenQuote: String = "「"
        static let cjkCloseQuote: String = "」"

        // 标题前缀
        /// 引用 SystemConstants.MarkdownSyntax.h1Prefix
        static let h1Prefix: String = SystemConstants.MarkdownSyntax.h1Prefix
        /// 引用 SystemConstants.MarkdownSyntax.h2Prefix
        static let h2Prefix: String = SystemConstants.MarkdownSyntax.h2Prefix
        static let h3Prefix: String = "### "

        // 列表标记
        /// 引用 SystemConstants.MarkdownSyntax.bulletDash
        static let bulletDash: String = SystemConstants.MarkdownSyntax.bulletDash
        /// 引用 SystemConstants.MarkdownSyntax.bulletAsterisk
        static let bulletAsterisk: String = SystemConstants.MarkdownSyntax.bulletAsterisk
        static let bulletPlus: String = "+ "

        // 任务列表标记
        static let taskUncheckedDash: String = "- [ ] "
        static let taskCheckedDashLower: String = "- [x] "
        static let taskCheckedDashUpper: String = "- [X] "
        static let taskUncheckedAsterisk: String = "* [ ] "
        static let taskCheckedAsteriskLower: String = "* [x] "
        static let taskCheckedAsteriskUpper: String = "* [X] "

        // 引用块
        static let blockquotePrefix: String = "> "

        // 代码块
        static let codeFence: String = "```"
        static let mermaidFence: String = "```mermaid"

        // 粗体/斜体
        /// 引用 SystemConstants.MarkdownSyntax.bold
        static let bold: String = SystemConstants.MarkdownSyntax.bold
        static let boldItalic: String = "***"

        // 水平线
        /// 引用 SystemConstants.MarkdownDelimiter.horizontalRule
        static let horizontalRuleDash: String = SystemConstants.MarkdownDelimiter.horizontalRule
        static let horizontalRuleAsterisk: String = "***"
        static let horizontalRuleUnderscore: String = "___"

        // 表格
        static let tableSeparatorDash: String = "|-"
        static let tableSeparatorDashSpace: String = "| -"
        static let tablePipe: String = SystemConstants.Character.pipe

        // 标题分隔（用于 PPTX 等文档拆分）
        static let sectionBreak: String = "\n## "

        // 演示文稿分页符
        static let slideSeparator: String = "\n---\n"
        static let slideSeparatorSpaced: String = "\n--- \n"
        static let slideJoinSeparator: String = "\n\n---\n\n"

        // MARK: 转义字符替换映射（cleanMarkdown 用）
        /// Markdown 转义字符 → 原始字符的替换映射
        static let escapeReplacements: [(target: String, replacement: String)] = [
            ("\\+", "+"), ("\\-", "-"), ("\\*", "*"), ("\\. ", ". "),
            ("\\!", "!"), ("\\[\\[", "[["), ("\\]\\]", "]]"),
            ("\\\\[", "["), ("\\\\]", "]")
        ]
    }

    // MARK: - HTML 标签 (HTML Tags)
    enum HTMLTag {
        // 折叠块
        static let detailsOpen: String = "<details>"
        static let detailsClose: String = "</details>"
        static let summaryOpen: String = "<summary>"
        static let summaryClose: String = "</summary>"
    }

    // MARK: - HTML 清洗正则 (Sanitization Regex)
    enum SanitizationRegex {
        /// 匹配所有 HTML 标签
        static let allTags: String = "<[^>]+>"
        /// 匹配 <style> 标签及其内容（含跨行）
        static let styleBlock: String = "<style[^>]*>[\\s\\S]*?</style>"
        /// 匹配 <script> 标签及其内容（大小写不敏感）
        static let scriptBlock: String = "(?i)<script.*?>.*?</script>"
        /// 匹配 <style> 标签及其内容（大小写不敏感）
        static let styleBlockCaseInsensitive: String = "(?i)<style.*?>.*?</style>"
    }

    // MARK: - SSRF 防护地址 (SSRF Guard)
    // 所有 SSRF 防护相关常量已迁移至 UFPCore/NetworkConstants.swift
    // 此处保留 typealias 以兼容现有引用，实际定义见 NetworkConstants
    enum SSRFGuard {
        // 环回地址（引用 NetworkConstants.Loopback）
        static let localhost: String = NetworkConstants.Loopback.localhost
        static let loopbackIPv4: String = NetworkConstants.Loopback.loopbackIPv4
        static let loopbackIPv6: String = NetworkConstants.Loopback.loopbackIPv6
        static let loopbackIPv6Bracketed: String = NetworkConstants.Loopback.loopbackIPv6Bracketed

        // 链路本地地址前缀（引用 NetworkConstants.Loopback）
        static let linkLocalPrefix: String = NetworkConstants.Loopback.linkLocalPrefix

        // 本地域名后缀（引用 NetworkConstants.LocalDomainSuffix）
        static let localDomainSuffix: String = NetworkConstants.LocalDomainSuffix.local
        static let internalDomainSuffix: String = NetworkConstants.LocalDomainSuffix.internalSuffix
        static let localhostDomainSuffix: String = NetworkConstants.LocalDomainSuffix.localhost

        // DNS rebinding 服务后缀（引用 NetworkConstants.DNSRebinding）
        static let rebindingSuffixes: [String] = NetworkConstants.DNSRebinding.suffixes

        // IPv6 私有地址前缀（引用 NetworkConstants.IPv6PrivateRange）
        static let ipv6UniqueLocalPrefixFC: String = NetworkConstants.IPv6PrivateRange.uniqueLocalPrefixFC
        static let ipv6UniqueLocalPrefixFD: String = NetworkConstants.IPv6PrivateRange.uniqueLocalPrefixFD
        static let ipv6LinkLocalPrefixFE8: String = NetworkConstants.IPv6PrivateRange.linkLocalPrefixFE8
        static let ipv6LinkLocalPrefixFE9: String = NetworkConstants.IPv6PrivateRange.linkLocalPrefixFE9
        static let ipv6LinkLocalPrefixFEA: String = NetworkConstants.IPv6PrivateRange.linkLocalPrefixFEA
        static let ipv6LinkLocalPrefixFEB: String = NetworkConstants.IPv6PrivateRange.linkLocalPrefixFEB

        // IP 编码前缀（引用 NetworkConstants.IPEncoding）
        static let hexPrefixLower: String = NetworkConstants.IPEncoding.hexPrefixLower
        static let hexPrefixUpper: String = NetworkConstants.IPEncoding.hexPrefixUpper
    }

    // MARK: - Mermaid 图表语法 (Mermaid Syntax)
    enum MermaidSyntax {
        static let flowchart: String = "flowchart"
        static let graph: String = "graph"
        static let graphTD: String = "graph TD"
        static let graphLR: String = "graph LR"
        static let graphTB: String = "graph TB"
        static let graphBT: String = "graph BT"
        static let mindmap: String = "mindmap"
        static let sequenceDiagram: String = "sequenceDiagram"
        static let gantt: String = "gantt"
        static let pie: String = "pie"
        static let timeline: String = "timeline"
        static let td: String = "TD"
        static let lr: String = "LR"
        static let tb: String = "TB"
        static let bt: String = "BT"
        static let root: String = "Root"
        static let mindmapRoot: String = "root"
        static let rootLabel: String = "Root[\""
        static let nodeLabel: String = "Node"
        static let arrow: String = " --> "
        static let indent: String = "  "
        static let labelSuffix: String = "\"]"
        static let doubleParenOpen: String = "(("
        static let doubleParenClose: String = "))"
        static let doubleBraceOpen: String = "{{"
        static let doubleBraceClose: String = "}}"
        static let patternSuffix: String = ".*"
        static let validPrefixes: [String] = [mindmap, graph, flowchart, sequenceDiagram, gantt, pie, timeline]
        static let matchPatterns: [String] = [
            mindmap + patternSuffix,
            graph + patternSuffix,
            pie + patternSuffix,
            timeline + patternSuffix,
            sequenceDiagram + patternSuffix,
            gantt + patternSuffix
        ]
        static let keywordSpacingCandidates: [String] = [
            mindmap,
            graphTD,
            graphLR,
            graphTB,
            graphBT,
            graph,
            timeline,
            gantt,
            pie,
            sequenceDiagram
        ]
    }

    // MARK: - OOXML 标签名 (Office Open XML Tags)
    enum OOXML {
        // Word OOXML
        static let wordText: String = "w:t"
        static let wordParagraph: String = "w:p"
        // Excel OOXML
        static let xmlExtension: String = ".xml"
        static let excelWorksheetPrefix: String = "xl/worksheets/sheet"
        static let inlineString: String = "inlineStr"
        static let sharedStringsPath: String = "xl/sharedStrings.xml"
        static let wordDocumentPath: String = "word/document.xml"
        static let cellElement: String = "c"
        static let valueElement: String = "v"
        static let cellTypeAttribute: String = "t"
        static let cellTypeShared: String = "s"
        static let cellTypeInlineString: String = "inlineStr"
        static let sharedStringIndexOpen: String = "["
        static let sharedStringIndexClose: String = "]"
        static let sharedStringIndexMax: Int = 10000
        // Office 文档嵌入图片的媒体目录路径
        static let imageMediaFolders: [String] = ["word/media", "xl/media", "ppt/media"]
    }

    // MARK: - 空白字符 (Whitespace)
    /// 基础空白字符引用 UFPCore.SystemConstants.Character，业务层转接为语义名称
    enum Whitespace {
        static let empty: String = ""
        static let space: String = SystemConstants.Character.space
        static let newline: String = SystemConstants.Character.newline
        static let doubleNewline: String = "\n\n"
        static let tripleNewline: String = "\n\n\n"
        static let newlineWithIndent: String = "\n  "
        static let tab: String = SystemConstants.Character.tab
        static let doubleSpace: String = "  "
        static let quadSpace: String = "    "
        static let commaSeparator: String = ", "
        static let dotSpace: String = ". "
        static let ideographicComma: String = "、"
    }

    // MARK: - 模块标识 (Module Identity)
    enum Module {
        static let webScraper: String = "WebScraper"
        static let paywallBlocked: String = "Paywall_Blocked"
        static let paywallTestDomain: String = "paywall-test.com"
    }

    // MARK: - 网页抓取器 (Web Scraper)
    enum WebScraper {
        /// Jina 请求超时（秒）
        static let jinaTimeoutInterval: TimeInterval = 10
        /// 直接抓取超时（秒）
        static let directTimeoutInterval: TimeInterval = 15
        /// 归档抓取超时（秒）
        static let archiveTimeoutInterval: TimeInterval = 20
        /// Googlebot UA 版本
        static let googlebotVersion: String = "2.1"
        /// Mozilla 版本
        static let mozillaVersion: String = "5.0"
        /// Accept header q 值
        static let acceptQValueHigh: String = "0.9"
        /// Accept header q 值
        static let acceptQValueLow: String = "0.8"
        /// 日志详情模板
        static let logDetailsTemplate: String = "%@ (Length: %lld)"
        /// 受限 HTTP 状态码
        static let restrictedStatusCodes: [Int] = [401, 402, 403, 429]
        /// HTTPS 协议前缀（不带 //）
        static let httpsPrefix: String = "https:"
        /// 通用桌面浏览器 UA（引用 SystemConstants.UserAgent.desktopSafari）
        static let desktopUserAgent: String = SystemConstants.UserAgent.desktopSafari
        /// Mock 测试用无效主机域名（用于验证本地灾难恢复流程）
        static let invalidHostTestDomain: String = "invalid-host-domain-never-exist.example.com"
    }

    // MARK: - HTML 提取正则模式 (HTML Extraction Regex)
    enum HTMLRegex {
        /// 匹配 <title> 标签内容
        static let titleTag: String = "<title>(.*?)</title>"
        /// 匹配 <article> 标签内容（大小写不敏感）
        static let articleTag: String = "(?i)<article[^>]*>(.*?)</article>"
        /// 匹配 <main> 标签内容（大小写不敏感）
        static let mainTag: String = "(?i)<main[^>]*>(.*?)</main>"
        /// 匹配 <p> 段落标签内容
        static let paragraphTag: String = "<p[^>]*>(.*?)</p>"
        /// 匹配 <img> 标签的 src 属性值
        static let imgSrcTag: String = #"<img[^>]+src\s*=\s*["']([^"']+)["'][^>]*>"#
    }

    // MARK: - HTML 实体解码映射 (HTML Entity Decoding)
    enum HTMLEntity {
        /// HTML 实体 → 字符映射表（覆盖常见命名实体与数字实体）
        static let decodeMap: [String: String] = [
            "&quot;": "\"",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " ",
            "&apos;": "'",
            "&#39;": "'",
            "&#34;": "\"",
            "&#60;": "<",
            "&#62;": ">",
            "&hellip;": "…",
            "&mdash;": "—",
            "&ndash;": "–",
            "&trade;": "™",
            "&copy;": "©",
            "&reg;": "®"
        ]
    }

    // MARK: - 文件格式 (File Format)
    enum FileFormat {
        static let pdf: String = "pdf"
        static let office: String = "office"
        static let svg: String = "svg"
    }

    // MARK: - OCR 图片标注模板 (OCR Image Annotation)

    /// OCR 图片标注 Markdown 模板常量集
    enum OCRAnnotation {
        /// HTML 图片 OCR 标注模板（参数：序号, 识别文本）
        static let htmlImageTemplate: String = "> ![img_%d]: %@"
        /// PDF/Office 图片 OCR 标注模板（参数：前缀, 序号, 识别文本）
        static let prefixedImageTemplate: String = "> ![%@_%d]: %@"
    }

    // MARK: - 布尔字面量 (Boolean String)
    /// 引用 SystemConstants.BooleanLiteral，避免重复定义
    enum BoolString {
        static let `true`: String = SystemConstants.BooleanLiteral.true
        static let `false`: String = SystemConstants.BooleanLiteral.false
    }

    // MARK: - Frontmatter 语法 (Frontmatter Syntax)
    enum Frontmatter {
        /// 引用 SystemConstants.MarkdownDelimiter.horizontalRule，避免重复定义
        static let yamlDelimiter: String = SystemConstants.MarkdownDelimiter.horizontalRule
        static let jsonDelimiter: String = "---json"
        static let minKey: String = "min"
    }

    // MARK: - 正则模式 (Regex Patterns)
    enum RegexPattern {
        /// 匹配编号列表前缀（如 "1. " 或 "12、"）
        static let numberedList: String = "^[0-9]+[.\\s、]+"
        /// 匹配选择题选项前缀（如 "A. " 或 "B:"）
        static let choiceOption: String = "^[A-D][.\\s、:]"
        /// 匹配无序列表前缀（- 或 * 后跟空白）
        static let bulletList: String = "^[*\\-]\\s*"
        /// 正则替换中的捕获组引用
        static let captureGroup12: String = "$1 $2"
        /// 多行匹配标志前缀
        static let multilineFlag: String = "(?s)"
        /// 大小写不敏感标志前缀
        static let caseInsensitiveFlag: String = "(?i)"
        /// 匹配 Markdown 行首项目符号/标题前缀（- * + # 数字.）
        static let markdownBulletStrip: String = #"^[\-\*\+\#\d\.]+\s*"#
        /// 匹配 Markdown 标题井号前缀
        static let markdownHeaderStrip: String = #"^#+\s*"#
        /// 匹配 Quiz 选项前缀（A-D 或数字 + 分隔符）
        static let quizOptionPrefix: String = #"^[A-D\d][\.\s、:]\s*"#
        /// 匹配 Quiz 选项剥离前缀（- 或 * 后跟空白）
        static let quizOptionStrip: String = "^[*\\-]\\s*"
        /// 匹配 Quiz Answer 行（Answer: 后跟字母/数字）
        static let quizAnswer: String = #"Answer:\s*([A-Da-d1-4])"#
        /// 匹配 CJK 与 ANSI 字符边界（CJK 在前）
        static let cjkAnsBoundary: String = #"([\u4e00-\u9fa5\u3040-\u30ff])([A-Za-z0-9@#\$%\^&\*\-\+\=])"#
        /// 匹配 CJK 与 ANSI 字符边界（ANSI 在前）
        static let ansCjkBoundary: String = #"([A-Za-z0-9@#\$%\^&\*\-\+\=])([\u4e00-\u9fa5\u3040-\u30ff])"#
        /// 匹配 Mermaid 标准节点 NodeID[Label]
        static let mermaidNodeStandard: String = #"([A-Za-z0-9_\-]+)\[([^"\]]+)\]"#
        /// 匹配 Mermaid 嵌套方括号节点 NodeID[Label[...]]
        static let mermaidNodeNested: String = #"([A-Za-z0-9_\-]+)\[([^"\]]*\[[^\]]*\][^"\]]*)\]"#
        /// Mermaid 节点替换模板（NodeID["Label"]）
        static let mermaidNodeTemplate: String = #"$1["$3"]"#
        /// 匹配 Mermaid 节点尾部连字符
        static let mermaidTrailingDash: String = #"-+$"#
        /// 匹配 Mermaid 节点括号内容
        static let mermaidNodeBracket: String = #"(\w+)(\[+|\(+|\{+)(.+?)(\]+|\)+|\}+)"#
        /// 匹配 Prompt 控制参数块（篇幅要求/目标受众等）
        static let promptBlockDepth: String = #"【(篇幅要求|目标受众|语气风格|自定义要求|深度要求)[^】]*】[^\n]*\n?"#
        /// 匹配 Prompt 控制参数块（简短形式）
        static let promptBlockShort: String = #"【(篇幅|受众|语气|风格)[^】]*】[^\n]*\n?"#
    }

    // MARK: - 文本分块器 (Text Chunker)
    enum TextChunker {
        /// 根锚点标识
        static let rootAnchor: String = "Root"
        /// 面包屑分隔符
        static let breadcrumbSeparator: String = " > "
        /// 上下文前缀模板
        static let contextPrefix: String = "[Context: "
        /// 上下文后缀
        static let contextSuffix: String = "]\n"
        /// 默认分块大小
        static let defaultChunkSize: Int = 1000
        /// 默认重叠窗口
        static let defaultChunkOverlap: Int = 200
        /// 默认分隔符梯度
        static let defaultSeparators: [String] = [
            "\n# ", "\n## ", "\n### ", "\n#### ",
            "\n\n", "\n", ". ", ". ", " ", ""
        ]
    }

    // MARK: - 合成处理 (Synthesis)
    enum Synthesis {
        /// Prompt 关键词：源
        static let promptKeywordSource: String = "Source"
        /// Prompt 关键词：格式
        static let promptKeywordFormat: String = "Format:"
        /// Prompt 关键词：要求
        static let promptKeywordRequirements: String = "Requirements:"
        /// Prompt 关键词集合
        static let promptKeywords: [String] = [
            promptKeywordSource,
            ProcessorConstants.Frontmatter.yamlDelimiter,
            promptKeywordFormat,
            promptKeywordRequirements
        ]
        /// Quiz 选项前缀 A
        static let quizOptionPrefixA: String = "A. "
        /// Quiz 选项前缀 B
        static let quizOptionPrefixB: String = "B. "
        /// Quiz 选项前缀 C
        static let quizOptionPrefixC: String = "C. "
        /// Quiz 选项前缀 D
        static let quizOptionPrefixD: String = "D. "
        /// Quiz Answer 关键字
        static let quizAnswerKeyword: String = "Answer:"
        /// Quiz Explanation 关键字
        static let quizExplanationKeyword: String = "Explanation:"
        /// Quiz 选项字母集合
        static let quizLetterOptions: [String] = ["A", "B", "C", "D"]
        /// Quiz 选项数字集合
        static let quizNumberOptions: [String] = ["1", "2", "3", "4"]
        /// Quiz 答案映射表
        static let quizAnswerMap: [String: Int] = [
            "A": 0, "1": 0,
            "B": 1, "2": 1,
            "C": 2, "3": 2,
            "D": 3, "4": 3
        ]
        /// Quiz 默认答案索引
        static let quizDefaultIndex: Int = 0
        /// Quiz 选项数量
        static let quizOptionCount: Int = 4
        /// Quiz 最小随机化选项数
        static let quizMinOptionsForRandomization: Int = 2
        /// Mermaid 节点缩进（一级）
        static let mermaidIndentLevel1: String = "    "
        /// Mermaid 节点缩进（二级）
        static let mermaidIndentLevel2: String = "      "
        /// Mermaid root 节点模板
        static let mermaidRootTemplate: String = "  root(("
        /// Mermaid root 节点后缀
        static let mermaidRootSuffix: String = "))"
        /// Mermaid 节点引号包裹模板
        static let mermaidQuotedNodeOpen: String = "[\""
        static let mermaidQuotedNodeClose: String = "\"]"
        /// Mermaid 双括号节点
        static let mermaidDoubleParenOpen: String = "(("
        static let mermaidDoubleParenClose: String = "))"
        /// Mermaid 花括号节点
        static let mermaidDoubleBraceOpen: String = "{{"
        static let mermaidDoubleBraceClose: String = "}}"
        /// Mermaid 危险字符集合
        static let mermaidDangerChars: [String] = [
            SystemConstants.Character.colon,
            SystemConstants.Character.questionMark,
            SystemConstants.Character.openParen,
            SystemConstants.Character.closeParen,
            SystemConstants.Character.openBracket,
            SystemConstants.Character.closeBracket,
            SystemConstants.Character.underscore,
            SystemConstants.Character.hash,
            SystemConstants.Character.openBrace,
            SystemConstants.Character.closeBrace,
            SystemConstants.Character.semicolon
        ]
        /// Mermaid 节点特殊字符集合（sanitizeLineNodes）
        static let mermaidSpecialChars: [Character] = [
            Swift.Character(ProcessorConstants.MarkdownSyntax.colon),
            Swift.Character(ProcessorConstants.MarkdownSyntax.openParen),
            Swift.Character(ProcessorConstants.MarkdownSyntax.closeParen),
            Swift.Character(ProcessorConstants.MarkdownSyntax.openBracket),
            Swift.Character(ProcessorConstants.MarkdownSyntax.closeBracket)
        ]
        /// 演示文稿最小有效标题长度
        static let minValidTitleLength: Int = 3
        /// 演示文稿每页最大 bullet 数
        static let maxBulletsPerSlide: Int = 4
        /// 演示文稿最小回退页数
        static let minFallbackSlideCount: Int = 4
        /// 演示文稿最大回退页数
        static let maxFallbackSlideCount: Int = 7
        /// 信息图节点最小长度
        static let infographicMinLength: Int = 2
        /// 信息图节点最大长度
        static let infographicMaxLength: Int = 40
        /// 信息图最大节点数
        static let infographicMaxNodes: Int = 6
        /// 报告前缀截取长度
        static let reportPrefixLength: Int = 300
        /// 报告要点最小长度
        static let reportPointMinLength: Int = 5
        /// 报告最大要点数
        static let reportMaxPoints: Int = 5
        /// 知识扩充前缀行数
        static let expansionPrefixLines: Int = 3
        /// 知识扩充最小每节行数
        static let expansionMinLinesPerSection: Int = 2
        /// Quiz 有效知识点最小长度
        static let quizPointMinLength: Int = 6
        /// Quiz 有效知识点最大长度
        static let quizPointMaxLength: Int = 60
        /// Quiz 最小有效知识点数
        static let quizMinValidPoints: Int = 3
        /// Quiz 回退题目数
        static let quizFallbackQuestionCount: Int = 3
        /// Quiz JSON 字段名：title
        static let quizTitleKey: String = "quizTitle"
        /// Quiz JSON 字段名：questions
        static let quizQuestionsKey: String = "questions"
        /// Quiz JSON 字段名：id
        static let quizIdKey: String = "id"
        /// Quiz JSON 字段名：question
        static let quizQuestionKey: String = "question"
        /// Quiz JSON 字段名：options
        static let quizOptionsKey: String = "options"
        /// Quiz JSON 字段名：answerIndex
        static let quizAnswerIndexKey: String = "answerIndex"
        /// Quiz JSON 字段名：explanation
        static let quizExplanationKey: String = "explanation"
        /// Quiz 首个 id
        static let quizFirstId: Int = 1
        /// Quiz 空 JSON
        static let quizEmptyJson: String = "{\"quizTitle\":\"\",\"questions\":[]}"
        /// 思维导图节点最小长度
        static let mindmapNodeMinLength: Int = 2
        /// 思维导图节点最大长度
        static let mindmapNodeMaxLength: Int = 30
    }

    // MARK: - 思考过程提取 (Thinking Processor)
    enum Thinking {
        /// 思考过程前缀（中文）
        static let prefixThinkingProcessColon: String = "思考过程："
        static let prefixThinkingProcessColonASCII: String = "思考过程:"
        static let prefixThinkingColon: String = "思考："
        static let prefixThinkingColonASCII: String = "思考:"
        static let prefixThinkingProcess: String = "Thinking Process:"
        static let prefixThinking: String = "Thinking:"
        static let prefixReasoningProcess: String = "Reasoning Process:"
        static let prefixReasoning: String = "Reasoning:"
        static let prefixThoughtAnalysis: String = "思路分析："
        static let prefixThoughtAnalysisASCII: String = "思路分析:"
        /// 思考过程前缀集合
        static let prefixes: [String] = [
            prefixThinkingProcessColon,
            prefixThinkingProcessColonASCII,
            prefixThinkingColon,
            prefixThinkingColonASCII,
            prefixThinkingProcess,
            prefixThinking,
            prefixReasoningProcess,
            prefixReasoning,
            prefixThoughtAnalysis,
            prefixThoughtAnalysisASCII
        ]
        /// 隐式 CoT 前缀：我们被要求
        static let implicitCoTWeAreAsked: String = "我们被要求"
        /// 隐式 CoT 前缀：用户需求
        static let implicitCoTUserNeedColon: String = "用户需求："
        static let implicitCoTUserNeedASCII: String = "用户需求:"
        /// 隐式 CoT 前缀：需求分析
        static let implicitCoTNeedAnalysisColon: String = "需求分析："
        static let implicitCoTNeedAnalysisASCII: String = "需求分析:"
        /// 隐式 CoT 前缀：分析用户
        static let implicitCoTAnalyzeUser: String = "分析用户"
        /// 隐式 CoT 前缀：解构问题
        static let implicitCoTDeconstructColon: String = "解构问题："
        static let implicitCoTDeconstructASCII: String = "解构问题:"
        /// 隐式 CoT 前缀集合
        static let implicitCoTPrefixes: [String] = [
            implicitCoTWeAreAsked,
            implicitCoTUserNeedColon,
            implicitCoTUserNeedASCII,
            implicitCoTNeedAnalysisColon,
            implicitCoTNeedAnalysisASCII,
            implicitCoTAnalyzeUser,
            implicitCoTDeconstructColon,
            implicitCoTDeconstructASCII
        ]
        /// 答案分隔关键字：根据
        static let dividerAccording: String = "\n\n根据"
        /// 答案分隔关键字：建议
        static let dividerSuggestion: String = "\n\n建议"
        /// 答案分隔关键字：以下是
        static let dividerFollowing: String = "\n\n以下是"
        /// 答案分隔关键字：编号列表
        static let dividerNumberedList: String = "\n\n1. "
        /// 答案分隔关键字：三级标题
        static let dividerH3: String = "\n\n### "
        /// 答案分隔关键字：回答
        static let dividerAnswer: String = "\n\n回答："
        /// 答案分隔关键字集合
        static let dividerKeywords: [String] = [
            dividerAccording,
            dividerSuggestion,
            dividerFollowing,
            dividerNumberedList,
            dividerH3,
            dividerAnswer
        ]
        /// think 标签正则（含闭合）
        static let thinkTagEnclosed: String = #"<think>(.*?)</think>"#
        /// thinking 标签正则（含闭合）
        static let thinkingTagEnclosed: String = #"<thinking>(.*?)</thinking>"#
        /// thought 标签正则（含闭合）
        static let thoughtTagEnclosed: String = #"<thought>(.*?)</thought>"#
        /// [think] 标签正则（含闭合）
        static let thinkBracketEnclosed: String = #"\[think\](.*?)\[/think\]"#
        /// [thinking] 标签正则（含闭合）
        static let thinkingBracketEnclosed: String = #"\[thinking\](.*?)\[/thinking\]"#
        /// [思考过程] 标签正则（含闭合）
        static let thinkingProcessBracketEnclosed: String = #"\[思考过程\](.*?)\[/思考过程\]"#
        /// ```think 代码块正则
        static let thinkCodeBlock: String = #"```think\s*\n(.*?)\n```"#
        /// 含闭合思考标签正则集合
        static let enclosedPatterns: [String] = [
            thinkTagEnclosed,
            thinkingTagEnclosed,
            thoughtTagEnclosed,
            thinkBracketEnclosed,
            thinkingBracketEnclosed,
            thinkingProcessBracketEnclosed,
            thinkCodeBlock
        ]
        /// 未闭合 think 标签正则
        static let thinkTagUnclosed: String = #"(?i)^<(think|thinking|thought)>(.*)"#
        /// 未闭合 [think] 标签正则
        static let thinkBracketUnclosed: String = #"(?i)^\[(think|thinking|thought|思考过程)\](.*)"#
        /// 未闭合思考标签正则集合
        static let unclosedPatterns: [String] = [
            thinkTagUnclosed,
            thinkBracketUnclosed
        ]
    }
}
