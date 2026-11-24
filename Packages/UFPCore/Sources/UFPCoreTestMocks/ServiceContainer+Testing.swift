// 系统层级：[Tests] 测试替身模块
// 核心职责：仅向测试调用方提供容器生命周期重置能力。
import Foundation
@testable import UFPCore

extension ServiceContainer {
    /// 原子清除生命周期标记及注册表，正式模块不提供此接口。
    public func resetForTesting() {
        let removedKeys = lock.withLock {
            isProductionChainPopulated = false
            let keys = Array(services.keys)
            services.removeAll()
            return keys
        }
        lastResetInfo = "Removed services: \(removedKeys.sorted().joined(separator: ", "))"
        lastResetTimestamp = Date()
    }
}
