//
//  PageSchema.swift
//  ZhiYuDomain
//
//  系统层级：[L1.5] 领域层（ZhiYuDomain SPM 包）
//  核心职责：定义页面模板（PageSchema）的领域模型，约束页面类型、必填字段及默认模板内容。
//           纯 Foundation 模型，无 L10n / UI 依赖。
//

import Foundation

/// 页面 Schema：定义特定类型页面必须包含的内容结构
public struct PageSchema: Codable, Sendable {
    public let type: PageType
    public let requiredFields: [String]
    public let template: String
    public let promptInstruction: String

    public init(type: PageType, requiredFields: [String], template: String, promptInstruction: String) {
        self.type = type
        self.requiredFields = requiredFields
        self.template = template
        self.promptInstruction = promptInstruction
    }
}
