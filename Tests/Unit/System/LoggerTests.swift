//
//  SystemLoggerTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0.5] 测试层
//  核心职责：针对系统日志器 Logger 开展全方位的结构化审计与存盘持久化单元测试验证。
//

import XCTest
import Combine
@testable import ZhiYu

final class SystemLoggerTests: XCTestCase {
    
    private var tempDirectory: URL!
    private var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        // 1. 创建干净的临时目录用于持久化测试，防灾沙盒污染
        let fm = FileManager.default
        tempDirectory = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? fm.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }
    
    override func tearDown() {
        // 2. 清理临时测试目录
        try? FileManager.default.removeItem(at: tempDirectory)
        cancellables = nil
        super.tearDown()
    }
    
    /// TC-LOG-01: 验证日志的非隔离标准级别输出接口执行健壮性，确保高频记录不发生闪退
    func testStandardLogLevels() async {
        let logger = Logger(customDirectory: tempDirectory)
        // 轮询等待 Logger init Task 完成
        for _ in 0..<20 {
            if await logger.getLogEntries().count == 0 { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // 验证非隔离环境下的同步快捷调用接口不引发异常
        logger.debug("调试级别日志消息")
        logger.info("信息级别日志消息")
        logger.warning("警告级别日志消息")
        logger.error("错误级别日志消息", error: NSError(domain: "TestDomain", code: 404, userInfo: [NSLocalizedDescriptionKey: "物理模拟错误"]))
        
        // 等待异步 Task 完成写入
        try? await Task.sleep(nanoseconds: UInt64(0.2 * 1_000_000_000))
        
        // 获取写入后的日志条目，由于是非隔离 error/addLog 级联，内存中应已存在
        let entries = await logger.getLogEntries()
        XCTAssertTrue(entries.count > 0, "内存缓存中应至少存在刚才写入的日志记录")
    }
    
    /// TC-LOG-02: 验证 maxLogEntries (500条) 的截断和溢出管理机制
    func testLogEntriesLimitClipping() async {
        let logger = Logger(customDirectory: tempDirectory)

        // 1. 高频写入 510 条记录，超出 500 条上限
        for i in 1...510 {
            logger.addLog(action: .create, target: "Page_\(i)", details: "高频测试批量写入")
            try? await Task.sleep(nanoseconds: 1_000_000)
        }

        // 2. 轮询等待所有非结构化 addLog Task 完成并触发截断
        let maxRetries = 30
        var entries: [LogEntry] = []
        for _ in 0..<maxRetries {
            entries = await logger.getLogEntries()
            if entries.count == 500 { break }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }

        // 3. 校验内存中保存的日志数是否被精准限缩在 500 条
        XCTAssertEqual(entries.count, 500, "超限写入后，内存日志条数应当被严格修剪并限缩在 500 条内")

        // 4. 校验最新写入的 page_510 排在最前（因 insert at 0）
        XCTAssertEqual(entries.first?.target, "Page_510", "最新插入的数据应当排列在缓存头部")
    }
    
    /// TC-LOG-03: 验证 logTimed 耗时操作测算方法在成功和失败路径下的记录表现与 rethrows 异常传导
    func testLogTimedOperation() async throws {
        let logger = Logger(customDirectory: tempDirectory)
        
        // 1. 成功操作路径
        let successVal = logger.logTimed(action: .ingest, target: "TimedSuccess", module: "TestModule", details: "测试计时成功") {
            // 模拟轻量操作
            return "Result_OK"
        }
        XCTAssertEqual(successVal, "Result_OK")
        
        // 2. 失败操作路径（验证异常的正确向上抛出并被 catch 捕获）
        struct DummyError: Error, LocalizedError {
            var errorDescription: String? { "测试异常错误说明" }
        }
        
        do {
            _ = try logger.logTimed(action: .ingest, target: "TimedFailure", module: "TestModule", details: "测试计时失败") {
                throw DummyError()
            }
            XCTFail("计时包裹内抛出的错误应当被 rethrows 抛出，而不是在内部吞掉")
        } catch {
            XCTAssertTrue(error is DummyError)
        }
        
        // 稍作等待以完成写入
        try? await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
        
        // 3. 校验日志存储中的记录完整度
        let entries = await logger.getLogEntries()
        
        let failureEntry = entries.first(where: { $0.target == "TimedFailure" })
        XCTAssertNotNil(failureEntry)
        XCTAssertEqual(failureEntry?.status, .failure)
        XCTAssertEqual(failureEntry?.failureReason, "测试异常错误说明")
        XCTAssertNotNil(failureEntry?.duration)
        
        let successEntry = entries.first(where: { $0.target == "TimedSuccess" })
        XCTAssertNotNil(successEntry)
        XCTAssertEqual(successEntry?.status, .success)
        XCTAssertNotNil(successEntry?.duration)
    }
    
    /// TC-LOG-04: 验证日志的物理存盘 (saveToDisk) 与反序列化重载 (loadFromDisk) 的完整无损链路
    func testLoggerDiskPersistence() async {
        let logger = Logger(customDirectory: tempDirectory)
        // 轮询等待 Logger init Task 完成
        for _ in 0..<20 {
            if await logger.getLogEntries().count == 0 { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        // 1. 写入 3 条特定标识测试日志
        logger.addLog(action: .create, target: "PageForDisk1", details: "落盘测试1", module: "DiskIO")
        logger.addLog(action: .create, target: "PageForDisk2", details: "落盘测试2", module: "DiskIO")
        
        // 2. 显式保存至物理临时目录
        await logger.saveToDisk()
        
        // 稍微休眠 0.3 秒，给予 Detached background 线程磁盘写操作的物理就绪窗口
        try? await Task.sleep(nanoseconds: UInt64(0.3 * 1_000_000_000))
        
        // 3. 实例化一个全新的 Logger（绑定相同物理路径），重新触发磁盘反序列化读取
        let secondLogger = Logger(customDirectory: tempDirectory)
        // 轮询等待 Logger init Task 完成
        for _ in 0..<20 {
            if await logger.getLogEntries().count == 0 { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        await secondLogger.loadFromDisk()
        
        // 4. 校验读回的内容与原始写入是否一致
        let restoredEntries = await secondLogger.getLogEntries()
        XCTAssertTrue(restoredEntries.count >= 2, "全新加载的日志器应当成功重载物理落盘数据")
        
        let match1 = restoredEntries.first(where: { $0.target == "PageForDisk1" })
        XCTAssertNotNil(match1)
        XCTAssertEqual(match1?.details, "落盘测试1")
        XCTAssertEqual(match1?.module, "DiskIO")
    }
    
    /// TC-LOG-05: 验证内存清空与通知广播的响应式闭环
    func testClearLogsAndCombinePublisher() async {
        let logger = Logger(customDirectory: tempDirectory)
        // 轮询等待 Logger init Task 完成
        for _ in 0..<20 {
            if await logger.getLogEntries().count == 0 { break }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        let expectation = XCTestExpectation(description: "等待日志流清空通知")
        
        // 1. 写入数据
        logger.addLog(action: .update, target: "CombinePage", details: "观察者日志")
        
        // 2. 订阅 Combine 发射流，检验清空后是否会发射 empty 列表
        var receivedEntriesCount = -1
        logger.logEntriesPublisher
            .sink { list in
                receivedEntriesCount = list.count
                if list.isEmpty {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
            
        // 等待订阅就绪
        try? await Task.sleep(nanoseconds: UInt64(0.1 * 1_000_000_000))
        
        // 3. 执行清空
        await logger.clearAllLogs()
        
        await fulfillment(of: [expectation], timeout: 2.0)
        XCTAssertEqual(receivedEntriesCount, 0, "调用 clearAllLogs 后，订阅流应当发射长度为 0 的空集合")
    }
    
    /// TC-LOG-06: 验证 TimeInterval.formattedAdaptive 在多量级下的自适应单位格式化无损校准
    func testTimeIntervalFormattedAdaptive() {
        // 1. 微秒级 (< 1ms)
        let microTime: TimeInterval = 0.000456 // 456 微秒
        XCTAssertEqual(microTime.formattedAdaptive, "456µs")
        
        // 2. 毫秒级 (1ms ~ 1s)
        let milliTime: TimeInterval = 0.1234 // 123.4 毫秒
        XCTAssertEqual(milliTime.formattedAdaptive, "123.4ms")
        
        // 3. 秒级 (1s ~ 60s)
        let secondTime: TimeInterval = 45.678 // 45.68 秒
        XCTAssertEqual(secondTime.formattedAdaptive, "45.68s")
        
        // 4. 分钟级 (>= 60s)
        let minuteTime: TimeInterval = 125.4 // 2分 5.4秒
        XCTAssertEqual(minuteTime.formattedAdaptive, "2m 5.4s")
    }
}
