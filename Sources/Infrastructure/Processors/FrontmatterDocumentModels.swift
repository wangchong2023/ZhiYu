//
//  FrontmatterParser.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/06/21.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1] 基础设施层
//  核心职责：提供 Markdown 纯文本头部 Frontmatter (YAML/JSON 元数据) 剥离及强类型反序列化解析器。
//

import Foundation
import ZhiYuDomain

// MARK: - 1. 主题页面 (Concept) 元数据结构
public struct ConceptFrontmatter: Codable, Sendable {
    public struct OutlineNode: Codable, Identifiable, Sendable {
        public let id: String
        public let title: String
        public let level: Int
        public let associatedPageID: String?
        
        enum CodingKeys: String, CodingKey {
            case id, title, level
            case associatedPageID = "associated_page_id"
        }
    }
    
    public struct SurprisingInsight: Codable, Sendable {
        public let insightTitle: String
        public let linkedConceptID: String
        public let reason: String
        
        enum CodingKeys: String, CodingKey {
            case insightTitle = "insight_title"
            case linkedConceptID = "linked_concept_id"
            case reason
        }
    }
    
    public let outlines: [OutlineNode]?
    public let surprisingInsights: [SurprisingInsight]?
    
    enum CodingKeys: String, CodingKey {
        case outlines
        case surprisingInsights = "surprising_insights"
    }
}

// MARK: - 2. 词条页面 (Entity) 元数据结构
public struct EntityFrontmatter: Codable, Sendable {
    public struct InfoBoxItem: Codable, Sendable {
        public let key: String
        public let value: String
    }
    
    public let pronunciation: String?
    public let definition: String?
    public let aliases: [String]?
    public let infobox: [InfoBoxItem]?
    public let overview: [String]?
}

// MARK: - 3. 来源页面 (Source) 元数据结构
public struct SourceFrontmatter: Codable, Sendable {
    public struct ExtractedPageRef: Codable, Sendable {
        public let pageID: String
        public let name: String
        public let type: String
        
        enum CodingKeys: String, CodingKey {
            case pageID = "page_id"
            case name, type
        }
    }
    
    public let type: String? // "voice" | "ocr" | "file" | "link"
    public let fileName: String?
    public let fileSize: Int64?
    public let voiceAmplitudeWaveform: [Double]?
    public let transcription: String?
    public let extractedPageIDs: [ExtractedPageRef]?
    
    enum CodingKeys: String, CodingKey {
        case type
        case fileName = "file_name"
        case fileSize = "file_size"
        case voiceAmplitudeWaveform = "voice_amplitude_waveform"
        case transcription
        case extractedPageIDs = "extracted_page_ids"
    }
}

// MARK: - 4. 对比页面 (Comparison) 元数据结构
public struct ComparisonFrontmatter: Codable, Sendable {
    public struct ComparisonSubject: Codable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public struct LogoAsset: Codable, Sendable {
            public let lightURL: String?
            public let darkURL: String?
            
            enum CodingKeys: String, CodingKey {
                case lightURL = "light_url"
                case darkURL = "dark_url"
            }
        }
        public let logoAsset: LogoAsset?
        
        enum CodingKeys: String, CodingKey {
            case id, name
            case logoAsset = "logo_asset"
        }
    }
    
    public struct ComparisonDimension: Codable, Identifiable, Sendable {
        public let id: String
        public let name: String
        public let type: String // "text" | "rating" | "range" | "image_list"
        public let unit: String?
    }
    
    public struct MatrixCell: Codable, Sendable {
        public let subjectID: String
        public let dimensionID: String
        public let value: MatrixValue
        
        enum CodingKeys: String, CodingKey {
            case subjectID = "subject_id"
            case dimensionID = "dimension_id"
            case value
        }
    }
    
    public let subjects: [ComparisonSubject]?
    public let dimensions: [ComparisonDimension]?
    public let matrix: [MatrixCell]?
}

/// 灵活存储对比指标的枚举类型
public enum MatrixValue: Codable, Sendable, Equatable {
    case text(String)
    case rating(Double)
    case range(min: Double, max: Double)
    case imageList([String])
    case null
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
            return
        }
        if let str = try? container.decode(String.self) {
            self = .text(str)
            return
        }
        if let dbl = try? container.decode(Double.self) {
            self = .rating(dbl)
            return
        }
        if let arr = try? container.decode([String].self) {
            self = .imageList(arr)
            return
        }
        if let rangeDict = try? container.decode([String: Double].self),
           let min = rangeDict["min"], let max = rangeDict["max"] {
            self = .range(min: min, max: max)
            return
        }
        self = .null
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let str):
            try container.encode(str)
        case .rating(let dbl):
            try container.encode(dbl)
        case .imageList(let arr):
            try container.encode(arr)
        case .range(let min, let max):
            try container.encode([ProcessorConstants.Frontmatter.minKey: min, "max": max])
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - 5. Frontmatter 物理解析核心处理器

/// 通用剥离逻辑已下沉至 ZhiYuDomain，此处 typealias 兼容层维持调用点不变
public typealias FrontmatterParser = ZhiYuDomain.FrontmatterParser
