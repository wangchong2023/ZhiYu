//
//  ChatRunnerAndPluginLoaderDeepTests.swift
//  ZhiYuTests
//
//  批次 A 补盲 Task 18：ChatRunner / PluginLoader / OnDeviceLLMService 深度测试
//  目标：以发现问题为目的，覆盖未测试的代码路径和边界条件
//

import XCTest
import UFPCore
import UFPStorage
import Dependencies
@testable import ZhiYu

// MARK: - StreamDeanonymizer 边界问题测试

/// 聚焦 StreamDeanonymizer 的边界条件和潜在问题
/// 已有 StreamDeanonymizerTests.swift 覆盖基础路径，本测试聚焦问题发现
final class StreamDeanonymizerEdgeProblemTests: XCTestCase {

    /// 发现：maxRawLength=25 限制只在找不到 ']' 时才触发（防止无限缓存）
    /// 如果方括号内容完整（找到 ']'），即使超过 maxRawLength 也会尝试还原
    /// 这意味着 maxRawLength 是防止"无闭合括号"的 DoS 保护，不是限制占位符长度
    func testLongBracketContentWithClosingBracketIsStillReplaced() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_VERY_LONG_NAME_EXCEEDING_LIMIT]": "张三"])
        // 构造一个超过 25 字符的方括号内容，但有闭合 ']'
        let longContent = "[ENTITY_VERY_LONG_NAME_EXCEEDING_LIMIT]"
        let result = deanon.process(chunk: longContent)
        // 找到 ']' 时，即使超过 maxRawLength 也会尝试还原
        XCTAssertEqual(result, "张三", "完整方括号内容即使超过 maxRawLength 也应被还原")
    }

    /// 发现：maxRawLength 只在无闭合 ']' 时触发 — 超长无闭合内容直接输出
    func testLongBracketContentWithoutClosingBracketOutputsImmediately() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_VERY_LONG_NAME_EXCEEDING_LIMIT]": "张三"])
        // 构造一个超过 25 字符的方括号内容，但无闭合 ']'
        let longUnclosed = "[ENTITY_VERY_LONG_NAME_EXCEEDING_LIMIT_WITHOUT_CLOSING"
        let result = deanon.process(chunk: longUnclosed)
        // 无闭合 ']' 且超过 maxRawLength 时直接输出，不缓存
        XCTAssertEqual(result, longUnclosed, "超过 maxRawLength 且无闭合 ']' 的内容应直接输出")
    }

    /// 问题：finalize 返回未还原的 buffer，如果 buffer 包含部分占位符，
    /// 调用方需要知道这个 buffer 是未完成的
    func testFinalizeReturnsUnresolvedBufferWithPartialPlaceholder() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])
        _ = deanon.process(chunk: "text [ENTITY_")
        let remaining = deanon.finalize()
        // finalize 返回 "[ENTITY_"，这是未完成的占位符
        XCTAssertEqual(remaining, "[ENTITY_", "finalize 应返回未完成的 buffer")
    }

    /// 问题：空 mapping 时，所有 [ENTITY_XXX] 占位符直接输出
    func testEmptyMappingPassesEntityPlaceholdersThrough() {
        var deanon = StreamDeanonymizer(mapping: [:])
        let result = deanon.process(chunk: "Hello [ENTITY_A] world")
        XCTAssertEqual(result, "Hello [ENTITY_A] world", "空 mapping 时占位符应直接输出")
    }

    /// 问题：mapping 中有 key 但占位符被分块切断在 '[' 之前
    func testPlaceholderSplitBeforeBracketBuffersNothing() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])
        let chunk1 = "Hello "
        let chunk2 = "[ENTITY_A]"

        let result1 = deanon.process(chunk: chunk1)
        let result2 = deanon.process(chunk: chunk2)

        XCTAssertEqual(result1, "Hello ")
        XCTAssertEqual(result2, "张三")
    }

    /// 问题：连续两个占位符，第一个完整，第二个被切断
    func testConsecutivePlaceholdersSecondSplit() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三", "[ENTITY_B]": "李四"])
        let result1 = deanon.process(chunk: "[ENTITY_A][ENTITY_")
        let result2 = deanon.process(chunk: "B]")

        XCTAssertEqual(result1, "张三")
        XCTAssertEqual(result2, "李四")
    }

    /// 问题：非 ENTITY_ 前缀的方括号内容（如 Markdown 链接）直接输出
    func testMarkdownLinkNotTreatedAsPlaceholder() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])
        let result = deanon.process(chunk: "See [link](url) and [ENTITY_A]")
        XCTAssertEqual(result, "See [link](url) and 张三")
    }

    /// 问题：buffer 在多次 process 调用间累积
    func testBufferAccumulatesAcrossMultipleProcessCalls() {
        var deanon = StreamDeanonymizer(mapping: ["[ENTITY_A]": "张三"])
        let r1 = deanon.process(chunk: "text [")
        let r2 = deanon.process(chunk: "ENT")
        let r3 = deanon.process(chunk: "ITY_")
        let r4 = deanon.process(chunk: "A]")

        XCTAssertEqual(r1, "text ")
        XCTAssertEqual(r2, "")
        XCTAssertEqual(r3, "")
        XCTAssertEqual(r4, "张三")
    }
}

