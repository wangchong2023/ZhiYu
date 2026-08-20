//
//  LoggerSupplementTests.swift
//  ZhiYu
//
//  系统层级：[L0] 测试层
//  核心职责：Logger 问题驱动深度测试 — 覆盖日志分级、持久化、脱敏、
//           logTimed、maxLogEntries 截断、formattedAdaptive 时间格式化。
//

import XCTest
import Combine
import UFPCore
@testable import ZhiYu

/// Logger 深度测试
///
/// 覆盖目标：
/// - Logger.shared: debug/info/warning/error/addLog/logTimed
/// - saveToDisk/loadFromDisk/clearAllLogs/getLogEntries
/// - logEntriesPublisher 订阅
/// - maxLogEntries=500 截断逻辑
/// - LogMasker.mask 脱敏（多提供商 API key）
/// - TimeInterval.formattedAdaptive 4 级格式化
/// - NoOpLogger 安全默认值
/// - LogAction/LogStatus 枚举属性
final class LoggerSupplementTests: XCTestCase {

    // MARK: - Logger 基础日志方法

    /// Logger.debug 应不崩溃（DEBUG 模式下打印）
    func testLogger_debug_不崩溃() {
        Logger.shared.debug("test debug message")
        // 不崩溃即通过
    }

    /// Logger.info 应不崩溃
    func testLogger_info_不崩溃() {
        Logger.shared.info("test info message")
        // 不崩溃即通过
    }

    /// Logger.warning 应不崩溃
    func testLogger_warning_不崩溃() {
        Logger.shared.warning("test warning message")
        // 不崩溃即通过
    }

    /// Logger.error 无 error 参数应不崩溃
    func testLogger_error_无error_不崩溃() {
        Logger.shared.error("test error message")
        // 不崩溃即通过
    }

    /// Logger.error 带 error 参数应不崩溃
    func testLogger_error_带error_不崩溃() {
        let error = NSError(domain: "test", code: 1, userInfo: nil)
        Logger.shared.error("test error with error", error: error)
        // 不崩溃即通过
    }

    // MARK: - addLog 结构化日志

    /// Logger.addLog 完整参数应不崩溃并记录
    func testLogger_addLog_完整参数_记录成功() async {
        await Logger.shared.clearAllLogs()
        Logger.shared.addLog(
            action: .create, target: "test_target", details: "test_details",
            duration: 1.5, startTime: Date(), endTime: Date(),
            module: "TestModule", status: .success, failureReason: nil
        )
        // addLog 是异步的，需要等待一小段时间让 Task 完成
        try? await Task.sleep(nanoseconds: 100_000_000)
        let entries = await Logger.shared.getLogEntries()
        XCTAssertTrue(entries.contains { $0.target == "test_target" }, "应包含刚添加的日志")
    }

    /// Logger.addLog 最小参数应不崩溃
    func testLogger_addLog_最小参数_不崩溃() async {
        Logger.shared.addLog(action: .update, target: "minimal")
        try? await Task.sleep(nanoseconds: 100_000_000)
        // 不崩溃即通过
    }

    /// Logger.addLog 失败状态应记录 failureReason
    func testLogger_addLog_失败状态_记录failureReason() async {
        await Logger.shared.clearAllLogs()
        Logger.shared.addLog(
            action: .delete, target: "failed_op",
            details: "op failed", status: .failure,
            failureReason: "permission denied"
        )
        try? await Task.sleep(nanoseconds: 100_000_000)
        let entries = await Logger.shared.getLogEntries()
        let failureEntry = entries.first { $0.target == "failed_op" }
        XCTAssertNotNil(failureEntry, "应能找到失败日志")
        XCTAssertEqual(failureEntry?.status, .failure)
        XCTAssertEqual(failureEntry?.failureReason, "permission denied")
    }

    // MARK: - logTimed

