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
public enum ProcessorConstants {

    // MARK: - Markdown 语法符号 (Markdown Syntax)
    /// 基础字符引用 UFPCore.SystemConstants.Character，业务层转接为 Markdown 语义名称
    public enum MarkdownSyntax {
        // 单字符标记（转接 UFPCore 基础字符）
        public static let hash: String = SystemConstants.Character.hash
        public static let dash: String = SystemConstants.Character.dash
        public static let asterisk: String = SystemConstants.Character.asterisk
        public static let greaterThan: String = SystemConstants.Character.greaterThan
        public static let dot: String = SystemConstants.Character.dot
        public static let doubleQuote: String = SystemConstants.Character.doubleQuote
        public static let singleQuote: String = SystemConstants.Character.singleQuote
        public static let slash: String = SystemConstants.Character.slash
        public static let doubleSlash: String = SystemConstants.Character.doubleSlash
        public static let colon: String = SystemConstants.Character.colon
        public static let questionMark: String = SystemConstants.Character.questionMark
        public static let underscore: String = SystemConstants.Character.underscore
        public static let openParen: String = SystemConstants.Character.openParen
        public static let closeParen: String = SystemConstants.Character.closeParen
        public static let openBracket: String = SystemConstants.Character.openBracket
        public static let closeBracket: String = SystemConstants.Character.closeBracket

        // CJK 标点
        public static let cjkOpenBracket: String = "【"

        // 标题前缀
        /// 引用 SystemConstants.MarkdownSyntax.h1Prefix
        public static let h1Prefix: String = SystemConstants.MarkdownSyntax.h1Prefix
        /// 引用 SystemConstants.MarkdownSyntax.h2Prefix
        public static let h2Prefix: String = SystemConstants.MarkdownSyntax.h2Prefix

        // 列表标记
        /// 引用 SystemConstants.MarkdownSyntax.bulletDash
        public static let bulletDash: String = SystemConstants.MarkdownSyntax.bulletDash
        /// 引用 SystemConstants.MarkdownSyntax.bulletAsterisk
        public static let bulletAsterisk: String = SystemConstants.MarkdownSyntax.bulletAsterisk
        public static let bulletPlus: String = "+ "

        // 任务列表标记
        public static let taskUncheckedDash: String = "- [ ] "
        public static let taskCheckedDashLower: String = "- [x] "
        public static let taskCheckedDashUpper: String = "- [X] "
        public static let taskUncheckedAsterisk: String = "* [ ] "
        public static let taskCheckedAsteriskLower: String = "* [x] "
        public static let taskCheckedAsteriskUpper: String = "* [X] "

        // 引用块
        public static let blockquotePrefix: String = "> "

        // 代码块
        public static let codeFence: String = "```"
        public static let mermaidFence: String = "```mermaid"

        // 粗体/斜体
        /// 引用 SystemConstants.MarkdownSyntax.bold
        public static let bold: String = SystemConstants.MarkdownSyntax.bold

        // 水平线
        /// 引用 SystemConstants.MarkdownDelimiter.horizontalRule
        public static let horizontalRuleDash: String = SystemConstants.MarkdownDelimiter.horizontalRule
        public static let horizontalRuleAsterisk: String = "***"
        public static let horizontalRuleUnderscore: String = "___"

        // 表格
        public static let tableSeparatorDash: String = "|-"
        public static let tableSeparatorDashSpace: String = "| -"
        public static let tablePipe: String = SystemConstants.Character.pipe

        // 标题分隔（用于 PPTX 等文档拆分）
        public static let sectionBreak: String = "\n## "

        // 演示文稿分页符
        public static let slideSeparator: String = "\n---\n"
        public static let slideSeparatorSpaced: String = "\n--- \n"
        public static let slideJoinSeparator: String = "\n\n---\n\n"

        // MARK: 转义字符替换映射（cleanMarkdown 用）
        /// Markdown 转义字符 → 原始字符的替换映射
        public static let escapeReplacements: [(target: String, replacement: String)] = [
            ("\\+", "+"), ("\\-", "-"), ("\\*", "*"), ("\\. ", ". "),
            ("\\!", "!"), ("\\[\\[", "[["), ("\\]\\]", "]]"),
            ("\\\\[", "["), ("\\\\]", "]")
        ]
    }

    // MARK: - HTML 标签 (HTML Tags)
    public enum HTMLTag {
        // 折叠块
        public static let detailsOpen: String = "<details>"
        public static let detailsClose: String = "</details>"
        public static let summaryOpen: String = "<summary>"
        public static let summaryClose: String = "</summary>"
    }

