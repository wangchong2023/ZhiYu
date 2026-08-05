//
//  InitialNotebookGenerator.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：提供项目启动时的初始演示/测试笔记本（Initial Notebook）数据生成器。
//           支持为页面填充物理溯源文件（在 sandbox 中的 Imports 文件夹下真实写入文件），
//           以保证详情页能够正确渲染引用源（Provenance）追溯视图，且与用户手工导入文件保持绝对一致。
//

import Foundation
import UFPCore
import UFPStorage

/// 演示数据生成器
///
/// 职责：用于快速填充知识库，展示图谱、检索、AI 分析及引用物理文件溯源能力。
struct InitialNotebookGenerator {

    /// 个人知识管理演示数据页面总数
    static let pkmPageCount = 18
    /// 咖啡店项目调研演示数据页面总数
    static let researchPageCount = 15

    // MARK: - 模拟调用日志常量

    /// 演示模型名称，模拟未配置外部大模型时的内置/本地空跑服务
    private static let demoModelName = "ZhiYu-Local-Mock"
    
    /// PKM 模拟调用条数
    private static let pkmLogCount = 50
    /// 调研集模拟调用条数
    private static let researchLogCount = 30
    
    /// PKM 模拟随机小时跨度 (30天 = 720小时)
    private static let pkmMaxHoursAgo = 720
    /// 调研集模拟随机小时跨度 (12天 = 288小时)
    private static let researchMaxHoursAgo = 288
    
    /// 提示 Token 最小值与最大值
    private static let minPromptTokens = 100
    private static let maxPromptTokens = 1000
    /// 补全 Token 最小值与最大值
    private static let minCompletionTokens = 50
    private static let maxCompletionTokens = 2000
    /// 模拟延迟最小值与最大值
    private static let minLatencyMS = 300
    private static let maxLatencyMS = 4500

    /// 统一的演示数据种子结构，支持溯源元数据
    struct PageSeed {
        let title: String
        let type: PageType
        let content: String
        let tags: [String]
        let sourceURL: String?
        let rawTextSnippet: String?
        let sourceType: String?

        init(
            title: String,
            type: PageType,
            content: String,
            tags: [String],
            sourceURL: String? = nil,
            rawTextSnippet: String? = nil,
            sourceType: String? = nil
        ) {
            self.title = title
            self.type = type
            self.content = content
            self.tags = tags
            self.sourceURL = sourceURL
            self.rawTextSnippet = rawTextSnippet
            self.sourceType = sourceType
        }
    }

    // MARK: - 公开生成接口

    /// 执行默认 PKM（个人知识管理）演示数据生成
    /// - Parameter store: 目标存储对象
    /// - Returns: 生成的页面数量
    static func generate(in store: any AnyPageStore) async throws -> Int {
        Logger.shared.info("InitialNotebook_Starting")
        let fileFolder = await resolveImportsFolder(for: .file)
        let ocrFolder = await resolveImportsFolder(for: .ocr)
        let voiceFolder = await resolveImportsFolder(for: .voice)
        
        // 动态根据当前本地化语言，决定去 Bundle 寻找的物理文件名（中文版使用中文物理文件名，英文版使用英文物理文件名）
        let methodologyURL = resolveFileURL(bundleName: L10n.InitialNotebook.FileNames.methodology, localName: L10n.InitialNotebook.FileNames.methodology, in: fileFolder,
            fallback: L10n.InitialNotebook.Fallback.methodology)
        let workflowURL = resolveFileURL(bundleName: L10n.InitialNotebook.FileNames.workflow, localName: L10n.InitialNotebook.FileNames.workflow, in: fileFolder,
            fallback: L10n.InitialNotebook.Fallback.workflow)
        let ocrFolderURL = resolveFileURL(bundleName: StorageConstants.BundleResource.ocrFolderScan, localName: L10n.InitialNotebook.FileNames.ocrFolderScan, in: ocrFolder,
            fallback: "")
        let voiceForgetURL = resolveFileURL(bundleName: "voice_note_forgetting_curve.mp3", localName: L10n.InitialNotebook.FileNames.voiceNoteForget, in: voiceFolder,
            fallback: "")
        
        let seeds = buildPKMPageSeeds(
            methodologyURL: methodologyURL,
            workflowURL: workflowURL,
            ocrFolderURL: ocrFolderURL,
            voiceForgetURL: voiceForgetURL
        )
        try await persistPages(seeds, in: store) { db in
            try injectPKMMockLogs(db: db)
        }
        Logger.shared.info("InitialNotebook_Finished")
        return seeds.count
    }