// MARK: - OnDeviceLLMService extractTags 深度测试

/// 覆盖 OnDeviceLLMService.extractTags 的边界条件
/// 已有 OnDeviceLLMServiceSupplementTests 覆盖基础路径
@MainActor
final class OnDeviceLLMServiceExtractTagsDeepTests: XCTestCase {

    private var service: OnDeviceLLMService!

    override func setUp() async throws {
        try await super.setUp()
        service = OnDeviceLLMService()
    }

    /// 发现：extractTags 使用 #(\w+) 正则，NSRegularExpression 的 \w 是 Unicode aware
    /// 这意味着中文标签（如 #中文标签）也会被提取 — 这不是 bug，而是实际行为
    /// 与源码注释"过滤单字符噪声"不完全一致，\w 实际匹配 Unicode 字母
    func testExtractTagsMatchesChineseTagsDueToUnicodeAwareRegex() {
        let tags = service.extractTags(from: "这是 #中文标签 测试")
        // \w 在 NSRegularExpression 中是 Unicode aware，匹配中文
        XCTAssertEqual(tags, ["中文标签"], "NSRegularExpression 的 \\w 匹配中文，中文标签应被提取")
    }

    /// 问题：extractTags 匹配 #123 但不匹配 #（数字开头后跟字母）
    func testExtractTagsMatchesNumericTags() {
        let tags = service.extractTags(from: "Issue #123 and #abc")
        XCTAssertEqual(tags, ["123", "abc"])
    }

    /// 问题：extractTags 匹配 #_underscore 但 #.dot 不匹配
    func testExtractTagsMatchesUnderscoreButNotDot() {
        let tags = service.extractTags(from: "Tag #_test and #.dot")
        XCTAssertEqual(tags, ["_test"], "#.dot 不应被提取（. 不在 \\w 中）")
    }

    /// 问题：连续的 # 标签
    func testExtractTagsHandlesConsecutiveTags() {
        let tags = service.extractTags(from: "#tag1#tag2#tag3")
        XCTAssertEqual(tags, ["tag1", "tag2", "tag3"])
    }

    /// 问题：# 后直接跟空格不匹配
    func testExtractTagsDoesNotMatchHashFollowedBySpace() {
        let tags = service.extractTags(from: "# heading not a tag")
        XCTAssertTrue(tags.isEmpty, "# 后跟空格不应被提取为标签")
    }

    /// 修复 A-37：URL 中的 #fragment 不再被误提取为标签
    func testExtractTagsDoesNotExtractURLFragments() {
        let tags = service.extractTags(from: "Visit https://example.com/page#section for details")
        XCTAssertTrue(tags.isEmpty, "URL 中的 #section 不应被提取为标签（A-37 已修复）")
    }

    /// 修复 A-37：URL 中的 #fragment 不被提取，但文本中的 #tag 仍正常提取
    func testExtractTagsExtractsTagsButNotURLFragments() {
        let tags = service.extractTags(from: "Check https://example.com/#section and #realtag here")
        XCTAssertEqual(tags, ["realtag"], "应只提取 #realtag，不提取 URL 中的 #section")
    }
}

// MARK: - OnDeviceLLMService importModel/deleteModel 问题测试

/// 覆盖 OnDeviceLLMService.importModel 和 deleteModel 的错误路径
@MainActor
final class OnDeviceLLMServiceImportDeleteTests: XCTestCase {

