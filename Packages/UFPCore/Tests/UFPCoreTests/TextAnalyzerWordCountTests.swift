//
//  TextAnalyzerWordCountTests.swift
//  UFPCoreTests
//
//  系统层级：[UFPCoreTests]
//  核心职责：验证 TextAnalyzer.wordCount 对中英文混排、标点符号、纯数字与空文本的字数统计算法。
//

import XCTest
@testable import UFPCore

final class TextAnalyzerWordCountTests: XCTestCase {

    func testWordCount_emptyString_returnsZero() {
        XCTAssertEqual(TextAnalyzer.wordCount(""), 0)
    }

    func testWordCount_pureChinese_countsCharacters() {
        XCTAssertEqual(TextAnalyzer.wordCount("你好世界"), 4)
        XCTAssertEqual(TextAnalyzer.wordCount("自然语言处理与知识图谱"), 11)
    }

    func testWordCount_pureEnglish_countsWords() {
        XCTAssertEqual(TextAnalyzer.wordCount("hello"), 1)
        XCTAssertEqual(TextAnalyzer.wordCount("hello world"), 2)
        XCTAssertEqual(TextAnalyzer.wordCount("Swift strict concurrency mode"), 4)
    }

    func testWordCount_mixedChineseAndEnglish_countsAccurately() {
        // "你好" (2) + "world" (1) = 3
        XCTAssertEqual(TextAnalyzer.wordCount("你好world"), 3)
        XCTAssertEqual(TextAnalyzer.wordCount("你好 world"), 3)
        // 英文紧邻中文：触发 inEnglishWord 在 isCJKCharacter 时的刷新分支
        XCTAssertEqual(TextAnalyzer.wordCount("world你好"), 3)
        // 连续标点与符号
        XCTAssertEqual(TextAnalyzer.wordCount("hello...world"), 2)
        // "Swift" (1) + "6" (1) + "编程" (2) = 4
        XCTAssertEqual(TextAnalyzer.wordCount("Swift 6 编程"), 4)
    }

    func testWordCount_punctuationAndWhitespace_doesNotCountAsWords() {
        // "Hello," (1) + "world!" (1) = 2
        XCTAssertEqual(TextAnalyzer.wordCount("Hello, world!"), 2)
        // 纯中文无标点：6 个汉字 = 6
        XCTAssertEqual(TextAnalyzer.wordCount("这是一个测试"), 6)
        // 中文句号属 CJK 符号区间，计入 CJK 字符 = 7
        XCTAssertEqual(TextAnalyzer.wordCount("这是一个测试。"), 7)
        // 空格与换行符
        XCTAssertEqual(TextAnalyzer.wordCount("   \n\t  "), 0)
    }

    func testWordCount_trailingEnglishWord_flushesCount() {
        // 确保循环结束后 if inEnglishWord { count += 1 } 分支被正确执行
        XCTAssertEqual(TextAnalyzer.wordCount("End"), 1)
        XCTAssertEqual(TextAnalyzer.wordCount("知识管理 Wiki"), 4 + 1)
    }
}
