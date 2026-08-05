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
        static let pattern = #"Answer:\s*([A-Da-d1-4])"#
        /// 选项字母 A 对应的索引
        static let optionAIndex = 0
        /// 选项字母 B 对应的索引
        static let optionBIndex = 1
        /// 选项字母 C 对应的索引
        static let optionCIndex = 2
        /// 选项字母 D 对应的索引
        static let optionDIndex = 3
        /// 选项字母集合（A-D）
        static let letterOptions: [String] = ["A", "B", "C", "D"]
        /// 选项数字集合（1-4）
        static let numberOptions: [String] = ["1", "2", "3", "4"]
        /// 字母/数字到索引的映射表
        static let answerMap: [String: Int] = [
            "A": optionAIndex, "1": optionAIndex,
            "B": optionBIndex, "2": optionBIndex,
            "C": optionCIndex, "3": optionCIndex,
            "D": optionDIndex, "4": optionDIndex
        ]
        /// 默认答案索引（解析失败时回退）
        static let defaultIndex = 0
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
                let container = try decoder.singleValueContainer()
                if let i = try? container.decode(Int.self) {
                    self = .int(i)
                } else if let s = try? container.decode(String.self) {
                    self = .string(s)
                } else {
                    self = .int(0)
                }
            }

            var intValue: Int {
                switch self {
                case .int(let i): return i
                case .string(let s): return Int(s) ?? 0
                }
            }
        }

        enum FlexibleAnswer: Codable {
            case int(Int)
            case string(String)

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let i = try? container.decode(Int.self) {
                    self = .int(i)
                } else if let s = try? container.decode(String.self) {
                    self = .string(s)
                } else {
                    self = .int(0)
                }
            }

            func asIndex(optionCount: Int) -> Int {
                guard optionCount > 0 else { return 0 }
                switch self {
                case .int(let i):
                    return (i >= 0 && i < optionCount) ? i : 0
                case .string(let s):
                    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                    if let i = Int(trimmed) {
                        return (i >= 0 && i < optionCount) ? i : 0
                    }
                    if trimmed.hasPrefix("A") { return 0 }
                    if trimmed.hasPrefix("B") { return min(1, optionCount - 1) }
                    if trimmed.hasPrefix("C") { return min(2, optionCount - 1) }
                    if trimmed.hasPrefix("D") { return min(3, optionCount - 1) }
                    return 0
                }
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
            var md = "# \(model.title)\n\n"
            for (index, question) in model.questions.enumerated() {
                md += "## \(index + 1). \(question.text)\n\n"
                for opt in question.options {
                    md += "* \(opt)\n"
                }
                md += "\n<details>\n<summary>\(L10n.Quiz.showAnswer)</summary>\n\n"
                if question.answer < question.options.count {
                    md += "**\(L10n.Quiz.correctAnswer):** \(question.options[question.answer])\n\n"
                }
                if !question.explanation.isEmpty {
                    md += "**\(L10n.AI.Prompt.Quiz.explanation):** \(question.explanation)\n\n"
                }
                md += "</details>\n\n"
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
                let opts = item.realOptions.isEmpty ? [L10n.AI.Prompt.Quiz.option] : item.realOptions
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

    // MARK: - 常量定义（告别魔鬼数字）
    private static let minOptionsForRandomization = 2
    private static let defaultAnswerIndex = 0

    /// 自动纠偏与随机打乱测验题目答案选项（防止所有测验的正确选项固定为第一个选项 / Option A）
    static func randomizeQuizAnswers(_ model: QuizModel) -> QuizModel {
        let randomizedQuestions = model.questions.map { question -> QuizQuestion in
            guard question.options.count >= minOptionsForRandomization else { return question }

            // 1. 清洗选项的前缀（如 "A. ", "B. ", "1. "）
            let cleanOptions = question.options.map { opt in
                opt.replacingOccurrences(of: #"^[A-D\d][\.\s、:]\s*"#, with: "", options: .regularExpression)
                   .trimmingCharacters(in: .whitespacesAndNewlines)
            }

            let isValidAnswer = (question.answer >= 0 && question.answer < cleanOptions.count)
            let origAnswerIndex = isValidAnswer ? question.answer : defaultAnswerIndex
            let correctAnswerText = cleanOptions[origAnswerIndex]

            // 2. 将选项洗牌打乱
            var shuffledOptions = cleanOptions
            shuffledOptions.shuffle()

            // 3. 计算洗牌后正确答案的新 index
            let newAnswerIndex = shuffledOptions.firstIndex(of: correctAnswerText) ?? defaultAnswerIndex

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
        let lines = text.components(separatedBy: .newlines)
        var title = L10n.Quiz.title
        var questions: [QuizQuestion] = []
        var currentQuestionText = ""
        var currentOptions: [String] = []
        var currentAnswer = 0
        var currentExplanation = ""
        var inQuestion = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# ") && title == L10n.Quiz.title {
                title = trimmed.replacingOccurrences(of: "# ", with: "")
                continue
            }

            if trimmed.hasPrefix("## ") || (trimmed.first?.isNumber == true && (trimmed.contains(". ") || trimmed.contains("、"))) {
                if inQuestion && !currentQuestionText.isEmpty {
                    questions.append(QuizQuestion(
                        id: questions.count + 1,
                        text: currentQuestionText,
                        options: currentOptions.isEmpty ? ["A", "B", "C", "D"] : currentOptions,
                        answer: currentAnswer,
                        explanation: currentExplanation
                    ))
                    currentOptions.removeAll()
                    currentAnswer = 0
                    currentExplanation = ""
                }
                inQuestion = true
                currentQuestionText = trimmed
                    .replacingOccurrences(of: "## ", with: "")
                    .replacingOccurrences(of: "^[0-9]+[.\\s、]+", with: "", options: .regularExpression)
            } else if trimmed.hasPrefix("* ") || trimmed.hasPrefix("- ") || (trimmed.prefix(2).range(of: "^[A-D][.\\s、:]", options: .regularExpression) != nil) {
                let optText = trimmed.replacingOccurrences(of: "^[*\\-]\\s*", with: "", options: .regularExpression)
                currentOptions.append(optText)
            } else if trimmed.contains(L10n.Quiz.correctAnswer) || trimmed.contains("Answer:") {
                currentAnswer = parseAnswerIndex(from: trimmed)
            } else if trimmed.contains(L10n.Quiz.explanation) || trimmed.contains("Explanation:") {
                currentExplanation = trimmed
            }
        }

        if inQuestion && !currentQuestionText.isEmpty {
            let defaultOpts = (0..<4).map { "\(L10n.AI.Prompt.Quiz.option) \($0 + 1)" }
            questions.append(QuizQuestion(
                id: questions.count + 1,
                text: currentQuestionText,
                options: currentOptions.isEmpty ? defaultOpts : currentOptions,
                answer: currentAnswer,
                explanation: currentExplanation
            ))
        }

        guard !questions.isEmpty else { return nil }
        return QuizModel(title: title, questions: questions)
    }

    private static func parseAnswerIndex(from line: String) -> Int {
        // 缺陷 #10 修复：改用正则精确提取 Answer: 后的首个字母/数字，避免 contains 误匹配
        guard let regex = try? NSRegularExpression(pattern: AnswerParsing.pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let answerRange = Range(match.range(at: 1), in: line) else {
            return AnswerParsing.defaultIndex
        }
        let answerChar = String(line[answerRange]).uppercased()
        return AnswerParsing.answerMap[answerChar] ?? AnswerParsing.defaultIndex
    }
}