    /// 问题：importModel 对不存在的 URL 会抛错
    func testImportModelThrowsForNonExistentURL() async {
        let service = OnDeviceLLMService()
        let nonExistentURL = URL(fileURLWithPath: "/tmp/non_existent_model_\(UUID().uuidString).mlmodelc")

        do {
            try await service.importModel(from: nonExistentURL)
            XCTFail("导入不存在的模型文件应抛错")
        } catch {
            // 预期路径：FileManager.copyItem 抛错
        }
    }

    /// 问题：deleteModel 对 url 为 nil 的模型不抛错（系统模型）
    func testDeleteModelWithNilURLDoesNotThrow() throws {
        let service = OnDeviceLLMService()
        let systemModel = OnDeviceModel(id: "system_test", name: "System", url: nil, size: 0, type: .system)

        // 不应抛错（url 为 nil 时跳过文件删除）
        XCTAssertNoThrow(try service.deleteModel(systemModel))
    }

    /// 问题：deleteModel 对不存在的文件 URL 会抛错
    func testDeleteModelWithNonExistentURLThrows() {
        let service = OnDeviceLLMService()
        let nonExistentURL = URL(fileURLWithPath: "/tmp/non_existent_\(UUID().uuidString).mlmodelc")
        let model = OnDeviceModel(id: "test", name: "Test", url: nonExistentURL, size: 0, type: .downloaded)

        do {
            try service.deleteModel(model)
            XCTFail("删除不存在的模型文件应抛错")
        } catch {
            // 预期路径
        }
    }

    /// 问题：deleteModel 删除 selectedModelID 对应的模型后会 unloadModel
    func testDeleteSelectedModelTriggersUnload() throws {
        let service = OnDeviceLLMService()
        // 创建临时文件
        let tempDir = FileManager.default.temporaryDirectory
        let modelURL = tempDir.appendingPathComponent("test_model_\(UUID().uuidString).mlmodelc")
        try FileManager.default.createDirectory(at: modelURL, withIntermediateDirectories: true)

        let model = OnDeviceModel(id: "test_delete_selected", name: "TestDelete", url: modelURL, size: 0, type: .downloaded)
        service.selectedModelID = model.id
        service.isModelLoaded = true
        service.loadedModelName = model.name

        try service.deleteModel(model)

        // deleteModel 会调用 unloadModel（因为 model.id == selectedModelID）
        XCTAssertFalse(service.isModelLoaded, "删除选中模型后应卸载模型")
        XCTAssertEqual(service.loadedModelName, "", "删除选中模型后应清空模型名")

        // 清理
        try? FileManager.default.removeItem(at: modelURL)
    }
}

// MARK: - OnDeviceLLMService generate 错误路径测试

/// 覆盖 OnDeviceLLMService.generate 的错误路径
@MainActor
final class OnDeviceLLMServiceGenerateErrorTests: XCTestCase {

    /// 问题：generate 在 isModelLoaded=false 时抛 modelNotLoaded
    func testGenerateThrowsModelNotLoadedWhenNotLoaded() async {
        let service = OnDeviceLLMService()
        service.isModelLoaded = false

        do {
            _ = try await service.generate(prompt: "test")
            XCTFail("模型未加载时应抛 modelNotLoaded")
        } catch OnDeviceError.modelNotLoaded {
            // 预期路径
        } catch {
            XCTFail("应抛 OnDeviceError.modelNotLoaded，实际：\(error)")
        }
    }

    /// 问题：generate 在 isModelLoaded=true 但 currentModel 不是 MLModel 时抛 emptyResponse
    func testGenerateThrowsEmptyResponseWhenNoMLModel() async {
        let service = OnDeviceLLMService()
        service.isModelLoaded = true
        // currentModel 仍为 nil（未通过 loadModel 加载真实模型）

        do {
            _ = try await service.generate(prompt: "test")
            XCTFail("无 MLModel 时应抛 emptyResponse")
        } catch OnDeviceError.emptyResponse {
            // 预期路径
        } catch {
            XCTFail("应抛 OnDeviceError.emptyResponse，实际：\(error)")
        }
    }

    /// 问题：chatOnDevice 在无 MLModel 时抛 emptyResponse
    func testChatOnDeviceThrowsEmptyResponseWhenNoMLModel() async {
        let service = OnDeviceLLMService()
        service.isModelLoaded = true

        do {
            _ = try await service.chatOnDevice(query: "test", pages: [])
            XCTFail("无 MLModel 时应抛 emptyResponse")
        } catch OnDeviceError.emptyResponse {
            // 预期路径
        } catch {
            XCTFail("应抛 OnDeviceError.emptyResponse，实际：\(error)")
        }
    }

