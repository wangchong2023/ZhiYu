//
//  PromptConstants+AppModels.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：为 ZhiYuDomain.PromptConstants.InferenceDefaults 补充主 App 模型标识扩展。
//

import Foundation
import ZhiYuDomain

public extension ZhiYuDomain.PromptConstants.InferenceDefaults {
    static let defaultTextModel: String = AppModel.gpt4o.rawValue
    static let defaultEmbeddingModel: String = AppModel.appleNLv1.rawValue
}
