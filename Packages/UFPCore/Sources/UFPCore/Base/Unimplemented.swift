// 系统层级：[L0] 基础设施层
// 核心职责：提供 unimplemented 闭包工厂，用于 DependencyKey.testValue — 测试中未覆盖的依赖会触发明确报错而非静默 crash

import Foundation

/// 创建一个 unimplemented 闭包 — 被调用时触发 fatalError，提示该依赖未在测试中覆盖。
///
/// 业界标准模式（Pointfree swift-dependencies）：testValue 返回 unimplemented 闭包，
/// 测试中未用 withDependencies 覆盖的依赖被调用时会明确报错，而非 crash 整个测试进程。
///
/// 用法：
/// ```swift
/// static var testValue: Foo {
///     Foo(
///         bar: unimplemented("Foo.bar"),
///         baz: unimplemented("Foo.baz")
///     )
/// }
/// ```
public func unimplemented<T>(
    _ description: String = "unimplemented",
    file: StaticString = #file,
    line: UInt = #line
) -> T {
    fatalError("\(description) was called without being implemented", file: file, line: line)
}
