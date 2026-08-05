//
//  MarkdownProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：文档处理器：Markdown 解析、文本分块、图谱布局、网页抓取。
//
import Foundation

// MARK: - Markdown 解析器

/// Markdown 内容的纯解析层（MarkdownProcessor）。
/// 该解析器负责将输入的 Markdown 原始文本转换为结构化的数据块（BlockType）与行内标记（InlineType）模型，
/// 以屏蔽排版细节并暴露给高层业务。渲染工作由 `MarkdownRendererView` 独立处理，完美遵循单一职责原则（SRP）。
final class MarkdownProcessor: Sendable {

    // MARK: - 块类型

    /// 代表 Markdown 结构化文档中的高级排版物理块 (BlockType)。
    enum BlockType {
        /// 标题块。
        /// - Parameters:
        ///   - text: 标题文字内容。
        ///   - level: 标题层级，范围为 1 至 6，分别对应 # 至 ######。
        case heading(text: String, level: Int)
        
        /// 普通段落文本块。
        /// - Parameter text: 段落的纯文本内容。
        case paragraph(text: String)
        
        /// 无序或有序列表块。
        /// - Parameters:
        ///   - items: 列表中每一项的纯文本内容数组。
        ///   - indent: 缩进级别（若为有序列表，则该值统一约定为 -1）。
        ///   - startNumber: 起始编号（有序列表默认为 1，可从指定数字如 2, 3 起算）。
        case bulletList(items: [String], indent: Int, startNumber: Int = 1)
        
        /// 引用块（以 `>` 引导）。
        /// - Parameter text: 引用块内的文本内容。
        case blockquote(text: String)
        
        /// 代码块（以 ``` 引导与收尾）。
        /// - Parameters:
        ///   - code: 代码块内部的原始代码串。
        ///   - language: 编程语言名称标识（如 swift, python 等，可能为空）。
        case codeBlock(code: String, language: String)
        
        /// 标准 Markdown 表格块。
        /// - Parameters:
        ///   - headers: 表头单元格的内容数组。
        ///   - rows: 二维数组，表示表格的每一行单元格内容。
        case table(headers: [String], rows: [[String]])
        
        /// 水平分割线（如 `---` 或 `***`）。
        case horizontalRule
        
        /// 带有复选框的任务列表块。
        /// - Parameter items: 元组数组，包含任务项文字和是否已勾选的状态。
        case taskList(items: [(text: String, checked: Bool)])
        
        /// HTML 折叠细节块（`<details>` 标签）。
        /// - Parameters:
        ///   - summary: 折叠栏标题文案（由 `<summary>` 包含）。
        ///   - content: 折叠内部展开的原始 Markdown 字符串。
        case details(summary: String, content: String)
    }

    // MARK: - 行内类型

    /// 标记文本行内部微观样式的行内类型 (InlineType)。
    enum InlineType {
        /// 普通纯文本。
        case text
        /// 加粗文本（如 `**内容**`）。
        case bold
        /// 斜体文本（如 `*内容*` 或 `_内容_`）。
        case italic
        /// 删除线文本（如 `~~内容~~`）。
        case strikethrough
        /// 行内代码（如 `` `代码` ``）。
        case code
        /// 智宇专有的双链 App 链接（如 `[[目标页面]]` 或 `[[显示文案|目标页面]]`）。
        case applink
        /// 标准 Markdown 外链（如 `[文案](URL)`）。
        case link
        /// 单个表情符号。
        case emoji
    }

    /// 行内分割实体，表示具有特定微观样式的局部片段 (InlineSegment)。
    struct InlineSegment {
        /// 当前片段的行内样式类型。
        let type: InlineType
        /// 当前片段的实际文本或目标跳转载荷。
        let content: String
    }

    // MARK: - 解析完整内容

    /// 将输入的整段 Markdown 原始字符串解析为有序的结构化物理块数组。
    /// - Parameter content: 需要解析的原始 Markdown 文本。
    /// - Returns: 解析完成后的 `BlockType` 物理块数组。
    func parse(_ content: String) -> [BlockType] {
        let lines = content.components(separatedBy: ProcessorConstants.Whitespace.newline)
        var blocks: [BlockType] = []
        var i = 0

        while i < lines.count {
            let trimmed = lines[i].trimmingCharacters(in: .whitespaces)
            // 跳过空行，不创建块 — 空白行仅用作段落分隔符
            guard !trimmed.isEmpty else {
                i += 1
                continue
            }
            if let (block, nextIndex) = parseNextBlock(lines: lines, currentIndex: i, trimmed: trimmed) {
                blocks.append(block)
                i = nextIndex
            } else {
                blocks.append(.paragraph(text: trimmed))
                i += 1
            }
        }

        return blocks
    }

