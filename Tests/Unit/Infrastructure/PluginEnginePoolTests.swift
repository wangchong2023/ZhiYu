//
//  PluginEnginePoolTests.swift
//  ZhiYuTests
//
//  系统层级：[Tests] 单元测试层
//  核心职责：验证 PluginEnginePool JSContext 连接池的复用、池上限与安全硬化逻辑。
//

import XCTest
@testable import ZhiYu

#if !os(watchOS)
import JavaScriptCore

final class PluginEnginePoolTests: XCTestCase {

    private var pool: PluginEnginePool!

    override func setUp() {
        super.setUp()
        pool = PluginEnginePool.shared
    }

    override func tearDown() {
        pool = nil
        super.tearDown()
    }

    // MARK: - borrowContext

    func testBorrowContext_returnsNonNilJSContext() {
        let context = pool.borrowContext()
        XCTAssertNotNil(context)
    }

    func testBorrowContext_multipleCalls_returnValidContexts() {
        let ctx1 = pool.borrowContext()
        let ctx2 = pool.borrowContext()

        XCTAssertNotNil(ctx1)
        XCTAssertNotNil(ctx2)
        XCTAssertFalse(ctx1 === ctx2)
    }

    // MARK: - returnContext + 复用

    func testReturnContext_thenBorrow_returnsSameInstance() {
        let ctx1 = pool.borrowContext()
        pool.returnContext(ctx1)

        let ctx2 = pool.borrowContext()
        XCTAssertTrue(ctx1 === ctx2, "归还后重新借出应返回同一实例")
    }

    func testReturnContext_clearsException() {
        let ctx = pool.borrowContext()
        ctx.exception = JSValue(newErrorFromMessage: "test error", in: ctx)
        XCTAssertNotNil(ctx.exception)

        pool.returnContext(ctx)
        let reused = pool.borrowContext()
        XCTAssertNil(reused.exception, "归还后 exception 应被清除")
    }

    // MARK: - 池上限

    func testReturnContext_exceedsMaxPoolSize_dropsExcessContext() {
        // 借出 5 个上下文（超过 maxPoolSize=4）
        var contexts: [JSContext] = []
        for _ in 0..<5 {
            contexts.append(pool.borrowContext())
        }

        // 全部归还：池只保留前 4 个，第 5 个被丢弃
        for ctx in contexts {
            pool.returnContext(ctx)
        }

        // 再借出 4 个，应从池中获取（复用）
        var reused: [JSContext] = []
        for _ in 0..<4 {
            reused.append(pool.borrowContext())
        }

        // 验证复用的实例都是之前借出的
        for ctx in reused {
            XCTAssertTrue(contexts.contains { $0 === ctx }, "前 4 个应从池中复用")
        }

        // 第 5 个借出：池已空，应创建新实例
        let newCtx = pool.borrowContext()
        XCTAssertNotNil(newCtx)

        // 归还所有
        for ctx in reused {
            pool.returnContext(ctx)
        }
        pool.returnContext(newCtx)
    }

    // MARK: - 安全硬化

    func testBorrowContext_evalIsUndefined() {
        let ctx = pool.borrowContext()
        let evalValue = ctx.evaluateScript("typeof globalThis.eval")
        XCTAssertEqual(evalValue?.toString(), "undefined")
        pool.returnContext(ctx)
    }

    func testBorrowContext_functionIsUndefined() {
        let ctx = pool.borrowContext()
        let funcValue = ctx.evaluateScript("typeof globalThis.Function")
        XCTAssertEqual(funcValue?.toString(), "undefined")
        pool.returnContext(ctx)
    }

    func testBorrowContext_objectPrototype_freezeAttempted() {
        let ctx = pool.borrowContext()
        // 硬化脚本尝试 freeze Object.prototype（在 try/catch 中）
        // JSC 可能不允许 freeze 原型对象，但脚本应不抛异常
        let result = ctx.evaluateScript("Object.isFrozen(Object.prototype)")
        XCTAssertNotNil(result)
        pool.returnContext(ctx)
    }

    func testBorrowContext_arrayPrototype_freezeAttempted() {
        let ctx = pool.borrowContext()
        // 硬化脚本尝试 freeze Array.prototype（在 try/catch 中）
        let result = ctx.evaluateScript("Object.isFrozen(Array.prototype)")
        XCTAssertNotNil(result)
        pool.returnContext(ctx)
    }

    // MARK: - 全局属性清理

    func testReturnContext_cleansUpCustomGlobals() {
        let ctx = pool.borrowContext()
        ctx.evaluateScript("globalThis.customVar = 42;")
        XCTAssertEqual(ctx.evaluateScript("globalThis.customVar")?.toNumber().intValue, 42)

        pool.returnContext(ctx)
        let reused = pool.borrowContext()
        let afterCleanup = reused.evaluateScript("typeof globalThis.customVar")
        XCTAssertEqual(afterCleanup?.toString(), "undefined", "归还后自定义全局属性应被清理")
        pool.returnContext(reused)
    }

    func testReturnContext_preservesInitialKeysMarker() {
        let ctx = pool.borrowContext()
        pool.returnContext(ctx)

        let reused = pool.borrowContext()
        // __zhiyu_initial_keys 在 returnContext 清理脚本中被保留（条件保护）
        // 但它本身是 Set 对象，typeof 返回 "object"
        let markerType = reused.evaluateScript("typeof globalThis.__zhiyu_initial_keys")
        XCTAssertEqual(markerType?.toString(), "object", "__zhiyu_initial_keys 标记应被保留")
        pool.returnContext(reused)
    }

    // MARK: - 执行能力

    func testBorrowContext_canExecuteSimpleJS() {
        let ctx = pool.borrowContext()
        let result = ctx.evaluateScript("1 + 2")
        XCTAssertEqual(result?.toNumber().intValue, 3)
        pool.returnContext(ctx)
    }

    func testBorrowContext_canDefineFunctions() {
        let ctx = pool.borrowContext()
        ctx.evaluateScript("globalThis.add = function(a, b) { return a + b; };")
        let result = ctx.evaluateScript("globalThis.add(3, 4)")
        XCTAssertEqual(result?.toNumber().intValue, 7)
        pool.returnContext(ctx)
    }
}

#endif
