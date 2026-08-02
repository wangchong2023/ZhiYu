//
//  MarkdownProcessor+BlockParsing.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/07.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：Markdown 块级元素解析扩展（标题/列表/表格/代码块等）。
//           从 MarkdownProcessor 独立提取，遵循单一职责原则 (SRP)。
//
import Foundation

extension MarkdownProcessor {

    // MARK: - 私有解析辅助方法

    /// 尝试解析 HTML 折叠块 `<details>`。
    /// - Parameters:
    ///   - lines: 原始全文按行拆分后的数组。
    ///   - startIndex: 当前扫描的起始行索引。
    /// - Returns: 若匹配成功，返回折叠块实体与下一行待扫描的偏移索引；否则返回 `nil`。
    func parseDetailsBlock(lines: [String], startIndex: Int) -> (block: BlockType, nextIndex: Int)? {
        let trimmed = lines[startIndex].trimmingCharacters(in: .whitespaces)
        // 检查折叠标签的开端
        guard trimmed.hasPrefix("<details>") else { return nil }

        var summary = ""
        var contentLines: [String] = []
        var i = startIndex + 1

        // 持续向下扫描，直到抓取到配对的闭合标签
        while i < lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("</details>") {
                i += 1
                break
            }

            // 精准抓取 summary 标题内容
            if line.hasPrefix("<summary>") && line.contains("</summary>") {
                summary = line.replacingOccurrences(of: "<summary>", with: "")
                              .replacingOccurrences(of: "</summary>", with: "")
            } else if line.hasPrefix("<summary>") {
                // 处理极少见的多行 summary 头部开端
                summary = line.replacingOccurrences(of: "<summary>", with: "")
            } else if line.contains("</summary>") {
                // 处理极少见的多行 summary 尾部闭合
                summary += line.replacingOccurrences(of: "</summary>", with: "")
            } else {
                // 折叠块内的正文行，追加合并
                contentLines.append(lines[i])
            }
            i += 1
        }