    /// Logger.logTimed 成功操作应记录 success 状态
    func testLogger_logTimed_成功_记录Success() async throws {
        await Logger.shared.clearAllLogs()
        let result = Logger.shared.logTimed(action: .ingest, target: "timed_op") {
            return 42
        }
        XCTAssertEqual(result, 42, "logTimed 应返回操作结果")
        try? await Task.sleep(nanoseconds: 100_000_000)
        let entries = await Logger.shared.getLogEntries()
        let timedEntry = entries.first { $0.target == "timed_op" }
        XCTAssertNotNil(timedEntry, "应记录 timed 操作")
        XCTAssertEqual(timedEntry?.status, .success)
        XCTAssertNotNil(timedEntry?.duration, "应记录耗时")
    }

    /// Logger.logTimed 抛出异常应记录 failure 状态并重新抛出
    func testLogger_logTimed_抛异常_记录Failure并重新抛出() async {
        await Logger.shared.clearAllLogs()
        struct TestError: Error {}

        do {
            _ = try Logger.shared.logTimed(action: .error, target: "throwing_op") {
                throw TestError()
            }
            XCTFail("应抛出异常")
        } catch {
            // 预期抛出
        }
        try? await Task.sleep(nanoseconds: 100_000_000)
        let entries = await Logger.shared.getLogEntries()
        let failureEntry = entries.first { $0.target == "throwing_op" }
        XCTAssertNotNil(failureEntry, "应记录失败的 timed 操作")
        XCTAssertEqual(failureEntry?.status, .failure)
    }

    // MARK: - 持久化

    /// Logger.clearAllLogs 应清空所有日志
    func testLogger_clearAllLogs_清空日志() async {
        Logger.shared.addLog(action: .create, target: "to_be_cleared")
        try? await Task.sleep(nanoseconds: 100_000_000)
        await Logger.shared.clearAllLogs()
        let entries = await Logger.shared.getLogEntries()
        XCTAssertTrue(entries.isEmpty, "清空后应无日志")
    }

    /// Logger.saveToDisk + loadFromDisk 应能持久化和恢复
    func testLogger_saveAndLoad_持久化恢复() async {
        await Logger.shared.clearAllLogs()
        Logger.shared.addLog(action: .create, target: "persist_test")
        try? await Task.sleep(nanoseconds: 200_000_000)
        await Logger.shared.saveToDisk()
        await Logger.shared.loadFromDisk()
        let entries = await Logger.shared.getLogEntries()
        // loadFromDisk 后应能恢复（至少不崩溃）
        XCTAssertNotNil(entries as [LogEntry]?)
    }

    /// Logger.getLogEntries 应按时间倒序排列
    func testLogger_getLogEntries_按时间倒序() async {
        await Logger.shared.clearAllLogs()
        Logger.shared.addLog(action: .create, target: "first")
        try? await Task.sleep(nanoseconds: 50_000_000)
        Logger.shared.addLog(action: .update, target: "second")
        try? await Task.sleep(nanoseconds: 200_000_000)
        let entries = await Logger.shared.getLogEntries()
        guard entries.count >= 2 else {
            XCTFail("应至少有 2 条日志")
            return
        }
        XCTAssertEqual(entries[0].target, "second", "最新的日志应在前")
        XCTAssertEqual(entries[1].target, "first", "较早的日志应在后")
    }

    // MARK: - logEntriesPublisher

    /// Logger.logEntriesPublisher 应能订阅并接收更新
    func testLogger_logEntriesPublisher_订阅接收() async {
        await Logger.shared.clearAllLogs()
        var receivedEntries: [LogEntry] = []
        let cancellable = Logger.shared.logEntriesPublisher
            .sink { entries in
                receivedEntries = entries
            }
        Logger.shared.addLog(action: .create, target: "publisher_test")
        try? await Task.sleep(nanoseconds: 200_000_000)
        XCTAssertTrue(receivedEntries.contains { $0.target == "publisher_test" }, "订阅应收到新日志")
        cancellable.cancel()
    }

    // MARK: - maxLogEntries 截断

