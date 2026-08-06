//
//  NotebookThemeFactoryTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 NotebookThemeFactory 语义配色匹配、哈希分发兜底、种子确定性等边界语义。
//

import XCTest
@testable import ZhiYu

final class NotebookThemeFactoryTests: XCTestCase {

    // MARK: - 语义配色匹配

    func testGenerate_techKeyword_matchesTechPalette() {
        let config = NotebookThemeFactory.generate(from: "Tech Notes", id: UUID())
        XCTAssertEqual(config.colors, ["#4A90E2", "#50E3C2", "#B8E986", "#1F3B4D"])
    }

    func testGenerate_aiKeyword_matchesTechPalette() {
        let config = NotebookThemeFactory.generate(from: "AI Research", id: UUID())
        XCTAssertEqual(config.colors, ["#4A90E2", "#50E3C2", "#B8E986", "#1F3B4D"])
    }

    func testGenerate_codeKeyword_matchesTechPalette() {
        let config = NotebookThemeFactory.generate(from: "Code Snippets", id: UUID())
        XCTAssertEqual(config.colors, ["#4A90E2", "#50E3C2", "#B8E986", "#1F3B4D"])
    }

    func testGenerate_artKeyword_matchesArtPalette() {
        let config = NotebookThemeFactory.generate(from: "Art Gallery", id: UUID())
        XCTAssertEqual(config.colors, ["#FF9A9E", "#FECFEF", "#A18CD1", "#FBC2EB"])
    }

    func testGenerate_designKeyword_matchesArtPalette() {
        let config = NotebookThemeFactory.generate(from: "Design System", id: UUID())
        XCTAssertEqual(config.colors, ["#FF9A9E", "#FECFEF", "#A18CD1", "#FBC2EB"])
    }

    func testGenerate_retroKeyword_matchesRetroPalette() {
        let config = NotebookThemeFactory.generate(from: "Retro Collection", id: UUID())
        XCTAssertEqual(config.colors, ["#F6D365", "#FDA085", "#D4A373", "#7F4F24"])
    }

    func testGenerate_natureKeyword_matchesNaturePalette() {
        let config = NotebookThemeFactory.generate(from: "Nature Journal", id: UUID())
        XCTAssertEqual(config.colors, ["#84FAB0", "#8FD3F4", "#2D6A4F", "#00B4D8"])
    }

    func testGenerate_geekKeyword_matchesGeekPalette() {
        let config = NotebookThemeFactory.generate(from: "Geek Notes", id: UUID())
        XCTAssertEqual(config.colors, ["#000000", "#333333", "#00FF41", "#008F11"])
    }

    func testGenerate_hackerKeyword_matchesGeekPalette() {
        let config = NotebookThemeFactory.generate(from: "Hacker Log", id: UUID())
        XCTAssertEqual(config.colors, ["#000000", "#333333", "#00FF41", "#008F11"])
    }

    // MARK: - 大小写不敏感匹配

    func testGenerate_caseInsensitive_matching() {
        let config = NotebookThemeFactory.generate(from: "TECH NOTES", id: UUID())
        XCTAssertEqual(config.colors, ["#4A90E2", "#50E3C2", "#B8E986", "#1F3B4D"])
    }

    // MARK: - 哈希分发兜底

    func testGenerate_noKeywordMatch_usesDefaultPalette() {
        let config = NotebookThemeFactory.generate(from: "My Notebook", id: UUID())
        let defaultPalettes: [[String]] = [
            ["#4A90E2", "#50E3C2", "#764BA2", "#FF9A9E"],
            ["#A18CD1", "#FBC2EB", "#8FD3F4", "#84FAB0"],
            ["#F6D365", "#FDA085", "#764BA2", "#4A90E2"]
        ]
        XCTAssertTrue(defaultPalettes.contains(config.colors), "未匹配语义时应使用默认配色")
    }

    func testGenerate_sameNameSameId_producesSamePalette() {
        let id = UUID()
        let config1 = NotebookThemeFactory.generate(from: "Random Name", id: id)
        let config2 = NotebookThemeFactory.generate(from: "Random Name", id: id)
        XCTAssertEqual(config1.colors, config2.colors, "相同名称和 ID 应产生相同配色")
    }

    // MARK: - 类型与种子

    func testGenerate_type_isMesh() {
        let config = NotebookThemeFactory.generate(from: "Any Name", id: UUID())
        XCTAssertEqual(config.type, .mesh, "默认应返回 mesh 类型")
    }

    func testGenerate_seed_isIdHashAbsolute() {
        let id = UUID()
        let config = NotebookThemeFactory.generate(from: "Test", id: id)
        let expectedSeed = abs(id.hashValue)
        XCTAssertEqual(config.seed, expectedSeed)
    }

    // MARK: - 语义匹配优先级

    func testGenerate_firstMatchWins_techOverArt() {
        // "tech art" 应匹配 tech（先遍历到 tech），而非 art
        let config = NotebookThemeFactory.generate(from: "tech art", id: UUID())
        XCTAssertEqual(config.colors, ["#4A90E2", "#50E3C2", "#B8E986", "#1F3B4D"])
    }

    // MARK: - 空名称

    func testGenerate_emptyName_usesDefaultPalette() {
        let config = NotebookThemeFactory.generate(from: "", id: UUID())
        let defaultPalettes: [[String]] = [
            ["#4A90E2", "#50E3C2", "#764BA2", "#FF9A9E"],
            ["#A18CD1", "#FBC2EB", "#8FD3F4", "#84FAB0"],
            ["#F6D365", "#FDA085", "#764BA2", "#4A90E2"]
        ]
        XCTAssertTrue(defaultPalettes.contains(config.colors), "空名称应使用默认配色")
    }
}