    /// 执行项目调研（Research）演示数据生成
    /// - Parameter store: 目标存储对象
    /// - Returns: 生成的页面数量
    static func generateResearchNotebook(in store: any AnyPageStore) async throws -> Int {
        Logger.shared.info("ResearchInitialNotebook_Starting")
        let fileFolder = await resolveImportsFolder(for: .file)
        let ocrFolder = await resolveImportsFolder(for: .ocr)
        let voiceFolder = await resolveImportsFolder(for: .voice)
        
        // 动态根据当前本地化语言，决定去 Bundle 寻找的物理文件名（中文版使用中文物理文件名，英文版使用英文物理文件名）
        let luckinURL = resolveFileURL(bundleName: L10n.InitialNotebook.FileNames.luckin, localName: L10n.InitialNotebook.FileNames.luckin, in: fileFolder,
            fallback: L10n.InitialNotebook.Fallback.luckin)
        let surveyURL = resolveFileURL(bundleName: L10n.InitialNotebook.FileNames.survey, localName: L10n.InitialNotebook.FileNames.survey, in: fileFolder,
            fallback: L10n.InitialNotebook.Fallback.survey)
        let ocrStoreURL = resolveFileURL(bundleName: StorageConstants.BundleResource.ocrStoreManual, localName: L10n.InitialNotebook.FileNames.ocrStoreManual, in: ocrFolder,
            fallback: "")
        let voiceProcureURL = resolveFileURL(bundleName: StorageConstants.BundleResource.voiceNoteProcurement, localName: L10n.InitialNotebook.FileNames.voiceNoteProcure, in: voiceFolder,
            fallback: "")
        
        let seeds = buildResearchPageSeeds(
            luckinURL: luckinURL,
            surveyURL: surveyURL,
            ocrStoreURL: ocrStoreURL,
            voiceProcureURL: voiceProcureURL
        )
        try await persistPages(seeds, in: store) { db in
            try injectResearchMockLogs(db: db)
        }
        Logger.shared.info("ResearchInitialNotebook_Finished")
        return seeds.count
    }

    /// 执行图谱压力测试数据生成（兼容测试套件调用）
    /// - Parameters:
    ///   - store: 目标存储对象
    ///   - targetCount: 注入的节点数量
    /// - Returns: 实际生成的页面数
    static func generateStressTest(in store: any AnyPageStore, count targetCount: Int = 1000) async throws -> Int {
        try await generateStressTestNotebooks(in: store, count: targetCount)
    }

    /// 执行图谱压力测试数据生成
    /// - Parameters:
    ///   - store: 目标存储对象
    ///   - targetCount: 生成的节点数量，默认为 1000
    /// - Returns: 生成的页面数量
    static func generateStressTestNotebooks(in store: any AnyPageStore, count targetCount: Int = 1000) async throws -> Int {
        Logger.shared.info("StressTestData_Starting")

        try await store.performBatchWrite { db in
            // 按照依赖关系的反向顺序进行物理清理
            try KnowledgePage.deleteAll(db)

            // 预生成标题列表，用于建立随机链接
            let titles = (1...targetCount).map { "StressNode_\($0)" }
            let types: [PageType] = [.concept, .entity, .source, .comparison]

            var localCount = 0
            for i in 0..<targetCount {
                let title = titles[i]
                let type = types[i % types.count]

                // 随机选择 1-3 个其他节点建立链接
                var content = ""
                let linkCount = Int.random(in: 1...3)
                var linkedIndices = Set<Int>()
                while linkedIndices.count < linkCount {
                    let randIdx = Int.random(in: 0..<targetCount)
                    if randIdx != i { linkedIndices.insert(randIdx) }
                }
                for _ in linkedIndices { content += "" }

                let page = KnowledgePage(
                    title: title, pageType: type, content: content,
                    tags: ["StressTest", "Performance"]
                )
                try page.save(db)
                localCount += 1
                if localCount % 100 == 0 { Logger.shared.debug("") }
            }
        }

        Logger.shared.debug("")
        return targetCount
    }

    // MARK: - 私有辅助方法：文件路径解析

    private static func getCategoryDirName(for category: ImportCategory) -> String {
        switch category {
        case .file: return "document"
        case .voice: return "audio"
        case .ocr: return "ocr"
        case .link: return "web"
        case .clipboard: return "clipboard"
        case .manual: return "manual"
        }
    }

    /// 解析当前笔记本沙盒目录下的 raw/{笔记本英文名}/{Category} 文件夹路径
    /// 必须在 MainActor 上执行，以安全访问 DatabaseManager
    private static func resolveImportsFolder(for category: ImportCategory) async -> URL? {
        await MainActor.run {
            if let dbURL = DatabaseManager.shared.dbURL {
                let fm = FileManager.default
                let categoryDirName = getCategoryDirName(for: category)
                
                // 从 UserDefaults 读取当前活跃笔记本英文名，作为 raw 隔离目录结构一部分
                let englishName = UserDefaults.standard.string(forKey: "vaultSelectedEnglishName") ?? "fallback"
                
                let folder = dbURL.deletingLastPathComponent()
                    .appendingPathComponent("raw")
                    .appendingPathComponent(englishName)
                    .appendingPathComponent(categoryDirName)
                
                try? fm.createDirectory(at: folder, withIntermediateDirectories: true)
                return folder
            }
            return nil
        }
    }

