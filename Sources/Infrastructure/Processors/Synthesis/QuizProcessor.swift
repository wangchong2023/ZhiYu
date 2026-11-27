//
//  QuizProcessor.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：文档处理器：Markdown 解析、文本分块、图谱布局、网页抓取。
//
import Foundation
import ZhiYuAICore

/// 专门处理知识测验数据的解析、转换与清洗
enum QuizProcessor {

    // MARK: - 常量定义（去魔鬼化）

    /// 测验答案解析常量
    enum AnswerParsing {
        /// Answer 行的正则模式，精确提取 Answer: 后的首个字母/数字
        static let pattern = ProcessorConstants.RegexPattern.quizAnswer
        /// 选项字母 A 对应的索引
        static let optionAIndex = 0
        /// 选项字母 B 对应的索引
        static let optionBIndex = 1
        /// 大写字母 A 的 ASCII 标量值
        static let asciiUppercaseA: UInt32 = 65
        /// 大写字母 Z 的 ASCII 标量值
        static let asciiUppercaseZ: UInt32 = 90
        /// 带冒号前缀的答案提取正则（兼容中英文冒号，如 "Answer: C" / "答案：D"，避免误取首字母）
        static let labeledOptionPattern = #"[:：]\s*([A-Z0-9])"#
        /// 单选项字母答案正则（匹配 "B"、"B."、"B)"、"B、"、"B 选项" 等，避免把 "Answer: C" 的首字母 A 误判为选项 A）
        static let standaloneOptionLetterPattern = #"^([A-Z])(?:\s*$|[.\)、:：\s])"#
        static let captureGroupIndex: Int = 1
        static let indexOffset: Int = 1
        static let crlf = "\r\n"
        static let carriageReturn = "\r"
        static let newline = "\n"
    }

    struct FlexibleQuizShell: Codable {
        let title: String?
        let quizTitle: String?
        let questions: [FlexibleQuestionShell]?