    // MARK: - HTML 清洗正则 (Sanitization Regex)
    public enum SanitizationRegex {
        /// 匹配所有 HTML 标签
        public static let allTags: String = "<[^>]+>"
        /// 匹配 <style> 标签及其内容（含跨行）
        public static let styleBlock: String = "<style[^>]*>[\\s\\S]*?</style>"
        /// 匹配 <script> 标签及其内容（大小写不敏感且跨行匹配）
        public static let scriptBlock: String = "(?is)<script[^>]*>.*?</script>"
        /// 匹配 <style> 标签及其内容（大小写不敏感且跨行匹配）
        public static let styleBlockCaseInsensitive: String = "(?is)<style[^>]*>.*?</style>"
    }

    // MARK: - Mermaid 图表语法 (Mermaid Syntax)
    public enum MermaidSyntax {
        /// Mermaid 节点语法冲突字符（标题净化时需清除）
        public static let flowchart: String = "flowchart"
        public static let graph: String = "graph"
        public static let graphTD: String = "graph TD"
        public static let graphLR: String = "graph LR"
        public static let graphTB: String = "graph TB"
        public static let graphBT: String = "graph BT"
        public static let mindmap: String = "mindmap"
        public static let sequenceDiagram: String = "sequenceDiagram"
        public static let gantt: String = "gantt"
        public static let pie: String = "pie"
        public static let timeline: String = "timeline"
        public static let td: String = "TD"
        public static let root: String = "Root"
        public static let mindmapRoot: String = "root"
        public static let rootLabel: String = "Root[\""
        public static let nodeLabel: String = "Node"
        public static let arrow: String = " --> "
        public static let indent: String = "  "
        public static let labelSuffix: String = "\"]"
        public static let doubleParenOpen: String = "(("
        public static let doubleParenClose: String = "))"
        public static let doubleBraceOpen: String = "{{"
        public static let doubleBraceClose: String = "}}"
        public static let patternSuffix: String = ".*"
        public static let validPrefixes: [String] = [mindmap, graph, flowchart, sequenceDiagram, gantt, pie, timeline]
        public static let matchPatterns: [String] = [
            mindmap + patternSuffix,
            graph + patternSuffix,
            pie + patternSuffix,
            timeline + patternSuffix,
            sequenceDiagram + patternSuffix,
            gantt + patternSuffix
        ]
        public static let keywordSpacingCandidates: [String] = [
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
    public enum OOXML {
        // Word OOXML
        public static let wordText: String = "w:t"
        public static let wordParagraph: String = "w:p"
        // Excel OOXML
        public static let xmlExtension: String = ".xml"
        public static let excelWorksheetPrefix: String = "xl/worksheets/sheet"
        public static let sharedStringsPath: String = "xl/sharedStrings.xml"
        public static let wordDocumentPath: String = "word/document.xml"
        public static let cellElement: String = "c"
        public static let valueElement: String = "v"
        public static let textElement: String = "t"
        public static let cellTypeAttribute: String = "t"
        public static let cellTypeShared: String = "s"
        public static let cellTypeInlineString: String = "inlineStr"
        public static let cellTypeFormulaString: String = "str"
        public static let cellTypeNumber: String = "n"
        public static let sharedStringIndexOpen: String = "["
        public static let sharedStringIndexClose: String = "]"
        public static let sharedStringIndexMax: Int = 10000
        // Office 文档嵌入图片的媒体目录路径
        public static let imageMediaFolders: [String] = ["word/media", "xl/media", "ppt/media"]
        /// PPTX 幻灯片 ID 基址（OOXML 规范：sldId 从 256 开始）
        public static let pptxSlideIdBase: Int = 255
    }

    // MARK: - 空白字符 (Whitespace)
    /// 基础空白字符引用 UFPCore.SystemConstants.Character，业务层转接为语义名称
    public enum Whitespace {
        public static let empty: String = ""
        public static let space: String = SystemConstants.Character.space
        public static let newline: String = SystemConstants.Character.newline
        public static let doubleNewline: String = "\n\n"
        public static let tripleNewline: String = "\n\n\n"
        public static let newlineWithIndent: String = "\n  "
        public static let tab: String = SystemConstants.Character.tab
        public static let doubleSpace: String = "  "
        public static let dotSpace: String = ". "
        public static let ideographicComma: String = "、"
    }

    // MARK: - 模块标识 (Module Identity)
    public enum Module {
        public static let webScraper: String = "WebScraper"
        public static let paywallBlocked: String = "Paywall_Blocked"
    }

    // MARK: - 网页抓取器 (Web Scraper)
    public enum WebScraper {
        /// Jina 请求超时（秒）
        public static let jinaTimeoutInterval: TimeInterval = 10
        /// 直接抓取超时（秒）
        public static let directTimeoutInterval: TimeInterval = 15
        /// 归档抓取超时（秒）
        public static let archiveTimeoutInterval: TimeInterval = 20
        /// Googlebot UA 版本
        public static let googlebotVersion: String = "2.1"
        /// Mozilla 版本
        public static let mozillaVersion: String = "5.0"
        /// Accept header q 值
        public static let acceptQValueHigh: String = "0.9"
        /// Accept header q 值
        public static let acceptQValueLow: String = "0.8"
        /// 日志详情模板
        public static let logDetailsTemplate: String = "%@ (Length: %lld)"
        /// 受限 HTTP 状态码
        public static let restrictedStatusCodes: [Int] = [
            SystemConstants.HTTPStatusCode.unauthorized,
            SystemConstants.HTTPStatusCode.paymentRequired,
            SystemConstants.HTTPStatusCode.forbidden,
            SystemConstants.HTTPStatusCode.rateLimited
        ]
        /// HTTPS 协议前缀（不带 //）
        public static let httpsPrefix: String = "https:"
        /// 通用桌面浏览器 UA（引用 SystemConstants.UserAgent.desktopSafari）
        public static let desktopUserAgent: String = SystemConstants.UserAgent.desktopSafari
    }

    // MARK: - HTML 提取正则模式 (HTML Extraction Regex)
    public enum HTMLRegex {
        /// 匹配 <title> 标签内容
        public static let titleTag: String = "<title>(.*?)</title>"
        /// 匹配 <article> 标签内容（大小写不敏感）
        public static let articleTag: String = "(?i)<article[^>]*>(.*?)</article>"
        /// 匹配 <main> 标签内容（大小写不敏感）
        public static let mainTag: String = "(?i)<main[^>]*>(.*?)</main>"
        /// 匹配 <p> 段落标签内容
        public static let paragraphTag: String = "<p[^>]*>(.*?)</p>"
        /// 匹配 <img> 标签的 src 属性值
        public static let imgSrcTag: String = #"<img[^>]+src\s*=\s*["']([^"']+)["'][^>]*>"#
    }

    // MARK: - HTML 实体解码映射 (HTML Entity Decoding)
    public enum HTMLEntity {
        /// HTML 实体 → 字符映射表（覆盖常见命名实体与数字实体）
        public static let decodeMap: [String: String] = [
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
    public enum FileFormat {
        public static let pdf: String = "pdf"
        public static let office: String = "office"
        public static let svg: String = "svg"
    }

    // MARK: - OCR 图片标注模板 (OCR Image Annotation)

    /// OCR 图片标注 Markdown 模板常量集
    public enum OCRAnnotation {
        /// HTML 图片 OCR 标注模板（参数：序号, 识别文本）
        public static let htmlImageTemplate: String = "> ![img_%d]: %@"
        /// PDF/Office 图片 OCR 标注模板（参数：前缀, 序号, 识别文本）
        public static let prefixedImageTemplate: String = "> ![%@_%d]: %@"
    }

    // MARK: - Frontmatter 语法 (Frontmatter Syntax)
    public enum Frontmatter {
        /// 引用 SystemConstants.MarkdownDelimiter.horizontalRule，避免重复定义
        public static let yamlDelimiter: String = SystemConstants.MarkdownDelimiter.horizontalRule
        public static let minKey: String = "min"
    }

    // MARK: - 正则模式 (Regex Patterns)
    public enum RegexPattern {
        /// 匹配编号列表前缀（如 "1. " 或 "12、"）
        public static let numberedList: String = "^[0-9]+[.\\s、]+"
        /// 匹配选择题选项前缀（如 "A. " 或 "B:"）
        public static let choiceOption: String = "^[A-D][.\\s、:]"
        /// 多行匹配标志前缀
        public static let multilineFlag: String = "(?s)"
        /// 匹配 Markdown 行首项目符号/标题前缀（- * + # 数字.）
        public static let markdownBulletStrip: String = #"^[\-\*\+\#\d\.]+\s*"#
        /// 匹配 Markdown 标题井号前缀
        public static let markdownHeaderStrip: String = #"^#+\s*"#
        /// 匹配 Quiz 选项前缀（A-D 或数字 + 分隔符）
        public static let quizOptionPrefix: String = #"^[A-D\d][\.\s、:]\s*"#
        /// 匹配 Quiz 选项剥离前缀（- 或 * 后跟空白）
        public static let quizOptionStrip: String = "^[*\\-]\\s*"
        /// 匹配 Quiz Answer 行（Answer: 后跟字母/数字）
        public static let quizAnswer: String = #"Answer:\s*([A-Da-d1-4])"#
        /// 匹配 Mermaid 标准节点 NodeID[Label]
        public static let mermaidNodeStandard: String = #"([A-Za-z0-9_\-]+)\[([^"\]]+)\]"#
        /// 匹配 Mermaid 嵌套方括号节点 NodeID[Label[...]]
        public static let mermaidNodeNested: String = #"([A-Za-z0-9_\-]+)\[([^"\]]*\[[^\]]*\][^"\]]*)\]"#
        /// Mermaid 节点替换模板（NodeID["Label"]）
        public static let mermaidNodeTemplate: String = #"$1["$3"]"#
        /// 匹配 Mermaid 节点尾部连字符
        public static let mermaidTrailingDash: String = #"-+$"#
        /// 匹配 Mermaid 节点括号内容
        public static let mermaidNodeBracket: String = #"(\w+)(\[+|\(+|\{+)(.+?)(\]+|\)+|\}+)"#
        /// 匹配 Prompt 控制参数块（篇幅要求/目标受众等）
        public static let promptBlockDepth: String = #"【(篇幅要求|目标受众|语气风格|自定义要求|深度要求)[^】]*】[^\n]*\n?"#
        /// 匹配 Prompt 控制参数块（简短形式）
        public static let promptBlockShort: String = #"【(篇幅|受众|语气|风格)[^】]*】[^\n]*\n?"#
    }

    // MARK: - 合成处理 (Synthesis)
    public enum Synthesis {
        /// Prompt 关键词：源
        public static let promptKeywordSource: String = "Source"
        /// Prompt 关键词：格式
        public static let promptKeywordFormat: String = "Format:"
        /// Prompt 关键词：要求
        public static let promptKeywordRequirements: String = "Requirements:"
        /// Prompt 关键词集合
        public static let promptKeywords: [String] = [
            promptKeywordSource,
            ProcessorConstants.Frontmatter.yamlDelimiter,
            promptKeywordFormat,
            promptKeywordRequirements
        ]
        /// Quiz Answer 关键字
        public static let quizAnswerKeyword: String = "Answer:"
        /// Quiz Explanation 关键字
        public static let quizExplanationKeyword: String = "Explanation:"
        /// Quiz 选项字母集合
        public static let quizLetterOptions: [String] = ["A", "B", "C", "D"]
        /// Quiz 答案映射表
        public static let quizAnswerMap: [String: Int] = [
            "A": 0, "1": 0,
            "B": 1, "2": 1,
            "C": 2, "3": 2,
            "D": 3, "4": 3
        ]
        /// Quiz 默认答案索引
        public static let quizDefaultIndex: Int = 0
        /// Quiz 选项数量
        public static let quizOptionCount: Int = 4
        /// Quiz 最小随机化选项数
        public static let quizMinOptionsForRandomization: Int = 2
        /// Mermaid 节点缩进（一级）
        public static let mermaidIndentLevel1: String = "    "
        /// Mermaid 节点缩进（二级）
        public static let mermaidIndentLevel2: String = "      "
        /// Mermaid 节点引号包裹模板
        public static let mermaidQuotedNodeOpen: String = "[\""
        public static let mermaidQuotedNodeClose: String = "\"]"
        /// Mermaid 危险字符集合
        public static let mermaidDangerChars: [String] = [
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
        public static let mermaidSpecialChars: [Character] = [
            Swift.Character(ProcessorConstants.MarkdownSyntax.colon),
            Swift.Character(ProcessorConstants.MarkdownSyntax.openParen),
            Swift.Character(ProcessorConstants.MarkdownSyntax.closeParen),
            Swift.Character(ProcessorConstants.MarkdownSyntax.openBracket),
            Swift.Character(ProcessorConstants.MarkdownSyntax.closeBracket)
        ]
        /// 演示文稿最小有效标题长度
        public static let minValidTitleLength: Int = 3
        /// 演示文稿每页最大 bullet 数
        public static let maxBulletsPerSlide: Int = 4
        /// 演示文稿最小回退页数
        public static let minFallbackSlideCount: Int = 4
        /// 演示文稿最大回退页数
        public static let maxFallbackSlideCount: Int = 7
        /// 信息图节点最小长度
        public static let infographicMinLength: Int = 2
        /// 信息图节点最大长度
        public static let infographicMaxLength: Int = 40
        /// 信息图最大节点数
        public static let infographicMaxNodes: Int = 6
        /// 报告前缀截取长度
        public static let reportPrefixLength: Int = 300
        /// 报告要点最小长度
        public static let reportPointMinLength: Int = 5
        /// 报告最大要点数
        public static let reportMaxPoints: Int = 5
        /// 知识扩充前缀行数
        public static let expansionPrefixLines: Int = 3
        /// 知识扩充最小每节行数
        public static let expansionMinLinesPerSection: Int = 2
        /// Quiz JSON 字段名：title
        public static let quizTitleKey: String = "quizTitle"
        /// Quiz JSON 字段名：questions
        public static let quizQuestionsKey: String = "questions"
        /// Quiz JSON 字段名：id
        public static let quizIdKey: String = "id"
        /// Quiz JSON 字段名：question
        public static let quizQuestionKey: String = "question"
        /// Quiz JSON 字段名：options
        public static let quizOptionsKey: String = "options"
        /// Quiz JSON 字段名：answerIndex
        public static let quizAnswerIndexKey: String = "answerIndex"
        /// Quiz JSON 字段名：explanation
        public static let quizExplanationKey: String = "explanation"
        /// Quiz 首个 id
        public static let quizFirstId: Int = 1
        /// Quiz 空 JSON
        public static let quizEmptyJson: String = "{\"quizTitle\":\"\",\"questions\":[]}"
        /// 思维导图节点最小长度
        public static let mindmapNodeMinLength: Int = 2
        /// 思维导图节点最大长度
        public static let mindmapNodeMaxLength: Int = 30
        /// 自愈日志原因：Expansion 内容不足
        public static let selfHealReasonInsufficientExpansion: String = "[SynthesisStatus: SelfHealed] Reason: InsufficientExpansionContent"
        /// 自愈日志原因：Report 内容不足
        public static let selfHealReasonInsufficientReport: String = "[SynthesisStatus: SelfHealed] Reason: InsufficientReportContent"
        /// 自愈日志原因：字节数不足
        public static let selfHealReasonInsufficientBytes: String = "[SynthesisStatus: SelfHealed] Reason: InsufficientBytes"
        /// 自愈日志原因：无效 Mermaid
        public static let selfHealReasonInvalidMermaid: String = "[SynthesisStatus: SelfHealed] Reason: InvalidMermaid"
        /// 自愈日志原因：无效信息图 Mermaid
        public static let selfHealReasonInvalidInfographic: String = "[SynthesisStatus: SelfHealed] Reason: InvalidInfographicMermaid"
        /// 自愈日志原因：无效 Quiz JSON
        public static let selfHealReasonInvalidQuizJSON: String = "[SynthesisStatus: SelfHealed] Reason: InvalidQuizJSON"
    }

    // MARK: - 思考过程提取 (Thinking Processor)
    public enum Thinking {
        /// 思考过程前缀（中文）
        public static let prefixThinkingProcessColon: String = "思考过程："
        public static let prefixThinkingProcessColonASCII: String = "思考过程:"
        public static let prefixThinkingColon: String = "思考："
        public static let prefixThinkingColonASCII: String = "思考:"
        public static let prefixThinkingProcess: String = "Thinking Process:"
        public static let prefixThinking: String = "Thinking:"
        public static let prefixReasoningProcess: String = "Reasoning Process:"
        public static let prefixReasoning: String = "Reasoning:"
        public static let prefixThoughtAnalysis: String = "思路分析："
        public static let prefixThoughtAnalysisASCII: String = "思路分析:"
        /// 思考过程前缀集合
        public static let prefixes: [String] = [
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
        public static let implicitCoTWeAreAsked: String = "我们被要求"
        /// 隐式 CoT 前缀：用户需求
        public static let implicitCoTUserNeedColon: String = "用户需求："
        public static let implicitCoTUserNeedASCII: String = "用户需求:"
        /// 隐式 CoT 前缀：需求分析
        public static let implicitCoTNeedAnalysisColon: String = "需求分析："
        public static let implicitCoTNeedAnalysisASCII: String = "需求分析:"
        /// 隐式 CoT 前缀：分析用户
        public static let implicitCoTAnalyzeUser: String = "分析用户"
        /// 隐式 CoT 前缀：解构问题
        public static let implicitCoTDeconstructColon: String = "解构问题："
        public static let implicitCoTDeconstructASCII: String = "解构问题:"
        /// 隐式 CoT 前缀集合
        public static let implicitCoTPrefixes: [String] = [
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
        public static let dividerAccording: String = "\n\n根据"
        /// 答案分隔关键字：建议
        public static let dividerSuggestion: String = "\n\n建议"
        /// 答案分隔关键字：以下是
        public static let dividerFollowing: String = "\n\n以下是"
        /// 答案分隔关键字：编号列表
        public static let dividerNumberedList: String = "\n\n1. "
        /// 答案分隔关键字：三级标题
        public static let dividerH3: String = "\n\n### "
        /// 答案分隔关键字：回答
        public static let dividerAnswer: String = "\n\n回答："
        /// 答案分隔关键字集合
        public static let dividerKeywords: [String] = [
            dividerAccording,
            dividerSuggestion,
            dividerFollowing,
            dividerNumberedList,
            dividerH3,
            dividerAnswer
        ]
        /// think 标签正则（含闭合）
        public static let thinkTagEnclosed: String = #"<think>(.*?)</think>"#
        /// thinking 标签正则（含闭合）
        public static let thinkingTagEnclosed: String = #"<thinking>(.*?)</thinking>"#
        /// thought 标签正则（含闭合）
        public static let thoughtTagEnclosed: String = #"<thought>(.*?)</thought>"#
        /// [think] 标签正则（含闭合）
        public static let thinkBracketEnclosed: String = #"\[think\](.*?)\[/think\]"#
        /// [thinking] 标签正则（含闭合）
        public static let thinkingBracketEnclosed: String = #"\[thinking\](.*?)\[/thinking\]"#
        /// [思考过程] 标签正则（含闭合）
        public static let thinkingProcessBracketEnclosed: String = #"\[思考过程\](.*?)\[/思考过程\]"#
        /// ```think 代码块正则
        public static let thinkCodeBlock: String = #"```think\s*\n(.*?)\n```"#
        /// 含闭合思考标签正则集合
        public static let enclosedPatterns: [String] = [
            thinkTagEnclosed,
            thinkingTagEnclosed,
            thoughtTagEnclosed,
            thinkBracketEnclosed,
            thinkingBracketEnclosed,
            thinkingProcessBracketEnclosed,
            thinkCodeBlock
        ]
        /// 未闭合 think 标签正则
        public static let thinkTagUnclosed: String = #"(?i)^<(think|thinking|thought)>(.*)"#
        /// 未闭合 [think] 标签正则
        public static let thinkBracketUnclosed: String = #"(?i)^\[(think|thinking|thought|思考过程)\](.*)"#
        /// 未闭合思考标签正则集合
        public static let unclosedPatterns: [String] = [
            thinkTagUnclosed,
            thinkBracketUnclosed
        ]
    }

    // MARK: - Markdown 标题 (Heading)
    /// Markdown 标题层级约束
    public enum Heading {
        /// 最小标题层级
        public static let minLevel: Int = 1
        /// 最大标题层级
        public static let maxLevel: Int = 6
    }

    // MARK: - 缩进换算 (Indentation)
    /// 缩进与制表符换算常量
    public enum Indentation {
        /// 1 个制表符等价的空格数
        public static let spacesPerTab: Int = 4
    }

    // MARK: - Markdown 行内格式正则 (Inline Format Regex)
    /// Markdown 行内标记（appLink/bold/italic/strikethrough/code/link）正则模式
    public enum InlineRegex {
        /// App Link 双方括号 `[[link]]`
        public static let appLink: String = #"(?<!\\)\[\[(.+?)\]\]"#
        /// 加粗 `**bold**`
        public static let bold: String = #"(?<!\\)\*\*(.+?)\*\*"#
        /// 斜体 `*italic*` 或 `_italic_`
        public static let italic: String = #"(?<!\\)[\*_](.+?)[\*_]"#
        /// 删除线 `~~text~~`
        public static let strikethrough: String = #"(?<!\\)~~(.+?)~~"#
        /// 行内代码 `` `code` ``
        public static let code: String = #"(?<!\\)`(.+?)`"#
        /// 链接 `[text](url)`
        public static let link: String = #"(?<!\\)\[(.+?)\]\((.+?)\)"#
    }
}