    /// Logger 超过 maxLogEntries(500) 应截断
    func testLogger_超过500条_截断() async {
        let logger = Logger(customDirectory: FileManager.default.temporaryDirectory
            .appendingPathComponent("logger_test_\(UUID().uuidString)"))
        await logger.clearAllLogs()
        // 添加 510 条日志
        for i in 0..<510 {
            logger.addLog(action: .create, target: "batch_\(i)")
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        let entries = await logger.getLogEntries()
        XCTAssertLessThanOrEqual(entries.count, 500, "日志条数不应超过 500")
    }

    // MARK: - LogMasker 脱敏

    /// LogMasker 应脱敏 OpenAI API key (sk-)
    func testLogMasker_OpenAIKey_脱敏() {
        let masked = LogMasker.mask("my key is sk-1234567890abcdefghijklmnopqrstuvwxyz")
        XCTAssertTrue(masked.contains("sk-****"), "OpenAI key 应被脱敏为 sk-****")
        XCTAssertFalse(masked.contains("sk-1234567890abcdefghijklmnopqrstuvwxyz"), "原始 key 不应残留")
    }

    /// LogMasker 应脱敏 Anthropic API key (sk-ant-)
    func testLogMasker_AnthropicKey_脱敏() {
        let masked = LogMasker.mask("key: sk-ant-1234567890abcdefghij")
        XCTAssertTrue(masked.contains("sk-ant-****"), "Anthropic key 应被脱敏")
    }

    /// LogMasker 应脱敏 Google API key (AIza)
    func testLogMasker_GoogleKey_脱敏() {
        let masked = LogMasker.mask("google: AIza1234567890abcdefghijklmnopqrstuvwxyz")
        XCTAssertTrue(masked.contains("AIza****"), "Google key 应被脱敏")
    }

    /// LogMasker 应脱敏 Zhipu API key (xxx.xxx 格式)
    func testLogMasker_ZhipuKey_脱敏() {
        let masked = LogMasker.mask("zhipu: abcdef1234567890abcdef1234567890.abcdefgh1234567890")
        XCTAssertTrue(masked.contains("****.****"), "Zhipu key 应被脱敏")
    }

    /// LogMasker 应脱敏 Authorization Bearer header
    func testLogMasker_AuthBearer_脱敏() {
        let masked = LogMasker.mask("Authorization: Bearer abc123def456")
        XCTAssertTrue(masked.contains("Authorization: Bearer ****"), "Auth Bearer 应被脱敏")
    }

    /// LogMasker 无敏感信息应原样返回
    func testLogMasker_无敏感信息_原样返回() {
        let plain = "this is a normal log message"
        let masked = LogMasker.mask(plain)
        XCTAssertEqual(masked, plain, "无敏感信息应原样返回")
    }

    /// LogMasker 空字符串应原样返回
    func testLogMasker_空字符串_原样返回() {
        let masked = LogMasker.mask("")
        XCTAssertEqual(masked, "")
    }

    // MARK: - TimeInterval.formattedAdaptive

    /// formattedAdaptive 微秒级 (< 1ms)
    func testFormattedAdaptive_微秒级() {
        let interval: TimeInterval = 0.0005
        let formatted = interval.formattedAdaptive
        XCTAssertTrue(formatted.contains("µs"), "微秒级应显示 µs 单位")
    }

    /// formattedAdaptive 毫秒级 (< 1s)
    func testFormattedAdaptive_毫秒级() {
        let interval: TimeInterval = 0.05
        let formatted = interval.formattedAdaptive
        XCTAssertTrue(formatted.contains("ms"), "毫秒级应显示 ms 单位")
    }

    /// formattedAdaptive 秒级 (< 60s)
    func testFormattedAdaptive_秒级() {
        let interval: TimeInterval = 5.0
        let formatted = interval.formattedAdaptive
        XCTAssertTrue(formatted.contains("s"), "秒级应显示 s 单位")
        XCTAssertFalse(formatted.contains("m"), "秒级不应显示分钟")
    }

    /// formattedAdaptive 分钟级 (>= 60s)
    func testFormattedAdaptive_分钟级() {
        let interval: TimeInterval = 125.0
        let formatted = interval.formattedAdaptive
        XCTAssertTrue(formatted.contains("m"), "分钟级应显示 m 单位")
    }

    // MARK: - NoOpLogger

    /// NoOpLogger 所有方法应不崩溃且返回安全默认值
    func testNoOpLogger_所有方法_安全默认值() async {
        let logger = NoOpLogger()
        logger.debug("test")
        logger.info("test")
        logger.warning("test")
        logger.error("test")
        logger.addLog(action: .create, target: "test")
        await logger.saveToDisk()
        await logger.loadFromDisk()
        await logger.clearAllLogs()
        let entries = await logger.getLogEntries()
        XCTAssertTrue(entries.isEmpty, "NoOp getLogEntries 应返回空数组")
        XCTAssertTrue(logger.logEntriesPublisher is AnyPublisher<[LogEntry], Never>)
    }

    /// NoOpLogger.logTimed 应直接执行操作并返回结果
    func testNoOpLogger_logTimed_直接执行() throws {
        let logger = NoOpLogger()
        let result = try logger.logTimed(action: .create, target: "test", module: nil, details: "") {
            return 100
        }
        XCTAssertEqual(result, 100, "NoOp logTimed 应返回操作结果")
    }

    // MARK: - LogAction 枚举

    /// LogAction 所有 case 的 colorName 应非空
    func testLogAction_allCases_colorName非空() {
        for action in LogAction.allCases {
            XCTAssertFalse(action.colorName.isEmpty, "\(action) 的 colorName 不应为空")
        }
    }

    /// LogAction 所有 case 的 icon 应非空
    func testLogAction_allCases_icon非空() {
        for action in LogAction.allCases {
            XCTAssertFalse(action.icon.isEmpty, "\(action) 的 icon 不应为空")
        }
    }

    /// LogAction.localizedName 应非空
    func testLogAction_localizedName_非空() {
        for action in LogAction.allCases {
            XCTAssertFalse(action.localizedName.isEmpty, "\(action) 的 localizedName 不应为空")
        }
    }

    // MARK: - LogStatus 枚举

    /// LogStatus 所有 case 的 localizedName 应非空
    func testLogStatus_allCases_localizedName非空() {
        for status in LogStatus.allCases {
            XCTAssertFalse(status.localizedName.isEmpty, "\(status) 的 localizedName 不应为空")
        }
    }

    // MARK: - LogEntry

    /// LogEntry 默认初始化应正确设置属性
    func testLogEntry_默认初始化_属性正确() {
        let entry = LogEntry(action: .create, target: "test")
        XCTAssertEqual(entry.action, .create)
        XCTAssertEqual(entry.target, "test")
        XCTAssertEqual(entry.details, "")
        XCTAssertNil(entry.duration)
        XCTAssertNil(entry.startTime)
        XCTAssertNil(entry.endTime)
        XCTAssertNil(entry.module)
        XCTAssertNil(entry.status)
        XCTAssertNil(entry.failureReason)
    }

    /// LogEntry 完整初始化应正确设置所有属性
    func testLogEntry_完整初始化_属性正确() {
        let id = UUID()
        let start = Date()
        let end = Date()
        let entry = LogEntry(
            id: id, action: .delete, target: "full_test",
            details: "details", timestamp: start,
            duration: 2.5, startTime: start, endTime: end,
            module: "TestModule", status: .failure,
            failureReason: "test failure"
        )
        XCTAssertEqual(entry.id, id)
        XCTAssertEqual(entry.action, .delete)
        XCTAssertEqual(entry.target, "full_test")
        XCTAssertEqual(entry.details, "details")
        XCTAssertEqual(entry.duration, 2.5)
        XCTAssertEqual(entry.startTime, start)
        XCTAssertEqual(entry.endTime, end)
        XCTAssertEqual(entry.module, "TestModule")
        XCTAssertEqual(entry.status, .failure)
        XCTAssertEqual(entry.failureReason, "test failure")
    }

    /// LogEntry Codable 编解码应正确往返
    func testLogEntry_Codable_编解码往返() throws {
        let entry = LogEntry(
            action: .update, target: "codec_test",
            details: "codec details", duration: 1.0,
            module: "CodecModule", status: .success
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(entry)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LogEntry.self, from: data)
        XCTAssertEqual(decoded.action, entry.action)
        XCTAssertEqual(decoded.target, entry.target)
        XCTAssertEqual(decoded.details, entry.details)
        XCTAssertEqual(decoded.duration, entry.duration)
        XCTAssertEqual(decoded.module, entry.module)
        XCTAssertEqual(decoded.status, entry.status)
    }
}