        var displayTitle: String {
            if let t = quizTitle, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return t }
            if let t = title, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return t }
            return L10n.Quiz.title
        }

        struct FlexibleQuestionShell: Codable {
            let id: FlexibleID?
            let text: String?
            let question: String?
            let questionText: String?
            let options: [String]?
            let answer: FlexibleAnswer?
            let answerIndex: FlexibleAnswer?
            let explanation: String?

            var realText: String {
                if let queryQuestion = question, !queryQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return queryQuestion }
                if let t = text, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return t }
                if let qt = questionText, !qt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return qt }
                return ""
            }

            var realOptions: [String] {
                options ?? []
            }

            var realAnswerIndex: Int {
                let ans = answer ?? answerIndex
                return ans?.asIndex(optionCount: realOptions.count) ?? 0
            }
        }

        enum FlexibleID: Codable {
            case int(Int)
            case string(String)

            init(from decoder: Decoder) throws {
                self = try Self.decodeFlexibleIntString(from: decoder)
            }

            var intValue: Int {
                switch self {
                case .int(let i): return i
                case .string(let s): return Int(s) ?? 0
                }
            }

            /// 共享的 Int/String 自愈解码逻辑，消除 FlexibleID 与 FlexibleAnswer 间的重复 init(from:)。
            private static func decodeFlexibleIntString(from decoder: Decoder) throws -> FlexibleID {
                try FlexibleIntStringDecoder.decode(from: decoder, intCase: FlexibleID.int, stringCase: FlexibleID.string)
            }
        }

        enum FlexibleAnswer: Codable {
            case int(Int)
            case string(String)

            init(from decoder: Decoder) throws {
                self = try Self.decodeFlexibleIntString(from: decoder)
            }

            func asIndex(optionCount: Int) -> Int {
                guard optionCount > AnswerParsing.optionAIndex else { return AnswerParsing.optionAIndex }
                switch self {
                case .int(let i):
                    return (i >= AnswerParsing.optionAIndex && i < optionCount) ? i : AnswerParsing.optionAIndex
                case .string(let s):
                    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    if let i = Int(trimmed) {
                        return (i >= AnswerParsing.optionAIndex && i < optionCount) ? i : AnswerParsing.optionAIndex
                    }
                    // 优先识别带标签前缀的答案（如 "Answer: C" / "答案：B"），避免取首字母 "A" 误判为选项 A
                    if let labeledRegex = try? NSRegularExpression(pattern: AnswerParsing.labeledOptionPattern, options: .caseInsensitive),
                       let match = labeledRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                       let range = Range(match.range(at: AnswerParsing.captureGroupIndex), in: trimmed) {
                        let token = String(trimmed[range])
                        if let i = Int(token), i >= AnswerParsing.optionAIndex, i < optionCount {
                            return i
                        }
                        if let letterIndex = Self.letterOffset(for: token, optionCount: optionCount) {
                            return letterIndex
                        }
                    }
                    // 其次识别独立选项字母（如 "B"、"B."、"B)"）
                    if let standaloneRegex = try? NSRegularExpression(pattern: AnswerParsing.standaloneOptionLetterPattern),
                       let match = standaloneRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
                       let range = Range(match.range(at: AnswerParsing.captureGroupIndex), in: trimmed),
                       let letterIndex = Self.letterOffset(for: String(trimmed[range]), optionCount: optionCount) {
                        return letterIndex
                    }
                    return AnswerParsing.optionAIndex
                }
            }

            private static func letterOffset(for token: String, optionCount: Int) -> Int? {
                guard let firstScalar = token.unicodeScalars.first,
                      firstScalar.value >= AnswerParsing.asciiUppercaseA,
                      firstScalar.value <= AnswerParsing.asciiUppercaseZ else {
                    return nil
                }
                let offset = Int(firstScalar.value - AnswerParsing.asciiUppercaseA)
                return min(offset, optionCount - AnswerParsing.indexOffset)
            }

            /// 共享的 Int/String 自愈解码逻辑，消除 FlexibleID 与 FlexibleAnswer 间的重复 init(from:)。
            private static func decodeFlexibleIntString(from decoder: Decoder) throws -> FlexibleAnswer {
                try FlexibleIntStringDecoder.decode(from: decoder, intCase: FlexibleAnswer.int, stringCase: FlexibleAnswer.string)
            }
        }
    }

    /// Int/String 自愈解码的泛型辅助器，消除 FlexibleID 与 FlexibleAnswer 间的解码样板重复。
    private enum FlexibleIntStringDecoder {
        static func decode<T>(
            from decoder: Decoder,
            intCase: (Int) -> T,
            stringCase: (String) -> T
        ) throws -> T {
            let container = try decoder.singleValueContainer()
            if let i = try? container.decode(Int.self) {
                return intCase(i)
            } else if let s = try? container.decode(String.self) {
                return stringCase(s)
            } else {
                return intCase(0)
            }
        }
    }

    /// 检查文本是否可以解析为标准的交互式测验模型
    static func canDecodeAsQuizModel(_ text: String) -> Bool {
        return parseToQuizModel(text) != nil
    }

    /// 尝试将 JSON 测验转换为 Markdown 格式
    static func convertJSONToMarkdown(_ text: String) -> String? {
        if let model = parseToQuizModel(text) {
            var md = "\(ProcessorConstants.MarkdownSyntax.h1Prefix)\(model.title)\(ProcessorConstants.Whitespace.doubleNewline)"
            for (index, question) in model.questions.enumerated() {
                md += "\(ProcessorConstants.MarkdownSyntax.h2Prefix)\(index + 1)\(ProcessorConstants.Whitespace.dotSpace)\(question.text)\(ProcessorConstants.Whitespace.doubleNewline)"
                for opt in question.options {
                    md += "\(ProcessorConstants.MarkdownSyntax.bulletAsterisk)\(opt)\(ProcessorConstants.Whitespace.newline)"
                }
                md += "\(ProcessorConstants.Whitespace.newline)\(ProcessorConstants.HTMLTag.detailsOpen)\(ProcessorConstants.Whitespace.newline)\(ProcessorConstants.HTMLTag.summaryOpen)\(L10n.Quiz.showAnswer)\(ProcessorConstants.HTMLTag.summaryClose)\(ProcessorConstants.Whitespace.doubleNewline)"
                if question.answer >= 0 && question.answer < question.options.count {
                    md += "\(ProcessorConstants.MarkdownSyntax.bold)\(L10n.Quiz.correctAnswer):\(ProcessorConstants.MarkdownSyntax.bold) \(question.options[question.answer])\(ProcessorConstants.Whitespace.doubleNewline)"
                }
                if !question.explanation.isEmpty {
                    md += "\(ProcessorConstants.MarkdownSyntax.bold)\(L10n.AI.Prompt.Quiz.explanation):\(ProcessorConstants.MarkdownSyntax.bold) \(question.explanation)\(ProcessorConstants.Whitespace.doubleNewline)"
                }
                md += "\(ProcessorConstants.HTMLTag.detailsClose)\(ProcessorConstants.Whitespace.doubleNewline)"
            }
            return md
        }
        return nil
    }

    /// 将任意文本（Raw JSON、Markdown 包裹 JSON 或纯 Markdown 试卷）自愈解析为 QuizModel
    static func parseToQuizModel(_ text: String) -> QuizModel? {
        let model: QuizModel?
        // 1. 尝试使用标准的 FlexibleQuizShell 解码 (结合 JSONRepairProcessor 自愈修复)
        let cleaned = LLMUtils.stripMarkdown(text)
        let repairedJSON = JSONRepairProcessor.repair(cleaned)
        
        if let data = repairedJSON.data(using: .utf8),
           let shell = try? JSONDecoder().decode(FlexibleQuizShell.self, from: data),
           let shellQuestions = shell.questions, !shellQuestions.isEmpty {
            let questions = shellQuestions.enumerated().compactMap { index, item -> QuizQuestion? in
                let rawOptions = item.realOptions
                let opts: [String]
                if rawOptions.count >= 2 {
                    opts = rawOptions
                } else {
                    opts = (0..<ProcessorConstants.Synthesis.quizOptionCount).map {
                        "\(L10n.AI.Prompt.Quiz.option) \(ProcessorConstants.Synthesis.quizLetterOptions[$0])"
                    }
                }
                let validAnswer = item.realAnswerIndex
                let id = item.id?.intValue ?? index + 1
                let qText = item.realText
                guard !qText.isEmpty else { return nil }
                return QuizQuestion(
                    id: id,
                    text: qText,
                    options: opts,
                    answer: validAnswer,
                    explanation: item.explanation ?? ""
                )
            }
            if !questions.isEmpty {
                model = QuizModel(title: shell.displayTitle, questions: questions)
            } else {
                model = parseMarkdownQuiz(text)
            }
        } else {
            // 2. 尝试从 Markdown 格式中自愈解析题目、选项与答案
            model = parseMarkdownQuiz(text)
        }

        guard let validModel = model else { return nil }
        return randomizeQuizAnswers(validModel)
    }

    /// 自动纠偏与随机打乱测验题目答案选项（防止所有测验的正确选项固定为第一个选项 / Option A）
    static func randomizeQuizAnswers(_ model: QuizModel) -> QuizModel {
        let randomizedQuestions = model.questions.map { question -> QuizQuestion in
            guard question.options.count >= ProcessorConstants.Synthesis.quizMinOptionsForRandomization else { return question }

            // 1. 清洗选项的前缀（如 "A. ", "B. ", "1. "）
            let cleanOptions = question.options.map { opt in
                opt.replacingOccurrences(of: ProcessorConstants.RegexPattern.quizOptionPrefix, with: "", options: .regularExpression)
                   .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let isValidAnswer = (question.answer >= AnswerParsing.optionAIndex && question.answer < cleanOptions.count)
            let origAnswerIndex = isValidAnswer ? question.answer : ProcessorConstants.Synthesis.quizDefaultIndex

            // 2. 携带原始索引洗牌打乱，即使存在重复选项也能 100% 精准追踪原正确答案槽位
            let indexedOptions = cleanOptions.enumerated().map { (originalIndex: $0.offset, text: $0.element) }.shuffled()
            let shuffledOptions = indexedOptions.map(\.text)

            // 3. 计算洗牌后正确答案的新 index
            let newAnswerIndex = indexedOptions.firstIndex(where: { $0.originalIndex == origAnswerIndex })
                ?? ProcessorConstants.Synthesis.quizDefaultIndex

            return QuizQuestion(
                id: question.id,
                text: question.text,
                options: shuffledOptions,
                answer: newAnswerIndex,
                explanation: question.explanation
            )
        }

        return QuizModel(title: model.title, questions: randomizedQuestions)
    }

    private static func parseMarkdownQuiz(_ text: String) -> QuizModel? {
        let normalized = text
            .replacingOccurrences(of: AnswerParsing.crlf, with: AnswerParsing.newline)
            .replacingOccurrences(of: AnswerParsing.carriageReturn, with: AnswerParsing.newline)
        let lines = normalized.components(separatedBy: AnswerParsing.newline)
        var title = L10n.Quiz.title
        var questions: [QuizQuestion] = []
        var currentQuestionText = ""
        var currentOptions: [String] = []
        var currentAnswer = 0
        var currentExplanation = ""
        var inQuestion = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.h1Prefix) && title == L10n.Quiz.title {
                title = trimmed.replacingOccurrences(of: ProcessorConstants.MarkdownSyntax.h1Prefix, with: "")
                continue
            }

            if trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.h2Prefix) || (trimmed.first?.isNumber == true && (trimmed.contains(ProcessorConstants.Whitespace.dotSpace) || trimmed.contains(ProcessorConstants.Whitespace.ideographicComma))) {
                if inQuestion && !currentQuestionText.isEmpty {
                    questions.append(makeMarkdownQuestion(
                        id: questions.count + AnswerParsing.indexOffset,
                        text: currentQuestionText,
                        options: currentOptions,
                        fallbackOptions: ProcessorConstants.Synthesis.quizLetterOptions,
                        answer: currentAnswer,
                        explanation: currentExplanation
                    ))
                    currentOptions.removeAll()
                    currentAnswer = AnswerParsing.optionAIndex
                    currentExplanation = ""
                }
                inQuestion = true
                currentQuestionText = trimmed
                    .replacingOccurrences(of: ProcessorConstants.MarkdownSyntax.h2Prefix, with: "")
                    .replacingOccurrences(of: ProcessorConstants.RegexPattern.numberedList, with: "", options: .regularExpression)
            } else if trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.bulletAsterisk) || trimmed.hasPrefix(ProcessorConstants.MarkdownSyntax.bulletDash) || (trimmed.prefix(2).range(of: ProcessorConstants.RegexPattern.choiceOption, options: .regularExpression) != nil) {
                let optText = trimmed.replacingOccurrences(of: ProcessorConstants.RegexPattern.quizOptionStrip, with: "", options: .regularExpression)
                currentOptions.append(optText)
            } else if trimmed.contains(L10n.Quiz.correctAnswer) || trimmed.contains(ProcessorConstants.Synthesis.quizAnswerKeyword) {
                currentAnswer = parseAnswerIndex(from: trimmed)
            } else if trimmed.contains(L10n.Quiz.explanation) || trimmed.contains(ProcessorConstants.Synthesis.quizExplanationKeyword) {
                currentExplanation = trimmed
            }
        }

        if inQuestion && !currentQuestionText.isEmpty {
            let defaultOpts = (AnswerParsing.optionAIndex..<ProcessorConstants.Synthesis.quizOptionCount).map {
                "\(L10n.AI.Prompt.Quiz.option) \($0 + AnswerParsing.indexOffset)"
            }
            questions.append(makeMarkdownQuestion(
                id: questions.count + AnswerParsing.indexOffset,
                text: currentQuestionText,
                options: currentOptions,
                fallbackOptions: defaultOpts,
                answer: currentAnswer,
                explanation: currentExplanation
            ))
        }

        guard !questions.isEmpty else { return nil }
        return QuizModel(title: title, questions: questions)
    }

    private static func makeMarkdownQuestion(
        id: Int,
        text: String,
        options: [String],
        fallbackOptions: [String],
        answer: Int,
        explanation: String
    ) -> QuizQuestion {
        let finalOptions = options.isEmpty ? fallbackOptions : options
        let safeAnswer = (answer >= AnswerParsing.optionAIndex && answer < finalOptions.count)
            ? answer
            : ProcessorConstants.Synthesis.quizDefaultIndex
        return QuizQuestion(
            id: id,
            text: text,
            options: finalOptions,
            answer: safeAnswer,
            explanation: explanation
        )
    }

    private static func parseAnswerIndex(from line: String) -> Int {
        // 缺陷 #10 修复：改用正则精确提取 Answer: 后的首个字母/数字，避免 contains 误匹配
        guard let regex = try? NSRegularExpression(pattern: AnswerParsing.pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let answerRange = Range(match.range(at: 1), in: line) else {
            return ProcessorConstants.Synthesis.quizDefaultIndex
        }
        let answerChar = String(line[answerRange]).uppercased()
        return ProcessorConstants.Synthesis.quizAnswerMap[answerChar] ?? ProcessorConstants.Synthesis.quizDefaultIndex
    }
}