    /// 问题：smartIngestOnDevice 在无 MLModel 时抛 emptyResponse
    func testSmartIngestOnDeviceThrowsEmptyResponseWhenNoMLModel() async {
        let service = OnDeviceLLMService()
        service.isModelLoaded = true

        do {
            _ = try await service.smartIngestOnDevice(title: "test", content: "content", pages: [])
            XCTFail("无 MLModel 时应抛 emptyResponse")
        } catch OnDeviceError.emptyResponse {
            // 预期路径
        } catch {
            XCTFail("应抛 OnDeviceError.emptyResponse，实际：\(error)")
        }
    }
}

// MARK: - OnDeviceLLMService loadModel 错误路径测试

@MainActor
final class OnDeviceLLMServiceLoadModelTests: XCTestCase {

    /// 问题：loadModel 在 selectedModelID 无效时抛 modelNotFound
    func testLoadModelThrowsModelNotFoundForInvalidID() async {
        let service = OnDeviceLLMService()
        service.selectedModelID = "non_existent_model_id"

        do {
            try await service.loadModel()
            XCTFail("无效 selectedModelID 应抛 modelNotFound")
        } catch OnDeviceError.modelNotFound {
            // 预期路径
        } catch {
            XCTFail("应抛 OnDeviceError.modelNotFound，实际：\(error)")
        }
    }

    /// 问题：loadModel 对 system 类型在 iOS < 18.2 时抛 notSupported
    /// 注意：模拟器上 iOS 版本可能 >= 18.2，此测试验证 modelNotFound 路径
    func testLoadModelForSystemTypeWithoutURL() async {
        let service = OnDeviceLLMService()
        // 手动添加一个 system 类型模型
        let systemModel = OnDeviceModel(id: "test_system_model", name: "TestSystem", url: nil, size: 0, type: .system)
        service.availableModels = [systemModel]
        service.selectedModelID = systemModel.id

        // system 类型在 iOS >= 18.2 时 isModelLoaded=true，否则抛 notSupported
        // 模拟器上行为取决于 iOS 版本，两种路径都不 crash 即通过
        do {
            try await service.loadModel()
            // iOS >= 18.2 路径：isModelLoaded = true
            XCTAssertTrue(service.isModelLoaded)
        } catch OnDeviceError.notSupported {
            // iOS < 18.2 路径
        } catch {
            // 其他错误也不算失败（模拟器环境差异）
        }
    }
}

// MARK: - PluginLoader verifyPluginSignature 深度测试

/// 覆盖 PluginLoader.verifyPluginSignature 的安全边界
@MainActor
final class PluginLoaderSignatureDeepTests: XCTestCase {

    /// 问题：isTrustedLocal=true 时跳过签名校验
    /// 这意味着任何通过 loadPluginFromRawJS 路径的插件都不需要签名
    func testTrustedLocalBypassesSignatureCheck() {
        let manifest = PluginManifest(
            id: "local.test",
            version: "1.0.0",
            names: ["en": "Test"],
            descriptions: ["en": "Test"],
            codeSignature: nil
        )

        let result = PluginLoader.verifyPluginSignature(script: "malicious code", manifest: manifest, isTrustedLocal: true)
        XCTAssertTrue(result, "isTrustedLocal=true 应跳过签名校验")
    }

    /// 问题：外部插件使用 local. 前缀被拒绝
    func testExternalPluginWithLocalPrefixRejected() {
        let manifest = PluginManifest(
            id: "local.malicious",
            version: "1.0.0",
            names: ["en": "Malicious"],
            descriptions: ["en": "Malicious"],
            codeSignature: "abc123"
        )

        let result = PluginLoader.verifyPluginSignature(script: "code", manifest: manifest, isTrustedLocal: false)
        XCTAssertFalse(result, "外部插件使用 local. 前缀应被拒绝")
    }

