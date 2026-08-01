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

/// 专门处理知识测验数据的解析、转换与清洗
enum QuizProcessor {

    struct QuizModelShell: Codable {
        let title: String
        let questions: [QuestionShell]
        struct QuestionShell: Codable {
            let id: Int?
            let text: String
            let options: [String]
            let answer: Int
            let explanation: String?
        }
    }

    /// 检查文本是否可以解析为标准的交互式测验模型
    static func canDecodeAsQuizModel(_ text: String) -> Bool {
        let cleaned = LLMUtils.stripMarkdown(text)
        guard let data = cleaned.data(using: .utf8) else { return false }
        return (try? JSONDecoder().decode(QuizModelShell.self, from: data)) != nil
    }

    /// 尝试将 JSON 测验转换为 Markdown 格式
    static func convertJSONToMarkdown(_ text: String) -> String? {
        let cleaned = LLMUtils.stripMarkdown(text)
        guard let data = cleaned.data(using: .utf8) else { return nil }

        struct QuizJSON: Codable {
            let title: String?
            let questions: [QuestionJSON]
        }
        struct QuestionJSON: Codable {
            let id: Int?
            let text: String
            let options: [String]
            let answer: AnyCodable?
            let explanation: String?
        }

        enum AnyCodable: Codable {
            case int(Int)
            case string(String)
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let i = try? container.decode(Int.self) { self = .int(i) } else if let s = try? container.decode(String.self) { self = .string(s) } else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not_int_or_string") }
            }

            /// 编码
            func encode(to encoder: Encoder) throws {}
            var stringValue: String {
                switch self {
                case .int(let i): return "\(i)"
                case .string(let s): return s
                }
            }
        }

        guard let quiz = try? JSONDecoder().decode(QuizJSON.self, from: data) else { return nil }

        var md = "# \(quiz.title ?? L10n.Quiz.title)\n\n"
        for (index, question) in quiz.questions.enumerated() {
            md += "## \(index + 1). \(question.text)\n\n"
            for opt in question.options {
                md += "* \(opt)\n"
            }
            md += "\n<details>\n<summary>\(L10n.Quiz.showAnswer)</summary>\n\n"
            if let ans = question.answer {
                md += "**\(L10n.Quiz.correctAnswer):** \(ans.stringValue)\n\n"
            }
            if let exp = question.explanation {
                md += "**\(L10n.Quiz.explanation):** \(exp)\n"
            }
            md += "\n</details>\n\n"
        }

        return md
    }

    /// 将任意文本（Raw JSON、Markdown 包裹 JSON 或纯 Markdown 试卷）自愈解析为 QuizModel
    static func parseToQuizModel(_ text: String) -> QuizModel? {
        // 1. 尝试直接解码为标准的 QuizModel
        if let data = text.data(using: .utf8),
           var quiz = try? JSONDecoder().decode(QuizModel.self, from: data),
           !quiz.questions.isEmpty {
            // 🛡️ 答案索引越界自动纠偏防爆
            let sanitizedQuestions = quiz.questions.map { question -> QuizQuestion in
                let validAnswer = (question.answer >= 0 && question.answer < question.options.count) ? question.answer : 0
                return QuizQuestion(id: question.id, text: question.text, options: question.options, answer: validAnswer, explanation: question.explanation)
            }
            return QuizModel(title: quiz.title, questions: sanitizedQuestions)
        }

        // 2. 尝试剥离 Markdown 围栏后解码 Shell
        let cleaned = LLMUtils.stripMarkdown(text)
        if let data = cleaned.data(using: .utf8),
           let shell = try? JSONDecoder().decode(QuizModelShell.self, from: data),
           !shell.questions.isEmpty {
            let questions = shell.questions.enumerated().map { index, item in
                let opts = item.options
                let validAnswer = (item.answer >= 0 && item.answer < opts.count) ? item.answer : 0
                return QuizQuestion(
                    id: item.id ?? index,
                    text: item.text,
                    options: opts,
                    answer: validAnswer,
                    explanation: item.explanation ?? ""
                )
            }
            return QuizModel(title: shell.title, questions: questions)
        }

        // 3. 从 Markdown 格式中自愈解析题目、选项与答案
        return parseMarkdownQuiz(text)
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
        if line.contains("B") || line.contains("1") {
            return 1
        } else if line.contains("C") || line.contains("2") {
            return 2
        } else if line.contains("D") || line.contains("3") {
            return 3
        }
        return 0
    }
}