    /// 将演示 file 路径解析为字符串 URL，若 folder 为 nil 则返回虚拟演示地址
    private static func resolveFileURL(bundleName: String, localName: String, in folder: URL?, fallback: String) -> String {
        guard let folder else { return "file:///demo/\(localName)" }
        return copyOrWriteDemoFile(bundleName: bundleName, localName: localName, to: folder, fallbackText: fallback)
    }

    // MARK: - 私有辅助方法：数据集构建

    /// 构建 PKM 知识管理演示页面的种子数据
    /// - Parameters:
    ///   - methodologyURL: pkm_methodology.md 的本地物理文件路径
    ///   - workflowURL: pkm_workflow.md 的本地物理文件路径
    ///   - ocrFolderURL: ocr_folder_scan.png 的本地物理文件路径
    ///   - voiceForgetURL: voice_note_forgetting_curve.mp3 的本地物理文件路径
    /// - Returns: 包含15个页面的种子数据数组
    private static func buildPKMPageSeeds(
        methodologyURL: String,
        workflowURL: String,
        ocrFolderURL: String,
        voiceForgetURL: String
    ) -> [PageSeed] {
        let methodologySnippet = L10n.InitialNotebook.Snippet.methodology
        let workflowSnippet = L10n.InitialNotebook.Snippet.workflow
        return [
            // 1. 个人知识图谱指南
            PageSeed(title: L10n.InitialNotebook.PKM.title1, type: .concept, content: L10n.InitialNotebook.PKM.content1,
                     tags: [L10n.InitialNotebook.Tags.knowledgeMgmt, L10n.InitialNotebook.Tags.methodology],
                     sourceURL: methodologyURL, rawTextSnippet: methodologySnippet, sourceType: StorageConstants.SourceType.markdown),
            
            // 2. 词条：什么是神经元
            PageSeed(title: L10n.InitialNotebook.PKM.title2, type: .entity, content: L10n.InitialNotebook.PKM.content2,
                     tags: [L10n.InitialNotebook.Tags.noteStyles, L10n.InitialNotebook.Tags.efficiency],
                     sourceURL: ocrFolderURL, rawTextSnippet: L10n.InitialNotebook.Snippet.pkmOcrFolder, sourceType: StorageConstants.SourceType.ocr),
            
            // 3. 跨领域笔记枢纽指南
            PageSeed(title: L10n.InitialNotebook.PKM.title3, type: .concept, content: L10n.InitialNotebook.PKM.content3,
                     tags: [L10n.InitialNotebook.Tags.techPrinciple, L10n.InitialNotebook.Tags.association],
                     sourceURL: AppConstants.URLs.exampleKarpathyLLM, rawTextSnippet: L10n.InitialNotebook.Snippet.pkmRagLink, sourceType: StorageConstants.SourceType.link),
            
            // 4. 语音速记的未关联笔记
            PageSeed(title: L10n.InitialNotebook.PKM.title4, type: .source, content: L10n.InitialNotebook.PKM.content4,
                     tags: [L10n.InitialNotebook.Tags.cognitivePsych],
                     sourceURL: voiceForgetURL, rawTextSnippet: L10n.InitialNotebook.Snippet.pkmVoiceForget, sourceType: StorageConstants.SourceType.voice),
            
            // 5. 渐进式总结对比分析
            PageSeed(title: L10n.InitialNotebook.PKM.title5, type: .comparison, content: L10n.InitialNotebook.PKM.content5,
                     tags: [L10n.InitialNotebook.Tags.retrievalTech],
                     sourceURL: workflowURL, rawTextSnippet: workflowSnippet, sourceType: StorageConstants.SourceType.pdf),
            
            // 6. 笔记的原子化解构
            PageSeed(title: String(localized: "demo.pkm.6.title", defaultValue: "笔记的原子化解构"), type: .concept,
                     content: String(localized: "demo.pkm.6.content", defaultValue: "原子化笔记（Atomic Notes）要求每个笔记只包含一个核心思想。它是[[个人知识图谱指南]]与[[卡片盒笔记法]]的基石，便于后续的灵活组合与复用。"),
                     tags: [L10n.InitialNotebook.Tags.noteStyles, L10n.InitialNotebook.Tags.efficiency]),
            
            // 7. 双向链接的价值
            PageSeed(title: String(localized: "demo.pkm.7.title", defaultValue: "双向链接的价值"), type: .concept,
                     content: String(localized: "demo.pkm.7.content", defaultValue: "通过[[双向链接的价值]]，我们可以在[[个人知识图谱指南]]中发现不同知识点之间隐藏的关联，从而将孤立的[[语音速记的未关联笔记]]连结起来，形成非线性的网状知识结构。"),
                     tags: [L10n.InitialNotebook.Tags.association, L10n.InitialNotebook.Tags.techPrinciple]),
            
            // 8. 费曼学习法实践
            PageSeed(title: String(localized: "demo.pkm.8.title", defaultValue: "费曼学习法实践"), type: .entity,
                     content: String(localized: "demo.pkm.8.content", defaultValue: "费曼学习法要求用最简单的语言解释复杂的概念。它是检验自己是否真正掌握知识的最好方法，在编写[[词条：什么是神经元]]或进行[[渐进式总结对比分析]]时有极大帮助。"),
                     tags: [L10n.InitialNotebook.Tags.learningMethod, L10n.InitialNotebook.Tags.cognitivePsych]),
            
            // 9. 渐进式总结
            PageSeed(title: String(localized: "demo.pkm.9.title", defaultValue: "渐进式总结"), type: .comparison,
                     content: String(localized: "demo.pkm.9.content", defaultValue: "Tiago Forte 提出的渐进式总结，要求通过多层高亮和加粗，快速提取文章核心精华。在[[个人知识图谱指南]]的构建过程中，它能够平衡阅读理解与笔记记录的精力消耗。"),
                     tags: [L10n.InitialNotebook.Tags.readingMethod, L10n.InitialNotebook.Tags.summary]),
            
            // 10. 卡片盒笔记法
            PageSeed(title: String(localized: "demo.pkm.10.title", defaultValue: "卡片盒笔记法"), type: .concept,
                     content: String(localized: "demo.pkm.10.content", defaultValue: "Zettelkasten 是一种自下而上的知识管理方法，通过卡片之间的[[双向链接的价值]]实现灵感的自然涌现。每一个原子卡片都遵循[[笔记的原子化解构]]原则。"),
                     tags: [L10n.InitialNotebook.Tags.knowledgeMgmt, L10n.InitialNotebook.Tags.innovation]),
            
            // 11. 语义网与知识图谱
            PageSeed(title: String(localized: "demo.pkm.11.title", defaultValue: "语义网与知识图谱"), type: .concept,
                     content: "语义网络通过图谱结构呈现复杂关联。在[[个人知识图谱指南]]的深入实践中，我们通过[[双向链接的价值]]将分散的卡片关联起来，最终建立一个类似[[卡片盒笔记法]]的语义网络图谱。",
                     tags: [L10n.InitialNotebook.Tags.association, L10n.InitialNotebook.Tags.techPrinciple]),
            
            // 12. 混合检索策略
            PageSeed(title: String(localized: "demo.pkm.12.title", defaultValue: "混合检索策略"), type: .concept,
                     content: "在[[个人知识图谱指南]]的检索设计中，混合检索结合了传统的关键字检索与向量相似度检索。当笔记完成了[[笔记的原子化解构]]后，混合检索可以极大提升 RAG 系统在[[跨领域笔记枢纽指南]]上下文召回中的准确率。",
                     tags: [L10n.InitialNotebook.Tags.retrievalTech, L10n.InitialNotebook.Tags.efficiency]),
            
            // 13. 主动召回与间隔重复
            PageSeed(title: String(localized: "demo.pkm.13.title", defaultValue: "主动召回与间隔重复"), type: .entity,
                     content: "主动召回是克服遗忘的科学手段。我们在实践[[费曼学习法实践]]时，可以结合主动召回机制，为[[卡片盒笔记法]]中的每一个神经元词条（例如[[词条：什么是神经元]]）设定渐进式的复习排程。",
                     tags: [L10n.InitialNotebook.Tags.cognitivePsych, L10n.InitialNotebook.Tags.learningMethod]),
            
            // 14. 结构化知识输出
            PageSeed(title: String(localized: "demo.pkm.14.title", defaultValue: "结构化知识输出"), type: .comparison,
                     content: "输入知识的最终目的是为了创造和输出。通过[[渐进式总结]]提炼信息，再在[[卡片盒笔记法]]中交叉连接，最后利用[[费曼学习法实践]]将它们组织成[[结构化知识输出]]的系统文章。",
                     tags: [L10n.InitialNotebook.Tags.summary, L10n.InitialNotebook.Tags.productivity]),
            
            // 15. 知识的涌现效应
            PageSeed(title: String(localized: "demo.pkm.15.title", defaultValue: "知识的涌现效应"), type: .concept,
                     content: "涌现效应是指当系统节点达到一定数量时出现的质变。在[[个人知识图谱指南]]中，只要我们不断为[[语音速记的未关联笔记]]建立链接，庞大的[[双向链接的价值]]网络就会自发在[[跨领域笔记枢纽指南]]中催生出全新的交叉学科灵感。",
                     tags: [L10n.InitialNotebook.Tags.association, L10n.InitialNotebook.Tags.innovation]),
            
            // 16. 卢曼卡片盒的选择
            PageSeed(title: String(localized: "demo.pkm.16.title", defaultValue: "卢曼卡片盒的选择"), type: .concept,
                     content: String(localized: "demo.pkm.16.content", defaultValue: "卢曼使用纸质卡片盒积累了大量的学术成果。选择卡片盒而不是笔记本，关键在于摆脱线性的目录束缚，促成不同主题（如[[卡片盒笔记法]]与[[费曼学习法实践]]）之间的非线性网状碰撞。"),
                     tags: [L10n.InitialNotebook.Tags.noteStyles, L10n.InitialNotebook.Tags.learningMethod]),
            
            // 17. 信息茧房与知识整合
            PageSeed(title: String(localized: "demo.pkm.17.title", defaultValue: "信息茧房与知识整合"), type: .entity,
                     content: String(localized: "demo.pkm.17.content", defaultValue: "在海量碎片化信息中，人们极易陷入信息茧房。通过在[[个人知识图谱指南]]中对信息进行原子化重写，并手动与已有的[[知识的涌现效应]]建立关联，能有效促进跨领域知识整合。"),
                     tags: [L10n.InitialNotebook.Tags.knowledgeMgmt, L10n.InitialNotebook.Tags.association]),
            
            // 18. 双脑协同工作流
            PageSeed(title: String(localized: "demo.pkm.18.title", defaultValue: "双脑协同工作流"), type: .comparison,
                     content: String(localized: "demo.pkm.18.content", defaultValue: "双脑协同工作流将人类的生物脑作为灵感与决策引擎，将基于[[个人知识图谱指南]]构建的“数字外脑”作为海量存储与精确索引。两者的协同配合需要依赖[[混合检索策略]]与[[主动召回与间隔重复]]机制。"),
                     tags: [L10n.InitialNotebook.Tags.summary, L10n.InitialNotebook.Tags.efficiency])
        ]
    }