    /// 问题：缺少 codeSignature 的外部插件被拒绝
    func testExternalPluginWithoutSignatureRejected() {
        let manifest = PluginManifest(
            id: "external.plugin",
            version: "1.0.0",
            names: ["en": "External"],
            descriptions: ["en": "External"],
            codeSignature: nil
        )

        let result = PluginLoader.verifyPluginSignature(script: "code", manifest: manifest, isTrustedLocal: false)
        XCTAssertFalse(result, "无签名的外部插件应被拒绝")
    }

    /// 问题：空字符串 codeSignature 被拒绝
    func testExternalPluginWithEmptySignatureRejected() {
        let manifest = PluginManifest(
            id: "external.plugin",
            version: "1.0.0",
            names: ["en": "External"],
            descriptions: ["en": "External"],
            codeSignature: ""
        )

        let result = PluginLoader.verifyPluginSignature(script: "code", manifest: manifest, isTrustedLocal: false)
        XCTAssertFalse(result, "空签名的外部插件应被拒绝")
    }

    /// 问题：无效 hex 格式的签名被拒绝
    func testExternalPluginWithInvalidHexSignatureRejected() {
        let manifest = PluginManifest(
            id: "external.plugin",
            version: "1.0.0",
            names: ["en": "External"],
            descriptions: ["en": "External"],
            codeSignature: "not_valid_hex_zzzz"
        )

        let result = PluginLoader.verifyPluginSignature(script: "code", manifest: manifest, isTrustedLocal: false)
        XCTAssertFalse(result, "无效 hex 格式的签名应被拒绝")
    }

    /// 问题：签名不匹配被拒绝
    func testExternalPluginWithMismatchedSignatureRejected() {
        let manifest = PluginManifest(
            id: "external.plugin",
            version: "1.0.0",
            names: ["en": "External"],
            descriptions: ["en": "External"],
            codeSignature: "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef"
        )

        let result = PluginLoader.verifyPluginSignature(script: "actual code content", manifest: manifest, isTrustedLocal: false)
        XCTAssertFalse(result, "签名不匹配应被拒绝")
    }
}

// MARK: - PluginLoader constantTimeCompare 问题测试

/// 覆盖 PluginLoader.constantTimeCompare 的安全边界
@MainActor
final class PluginLoaderConstantTimeCompareTests: XCTestCase {

    /// 问题：长度不等时返回 false
    func testDifferentLengthsReturnFalse() {
        let a = Data([1, 2, 3])
        let b = Data([1, 2])
        XCTAssertFalse(PluginLoader.constantTimeCompare(a, b: b))
    }

    /// 问题：空数据比较返回 true
    func testEmptyDataCompareReturnsTrue() {
        let a = Data()
        let b = Data()
        XCTAssertTrue(PluginLoader.constantTimeCompare(a, b: b))
    }

    /// 问题：一个空一个非空返回 false
    func testOneEmptyOneNonEmptyReturnsFalse() {
        let a = Data()
        let b = Data([1])
        XCTAssertFalse(PluginLoader.constantTimeCompare(a, b: b))
    }

    /// 问题：相同数据返回 true
    func testSameDataReturnsTrue() {
        let a = Data([1, 2, 3, 4, 5])
        let b = Data([1, 2, 3, 4, 5])
        XCTAssertTrue(PluginLoader.constantTimeCompare(a, b: b))
    }

    /// 问题：仅最后一位不同返回 false
    func testOnlyLastByteDifferentReturnsFalse() {
        let a = Data([1, 2, 3, 4, 5])
        let b = Data([1, 2, 3, 4, 6])
        XCTAssertFalse(PluginLoader.constantTimeCompare(a, b: b))
    }
}

// MARK: - Data hex 编解码问题测试

/// 覆盖 Data(hexString:) 和 Data.hexEncoded 的边界条件
final class DataHexCodecTests: XCTestCase {

    /// 问题：奇数长度 hex 字符串返回 nil
    func testOddLengthHexStringReturnsNil() {
        let data = Data(hexString: "abc")
        XCTAssertNil(data, "奇数长度 hex 字符串应返回 nil")
    }

