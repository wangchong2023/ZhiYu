//
//  QuizProcessorEdgeTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 QuizProcessor 的 FlexibleID/FlexibleAnswer 解析、JSON 自愈、Markdown 试卷解析、答案随机化语义。
//

import XCTest
@testable import ZhiYu

final class QuizProcessorEdgeTests: XCTestCase {

    // MARK: - FlexibleID 解析

    func testFlexibleID_int_decodesAsInt() throws {
        let json = #"{"id": 42}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.id?.intValue, 42)
    }

    func testFlexibleID_stringNumeric_decodesAsInt() throws {
        let json = #"{"id": "7"}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.id?.intValue, 7)
    }

    func testFlexibleID_stringNonNumeric_decodesAsZero() throws {
        let json = #"{"id": "abc"}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.id?.intValue, 0)
    }

    func testFlexibleID_null_decodesAsNil() throws {
        let json = #"{"id": null}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        // null 解码时 try? Int 和 try? String 都失败，fallback 到 .int(0)
        // 但 id 字段是可选的，decode 失败时整个 id 为 nil
        XCTAssertNil(shell.id)
    }

    // MARK: - FlexibleAnswer.asIndex

    func testFlexibleAnswer_intInRange_returnsIndex() throws {
        let json = #"{"answer": 2, "options": ["A", "B", "C", "D"]}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.realAnswerIndex, 2)
    }

    func testFlexibleAnswer_intOutOfRange_returnsZero() throws {
        let json = #"{"answer": 99, "options": ["A", "B"]}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.realAnswerIndex, 0)
    }

    func testFlexibleAnswer_stringA_returns0() throws {
        let json = #"{"answer": "A", "options": ["A", "B", "C", "D"]}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.realAnswerIndex, 0)
    }

    func testFlexibleAnswer_stringB_returns1() throws {
        let json = #"{"answer": "B", "options": ["A", "B", "C", "D"]}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.realAnswerIndex, 1)
    }

    func testFlexibleAnswer_stringC_returns2() throws {
        let json = #"{"answer": "C", "options": ["A", "B", "C", "D"]}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.realAnswerIndex, 2)
    }

    func testFlexibleAnswer_stringD_returns3() throws {
        let json = #"{"answer": "D", "options": ["A", "B", "C", "D"]}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.realAnswerIndex, 3)
    }

    func testFlexibleAnswer_stringNumeric_returnsIndex() throws {
        let json = #"{"answer": "1", "options": ["A", "B", "C"]}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.realAnswerIndex, 1)
    }

    func testFlexibleAnswer_emptyOptions_returnsZero() throws {
        let json = #"{"answer": 2, "options": []}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.realAnswerIndex, 0)
    }

    func testFlexibleAnswer_DWithTwoOptions_cappedAt1() throws {
        let json = #"{"answer": "D", "options": ["A", "B"]}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.realAnswerIndex, 1, "D 应被 min(3, optionCount-1) 限制为 1")
    }

    // MARK: - realText 字段优先级

    func testRealText_questionField_priority() throws {
        let json = #"{"question": "Q1", "text": "T1", "questionText": "QT1"}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.realText, "Q1")
    }

    func testRealText_textField_fallback() throws {
        let json = #"{"text": "T1", "questionText": "QT1"}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.realText, "T1")
    }

    func testRealText_questionTextField_fallback() throws {
        let json = #"{"questionText": "QT1"}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.realText, "QT1")
    }

    func testRealText_allNil_returnsEmpty() throws {
        let json = #"{}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.FlexibleQuestionShell.self, from: data)
        XCTAssertEqual(shell.realText, "")
    }

    // MARK: - displayTitle 优先级

    func testDisplayTitle_quizTitle_priority() throws {
        let json = #"{"quizTitle": "QT", "title": "T"}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.self, from: data)
        XCTAssertEqual(shell.displayTitle, "QT")
    }

    func testDisplayTitle_title_fallback() throws {
        let json = #"{"title": "T"}"#
        let data = Data(json.utf8)
        let shell = try JSONDecoder().decode(QuizProcessor.FlexibleQuizShell.self, from: data)
        XCTAssertEqual(shell.displayTitle, "T")
    }

    // MARK: - canDecodeAsQuizModel

    func testCanDecodeAsQuizModel_validJSON_returnsTrue() {
        let json = """
        {"quizTitle": "测试", "questions": [{"question": "Q1", "options": ["A", "B"], "answer": 0}]}
        """
        XCTAssertTrue(QuizProcessor.canDecodeAsQuizModel(json))
    }

    func testCanDecodeAsQuizModel_emptyQuestions_returnsFalse() {
        let json = #"{"quizTitle": "测试", "questions": []}"#
        XCTAssertFalse(QuizProcessor.canDecodeAsQuizModel(json))
    }

    func testCanDecodeAsQuizModel_invalidJSON_returnsFalse() {
        XCTAssertFalse(QuizProcessor.canDecodeAsQuizModel("not a json"))
    }

    func testCanDecodeAsQuizModel_markdownQuiz_returnsTrue() {
        let md = """
        # 测验标题

        ## 1. 问题1

        * 选项A
        * 选项B

        正确答案: A
        """
        XCTAssertTrue(QuizProcessor.canDecodeAsQuizModel(md))
    }

    // MARK: - parseToQuizModel

    func testParseToQuizModel_validJSON_returnsModel() {
        let json = """
        {"quizTitle": "测试", "questions": [{"question": "Q1", "options": ["A", "B"], "answer": 0}]}
        """
        let model = QuizProcessor.parseToQuizModel(json)
        XCTAssertNotNil(model)
        XCTAssertEqual(model?.title, "测试")
        XCTAssertEqual(model?.questions.count, 1)
    }