    /// 构建项目调研（咖啡店研究）演示页面的种子数据
    /// - Parameters:
    ///   - luckinURL: 瑞幸 vs 星巴克分析报告 PDF 的本地物理文件路径
    ///   - surveyURL: 用户调研问卷 PDF 的本地物理文件路径
    ///   - ocrStoreURL: ocr_store_manual.png 的本地物理文件路径
    ///   - voiceProcureURL: voice_note_procurement.mp3 的本地物理文件路径
    /// - Returns: 包含15个页面的种子数据数组
    private static func buildResearchPageSeeds(
        luckinURL: String,
        surveyURL: String,
        ocrStoreURL: String,
        voiceProcureURL: String
    ) -> [PageSeed] {
        let luckinSnippet = L10n.InitialNotebook.Snippet.luckin
        let surveySnippet = L10n.InitialNotebook.Snippet.survey
        return [
            // 1. 瑞幸与星巴克商业对比报告
            PageSeed(title: L10n.InitialNotebook.Coffee.title1, type: .comparison,
                     content: L10n.InitialNotebook.Coffee.content1,
                     tags: [L10n.InitialNotebook.Tags.competitorAnalysis, L10n.InitialNotebook.Tags.marketResearch],
                     sourceURL: luckinURL, rawTextSnippet: luckinSnippet, sourceType: StorageConstants.SourceType.pdf),
            
            // 2. 词条：什么是咖啡豆烘焙度
            PageSeed(title: L10n.InitialNotebook.Coffee.title2, type: .entity,
                     content: L10n.InitialNotebook.Coffee.content2,
                     tags: [L10n.InitialNotebook.Tags.productDesign, L10n.InitialNotebook.Tags.operation],
                     sourceURL: ocrStoreURL, rawTextSnippet: L10n.InitialNotebook.Snippet.coffeeOcrManual, sourceType: StorageConstants.SourceType.ocr),
            
            // 3. 咖啡连锁行业选址规划
            PageSeed(title: L10n.InitialNotebook.Coffee.title3, type: .concept,
                     content: L10n.InitialNotebook.Coffee.content3,
                     tags: [L10n.InitialNotebook.Tags.userResearch],
                     sourceURL: AppConstants.URLs.exampleCoffeeIndustry, rawTextSnippet: L10n.InitialNotebook.Snippet.coffeeRagLink, sourceType: StorageConstants.SourceType.link),
            
            // 4. 语音速记：咖啡设备采购清单
            PageSeed(title: L10n.InitialNotebook.Coffee.title4, type: .source,
                     content: L10n.InitialNotebook.Coffee.content4,
                     tags: [L10n.InitialNotebook.Tags.infrastructure, L10n.InitialNotebook.Tags.decoration],
                     sourceURL: voiceProcureURL, rawTextSnippet: L10n.InitialNotebook.Snippet.coffeeVoiceProcure, sourceType: StorageConstants.SourceType.voice),
            
            // 5. 咖啡店日常运营手册
            PageSeed(title: L10n.InitialNotebook.Coffee.title5, type: .concept,
                     content: L10n.InitialNotebook.Coffee.content5,
                     tags: [L10n.InitialNotebook.Tags.finance, L10n.InitialNotebook.Tags.planning],
                     sourceURL: surveyURL, rawTextSnippet: surveySnippet, sourceType: StorageConstants.SourceType.markdown),
            
            // 6. Manner 扩张策略
            PageSeed(title: String(localized: "demo.coffee.6.title", defaultValue: "Manner 扩张策略"), type: .comparison,
                     content: String(localized: "demo.coffee.6.content", defaultValue: "Manner 早期主打极小店面和自带杯优惠，以极高坪效支撑其[[咖啡连锁行业选址规划]]。随后通过[[咖啡豆供应链成本拆解]]获得的成本红利，向一线城市的核心商圈进行规模扩张。"),
                     tags: [L10n.InitialNotebook.Tags.competitorAnalysis, L10n.InitialNotebook.Tags.planning]),
            
            // 7. 下沉市场咖啡消费洞察
            PageSeed(title: String(localized: "demo.coffee.7.title", defaultValue: "下沉市场咖啡消费洞察"), type: .concept,
                     content: String(localized: "demo.coffee.7.content", defaultValue: "三四线城市的消费者更注重社交属性和极致性价比，这与[[瑞幸与星巴克商业对比报告]]中的瑞幸打法不谋合。在进行[[咖啡连锁行业选址规划]]时，必须针对下沉市场的用户画像做定制化菜单。"),
                     tags: [L10n.InitialNotebook.Tags.marketResearch, L10n.InitialNotebook.Tags.userResearch]),
            
            // 8. 独立咖啡馆生存指南
            PageSeed(title: String(localized: "demo.coffee.8.title", defaultValue: "独立咖啡馆生存指南"), type: .entity,
                     content: String(localized: "demo.coffee.8.content", defaultValue: "独立咖啡馆需要建立独特的品牌调性和社区连接，以差异化体验对抗[[瑞幸与星巴克商业对比报告]]中的连锁品牌规模优势。在日常运营中，可参考[[咖啡店日常运营手册]]进行精细化管理。"),
                     tags: [L10n.InitialNotebook.Tags.operation, L10n.InitialNotebook.Tags.team]),
            
            // 9. 咖啡豆供应链成本拆解
            PageSeed(title: String(localized: "demo.coffee.9.title", defaultValue: "咖啡豆供应链成本拆解"), type: .source,
                     content: String(localized: "demo.coffee.9.content", defaultValue: "供应链成本控制是咖啡馆盈利的生命线。从生豆采购、烘焙损耗（参考[[词条：什么是咖啡豆烘焙度]]）到物流，每个环节的成本把控都直接决定了[[独立咖啡馆生存指南]]中的毛利表现。"),
                     tags: [L10n.InitialNotebook.Tags.supplyChain, L10n.InitialNotebook.Tags.finance]),
            
            // 10. 第三空间设计原则
            PageSeed(title: String(localized: "demo.coffee.10.title", defaultValue: "第三空间设计原则"), type: .concept,
                     content: String(localized: "demo.coffee.10.content", defaultValue: "第三空间概念强调舒适的座椅、适宜的灯光，旨在为顾客提供家与工作场所之外的放松区域。这一原则在[[咖啡店日常运营手册]]中被奉为圭臬，也是我们设计新店空间时的重要参考。"),
                     tags: [L10n.InitialNotebook.Tags.decoration, L10n.InitialNotebook.Tags.design]),
            
            // 11. 咖啡店选址方法论
            PageSeed(title: String(localized: "demo.coffee.11.title", defaultValue: "咖啡店选址方法论"), type: .concept,
                     content: "咖啡店选址是一门科学。我们需要结合[[下沉市场咖啡消费洞察]]的数据流，并在[[咖啡连锁行业选址规划]]的框架下，通过客流模型和租金模型进行综合评估，这直接关乎[[独立咖啡馆生存指南]]的生死存亡。",
                     tags: [L10n.InitialNotebook.Tags.planning, L10n.InitialNotebook.Tags.operation]),
            
            // 12. 菜单研发与爆款策略
            PageSeed(title: String(localized: "demo.coffee.12.title", defaultValue: "菜单研发与爆款策略"), type: .comparison,
                     content: "爆款战略能迅速打开品牌知名度。借鉴[[瑞幸与星巴克商业对比报告]]中瑞幸生椰拿铁的成功逻辑，研发团队需利用[[词条：什么是咖啡豆烘焙度]]中不同的风味基调设计新品，并通过[[咖啡豆供应链成本拆解]]锁定原材料采购优势。",
                     tags: [L10n.InitialNotebook.Tags.productDesign, L10n.InitialNotebook.Tags.competitorAnalysis]),
            
            // 13. 咖啡会员与数字化运营
            PageSeed(title: String(localized: "demo.coffee.13.title", defaultValue: "咖啡会员与数字化运营"), type: .entity,
                     content: "数字化是提升复购率的核武器。连锁咖啡品牌（如[[瑞幸与星巴克商业对比报告]]）通过小程序券包和社群营销将顾客转化为会员。对于小店来说，将这些技术简化后写入[[咖啡店日常运营手册]]中，也能获得稳定的熟客流量。",
                     tags: [L10n.InitialNotebook.Tags.operation, L10n.InitialNotebook.Tags.userResearch]),
            
            // 14. 烘焙工厂与产地直采
            PageSeed(title: String(localized: "demo.coffee.14.title", defaultValue: "烘焙工厂与产地直采"), type: .source,
                     content: "为了从根本上降低[[咖啡豆供应链成本拆解]]中的原料损耗，头部连锁咖啡店开始自建烘焙工厂并直接向产地直采咖啡生豆，这对于稳定风味（如保障[[词条：什么是咖啡豆烘焙度]]的标准）和支撑[[Manner 扩张策略]]的超高开店速度至关重要。",
                     tags: [L10n.InitialNotebook.Tags.supplyChain, L10n.InitialNotebook.Tags.finance]),
            
            // 15. 社区咖啡与熟客文化
            PageSeed(title: String(localized: "demo.coffee.15.title", defaultValue: "社区咖啡与熟客文化"), type: .concept,
                     content: "社区咖啡馆强调邻里熟人间的信任纽带，这与大型连锁品牌抛弃[[第三空间设计原则]]主打快取店的策略相反。它是[[独立咖啡馆生存指南]]的核心防线，通过高品质的日常交流与精细化运营，建立起天然的本地竞争壁垒。",
                     tags: [L10n.InitialNotebook.Tags.decoration, L10n.InitialNotebook.Tags.team])
        ]
    }