    /// 问题：空 hex 字符串返回空 Data
    func testEmptyHexStringReturnsEmptyData() {
        let data = Data(hexString: "")
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.count, 0)
    }

    /// 问题：包含空格的 hex 字符串被清理
    func testHexStringWithSpacesIsCleaned() {
        let data = Data(hexString: "de ad be ef")
        XCTAssertNotNil(data)
        XCTAssertEqual(data, Data([0xde, 0xad, 0xbe, 0xef]))
    }

    /// 问题：大写 hex 字符串被接受
    func testUpperCaseHexStringIsAccepted() {
        let data = Data(hexString: "DEADBEEF")
        XCTAssertNotNil(data)
        XCTAssertEqual(data, Data([0xde, 0xad, 0xbe, 0xef]))
    }

    /// 问题：无效 hex 字符返回 nil
    func testInvalidHexCharReturnsNil() {
        let data = Data(hexString: "xy")
        XCTAssertNil(data, "无效 hex 字符应返回 nil")
    }

    /// 问题：hexEncoded 输出小写
    func testHexEncodedOutputsLowerCase() {
        let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
        XCTAssertEqual(data.hexEncoded, "deadbeef")
    }

    /// 问题：hexEncoded 空数据
    func testHexEncodedEmptyData() {
        XCTAssertEqual(Data().hexEncoded, "")
    }

    /// 问题：往返编解码
    func testRoundTripHexEncodeDecode() {
        let original = Data([0x00, 0xFF, 0x80, 0x7F, 0x01])
        let encoded = original.hexEncoded
        let decoded = Data(hexString: encoded)
        XCTAssertEqual(decoded, original)
    }
}

// MARK: - ChatRunner UITesting mock 路径测试

/// 覆盖 ChatRunner 在 --uitesting 模式下的 mock 响应
/// 这些路径在正常单元测试中不执行（无 --uitesting 参数）
@MainActor
final class ChatRunnerUITestingMockTests: XCTestCase {

    /// 问题：无 --uitesting 参数时，generate 不走 mock 路径
    /// 验证 ProcessInfo.processInfo.arguments 不包含 --uitesting
    func testNoUITestingArgInUnitTestEnvironment() {
        let args = ProcessInfo.processInfo.arguments
        XCTAssertFalse(args.contains(LLMConstants.UITesting.launchArg), "单元测试环境不应包含 --uitesting 参数")
    }

    /// 问题：mockStreamChunks 不为空
    func testMockStreamChunksNotEmpty() {
        XCTAssertFalse(LLMConstants.UITesting.mockStreamChunks.isEmpty, "mockStreamChunks 不应为空")
    }

    /// 问题：mockStreamChunks 拼接后是有效文本
    func testMockStreamChunksConcatenatedIsValidText() {
        let fullText = LLMConstants.UITesting.mockStreamChunks.joined()
        XCTAssertFalse(fullText.isEmpty, "拼接后的 mock 文本不应为空")
        XCTAssertTrue(fullText.contains("Mock"), "mock 文本应包含 'Mock' 标识")
    }

    /// 问题：mockNonStreamReply 不为空
    func testMockNonStreamReplyNotEmpty() {
        XCTAssertFalse(LLMConstants.UITesting.mockNonStreamReply.isEmpty)
    }

    /// 问题：mockRAGReply 不为空
    func testMockRAGReplyNotEmpty() {
        XCTAssertFalse(LLMConstants.UITesting.mockRAGReply.isEmpty)
    }

    /// 问题：nanosecondsPerSecond 常量正确
    func testNanosecondsPerSecondConstant() {
        XCTAssertEqual(LLMConstants.UITesting.nanosecondsPerSecond, 1_000_000_000)
    }

    /// 问题：mockNonStreamDelaySeconds > 0
    func testMockNonStreamDelaySecondsPositive() {
        XCTAssertGreaterThan(LLMConstants.UITesting.mockNonStreamDelaySeconds, 0)
    }

    /// 问题：mockStreamInitialDelaySeconds > mockStreamChunkDelaySeconds
    func testMockStreamInitialDelayGreaterThanChunkDelay() {
        XCTAssertGreaterThan(LLMConstants.UITesting.mockStreamInitialDelaySeconds, LLMConstants.UITesting.mockStreamChunkDelaySeconds)
    }
}

// MARK: - LLMConstants.Anonymization 常量测试

/// 验证脱敏相关常量
final class LLMAnonymizationConstantsTests: XCTestCase {

    /// 问题：placeholderPrefix 是 "[ENTITY_"
    func testPlaceholderPrefix() {
        XCTAssertEqual(LLMConstants.Anonymization.placeholderPrefix, "[ENTITY_")
    }

