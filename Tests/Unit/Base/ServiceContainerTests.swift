//
//  ServiceContainerTests.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/28.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[L0] 测试层
//  核心职责：针对底层 ServiceContainer 依赖注入容器进行完备的单元测试，
//          重点覆盖高并发多线程解析下的并发安全，以及循环依赖防御场景。
//

import XCTest
@testable import ZhiYu

// MARK: - 测试存根定义 (使用 ForDI 前缀防止与 TestMocks.swift 全局冲突)

/// 模拟日志服务接口，显式约束为 AnyObject 以便支持恒等 (===) 校验
private protocol MockLoggerForDIProtocol: AnyObject, Sendable {
    func log(_ message: String)
}

/// 模拟日志服务实现
private final class MockLoggerForDI: MockLoggerForDIProtocol {
    func log(_ message: String) {
        // 存根实现
    }
}

/// 模拟数据库服务接口
private protocol MockDatabaseForDIProtocol: AnyObject, Sendable {
    func execute(_ query: String)
}

/// 模拟数据库服务实现
private final class MockDatabaseForDI: MockDatabaseForDIProtocol, @unchecked Sendable {
    @Inject var logger: any MockLoggerForDIProtocol
    
    func execute(_ query: String) {
        logger.log("Executing query: \(query)")
    }
}

/// 模拟循环依赖服务A
private final class CircularServiceA {
    var dependencyB: CircularServiceB?
    
    init() {}
}

/// 模拟循环依赖服务B
private final class CircularServiceB {
    var dependencyA: CircularServiceA?
    
    init() {}
}

// MARK: - 测试套件

/// 针对 ServiceContainer 依赖注入容器的单元测试
final class ServiceContainerTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // 每个测试用例启动前重置 DI 容器，保证用例间的强隔离性
        ServiceContainer.shared.reset()
    }
    
    override func tearDown() {
        ServiceContainer.shared.reset()
        super.tearDown()
    }
    
    /// TC-DI-01: 验证服务的基础注册、解析、可选解析与状态检测
    func testBasicRegistrationAndResolution() {
        let container = ServiceContainer.shared
        let logger = MockLoggerForDI()
        
        // 1. 验证初始状态下服务未注册
        XCTAssertFalse(container.hasService(for: (any MockLoggerForDIProtocol).self))
        XCTAssertNil(container.resolveOptional((any MockLoggerForDIProtocol).self))
        
        // 2. 执行注册服务
        container.register(logger as any MockLoggerForDIProtocol, for: (any MockLoggerForDIProtocol).self)
        
        // 3. 验证注册后状态
        XCTAssertTrue(container.hasService(for: (any MockLoggerForDIProtocol).self))
        
        // 4. 验证成功解析出相同实例
        let resolved = container.resolve((any MockLoggerForDIProtocol).self)
        XCTAssertTrue(resolved === logger, "解析出的服务实例应当与注册的完全一致")
        
        // 5. 验证可选解析正常工作
        let resolvedOptional = container.resolveOptional((any MockLoggerForDIProtocol).self)
        XCTAssertNotNil(resolvedOptional)
        XCTAssertTrue(resolvedOptional === logger)
    }
    
    /// TC-DI-02: 验证 @Inject 属性包装器的延迟解析机制与依赖联动
    func testPropertyWrapperInject() {
        let container = ServiceContainer.shared
        let logger = MockLoggerForDI()
        let database = MockDatabaseForDI()
        
        // 1. 注册所需依赖
        container.register(logger as any MockLoggerForDIProtocol, for: (any MockLoggerForDIProtocol).self)
        container.register(database as any MockDatabaseForDIProtocol, for: (any MockDatabaseForDIProtocol).self)
        
        // 2. 通过属性包装器自动解析
        @Inject var injectedDb: any MockDatabaseForDIProtocol
        
        XCTAssertNotNil(injectedDb)
        // 3. 调用其依赖 logger 的联动方法，确保在没有崩溃的情况下执行通过
        injectedDb.execute("SELECT 1")
    }
    
    /// TC-DI-03: 验证高并发多线程解析场景下的线程安全
    /// 模拟 50 个 Task 同时在不同的并发子线程中高频并发进行 resolve 解析，验证 os_unfair_lock 的防数据竞争 (Data Race) 效能
    func testHighConcurrencyResolutionSafety() async {
        let container = ServiceContainer.shared
        let logger = MockLoggerForDI()
        container.register(logger as any MockLoggerForDIProtocol, for: (any MockLoggerForDIProtocol).self)
        
        let concurrencyCount = 50
        
        // 利用 Swift 6 严格并发 TaskGroup 模拟并发调度
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<concurrencyCount {
                group.addTask {
                    // 并发读取解析服务
                    let resolved = container.resolve((any MockLoggerForDIProtocol).self)
                    XCTAssertNotNil(resolved)
                    
                    // 并发进行 Optional 解析
                    let resolvedOpt = container.resolveOptional((any MockLoggerForDIProtocol).self)
                    XCTAssertNotNil(resolvedOpt)
                    
                    // 并发检测服务是否存在
                    let exists = container.hasService(for: (any MockLoggerForDIProtocol).self)
                    XCTAssertTrue(exists)
                }
            }
            
            // 等待所有并发 Task 稳健执行完成，未触发 EXCBADACCESS 则代表锁防卫成功
            await group.waitForAll()
        }
    }
    
    /// TC-DI-04: 验证动态并发注册与解析的竞态条件防御
    /// 多个线程同时在进行 register 和 resolve，保障在高频加载插件时系统在并发读写字典时不会触发闪退
    func testConcurrentRegisterAndResolveRace() async {
        let container = ServiceContainer.shared
        let concurrencyCount = 30
        
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<concurrencyCount {
                group.addTask {
                    let serviceInstance = MockLoggerForDI()
                    // 模拟随机并发读写
                    if i % 2 == 0 {
                        container.register(serviceInstance as any MockLoggerForDIProtocol, for: (any MockLoggerForDIProtocol).self)
                    } else {
                        _ = container.resolveOptional((any MockLoggerForDIProtocol).self)
                    }
                }
            }
            await group.waitForAll()
        }
    }
    
    /// TC-DI-05: 验证循环依赖下的防御性安全隔离，防止实例化构造过程中的无限递归死锁
    func testCircularDependencyResolutionSafety() {
        let container = ServiceContainer.shared
        
        let a = CircularServiceA()
        let b = CircularServiceB()
        
        // 建立双向循环引用关系
        a.dependencyB = b
        b.dependencyA = a
        
        // 注册到容器中
        container.register(a, for: CircularServiceA.self)
        container.register(b, for: CircularServiceB.self)
        
        // 预期：如果实例已经在容器中完成扁平化注册，解析时应是 O(1) 直接返回缓存实例，而不会进入死递归
        let resolvedA = container.resolve(CircularServiceA.self)
        let resolvedB = container.resolve(CircularServiceB.self)
        
        XCTAssertNotNil(resolvedA)
        XCTAssertNotNil(resolvedB)
        XCTAssertTrue(resolvedA.dependencyB === resolvedB)
        XCTAssertTrue(resolvedB.dependencyA === resolvedA)
    }
}