    // MARK: - 私有辅助方法：持久化
    
    /// 通用页面批量写入模板：清空旧数据 → 写入页面 → 执行附加日志注入及导入历史写入
    private static func persistPages(
        _ seeds: [PageSeed],
        in store: any AnyPageStore,
        additionalWrites: @escaping @Sendable (Database) throws -> Void
    ) async throws {
        let activeVaultID = await MainActor.run {
            ServiceContainer.shared.resolve((any VaultServiceProtocol).self).selectedVaultID?.uuidString
        }
        
        try await store.performBatchWrite { db in
            try KnowledgePage.deleteAll(db)
            try TokenUsage.deleteAll(db)
            try LLMCallLog.deleteAll(db)
            try ImportRecord.deleteAll(db)
            
            for seed in seeds {
                let pageID = UUID()
                let page = KnowledgePage(
                    id: pageID,
                    title: seed.title, pageType: seed.type, content: seed.content,
                    tags: seed.tags, sourceURL: seed.sourceURL,
                    rawTextSnippet: seed.rawTextSnippet, sourceType: seed.sourceType
                )
                try page.save(db)
                
                // 建立对应的已完成导入记录，对齐导入历史和状态维护。
                // 根据 PageSeed 中声明的 sourceType，将其映射到标准的 6 种 Ingest 导入分类中。
                let category: String
                if let st = seed.sourceType?.lowercased() {
                    if [StorageConstants.SourceType.ocr, StorageConstants.SourceType.clipboard, StorageConstants.SourceType.voice, StorageConstants.SourceType.link, StorageConstants.SourceType.manual].contains(st) {
                        category = st
                    } else if st == StorageConstants.SourceType.pdf || st == StorageConstants.SourceType.markdown || st == StorageConstants.SourceType.md || st == StorageConstants.SourceType.file {
                        category = StorageConstants.SourceType.file
                    } else {
                        category = StorageConstants.SourceType.manual
                    }
                } else if seed.sourceURL != nil {
                    category = "link"
                } else {
                    category = "manual"
                }
                
                let filePath: String?
                if let urlStr = seed.sourceURL, let url = URL(string: urlStr) {
                    filePath = url.path
                } else {
                    filePath = nil
                }
                
                var record = ImportRecord(
                    id: UUID().uuidString,
                    category: category,
                    title: seed.title,
                    status: StorageConstants.OperationStatus.done,
                    rawText: seed.rawTextSnippet,
                    sourceURL: seed.sourceURL,
                    filePath: filePath,
                    fileSize: Int64((seed.rawTextSnippet ?? seed.content).utf8.count),
                    pageID: pageID.uuidString,
                    vaultID: activeVaultID,
                    taskID: nil,
                    tags: seed.tags.joined(separator: ", "),
                    createdAt: Date(),
                    completedAt: Date()
                )
                try record.save(db)
            }
            try additionalWrites(db)
        }
    }