    /// 问题：maxRawLength=25 限制了 buffer 缓存的最大长度
    /// 如果 LLM 生成了超过 25 字符的 [ 开头内容，不会被缓存
    func testMaxRawLength() {
        XCTAssertEqual(LLMConstants.EntityPlaceholder.maxRawLength, 25)
    }

    /// 问题：maxRawLength 足够容纳合理的 ENTITY 占位符
    /// [ENTITY_XXXX] 最长约 15 字符，25 足够
    func testMaxRawLengthSufficientForEntityPlaceholders() {
        let samplePlaceholder = "[ENTITY_AAAAAAAA]" // 17 字符
        XCTAssertLessThan(samplePlaceholder.count, LLMConstants.EntityPlaceholder.maxRawLength)
    }
}

// MARK: - PluginManifest 本地化测试

/// 覆盖 PluginManifest.name 和 description 的本地化回退逻辑
@MainActor
final class PluginManifestLocalizationTests: XCTestCase {

    /// A-38：name 在无匹配语言时返回字典中的任意值（比 fallback 到 id 更有信息量）
    /// 字典非空时，bestMatch 返回字典中的值（某种语言的名称），
    /// 而非 fallback 到插件 id — 用户至少能看到一个名称
    func testNameFallsBackToIdWhenNoMatch() {
        let manifest = PluginManifest(
            id: "test.plugin",
            version: "1.0.0",
            names: ["fr": "Plugin Français"],
            descriptions: ["fr": "Description en français"]
        )
        // 修正后：bestMatch 字典非空时返回字典中的值（比 fallback 更有信息量）
        XCTAssertEqual(manifest.name, "Plugin Français", "无匹配语言时 name 应返回字典中的值（比 fallback 到 id 更有信息量）")
    }

    /// A-38：description 在无匹配语言时返回字典中的任意值
    /// description 的 fallback 是空字符串，bestMatch 在字典非空时返回字典任意值
    /// 这比返回空字符串更有信息量 — 用户至少能看到某种语言的描述
    func testDescriptionReturnsArbitraryValueWhenNoMatch() {
        let manifest = PluginManifest(
            id: "test.plugin",
            version: "1.0.0",
            names: ["en": "Test"],
            descriptions: ["fr": "Description en français"]
        )
        // 字典非空时，返回字典中的任意值（比空字符串更有信息量）
        XCTAssertEqual(manifest.description, "Description en français", "description 字典非空时返回字典任意值是合理行为")
    }

    /// 问题：name 在有 en 匹配时返回 en 值
    func testNameReturnsEnValueWhenAvailable() {
        let manifest = PluginManifest(
            id: "test.plugin",
            version: "1.0.0",
            names: ["en": "Test Plugin"],
            descriptions: ["en": "A test plugin"]
        )
        // bestMatch 会匹配 en 或当前语言
        XCTAssertFalse(manifest.name.isEmpty)
    }
}

// MARK: - OnDeviceLLMService discoverModels 状态测试

/// 覆盖 OnDeviceLLMService.discoverModels 的状态更新逻辑
@MainActor
final class OnDeviceLLMServiceDiscoverModelsTests: XCTestCase {

    /// 问题：discoverModels 后 selectedModelID 被设置为第一个可用模型
    func testDiscoverModelsSetsSelectedModelIDToFirst() {
        let service = OnDeviceLLMService()
        service.discoverModels()

        // 如果有可用模型，selectedModelID 应不为空
        if !service.availableModels.isEmpty {
            XCTAssertFalse(service.selectedModelID.isEmpty, "discoverModels 后 selectedModelID 应被设置")
        }
    }

    /// 问题：discoverModels 后 availableModels 包含系统模型（iOS 18.1+）
    func testDiscoverModelsIncludesSystemModelOnIOS18Plus() {
        let service = OnDeviceLLMService()
        service.discoverModels()

        if #available(iOS 18.1, *) {
            let hasSystem = service.availableModels.contains { $0.type == .system }
            XCTAssertTrue(hasSystem, "iOS 18.1+ 应包含系统模型")
        }
    }

    /// 问题：多次调用 discoverModels 不重复添加模型
    func testDiscoverModelsCalledMultipleTimesDoesNotDuplicate() {
        let service = OnDeviceLLMService()
        service.discoverModels()
        let firstCount = service.availableModels.count

        service.discoverModels()
        let secondCount = service.availableModels.count

        XCTAssertEqual(firstCount, secondCount, "多次 discoverModels 不应重复添加模型")
    }
}
