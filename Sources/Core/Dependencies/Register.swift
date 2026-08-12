// 系统层级：[L0 基础设施层]
// 核心职责：DependencyValues 注册入口 — 集中注册 21 个服务的 DependencyKey。
//           迁移期间为空占位，P2-P6 阶段逐步为每个服务添加 DependencyKey 扩展。
//           终态：每个服务有 live/test/preview 三态注册，通过 @Dependency(\.xxxService) 注入。

import Dependencies

// MARK: - DependencyValues 注册入口
//
// P2-P6 阶段将在此文件追加各服务的 DependencyKey 扩展，格式如下：
//
// extension DependencyValues {
//     var routerService: any RouterServiceProtocol {
//         get { self[RouterServiceKey.self] }
//         set { self[RouterServiceKey.self] = newValue }
//     }
// }
//
// private enum RouterServiceKey: DependencyKey {
//     static let liveValue: any RouterServiceProtocol = Router.shared
//     static let testValue: any RouterServiceProtocol = MockRouter()
//     static let previewValue: any RouterServiceProtocol = Router.preview()
// }
//
// P1 阶段：空占位，无注册项
