// 系统层级：[Tests] 测试替身模块
// 核心职责：为事务排空失败路径提供可控状态。
@testable import UFPStorage

extension TransactionGatekeeper {
    /// 设置排空状态（仅测试使用）。
    public func setDrainingForTesting(_ value: Bool) {
        draining = value
    }

}