    /// 注入 PKM 演示集的模拟 AI 调用日志（50 条，近 30天随机分布）
    private static func injectPKMMockLogs(db: Database) throws {
        let calendar = Calendar.current
        for _ in 0..<pkmLogCount {
            let model = demoModelName
            let prompt = Int.random(in: minPromptTokens...maxPromptTokens)
            let completion = Int.random(in: minCompletionTokens...maxCompletionTokens)
            let latency = Int.random(in: minLatencyMS...maxLatencyMS)
            guard let date = calendar.date(byAdding: .hour, value: -Int.random(in: 1...pkmMaxHoursAgo), to: Date()) else { continue }
            var log = LLMCallLog(model: model, promptTokens: prompt, completionTokens: completion,
                                 latencyMS: latency, status: StorageConstants.OperationStatus.success, createdAt: date)
            try log.insert(db)
            var usage = TokenUsage(model: model, promptTokens: prompt, completionTokens: completion, createdAt: date)
            try usage.insert(db)
        }
    }

    /// 注入调研演示集的模拟 AI 调用日志（30 条，近 12 天随机分布）
    private static func injectResearchMockLogs(db: Database) throws {
        let calendar = Calendar.current
        for _ in 0..<researchLogCount {
            let model = demoModelName
            let prompt = Int.random(in: minPromptTokens...maxPromptTokens)
            let completion = Int.random(in: minCompletionTokens...maxCompletionTokens)
            let latency = Int.random(in: minLatencyMS...maxLatencyMS)
            guard let date = calendar.date(byAdding: .hour, value: -Int.random(in: 1...researchMaxHoursAgo), to: Date()) else { continue }
            var log = LLMCallLog(model: model, promptTokens: prompt, completionTokens: completion,
                                 latencyMS: latency, status: StorageConstants.OperationStatus.success, createdAt: date)
            try log.insert(db)
            var usage = TokenUsage(model: model, promptTokens: prompt, completionTokens: completion, createdAt: date)
            try usage.insert(db)
        }
    }

