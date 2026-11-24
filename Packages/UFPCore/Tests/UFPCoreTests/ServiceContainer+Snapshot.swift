// 系统层级：[Tests] 单元测试
// 核心职责：通过内部状态检查 DI 失败诊断，不在生产类暴露测试方法。
@testable import UFPCore

extension ServiceContainer {
    /// 测试辅助：构造当前 DI 状态的 resolve 快照（不触发 resolve 计数器递增）
    /// 仅供单元测试 buildResolveFailureDiagnostics 使用
    internal func makeResolveSnapshotForTesting() -> ResolveSnapshot {
        lock.withLock {
            ResolveSnapshot(
                instance: nil,
                registeredKeys: Array(services.keys),
                callCount: resolveCallCount,
                regCallCount: registerCallCount
            )
        }
    }

}