    /// 按优先级依次尝试各解析器，返回匹配到的块及下一扫描位置；若无匹配返回 nil
    private func parseNextBlock(lines: [String], currentIndex i: Int, trimmed: String) -> (BlockType, Int)? {
        // trimmed 已由 parse() 保证非空，无需再次检查

        if let result = parseDetailsBlock(lines: lines, startIndex: i) { return (result.block, result.nextIndex) }
        if let result = parseCodeBlock(lines: lines, startIndex: i) { return (result.block, result.nextIndex) }
        if let result = parseHeading(trimmed) { return (result, i + 1) }
        if let result = parseHorizontalRule(trimmed) { return (result, i + 1) }
        if let result = parseTaskList(lines: lines, startIndex: i) { return (result.block, result.nextIndex) }
        if let result = parseBulletList(lines: lines, startIndex: i) { return (result.block, result.nextIndex) }
        if let result = parseBlockquote(trimmed) { return (result, i + 1) }
        if let result = parseTable(lines: lines, startIndex: i) { return (result.block, result.nextIndex) }

        return nil
    }

    // MARK: - 行内解析（核心两阶段解析算法）

    /// 智宇系统核心：基于两阶段行内样式解析法提取富文本片段。
    ///
    /// - 核心设计初衷 (Conflict Prevention):
    ///   标准的正则表达式引擎在面对复合嵌套样式（如加粗斜体包围智宇双链，形如 `***[[知识页面]]***`）时，
    ///   极易发生贪婪模式匹配错乱，导致双链标志 `[[` 与 `]]` 被错误切断破坏。
    ///   为彻底根除此项工业级痛点，我们设计了精妙的“两阶段解析算法”：
    ///   1. **阶段一 (Applink 保护区)**：优先全局检索并提取所有的智宇双链 `[[...]]` 位置。将其视为高级黄金保护节点固定下来。
    ///   2. **阶段二 (格式化碎裂匹配)**：在两个双链节点之间的物理夹缝文本段中，依次级联运行 Bold、Italic、Strikethrough、Link 与 Code 正则，
    ///      从而实现防对撞、防截断的完美富文本物理分割。
    ///
    /// - Parameter text: 包含各种行内标记的原始单行 Markdown 字符串。
    /// - Returns: 有序排列的行内样式片段（`InlineSegment`）实体数组。
    func parseInlineSegments(_ text: String) -> [InlineSegment] {
        // 步骤 1.1：为避免 Objective-C NSString 范围与 Swift String.Index 偏移冲突导致崩溃，将输入字符串安全转换为 NSString
        let nsText = text as NSString
        var result: [InlineSegment] = []
        var currentOffset = 0

        // 步骤 1.2：第一阶段——寻找所有的 Applink。定义整行覆盖范围，并利用预编译的 appLinkRegex 查找全部 `[[双向链接]]`
        let searchRange = NSRange(location: 0, length: nsText.length)
        let applinkMatches = NSRegularExpression.appLinkRegex.matches(in: text, options: [], range: searchRange)

        // 步骤 1.3：启动双链迭代扫描，将每一个捕获到的双链区域视为绝对保护段
        for match in applinkMatches {
            // 步骤 1.4：如果当前双链匹配的起点大于记录 of 偏移量，说明中间夹有非双链文本，截取子串并调度二级格式化解析器进行深度匹配
            if match.range.location > currentOffset {
                let beforeRange = NSRange(location: currentOffset, length: match.range.location - currentOffset)
                let beforeText = nsText.substring(with: beforeRange)
                result.append(contentsOf: parseFormattingSegments(beforeText))
            }

            // 步骤 1.5：提取双链中由第一捕获组 `(.+?)` 所包裹的原始字面量，并安全剔除首尾多余空格
            let raw = nsText.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
            let content: String
            
            // 步骤 1.6：若包含管线符 `|`，说明是别名双链（如 `[[我的链接|实际页面]]`），进行物理切分，将别名与真实页面组合编码以备后续使用
            if raw.contains("|") {
                let parts = raw.components(separatedBy: "|")
                let label = String(parts.first ?? "").trimmingCharacters(in: .whitespaces)
                let title = String(parts.last ?? "").trimmingCharacters(in: .whitespaces)
                content = "\(label)|\(title)"
            } else {
                content = raw
            }
            
            // 步骤 1.7：将处理完毕的双链封装为 .applink 段追加进结果中，并将偏移量同步平移到双链闭合括号 `]]` 的下一位
            result.append(InlineSegment(type: .applink, content: content))
            currentOffset = match.range.location + match.range.length
        }

        // 步骤 1.8：首阶段扫尾。若最后一个双链解析完毕后，偏移量距离字符串总长度还有剩余，说明尾端存在碎屑文本，再次调用二级解析器扫尾
        if currentOffset < nsText.length {
            let remaining = nsText.substring(from: currentOffset)
            result.append(contentsOf: parseFormattingSegments(remaining))
        }

        return result
    }

