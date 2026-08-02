//
//  PromptConstants.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/08/02.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L1.5] 领域层
//  核心职责：大模型 (LLM)、Prompt 提示词、知识合成与 Token 上下文治理专有常量集。
//

import Foundation

/// 针对大模型 (LLM)、Prompt 提示词与 Token 治理的专有领域常量
public enum PromptConstants {
    
    // MARK: - Token 与上下文限制 (Context Window & Tokens)
    public struct TokenLimits {
        /// 字符到 Token 的估算系数 (约 4 字符/Token)
        public static let charactersPerToken: Int = 4

        /// Chat 用户单次发送的最大字符上限 (4000 字符)
        public static let maxUserInputLength: Int = 4000

        /// 知识合成/RAG 多源拼接的最大上下文字符上限 (8000 字符)
        public static let maxSynthesisInputLength: Int = 8000

        /// 标准 AI 对话回复的最大 Token 上下文硬上限 (3072 Token)
        public static let defaultMaxOutputTokens: Int = 3072

        /// 单次 RAG 注入的最大历史会话轮数 (10 轮)
        public static let maxChatHistorySize: Int = 10
    }

    // MARK: - RAG Prompt 提示词上下文注入限制
    public struct RAGPrompt {
        /// 系统提示词中列出的实体最大数量
        public static let maxEntityOverview: Int = 20
        /// 系统提示词中列出的概念最大数量
        public static let maxConceptOverview: Int = 20
        /// 系统提示词中列出的来源最大数量
        public static let maxSourceOverview: Int = 10
        /// 系统提示词中列出的最近更新页面最大数量
        public static let maxRecentOverview: Int = 5
        /// 系统提示词中页面的预览长度
        public static let contentPreviewLength: Int = 100
        /// 查询上下文中包含的最大页面数
        public static let maxContextPages: Int = 10
        /// 查询上下文中每页的预览长度
        public static let contextPreviewLength: Int = 500
    }

    // MARK: - 知识合成调控目标字数 (Synthesis Control Word Count Targets)
    public struct SynthesisWordCount {
        /// 精简提炼 (Concise) 目标字数区间 (300 ~ 500 字)
        public static let conciseMinWords: Int = 300
        public static let conciseMaxWords: Int = 500

        /// 标准深度 (Standard) 目标字数区间 (1000 ~ 1500 字)
        public static let standardMinWords: Int = 1000
        public static let standardMaxWords: Int = 1500

        /// 详尽长文与深度扩写 (Detailed) 目标字数区间 (2500 ~ 4000 字)
        public static let detailedMinWords: Int = 2500
        public static let detailedMaxWords: Int = 4000
    }

    // MARK: - 推理参数默认基准 (Inference Parameter Defaults)
    public struct InferenceDefaults {
        public static let temperature: Double = 0.7
        public static let topP: Double = 0.9
        public static let topK: Int = 40
        public static let defaultTextModel: String = AppModel.gpt4o.rawValue
        public static let defaultEmbeddingModel: String = AppModel.appleNLv1.rawValue
    }

    // MARK: - JSON Schema 结构约束描述 (Structured Output JSON Schemas)
    public struct Schemas {
        /// Quiz 测验题目的标准 JSON Schema 约束描述（强制 LLM 按照结构化 JSON 返回）
        public static let quizJSONSchema: String = """
        {
          "type": "object",
          "properties": {
            "title": { "type": "string", "description": "测验标题" },
            "questions": {
              "type": "array",
              "description": "测验题目列表",
              "items": {
                "type": "object",
                "properties": {
                  "id": { "type": "integer", "description": "题目序号从 1 开始" },
                  "question": { "type": "string", "description": "问题描述" },
                  "options": {
                    "type": "array",
                    "items": { "type": "string" },
                    "description": "选项列表 (至少 2 项)"
                  },
                  "answer": { "type": "integer", "description": "正确选项索引 (从 0 开始)" },
                  "explanation": { "type": "string", "description": "解析说明" }
                },
                "required": ["question", "options", "answer", "explanation"]
              }
            }
          },
          "required": ["questions"]
        }
        """
    }
}