        // 默认兜底标题文案
        if summary.isEmpty { summary = "Details" }
        return (.details(summary: summary, content: contentLines.joined(separator: "\n")), i)
    }

    /// 尝试解析标准多行代码块。
    /// - Parameters:
    ///   - lines: 原始全文按行拆分后的数组。
    ///   - startIndex: 当前扫描的起始行索引。
    /// - Returns: 若匹配成功，返回代码块实体与下一行待扫描的偏移索引；否则返回 `nil`。
    func parseCodeBlock(lines: [String], startIndex: Int) -> (block: BlockType, nextIndex: Int)? {
        let trimmed = lines[startIndex].trimmingCharacters(in: .whitespaces)
        // 代码块必须以三反引号引导
        guard trimmed.hasPrefix("```") else { return nil }

        // 提取语法高亮语言标识 (e.g. ```swift -> swift)
        let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        var codeLines: [String] = []
        var i = startIndex + 1

        // 循环收集代码行，直到遇见下一组闭合的反引号为止
        while i < lines.count && !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
            codeLines.append(lines[i])
            i += 1
        }

        return (.codeBlock(code: codeLines.joined(separator: "\n"), language: language), i + 1)
    }

    /// 尝试解析 Markdown 标准标题（H1 - H6）。
    /// - Parameter line: 当前待匹配的去空格行。
    /// - Returns: 若匹配成功，返回对应的 `BlockType.heading` 标题块；否则返回 `nil`。
    func parseHeading(_ line: String) -> BlockType? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.hasPrefix("#") else { return nil }

        // 统计开头连续的井号个数以决定标题等级
        let hashes = trimmed.prefix(while: { $0 == "#" })
        let level = hashes.count

        // 标题后面必须跟一个空格才是标准的 Markdown 标题且层级在 1 到 6 之间
        guard level >= 1 && level <= 6 else { return nil }

        let contentStart = trimmed.index(trimmed.startIndex, offsetBy: level)
        guard contentStart < trimmed.endIndex else { return nil }

        let afterHashes = trimmed[contentStart...]
        if afterHashes.hasPrefix(" ") {
            return .heading(text: afterHashes.trimmingCharacters(in: .whitespaces), level: level)
        }

        return nil
    }

    /// 尝试解析水平线分割符。
    /// - Parameter line: 当前待匹配的去空格行。
    /// - Returns: 若匹配成功，返回 `BlockType.horizontalRule`；否则返回 `nil`。
    func parseHorizontalRule(_ line: String) -> BlockType? {
        if line.hasPrefix("---") || line.hasPrefix("***") || line.hasPrefix("___") {
            return .horizontalRule
        }
        return nil
    }

    /// 尝试解析任务列表块。
    /// - Parameters:
    ///   - lines: 原始全文按行拆分后的数组。
    ///   - startIndex: 当前扫描的起始行索引。
    /// - Returns: 若匹配成功，返回任务列表块实体与下一行扫描物理偏移；否则返回 `nil`。
    func parseTaskList(lines: [String], startIndex: Int) -> (block: BlockType, nextIndex: Int)? {
        let trimmed = lines[startIndex].trimmingCharacters(in: .whitespaces)
        // 精准过滤各种复选框样式
        guard trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") ||
              trimmed.hasPrefix("- [X] ") || trimmed.hasPrefix("* [ ] ") ||
              trimmed.hasPrefix("* [x] ") || trimmed.hasPrefix("* [X] ") else {
            return nil
        }

        var items: [(text: String, checked: Bool)] = []
        var i = startIndex

        // 连续收拢复选框行，聚合成高内聚的任务物理块
        while i < lines.count {
            let taskLine = lines[i].trimmingCharacters(in: .whitespaces)
            if taskLine.hasPrefix("- [ ] ") {
                items.append((text: String(taskLine.dropFirst(6)), checked: false))
            } else if taskLine.hasPrefix("- [x] ") || taskLine.hasPrefix("- [X] ") {
                items.append((text: String(taskLine.dropFirst(6)), checked: true))
            } else if taskLine.hasPrefix("* [ ] ") {
                items.append((text: String(taskLine.dropFirst(6)), checked: false))
            } else if taskLine.hasPrefix("* [x] ") || taskLine.hasPrefix("* [X] ") {
                items.append((text: String(taskLine.dropFirst(6)), checked: true))
            } else {
                break // 遇见非复选框内容时打断连续合并
            }
            i += 1
        }

        return (.taskList(items: items), i)
    }

    /// 获取某一文本行的物理缩进空格数（处理嵌套列表的核心算法辅助）。
    /// - Parameter line: 原始文本行。
    /// - Returns: 该行起首的空格计数（制表符 \t 强制折算为 4 个空格）。
    func getIndentLevel(_ line: String) -> Int {
        var count = 0
        for char in line {
            if char == " " {
                count += 1
            } else if char == "\t" {
                count += 4
            } else {
                break
            }
        }
        return count
    }

    /// 尝试解析无序列表或有序列表块。
    /// - Parameters:
    ///   - lines: 原始全文按行拆分后的数组。
    ///   - startIndex: 当前扫描的起始行索引。
    /// - Returns: 若匹配成功，返回对应的 `bulletList` 物理块及下一次的行偏移；否则返回 `nil`。
    func parseBulletList(lines: [String], startIndex: Int) -> (block: BlockType, nextIndex: Int)? {
        let startLine = lines[startIndex]
        let trimmedStart = startLine.trimmingCharacters(in: .whitespaces)
        let isBulletList = trimmedStart.hasPrefix("- ") || trimmedStart.hasPrefix("* ")
        let isNumberedList = isNumberedLine(trimmedStart)

        guard isBulletList || isNumberedList else { return nil }

        let startIndent = getIndentLevel(startLine)
        let startNumber = isNumberedList ? extractNumberPrefix(trimmedStart) : 1
        var items: [String] = []
        var i = startIndex

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let indent = getIndentLevel(line)

            if trimmed.isEmpty { break }

            let isItem = trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ")
            let isNumItem = isNumberedLine(trimmed)

            if isItem || isNumItem {
                if indent == startIndent {
                    if isBulletList && isItem {
                        items.append(String(trimmed.dropFirst(2)))
                    } else if isNumberedList && isNumItem, let dotIndex = trimmed.firstIndex(of: ".") {
                        let content = String(trimmed[trimmed.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
                        items.append(content)
                    } else {
                        break
                    }
                } else if indent < startIndent {
                    break
                }
            } else {
                break
            }
            i += 1
        }

        return (.bulletList(items: items, indent: isNumberedList ? -1 : startIndent, startNumber: startNumber), i)
    }

    /// 提取编号行开头的具体数字（如 "1. " -> 1, "3. " -> 3）
    private func extractNumberPrefix(_ trimmed: String) -> Int {
        guard let dotIndex = trimmed.firstIndex(of: ".") else { return 1 }
        let prefix = trimmed[..<dotIndex]
        return Int(prefix) ?? 1
    }

    /// 判断一行是否为编号列表项（如 "1. " 或 "12.xx"）
    private func isNumberedLine(_ trimmed: String) -> Bool {
        let maxDotPos = min(4, trimmed.count)
        guard maxDotPos > 0,
              let dotIndex = trimmed.firstIndex(of: "."),
              dotIndex < trimmed.index(trimmed.startIndex, offsetBy: maxDotPos) else { return false }
        let prefix = trimmed[..<dotIndex]
        return prefix.allSatisfy { $0.isNumber } && !prefix.isEmpty
    }

    /// 尝试解析引用块。
    /// - Parameter line: 当前待匹配的去空格行。
    /// - Returns: 若匹配成功，返回 `BlockType.blockquote` 引用块；否则返回 `nil`。
    func parseBlockquote(_ line: String) -> BlockType? {
        if line.hasPrefix("> ") {
            return .blockquote(text: String(line.dropFirst(2)))
        }
        return nil
    }

    /// 尝试解析表格块。
    /// - Parameters:
    ///   - lines: 原始全文按行拆分后的数组。
    ///   - startIndex: 当前扫描的起始行索引。
    /// - Returns: 若匹配成功，返回标准表格块实体与下一扫描行偏移；否则返回 `nil`。
    func parseTable(lines: [String], startIndex: Int) -> (block: BlockType, nextIndex: Int)? {
        guard isTableLine(lines[startIndex].trimmingCharacters(in: .whitespaces)) else { return nil }

        var tableLines: [String] = []
        var i = startIndex

        // 持续收集表格格式行（以 | 开始并以 | 结束）
        while i < lines.count && isTableLine(lines[i].trimmingCharacters(in: .whitespaces)) {
            tableLines.append(lines[i].trimmingCharacters(in: .whitespaces))
            i += 1
        }

        // 剔除表格的分割对齐行（例如 |---| 或 |:---|）
        let dataLines = tableLines.filter { !$0.hasPrefix("|-") && !$0.hasPrefix("| -") }
        guard !dataLines.isEmpty else { return nil }

        // 解析第一行为表头 headers
        let headers = parseTableCells(dataLines[0])
        var rows: [[String]] = []
        // 依次解析余下行为每一行数据 rows
        for lineIdx in 1..<dataLines.count {
            rows.append(parseTableCells(dataLines[lineIdx]))
        }

        return (.table(headers: headers, rows: rows), i)
    }

    /// - Parameter line: 包含管线符的 Markdown 原始表格单行字符串。
    /// - Returns: 清除首尾空格并物理过滤掉虚线对齐分隔符后，所包含的单元格字符有序数组。

    /// 判定指定行是否为表格行。
    /// - Parameter line: 被检测的字符串行。
    /// - Returns: 若该行同时包含 "|" 且以 "|" 或数字开头，返回 true。
    func isTableLine(_ line: String) -> Bool {
        let hasPipe = line.contains("|")
        let isFormatLine = line.hasPrefix("|") || line.range(of: #"^\d+\. "#, options: .regularExpression) != nil
        return hasPipe && isFormatLine
    }

	/// 提取表格行中被管线符 | 分隔的单元格文本。
	/// - Parameter line: 包含管线符的原始表格行。
	/// - Returns: 过滤掉空单元格和对齐分隔符后的字符串数组。
    func parseTableCells(_ line: String) -> [String] {
        line.split(separator: "|")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("-") }
}
}
