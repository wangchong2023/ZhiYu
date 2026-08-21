//
//  LLMCoreSupplementTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：补充验证 Infrastructure/LLM 核心服务的未覆盖分支
//          （StreamDeanonymizer 缓冲逻辑、LLMClient SSE 解析、
//            OnDeviceLLMService 工具方法、LLMModels 边界情况）。
//

import XCTest
@testable import ZhiYu

@MainActor
final class LLMCoreSupplementTests: XCTestCase {

    // MARK: - StreamDeanonymizer 缓冲与去匿名化

    /// 验证无占位符的文本直接输出
    func testStreamDeanonymizer_无占位符_直接输出() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        let output = deanon.process(chunk: "这是一段普通文本，没有占位符。")
        XCTAssertEqual(output, "这是一段普通文本，没有占位符。")
    }

    /// 验证占位符被正确还原
    func testStreamDeanonymizer_占位符_正确还原() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        let output = deanon.process(chunk: "你好，[ENTITY_1]今天来了。")
        XCTAssertEqual(output, "你好，张三今天来了。")
    }

    /// 验证非占位符方括号文本直接输出（如 Markdown 链接）
    func testStreamDeanonymizer_Markdown链接_直接输出() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        let output = deanon.process(chunk: "请参考[文档](https://example.com)了解详情。")
        XCTAssertTrue(output.contains("[文档](https://example.com)"), "Markdown 链接应直接输出")
    }

    /// 验证占位符被分包切断时缓存到 buffer
    func testStreamDeanonymizer_占位符切断_缓存到Buffer() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        // 第一块包含未闭合的占位符起始
        let output1 = deanon.process(chunk: "文本[ENTITY_")
        XCTAssertEqual(output1, "文本", "切断前的文本应直接输出")
        // 第二块补全占位符
        let output2 = deanon.process(chunk: "1]来了。")
        XCTAssertEqual(output2, "张三来了。", "补全后应还原占位符")
    }

    /// 验证超过 maxRawLength 的未闭合方括号直接输出不缓存
    func testStreamDeanonymizer_超长未闭合方括号_直接输出() {
        var deanon = StreamDeanonymizer(mapping: [:])
        let longText = "[" + String(repeating: "A", count: LLMConstants.EntityPlaceholder.maxRawLength + 5)
        let output = deanon.process(chunk: longText)
        XCTAssertEqual(output, longText, "超过 maxRawLength 的未闭合方括号应直接输出")
    }

    /// 验证 mapping 中不存在的占位符直接输出原文
    func testStreamDeanonymizer_未知占位符_直接输出原文() {
        var deanon = StreamDeanonymizer(mapping: [:])
        let output = deanon.process(chunk: "未知[ENTITY_999]占位符。")
        XCTAssertTrue(output.contains("[ENTITY_999]"), "未知占位符应直接输出原文")
    }

    /// 验证 finalize 返回 buffer 中剩余内容
    func testStreamDeanonymizer_finalize_返回剩余Buffer() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_1]": "张三"])
        _ = deanon.process(chunk: "文本[ENTITY_")
        let remaining = deanon.finalize()
        XCTAssertEqual(remaining, "[ENTITY_", "finalize 应返回 buffer 中剩余内容")
    }

    /// 验证空 chunk 处理
    func testStreamDeanonymizer_空Chunk_返回空() {
        var deanon = StreamDeanonymizer(mapping: [:])
        let output = deanon.process(chunk: "")
        XCTAssertEqual(output, "")
    }

    /// 验证多个占位符同时还原
    func testStreamDeanonymizer_多占位符_同时还原() {
        var deanon = StreamDeanonymizer(mapping: [
            "[ENTITY_1]": "张三",
            "[ENTITY_2]": "李四"
        ])
        let output = deanon.process(chunk: "[ENTITY_1]和[ENTITY_2]一起来了。")
        XCTAssertEqual(output, "张三和李四一起来了。")
    }

    // MARK: - LLMClient SSE 解析静态方法

    /// 验证 extractDataString 从 "data: " 前缀提取内容
    func testExtractDataString_标准前缀_提取内容() {
        let result = SSEParser.extractDataString(from: "data: {\"content\":\"hello\"}")
        XCTAssertEqual(result, "{\"content\":\"hello\"}")
    }

    /// 验证 extractDataString 从 "data:" 前缀提取内容（无空格变体）
    func testExtractDataString_无空格前缀_提取内容() {
        let result = SSEParser.extractDataString(from: "data:{\"content\":\"hello\"}")
        XCTAssertEqual(result, "{\"content\":\"hello\"}")
    }

    /// 验证 extractDataString 非 data 行返回 nil
    func testExtractDataString_非Data行_返回Nil() {
        let result = SSEParser.extractDataString(from: ": comment line")
        XCTAssertNil(result)
    }

    /// 验证 extractDataString 空行返回 nil
    func testExtractDataString_空行_返回Nil() {
        let result = SSEParser.extractDataString(from: "")
        XCTAssertNil(result)
    }

    /// 验证 parseJSONLine 有效 JSON 返回字典
    func testParseJSONLine_有效JSON_返回字典() {
        let json = SSEParser.parseJSONLine("{\"key\":\"value\"}", logger: nil)
        XCTAssertEqual(json?["key"] as? String, "value")
    }

    /// 验证 parseJSONLine 无效 JSON 返回 nil
    func testParseJSONLine_无效JSON_返回Nil() {
        let json = SSEParser.parseJSONLine("not json", logger: nil)
        XCTAssertNil(json)
    }

    /// 验证 parseJSONLine 空字符串返回 nil
    func testParseJSONLine_空字符串_返回Nil() {
        let json = SSEParser.parseJSONLine("", logger: nil)
        XCTAssertNil(json)
    }

    /// 验证 extractContent 从 delta 结构提取 content
    func testExtractContent_delta结构_提取Content() {
        let json: [String: Any] = [
            "choices": [["delta": ["content": "hello world"]]]
        ]
        let content = SSEParser.extractContent(from: json)
        XCTAssertEqual(content, "hello world")
    }

    /// 验证 extractContent 从 delta 结构提取 reasoning_content（content 不存在时）
    func testExtractContent_delta结构_提取ReasoningContent() {
        let json: [String: Any] = [
            "choices": [["delta": ["reasoning_content": "思考中"]]]
        ]
        let content = SSEParser.extractContent(from: json)
        XCTAssertEqual(content, "思考中")
    }

    /// 验证 extractContent 从 message 结构提取 content
    func testExtractContent_message结构_提取Content() {
        let json: [String: Any] = [
            "choices": [["message": ["content": "完整回复"]]]
        ]
        let content = SSEParser.extractContent(from: json)
        XCTAssertEqual(content, "完整回复")
    }

    /// 验证 extractContent 无 choices 返回 nil
    func testExtractContent_无Choices_返回Nil() {
        let json: [String: Any] = ["error": "something"]
        let content = SSEParser.extractContent(from: json)
        XCTAssertNil(content)
    }

    /// 验证 extractContent 空 choices 数组返回 nil
    func testExtractContent_空Choices数组_返回Nil() {
        let json: [String: Any] = ["choices": []]
        let content = SSEParser.extractContent(from: json)
        XCTAssertNil(content)
    }

    /// 验证 extractContent delta 中无 content 和 reasoning_content 返回 nil
    func testExtractContent_delta无Content_返回Nil() {
        let json: [String: Any] = [
            "choices": [["delta": ["role": "assistant"]]]
        ]
        let content = SSEParser.extractContent(from: json)
        XCTAssertNil(content)
    }

    // MARK: - OnDeviceLLMService 工具方法

    /// 验证 OnDeviceLLMService.Config 常量值
    func testOnDeviceLLMService_Config常量值() {
        XCTAssertEqual(OnDeviceLLMService.Config.defaultMaxTokens, 256)
        XCTAssertEqual(OnDeviceLLMService.Config.titleHitWeight, 3)
        XCTAssertEqual(OnDeviceLLMService.Config.tagHitWeight, 2)
        XCTAssertEqual(OnDeviceLLMService.Config.contentHitWeight, 1)
        XCTAssertEqual(OnDeviceLLMService.Config.minTokenLength, 2)
    }

    /// 验证 cancelGeneration 重置状态
    func testOnDeviceLLMService_cancelGeneration_重置状态() {
        let service = OnDeviceLLMService()
        service.cancelGeneration()
        XCTAssertFalse(service.isGenerating)
        XCTAssertEqual(service.generatedText, "")
        XCTAssertEqual(service.generationProgress, 0)
    }

    /// 验证 unloadModel 不崩溃
    func testOnDeviceLLMService_unloadModel_不崩溃() {
        let service = OnDeviceLLMService()
        service.unloadModel()
        XCTAssertFalse(service.isModelLoaded)
    }

    /// 验证 discoverModels 返回数组（不崩溃）
    func testOnDeviceLLMService_discoverModels_返回数组() {
        let service = OnDeviceLLMService()
        let models = service.discoverModels()
        XCTAssertNotNil(models)
    }

    /// 验证 availableModels 属性可访问
    func testOnDeviceLLMService_availableModels_可访问() {
        let service = OnDeviceLLMService()
        XCTAssertNotNil(service.availableModels)
    }

    /// 验证 selectedModelID 属性可读写
    func testOnDeviceLLMService_selectedModelID_可读写() {
        let service = OnDeviceLLMService()
        service.selectedModelID = "test-model-id"
        XCTAssertEqual(service.selectedModelID, "test-model-id")
    }

    /// 验证 extractTags 从文本中提取标签
    func testOnDeviceLLMService_extractTags_从文本提取标签() {
        let service = OnDeviceLLMService()
        let tags = service.extractTags(from: "这是一段文本 #标签1 #标签2")
        XCTAssertTrue(tags.contains("标签1"))
        XCTAssertTrue(tags.contains("标签2"))
    }

    /// 验证 extractTags 无标签返回空数组
    func testOnDeviceLLMService_extractTags_无标签_返回空() {
        let service = OnDeviceLLMService()
        let tags = service.extractTags(from: "这是一段没有标签的文本")
        XCTAssertTrue(tags.isEmpty)
    }

    /// 验证 extractTags 空字符串返回空数组
    func testOnDeviceLLMService_extractTags_空字符串_返回空() {
        let service = OnDeviceLLMService()
        let tags = service.extractTags(from: "")
        XCTAssertTrue(tags.isEmpty)
    }

    // MARK: - LLMModels 边界情况

    /// 验证 LLMProvider.custom 的 validateAPIKeyFormat 空格键返回 invalid
    func testLLMProvider_custom_validateAPIKeyFormat_空格键_invalid() {
        let result = LLMProvider.custom.validateAPIKeyFormat("   ")
        XCTAssertFalse(result.isValid)
    }

    /// 验证 LLMProvider.custom 的 validateAPIKeyFormat 任意非空键返回 valid
    func testLLMProvider_custom_validateAPIKeyFormat_任意非空键_valid() {
        let result = LLMProvider.custom.validateAPIKeyFormat("any-key")
        XCTAssertTrue(result.isValid)
        XCTAssertNil(result.message)
    }

    /// 验证 LLMProvider.deepSeek 的 validateAPIKeyFormat 正确前缀且足够长返回 valid
    func testLLMProvider_deepSeek_validateAPIKeyFormat_正确前缀_valid() {
        let result = LLMProvider.deepSeek.validateAPIKeyFormat("sk-1234567890abcdef1234567890abcdef")
        XCTAssertTrue(result.isValid)
    }

    /// 验证 LLMProvider.deepSeek 的 validateAPIKeyFormat 错误前缀返回 invalid
    func testLLMProvider_deepSeek_validateAPIKeyFormat_错误前缀_invalid() {
        let result = LLMProvider.deepSeek.validateAPIKeyFormat("wrong-prefix-1234567890abcdef")
        XCTAssertFalse(result.isValid)
    }

    /// 验证 LLMProvider.deepSeek 的 validateAPIKeyFormat 太短返回 invalid
    func testLLMProvider_deepSeek_validateAPIKeyFormat_太短_invalid() {
        let result = LLMProvider.deepSeek.validateAPIKeyFormat("sk-short")
        XCTAssertFalse(result.isValid)
    }

    /// 验证 LLMProvider.icon 属性非空
    func testLLMProvider_icon_非空() {
        for provider in LLMProvider.allCases {
            XCTAssertFalse(provider.icon.isEmpty, "\(provider) 的 icon 不应为空")
        }
    }

    /// 验证 LLMProvider.defaultModel 属性可访问
    func testLLMProvider_defaultModel_可访问() {
        XCTAssertFalse(LLMProvider.deepSeek.defaultModel.isEmpty)
    }

    /// 验证 LLMProvider.suggestedModels 属性可访问
    func testLLMProvider_suggestedModels_可访问() {
        XCTAssertFalse(LLMProvider.deepSeek.suggestedModels.isEmpty)
    }

    // MARK: - LLMConstants 常量验证

    /// 验证 LLMConstants SSEStream 常量
    func testLLMConstants_SSEStream常量() {
        XCTAssertEqual(LLMConstants.SSEStream.doneMarker, "[DONE]")
        XCTAssertEqual(LLMConstants.SSEStream.dataPrefix, "data: ")
        XCTAssertEqual(LLMConstants.SSEStream.dataPrefixNoSpace, "data:")
    }

    /// 验证 LLMConstants Anonymization 常量
    func testLLMConstants_Anonymization常量() {
        XCTAssertEqual(LLMConstants.Anonymization.placeholderPrefix, "[ENTITY_")
    }

    /// 验证 LLMConstants EntityPlaceholder maxRawLength
    func testLLMConstants_EntityPlaceholder_maxRawLength() {
        XCTAssertEqual(LLMConstants.EntityPlaceholder.maxRawLength, 25)
    }

    /// 验证 LLMConstants ContextCompression 常量
    func testLLMConstants_ContextCompression常量() {
        XCTAssertEqual(LLMConstants.ContextCompression.summaryScoreThreshold, 0.8)
        XCTAssertEqual(LLMConstants.ContextCompression.overflowTolerance, 500)
    }

    /// 验证 LLMConstants LogPreview 常量
    func testLLMConstants_LogPreview常量() {
        XCTAssertEqual(LLMConstants.LogPreview.maxDiagnosticLines, 15)
        XCTAssertEqual(LLMConstants.LogPreview.diagnosticLineLength, 250)
        XCTAssertEqual(LLMConstants.LogPreview.sseNonJsonLength, 120)
    }
}
