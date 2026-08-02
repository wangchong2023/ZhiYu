//
//  VaultTests.swift
//  ZhiYuTests
//
//  Created by Antigravity on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Tests] 单元测试层
//  核心职责：对 Vault 数据模型英文目录名自适应与转译清洗逻辑（englishName）进行充分的单元测试覆盖。
//

import XCTest
@testable import ZhiYu

final class VaultTests: XCTestCase {
    
    /// 测试内置默认笔记本的中英文及本地化翻译映射
    func testBuiltInVaultEnglishNames() {
        // 1. 默认笔记本 知识图谱 / Knowledge Graph
        let vault1 = Vault(name: L10n.Vault.defaultNameZh)
        XCTAssertEqual(vault1.englishName, "Personal_KM")
        
        let vault2 = Vault(name: L10n.Vault.defaultNameEn)
        XCTAssertEqual(vault2.englishName, "Personal_KM")
        
        // 2. 项目调研默认笔记本
        let vault3 = Vault(name: L10n.Vault.researchNameZh)
        XCTAssertEqual(vault3.englishName, "Project_Research")
        
        let vault4 = Vault(name: L10n.Vault.researchNameEn)
        XCTAssertEqual(vault4.englishName, "Project_Research")
    }
    
    /// 测试自定义笔记本中文名转换为拉丁拼音及特殊字符清洗
    func testCustomVaultChineseNameTranslation() {
        // 中文名转拼音并清洗特殊字符
        let vault = Vault(name: "我的 AI 知识库 & 笔记本 2026")
        // "我的 AI 知识库 & 笔记本 2026" -> "wo_de_AI_zhi_shi_ku_bi_ji_ben_2026" （去除了 & 等非安全字符）
        XCTAssertTrue(vault.englishName.contains("wo_de"))
        XCTAssertTrue(vault.englishName.contains("zhi_shi_ku"))
        XCTAssertFalse(vault.englishName.contains("&"))
        
        // 普通纯中文
        let vaultSimple = Vault(name: "个人笔记")
        XCTAssertEqual(vaultSimple.englishName, "ge_ren_bi_ji")
    }
    
    /// 测试带有多空格、连接符的自定义英文名称清洗
    func testCustomVaultEnglishNameCleaning() {
        let vault = Vault(name: "  My-Awesome  Vault_2026!! ")
        // 连续空格和连接符转为下划线，去除 !!，移除首尾下划线 -> "My_Awesome_Vault_2026"
        XCTAssertEqual(vault.englishName, "My_Awesome_Vault_2026")
    }
    
    /// 测试空笔记本名或纯特殊符号的边界情况兜底
    func testVaultNameBoundaryCases() {
        let id = UUID()
        let vaultEmpty = Vault(id: id, name: "   ")
        XCTAssertEqual(vaultEmpty.englishName, "Vault_\(id.uuidString.prefix(8))")
        
        let vaultSymbols = Vault(id: id, name: "###$$$@@@")
        XCTAssertEqual(vaultSymbols.englishName, "Vault_\(id.uuidString.prefix(8))")
    }
}