    // MARK: - 私有辅助方法：文件拷贝

    /// 从应用 Bundle 中物理拷贝演示 file 至 Imports 沙盒，如果不存在则写入 fallback 文本
    /// - Parameters:
    ///   - bundleName: Bundle 中英文文件名
    ///   - localName: 本地化后的物理文件名
    ///   - folder: 目标沙盒 Imports 路径
    ///   - fallbackText: 降级写入的文本
    private static func copyOrWriteDemoFile(bundleName: String, localName: String, to folder: URL, fallbackText: String) -> String {
        let fileURL = folder.appendingPathComponent(localName)

        // 尝试先物理清理旧文件，防止 copyItem 报 FileExists 错误
        try? FileManager.default.removeItem(at: fileURL)

        let expectedPartsCount = 2
        let extensionSeparator: Character = "."
        let fileParts = bundleName.split(separator: extensionSeparator)
        if fileParts.count == expectedPartsCount,
           let resourceName = fileParts.first.map(String.init),
           let resourceExt = fileParts.last.map(String.init),
           let bundleURL = Bundle.main.url(forResource: resourceName, withExtension: resourceExt) {
            do {
                try FileManager.default.copyItem(at: bundleURL, to: fileURL)
                Logger.shared.info("InitialNotebook_CopiedResource: \(localName)")
                return fileURL.absoluteString
            } catch {
                Logger.shared.error("InitialNotebook_CopyFailed: \(localName), error: \(error)")
            }
        }

        // Fallback: 写入硬编码文本
        do {
            try fallbackText.write(to: fileURL, atomically: true, encoding: .utf8)
            Logger.shared.info("InitialNotebook_WroteFallback: \(localName)")
        } catch {
            Logger.shared.error("InitialNotebook_WriteFallbackFailed: \(localName), error: \(error)")
        }
        return fileURL.absoluteString
    }
}
