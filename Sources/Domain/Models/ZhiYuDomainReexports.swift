//
//  ZhiYuDomainReexports.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/11/25.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：将已物理下沉至 ZhiYuDomain SPM 包的纯领域模型与常量向主 App 及 Watch Target 零侵入透传。
//

import ZhiYuDomain

public typealias SearchConstants = ZhiYuDomain.SearchConstants
public typealias DomainThresholds = ZhiYuDomain.DomainThresholds
public typealias ChunkType = ZhiYuDomain.ChunkType
public typealias PotentialLinkSuggestion = ZhiYuDomain.PotentialLinkSuggestion
public typealias LintIssue = ZhiYuDomain.LintIssue
public typealias SearchDiagnosticInfo = ZhiYuDomain.SearchDiagnosticInfo
public typealias IngestPipelineConstants = ZhiYuDomain.IngestPipelineConstants
public typealias RAGEvalConstants = ZhiYuDomain.RAGEvalConstants
public typealias SyncConstants = ZhiYuDomain.SyncConstants
public typealias AITaskMetadata = ZhiYuDomain.AITaskMetadata
public typealias AITaskProgressState = ZhiYuDomain.AITaskProgressState
public typealias PageLink = ZhiYuDomain.PageLink
public typealias KnowledgeSource = ZhiYuDomain.KnowledgeSource
public typealias GraphConstants = ZhiYuDomain.GraphConstants
public typealias KnowledgePageFTS = ZhiYuDomain.KnowledgePageFTS
public typealias PluginRecordFTS = ZhiYuDomain.PluginRecordFTS
public typealias AgentTool = ZhiYuDomain.AgentTool
public typealias PluginRecord = ZhiYuDomain.PluginRecord
public typealias ToolItem = ZhiYuDomain.ToolItem
public typealias PromptConstants = ZhiYuDomain.PromptConstants
public typealias MemoryEngineType = ZhiYuDomain.MemoryEngineType
public typealias PlanQuotasVo = ZhiYuDomain.PlanQuotasVo
public typealias SubscriptionQuotaConstants = ZhiYuDomain.SubscriptionQuotaConstants
public typealias ProcessorConstants = ZhiYuDomain.ProcessorConstants
public typealias LineIterationHelpers = ZhiYuDomain.LineIterationHelpers
public typealias MermaidSanitizer = ZhiYuDomain.MermaidSanitizer
public typealias WikiLinkMatch = ZhiYuDomain.WikiLinkMatch
public typealias WikiLinkExtractor = ZhiYuDomain.WikiLinkExtractor
public typealias ThinkingProcessor = ZhiYuDomain.ThinkingProcessor
public typealias ConceptFrontmatter = ZhiYuDomain.ConceptFrontmatter
public typealias EntityFrontmatter = ZhiYuDomain.EntityFrontmatter
public typealias SourceFrontmatter = ZhiYuDomain.SourceFrontmatter
public typealias ComparisonFrontmatter = ZhiYuDomain.ComparisonFrontmatter
public typealias MatrixValue = ZhiYuDomain.MatrixValue
public typealias FrontmatterParser = ZhiYuDomain.FrontmatterParser
public typealias IngestProgressCalculator = ZhiYuDomain.IngestProgressCalculator
public typealias PageContentUtility = ZhiYuDomain.PageContentUtility
public typealias TextChunkerProcessor = ZhiYuDomain.TextChunkerProcessor
public typealias OOXMLParserBase = ZhiYuDomain.OOXMLParserBase
public typealias XMLParserLauncher = ZhiYuDomain.XMLParserLauncher
public typealias DocxProcessor = ZhiYuDomain.DocxProcessor
public typealias ExcelProcessor = ZhiYuDomain.ExcelProcessor
public typealias XlsxSharedStringsParser = ZhiYuDomain.XlsxSharedStringsParser
public typealias SwiftMarkdownASTCleaner = ZhiYuDomain.SwiftMarkdownASTCleaner
public typealias MarkdownProcessor = ZhiYuDomain.MarkdownProcessor