    /// 第二阶段解析：在双链保护区夹缝中，深度级联提取普通富文本标记（加粗、斜体、删除线、外链及代码块）。
    ///
    /// - Parameter text: 夹在双链片段之间的子区间纯文本字串。
    /// - Returns: 解析完毕的局域行内格式化片段列表。
    private func parseFormattingSegments(_ text: String) -> [InlineSegment] {
        var segments: [InlineSegment] = []
        let nsText = text as NSString
        var currentOffset = 0

        // 步骤 2.1：定义高优先级贪婪度格式正则的级联匹配字典，严格按照“外链 -> 粗体 -> 斜体 -> 删除线 -> 行内代码”的物理次序层级递归
        let patterns: [(InlineType, NSRegularExpression)] = [
            (.link, .linkRegex),
            (.bold, .boldRegex),
            (.italic, .italicRegex),
            (.strikethrough, .strikethroughRegex),
            (.code, .codeRegex)
        ]

        // 步骤 2.2：启动位置平移指针，开始循环扫描碎屑区间的所有微观格式
        while currentOffset < nsText.length {
            var earliestMatch: (type: InlineType, match: NSTextCheckingResult)?

            // 步骤 2.3：为防止跨样式对冲命中，在当前偏移量后依次运行所有格式正则，寻找“首个被物理命中的最前方格式前缀”（即 location 最小者）
            for (type, regex) in patterns {
                if let match = regex.firstMatch(in: text, options: [], range: NSRange(location: currentOffset, length: nsText.length - currentOffset)) {
// swiftlint:disable:next force_unwrapping
                    if earliestMatch == nil || match.range.location < earliestMatch!.match.range.location {
                        earliestMatch = (type, match)
                    }
                }
            }

            // 步骤 2.4：若检测到有效格式命中，则提取该匹配段前方的纯文本字串，将其安全封包为 `.text` 原始片段
            if let earliest = earliestMatch {
                let matchRange = earliest.match.range
                
                if matchRange.location > currentOffset {
                    let before = nsText.substring(with: NSRange(location: currentOffset, length: matchRange.location - currentOffset))
                    segments.append(InlineSegment(type: .text, content: before))
                }

                // 步骤 2.5：核心内容清洗——剥离格式化引导符（如 `**`、`~~`、`[ ]`），精准还原捕获组内的真正正文，并区分处理 Markdown 外链
                let content: String
                switch earliest.type {
                case .link:
                    let label = nsText.substring(with: earliest.match.range(at: 1))
                    let url = nsText.substring(with: earliest.match.range(at: 2))
                    content = "\(label)|\(url)"
                case .bold, .italic, .code, .strikethrough:
                    content = nsText.substring(with: earliest.match.range(at: 1))
                default:
                    content = ""
                }

                // 步骤 2.6：装载匹配到的 Segment 实例，并瞬间平移当前偏移量至整个匹配区间（如整个 **粗体**）的闭合标记之后
                segments.append(InlineSegment(type: earliest.type, content: content))
                currentOffset = matchRange.location + matchRange.length
            } else {
                // 步骤 2.7：当没有任何格式化正则被命中的情况下，将剩余所有字符合并打包为最后的普通 `.text` Segment 载荷，打断循环
                let remaining = nsText.substring(from: currentOffset)
                if !remaining.isEmpty {
                    segments.append(InlineSegment(type: .text, content: remaining))
                }
                break
            }
        }
        return segments
    }

    // MARK: - 表格辅助解析方法

    /// 提取表格行中被管线符 `|` 物理分隔的多列单元格文本。
}

// MARK: - 正则表达式拓展

extension NSRegularExpression {
    static let appLinkRegex: NSRegularExpression = {
        do { return try NSRegularExpression(pattern: "(?<!\\\\)\\[\\[(.+?)\\]\\]") } catch { fatalError("MarkdownProcessor: 无效正则 appLinkRegex — \(error)") }
    }()
    static let boldRegex: NSRegularExpression = {
        do { return try NSRegularExpression(pattern: "(?<!\\\\)\\*\\*(.+?)\\*\\*") } catch { fatalError("MarkdownProcessor: 无效正则 boldRegex — \(error)") }
    }()
    static let italicRegex: NSRegularExpression = {
        do { return try NSRegularExpression(pattern: "(?<!\\\\)[\\*_](.+?)[\\*_]") } catch { fatalError("MarkdownProcessor: 无效正则 italicRegex — \(error)") }
    }()
    static let strikethroughRegex: NSRegularExpression = {
        do { return try NSRegularExpression(pattern: "(?<!\\\\)~~(.+?)~~") } catch { fatalError("MarkdownProcessor: 无效正则 strikethroughRegex — \(error)") }
    }()
    static let codeRegex: NSRegularExpression = {
        do { return try NSRegularExpression(pattern: "(?<!\\\\)`(.+?)`") } catch { fatalError("MarkdownProcessor: 无效正则 codeRegex — \(error)") }
    }()
    static let linkRegex: NSRegularExpression = {
        do { return try NSRegularExpression(pattern: "(?<!\\\\)\\[(.+?)\\]\\((.+?)\\)") } catch { fatalError("MarkdownProcessor: 无效正则 linkRegex — \(error)") }
    }()
}
