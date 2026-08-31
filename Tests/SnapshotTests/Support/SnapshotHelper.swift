//
//  SnapshotHelper.swift
//  ZhiYu
//
//  Created by Antigravity on 2026/05/23.
//  Copyright © 2026 WangChong. All rights reserved.
//
//  系统层级：[Shared] 测试层
//  核心职责：属于 Support 模块，提供相关的结构体或工具支撑。
//
import SwiftUI
import Dependencies
@testable import ZhiYu

// MARK: - 快照测试公共配置

/// 快照测试公共配置常量
enum SnapshotConfig {

    /// 默认像素精度阈值（0.95 = 允许 5% 像素偏差）
    ///
    /// 用于 `assertSnapshot(of:as:.image(precision:))` 调用，
    /// 统一全项目快照测试的精度标准，避免魔鬼数字重复硬编码。
    static let defaultPrecision: Float = 0.95
}

// MARK: - 快照测试统一环境注入

extension View {

    /// 快照测试专用：一次性注入项目全部 `@Environment` / `@EnvironmentObject` 依赖。
    ///
    /// **背景**：SwiftUI 的 `@Environment` 是隐式依赖，编译器不检查，
    /// 测试中遗漏注入会导致运行时崩溃（`EnvironmentValues.subscript.getter` → `_assertionFailure`）。
    /// 此 modifier 统一维护全量依赖列表，杜绝快照测试遗漏注入。
    ///
    /// **使用方式**：
    /// ```swift
    /// assertSnapshot(of: MyView().snapshotEnvironment(), as: .image(...))
    /// ```
    ///
    /// **维护方式**：新增 `@Environment` 依赖类型时，只需在此处追加一行 `.environment(...)`。
    /// 全量依赖清单通过 `rg "@Environment\([A-Z].*\.(self|shared)\)" Sources/` 盘点。
    func snapshotEnvironment(synthesisStore: SynthesisStore? = nil) -> some View {
        @Dependency(\.themeService) var themeManager
        return self
            // MARK: @Environment（@Observable 类型，共 16 个）
            .environment(AppStore())
            .environment(Router.shared)
            .environment(VaultService.shared)
            .environment(AuthService.shared)
            .environment(AppEnvironment.shared)
            .environment(SettingsStore())
            .environment(KnowledgeStore())
            .environment(IngestStore())
            .environment(synthesisStore ?? SynthesisStore())
            .environment(SearchStore())
            .environment(AIWorkflowStore())
            .environment(AIInsightStore())
            .environment(ChatCoordinator())
            .environment(LLMConfigManager())
            .environment(NotebookHubViewModel())
            .environment(themeManager)
            // MARK: @EnvironmentObject（ObservableObject 类型，共 3 个）
            .environmentObject(OnboardingService.shared)
            .environmentObject(LLMService.shared)
            .environmentObject(MedalService.shared)
    }
}

/// 轻量级快照测试助手
/// 原理：将视图渲染为 Image，并对比 Base64 哈希值
final class SnapshotHelper {
    
    /// 验证视图是否与参考快照一致
    @MainActor
    static func verifyView<V: View>(_ view: V, named name: String) -> Bool {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2.0 // 使用 Retina 分辨率
        
        guard let uiImage = renderer.uiImage,
              let data = uiImage.pngData() else {
            return false
        }

        // 1. 获取参考快照路径
        // swiftlint:disable:next force_unwrapping
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let refURL = docs.appendingPathComponent("snapshots/\(name).ref")
        
        // 2. 如果不存在参考快照，则记录当前快照为参考（录制模式）
        if !FileManager.default.fileExists(atPath: refURL.path) {
            try? FileManager.default.createDirectory(at: refURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: refURL)
            print("📸 [Snapshot] 参考快照已录制: \(name)")
            return true
        }
        
        // 3. 读取参考快照并对比
        let refData = try? Data(contentsOf: refURL)
        if data == refData {
            print("✅ [Snapshot] \(name) 验证通过！")
            return true
        } else {
            print("❌ [Snapshot] \(name) 验证失败！视觉出现偏差。")
            return false
        }
    }
}