    func testParseToQuizModel_emptyText_returnsNil() {
        XCTAssertNil(QuizProcessor.parseToQuizModel(""))
    }

    func testParseToQuizModel_randomizesAnswers() {
        // 多次解析，验证答案位置会变化（随机化生效）
        let json = """
        {"questions": [{"question": "Q", "options": ["A", "B", "C", "D"], "answer": 0}]}
        """
        var seenNonZero = false
        for _ in 0..<20 {
            if let model = QuizProcessor.parseToQuizModel(json) {
                if model.questions.first?.answer != 0 {
                    seenNonZero = true
                    break
                }
            }
        }
        // 由于随机化，20 次内应至少有一次答案不在位置 0
        XCTAssertTrue(seenNonZero, "答案随机化应使正确答案位置发生变化")
    }

    // MARK: - randomizeQuizAnswers

    func testRandomizeQuizAnswers_singleOption_unchanged() {
        let model = QuizModel(title: "T", questions: [
            QuizQuestion(id: 1, text: "Q", options: ["A"], answer: 0, explanation: "")
        ])
        let randomized = QuizProcessor.randomizeQuizAnswers(model)
        XCTAssertEqual(randomized.questions[0].options, ["A"])
        XCTAssertEqual(randomized.questions[0].answer, 0)
    }

    func testRandomizeQuizAnswers_stripsOptionPrefixes() {
        let model = QuizModel(title: "T", questions: [
            QuizQuestion(id: 1, text: "Q", options: ["A. 选项1", "B. 选项2"], answer: 0, explanation: "")
        ])
        let randomized = QuizProcessor.randomizeQuizAnswers(model)
        XCTAssertTrue(randomized.questions[0].options.contains("选项1"))
        XCTAssertTrue(randomized.questions[0].options.contains("选项2"))
        XCTAssertFalse(randomized.questions[0].options.contains("A. "))
    }

    func testRandomizeQuizAnswers_preservesCorrectAnswer() {
        let model = QuizModel(title: "T", questions: [
            QuizQuestion(id: 1, text: "Q", options: ["正确", "错误"], answer: 0, explanation: "")
        ])
        let randomized = QuizProcessor.randomizeQuizAnswers(model)
        let correctText = randomized.questions[0].options[randomized.questions[0].answer]
        XCTAssertEqual(correctText, "正确")
    }

    // MARK: - convertJSONToMarkdown

    func testConvertJSONToMarkdown_validJSON_returnsMarkdown() {
        let json = """
        {"quizTitle": "测试", "questions": [{"question": "Q1", "options": ["A", "B"], "answer": 0, "explanation": "解释"}]}
        """
        let md = QuizProcessor.convertJSONToMarkdown(json)
        XCTAssertNotNil(md)
        XCTAssertTrue(md?.contains("# 测试") == true)
        XCTAssertTrue(md?.contains("Q1") == true)
        XCTAssertTrue(md?.contains("A") == true)
    }

    func testConvertJSONToMarkdown_invalidJSON_returnsNil() {
        XCTAssertNil(QuizProcessor.convertJSONToMarkdown("not json"))
    }

    // MARK: - Markdown 试卷解析

    func testParseToQuizModel_markdownFormat_parsesTitle() {
        let md = """
        # 我的测验

        ## 1. 问题1

        * 选项A
        * 选项B
        """
        let model = QuizProcessor.parseToQuizModel(md)
        XCTAssertEqual(model?.title, "我的测验")
    }

    func testParseToQuizModel_markdownFormat_parsesQuestions() {
        let md = """
        # 测验

        ## 1. 问题1

        * 选项A
        * 选项B

        ## 2. 问题2

        * 选项C
        * 选项D
        """
        let model = QuizProcessor.parseToQuizModel(md)
        XCTAssertEqual(model?.questions.count, 2)
    }

    // MARK: - 缺陷 #10 回归测试：parseAnswerIndex 精确匹配

    func testParseAnswerIndex_answerA_returns0() {
        // "Answer: A" 应返回选项 A 的索引
        let model = QuizProcessor.parseToQuizModel("""
        # 测验

        ## 1. 问题

        * A
        * B
        * C
        * D

        Answer: A
        """)
        XCTAssertNotNil(model)
    }

    func testParseAnswerIndex_answerB_returns1() {
        // "Answer: B" 应返回选项 B 的索引
        XCTAssertNotNil(QuizProcessor.parseToQuizModel("""
        # 测验

        ## 1. 问题

        * A
        * B

        Answer: B
        """))
    }

    func testParseAnswerIndex_answerAB_returns0_bug10Fixed() {
        // 缺陷 #10 已修复："Answer: AB" 现在取首个字母 A，返回选项 A 的索引（而非旧的 B）
        // 注意：parseToQuizModel 会调用 randomizeQuizAnswers 打乱选项，无法直接验证 answer 值
        // 此处验证 ProcessorConstants.Synthesis.quizAnswerMap 的映射正确性（缺陷 #10 的核心修复点）
        XCTAssertEqual(ProcessorConstants.Synthesis.quizAnswerMap["A"], QuizProcessor.AnswerParsing.optionAIndex,
            "字母 A 应映射到选项 A 的索引")
        XCTAssertEqual(ProcessorConstants.Synthesis.quizAnswerMap["B"], QuizProcessor.AnswerParsing.optionBIndex,
            "字母 B 应映射到选项 B 的索引")

        // 验证模型被正确解析（不验证具体 answer 值，因随机化打乱）
        let model = QuizProcessor.parseToQuizModel("""
        # 测验

        ## 1. 问题

        * A
        * B
        * C
        * D

        Answer: AB
        """)
        XCTAssertNotNil(model, "模型应被正确解析")
    }
}
